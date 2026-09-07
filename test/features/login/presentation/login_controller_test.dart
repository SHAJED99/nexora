// features/login/presentation — E01-T01: device id generation switched
// from Random() to Random.secure().
//
// E13-T07 review round 2 (F1, S1/S2): also covers the regression this
// round exists to fix — `LoginController._signIn` used to mint a fresh
// device id on EVERY launch, always going through
// `SignInUseCase`'s registration/rate-limit path, so a normal user
// relaunching the app more than 5 times in 24h got silently denied on
// launch 6 (see `sign_in_use_case.dart`'s own header for the full fix
// description).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';

import '../../../support/fake_google_auth_service.dart';

/// Records whether each `call` completed or threw, without changing
/// `SignInUseCase`'s own behaviour at all (delegates to `super.call`) —
/// lets this test observe, from outside `LoginController`'s own
/// swallowing `catch (e)` (`login_controller.dart`), whether each launch
/// actually reached the point that triggers `Get.offNamed('/dashboard')`
/// (a completed `call`) or was denied (a thrown `AppFailure`).
class _TrackingSignInUseCase extends SignInUseCase {
  _TrackingSignInUseCase(super.repository, {super.authService});

  int successCount = 0;
  int deniedCount = 0;

  @override
  Future<void> call(String deviceId) async {
    try {
      await super.call(deviceId);
      successCount++;
    } catch (_) {
      deniedCount++;
      rethrow;
    }
  }
}

/// F6 regression (E13-T07 review round 3): `existingDeviceId()` is a thin
/// passthrough to `DeviceIdentityRepository.latestDeviceIdentity()` — a
/// real Drift/SQLite read that can throw (corrupt or locked db, I/O
/// error). This fake reproduces that by throwing directly from
/// `existingDeviceId()`, without needing a real failing database.
class _ThrowingExistingDeviceIdUseCase extends SignInUseCase {
  _ThrowingExistingDeviceIdUseCase(super.repository, {super.authService});

  @override
  Future<String?> existingDeviceId() async {
    throw StateError('drift read failed: db is locked');
  }
}

void main() {
  test(
    'test_EARS_ABUSE_5_returning_device_reaches_dashboard_across_N_launches',
    () async {
      // F1 regression: at least 6 consecutive "app launches" (fresh
      // `LoginController` instances, each mirroring a fresh process's
      // `onInit()`, sharing one local `AppDatabase`/`DeviceIdentityRepository`
      // exactly as one real device would across relaunches) on the SAME
      // account must ALL reach the dashboard — i.e. every one of
      // `SignInUseCase.call`'s invocations must complete, never be denied
      // by the per-account registration rate limit (5/24h), even though 6
      // exceeds that cap. `test_EARS_ABUSE_5_wired_sign_in_flow_denies_over
      // _limit_registration` (`sign_in_use_case_test.dart`) still proves the
      // opposite case — a genuinely new device hitting the cap is still
      // denied — untouched by this test.
      Get.testMode = true;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(
        db,
        rateLimiter: RateLimiter(db),
      );
      const accountUid = 'firebase-uid-relaunch-regression';
      final useCase = _TrackingSignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success(accountUid),
      );

      const launchCount = 6;
      for (var launch = 0; launch < launchCount; launch++) {
        final controller = LoginController(useCase);
        controller.onInit();
        await controller.signingIn.stream.firstWhere((signingIn) => !signingIn);
      }

      expect(
        useCase.successCount,
        launchCount,
        reason: 'every one of the $launchCount launches must have reached '
            'the point that navigates to /dashboard',
      );
      expect(
        useCase.deniedCount,
        0,
        reason: 'a returning device must never be denied by the '
            'registration rate limiter, no matter how many times it '
            'launches',
      );

      // Exactly ONE device identity row across all launches — the same
      // device reused every time, never re-registered.
      final rows = await db.select(db.deviceIdentities).get();
      expect(rows, hasLength(1));

      Get.reset();
      await db.close();
    },
  );

  test(
    'test_EARS_AUTH_3_existing_device_id_read_failure_completes_signin_'
    'instead_of_hanging',
    () async {
      // F6 regression (E13-T07 review round 3): `existingDeviceId()` used
      // to be called OUTSIDE `_signIn`'s try block. `onInit()` calls
      // `_signIn()` unawaited, so a throw from that read used to escape as
      // an unhandled async error: `signingIn` stayed `true` forever (the
      // "Signing in..." screen frozen permanently, reintroducing F1's
      // original symptom) and nothing was logged. This proves `_signIn()`
      // now completes, `signingIn` flips back to `false`, and no
      // unhandled async error escapes — i.e. the failure is caught and
      // handled the same way every other failure on this path already is
      // (EARS-AUTH-3).
      Get.testMode = true;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(
        db,
        rateLimiter: RateLimiter(db),
      );
      final useCase = _ThrowingExistingDeviceIdUseCase(
        repository,
        authService: FakeGoogleAuthService.success('firebase-uid-f6'),
      );

      final controller = LoginController(useCase);

      // Regression check: this must not hang. `onInit()` mirrors the real
      // unawaited call site; awaiting the `signingIn` stream directly
      // (rather than `onInit()` itself, which returns immediately either
      // way) is what actually proves `_signIn()` reached its `finally`
      // state rather than leaving `signingIn` stuck at `true` forever.
      controller.onInit();
      await controller.signingIn.stream
          .firstWhere((signingIn) => !signingIn)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail(
              'signingIn never flipped back to false — the '
              'existingDeviceId() failure escaped instead of being caught',
            ),
          );

      expect(
        controller.signingIn.value,
        isFalse,
        reason: 'a failure reading the existing device id must still '
            'leave the controller in a settled, non-frozen state',
      );

      // No device identity row was ever written — sign-in never actually
      // completed, consistent with the existing catch's behaviour for
      // every other failure on this path (no navigation, no partial
      // state).
      final rows = await db.select(db.deviceIdentities).get();
      expect(rows, isEmpty);

      Get.reset();
      await db.close();
    },
  );

  test('test_EARS_AUTH_2_device_id_is_secure_random', () {
    // EARS-AUTH-2 (FR-AUTH-003): the system SHALL generate a device
    // identity independent of the account identity.
    //
    // Random.secure() has no seeded constructor (unlike Random(seed)), so
    // a black-box test cannot directly observe "which PRNG produced this
    // value" — that fact is verified by review of
    // login_controller.dart against ADR-0005/FR-AUTH-003. What a runtime
    // test CAN verify, and what guards against a regression back to a
    // low-entropy or deterministic generator, is: correct format, and no
    // collisions across a large sample.
    final ids = {for (var i = 0; i < 500; i++) generateSecureDeviceId()};

    expect(ids, hasLength(500)); // distinct across every call
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
    }
  });

  group('test_E11_B06_first_sign_in_derives_device_id_from_local_identity',
      () {
    test(
      'a genuinely first-ever sign-in (no existingDeviceId) uses this '
      'device\'s own identity public key as its device id, hex-encoded — '
      'NOT a random generateSecureDeviceId() token',
      () async {
        Get.testMode = true;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = DeviceIdentityRepository(
          db,
          rateLimiter: RateLimiter(db),
        );
        final useCase = SignInUseCase(
          repository,
          authService: FakeGoogleAuthService.success('firebase-uid-e11b06'),
        );

        // Mirrors `lib/app/main.dart`'s own real first-launch construction
        // EXACTLY: `selfDeviceId: ''`, since `db.latestDeviceIdentity()`
        // is null pre-first-sign-in. This is the load-bearing part of
        // this test — `MessagingStack.create` reports `status:
        // unavailable` for this exact reason (empty selfDeviceId), which
        // is precisely the case `_deriveDeviceIdFromLocalIdentity` must
        // NOT gate on (see that method's own doc comment).
        final messagingStack = await MessagingStack.create(
          db: db,
          selfDeviceId: '',
        );
        expect(
          messagingStack.status.isReady,
          isFalse,
          reason: 'sanity check: this test only proves what it claims to '
              'if MessagingStack really is unavailable here, matching '
              'the real first-launch condition — if this ever starts '
              'passing `isReady`, the scenario has changed and this '
              'test needs re-examining, not silently trusting the '
              'derivation still gets exercised',
        );
        final identityKeyPair = await messagingStack.signalStore.getIdentityKeyPair();
        final expectedDeviceId =
            hexEncodeIdentityKey(identityKeyPair.getPublicKey());

        final controller = LoginController(
          useCase,
          messagingStack: messagingStack,
        );
        controller.onInit();
        await controller.signingIn.stream.firstWhere((signingIn) => !signingIn);

        final rows = await db.select(db.deviceIdentities).get();
        expect(rows, hasLength(1));
        expect(
          rows.single.deviceId,
          expectedDeviceId,
          reason: 'the persisted device id must be the hex-encoded '
              'identity public key, not a random token',
        );
        expect(
          rows.single.deviceId,
          matches(RegExp(r'^[0-9a-f]+$')),
          reason: 'never the base64 encoding — must contain no "/", "+" '
              'or "=" (Firebase path-safety, see identity_key_hex.dart)',
        );

        Get.reset();
        await db.close();
      },
    );

    test(
      'a RETURNING device (existingDeviceId present) keeps reusing its '
      'own already-registered id — the new derivation must never override '
      'an existing identity, even when a MessagingStack is available',
      () async {
        Get.testMode = true;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = DeviceIdentityRepository(
          db,
          rateLimiter: RateLimiter(db),
        );
        const accountUid = 'firebase-uid-e11b06-returning';
        final useCase = SignInUseCase(
          repository,
          authService: FakeGoogleAuthService.success(accountUid),
        );
        final messagingStack = await MessagingStack.create(
          db: db,
          selfDeviceId: '',
        );

        // First launch establishes the device identity (whatever it
        // derives to).
        final firstController = LoginController(
          useCase,
          messagingStack: messagingStack,
        );
        firstController.onInit();
        await firstController.signingIn.stream
            .firstWhere((signingIn) => !signingIn);
        final firstRows = await db.select(db.deviceIdentities).get();
        expect(firstRows, hasLength(1));
        final establishedDeviceId = firstRows.single.deviceId;

        // Second launch: same account, same MessagingStack (same identity
        // keypair still available) — must reuse the SAME id, not derive
        // (or generate) a new one.
        final secondController = LoginController(
          useCase,
          messagingStack: messagingStack,
        );
        secondController.onInit();
        await secondController.signingIn.stream
            .firstWhere((signingIn) => !signingIn);

        final secondRows = await db.select(db.deviceIdentities).get();
        expect(
          secondRows,
          hasLength(1),
          reason: 'still exactly one device identity row — a returning '
              'device must never register a second one',
        );
        expect(secondRows.single.deviceId, establishedDeviceId);

        Get.reset();
        await db.close();
      },
    );

    test(
      'when no MessagingStack is available at all (e.g. Get.find finds '
      'nothing registered, no override given), sign-in still completes '
      'via the pre-existing generateSecureDeviceId() fallback — this '
      'derivation is additive, never a new way to fail sign-in',
      () async {
        Get.testMode = true;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = DeviceIdentityRepository(
          db,
          rateLimiter: RateLimiter(db),
        );
        final useCase = SignInUseCase(
          repository,
          authService: FakeGoogleAuthService.success('firebase-uid-no-stack'),
        );

        // No `messagingStack:` override, and nothing registered via
        // `Get.put` — `_resolveMessagingStack` must fail closed to `null`
        // (caught, logged), not throw.
        final controller = LoginController(useCase);
        controller.onInit();
        await controller.signingIn.stream.firstWhere((signingIn) => !signingIn);

        final rows = await db.select(db.deviceIdentities).get();
        expect(rows, hasLength(1));
        expect(
          rows.single.deviceId,
          matches(RegExp(r'^[0-9a-f]{16}$')),
          reason: 'falls back to generateSecureDeviceId()\'s own '
              '16-hex-char shape, unchanged from before this fix',
        );

        Get.reset();
        await db.close();
      },
    );
  });
}
