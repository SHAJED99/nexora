// E12-T01 -- FirebaseMetadataService.readOwnDeviceIds tests.
//
// `FR-RECOVER-001` needs one fact: which device ids already exist under
// this account's own `users/$uid/devices` registry. This mirrors
// `DeviceRevocationService.readDevicesData`/`_extractRevocationFlags`'s
// exact seam-splitting pattern (a raw-read test seam + a pure extraction
// function), so tests never need a real `FirebaseDatabase`/platform-channel
// harness -- same reasoning as every other test in this class
// (`firebase_metadata_service_test.dart`).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';

/// Returns a fixed raw `users/$uid/devices` snapshot from the read seam.
class _RespondingFirebaseMetadataService extends FirebaseMetadataService {
  _RespondingFirebaseMetadataService(this.response);

  final Object? response;

  @override
  Future<Object?> readOwnDevicesData(String uid) async => response;
}

/// Always throws from the read seam, to prove `readOwnDeviceIds` returns an
/// empty set rather than propagating (EARS-RECOVER-4).
class _ThrowingFirebaseMetadataService extends FirebaseMetadataService {
  @override
  Future<Object?> readOwnDevicesData(String uid) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the read seam -- simulates a queued-offline read
/// that never gets a server ack. Proves the read is bounded by `timeout`,
/// not an indefinite hang (EARS-RECOVER-4).
class _HangingFirebaseMetadataService extends FirebaseMetadataService {
  _HangingFirebaseMetadataService({required Duration timeout})
      : super(timeout: timeout);

  @override
  Future<Object?> readOwnDevicesData(String uid) {
    return Completer<Object?>().future; // never completes
  }
}

void main() {
  group('readOwnDeviceIds', () {
    test(
      'test_EARS_RECOVER_3_returns_every_registered_device_id',
      () async {
        final service = _RespondingFirebaseMetadataService({
          'device-A': {
            'deviceId': 'device-A',
            'createdAt': 1000,
            'lastSeenAt': 1000,
            'platform': 'android',
          },
          'device-B': {
            'deviceId': 'device-B',
            'createdAt': 1500,
            'lastSeenAt': 2000,
            'platform': 'android',
          },
          'device-C': {
            'deviceId': 'device-C',
            'createdAt': 1600,
            'lastSeenAt': 2100,
            'platform': 'android',
          },
        });

        final ids = await service.readOwnDeviceIds('uid-123');

        expect(ids, {'device-A', 'device-B', 'device-C'});
      },
    );

    test('no devices registered yet returns an empty set', () async {
      final service = _RespondingFirebaseMetadataService(null);

      final ids = await service.readOwnDeviceIds('uid-123');

      expect(ids, isEmpty);
    });

    test(
      'test_EARS_RECOVER_4_read_failure_returns_empty_set_not_throw',
      () async {
        final service = _ThrowingFirebaseMetadataService();

        final ids = await service.readOwnDeviceIds('uid-123');

        expect(ids, isEmpty);
      },
    );

    test(
      'test_EARS_RECOVER_4_malformed_data_returns_empty_set',
      () async {
        // Not a Map at all -- a malformed/unexpected snapshot shape.
        final service = _RespondingFirebaseMetadataService('not-a-map');

        final ids = await service.readOwnDeviceIds('uid-123');

        expect(ids, isEmpty);
      },
    );

    test(
      'a never-completing read is bounded by timeout, returns an empty set',
      () async {
        final service = _HangingFirebaseMetadataService(
          timeout: const Duration(milliseconds: 50),
        );

        final ids = await service.readOwnDeviceIds('uid-123');

        expect(ids, isEmpty);
      },
    );

    test('a non-String key in the snapshot map is skipped, not thrown', () async {
      final service = _RespondingFirebaseMetadataService({
        'device-A': {'deviceId': 'device-A'},
        // A malformed key shape should never happen from real Firebase data
        // (keys are always Strings), but the extraction must not throw if
        // it did.
        42: {'deviceId': 'not-a-real-key'},
      });

      final ids = await service.readOwnDeviceIds('uid-123');

      expect(ids, {'device-A'});
    });
  });
}
