// Walking-skeleton widget test (E00-T05, updated E01-T01, E06-T12): proves
// welcome -> login navigates on "Continue with Google", the sign-in use
// case performs one real Drift write (through a test-doubled
// GoogleAuthService — no real Google/Firebase network calls in this
// suite), and the app lands on the post-login destination able to read that
// row back.
//
// E06-T12: `LoginController` now navigates to `/dashboard`
// (design/screens/dashboard.md), superseding this walking skeleton's
// `/home` placeholder (see that task's own Deviations for why this file —
// outside its `files:` fence — needed this one-line, disclosed update to
// stay green: `/dashboard` requires a full `MessagingStack`/`AppBinding`
// this genesis test deliberately never constructs, so the destination page
// registered here is a minimal stub, not the real `DashboardView` — this
// test's actual assertions are about the login->navigation seam and the
// real Drift write/read-back, both unaffected by which widget the
// destination route renders).
//
// Uses an in-memory Drift database — no real filesystem I/O.
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';
import 'package:nexora/features/login/presentation/login_view.dart';
import 'package:nexora/features/welcome/presentation/welcome_controller.dart';
import 'package:nexora/features/welcome/presentation/welcome_view.dart';

import 'support/fake_google_auth_service.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets(
    'welcome -> Continue with Google -> login -> Drift write -> dashboard',
    (WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(db);
      final signInUseCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success('firebase-uid-test'),
      );

      Get.lazyPut(WelcomeController.new);
      Get.lazyPut(() => LoginController(signInUseCase));

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/welcome',
          getPages: [
            GetPage<dynamic>(name: '/welcome', page: () => const WelcomeView()),
            GetPage<dynamic>(name: '/login', page: () => const LoginView()),
            // A minimal stub, not the real DashboardView (E06-T12) — this
            // test proves the login->navigation seam and the real Drift
            // write/read-back, not the Dashboard screen's own content
            // (covered by test/features/dashboard/).
            GetPage<dynamic>(
              name: '/dashboard',
              page: () => const Text('dashboard placeholder'),
            ),
          ],
        ),
      );

      // Starts on welcome.
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(await db.latestDeviceIdentity(), isNull);

      // Tap -> navigates to login, showing the transient "signing in" copy.
      await tester.tap(find.text('Continue with Google'));
      await tester.pump(); // process the tap
      await tester.pump(); // process the route transition
      expect(find.text('Signing in with Google...'), findsOneWidget);

      // Let the (50ms) stubbed sign-in delay elapse and the app navigate on.
      await tester.pumpAndSettle();

      // The sign-in use case has run: one real Drift row, written through
      // controller -> use case -> repository -> Drift.
      final identity = await db.latestDeviceIdentity();
      expect(identity, isNotNull);
      expect(identity!.signedIn, isTrue);

      // ... and it navigated onward to /dashboard (E06-T12), not /home.
      expect(find.text('Signing in with Google...'), findsNothing);
      expect(find.text('dashboard placeholder'), findsOneWidget);

      await db.close();
    },
  );

  testWidgets(
    'F1 regression (E13-T07 review round 2, S1/S2): a returning device '
    '(one that already has a local identity, e.g. relaunch #6+ of the '
    'app) still reaches the dashboard through the real welcome -> login '
    '-> dashboard navigation, never denied by the per-account '
    'registration rate limiter',
    (WidgetTester tester) async {
      // Before this fix, `LoginController._signIn` minted a brand-new
      // random device id on EVERY launch and always went through
      // `SignInUseCase`'s registration path, gated by
      // `DeviceIdentityRepository`'s per-account rate limit
      // (5 registrations / 24h, E13-T02) — so a device that already had a
      // local identity (i.e. every relaunch past the very first) would
      // still count against that same limit and could be denied. A real
      // `RateLimiter` is used here, pre-loaded (via direct repository
      // writes, no UI) with 5 PRIOR registrations under the SAME account —
      // exactly at the cap — so this device's OWN relaunch, through the
      // real welcome->login->dashboard navigation, proves it is never
      // counted as attempt #6.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(
        db,
        rateLimiter: RateLimiter(db),
      );
      const accountUid = 'firebase-uid-returning-widget';

      // 5 OTHER devices already registered under this account — the cap
      // (`_maxDeviceRegistrationsPerWindow` = 5) is already exhausted.
      // Written directly through `db` (bypassing the repository's own
      // gate) purely to seed test history — these are meant to represent
      // registrations that already happened in the past, not attempts this
      // test itself is making.
      for (var i = 0; i < 5; i++) {
        final id = await db.createDeviceIdentity('other-device-$i');
        await db.markSignedIn(id, accountUid: accountUid);
      }
      // THIS device's own existing local identity — the one
      // `LoginController` must read back and reuse instead of minting a
      // fresh id (which would be attempt #6 and denied).
      final ownId = await db.createDeviceIdentity('this-devices-own-id');
      await db.markSignedIn(ownId, accountUid: accountUid);

      final signInUseCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success(accountUid),
      );

      Get.lazyPut(WelcomeController.new);
      Get.lazyPut(() => LoginController(signInUseCase));

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/welcome',
          getPages: [
            GetPage<dynamic>(name: '/welcome', page: () => const WelcomeView()),
            GetPage<dynamic>(name: '/login', page: () => const LoginView()),
            GetPage<dynamic>(
              name: '/dashboard',
              page: () => const Text('dashboard placeholder'),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump(); // process the tap
      await tester.pump(); // process the route transition
      await tester.pumpAndSettle();

      // Reaching the dashboard, not stuck on "Signing in..." with no
      // navigation and no error surfaced, is the whole proof here — the
      // exact user-visible symptom F1 describes.
      expect(
        find.text('Signing in with Google...'),
        findsNothing,
      );
      expect(
        find.text('dashboard placeholder'),
        findsOneWidget,
        reason: 'a returning device must reach /dashboard — a rate-limit '
            'denial would leave the user stuck on "Signing in..." with no '
            'navigation and no error affordance',
      );

      // Still exactly 6 rows total (5 other devices + this one) — this
      // device's relaunch reused its own row rather than writing a 7th.
      final rows = await db.select(db.deviceIdentities).get();
      expect(rows, hasLength(6));

      await db.close();
    },
  );
}
