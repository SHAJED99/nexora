// core/crypto — group message encryption: the concrete Sender-Keys layer
// ADR-0003 deferred, and `OQ-E07-8` designed at sharding time (E07-T04).
//
// **The layering, concretely (task file §2, `OQ-E07-8`).**
// `libsignal_protocol_dart` 0.8.2 already ships the group primitives this
// file composes — `GroupSessionBuilder`, `GroupCipher`, `SenderKeyName`,
// `SenderKeyRecord` — over the [DriftSenderKeyStore] this task's sibling file
// provides. Nothing here is hand-rolled crypto: every key/ratchet/cipher
// operation below is a `libsignal_protocol_dart` call. Rolling a custom group
// ratchet is out of scope and forbidden (ADR-0003 §Options, option 3).
//
// **Distribution rides the pairwise Double Ratchet session, one recipient at
// a time (task file §2) — this is the join between the two schemes.** A
// group chain key is a secret that must reach exactly the current members,
// and the only authenticated confidential channel this app has to each
// member is the 1:1 session `E03`/`E06-T07` built. [distributeTo] therefore:
// `PrekeyExchange.ensureSession` -> `CryptoService.encrypt` (the pairwise
// ratchet, NOT the group cipher) -> `encodeCiphertextControlBody`
// (`group_control.dart`'s existing nesting codec, reused unchanged) ->
// `RelayEngine.enqueue`, exactly the same shape
// `GroupMembershipService._sendOne` (E07-T03) already established for
// membership control frames, on the new `kControlKindGroupKeyDistribution`
// slot rather than fighting T03 for its own.
//
// **What actually travels inside that pairwise ciphertext is a small private
// envelope ([_KeyDistributionEnvelope]), not the raw
// `SenderKeyDistributionMessage` bytes alone.** The distribution message
// itself carries no `groupId`/`epoch` — libsignal's own wire format has no
// room for either — so this file wraps it with the `(groupId, epoch,
// distributionMessageBytes)` triple the receive side needs to reconstruct
// the exact [senderKeyNameFor] used to mint it. Deterministic binary
// encoding, length-prefixed, the same idiom `group_control.dart`/
// `prekey_exchange.dart` already use — never JSON. Private to this file:
// nothing outside this task ever needs to parse it.
//
// **The epoch mapping itself lives in `drift_sender_key_store.dart`**
// ([senderKeyNameFor]/[parseSenderKeyName]), not duplicated here — this file
// is the only caller.
//
// **`FR-GROUP-006` is enforced here, at the send site only (task file §2).**
// [distributeTo] refuses any recipient whose `joined_at_epoch` is greater
// than the epoch being distributed — the human's 2026-08-26 decision (v1 has
// no exception path for historical access) encoded as a hard refusal.
// `E07-T05` enforces the same check again at rotation; this task does not
// duplicate that enforcement on the *receive* side (task file §2).
//
// **`decryptFromGroup`/`encryptForGroup` fail loudly, never silently, when no
// chain exists for the given `(group, epoch, sender)`** (task file §6's own
// risk note: `SenderKeyStore.loadSenderKey` returning a fresh empty record
// for an unknown name is indistinguishable, at the call site, from "I have a
// chain but it's empty"). `GroupCipher` itself throws `NoSessionException` in
// exactly that case (`decryptWithCallback`'s own `record.isEmpty` check,
// `GroupCipher.encrypt`'s `InvalidKeyIdException` -> `NoSessionException`
// translation) — caught here and re-thrown as `AppFailure('group.no_chain')`,
// this codebase's one error envelope, rather than letting a confusing
// library exception escape.
//
// Does NOT decide when to rotate a chain (`E07-T05` calls [ensureOwnChain]/
// [distributeTo]/[discardChains] in response to an epoch change; no epoch
// listener lives here). Does NOT send or receive group *messages*
// (`E07-T06`; [encryptForGroup]/[decryptFromGroup] are the thin wrappers that
// task consumes). Does NOT modify `DriftSignalProtocolStore`, `CryptoService`,
// `IdentityService`, `PrekeyExchange` or `InboundPipeline` — it composes them,
// exactly like `GroupMembershipService` (E07-T03) does. Does NOT add a table,
// column, index or migration (`E07-T01` owns `group_sender_keys`). Does NOT
// fix the one-time-prekey pool leak (`OQ-E06-T07-2`/`OQ-E07-9`) — a group's
// first key distribution can consume up to N-1 one-time prekeys in one burst,
// and this task's own test suite asserts that number rather than fixing it.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `relay_engine.dart`/`prekey_exchange.dart`/`group_membership_service.dart`.
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../auth/google_auth_service.dart' show AppFailure;
import '../messaging/group_control.dart';
import '../messaging/messaging_stack.dart';
import '../messaging/relay_packet_frame.dart';
import 'drift_sender_key_store.dart';

/// The `controlKind` byte `InboundPipeline` dispatches on
/// (`inbound_pipeline.dart`'s keyed `Map<int, ControlHandler>`) — `1` is
/// `PrekeyExchange`'s (E06-T07), `2` is `DeliveryAckService`'s (E06-T08), `3`
/// is `GroupMembershipService`'s (E07-T03); this task's group key
/// distribution protocol takes the next unused value. Registered against
/// [GroupCryptoService.handleWireFrame] in `messaging_stack.dart`.
const int kControlKindGroupKeyDistribution = 4;

/// The wire TTL stamped on every key-distribution control frame this file
/// sends — mirrors `GroupMembershipService`'s own `_controlFrameTtl`
/// reasoning: a distribution that is still queued when a later rotation
/// supersedes it is simply superseded by that rotation's own, later
/// distribution on arrival.
const Duration _controlFrameTtl = Duration(days: 1);

/// The small private envelope a key-distribution control frame's PLAINTEXT
/// (i.e., already decrypted through the pairwise session) actually carries:
/// the `(groupId, epoch)` pair the raw `SenderKeyDistributionMessage` bytes
/// cannot themselves express, alongside those bytes unchanged (this file's
/// header). Pure codec, no I/O — mirrors `group_control.dart`'s own
/// length-prefixed, non-JSON discipline. Private: nothing outside this file
/// ever constructs or inspects one directly.
class _KeyDistributionEnvelope {
  const _KeyDistributionEnvelope({
    required this.groupId,
    required this.epoch,
    required this.distributionMessageBytes,
  });

  final String groupId;
  final int epoch;
  final Uint8List distributionMessageBytes;

  Uint8List serialize() {
    final groupIdBytes = Uint8List.fromList(utf8.encode(groupId));
    final totalLength = 4 + // groupIdLen
        groupIdBytes.length +
        4 + // epoch
        4 + // distLen
        distributionMessageBytes.length;

    final buffer = ByteData(totalLength);
    final bytes = buffer.buffer.asUint8List();
    var offset = 0;

    buffer.setUint32(offset, groupIdBytes.length);
    offset += 4;
    bytes.setRange(offset, offset + groupIdBytes.length, groupIdBytes);
    offset += groupIdBytes.length;

    buffer.setUint32(offset, epoch);
    offset += 4;

    buffer.setUint32(offset, distributionMessageBytes.length);
    offset += 4;
    bytes.setRange(
      offset,
      offset + distributionMessageBytes.length,
      distributionMessageBytes,
    );
    offset += distributionMessageBytes.length;

    return bytes;
  }

  static _KeyDistributionEnvelope deserialize(Uint8List bytes) {
    final view = ByteData.sublistView(bytes);
    var offset = 0;

    _requireRemaining(bytes, offset, 4);
    final groupIdLen = view.getUint32(offset);
    offset += 4;
    _requireRemaining(bytes, offset, groupIdLen);
    final groupId = utf8.decode(bytes.sublist(offset, offset + groupIdLen));
    offset += groupIdLen;

    _requireRemaining(bytes, offset, 4);
    final epoch = view.getUint32(offset);
    offset += 4;

    _requireRemaining(bytes, offset, 4);
    final distLen = view.getUint32(offset);
    offset += 4;
    _requireRemaining(bytes, offset, distLen);
    final distBytes =
        Uint8List.fromList(bytes.sublist(offset, offset + distLen));
    offset += distLen;

    if (offset != bytes.length) {
      throw const AppFailure('group.malformed_control');
    }

    return _KeyDistributionEnvelope(
      groupId: groupId,
      epoch: epoch,
      distributionMessageBytes: distBytes,
    );
  }

  static void _requireRemaining(Uint8List bytes, int offset, int needed) {
    if (bytes.length < offset + needed) {
      throw const AppFailure('group.malformed_control');
    }
  }
}

/// The group message-encryption surface (task file §1/§3): this device's own
/// outbound chain per `(group, epoch)`, every peer's inbound chain, both
/// persisted durably via [DriftSenderKeyStore], and the distribution
/// mechanism that hands a member the chain key they need without ever
/// putting it on the wire in the clear. Exactly one instance per
/// [MessagingStack], constructed and registered by [MessagingStack]'s own
/// constructor — mirrors `PrekeyExchange`/`GroupMembershipService`'s own
/// construction pattern.
class GroupCryptoService {
  GroupCryptoService({
    required MessagingStack stack,
    DriftSenderKeyStore? senderKeyStore,
    DateTime Function() clock = DateTime.now,
  })  : _stack = stack,
        _clock = clock,
        _senderKeyStore = senderKeyStore ?? DriftSenderKeyStore(stack.db) {
    _sessionBuilder = GroupSessionBuilder(_senderKeyStore);
  }

  final MessagingStack _stack;
  final DateTime Function() _clock;
  final DriftSenderKeyStore _senderKeyStore;
  late final GroupSessionBuilder _sessionBuilder;

  int _packetIdCounter = 0;
  String _nextPacketId() =>
      'gkd:${_stack.selfDeviceId}-${_clock().microsecondsSinceEpoch}-'
      '${_packetIdCounter++}';

  // --- This device's own chain -----------------------------------------

  /// Creates this device's own sender key for `(groupId, epoch)` via
  /// `GroupSessionBuilder.create` if one does not already exist, and returns
  /// the serialized `SenderKeyDistributionMessage` bytes either way (task
  /// file §3/§5). Idempotent by construction: `GroupSessionBuilder.create`
  /// itself only mints a fresh chain when the loaded record `isEmpty` — a
  /// second call for the same `(groupId, epoch)` returns a distribution
  /// message for the SAME chain, never a new one.
  Future<Uint8List> ensureOwnChain({
    required String groupId,
    required int epoch,
  }) async {
    final name = senderKeyNameFor(
      groupId: groupId,
      epoch: epoch,
      senderDeviceId: _stack.selfDeviceId,
    );
    final wrapper = await _sessionBuilder.create(name);
    return wrapper.serialize();
  }

  // --- Distribution (send side) -----------------------------------------

  /// Hands each of [recipientDeviceIds] this device's chain key for
  /// `(groupId, epoch)` inside their pairwise Signal session (task file
  /// §2/§3). Refuses any recipient whose `joined_at_epoch` is greater than
  /// [epoch] with `AppFailure('group.member_joined_later')`
  /// (`FR-GROUP-006`) — including a device this table has no membership row
  /// for at all, which cannot have a valid `joined_at_epoch` either. A
  /// failure for one recipient never aborts the others: each recipient's
  /// outcome is independent, mirroring `GroupMembershipService._sendOne`'s
  /// own "one unreachable member must never abort another member's send"
  /// discipline (task file §6).
  Future<Map<String, AppFailure?>> distributeTo({
    required String groupId,
    required int epoch,
    required List<String> recipientDeviceIds,
  }) async {
    final distributionMessageBytes =
        await ensureOwnChain(groupId: groupId, epoch: epoch);
    final envelopeBytes = _KeyDistributionEnvelope(
      groupId: groupId,
      epoch: epoch,
      distributionMessageBytes: distributionMessageBytes,
    ).serialize();

    final results = <String, AppFailure?>{};
    for (final recipientDeviceId in recipientDeviceIds) {
      final joinedAtEpoch = await _joinedAtEpoch(groupId, recipientDeviceId);
      if (joinedAtEpoch == null || joinedAtEpoch > epoch) {
        results[recipientDeviceId] =
            const AppFailure('group.member_joined_later');
        continue;
      }
      results[recipientDeviceId] =
          await _sendOne(recipientDeviceId, envelopeBytes);
    }
    return results;
  }

  Future<int?> _joinedAtEpoch(String groupId, String deviceId) async {
    final db = _stack.db;
    final row = await (db.select(db.groupMembers)
          ..where(
            (t) => t.groupId.equals(groupId) & t.deviceId.equals(deviceId),
          ))
        .getSingleOrNull();
    return row?.joinedAtEpoch;
  }

  /// Encrypts [envelopeBytes] through the pairwise session with
  /// [recipientDeviceId] and hands it to `RelayEngine` for best-effort,
  /// asynchronous delivery — the exact same shape
  /// `GroupMembershipService._sendOne` (E07-T03) already established, on
  /// this task's own `kControlKindGroupKeyDistribution` slot. Every failure
  /// (session establishment, encryption, enqueue) is caught and returned as
  /// an [AppFailure] rather than thrown, so [distributeTo] can report a
  /// per-recipient outcome without one recipient's failure aborting another.
  Future<AppFailure?> _sendOne(
    String recipientDeviceId,
    Uint8List envelopeBytes,
  ) async {
    try {
      await _stack.prekeyExchange.ensureSession(recipientDeviceId);
      final address =
          SignalProtocolAddress(recipientDeviceId, kSenderKeyDeviceId);
      final ciphertext =
          await _stack.cryptoService.encrypt(address, envelopeBytes);
      final body = encodeCiphertextControlBody(ciphertext);
      final framedBody = Uint8List(body.length + 1);
      framedBody[0] = kControlKindGroupKeyDistribution;
      framedBody.setRange(1, framedBody.length, body);

      final now = _clock();
      final wireFrame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: _nextPacketId(),
        destination: recipientDeviceId,
        source: _stack.selfDeviceId,
        priority: 0,
        createdAtMs: now.millisecondsSinceEpoch,
        expiresAtMs: now.add(_controlFrameTtl).millisecondsSinceEpoch,
        payload: framedBody,
      );
      await _stack.relayEngine.enqueue(
        recipientDeviceId,
        wireFrame.serialize(),
        0,
        _controlFrameTtl,
      );
      return null;
    } catch (e) {
      return AppFailure('group.key_distribution_failed', cause: e);
    }
  }

  // --- Receive side -------------------------------------------------------

  /// Registered on `stack.inbound.registerControlHandler
  /// (kControlKindGroupKeyDistribution, ...)` (E06-T05's seam, unmodified by
  /// this task). [frame.payload] here has already had its leading
  /// `controlKind` byte read and stripped by `InboundPipeline` — it is
  /// exactly [encodeCiphertextControlBody]'s output.
  ///
  /// [frame.source] is used ONLY to select which pairwise session to attempt
  /// decryption under — never trusted as the acting device id, exactly the
  /// same discipline `GroupMembershipService.handleWireFrame` (E07-T03) and
  /// this file's own header document. A decrypt failure (wrong session,
  /// forged claim, corrupt bytes) is dropped silently; it never reaches
  /// [acceptDistribution].
  Future<void> handleWireFrame(RelayPacketFrame frame) async {
    final CiphertextMessage ciphertext;
    try {
      ciphertext = decodeCiphertextControlBody(frame.payload);
    } on AppFailure {
      return;
    }

    final address =
        SignalProtocolAddress(frame.source, kSenderKeyDeviceId);
    final Uint8List plaintext;
    try {
      plaintext = await _stack.cryptoService.decrypt(address, ciphertext);
    } catch (_) {
      // Any decrypt failure -- no session, wrong session, tampered
      // ciphertext -- is dropped here, exactly like
      // GroupMembershipService.handleWireFrame's own `groupUnauthenticated`
      // path (E07-T03).
      return;
    }

    await acceptDistribution(frame.source, plaintext);
  }

  /// The receive half's business logic (task file §3/§5), separated from
  /// [handleWireFrame]'s decrypt step so it is directly testable against
  /// already-decrypted bytes and an already-verified [sourceDeviceId] —
  /// mirrors `GroupMembershipService.handleControlFrame`'s own separation
  /// (E07-T03).
  ///
  /// [sourceDeviceId] MUST be the address of the Signal session [plaintext]
  /// decrypted under (task file §5) — never `RelayPacketFrame.source`
  /// directly from an unauthenticated frame. A malformed envelope, or a
  /// `SenderKeyDistributionMessage` libsignal itself cannot parse, is
  /// dropped silently rather than thrown -- this method never throws to the
  /// pipeline.
  Future<void> acceptDistribution(
    String sourceDeviceId,
    Uint8List plaintext,
  ) async {
    final _KeyDistributionEnvelope envelope;
    try {
      envelope = _KeyDistributionEnvelope.deserialize(plaintext);
    } catch (_) {
      return;
    }

    final name = senderKeyNameFor(
      groupId: envelope.groupId,
      epoch: envelope.epoch,
      senderDeviceId: sourceDeviceId,
    );

    try {
      final wrapper = SenderKeyDistributionMessageWrapper.fromSerialized(
        envelope.distributionMessageBytes,
      );
      await _sessionBuilder.process(name, wrapper);
    } catch (_) {
      // A distribution message this device cannot parse or apply is a
      // dropped update, never a crash of the receive pipeline (mirrors
      // every other control handler's own resilience discipline).
    }
  }

  // --- Group message encrypt/decrypt (the E07-T06 surface) ---------------

  /// Encrypts [plaintext] under this device's own chain for
  /// `(groupId, epoch)` — a thin `GroupCipher.encrypt` wrapper (task file
  /// §3). Throws `AppFailure('group.no_chain')` when this device has no
  /// chain for the epoch, translated from the library's own
  /// `NoSessionException` rather than left as a library exception a caller
  /// has to know to catch by name (task file §6).
  Future<Uint8List> encryptForGroup({
    required String groupId,
    required int epoch,
    required Uint8List plaintext,
  }) async {
    final name = senderKeyNameFor(
      groupId: groupId,
      epoch: epoch,
      senderDeviceId: _stack.selfDeviceId,
    );
    final cipher = GroupCipher(_senderKeyStore, name);
    try {
      return await cipher.encrypt(plaintext);
    } on NoSessionException {
      throw const AppFailure('group.no_chain');
    }
  }

  /// Decrypts [bytes] against [senderDeviceId]'s chain for
  /// `(groupId, epoch)` — a thin `GroupCipher.decrypt` wrapper (task file
  /// §3). Throws `AppFailure('group.no_chain')` when no chain for that
  /// sender/epoch is held (task file §5) — the `FR-GROUP-006` case for a
  /// message predating this device's membership, or a message from a
  /// different epoch/group than this device holds a chain for
  /// (`EARS-GROUP-14`) — and it fails LOUDLY, never silently returning
  /// empty bytes.
  Future<Uint8List> decryptFromGroup({
    required String groupId,
    required int epoch,
    required String senderDeviceId,
    required Uint8List bytes,
  }) async {
    final name = senderKeyNameFor(
      groupId: groupId,
      epoch: epoch,
      senderDeviceId: senderDeviceId,
    );
    final cipher = GroupCipher(_senderKeyStore, name);
    try {
      return await cipher.decrypt(bytes);
    } on NoSessionException {
      throw const AppFailure('group.no_chain');
    }
  }

  // --- Rotation primitive (E07-T05 calls this; provided + tested here) ---

  /// Deletes every `group_sender_keys` row for [groupId] with
  /// `membershipEpoch < belowEpoch`. Returns rows deleted (task file §3/§5).
  /// `E07-T05`'s rotation primitive — nothing in THIS task calls it in
  /// response to an epoch change (task file §4: no epoch listener lives
  /// here).
  Future<int> discardChains({
    required String groupId,
    required int belowEpoch,
  }) {
    final db = _stack.db;
    return (db.delete(db.groupSenderKeys)
          ..where(
            (t) =>
                t.groupId.equals(groupId) &
                t.membershipEpoch.isSmallerThanValue(belowEpoch),
          ))
        .go();
  }
}
