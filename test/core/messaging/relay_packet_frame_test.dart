// Tests for RelayPacketFrame (E06-T02, EARS-COMM-3/4).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';

/// Builds a well-formed serialized frame, letting individual fields be
/// overridden — used both for the happy-path round-trip test and as the base
/// buffer the malformed-input matrix mutates byte-by-byte.
Uint8List _wellFormedFrame({
  int? frameVersionOverride,
  int? payloadTypeOverride,
}) {
  final frame = RelayPacketFrame(
    payloadType: PayloadType.signalMessage,
    packetId: 'packet-1',
    destination: 'device-B',
    source: 'device-A',
    priority: 5,
    createdAtMs: 1000,
    expiresAtMs: 2000,
    payload: Uint8List.fromList([1, 2, 3]),
  );
  final bytes = frame.serialize();
  if (frameVersionOverride != null) {
    bytes[0] = frameVersionOverride;
  }
  if (payloadTypeOverride != null) {
    bytes[1] = payloadTypeOverride;
  }
  return bytes;
}

void main() {
  group('test_EARS_COMM_3_frame_round_trips_every_header_field', () {
    test('non-ASCII ids, mid-range priority, small payload', () {
      final frame = RelayPacketFrame(
        payloadType: PayloadType.preKeySignalMessage,
        packetId: 'pkt-日本語-🎉',
        destination: 'device-Ω-dëst',
        source: 'device-Ω-sørc',
        priority: 5,
        createdAtMs: 1234567890,
        expiresAtMs: 9876543210,
        payload: Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      final bytes = frame.serialize();
      final decoded = RelayPacketFrame.deserialize(bytes);

      expect(decoded.payloadType, PayloadType.preKeySignalMessage);
      expect(decoded.packetId, frame.packetId);
      expect(decoded.destination, frame.destination);
      expect(decoded.source, frame.source);
      expect(decoded.priority, frame.priority);
      expect(decoded.createdAtMs, frame.createdAtMs);
      expect(decoded.expiresAtMs, frame.expiresAtMs);
      expect(decoded.payload, equals(frame.payload));
    });

    test('priority at lower bound (0)', () {
      final frame = RelayPacketFrame(
        payloadType: PayloadType.signalMessage,
        packetId: 'p',
        destination: 'd',
        source: 's',
        priority: 0,
        createdAtMs: 0,
        expiresAtMs: 0,
        payload: Uint8List(0),
      );
      final decoded = RelayPacketFrame.deserialize(frame.serialize());
      expect(decoded.priority, 0);
    });

    test('priority at upper bound (255)', () {
      final frame = RelayPacketFrame(
        payloadType: PayloadType.signalMessage,
        packetId: 'p',
        destination: 'd',
        source: 's',
        priority: 255,
        createdAtMs: 0,
        expiresAtMs: 0,
        payload: Uint8List(0),
      );
      final decoded = RelayPacketFrame.deserialize(frame.serialize());
      expect(decoded.priority, 255);
    });

    test('0-byte payload round-trips byte-for-byte (empty, not omitted)', () {
      final frame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'p',
        destination: 'd',
        source: 's',
        priority: 1,
        createdAtMs: 10,
        expiresAtMs: 20,
        payload: Uint8List(0),
      );
      final decoded = RelayPacketFrame.deserialize(frame.serialize());
      expect(decoded.payload, isEmpty);
      expect(decoded.payloadType, PayloadType.control);
    });

    test('64 KiB payload round-trips byte-for-byte', () {
      final bigPayload = Uint8List.fromList(
        List<int>.generate(64 * 1024, (i) => i % 256),
      );
      final frame = RelayPacketFrame(
        payloadType: PayloadType.signalMessage,
        packetId: 'p',
        destination: 'd',
        source: 's',
        priority: 3,
        createdAtMs: 111,
        expiresAtMs: 222,
        payload: bigPayload,
      );
      final decoded = RelayPacketFrame.deserialize(frame.serialize());
      expect(decoded.payload.length, bigPayload.length);
      expect(decoded.payload, equals(bigPayload));
    });
  });

  group('test_EARS_COMM_4_malformed_frames_rejected', () {
    test('empty buffer', () {
      expect(
        () => RelayPacketFrame.deserialize(Uint8List(0)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('empty buffer'),
          ),
        ),
      );
    });

    test('header truncated mid-field (packetId length header cut short)', () {
      final full = _wellFormedFrame();
      // frameVersion(1) + payloadType(1) = 2 bytes, then only 2 of the 4
      // packetIdLength bytes -- truncated squarely inside that field.
      final truncated = Uint8List.fromList(full.sublist(0, 4));
      expect(
        () => RelayPacketFrame.deserialize(truncated),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('packetIdLength'),
          ),
        ),
      );
    });

    test('frameVersion=0 rejected', () {
      final bytes = _wellFormedFrame(frameVersionOverride: 0);
      expect(
        () => RelayPacketFrame.deserialize(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('frameVersion'),
          ),
        ),
      );
    });

    test('frameVersion=2 rejected', () {
      final bytes = _wellFormedFrame(frameVersionOverride: 2);
      expect(
        () => RelayPacketFrame.deserialize(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('frameVersion'),
          ),
        ),
      );
    });

    test('payloadType=99 (unknown tag) rejected', () {
      final bytes = _wellFormedFrame(payloadTypeOverride: 99);
      expect(
        () => RelayPacketFrame.deserialize(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('payloadType'),
          ),
        ),
      );
    });

    test('a length prefix larger than the buffer', () {
      final bytes = _wellFormedFrame();
      // Overwrite the packetId length prefix (bytes 2-5, big-endian u32)
      // with a value bigger than the whole buffer, but small enough not to
      // overflow the offset+length arithmetic differently than the
      // dedicated 0xFFFFFFFF case below.
      final view = ByteData.sublistView(bytes);
      view.setUint32(2, bytes.length + 1000);
      expect(
        () => RelayPacketFrame.deserialize(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('packetId'),
          ),
        ),
      );
    });

    test('a length prefix of 0xFFFFFFFF', () {
      final bytes = _wellFormedFrame();
      final view = ByteData.sublistView(bytes);
      view.setUint32(2, 0xFFFFFFFF);
      expect(
        () => RelayPacketFrame.deserialize(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('packetId'),
          ),
        ),
      );
    });
  });
}
