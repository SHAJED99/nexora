// features/login/domain — E01-T01: SignInUseCase now orchestrates a real
// (test-doubled) Google sign-in + local device-identity write, replacing
// the genesis stub's `Future.delayed`.
//
// E01-T02: also fires a best-effort Firebase account<->device metadata
// registration after the local Drift write. A Realtime Database failure must never
// block sign-in (EARS-FB-2) — verified here with a metadata service double
// that always throws from its write seam.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';

import '../../../support/fake_google_auth_service.dart';

/// Always throws from the write seam — proves a Realtime Database failure never
/// propagates out of `SignInUseCase.call` (EARS-FB-2).
class _ThrowingFirebaseMetadataService extends FirebaseMetadataService {
  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    throw Exception('firestore unavailable');
  }
}

/// Captures the uid/deviceId a real registration would have used.
class _CapturingFirebaseMetadataService extends FirebaseMetadataService {
  String? capturedUid;
  String? capturedDeviceId;

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    capturedUid = uid;
    capturedDeviceId = deviceId;
  }
}

void main() {
  test('test_EARS_AUTH_1_signs_in_via_firebase', () async {
    // EARS-AUTH-1 (FR-AUTH-001): WHEN a user taps "Continue with Google",
    // the system SHALL authenticate via Firebase Auth.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DeviceIdentityRepository(db);
    final useCase = SignInUseCase(
      repository,
      authService: FakeGoogleAuthService.success('firebase-uid-123'),
    );

    await useCase('device-abc');

    final identity = await db.latestDeviceIdentity();
    expect(identity, isNotNull);
    expect(identity!.signedIn, isTrue);
    expect(identity.deviceId, 'device-abc');
    // FR-AUTH-004: the account uid Firebase Auth returned is recorded
    // alongside the device row, so multiple devices under one account are
    // queryable — but the device identity itself (deviceId) was supplied
    // independently, before sign-in ran (EARS-AUTH-2).
    expect(identity.accountUid, 'firebase-uid-123');

    await db.close();
  });

  test('test_EARS_AUTH_3_signin_failure_maps_to_app_failure', () async {
    // EARS-AUTH-3: IF sign-in is cancelled or fails, THEN the system SHALL
    // surface an AppFailure rather than crash or hang.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DeviceIdentityRepository(db);
    final useCase = SignInUseCase(
      repository,
      authService: FakeGoogleAuthService.failure(
        const AppFailure('auth.google_sign_in_failed', cause: 'cancelled'),
      ),
    );

    // Propagates as a normal Future rejection — not a crash/hang.
    await expectLater(useCase('device-xyz'), throwsA(isA<AppFailure>()));

    // Sign-in failed before any persistence happened — no orphaned row.
    expect(await db.latestDeviceIdentity(), isNull);

    await db.close();
  });

  test(
    'test_EARS_FB_1_registers_device_under_account_after_local_write',
    () async {
      // EARS-FB-1 (FR-FB-001/002, FR-AUTH-004): WHEN sign-in completes, the
      // system SHALL register the device under the account in Realtime Database —
      // fired after the local Drift write.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(db);
      final metadataService = _CapturingFirebaseMetadataService();
      final useCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success('firebase-uid-123'),
        metadataService: metadataService,
      );

      await useCase('device-abc');

      expect(metadataService.capturedUid, 'firebase-uid-123');
      expect(metadataService.capturedDeviceId, 'device-abc');

      await db.close();
    },
  );

  test(
    'test_EARS_FB_2_metadata_write_failure_does_not_block_signin',
    () async {
      // EARS-FB-2 (offline-first constitution): IF the Realtime Database write
      // fails, THEN local sign-in SHALL still succeed — `call` completes
      // normally and the local device-identity row is written, even though
      // the metadata service always throws.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(db);
      final useCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success('firebase-uid-123'),
        metadataService: _ThrowingFirebaseMetadataService(),
      );

      await expectLater(useCase('device-xyz'), completes);

      final identity = await db.latestDeviceIdentity();
      expect(identity, isNotNull);
      expect(identity!.signedIn, isTrue);

      await db.close();
    },
  );
}
