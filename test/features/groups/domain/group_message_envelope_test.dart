// Tests for GroupMessageEnvelope / GroupMessageRoutingHeader (E07-T06).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/features/groups/domain/group_message_envelope.dart';

void main() {
  group('GroupMessageEnvelope', () {
    test('round trips every field exactly', () {
      final envelope = GroupMessageEnvelope(
        groupId: 'g:abc123',
        epoch: 7,
        senderDeviceId: 'device-a',
        messageId: 'msg-1',
        sequenceNumber: 42,
        createdAtMs: 1700000000000,
        body: Uint8List.fromList('hello group'.codeUnits),
      );

      final decoded = GroupMessageEnvelope.deserialize(envelope.serialize());

      expect(decoded.groupId, envelope.groupId);
      expect(decoded.epoch, envelope.epoch);
      expect(decoded.senderDeviceId, envelope.senderDeviceId);
      expect(decoded.messageId, envelope.messageId);
      expect(decoded.sequenceNumber, envelope.sequenceNumber);
      expect(decoded.createdAtMs, envelope.createdAtMs);
      expect(decoded.body, envelope.body);
    });

    test('round trips an empty body', () {
      final envelope = GroupMessageEnvelope(
        groupId: 'g:empty',
        epoch: 0,
        senderDeviceId: 'device-a',
        messageId: 'msg-empty',
        sequenceNumber: 0,
        createdAtMs: 0,
        body: Uint8List(0),
      );

      final decoded = GroupMessageEnvelope.deserialize(envelope.serialize());
      expect(decoded.body, isEmpty);
    });

    test('empty buffer throws group.malformed_message', () {
      expect(
        () => GroupMessageEnvelope.deserialize(Uint8List(0)),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'group.malformed_message'),
        ),
      );
    });

    test('unknown format version throws group.malformed_message', () {
      final envelope = GroupMessageEnvelope(
        groupId: 'g:v',
        epoch: 0,
        senderDeviceId: 'device-a',
        messageId: 'msg-v',
        sequenceNumber: 0,
        createdAtMs: 0,
        body: Uint8List.fromList([1, 2, 3]),
      );
      final bytes = envelope.serialize();
      bytes[0] = 0xFF; // corrupt the version byte

      expect(
        () => GroupMessageEnvelope.deserialize(bytes),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'group.malformed_message'),
        ),
      );
    });

    test('truncated buffer throws group.malformed_message', () {
      final envelope = GroupMessageEnvelope(
        groupId: 'g:trunc',
        epoch: 0,
        senderDeviceId: 'device-a',
        messageId: 'msg-trunc',
        sequenceNumber: 0,
        createdAtMs: 0,
        body: Uint8List.fromList([1, 2, 3, 4, 5]),
      );
      final bytes = envelope.serialize();
      final truncated = bytes.sublist(0, bytes.length - 20);

      expect(
        () => GroupMessageEnvelope.deserialize(truncated),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'group.malformed_message'),
        ),
      );
    });

    test('a length prefix declaring more bytes than remain fails loudly, '
        'never reads past the buffer', () {
      final envelope = GroupMessageEnvelope(
        groupId: 'g:oversize',
        epoch: 0,
        senderDeviceId: 'device-a',
        messageId: 'm',
        sequenceNumber: 0,
        createdAtMs: 0,
        body: Uint8List.fromList([9]),
      );
      final bytes = envelope.serialize();
      // Corrupt the groupId length prefix (offset 1..4) to an oversized
      // value.
      final view = ByteData.sublistView(bytes);
      view.setUint32(1, 0xFFFFFFF0);

      expect(
        () => GroupMessageEnvelope.deserialize(bytes),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'group.malformed_message'),
        ),
      );
    });
  });

  group('GroupMessageRoutingHeader', () {
    test('round trips groupId/epoch/ciphertext exactly', () {
      final header = GroupMessageRoutingHeader(
        groupId: 'g:route',
        epoch: 3,
        ciphertext: Uint8List.fromList([10, 20, 30, 40]),
      );
      final decoded = GroupMessageRoutingHeader.deserialize(header.serialize());

      expect(decoded.groupId, header.groupId);
      expect(decoded.epoch, header.epoch);
      expect(decoded.ciphertext, header.ciphertext);
    });

    test('round trips empty ciphertext', () {
      final header = GroupMessageRoutingHeader(
        groupId: 'g:route2',
        epoch: 0,
        ciphertext: Uint8List(0),
      );
      final decoded = GroupMessageRoutingHeader.deserialize(header.serialize());
      expect(decoded.ciphertext, isEmpty);
    });

    test('empty buffer throws group.malformed_message', () {
      expect(
        () => GroupMessageRoutingHeader.deserialize(Uint8List(0)),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'group.malformed_message'),
        ),
      );
    });

    test('unknown version throws group.malformed_message', () {
      final header = GroupMessageRoutingHeader(
        groupId: 'g:v2',
        epoch: 1,
        ciphertext: Uint8List.fromList([1, 2]),
      );
      final bytes = header.serialize();
      bytes[0] = 0xEE;

      expect(
        () => GroupMessageRoutingHeader.deserialize(bytes),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'group.malformed_message'),
        ),
      );
    });

    test('truncated buffer throws group.malformed_message', () {
      final header = GroupMessageRoutingHeader(
        groupId: 'g:trunc2',
        epoch: 1,
        ciphertext: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
      );
      final bytes = header.serialize();
      final truncated = bytes.sublist(0, 3);

      expect(
        () => GroupMessageRoutingHeader.deserialize(truncated),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'group.malformed_message'),
        ),
      );
    });
  });
}
