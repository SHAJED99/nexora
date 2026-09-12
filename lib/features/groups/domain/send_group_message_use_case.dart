// features/groups/domain — group message send/fan-out (E07-T06).
//
// FR-COMM-002's send half: encrypt a group text message exactly ONCE with
// the group's current-epoch Sender-Keys chain (`GroupCryptoService.
// encryptForGroup`, E07-T04), then fan that ONE ciphertext out as one
// `RelayPacketFrame` per current member other than self — the whole point
// of the Sender-Keys family ADR-0003 chose (task file §2): encrypt once,
// address N times.
//
// **OQ-E07-T06-1 — RESOLVED (2026-09-01, planner).** This file's sequence
// reservation is bound, by default, to the SAME transaction
// `SendMessageUseCase` uses: `MessageSequenceReserver`
// (`features/messaging/domain/message_sequence_reserver.dart`).
//
// The reservation was originally inlined inside `SendMessageUseCase.call`'s
// body over its private fields, with no smaller public entry point — the
// "private-member wall" this task's own §6 risk anticipated — so T06 could
// neither call it nor (per §3 step 2) copy it, and correctly shipped
// [ReserveGroupSequenceFn] as an UNBOUND injected seam plus an Open
// Question. The resolution is the extraction that question asked for: the
// transaction body moved verbatim out of `SendMessageUseCase.call` into
// `MessageSequenceReserver.reserve`, and both use cases now call it. ONE
// transaction implementation, TWO call sites — never two independent
// writers of one counter, which is L-backend-003's whole subject.
//
// [ReserveGroupSequenceFn] survives as an OPTIONAL constructor parameter:
// omitted (production), it binds to `MessageSequenceReserver` built from
// this use case's own `db`/`selfDeviceId`; supplied, it lets a test observe
// or perturb the reservation. That is the same DI shape
// `SendMessageUseCase` already uses for [MessageEncryptFn]/[MessageEnqueueFn]
// — with the difference that the default is now real, so constructing this
// class is enough to send a group message for real.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `send_message_use_case.dart`/`relay_engine.dart`/`inbound_pipeline.dart`:
// the fields are private while the constructor's public named parameters
// match this task's documented call shape.
// ignore_for_file: prefer_initializing_formals
import 'package:drift/drift.dart';

import '../../../core/auth/google_auth_service.dart' show AppFailure;
import '../../../core/crypto/group_crypto_service.dart';
// E04-B15: `resolveOutboundDestination` -- deliberately `show`n rather than
// importing the whole file, since `messaging_stack.dart` already imports
// THIS file (its own composition-root construction of
// `SendGroupMessageUseCase`) -- a `show` import of one top-level function
// keeps this side of the cycle minimal and avoids depending on anything
// else that file declares.
import '../../../core/messaging/messaging_stack.dart'
    show resolveOutboundDestination;
import '../../../core/messaging/relay_packet_frame.dart';
import '../../../core/persistence/database.dart';
import '../../messaging/domain/delivery_state_machine.dart';
import '../../messaging/domain/message.dart';
import '../../messaging/domain/message_sequence_reserver.dart';
import '../data/group_repository.dart';
import 'group_message_envelope.dart';
import 'group_permissions.dart';

/// The seam this use case needs to hand a fully-serialized wire frame to
/// E04's `RelayEngine` — identical in shape to
/// `send_message_use_case.dart`'s own `MessageEnqueueFn` (arity/order/return
/// type already verified equal to `RelayEngine.enqueue` by E05-T02/E06-T03's
/// own reviews), redeclared here rather than imported since this use case
/// must not depend on `send_message_use_case.dart` being present at a
/// specific version just to reuse a structurally-identical typedef.
typedef GroupMessageEnqueueFn = Future<String> Function(
  String destination,
  Uint8List payload,
  int priority,
  Duration ttl,
);

/// The reservation seam. Must, atomically (a single
/// `AppDatabase.transaction`): compute the next `sequenceNumber` for
/// `(groupId, senderDeviceId: selfDeviceId)` per `messages`' existing
/// monotonic-per-`(conversationId, senderDeviceId)` contract, insert a
/// `Queued` placeholder `messages` row for [messageId] with that number
/// (`ciphertext: Uint8List(0)`), and return the assigned sequence number.
///
/// Optional at the constructor: when omitted it binds to
/// [MessageSequenceReserver] — the one shared implementation, also used by
/// `SendMessageUseCase` (OQ-E07-T06-1). A test may supply its own to observe
/// the reservation; production code must NOT, and must never write a second
/// implementation of this transaction.
typedef ReserveGroupSequenceFn = Future<int> Function(
  String groupId,
  String messageId,
  int createdAtMs,
);

/// FR-COMM-002's send half (task file §1/§3). One instance per device
/// identity, mirroring `SendMessageUseCase`'s own shape.
class SendGroupMessageUseCase {
  SendGroupMessageUseCase({
    required AppDatabase db,
    required String selfDeviceId,
    required GroupRepository groups,
    required GroupCryptoService crypto,
    required GroupMessageEnqueueFn enqueue,
    ReserveGroupSequenceFn? reserveSequence,
    int priority = 0,
    Duration ttl = const Duration(days: 3),
    DateTime Function() clock = DateTime.now,
  })  : _db = db,
        _selfDeviceId = selfDeviceId,
        _groups = groups,
        _crypto = crypto,
        _enqueue = enqueue,
        _reserveSequence =
            reserveSequence ?? _sharedReserver(db, selfDeviceId),
        _priority = priority,
        _ttl = ttl,
        _clock = clock;

  final AppDatabase _db;
  final String _selfDeviceId;
  final GroupRepository _groups;
  final GroupCryptoService _crypto;
  final GroupMessageEnqueueFn _enqueue;
  final ReserveGroupSequenceFn _reserveSequence;
  final int _priority;
  final Duration _ttl;
  final DateTime Function() _clock;

  /// The production binding of [ReserveGroupSequenceFn] — the ONE shared
  /// reservation transaction (`MessageSequenceReserver`, also
  /// `SendMessageUseCase`'s), adapted to this typedef's positional shape. A
  /// group's `conversationId` IS its group id (task file §2), so no
  /// translation beyond the parameter name is needed.
  static ReserveGroupSequenceFn _sharedReserver(
    AppDatabase db,
    String selfDeviceId,
  ) {
    final reserver = MessageSequenceReserver(
      db: db,
      selfDeviceId: selfDeviceId,
    );
    return (groupId, messageId, createdAtMs) => reserver.reserve(
          conversationId: groupId,
          messageId: messageId,
          createdAtMs: createdAtMs,
        );
  }

  int _idCounter = 0;

  /// Timestamp + an in-process counter, unique per instance — matches
  /// `SendMessageUseCase._generateId`/`RelayEngine._generateId`'s own
  /// established pattern (no new dependency for an internal-only id).
  String _generateId() =>
      '${_clock().microsecondsSinceEpoch}-${_idCounter++}';

  /// The one call site described by the task's §5 contract: permission +
  /// current-membership check -> reserve sequence number -> encrypt once ->
  /// persist one `messages` row -> one `RelayPacketFrame` per current member
  /// except self, all sharing the ONE payload reference (task file §6: never
  /// mutate a serialized buffer in place per recipient).
  ///
  /// Returns `null` on success; `AppFailure('group.not_a_member')` /
  /// `AppFailure('group.forbidden')` / `AppFailure('group.unknown_group')` /
  /// whatever `GroupCryptoService.encryptForGroup` itself throws (in
  /// particular `AppFailure('group.no_chain')`) on failure.
  Future<AppFailure?> send({
    required String groupId,
    required Uint8List body,
  }) async {
    // Step 1 (task file §3): permission + current-membership check.
    // `GroupPermissions.allows(sendMessage)` is unconditionally `true` for
    // every role (`group_permissions.dart`'s own matrix) -- the real gate
    // is current membership itself, via `GroupRepository.roleOf`, which
    // returns `null` for a non-member OR an already-removed member
    // (`removedAtEpoch IS NULL` discipline, carried-forward finding #2).
    final myRole = await _groups.roleOf(groupId, _selfDeviceId);
    if (myRole == null) {
      return const AppFailure('group.not_a_member');
    }
    if (!GroupPermissions.allows(
      actorRole: myRole,
      action: GroupAction.sendMessage,
    )) {
      return const AppFailure('group.forbidden');
    }

    final group = await _groups.groupRow(groupId);
    if (group == null) return const AppFailure('group.unknown_group');
    final epoch = group.membershipEpoch;

    final messageId = _generateId();
    final now = _clock();
    final createdAtMs = now.millisecondsSinceEpoch;

    // Step 2 (task file §3): reserve the sequence number and durably insert
    // a `Queued` placeholder row, atomically, before any crypto call --
    // exactly `SendMessageUseCase.call`'s own phase-1 ordering, because it is
    // literally the same transaction (`MessageSequenceReserver`, bound by
    // default in this class's constructor -- OQ-E07-T06-1).
    final sequenceNumber =
        await _reserveSequence(groupId, messageId, createdAtMs);

    var message = Message(
      id: messageId,
      conversationId: groupId,
      senderDeviceId: _selfDeviceId,
      sequenceNumber: sequenceNumber,
      ciphertext: Uint8List(0),
      createdAt: createdAtMs,
      deliveryState: DeliveryState.queued,
    );

    final envelope = GroupMessageEnvelope(
      groupId: groupId,
      epoch: epoch,
      senderDeviceId: _selfDeviceId,
      messageId: messageId,
      sequenceNumber: sequenceNumber,
      createdAtMs: createdAtMs,
      body: body,
    );

    // Step 3 (task file §3): encrypt ONCE with the group's current-epoch
    // chain. Deliberately outside any transaction, same discipline
    // `SendMessageUseCase.call` already uses for its own single-recipient
    // encrypt (the crypto call never holds a DB lock open).
    final Uint8List ciphertext;
    try {
      ciphertext = await _crypto.encryptForGroup(
        groupId: groupId,
        epoch: epoch,
        plaintext: envelope.serialize(),
      );
    } on AppFailure catch (e) {
      // The reserved row is transitioned to Failed, never left at Queued
      // (task file §6; mirrors SendMessageUseCase's own `messaging.no_session`
      // handling for its analogous "reserved but never encrypted" case).
      await _applyTransition(message, DeliveryState.failed);
      return e;
    }

    // Step 4 (task file §3): persist the real ciphertext over the
    // placeholder -- the row stays Queued at this point.
    await (_db.update(_db.messages)..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(ciphertext: Value(ciphertext)));
    message = Message(
      id: message.id,
      conversationId: message.conversationId,
      senderDeviceId: message.senderDeviceId,
      sequenceNumber: message.sequenceNumber,
      ciphertext: ciphertext,
      createdAt: message.createdAt,
      deliveryState: message.deliveryState,
    );

    // Step 5 (task file §3/§6): one `RelayPacketFrame` per current member
    // except self, ALL SHARING the one payload reference -- `RelayPacketFrame`
    // is immutable by construction, so building N frames from the same
    // `controlPayload` Uint8List (never mutated, never rebuilt per
    // recipient) is what "one payload, N frames" means in practice; only
    // `destination` differs frame to frame.
    final routingHeaderBytes = GroupMessageRoutingHeader(
      groupId: groupId,
      epoch: epoch,
      ciphertext: ciphertext,
    ).serialize();
    final controlPayload = Uint8List(1 + routingHeaderBytes.length);
    controlPayload[0] = kControlKindGroupMessage;
    controlPayload.setRange(1, controlPayload.length, routingHeaderBytes);

    final members = await _groups.currentMembers(groupId);
    final recipients =
        members.map((m) => m.deviceId).where((id) => id != _selfDeviceId);
    final expiresAtMs = now.add(_ttl).millisecondsSinceEpoch;

    for (final recipientId in recipients) {
      try {
        // E04-B15: resolve the peer's real, learned `selfDeviceId` for the
        // frame's own `destination` field -- same forward-only pattern
        // E04-B13 established (`resolveOutboundDestination`'s own doc
        // comment in `messaging_stack.dart`), reused rather than
        // re-derived. `_enqueue` below keeps using the raw `recipientId`
        // (Bluetooth MAC) unchanged -- only the wire frame's own
        // `destination` field is resolved. Deliberately INSIDE this try
        // block (mirrors the sibling fix in `delivery_ack.dart`'s own
        // `_sendAck`): a resolution failure for one recipient must not
        // abort the whole fan-out loop any more than an `_enqueue` failure
        // already doesn't.
        final destination =
            await resolveOutboundDestination(_db, recipientId);
        final frame = RelayPacketFrame(
          payloadType: PayloadType.control,
          packetId: messageId,
          destination: destination,
          source: _selfDeviceId,
          priority: _priority,
          createdAtMs: createdAtMs,
          expiresAtMs: expiresAtMs,
          payload: controlPayload,
        );
        await _enqueue(recipientId, frame.serialize(), _priority, _ttl);
      } catch (_) {
        // Best-effort fan-out (task file §2/§6, mirrors
        // `GroupMembershipService._sendOne`'s own discipline): one
        // unreachable/failing recipient must never abort another
        // recipient's send or roll back the local write, which has already
        // committed by this point.
      }
    }

    message = await _applyTransition(message, DeliveryState.sent);
    return null;
  }

  Future<Message> _applyTransition(Message message, DeliveryState to) async {
    final updated = message.withDeliveryState(to);
    await (_db.update(_db.messages)..where((t) => t.id.equals(message.id)))
        .write(MessagesCompanion(deliveryState: Value(to.name)));
    return updated;
  }
}
