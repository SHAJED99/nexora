// E11-T01 — FirebaseBoundary tests (EARS-FB-1, EARS-FB-2).
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/services/firebase_boundary.dart';

void main() {
  group('test_EARS_FB_1_no_forbidden_field_is_writable', () {
    // For each node kind, a payload carrying a forbidden field (message
    // plaintext, a private/session key, or location data — FR-FB-002) is
    // never in the allow-list, so it always throws.
    test('device node rejects plaintext/privateKey/sessionKey/latitude', () {
      for (final forbiddenKey in [
        'plaintext',
        'privateKey',
        'sessionKey',
        'latitude',
      ]) {
        expect(
          () => FirebaseBoundary.assertAllowedFields(
            FirebaseNodeKind.device,
            {'deviceId': 'd1', forbiddenKey: 'x'},
          ),
          throwsA(isA<FirebaseBoundaryViolation>()),
        );
      }
    });

    test(
      'syncCursor node rejects plaintext/privateKey/sessionKey/latitude',
      () {
        for (final forbiddenKey in [
          'plaintext',
          'privateKey',
          'sessionKey',
          'latitude',
        ]) {
          expect(
            () => FirebaseBoundary.assertAllowedFields(
              FirebaseNodeKind.syncCursor,
              {'localDeviceId': 'd1', forbiddenKey: 'x'},
            ),
            throwsA(isA<FirebaseBoundaryViolation>()),
          );
        }
      },
    );
  });

  group('test_EARS_FB_2_unknown_key_rejected_before_write', () {
    test('a fake write seam is never reached when the guard throws first', () {
      var writeReached = false;
      void fakeWrite(Map<String, Object?> data) {
        FirebaseBoundary.assertAllowedFields(FirebaseNodeKind.device, data);
        writeReached = true; // only reached if the guard did not throw
      }

      expect(
        () => fakeWrite({'deviceId': 'd1', 'extra': 'nope'}),
        throwsA(isA<FirebaseBoundaryViolation>()),
      );
      expect(writeReached, isFalse);
    });
  });

  group('test_EARS_FB_2_allowed_payload_passes', () {
    test("today's exact four-field device payload passes unchanged", () {
      expect(
        () => FirebaseBoundary.assertAllowedFields(
          FirebaseNodeKind.device,
          {
            'deviceId': 'device-abc',
            'createdAt': 12345,
            'lastSeenAt': 12345,
            'platform': 'android',
          },
        ),
        returnsNormally,
      );
    });

    test("today's exact five-field sync-cursor payload passes unchanged", () {
      expect(
        () => FirebaseBoundary.assertAllowedFields(
          FirebaseNodeKind.syncCursor,
          {
            'localDeviceId': 'device-A',
            'remoteDeviceId': 'device-B',
            'conversationId': 'conv-1',
            'lastConfirmedSequenceNumber': 7,
            'updatedAt': 1000,
          },
        ),
        returnsNormally,
      );
    });
  });

  test(
    'ServerValue.timestamp-shaped sentinel map value does not trip the guard '
    '-- keys are checked, not value types',
    () {
      // ServerValue.timestamp is `{'.sv': 'timestamp'}`, not an int. The
      // guard must not reject an allowed key merely because its value is a
      // Map (task §6 Risks).
      expect(
        () => FirebaseBoundary.assertAllowedFields(
          FirebaseNodeKind.device,
          {
            'deviceId': 'device-abc',
            'createdAt': {'.sv': 'timestamp'},
            'lastSeenAt': {'.sv': 'timestamp'},
            'platform': 'android',
          },
        ),
        returnsNormally,
      );
    },
  );

  test('violation message names the offending key, never any value', () {
    try {
      FirebaseBoundary.assertAllowedFields(
        FirebaseNodeKind.device,
        {'deviceId': 'device-abc', 'privateKey': 'super-secret-value'},
      );
      fail('expected FirebaseBoundaryViolation');
    } on FirebaseBoundaryViolation catch (e) {
      expect(e.toString(), contains('privateKey'));
      expect(e.toString(), contains('device'));
      expect(e.toString(), isNot(contains('super-secret-value')));
    }
  });

  test('allowedFields exposes the closed set for each kind', () {
    expect(
      FirebaseBoundary.allowedFields(FirebaseNodeKind.device),
      {'deviceId', 'createdAt', 'lastSeenAt', 'platform'},
    );
    expect(
      FirebaseBoundary.allowedFields(FirebaseNodeKind.syncCursor),
      {
        'localDeviceId',
        'remoteDeviceId',
        'conversationId',
        'lastConfirmedSequenceNumber',
        'updatedAt',
      },
    );
  });
}
