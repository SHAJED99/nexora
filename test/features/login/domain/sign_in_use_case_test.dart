// features/login/domain — E01-T01: SignInUseCase now orchestrates a real
// (test-doubled) Google sign-in + local device-identity write, replacing
// the genesis stub's `Future.delayed`.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';

import '../../../support/fake_google_auth_service.dart';

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
}
