// core/messaging — the producer/consumer pair OQ-E05-B01-1 asked for
// (E06-T02).
//
// `libsignal_protocol_dart` 0.8.2 gives no type-discriminating reconstructor:
// a `PreKeySignalMessage` and a steady-state `SignalMessage` read the same
// version-bits byte, and the library relies on an out-of-band message-type
// tag it does not itself define (E05-B01's `OQ-E05-B01-1`). This file is
// where that tag lives, carried alongside the wire bytes in
// `RelayPacketFrame.payloadType` rather than guessed at with a
// try-PreKey-then-SignalMessage heuristic — E05-B01's reviewer named that
// heuristic the worse failure mode: a mis-parse there is silent, and a
// garbage id from a mis-parse can evict a real message through dedup.
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../crypto/crypto_failures.dart';
import 'relay_packet_frame.dart';

/// Encodes and decodes the two-way mapping between a `CiphertextMessage` and
/// the `(PayloadType, bytes)` pair a [RelayPacketFrame] actually carries.
///
/// Explicit tag dispatch only — no heuristic, no try-both. An unrecognised
/// tag or unparseable bytes throws loudly (§6's own risk note: silent
/// mis-parse is the worse failure this codec exists to avoid).
class CiphertextCodec {
  /// `message.getType()` (the library's own type tag —
  /// `CiphertextMessage.prekeyType`/`whisperType`, NOT the same integers as
  /// [PayloadType.tag] — mapped explicitly below, never assumed equal) and
  /// `message.serialize()`, paired for a [RelayPacketFrame]'s
  /// `payloadType`/`payload` fields.
  static (PayloadType, Uint8List) encode(CiphertextMessage message) {
    final PayloadType type;
    switch (message.getType()) {
      case CiphertextMessage.prekeyType:
        type = PayloadType.preKeySignalMessage;
      case CiphertextMessage.whisperType:
        type = PayloadType.signalMessage;
      default:
        throw ArgumentError(
          'CiphertextCodec.encode: unsupported CiphertextMessage.getType() '
          '${message.getType()} (${message.runtimeType})',
        );
    }
    return (type, message.serialize());
  }

  /// Reconstructs a `CiphertextMessage` from wire [bytes] tagged with
  /// [type]. Dispatches explicitly on [type] — never inspects [bytes] to
  /// guess.
  ///
  /// Throws [ArgumentError] if [type] is not a ciphertext tag (e.g.
  /// [PayloadType.control] — reserved for non-message envelopes this task
  /// does not define, see `relay_packet_frame.dart`). Throws
  /// [CryptoDecryptFailure] with reason
  /// [CryptoDecryptFailureReason.invalidMessage] if [bytes] cannot be parsed
  /// as the declared type (the library's own constructors throw
  /// `InvalidMessageException` — unexported, hence mapped here via
  /// [mapSignalException] rather than left to escape as an unnameable type).
  static CiphertextMessage decode(PayloadType type, Uint8List bytes) {
    switch (type) {
      case PayloadType.preKeySignalMessage:
        try {
          return PreKeySignalMessage(bytes);
        } catch (e) {
          throw mapSignalException(e);
        }
      case PayloadType.signalMessage:
        try {
          return SignalMessage.fromSerialized(bytes);
        } catch (e) {
          throw mapSignalException(e);
        }
      case PayloadType.control:
        throw ArgumentError(
          'CiphertextCodec.decode: ${type.name} is not a ciphertext tag',
        );
    }
  }
}
