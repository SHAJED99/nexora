// Walking-skeleton widget test (E00-T05, updated E01-T01): proves
// welcome -> login navigates on "Continue with Google", the sign-in use
// case performs one real Drift write (through a test-doubled
// GoogleAuthService — no real Google/Firebase network calls in this
// suite), and the app lands on the placeholder home screen able to read
// that row back.
//
// Uses an in-memory Drift database — no real filesystem I/O.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/home/presentation/home_controller.dart';
import 'package:nexora/features/home/presentation/home_view.dart';
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
    'welcome -> Continue with Google -> login -> Drift write -> home',
    (WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(db);
      final signInUseCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success('firebase-uid-test'),
      );

      Get.lazyPut(WelcomeController.new);
      Get.lazyPut(() => LoginController(signInUseCase));
      Get.lazyPut(() => HomeController(repository));

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/welcome',
          getPages: [
            GetPage<dynamic>(name: '/welcome', page: () => const WelcomeView()),
            GetPage<dynamic>(name: '/login', page: () => const LoginView()),
            GetPage<dynamic>(name: '/home', page: () => const HomeView()),
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

      // ... and it navigated onward to the placeholder home screen.
      expect(find.text('Signing in with Google...'), findsNothing);
      expect(
        find.textContaining('Signed in'),
        findsOneWidget,
      );

      await db.close();
    },
  );
}
