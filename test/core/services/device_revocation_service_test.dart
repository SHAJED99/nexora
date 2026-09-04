// E11-T04 -- DeviceRevocationService tests.
//
// Local read/write tests use a real in-memory AppDatabase (fast, no mocking
// needed for Drift). Firebase read/write tests use the same test-seam
// pattern as firebase_metadata_service_test.dart / sync_cursor_service_test.dart
// -- subclass the service and override the seam methods
// (`writeRevocationData`/`readDevicesData`) instead of touching a real
// `FirebaseDatabase`/platform channel.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/device_revocation_service.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_paths.dart';

/// Captures the uid/deviceId/data a real write would have sent.
class _CapturingDeviceRevocationService extends DeviceRevocationService {
  _CapturingDeviceRevocationService({
    required super.localDeviceId,
    required super.database,
  });

  String? capturedUid;
  String? capturedDeviceId;
  Map<String, dynamic>? capturedData;

  @override
  Future<void> writeRevocationData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    capturedUid = uid;
    capturedDeviceId = deviceId;
    capturedData = data;
  }
}

/// Proves `revoke` is local-first (EARS-FB-10): the Firebase write seam
/// checks, at the moment it is called, whether the local row already
/// exists -- `revoke` must await the local write before ever reaching this
/// seam.
class _OrderRecordingDeviceRevocationService extends DeviceRevocationService {
  _OrderRecordingDeviceRevocationService({
    required super.localDeviceId,
    required super.database,
  });

  bool? localRowExistedWhenFirebaseWriteRan;
  var firebaseWriteCalls = 0;

  @override
  Future<void> writeRevocationData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    firebaseWriteCalls++;
    localRowExistedWhenFirebaseWriteRan = await isRevoked(deviceId);
  }
}

/// Always throws from the write seam, to prove `revoke` swallows and logs
/// rather than propagating (EARS-FB-10).
class _ThrowingWriteDeviceRevocationService extends DeviceRevocationService {
  _ThrowingWriteDeviceRevocationService({
    required super.localDeviceId,
    required super.database,
  });

  @override
  Future<void> writeRevocationData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the write seam -- simulates `DatabaseReference.set()`
/// queuing offline and never getting a server ack. Proves the write is
/// bounded by `timeout`, not an indefinite hang.
class _HangingWriteDeviceRevocationService extends DeviceRevocationService {
  _HangingWriteDeviceRevocationService({
    required super.localDeviceId,
    required super.database,
    required super.timeout,
  });

  @override
  Future<void> writeRevocationData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return Completer<void>().future; // never completes
  }
}

/// Always throws from the read seam, to prove `pullRevocations` returns `0`
/// rather than propagating (EARS-FB-12).
class _ThrowingReadDeviceRevocationService extends DeviceRevocationService {
  _ThrowingReadDeviceRevocationService({
    required super.localDeviceId,
    required super.database,
  });

  @override
  Future<Object?> readDevicesData(String uid) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the read seam -- proves the read is bounded by
/// `timeout` and returns `0` rather than hanging forever (EARS-FB-12).
class _HangingReadDeviceRevocationService extends DeviceRevocationService {
  _HangingReadDeviceRevocationService({
    required super.localDeviceId,
    required super.database,
    required super.timeout,
  });

  @override
  Future<Object?> readDevicesData(String uid) {
    return Completer<Object?>().future; // never completes
  }
}

/// Returns a fixed raw `users/$uid/devices` snapshot from the read seam.
class _RespondingReadDeviceRevocationService extends DeviceRevocationService {
  _RespondingReadDeviceRevocationService({
    required super.localDeviceId,
    required super.database,
    required this.response,
  });

  final Object? response;

  @override
  Future<Object?> readDevicesData(String uid) async => response;
}

AppDatabase _openTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  group('local revoke + isRevoked', () {
    test('isRevoked is false for a device with no revocation row', () async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final service =
          DeviceRevocationService(localDeviceId: 'device-A', database: db);

      expect(await service.isRevoked('device-B'), isFalse);
    });

    test(
      'test_EARS_FB_10_revoke_writes_local_then_firebase',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _OrderRecordingDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
        );

        expect(await service.isRevoked('device-B'), isFalse);
        await service.revoke('uid-123', 'device-B');

        expect(await service.isRevoked('device-B'), isTrue);
        expect(service.firebaseWriteCalls, 1);
        // The local row was already durably written by the time the
        // Firebase write seam ran -- proves local-first ordering, not just
        // "both eventually happened".
        expect(service.localRowExistedWhenFirebaseWriteRan, isTrue);
      },
    );

    test('revoking a device is idempotent (re-revoking does not error)',
        () async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final service = _CapturingDeviceRevocationService(
        localDeviceId: 'device-A',
        database: db,
      );

      await service.revoke('uid-123', 'device-B');
      await service.revoke('uid-123', 'device-B');

      expect(await service.isRevoked('device-B'), isTrue);
    });
  });

  group('Firebase write (revoke)', () {
    test('writes only revokedAt + revokedByDeviceId to Firebase', () async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final service = _CapturingDeviceRevocationService(
        localDeviceId: 'device-A',
        database: db,
      );

      await service.revoke('uid-123', 'device-B');

      expect(service.capturedUid, 'uid-123');
      expect(service.capturedDeviceId, 'device-B');
      expect(
        service.capturedData!.keys.toSet(),
        {'revokedAt', 'revokedByDeviceId'},
      );
      expect(service.capturedData!['revokedByDeviceId'], 'device-A');
    });

    test(
      'test_EARS_FB_13_writeRevocationData_asserts_allowed_fields_before_the_try_block',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _CapturingDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
        );

        await service.revoke('uid-123', 'device-B');

        expect(
          service.capturedData!.keys.toSet(),
          FirebaseBoundary.allowedFields(FirebaseNodeKind.deviceRevocation),
        );
      },
    );

    test(
      'test_EARS_FB_13_boundary_rejects_extra_revocation_field',
      () {
        expect(
          () => FirebaseBoundary.assertAllowedFields(
            FirebaseNodeKind.deviceRevocation,
            const {
              'revokedAt': 12345,
              'revokedByDeviceId': 'device-A',
              'extraField': 'not allowed',
            },
          ),
          throwsA(isA<FirebaseBoundaryViolation>()),
        );
      },
    );

    test(
      'Firebase write failure is caught, not thrown (EARS-FB-10 best-effort)',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _ThrowingWriteDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
        );

        await expectLater(
          service.revoke('uid-123', 'device-B'),
          completes,
        );
        // The local write still happened even though Firebase failed.
        expect(await service.isRevoked('device-B'), isTrue);
      },
    );

    test(
      'a never-completing Firebase write is bounded by timeout, not hung',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _HangingWriteDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
          timeout: const Duration(milliseconds: 50),
        );

        await expectLater(
          service.revoke('uid-123', 'device-B'),
          completes,
        );
      },
    );
  });

  group('pullRevocations', () {
    test(
      'test_EARS_FB_11_remote_revoked_local_active_resolves_revoked',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _RespondingReadDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
          response: {
            'device-B': {
              'deviceId': 'device-B',
              'createdAt': 1000,
              'lastSeenAt': 1000,
              'platform': 'android',
              'revocation': {
                'revokedAt': 2000,
                'revokedByDeviceId': 'device-C',
              },
            },
          },
        );

        expect(await service.isRevoked('device-B'), isFalse);
        final changed = await service.pullRevocations('uid-123');

        expect(changed, 1);
        expect(await service.isRevoked('device-B'), isTrue);
      },
    );

    test(
      'test_EARS_FB_11_local_revoked_remote_absent_stays_revoked',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        // The account has no devices/revocations published at all --
        // simulates a brand new/offline account state.
        final service = _RespondingReadDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
          response: null,
        );
        await service.revoke('uid-123', 'device-B');
        expect(await service.isRevoked('device-B'), isTrue);

        final changed = await service.pullRevocations('uid-123');

        expect(changed, 0);
        // Still revoked -- a missing remote node must never un-revoke.
        expect(await service.isRevoked('device-B'), isTrue);
      },
    );

    test(
      'remote device present but not revoked does not create a local row',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _RespondingReadDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
          response: {
            'device-B': {
              'deviceId': 'device-B',
              'createdAt': 1000,
              'lastSeenAt': 1000,
              'platform': 'android',
            },
          },
        );

        final changed = await service.pullRevocations('uid-123');

        expect(changed, 0);
        expect(await service.isRevoked('device-B'), isFalse);
      },
    );

    test(
      'test_EARS_FB_12_offline_pull_changes_nothing_and_does_not_throw',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _ThrowingReadDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
        );
        await service.revoke('uid-123', 'device-B');

        final result = await service.pullRevocations('uid-123');

        expect(result, 0);
        expect(await service.isRevoked('device-B'), isTrue);
      },
    );

    test(
      'a never-completing Firebase read is bounded by timeout, returns 0',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _HangingReadDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
          timeout: const Duration(milliseconds: 50),
        );

        final result = await service.pullRevocations('uid-123');

        expect(result, 0);
      },
    );

    test(
      'multiple revoked devices in one pull are all merged, count reflects each',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _RespondingReadDeviceRevocationService(
          localDeviceId: 'device-A',
          database: db,
          response: {
            'device-B': {
              'revocation': {'revokedAt': 1000, 'revokedByDeviceId': 'device-C'},
            },
            'device-D': {
              'revocation': {'revokedAt': 1500, 'revokedByDeviceId': 'device-C'},
            },
            'device-E': {'deviceId': 'device-E'},
          },
        );

        final changed = await service.pullRevocations('uid-123');

        expect(changed, 2);
        expect(await service.isRevoked('device-B'), isTrue);
        expect(await service.isRevoked('device-D'), isTrue);
        expect(await service.isRevoked('device-E'), isFalse);
      },
    );
  });

  group('E11-T04 path registry', () {
    test('deviceRevocation path is a child of the pre-existing device node',
        () {
      expect(
        FirebasePaths.deviceRevocation('uid-123', 'device-B'),
        'users/uid-123/devices/device-B/revocation',
      );
      expect(
        FirebasePaths.deviceRevocation('uid-123', 'device-B'),
        '${FirebasePaths.device('uid-123', 'device-B')}/revocation',
      );
    });

    test('devices path is the parent enumerated by pullRevocations', () {
      expect(
        FirebasePaths.devices('uid-123'),
        'users/uid-123/devices',
      );
    });
  });
}
