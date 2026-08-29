// features/messaging/domain — incoming message handling (E05-T03).
//
// The receiving-side mirror of T02 (E05-T02, outgoing): given a sender's
// device address and a ciphertext packet, decrypt it (E03's `CryptoService`),
// recover the envelope T02's sending side serialized INTO the plaintext
// before encrypting, dedup by the envelope's client-generated `id`
// (FR-MSG-003/EARS-MSG-2), and persist using the envelope's
// `sequenceNumber` for logical ordering rather than arrival order
// (FR-MSG-004/EARS-MSG-3) — never re-deriving order from wall-clock time or
// arrival order (T01's own note: clock drift across devices).
//
// Pure use case (task file §4): no transport wiring (no subscription to
// `TransportService.incomingData` — that's a scheduler/coordinator concern,
// most likely E06's), no Delivered/Stored/Read transitions (UI/application
// events, also later), no group envelopes/Sender-Keys (E07), no re-deriving
// E04's routing.
import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../../../core/crypto/crypto_stub.dart';
import '../../../core/persistence/database.dart';
import 'delivery_state_machine.dart';
import 'message.dart';

/// Signal device-id half of every [SignalProtocolAddress] this app mints,
/// per the existing single-device-per-identity convention already used by
/// `IdentityService` and every Signal test in this repo (E03-T02's own
/// deviation note: `SignalProtocolAddress(name, 1)`). [senderDeviceId] here
/// supplies the `name` half; when multi-device support lands, this becomes a
/// looked-up parameter rather than a constant — a localized change, not a
/// rework (same reasoning E03-T02 already recorded for its own use of `1`).
const int _localSignalDeviceId = 1;

/// The minimal wire envelope this task defines (task file §3/§5): NOT raw
/// ciphertext bytes — decrypt only recovers opaque plaintext (E03's
/// `CryptoService` never defines message structure), so the sending side
/// (T02) serializes this envelope INTO the plaintext before encrypting, and
/// this task deserializes it AFTER decrypting. Encryption still covers the
/// whole envelope: a relay never sees `conversationId`/`sequenceNumber`
/// (FR-ROUTE-003 still holds) — only the two encryption endpoints ever see
/// the envelope's plaintext fields.
///
/// Fixed-width/length-prefixed binary encoding, deliberately not a general
/// serialization framework (task file §5): `[u32 idLen][idBytes]
/// [u32 conversationIdLen][conversationIdBytes][u64 sequenceNumber]
/// [payload bytes: remainder]`, all integers big-endian.
class MessageEnvelope {
  const MessageEnvelope({
    required this.id,
    required this.conversationId,
    required this.sequenceNumber,
    required this.payload,
  });

  final String id;
  final String conversationId;

  /// Monotonic per `(conversationId, senderDeviceId)`, assigned by the
  /// sender at compose time (T02) — this is the field that lets this task
  /// persist messages in correct logical order regardless of the order
  /// packets physically arrived in (FR-MSG-004/EARS-MSG-3).
  final int sequenceNumber;

  final Uint8List payload;

  /// Encodes this envelope into the bytes T02 hands to
  /// `CryptoService.encrypt` as plaintext. Exposed here (not just on the
  /// sending side) so this task's own round-trip test
  /// (`test_envelope_roundtrip_preserves_all_fields`) and any future T02
  /// implementation share one definition of the wire format rather than two
  /// independently-guessed ones.
  Uint8List serialize() {
    final idBytes = Uint8List.fromList(utf8.encode(id));
    final conversationIdBytes = Uint8List.fromList(utf8.encode(conversationId));

    final totalLength =
        4 + idBytes.length + 4 + conversationIdBytes.length + 8 + payload.length;
    final buffer = ByteData(totalLength);
    var offset = 0;

    buffer.setUint32(offset, idBytes.length);
    offset += 4;
    for (final byte in idBytes) {
      buffer.setUint8(offset, byte);
      offset += 1;
    }

    buffer.setUint32(offset, conversationIdBytes.length);
    offset += 4;
    for (final byte in conversationIdBytes) {
      buffer.setUint8(offset, byte);
      offset += 1;
    }

    buffer.setUint64(offset, sequenceNumber);
    offset += 8;

    final result = buffer.buffer.asUint8List();
    result.setRange(offset, offset + payload.length, payload);
    return result;
  }

  /// Decodes bytes produced by [serialize]. Throws [FormatException] if
  /// `bytes` is shorter than the fixed-width header requires — a corrupt or
  /// truncated envelope must fail loudly, not silently return a wrong field.
  static MessageEnvelope deserialize(Uint8List bytes) {
    if (bytes.length < 4) {
      throw const FormatException(
        'MessageEnvelope: truncated, missing id-length header',
      );
    }
    final view = ByteData.sublistView(bytes);
    var offset = 0;

    final idLength = view.getUint32(offset);
    offset += 4;
    if (bytes.length < offset + idLength + 4) {
      throw const FormatException(
        'MessageEnvelope: truncated, missing id bytes or '
        'conversationId-length header',
      );
    }
    final id = utf8.decode(bytes.sublist(offset, offset + idLength));
    offset += idLength;

    final conversationIdLength = view.getUint32(offset);
    offset += 4;
    if (bytes.length < offset + conversationIdLength + 8) {
      throw const FormatException(
        'MessageEnvelope: truncated, missing conversationId bytes or '
        'sequenceNumber',
      );
    }
    final conversationId = utf8.decode(
      bytes.sublist(offset, offset + conversationIdLength),
    );
    offset += conversationIdLength;

    final sequenceNumber = view.getUint64(offset);
    offset += 8;

    final payload = Uint8List.fromList(bytes.sublist(offset));

    return MessageEnvelope(
      id: id,
      conversationId: conversationId,
      sequenceNumber: sequenceNumber,
      payload: payload,
    );
  }
}

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
