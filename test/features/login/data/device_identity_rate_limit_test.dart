// E13-T02 (FR-ABUSE-001) -- rate-limiting device-identity registration per
// account uid. This task's chosen limit (§3): `maxCount: 5`,
// `window: 24 hours`, keyed by the LOCAL account uid registering a new
// device (`device_identity_repository.dart`'s own comment documents the
// full reasoning).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';

void main() {
  late AppDatabase db;
  late RateLimiter limiter;
  late DeviceIdentityRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    limiter = RateLimiter(db);
    repository = DeviceIdentityRepository(db, rateLimiter: limiter);
  });

  tearDown(() => db.close());

  test(
    'test_EARS_ABUSE_5_device_registration_over_limit_is_denied',
    () async {
      const accountUid = 'account-spammer';
      // Exhaust the configured window (maxCount: 5) with legitimate
      // registrations under the same account.
      for (var i = 0; i < 5; i++) {
        final id = await repository.createDeviceIdentity(
          'device-$i',
          accountUid: accountUid,
        );
        expect(id, isNonNegative);
      }

      // The 6th registration within the same window must be denied by
      // throwing an `AppFailure` -- matching `sign_in_use_case.dart`'s
      // existing error-mapping convention (propagate, never swallow) --
      // BEFORE the write, so no 6th device-identity row is created.
      await expectLater(
        () => repository.createDeviceIdentity(
          'device-6',
          accountUid: accountUid,
        ),
        throwsA(isA<AppFailure>()),
      );

      final rows = await db.select(db.deviceIdentities).get();
      expect(
        rows.length,
        5,
        reason: 'the denied 6th registration must not have written a row',
      );
    },
  );

  test(
    'test_device_registration_under_limit_still_succeeds',
    () async {
      const accountUid = 'account-occasional';
      // Well under the configured max (5) -- normal registration proceeds
      // untouched by the new gate, matching a user reasonably registering
      // 2-3 devices in a sitting (task §3).
      for (var i = 0; i < 3; i++) {
        final id = await repository.createDeviceIdentity(
          'device-$i',
          accountUid: accountUid,
        );
        expect(id, isNonNegative);
      }
    },
  );

  test(
    'test_device_registration_two_accounts_are_independent',
    () async {
      // Exhausting one account's bucket must never affect another
      // account's own limit.
      const accountA = 'account-a';
      const accountB = 'account-b';
      for (var i = 0; i < 5; i++) {
        await repository.createDeviceIdentity('a-device-$i', accountUid: accountA);
      }
      await expectLater(
        () => repository.createDeviceIdentity('a-device-6', accountUid: accountA),
        throwsA(isA<AppFailure>()),
      );

      final idForB = await repository.createDeviceIdentity(
        'b-device-0',
        accountUid: accountB,
      );
      expect(idForB, isNonNegative);
    },
  );

  test(
    'test_device_registration_without_account_uid_is_unaffected',
    () async {
      // The one real production caller, `sign_in_use_case.dart`, cannot
      // be edited (outside this task's `files:` fence) to pass an
      // `accountUid` through -- confirms that call shape is entirely
      // unaffected by this task (byte-for-byte the same as before
      // E13-T02), never denies regardless of call volume.
      for (var i = 0; i < 20; i++) {
        final id = await repository.createDeviceIdentity('device-no-uid-$i');
        expect(id, isNonNegative);
      }
    },
  );
}
