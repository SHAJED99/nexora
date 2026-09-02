// features/groups/domain — the six FR-GROUP-002 membership actions as real,
// networked, permission-checked operations (E07-T03).
//
// **The security design this whole file exists to uphold (task file §2,
// OQ-E07-6, group_control.dart's header).** `E06-B04` proved that
// `RelayPacketFrame.source` is an unauthenticated, attacker-settable claim
// at the transport layer — any existing `PayloadType.control` sub-protocol
// that trusts it outright (`PrekeyExchange`, `DeliveryAckService`) inherits
// that weakness. A group membership frame must not: a forged `frame.source`
// on a `memberRemoved` frame would let any mesh node remove any member of
// any group. So this file NEVER reads `RelayPacketFrame.source` as the
// acting device id. Instead:
//
//   - **Sending** ([_sendOne]): every [GroupControlFrame] is encrypted
//     through the pairwise Double Ratchet session with the recipient
//     (`PrekeyExchange.ensureSession` + `CryptoService.encrypt`, the same
//     machinery E06-T07 built for first-contact messaging) before it is
//     nested inside a `PayloadType.control` wire frame
//     (`group_control.dart`'s `encodeCiphertextControlBody`) and handed to
//     `RelayEngine.enqueue` for best-effort, asynchronous delivery.
//   - **Receiving** ([handleWireFrame]): the inbound wire frame's
//     `frame.source` is used ONLY as a hint for which pairwise session to
//     attempt decryption under (exactly how `ReceiveMessageUseCase` already
//     treats it for ordinary chat messages) — the ACTING device id this
//     file ever trusts is the address `CryptoService.decrypt` proves the
//     ciphertext really decrypted under. Decrypt failure (wrong session,
//     forged claim, tampered bytes) is `counters.groupUnauthenticated` and a
//     silent drop, never a crash and never an apply. On top of that,
//     [handleControlFrame] independently checks the DECRYPTED frame's own
//     `actorDeviceId` field against that same verified session address
//     (EARS-GROUP-10) — a frame that decrypted correctly under, say, a
//     Member's session but *claims* to be the Owner is still discarded,
//     because the claim inside the plaintext is exactly as forgeable as
//     `frame.source` ever was; only the session that produced the
//     ciphertext is trustworthy.
//
// **Permission is checked twice, both times locally (task file §2).** Every
// action method below checks `GroupPermissions` against this device's own
// role before ever building a frame (fail-fast, good UX) — see
// `group_repository.dart`'s header for why `GroupRepository.applyEvent`
// re-checks it again, unconditionally, on both the local-apply path AND the
// receive path, against each device's own current `GroupMembers` state. A
// receiver never trusts a sender's claim of authority.
//
// **Fan-out is best-effort and never blocks the local write (task file §6).**
// Every action method applies the local change (via
// `GroupRepository.applyEvent`) BEFORE attempting a single network send.
// Each recipient's send is independently wrapped so one unreachable member
// (a stalled `ensureSession`, a `RelayEngine.enqueue` failure) can never roll
// back the local change or abort another member's send.
//
// Does NOT implement `SenderKeyStore`/key distribution (E07-T04), key
// rotation (E07-T05), or message fan-out (E07-T06). Does NOT modify
// `PrekeyExchange`, `DeliveryAckService`, `InboundPipeline` or
// `relay_packet_frame.dart` — it registers on the existing
// `registerControlHandler` seam, exactly like T07/T08 did, and reads
// `CryptoService`/`PrekeyExchange`'s already-public API. Does NOT build any
// UI, controller or route (task file §4).
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `relay_engine.dart`/`inbound_pipeline.dart`/`prekey_exchange.dart`: the
// fields are private (`_stack`, `_repository`, ...) while the constructor's
// public named parameters match this task's documented §5 call shape.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../../../core/auth/google_auth_service.dart' show AppFailure;
import '../../../core/messaging/group_control.dart';
import '../../../core/messaging/messaging_stack.dart';
import '../../../core/messaging/relay_packet_frame.dart';
import '../../../core/persistence/group_tables.dart';
import '../../trust/data/relationship_repository.dart';
import '../data/group_repository.dart';
import 'group_key_rotation_service.dart';
import 'group_permissions.dart';

/// Matches `messaging_stack.dart`/`prekey_exchange.dart`'s own
/// `_remoteSignalDeviceId`/`_localSignalDeviceId` (private, so independently
/// redeclared per file — see `messaging_stack.dart`'s header, judgment
/// call 1, for why Dart makes literal reuse across files impossible).
const int _remoteSignalDeviceId = 1;

/// The wire TTL stamped on every group control frame this file sends —
/// short-lived is fine, since a fan-out that is still queued when a later
/// membership change supersedes it will simply be superseded by that later
/// change's own, higher epoch on arrival.
const Duration _controlFrameTtl = Duration(days: 1);

/// Default bound on how long a single fan-out recipient's `ensureSession`
/// may take before that ONE send is abandoned (not the whole fan-out — task
/// file §6: "one failed member send must not ... abort the other sends").
/// Overridable per instance so a test does not have to wait out a full
/// production-sized timeout to prove an unreachable member doesn't block the
/// others.
const Duration _defaultFanOutSessionTimeout = Duration(seconds: 20);

/// So a dropped frame is observable rather than silent (task file §3),
/// mirroring `InboundCounters`/`PrekeyExchangeCounters`'s own style.
class GroupMembershipCounters {
  /// A control frame's claimed action was refused by `GroupPermissions`
  /// against this device's own current membership state.
  int groupForbidden = 0;

  /// A control frame's epoch was `<= ` this device's already-applied epoch.
  int groupReplayed = 0;

  /// A control frame's epoch was more than one ahead of this device's
  /// current epoch — parked, not applied speculatively.
  int groupOutOfOrder = 0;

  /// A control frame failed to decrypt under the claimed session, OR its
  /// decrypted `actorDeviceId` field disagreed with the session that
  /// actually produced it (EARS-GROUP-10) — the security property this
  /// whole file exists to enforce.
  int groupUnauthenticated = 0;
}

/// The six FR-GROUP-002 actions (plus `leave` and `createGroup`), each:
/// permission check -> local transaction -> best-effort fan-out over
/// pairwise sessions (task file §3). Exactly one instance per
/// [MessagingStack], constructed and registered by
/// [MessagingStack.create] itself — mirrors `PrekeyExchange`/
/// `DeliveryAckService`'s own construction pattern.
class GroupMembershipService {
  GroupMembershipService({
    required MessagingStack stack,
    required GroupRepository repository,
    required RelationshipRepository relationshipRepository,
    DateTime Function() clock = DateTime.now,
    Duration fanOutSessionTimeout = _defaultFanOutSessionTimeout,
  })  : _stack = stack,
        _repository = repository,
        _relationshipRepository = relationshipRepository,
        _clock = clock,
        _fanOutSessionTimeout = fanOutSessionTimeout;

  final MessagingStack _stack;
  final GroupRepository _repository;
  final RelationshipRepository _relationshipRepository;
  final DateTime Function() _clock;
  final Duration _fanOutSessionTimeout;

  final GroupMembershipCounters counters = GroupMembershipCounters();

  int _packetIdCounter = 0;
  String _nextPacketId() =>
      'gc:${_stack.selfDeviceId}-${_clock().microsecondsSinceEpoch}-${_packetIdCounter++}';

  /// `GroupKeyRotationService` (E07-T05), built lazily on first use rather
  /// than in this constructor. `MessagingStack`'s own constructor builds
  /// `groupMembershipService` (this class) BEFORE `groupCryptoService`
  /// (see `messaging_stack.dart`'s constructor body) -- reading
  /// `_stack.groupCryptoService` eagerly here would throw a
  /// `LateInitializationError` on every real app boot. By the time either
  /// [_perform] or [handleControlFrame] actually runs, `MessagingStack`'s
  /// constructor has long since finished and `groupCryptoService` is a
  /// real, fully-constructed instance -- so a lazy getter is sufficient and
  /// requires no change to `messaging_stack.dart` (out of this task's
  /// `files:` fence).
  GroupKeyRotationService? _rotationOrNull;
  GroupKeyRotationService get _rotation => _rotationOrNull ??=
      GroupKeyRotationService(
        groups: _repository,
        crypto: _stack.groupCryptoService,
        selfDeviceId: _stack.selfDeviceId,
      );

  /// The most recently fired (never awaited by production code — see the
  /// call sites) rotation `Future`, so this file's own test suite can await
  /// it deterministically instead of sleeping a fixed duration. Not part of
  /// this task's §5 contract, not annotated `@visibleForTesting` (that
  /// would need `package:meta` added as a direct dependency — a 🧍
  /// `new_dependency` gate this one testing seam does not justify); never
  /// read outside tests.
  Future<Map<String, AppFailure?>>? lastRotationForTest;

  // --- Founding write -------------------------------------------------

  /// Creates a group locally (this device becomes Owner) and fans out a
  /// `created` [GroupControlFrame] — carrying the full roster via
  /// `memberList` — to every invitee, so a device that has never heard of
  /// this group before learns it in one frame (task file §2/§3). A local
  /// act: there is no server to register with (ADR-0005).
  Future<String> createGroup({
    required String name,
    required List<String> memberDeviceIds,
  }) async {
    final ownerDeviceId = _stack.selfDeviceId;
    final groupId = await _repository.createGroup(
      name: name,
      ownerDeviceId: ownerDeviceId,
      memberDeviceIds: memberDeviceIds,
    );
    final roster = <String>[
      ownerDeviceId,
      ...memberDeviceIds.where((m) => m != ownerDeviceId),
    ];
    final frame = GroupControlFrame(
      kind: GroupEventKind.created,
      groupId: groupId,
      epoch: 0,
      actorDeviceId: ownerDeviceId,
      name: name,
      memberList: roster,
      createdAtMs: _clock().millisecondsSinceEpoch,
    );
    final bytes = frame.serialize();
    await Future.wait(
      roster.where((m) => m != ownerDeviceId).map((m) => _sendOne(m, bytes)),
    );
    return groupId;
  }

  // --- The eight FR-GROUP-002/003 actions ------------------------------

  Future<AppFailure?> rename(String groupId, String newName) => _perform(
        groupId: groupId,
        action: GroupAction.rename,
        name: newName,
      );

  /// FR-BLOCK-001 (E02): a device the local user has blocked is refused
  /// locally with `group.blocked_member` before any frame is built — this
  /// is a LOCAL view only. An incoming `memberAdded` naming a blocked device
  /// is still applied by [GroupRepository.applyEvent] (task file §2): the
  /// group really does contain them, and blocking stays a local filter on
  /// their messages, not a group-wide veto another member can be silently
  /// overridden by.
  Future<AppFailure?> addMember(String groupId, String deviceId) async {
    if (await _relationshipRepository.isBlocked(deviceId)) {
      return const AppFailure('group.blocked_member');
    }
    return _perform(
      groupId: groupId,
      action: GroupAction.addMember,
      subjectDeviceId: deviceId,
    );
  }

  Future<AppFailure?> removeMember(String groupId, String deviceId) => _perform(
        groupId: groupId,
        action: GroupAction.removeMember,
        subjectDeviceId: deviceId,
      );

  Future<AppFailure?> grantAdmin(String groupId, String deviceId) => _perform(
        groupId: groupId,
        action: GroupAction.grantAdmin,
        subjectDeviceId: deviceId,
      );

  Future<AppFailure?> revokeAdmin(String groupId, String deviceId) => _perform(
        groupId: groupId,
        action: GroupAction.revokeAdmin,
        subjectDeviceId: deviceId,
      );

  Future<AppFailure?> transferOwnership(String groupId, String toDeviceId) =>
      _perform(
        groupId: groupId,
        action: GroupAction.transferOwnership,
        subjectDeviceId: toDeviceId,
      );

  Future<AppFailure?> deleteGroup(String groupId) => _perform(
        groupId: groupId,
        action: GroupAction.deleteGroup,
      );

  /// Sent on the wire as a `memberRemoved` [GroupControlFrame] with
  /// `subjectDeviceId == actorDeviceId == selfDeviceId` — a self-removal,
  /// distinct from an Owner/Admin removing someone else (see
  /// `group_repository.dart`'s `_checkPermission`, which uses exactly that
  /// equality to pick `GroupAction.leave` over `GroupAction.removeMember`).
  Future<AppFailure?> leave(String groupId) => _perform(
        groupId: groupId,
        action: GroupAction.leave,
        subjectDeviceId: _stack.selfDeviceId,
      );

  /// Permission check -> local transaction -> best-effort fan-out, the
  /// shared shape every action above follows (task file §3).
  Future<AppFailure?> _perform({
    required String groupId,
    required GroupAction action,
    String? subjectDeviceId,
    String? name,
  }) async {
    final myRole = await _repository.roleOf(groupId, _stack.selfDeviceId);
    if (myRole == null) return const AppFailure('group.forbidden');

    GroupRole? subjectRole;
    var effectiveAction = action;
    if (action == GroupAction.removeMember || action == GroupAction.removeAdmin) {
      if (subjectDeviceId == null) return const AppFailure('group.forbidden');
      if (subjectDeviceId == _stack.selfDeviceId) {
        // A self-targeted removeMember is a `leave`, not a `removeMember` --
        // distinct permission row, and `GroupAction.leave` never conditions
        // on subjectRole at all, so there is no null-subject hazard for it.
        // Mirrors `group_repository.dart`'s `_checkPermission`, which makes
        // exactly this substitution on the receive side for a self-targeted
        // `memberRemoved` frame; the sender-side check must agree with it,
        // or a self-targeted `removeMember` call falls through to
        // `GroupPermissions.check(removeMember, subjectRole: null)`, which
        // throws `ArgumentError` instead of returning an `AppFailure`.
        if (action == GroupAction.removeMember) {
          effectiveAction = GroupAction.leave;
        }
      } else {
        subjectRole = await _repository.roleOf(groupId, subjectDeviceId);
        if (subjectRole == null) {
          // Carried-forward finding #1: never reach GroupPermissions.allows
          // with a null subjectRole -- the target isn't a current member,
          // which is a precondition failure/denial, not a permission
          // decision (see group_repository.dart's own copy of this guard
          // for the receive-side half of the same rule).
          return const AppFailure('group.forbidden');
        }
      }
    }

    final failure = GroupPermissions.check(
      actorRole: myRole,
      action: effectiveAction,
      subjectRole: subjectRole,
    );
    if (failure != null) return failure;

    final group = await _repository.groupRow(groupId);
    if (group == null) return const AppFailure('group.unknown_group');
    final newEpoch = group.membershipEpoch + 1;

    final frame = GroupControlFrame(
      kind: _kindFor(action),
      groupId: groupId,
      epoch: newEpoch,
      actorDeviceId: _stack.selfDeviceId,
      subjectDeviceId: subjectDeviceId,
      name: name,
      createdAtMs: _clock().millisecondsSinceEpoch,
    );

    final applyFailure = await _repository.applyEvent(frame);
    if (applyFailure != null) return applyFailure;

    // E07-T05: every epoch bump rotates, with no per-action list to keep
    // in sync (task file §2) -- fired immediately after the commit above
    // succeeds, before the membership-frame fan-out below, and inside
    // neither the write transaction nor that fan-out loop.
    //
    // Deliberately NOT awaited (task file §2: "rotation is best-effort per
    // recipient and never blocks the local change"). Unlike this file's own
    // membership-frame fan-out below, whose per-recipient bound
    // (`_fanOutSessionTimeout`) is test-overridable,
    // `GroupCryptoService.distributeTo`'s own `ensureSession` call
    // (E07-T04) uses a hardcoded, non-configurable ~20s timeout per
    // recipient -- awaiting it here would make `rename`/`removeMember`/etc.
    // ride behind an unreachable member's own network attempt for up to
    // 20s, exactly the regression
    // `test_EARS_GROUP_8_local_write_is_not_blocked_by_a_failing_member_send`
    // (E07-T03) exists to catch, and did catch during this task's own
    // development (see Run log). `onEpochApplied` itself never throws for a
    // per-recipient distribution failure (E07-T04's own contract), so the
    // `catchError` below only guards against a genuine bug in the mint/
    // discard steps becoming an unhandled Future rejection.
    // `lastRotationForTest` exists purely so this file's own test suite can
    // await the fired-off rotation deterministically rather than sleeping a
    // fixed duration -- never read by production code.
    final rotationFuture = _rotation.onEpochApplied(
      groupId: groupId,
      newEpoch: newEpoch,
      kind: frame.kind,
    );
    lastRotationForTest = rotationFuture;
    unawaited(rotationFuture.catchError((_) => <String, AppFailure?>{}));

    final members = await _repository.currentMembers(groupId);
    final bytes = frame.serialize();
    await Future.wait(
      members
          .where((m) => m.deviceId != _stack.selfDeviceId)
          .map((m) => _sendOne(m.deviceId, bytes)),
    );

    return null;
  }

  GroupEventKind _kindFor(GroupAction action) {
    switch (action) {
      case GroupAction.rename:
        return GroupEventKind.renamed;
      case GroupAction.addMember:
        return GroupEventKind.memberAdded;
      case GroupAction.removeMember:
      case GroupAction.leave:
        return GroupEventKind.memberRemoved;
      case GroupAction.grantAdmin:
        return GroupEventKind.adminGranted;
      case GroupAction.revokeAdmin:
        return GroupEventKind.adminRevoked;
      case GroupAction.transferOwnership:
        return GroupEventKind.ownershipTransferred;
      case GroupAction.deleteGroup:
        return GroupEventKind.deleted;
      case GroupAction.removeAdmin:
        // No GroupMembershipService entry point calls this action (task
        // file §5's function list has no `removeAdmin` method) -- to remove
        // an admin from the group entirely, the Owner revokes their admin
        // status first (`revokeAdmin`, demoting to Member) and then removes
        // them as a Member (`removeMember`). Unreachable in practice.
        throw UnsupportedError(
          'GroupAction.removeAdmin has no GroupMembershipService entry point',
        );
      case GroupAction.sendMessage:
        throw UnsupportedError(
          'GroupAction.sendMessage is not a membership action',
        );
    }
  }

  // --- Fan-out (send side) ---------------------------------------------

  /// Encrypts [plaintext] (a serialized [GroupControlFrame]) through the
  /// pairwise session with [peerDeviceId] and hands it to `RelayEngine` for
  /// best-effort, asynchronous delivery. Every failure (session
  /// establishment, encryption, enqueue) is swallowed here — task file §6:
  /// one unreachable member must never roll back the local change or abort
  /// another member's send.
  Future<void> _sendOne(String peerDeviceId, Uint8List plaintext) async {
    try {
      await _stack.prekeyExchange.ensureSession(
        peerDeviceId,
        timeout: _fanOutSessionTimeout,
      );
      final address = SignalProtocolAddress(peerDeviceId, _remoteSignalDeviceId);
      final ciphertext = await _stack.cryptoService.encrypt(address, plaintext);
      final body = encodeCiphertextControlBody(ciphertext);
      final framedBody = Uint8List(body.length + 1);
      framedBody[0] = kControlKindGroupControl;
      framedBody.setRange(1, framedBody.length, body);

      final now = _clock();
      final wireFrame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: _nextPacketId(),
        destination: peerDeviceId,
        source: _stack.selfDeviceId,
        priority: 0,
        createdAtMs: now.millisecondsSinceEpoch,
        expiresAtMs: now.add(_controlFrameTtl).millisecondsSinceEpoch,
        payload: framedBody,
      );
      await _stack.relayEngine.enqueue(
        peerDeviceId,
        wireFrame.serialize(),
        0,
        _controlFrameTtl,
      );
    } catch (_) {
      // Best-effort (task file §6) -- the caller already committed the
      // local change before this method ever ran.
    }
  }

  // --- Receive side ------------------------------------------------------

  /// Registered on `stack.inbound.registerControlHandler(kControlKindGroupControl, ...)`
  /// (E06-T05's seam, unmodified by this task). [frame.payload] here has
  /// already had its leading `controlKind` byte read and stripped by
  /// `InboundPipeline` — it is exactly [encodeCiphertextControlBody]'s
  /// output: a ciphertext type tag followed by the serialized
  /// `CiphertextMessage`.
  ///
  /// **[frame.source] is used ONLY to select which pairwise session to
  /// attempt decryption under — never trusted as the acting device id.**
  /// The device id this method actually believes is whatever
  /// `CryptoService.decrypt` proves the ciphertext decrypted under: on
  /// success, [frame.source] and that session's address are, by
  /// construction, the same address (there is exactly one session per
  /// `SignalProtocolAddress`) — but the trust comes from decryption
  /// succeeding, not from the header claim, exactly as `group_control.dart`
  /// and this file's own header document. A decrypt failure (wrong session,
  /// forged claim, corrupt bytes) is dropped and counted as
  /// `groupUnauthenticated`; it never reaches [handleControlFrame].
  Future<void> handleWireFrame(RelayPacketFrame frame) async {
    final CiphertextMessage ciphertext;
    try {
      ciphertext = decodeCiphertextControlBody(frame.payload);
    } on AppFailure {
      return;
    }

    final address = SignalProtocolAddress(frame.source, _remoteSignalDeviceId);
    final Uint8List plaintext;
    try {
      plaintext = await _stack.cryptoService.decrypt(address, ciphertext);
    } catch (_) {
      // Any decrypt failure -- no session, wrong session, tampered
      // ciphertext, replay -- is exactly the same "not authenticated"
      // outcome from this file's perspective (EARS-GROUP-10).
      counters.groupUnauthenticated++;
      return;
    }

    await handleControlFrame(frame.source, plaintext);
  }

  /// The receive half's business logic (task file §5's contract), separated
  /// from [handleWireFrame]'s decrypt step so it is directly testable
  /// against already-decrypted bytes and an already-verified
  /// [sourceDeviceId] — see this task's own test file for how it hand-builds
  /// scenarios this way, mirroring `prekey_exchange_test.dart`'s
  /// `test_unsolicited_bundle_response_is_dropped` pattern.
  ///
  /// [sourceDeviceId] MUST be the address of the Signal session [plaintext]
  /// decrypted under (task file §5) — never `RelayPacketFrame.source`
  /// directly from an unauthenticated frame.
  Future<void> handleControlFrame(
    String sourceDeviceId,
    Uint8List plaintext,
  ) async {
    final GroupControlFrame frame;
    try {
      frame = GroupControlFrame.deserialize(plaintext);
    } on AppFailure {
      return;
    }

    if (frame.actorDeviceId != sourceDeviceId) {
      // EARS-GROUP-10: the claimed actor inside the (already-decrypted)
      // frame disagrees with the identity of the session that actually
      // decrypted it. The plaintext's own `actorDeviceId` field is exactly
      // as forgeable as `frame.source` ever was -- only the session
      // address is trustworthy.
      counters.groupUnauthenticated++;
      return;
    }

    final result = await _repository.applyEvent(frame);
    if (result == null) {
      // E07-T05: this device just applied someone else's membership
      // frame -- it rotates its own outbound chain too. Every device
      // rotates on an epoch change; rotation is not the acting device's
      // job alone (task file §3). Fired, not awaited -- same reasoning as
      // the local-action path above: awaiting `distributeTo`'s
      // non-configurable ~20s-per-recipient timeout here would stall
      // `InboundPipeline`'s dispatch of every subsequent frame from this
      // peer behind an unreachable co-member's own network attempt.
      final rotationFuture = _rotation.onRemoteEpochApplied(
        groupId: frame.groupId,
        newEpoch: frame.epoch,
        kind: frame.kind,
      );
      lastRotationForTest = rotationFuture;
      unawaited(rotationFuture.catchError((_) => <String, AppFailure?>{}));
      return;
    }
    switch (result.code) {
      case 'group.forbidden':
        counters.groupForbidden++;
      case 'group.replayed':
        counters.groupReplayed++;
      case 'group.out_of_order':
        counters.groupOutOfOrder++;
      default:
        // 'group.unknown_group' / 'group.malformed_control' -- a
        // structurally or referentially bad frame, not a policy violation;
        // no dedicated counter is named for it in the task's own §3
        // contract, so it is dropped without inflating one of the four
        // named counters.
        break;
    }
  }
}
