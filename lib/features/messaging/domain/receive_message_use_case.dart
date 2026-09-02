// features/messaging/domain — incoming message handling (E05-T03).
//
// The receiving-side mirror of T02 (E05-T02, outgoing): given a sender's
// device address and a ciphertext packet, decrypt it (E03's `CryptoService`),
// recover the envelope the sending side serializes INTO the plaintext before
// encrypting (`SendMessageUseCase`, `message_envelope.dart` — as of E05-B01;
// before that fix this comment's claim was FALSE, see E05-B01.md), dedup by
// the envelope's client-generated `id` (FR-MSG-003/EARS-MSG-2), and persist
// using the envelope's `sequenceNumber` for logical ordering rather than
// arrival order (FR-MSG-004/EARS-MSG-3) — never re-deriving order from
// wall-clock time or arrival order (T01's own note: clock drift across
// devices).
//
// Pure use case (task file §4): no transport wiring (no subscription to
// `TransportService.incomingData` — that's a scheduler/coordinator concern,
// most likely E06's), no Delivered/Stored/Read transitions (UI/application
// events, also later), no group envelopes/Sender-Keys (E07), no re-deriving
// E04's routing.
//
// KNOWN REMAINING GAP (E05-B01, not closed by this bug fix — see its
// "Related gap in the same seam" section and OQ-E05-B01-1): `call`'s
// `ciphertext` parameter is typed `CiphertextMessage`, but E04's
// `RelayEngine`/transport only ever carries raw `Uint8List` wire bytes
// (`send_message_use_case.dart` hands `RelayEngine.enqueue` a `Uint8List`,
// never a `CiphertextMessage`). Nothing in this codebase re-types relayed
// wire bytes back into a `CiphertextMessage`
// (`PreKeySignalMessage`/`SignalMessage` reconstruction from raw bytes is
// never called anywhere in `lib/`), and this task's own contract (§4) is
// explicit that transport wiring is out of scope here. Whoever first wires a
// live transport receive path (most likely E06) must build that bridge --
// `libsignal_protocol_dart` (0.8.2) exposes `PreKeySignalMessage(bytes)` and
// `SignalMessage.fromSerialized(bytes)` constructors but no single
// type-discriminating "reconstruct whichever one this is" entry point, so
// the bridge needs either an out-of-band type tag (e.g. carried by whatever
// transport envelope wraps the wire bytes) or a try-PreKey-then-SignalMessage
// fallback -- deliberately not built here without a real caller or a test
// that would exercise it.
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../../../core/crypto/crypto_stub.dart';
import '../../../core/persistence/database.dart';
import 'delivery_state_machine.dart';
import 'message.dart';
import 'message_envelope.dart';

/// Re-exported so existing imports of `MessageEnvelope` from this file (this
/// task's own test suite included) keep working unchanged now that the class
/// itself lives in `message_envelope.dart`, shared with `SendMessageUseCase`
/// (E05-B01).
export 'message_envelope.dart';

/// Signal device-id half of every [SignalProtocolAddress] this app mints,
/// per the existing single-device-per-identity convention already used by
/// `IdentityService` and every Signal test in this repo (E03-T02's own
/// deviation note: `SignalProtocolAddress(name, 1)`). [senderDeviceId] here
/// supplies the `name` half; when multi-device support lands, this becomes a
/// looked-up parameter rather than a constant — a localized change, not a
/// rework (same reasoning E03-T02 already recorded for its own use of `1`).
const int _localSignalDeviceId = 1;

/// Decrypt, dedup, and correctly-ordered persistence of one incoming packet
/// (task file §3/§5). The only public entry point is [call]; its signature
/// is the task's binding contract:
/// `ReceiveMessageUseCase.call(senderDeviceId, ciphertext) -> Future<Message?>`.
class ReceiveMessageUseCase {
  /// [database] is the shared `AppDatabase` (T01's `messages` table lives
  /// there). [decrypt] defaults to `CryptoService.instance.decrypt` — the
  /// real E03 Double Ratchet decrypt step — but is an injectable seam so
  /// this task's own tests can exercise the dedup/ordering/persistence logic
  /// deterministically without needing a live two-party Signal session for
  /// every case (the round-trip/real-decrypt path is still covered
  /// separately, see the test file). Not part of the task's `call` contract,
  /// which is unchanged.
  ReceiveMessageUseCase({
    required AppDatabase database,
    Future<Uint8List> Function(SignalProtocolAddress, CiphertextMessage)?
        decrypt,
  })  : _db = database,
        _decrypt = decrypt ?? CryptoService.instance.decrypt;

  final AppDatabase _db;
  final Future<Uint8List> Function(SignalProtocolAddress, CiphertextMessage)
      _decrypt;

  /// Decrypts [ciphertext] as having arrived from [senderDeviceId],
  /// recovers the envelope, and either drops it as a duplicate (returns
  /// `null`) or persists it as a new `Accepted` message and returns it.
  ///
  /// The "does this id already exist" check and the insert are one atomic
  /// transaction (task file §6): two near-simultaneous calls for the same
  /// duplicate packet must not both observe "not found" before either
  /// writes — this project has hit exactly this race-class before
  /// (L-backend-003's lineage: a counter/uniqueness invariant checked
  /// read-then-write across two concurrent calls). Drift's `transaction()`
  /// serializes concurrent callback bodies against the same connection
  /// (the same pattern `DriftSignalProtocolStore.allocateOneTimePreKeyIds`/
  /// `issueOneTimePreKey` already rely on), so the second of two racing
  /// calls always observes the first call's write before running its own
  /// select.
  Future<Message?> call(
    String senderDeviceId,
    CiphertextMessage ciphertext,
  ) async {
    final address = SignalProtocolAddress(senderDeviceId, _localSignalDeviceId);
    final plaintext = await _decrypt(address, ciphertext);
    final envelope = MessageEnvelope.deserialize(plaintext);

    return _db.transaction(() async {
      final existing = await (_db.select(_db.messages)
            ..where((t) => t.id.equals(envelope.id)))
          .getSingleOrNull();
      if (existing != null) {
        // Duplicate packet (task file §3.3/EARS-MSG-2): no second row, no
        // second delivery-state transition.
        return null;
      }

      // DISCLOSED LIMITATION (E08-B04, resolved 2026-09-03, option 3 —
      // "keep DateTime.now(), disclose only"): this dedup check is "does a
      // row with this id exist in `messages`" — sound only as long as
      // nothing ever deletes a message. `RetentionExecutor.deleteMessageItems`
      // (a manual retention mode) does delete rows here, and records nothing
      // this check consults. So once a message has been retention-deleted,
      // nothing remembers that it ever existed: if a copy is still
      // circulating in the mesh (held by a peer or a not-yet-reclaimed relay
      // payload) and gets re-delivered, `existing` above comes back null and
      // the packet is treated as brand new, not as the duplicate it actually
      // is. It is re-inserted below with `createdAt: DateTime.now()`, i.e.
      // today's date, not whatever date it originally carried — so it can
      // sort back into view and is immune to the same age policy that
      // removed it, for another full retention window.
      //
      // This is a known, accepted limitation, not a bug to fix here: the
      // alternative is tombstones (recording deleted ids, or a `deleted`
      // stub row, so this check can consult them) which is a schema
      // migration and trades storage back for the space the deletion just
      // reclaimed — a decision this storage epic has deliberately deferred,
      // not one a bug fix may make unilaterally. An earlier attempt at this
      // task tried instead to preserve "the envelope's own creation
      // timestamp" on re-insert, but `MessageEnvelope`'s wire format has no
      // timestamp field at all (see `message_envelope.dart`); adding one
      // would be a protocol change, not a bug fix, so the human chose to
      // keep `DateTime.now()` exactly as today's code does and disclose the
      // limitation instead. See `epics/E08-local-storage/tasks/E08-B04.md`
      // (`Q-E08-B04-1`) for the full history.
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      final ciphertextBytes = Uint8List.fromList(ciphertext.serialize());

      await _db.into(_db.messages).insert(
            MessagesCompanion.insert(
              id: envelope.id,
              conversationId: envelope.conversationId,
              senderDeviceId: senderDeviceId,
              sequenceNumber: envelope.sequenceNumber,
              ciphertext: ciphertextBytes,
              createdAt: createdAt,
              // Received and decrypted successfully — the receiving-side
              // equivalent of T02's `Sent` (task file §3.4).
              deliveryState: DeliveryState.accepted.name,
            ),
          );

      return Message(
        id: envelope.id,
        conversationId: envelope.conversationId,
        senderDeviceId: senderDeviceId,
        sequenceNumber: envelope.sequenceNumber,
        ciphertext: ciphertextBytes,
        createdAt: createdAt,
        deliveryState: DeliveryState.accepted,
      );
    });
  }
}
