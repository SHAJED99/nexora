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

/// The **v2** format tag (E05-T06, ADR-0009). An envelope led by this byte
/// carries one extra `u8 kind` immediately after it; every subsequent field
/// keeps its order and shifts by exactly one.
///
/// Note the asymmetry with `GroupMessageEnvelope`, which is pre-existing and
/// deliberate: this field is a **magic sentinel**, not a counter (see
/// [envelopeFormatVersion]'s own doc -- its job is to make a non-envelope
/// payload fail loudly), so "v2" here is a second accepted sentinel rather
/// than `0xE5 + 1` meaning anything arithmetically. `GroupMessageEnvelope`
/// does use a real monotonic version, so its v2 is plain `2`.
const int envelopeFormatVersionV2 = 0xE6;

/// What a message's payload actually *contains* (ADR-0009).
///
/// **Why this lives inside the encrypted envelope and nowhere else.** The
/// frame-level `PayloadType` is relay-visible metadata by design
/// (`relay_packet_frame.dart`: "Every field except `payload` is metadata a
/// relay is allowed to see (`FR-ROUTE-004`)"), and the control-kind
/// discriminator is read *before* any decryption --
/// `inbound_pipeline.dart` does `final int controlKind = frame.payload[0];`
/// unconditionally, ahead of dispatch. Any byte in a pre-decrypt position is
/// visible to every relay that forwards the packet. Putting "this is a voice
/// note" in either place would disclose content type on the wire, a direct
/// regression against FR-ROUTE-003/FR-ROUTE-004. Carried here, inside the
/// plaintext the two endpoints encrypt as a unit, a relay observes nothing
/// new at all.
enum MessageContentKind {
  /// Wire value `1`. Defined so the decoder is total, but **never emitted**
  /// as a v2 kind byte: a text message is always a v1 envelope, byte for
  /// byte identical to what this app has always sent (ADR-0009's emission
  /// rule, and the reason the working path never executes new code).
  text(1),
  image(2),
  file(3),
  voice(4),
  location(5);

  const MessageContentKind(this.wireValue);

  final int wireValue;

  /// The kind for [wireValue], or `null` if this build does not recognise
  /// it.
  ///
  /// `null` is a real, carried outcome -- **not** an error and **not** an
  /// invitation to guess. ADR-0009 is explicit: an unknown kind is neither
  /// guessed nor silently dropped, and nothing infers content from payload
  /// shape, filename, magic bytes or MIME sniffing. Silently resolving an
  /// unrecognised byte to [text] would re-create exactly the silent
  /// mis-parse class `E05-B01` already cost this project once.
  static MessageContentKind? fromWire(int wireValue) {
    for (final kind in MessageContentKind.values) {
      if (kind.wireValue == wireValue) {
        return kind;
      }
    }
    return null;
  }
}

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
    this.kind = MessageContentKind.text,
    this.unknownKindWireValue,
  });

  final String id;
  final String conversationId;

  /// What [payload] contains (E05-T06, ADR-0009). `null` means this build
  /// does not recognise the kind byte a v2 envelope carried -- see
  /// [unknownKindWireValue].
  ///
  /// Defaults to [MessageContentKind.text], which is also what every v1
  /// envelope decodes to unconditionally.
  final MessageContentKind? kind;

  /// The raw kind byte, preserved **only** when it was not recognised
  /// (i.e. exactly when [kind] is `null`); `null` otherwise.
  ///
  /// Kept so an unknown kind is neither guessed nor silently dropped: the
  /// message still parses, still persists, and a caller can report honestly
  /// that it cannot render *this specific* kind. What that caller should
  /// say is an open Rule-2 product decision (`E05-T06` §9) and no string is
  /// invented for it here.
  final int? unknownKindWireValue;

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

    // ADR-0009's emission rule. Text emits v1 -- byte-identical to what this
    // app has always sent, not merely compatible with it -- so the only path
    // that actually runs today never executes the v2 branch at all. v2 is
    // emitted ONLY for a non-text kind.
    //
    // An unknown kind (`kind == null`) cannot be re-emitted: this build does
    // not know what it means, and writing a byte for it would be inventing
    // one. Nothing in this codebase re-serializes a decoded envelope, so
    // this is unreachable today; it throws rather than silently degrading to
    // text, which is the failure mode ADR-0009 exists to prevent.
    if (kind == null) {
      throw StateError(
        'MessageEnvelope: refusing to serialize an unrecognised content kind '
        '(wire value ${unknownKindWireValue ?? "unknown"}) -- this build '
        'cannot know what it means, and guessing is exactly what ADR-0009 '
        'forbids',
      );
    }
    final emitV2 = kind != MessageContentKind.text;

    final totalLength = _headerFixedBytes +
        (emitV2 ? 1 : 0) +
        idBytes.length +
        conversationIdBytes.length +
        payload.length;
    final buffer = ByteData(totalLength);
    var offset = 0;

    if (emitV2) {
      buffer.setUint8(offset, envelopeFormatVersionV2);
      offset += 1;
      buffer.setUint8(offset, kind!.wireValue);
      offset += 1;
    } else {
      buffer.setUint8(offset, envelopeFormatVersion);
      offset += 1;
    }

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

    // Was a strict `!=` against the single sentinel; E05-T06 widens it to a
    // two-value known set (v1 `0xE5`, v2 `0xE6`). Everything else about the
    // E05-B01 hardening is unchanged -- any OTHER leading byte is still
    // rejected outright rather than risking a silent mis-parse.
    final version = view.getUint8(offset);
    if (version != envelopeFormatVersion &&
        version != envelopeFormatVersionV2) {
      throw FormatException(
        'MessageEnvelope: not an envelope (leading format-version byte was '
        '0x${version.toRadixString(16)}, expected '
        '0x${envelopeFormatVersion.toRadixString(16)} or '
        '0x${envelopeFormatVersionV2.toRadixString(16)}) -- refusing to '
        'parse a payload that is very likely not one of these envelopes, '
        'rather than risk a silent mis-parse into a garbage row (E05-B01)',
      );
    }
    offset += 1;

    // v1 means text, unconditionally (ADR-0009's decode rule) -- there is no
    // kind byte to read and none is inferred.
    var kind = MessageContentKind.text;
    int? unknownKindWireValue;
    if (version == envelopeFormatVersionV2) {
      if (bytes.length < offset + 1) {
        throw const FormatException(
          'MessageEnvelope: truncated, v2 envelope is missing its '
          'content-kind byte',
        );
      }
      final kindByte = view.getUint8(offset);
      offset += 1;
      final resolved = MessageContentKind.fromWire(kindByte);
      if (resolved == null) {
        // Neither guessed nor dropped: the envelope still parses and the
        // raw byte is carried out so the caller can be honest about what it
        // cannot render (ADR-0009).
        unknownKindWireValue = kindByte;
      } else {
        kind = resolved;
      }
    }

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
      kind: unknownKindWireValue == null ? kind : null,
      unknownKindWireValue: unknownKindWireValue,
    );
  }
}
