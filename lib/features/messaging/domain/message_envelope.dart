// features/messaging/domain — the wire envelope shared by the sending side
// (`SendMessageUseCase`, E05-T02) and the receiving side
// (`ReceiveMessageUseCase`, E05-T03).
//
// Moved here by E05-B01. Originally this class lived only inside
// `receive_message_use_case.dart`, with a comment there claiming the sending
// side already serialized one of these into its plaintext before
// encrypting -- it did not; `SendMessageUseCase.call` encrypted the caller's
// raw bytes directly, so nothing T02 sent could ever be deserialized by
// T03's `ReceiveMessageUseCase` (either `deserialize` threw, or worse,
// silently mis-parsed a raw payload into a garbage row -- see E05-B01.md for
// the full defect writeup and repro). Giving the wire format exactly one
// definition with two importers, instead of one user and a false comment in
// the other, is what this move actually fixes.
import 'dart:convert';
import 'dart:typed_data';

/// A single-byte format tag prefixed to every serialized envelope (E05-B01
/// hardening). Its only job is to make a non-envelope payload -- raw bytes
/// that happen to start with small, plausible-looking length-prefix values --
/// fail LOUDLY instead of silently mis-parsing into a garbage `id`/
/// `conversationId`/`sequenceNumber`. That silent mis-parse was the worse of
/// E05-B01's two failure modes: a garbage `id` can collide with an existing
/// row's primary key and cause a *legitimate* message to be silently dropped
/// as a "duplicate". Bump this value if the wire format ever changes
/// incompatibly.
const int envelopeFormatVersion = 0xE5;

/// The minimal wire envelope both `SendMessageUseCase` and
/// `ReceiveMessageUseCase` share: NOT raw ciphertext bytes -- E03's
/// `CryptoService` only encrypts/decrypts opaque plaintext, it never defines
/// message structure, so the sending side serializes one of these INTO the
/// plaintext before encrypting, and the receiving side deserializes it AFTER
/// decrypting. Encryption still covers the whole envelope: a relay never
/// sees `conversationId`/`sequenceNumber` (FR-ROUTE-003 still holds) -- only
/// the two encryption endpoints ever see the envelope's plaintext fields
/// (E05-T03.md §3/§5).
///
/// Fixed-width/length-prefixed binary encoding, deliberately not a general
/// serialization framework: `[u8 formatVersion][u32 idLen][idBytes]
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
  /// sender at compose time (T02) -- this is the field that lets the
  /// receiving side persist messages in correct logical order regardless of
  /// the order packets physically arrived in (FR-MSG-004/EARS-MSG-3).
  final int sequenceNumber;

  final Uint8List payload;

  /// `formatVersion(1) + idLen(4) + conversationIdLen(4) + sequenceNumber(8)`.
  static const int _headerFixedBytes = 1 + 4 + 4 + 8;

  /// Encodes this envelope into the bytes the sending side hands to
  /// `CryptoService.encrypt` as plaintext. Exposed here (one definition, two
  /// users) so `SendMessageUseCase` and `ReceiveMessageUseCase` -- and every
  /// test on either side -- share one encoding rather than two independently
  /// guessed ones (E05-B01's root cause).
  Uint8List serialize() {
    final idBytes = Uint8List.fromList(utf8.encode(id));
    final conversationIdBytes =
        Uint8List.fromList(utf8.encode(conversationId));

    final totalLength = _headerFixedBytes +
        idBytes.length +
        conversationIdBytes.length +
        payload.length;
    final buffer = ByteData(totalLength);
    var offset = 0;

    buffer.setUint8(offset, envelopeFormatVersion);
    offset += 1;

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

  /// Decodes bytes produced by [serialize]. Throws [FormatException] if:
  /// - `bytes` is shorter than the fixed-width header requires (a corrupt or
  ///   truncated envelope must fail loudly, not silently return a wrong
  ///   field), or
  /// - the leading format-version byte doesn't match [envelopeFormatVersion]
  ///   -- this is the E05-B01 hardening: a raw, non-envelope payload (e.g. a
  ///   length-prefixed blob, a protobuf, an image chunk -- anything that
  ///   isn't one of these envelopes) is rejected up front instead of being
  ///   silently mis-parsed into a garbage `id`/`conversationId`/
  ///   `sequenceNumber` that could collide with a real message's dedup key.
  static MessageEnvelope deserialize(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException(
        'MessageEnvelope: empty buffer, missing format-version byte',
      );
    }
    final view = ByteData.sublistView(bytes);
    var offset = 0;

    final version = view.getUint8(offset);
    if (version != envelopeFormatVersion) {
      throw FormatException(
        'MessageEnvelope: not an envelope (leading format-version byte was '
        '0x${version.toRadixString(16)}, expected '
        '0x${envelopeFormatVersion.toRadixString(16)}) -- refusing to parse '
        'a payload that is very likely not one of these envelopes, rather '
        'than risk a silent mis-parse into a garbage row (E05-B01)',
      );
    }
    offset += 1;

    if (bytes.length < offset + 4) {
      throw const FormatException(
        'MessageEnvelope: truncated, missing id-length header',
      );
    }
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

    // Exact-length re-affirmation (E05-B01): every check above already
    // guarantees `offset <= bytes.length` for a well-formed envelope --
    // there is no field after the header whose length is anything other
    // than "the rest of the buffer" (the payload), so a header that parses
    // at all necessarily accounts for the whole buffer exactly, with
    // nothing left unaccounted for. Kept as an explicit, real (not `assert`,
    // which release builds strip) check so a future header field added
    // without updating every bounds check above fails loudly here instead
    // of silently under-reading.
    if (offset > bytes.length) {
      throw const FormatException(
        'MessageEnvelope: declared header fields do not fit the buffer',
      );
    }

    final payload = Uint8List.fromList(bytes.sublist(offset));

    return MessageEnvelope(
      id: id,
      conversationId: conversationId,
      sequenceNumber: sequenceNumber,
      payload: payload,
    );
  }
}
