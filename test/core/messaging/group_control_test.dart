// Tests for GroupControlFrame (E07-T03) -- pure codec, no I/O.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/messaging/group_control.dart';
import 'package:nexora/core/persistence/group_tables.dart';

void main() {
  group('GroupControlFrame', () {
    test(
      'test_control_frame_round_trips_and_rejects_trailing_bytes',
      () {
        for (final kind in GroupEventKind.values) {
          final frame = GroupControlFrame(
            kind: kind,
            groupId: 'g:abc123',
            epoch: 7,
            actorDeviceId: 'device-owner',
            subjectDeviceId: 'device-subject',
            name: 'New Name',
            memberList: const ['device-owner', 'device-a', 'device-b'],
            createdAtMs: 1234567890123,
          );
          final bytes = frame.serialize();
          final decoded = GroupControlFrame.deserialize(bytes);

          expect(decoded.version, frame.version);
          expect(decoded.kind, kind);
          expect(decoded.groupId, frame.groupId);
          expect(decoded.epoch, frame.epoch);
          expect(decoded.actorDeviceId, frame.actorDeviceId);
          expect(decoded.subjectDeviceId, frame.subjectDeviceId);
          expect(decoded.name, frame.name);
          expect(decoded.memberList, frame.memberList);
          expect(decoded.createdAtMs, frame.createdAtMs);

          // Trailing garbage after an otherwise-complete, valid buffer.
          final withTrailingByte = Uint8List.fromList([...bytes, 0]);
          expect(
            () => GroupControlFrame.deserialize(withTrailingByte),
            throwsA(
              isA<AppFailure>().having(
                (f) => f.code,
                'code',
                'group.malformed_control',
              ),
            ),
          );
        }
      },
    );

    test('round trips with every optional field absent', () {
      final frame = GroupControlFrame(
        kind: GroupEventKind.deleted,
        groupId: 'g:abc',
        epoch: 3,
        actorDeviceId: 'device-owner',
        createdAtMs: 42,
      );
      final decoded = GroupControlFrame.deserialize(frame.serialize());
      expect(decoded.subjectDeviceId, isNull);
      expect(decoded.name, isNull);
      expect(decoded.memberList, isNull);
    });

    test('rejects a malformed matrix', () {
      // Empty buffer.
      expect(
        () => GroupControlFrame.deserialize(Uint8List(0)),
        throwsA(isA<AppFailure>()),
      );

      // Unknown version byte.
      expect(
        () => GroupControlFrame.deserialize(Uint8List.fromList([99])),
        throwsA(isA<AppFailure>()),
      );

      final valid = GroupControlFrame(
        kind: GroupEventKind.renamed,
        groupId: 'g:abc',
        epoch: 1,
        actorDeviceId: 'device-owner',
        name: 'x',
        createdAtMs: 1,
      ).serialize();

      // Truncated buffer (cuts off mid-groupId length prefix).
      expect(
        () => GroupControlFrame.deserialize(valid.sublist(0, 3)),
        throwsA(isA<AppFailure>()),
      );

      // Unknown kind tag.
      final badKind = Uint8List.fromList(valid);
      badKind[1] = 200;
      expect(
        () => GroupControlFrame.deserialize(badKind),
        throwsA(isA<AppFailure>()),
      );

      // A length prefix claiming more bytes than remain.
      final badLength = Uint8List.fromList(valid);
      badLength[6] = 0xff;
      expect(
        () => GroupControlFrame.deserialize(badLength),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('ciphertext control body nesting', () {
    test('decodeCiphertextControlBody rejects an empty buffer', () {
      expect(
        () => decodeCiphertextControlBody(Uint8List(0)),
        throwsA(isA<AppFailure>()),
      );
    });

    test('decodeCiphertextControlBody rejects the control tag itself', () {
      // tag 3 == PayloadType.control -- not a ciphertext tag, must never be
      // accepted here (this file's own header: never PayloadType.control).
      expect(
        () => decodeCiphertextControlBody(Uint8List.fromList([3, 1, 2, 3])),
        throwsA(isA<AppFailure>()),
      );
    });

    test('decodeCiphertextControlBody rejects an unknown tag', () {
      expect(
        () => decodeCiphertextControlBody(Uint8List.fromList([99, 1, 2])),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
