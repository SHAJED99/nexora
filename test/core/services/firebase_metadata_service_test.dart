// core/services — E01-T02: best-effort account↔device metadata write to
// Realtime Database (FR-FB-001/002). Tests exercise `writeDeviceMetadata`,
// the seam `FirebaseMetadataService` exposes specifically so tests never
// need a real `FirebaseDatabase`/platform-channel test harness (same
// pattern as `GoogleAuthService.signInAndGetAccountUid` — see that file's
// comments).
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';

/// Captures the path + data a real write would have sent, instead of
/// touching Realtime Database.
class _CapturingFirebaseMetadataService extends FirebaseMetadataService {
  String? capturedUid;
  String? capturedDeviceId;
  Map<String, dynamic>? capturedData;

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    capturedUid = uid;
    capturedDeviceId = deviceId;
    capturedData = data;
  }
}

/// Always throws from the write seam, to prove `registerDevice` swallows
/// and logs rather than propagating (EARS-FB-2 boundary, service level).
class _ThrowingFirebaseMetadataService extends FirebaseMetadataService {
  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the write seam — simulates `DatabaseReference.set()`
/// queuing offline and never getting a server ack. Proves `registerDevice`
/// is bounded by its `timeout`, not an indefinite hang (review finding,
/// E01-T02).
class _HangingFirebaseMetadataService extends FirebaseMetadataService {
  _HangingFirebaseMetadataService({super.timeout});

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return Completer<void>().future; // never completes
  }
}

void main() {
  test('test_EARS_FB_1_registers_device_metadata_only', () async {
    // EARS-FB-1 (FR-FB-001/002): WHEN sign-in completes, the system SHALL
    // register the device under the account in Realtime Database,
    // containing only metadata (no plaintext/keys/recordings).
    final service = _CapturingFirebaseMetadataService();

    await service.registerDevice('uid-123', 'device-abc');

    expect(service.capturedUid, 'uid-123');
    expect(service.capturedDeviceId, 'device-abc');
    final data = service.capturedData!;
    // Exactly the allowed field set — no more, no less.
    expect(data.keys.toSet(), {'deviceId', 'createdAt', 'lastSeenAt', 'platform'});
    expect(data['deviceId'], 'device-abc');
    expect(data['platform'], 'android');
    expect(data['createdAt'], ServerValue.timestamp);
    expect(data['lastSeenAt'], ServerValue.timestamp);
  });

  test(
    'test_EARS_FB_2_realtime_db_failure_is_caught_and_logged_not_thrown',
    () async {
      // EARS-FB-2 (offline-first constitution): a Realtime Database
      // failure must never propagate out of registerDevice — it is
      // swallowed and logged, not thrown.
      final service = _ThrowingFirebaseMetadataService();

      await expectLater(
        service.registerDevice('uid-123', 'device-abc'),
        completes,
      );
    },
  );

  test(
    'test_EARS_FB_2_never_completing_write_is_bounded_by_timeout_not_hung',
    () async {
      // Review finding (E01-T02): a write seam that never completes (the
      // real-world shape of an offline `DatabaseReference.set()`) must not
      // hang registerDevice forever — §4's "fire-and-forget" promise is
      // broken if awaiting it can block sign-in indefinitely.
      final service = _HangingFirebaseMetadataService(
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.registerDevice('uid-123', 'device-abc'),
        completes,
      );
    },
  );
}
