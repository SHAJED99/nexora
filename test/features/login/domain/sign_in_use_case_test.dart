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
import 'package:nexora/core/abuse/rate_limiter.dart';
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
    throw Exception('realtime database unavailable');
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

  test(
    'test_EARS_ABUSE_5_wired_sign_in_flow_denies_over_limit_registration',
    () async {
      // E13-T07 (FR-ABUSE-001): before this task, `SignInUseCase.call`
      // never passed `accountUid` into `createDeviceIdentity`, so
      // `DeviceIdentityRepository`'s per-account registration rate limit
      // (E13-T02) could never actually fire through the real sign-in path,
      // no matter how many devices one account registered. This proves the
      // wiring: the SAME account uid, registering past
      // `_maxDeviceRegistrationsPerWindow` (5) devices, gets denied via the
      // real `SignInUseCase.call` entry point, not just the repository in
      // isolation.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(
        db,
        rateLimiter: RateLimiter(db),
      );
      const accountUid = 'firebase-uid-flood';
      final useCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success(accountUid),
      );

      for (var i = 0; i < 5; i++) {
        await useCase('device-$i');
      }

      // The 6th registration under the SAME account uid must be denied.
      await expectLater(
        useCase('device-6'),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.code,
            'code',
            'device.registration_rate_limited',
          ),
        ),
      );

      final rows = await db.select(db.deviceIdentities).get();
      expect(
        rows,
        hasLength(5),
        reason: 'the denied 6th attempt must not have written a device row',
      );

      await db.close();
    },
  );

  test(
    'test_EARS_ABUSE_5_returning_device_reuses_identity_and_is_never_rate_limited',
    () async {
      // F1 fix (E13-T07 review round 2, S1/S2): before this fix,
      // `LoginController._signIn` minted a brand-new random device id on
      // EVERY app launch and always called through `SignInUseCase.call`'s
      // full registration path — so a normal user relaunching the app more
      // than `_maxDeviceRegistrationsPerWindow` (5) times in 24h got
      // silently denied on launch 6, even though it is the SAME device
      // every time. This proves the fix's actual mechanism: once
      // `call(deviceId)` is invoked with THIS device's own existing id
      // (exactly what `LoginController` now does via `existingDeviceId()`
      // before minting fresh), it recognizes a returning device and never
      // touches `createDeviceIdentity`/the rate limiter again — proven
      // across 10 consecutive "launches", well past the 5/24h cap that
      // would otherwise fire.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(
        db,
        rateLimiter: RateLimiter(db),
      );
      const accountUid = 'firebase-uid-returning-device';
      final useCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success(accountUid),
      );

      // Launch 1: fresh install, no existing identity yet — mints and
      // registers, exactly like today.
      final firstDeviceId = await useCase.existingDeviceId();
      expect(firstDeviceId, isNull);
      await useCase('mint-device-0');

      // Launches 2-10: `LoginController`'s own logic — read the existing
      // id back, reuse it instead of minting — repeated well past the
      // 5/24h cap.
      for (var launch = 0; launch < 9; launch++) {
        final existingDeviceId = await useCase.existingDeviceId();
        expect(existingDeviceId, 'mint-device-0');
        await expectLater(useCase(existingDeviceId!), completes);
      }

      // Exactly ONE row was ever written — every later "launch" reused it,
      // never registered a new one.
      final rows = await db.select(db.deviceIdentities).get();
      expect(rows, hasLength(1));
      expect(rows.single.deviceId, 'mint-device-0');
      expect(rows.single.signedIn, isTrue);

      await db.close();
    },
  );
}
