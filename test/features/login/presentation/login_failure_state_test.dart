// features/login/presentation — `E01-B02`: the login screen's `error`
// state and its retry action.
//
// The bug this pins, found on real hardware (two Android devices,
// 2026-09-28): `_signIn()`'s `catch` cleared `signingIn` but the heading was
// a `const Text('Signing in with Google...')`, so after a genuine failure
// the screen went on claiming it was signing in — with no spinner, no
// error, and no way forward. The log showed `auth.google_sign_in_failed` at
// 21:06:41 and the screen still read "Signing in with Google…" at 21:08:12.
// The only escape was force-stopping the app, which a real user cannot do.
//
// `SignInUseCase` is stubbed (no Google/Firebase), the same seam
// `login_controller_enrollment_gate_test.dart` already establishes — but
// the assertions below are about observable controller state and the real
// rendered widget tree, never about the stub.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';
import 'package:nexora/features/login/presentation/login_view.dart';

/// Fails the first [failures] attempts, then succeeds — so one fixture
/// covers "it failed" and "the retry worked" without swapping the seam
/// mid-test.
class _FlakySignInUseCase extends SignInUseCase {
  _FlakySignInUseCase(this._repository, {required this.failures})
      : super(_repository);

  final DeviceIdentityRepository _repository;
  final int failures;
  int attempts = 0;

  @override
  Future<void> call(String deviceId) async {
    attempts++;
    if (attempts <= failures) {
      throw Exception('simulated google sign-in failure');
    }
    final id = await _repository.createDeviceIdentity(deviceId);
    await _repository.markSignedIn(id, accountUid: 'uid-1');
  }
}

/// The post-sign-in Firebase read `_signIn()` performs. Stubbed to an empty
/// set (no other registered devices -> the dashboard branch); the REAL
/// service throws without a Firebase app, which would make every "success"
/// case fail for a reason that has nothing to do with this bug.
class _StubMetadataService extends FirebaseMetadataService {
  @override
  Future<Set<String>> readOwnDeviceIds(String uid) async => <String>{};
}

void main() {
  late AppDatabase db;
  late DeviceIdentityRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DeviceIdentityRepository(db);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  /// `Get.put` FIRST: `LoginView` is a `GetView` and resolves its
  /// controller during `build`, so registering after `pumpWidget` throws
  /// "LoginController not found". `onInit` fires `_signIn()` immediately on
  /// put; with no navigator attached yet a successful run's `Get.offNamed`
  /// is simply a no-op, which is fine — every assertion below is about the
  /// login screen itself, never about where a success navigates to (that is
  /// `login_controller_enrollment_gate_test.dart`'s subject).
  Future<void> pump(WidgetTester tester, LoginController controller) async {
    Get.put<LoginController>(controller);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/login',
        getPages: [
          GetPage<dynamic>(name: '/login', page: () => const LoginView()),
          GetPage<dynamic>(
            name: '/dashboard',
            page: () => const SizedBox.shrink(),
          ),
          GetPage<dynamic>(
            name: '/device-enrollment',
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'test_E01_B02_a_failed_sign_in_stops_claiming_it_is_signing_in',
    (tester) async {
      final controller = LoginController(
        _FlakySignInUseCase(repository, failures: 1),
        deviceIdentityRepository: repository,
      );
      await pump(tester, controller);

      expect(controller.signingIn.value, isFalse);
      expect(controller.signInFailed.value, isTrue);

      // THE regression: the heading must no longer say this.
      expect(find.text('Signing in with Google...'), findsNothing);
      expect(find.text("Couldn't sign in. Try again."), findsOneWidget);
    },
  );

  testWidgets(
    'test_E01_B02_a_failed_sign_in_leaves_no_permanent_spinner',
    (tester) async {
      final controller = LoginController(
        _FlakySignInUseCase(repository, failures: 1),
        deviceIdentityRepository: repository,
      );
      await pump(tester, controller);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'test_E01_B02_a_failed_sign_in_offers_a_retry_action',
    (tester) async {
      final controller = LoginController(
        _FlakySignInUseCase(repository, failures: 1),
        deviceIdentityRepository: repository,
      );
      await pump(tester, controller);

      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets(
    'test_E01_B02_tapping_retry_runs_a_second_attempt_and_succeeds',
    (tester) async {
      final useCase = _FlakySignInUseCase(repository, failures: 1);
      final controller = LoginController(
        useCase,
        metadataService: _StubMetadataService(),
        deviceIdentityRepository: repository,
      );
      await pump(tester, controller);
      expect(useCase.attempts, 1);
      expect(controller.signInFailed.value, isTrue);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      // A real second attempt ran, and the failure state cleared rather
      // than sticking around behind a successful sign-in.
      expect(useCase.attempts, 2);
      expect(controller.signInFailed.value, isFalse);
      expect(find.text("Couldn't sign in. Try again."), findsNothing);
    },
  );

  testWidgets(
    'test_E01_B02_a_successful_sign_in_never_shows_the_failure_state',
    (tester) async {
      // Unlike the failure cases, a SUCCESS navigates away, so a real
      // navigator has to exist before `_signIn()` runs — the app is pumped
      // on a neutral route first and the controller registered after, then
      // `/login` is rendered explicitly to assert what the screen shows.
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/boot',
          getPages: [
            GetPage<dynamic>(
              name: '/boot',
              page: () => const SizedBox.shrink(),
            ),
            GetPage<dynamic>(name: '/login', page: () => const LoginView()),
            GetPage<dynamic>(
              name: '/dashboard',
              page: () => const SizedBox.shrink(),
            ),
            GetPage<dynamic>(
              name: '/device-enrollment',
              page: () => const SizedBox.shrink(),
            ),
          ],
        ),
      );
      final controller = LoginController(
        _FlakySignInUseCase(repository, failures: 0),
        metadataService: _StubMetadataService(),
        deviceIdentityRepository: repository,
      );
      Get.put<LoginController>(controller);
      await tester.pumpAndSettle();

      expect(controller.signInFailed.value, isFalse);

      // Asserted on the controller, not by re-rendering `/login`: a
      // successful sign-in navigates away and GetX disposes the route's
      // controller with it, so building `LoginView` again here would fail
      // to resolve one. `signingIn` false + `signInFailed` false is exactly
      // the state that makes the view render neither the error copy nor the
      // retry action (the two `findsNothing` cases are covered from the
      // rendered tree in the failure tests above, where the screen stays).
    },
  );

  test(
    'test_E01_B02_retry_is_a_no_op_while_an_attempt_is_already_in_flight',
    () async {
      final useCase = _FlakySignInUseCase(repository, failures: 0);
      final controller = LoginController(
        useCase,
        deviceIdentityRepository: repository,
      );
      // Not `onInit`-driven here: drive the guard directly, so a double tap
      // during a slow real sign-in cannot start a second concurrent attempt.
      controller.signingIn.value = true;
      await controller.retry();
      expect(useCase.attempts, 0);
    },
  );
}
