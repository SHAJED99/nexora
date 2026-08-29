// core/messaging — the relay wire packet (E06-T02).
//
// Gives the mesh an actual wire packet: bytes a receiving/relaying device can
// read well enough to know who a packet is for and what kind of ciphertext
// is inside, without being able to read the payload (FR-ROUTE-003/004).
//
// Layout, big-endian, deliberately matching `MessageEnvelope`'s existing
// framing idiom (`lib/features/messaging/domain/message_envelope.dart`) —
// length-prefixed fields, an explicit format-version byte checked first, and
// every length prefix validated against the *remaining* buffer before it is
// used to slice (the E05-B01 discipline: length-prefix parsing is where wire
// codecs get CVEs):
//
//   [u8  frameVersion=1]
//   [u8  payloadType]                          // PayloadType's integer tag
//   [u32 packetIdLen][packetId bytes]           // RelayEngine's packet id
//   [u32 destinationLen][destination bytes]     // final destination device id
//   [u32 sourceLen][source bytes]               // originating device id
//   [u8  priority]
//   [u64 createdAtMs][u64 expiresAtMs]
//   [u32 payloadLen][payload bytes]             // OPAQUE — never inspected
//
// This frame nests OUTSIDE a serialized `MessageEnvelope`: `payload` here is
// the ciphertext of a serialized `MessageEnvelope`. The two framings are
// never merged (E06-T02.md §4) — this one is relay-readable, the inner one
// must not be, and merging them would blur that boundary.
//
// This file does NOT send, receive, forward, schedule or store anything —
// pure codec, no I/O, no `AppDatabase` access (E06-T02.md §4). It does NOT
// add a MAC/signature/header-integrity check — a relay can rewrite the
// clear header today; see OQ-E06-T02-1 in the task file for why that is a
// disclosed, non-blocking bound for v1 rather than a silent omission.
import 'dart:convert';
import 'dart:typed_data';

/// Current, and so far only, frame layout version. Bump this — and add a
/// new `deserialize` branch, never silently reinterpret the old one — if the
/// layout ever changes incompatibly.
const int relayFrameVersion = 1;

/// The kind of ciphertext (or non-ciphertext control body) `payload` holds.
/// Serialized as its explicit integer [tag] — never Dart's enum index — so
/// the wire value survives reordering this declaration and matches
/// `CiphertextMessage.getType()`'s own tag space only where [CiphertextCodec]
/// explicitly maps it (the two spaces are NOT the same numbers by
/// coincidence; see that file).
///
/// `control` is reserved for the non-message envelopes later tasks add
/// (prekey bundles in T07, acks in T08) — this task only declares the tag,
/// it defines no control body (E06-T02.md §3/§4).
enum PayloadType {
  preKeySignalMessage(1),
  signalMessage(2),
  control(3);

  const PayloadType(this.tag);

  /// The byte written to (and read from) the wire — never this enum's
  /// declaration-order index.
  final int tag;

  /// Reverse lookup by wire tag. Throws [FormatException] naming the
  /// unrecognised value on an unknown tag — never a heuristic guess.
  static PayloadType fromTag(int tag) {
    for (final type in PayloadType.values) {
      if (type.tag == tag) return type;
    }
    throw FormatException(
      'RelayPacketFrame: unknown payloadType tag $tag',
    );
  }
}

/// The relay-readable wire frame (§ above). Every field except [payload] is
/// metadata a relay is allowed to see (FR-ROUTE-004); [payload] is opaque
/// ciphertext a relay must never inspect, log, or length-validate against
/// anything content-derived.
class RelayPacketFrame {
  const RelayPacketFrame({
    required this.payloadType,
    required this.packetId,
    required this.destination,
    required this.source,
    required this.priority,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.payload,
  });

  final PayloadType payloadType;

  /// `RelayEngine`'s own packet id (FR-ROUTE-004).
  final String packetId;

  /// Final destination device id.
  final String destination;

  /// Originating device id.
  final String source;

  /// 0-255 — a relay reads this to order its forward queue
  /// (`RelayEngine.processQueue`'s own priority-then-age ordering).
  final int priority;

  final int createdAtMs;
  final int expiresAtMs;

  /// OPAQUE ciphertext bytes. Never inspected, logged, or length-validated
  /// against anything content-derived by this class or any of its callers.
  final Uint8List payload;

  /// `frameVersion(1) + payloadType(1) + priority(1) + createdAtMs(8) +
  /// expiresAtMs(8)` — every fixed-width field that is not itself a
  /// length-prefixed variable one.
  static const int _fixedScalarBytes = 1 + 1 + 1 + 8 + 8;

  /// Encodes this frame into the wire layout documented above.
  Uint8List serialize() {
    final packetIdBytes = Uint8List.fromList(utf8.encode(packetId));
    final destinationBytes = Uint8List.fromList(utf8.encode(destination));
    final sourceBytes = Uint8List.fromList(utf8.encode(source));

    final totalLength = _fixedScalarBytes +
        4 + packetIdBytes.length +
        4 + destinationBytes.length +
        4 + sourceBytes.length +
        4 + payload.length;

    final buffer = ByteData(totalLength);
    var offset = 0;

    buffer.setUint8(offset, relayFrameVersion);
    offset += 1;

    buffer.setUint8(offset, payloadType.tag);
    offset += 1;

    offset = _putLengthPrefixed(buffer, offset, packetIdBytes);
    offset = _putLengthPrefixed(buffer, offset, destinationBytes);
    offset = _putLengthPrefixed(buffer, offset, sourceBytes);

    buffer.setUint8(offset, priority);
    offset += 1;

    buffer.setUint64(offset, createdAtMs);
    offset += 8;

    buffer.setUint64(offset, expiresAtMs);
    offset += 8;

    offset = _putLengthPrefixed(buffer, offset, payload);

    return buffer.buffer.asUint8List();
  }

  static int _putLengthPrefixed(ByteData buffer, int offset, Uint8List bytes) {
    buffer.setUint32(offset, bytes.length);
    offset += 4;
    final target = buffer.buffer.asUint8List();
    target.setRange(offset, offset + bytes.length, bytes);
    return offset + bytes.length;
  }

  /// Decodes bytes produced by [serialize]. Every `u32` length prefix is
  /// validated against the *remaining* buffer — never trusted blindly and
  /// used to slice — before it is used (the E05-B01 discipline, matched here
  /// rather than re-derived; see `message_envelope.dart:117` for the
  /// reviewed original). Throws [FormatException] naming the failing field
  /// on: an empty buffer, a truncated header, an unknown [relayFrameVersion],
  /// an unknown [PayloadType] tag, or any length prefix (including
  /// `0xFFFFFFFF`) that would read past the end of the buffer. Never returns
  /// a partially-parsed frame.
  static RelayPacketFrame deserialize(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException(
        'RelayPacketFrame: empty buffer, missing frameVersion byte',
      );
    }
    final view = ByteData.sublistView(bytes);
    var offset = 0;

    final version = view.getUint8(offset);
    if (version != relayFrameVersion) {
      throw FormatException(
        'RelayPacketFrame: unknown frameVersion '
        '(got $version, expected $relayFrameVersion)',
      );
    }
    offset += 1;

    _requireRemaining(bytes, offset, 1, 'payloadType');
    final payloadType = PayloadType.fromTag(view.getUint8(offset));
    offset += 1;

    final packetIdRead =
        _readLengthPrefixedString(view, bytes, offset, 'packetId');
    final packetId = packetIdRead.$1;
    offset = packetIdRead.$2;

    final destinationRead =
        _readLengthPrefixedString(view, bytes, offset, 'destination');
    final destination = destinationRead.$1;
    offset = destinationRead.$2;

    final sourceRead =
        _readLengthPrefixedString(view, bytes, offset, 'source');
    final source = sourceRead.$1;
    offset = sourceRead.$2;

    _requireRemaining(bytes, offset, 1, 'priority');
    final priority = view.getUint8(offset);
    offset += 1;

    _requireRemaining(bytes, offset, 8, 'createdAtMs');
    final createdAtMs = view.getUint64(offset);
    offset += 8;

    _requireRemaining(bytes, offset, 8, 'expiresAtMs');
    final expiresAtMs = view.getUint64(offset);
    offset += 8;

    final payloadRead =
        _readLengthPrefixedBytes(view, bytes, offset, 'payload');
    final payload = payloadRead.$1;
    offset = payloadRead.$2;

    // Exact-length re-affirmation (matching `MessageEnvelope`'s discipline):
    // every field above is either fixed-width or explicitly length-prefixed
    // and bounds-checked, so a header+payload that parses at all must
    // account for the whole buffer exactly. A future field added without
    // updating every bounds check above fails loudly here instead of
    // silently under- or over-reading.
    if (offset != bytes.length) {
      throw const FormatException(
        'RelayPacketFrame: declared fields do not account for the buffer '
        'exactly (trailing or missing bytes)',
      );
    }

    return RelayPacketFrame(
      payloadType: payloadType,
      packetId: packetId,
      destination: destination,
      source: source,
      priority: priority,
      createdAtMs: createdAtMs,
      expiresAtMs: expiresAtMs,
      payload: payload,
    );
  }

  /// Throws [FormatException] naming [field] if fewer than [needed] bytes
  /// remain at [offset]. The one guard every length-prefixed or fixed-width
  /// read below goes through before touching the buffer.
  static void _requireRemaining(
    Uint8List bytes,
    int offset,
    int needed,
    String field,
  ) {
    // `offset + needed` is computed as an int; on 32-bit-length buffers this
    // cannot itself overflow Dart's 64-bit ints, so a `0xFFFFFFFF` length
    // prefix compares correctly against `bytes.length` here rather than
    // wrapping around to a small, falsely-passing value.
    if (bytes.length < offset + needed) {
      throw FormatException(
        'RelayPacketFrame: truncated, missing $field '
        '(need $needed byte(s) at offset $offset, only '
        '${bytes.length - offset} remain)',
      );
    }
  }

  static (String, int) _readLengthPrefixedString(
    ByteData view,
    Uint8List bytes,
    int offset,
    String field,
  ) {
    final (raw, next) =
        _readLengthPrefixedBytes(view, bytes, offset, field);
    return (utf8.decode(raw), next);
  }

  static (Uint8List, int) _readLengthPrefixedBytes(
    ByteData view,
    Uint8List bytes,
    int offset,
    String field,
  ) {
    _requireRemaining(bytes, offset, 4, '${field}Length');
    final length = view.getUint32(offset);
    offset += 4;
    _requireRemaining(bytes, offset, length, field);
    final value = Uint8List.fromList(bytes.sublist(offset, offset + length));
    offset += length;
    return (value, offset);
  }
}
