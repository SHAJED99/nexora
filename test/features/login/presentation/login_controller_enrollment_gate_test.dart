// features/login/presentation — E12-T03 (FR-RECOVER-001): the new branch
// point in `LoginController._signIn()`. `SignInUseCase` is stubbed to skip
// the real Google/Firebase calls entirely (this task explicitly does not
// change `SignInUseCase` — see login_controller.dart's own header) while
// still performing the same local `DeviceIdentityRepository` writes the
// real use case does, so `LoginController`'s new
// `latestDeviceIdentity()`-read logic exercises a real in-memory Drift
// table, not a mock. `FirebaseMetadataService.readOwnDeviceIds` is stubbed
// directly (a higher-level seam than the raw-read seam
// `firebase_metadata_service_own_devices_test.dart` exercises, since this
// file is testing LoginController's own branch, not that service's
// extraction logic, which is already covered there).
//
// Navigation is proven the same way
// `conversations_groups_test.dart` proves its own cross-controller
// navigation: a real `GetMaterialApp` with `getPages` recording which
// route was actually reached, then asserting `Get.currentRoute`.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';

/// Performs the same LOCAL writes the real `SignInUseCase.call` performs
/// (`createDeviceIdentity` + `markSignedIn`), skipping `GoogleAuthService`/
/// `FirebaseMetadataService.registerDevice` entirely — this test is about
/// `LoginController`'s own branch, not `SignInUseCase`'s (unchanged,
/// already covered by `sign_in_use_case_test.dart`).
class _StubSignInUseCase extends SignInUseCase {
  _StubSignInUseCase(this._deviceIdentityRepository, {this.accountUid})
      : super(_deviceIdentityRepository);

  final DeviceIdentityRepository _deviceIdentityRepository;
  final String? accountUid;

  @override
  Future<void> call(String deviceId) async {
    final id = await _deviceIdentityRepository.createDeviceIdentity(deviceId);
    await _deviceIdentityRepository.markSignedIn(id, accountUid: accountUid);
  }
}

/// Stubs `readOwnDeviceIds` directly with a caller-supplied builder, so each
/// test controls exactly what "other registered device ids" LoginController
/// sees, including cases that depend on knowing the just-generated device id
/// (which the test itself cannot predict — `generateSecureDeviceId()` is
/// random).
class _StubFirebaseMetadataService extends FirebaseMetadataService {
  _StubFirebaseMetadataService(this._builder);

  final Future<Set<String>> Function(String uid) _builder;
  String? capturedUid;

  @override
  Future<Set<String>> readOwnDeviceIds(String uid) async {
    capturedUid = uid;
    return _builder(uid);
  }
}

AppDatabase _openTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  /// Puts [controller], mounts a real `GetMaterialApp` with `/login` as the
  /// initial route (so `onInit`'s `_signIn()` fires the same way it would in
  /// the running app), plus placeholder `/dashboard` and
  /// `/device-enrollment` pages that record when they are reached, then
  /// settles.
  Future<void> pumpLoginFlow(
    WidgetTester tester,
    LoginController controller,
    List<String> reached,
  ) async {
    // The real `GetMaterialApp` (and its Navigator) must exist BEFORE
    // `LoginController` is put — `onInit()` fires `_signIn()` immediately,
    // synchronously on `Get.put`, and `Get.offNamed` is a no-op with no
    // navigator attached yet.
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/login',
        getPages: [
          GetPage<dynamic>(
            name: '/login',
            page: () => const SizedBox.shrink(),
          ),
          GetPage<dynamic>(
            name: '/dashboard',
            page: () {
              reached.add('/dashboard');
              return const SizedBox.shrink();
            },
          ),
          GetPage<dynamic>(
            name: '/device-enrollment',
            page: () {
              reached.add('/device-enrollment');
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
    Get.put<LoginController>(controller);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'test_EARS_RECOVER_8_other_devices_exist_routes_to_enrollment',
    (tester) async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = DeviceIdentityRepository(db);
      final signInUseCase = _StubSignInUseCase(repository, accountUid: 'uid-1');
      // A fixed id that can never equal the randomly-generated device id
      // this run produces (`generateSecureDeviceId` is a 16-hex-char
      // string; this value is not hex-shaped at all).
      final metadataService = _StubFirebaseMetadataService(
        (uid) async => {'some-other-registered-device'},
      );
      final controller = LoginController(
        signInUseCase,
        metadataService: metadataService,
        deviceIdentityRepository: repository,
      );

      final reached = <String>[];
      await pumpLoginFlow(tester, controller, reached);

      expect(reached, ['/device-enrollment']);
      expect(Get.currentRoute, '/device-enrollment');
      expect(metadataService.capturedUid, 'uid-1');
    },
  );

  testWidgets(
    'test_EARS_RECOVER_9_first_device_routes_to_dashboard_unchanged',
    (tester) async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = DeviceIdentityRepository(db);
      final signInUseCase = _StubSignInUseCase(repository, accountUid: 'uid-1');
      // "No OTHER registered device ids" -- the only id the account has
      // registered is this device's own just-created one. Read it back
      // from the same repository the controller itself reads, rather than
      // guessing the random id.
      final metadataService = _StubFirebaseMetadataService((uid) async {
        final latest = await repository.latestDeviceIdentity();
        return {if (latest != null) latest.deviceId};
      });
      final controller = LoginController(
        signInUseCase,
        metadataService: metadataService,
        deviceIdentityRepository: repository,
      );

      final reached = <String>[];
      await pumpLoginFlow(tester, controller, reached);

      expect(reached, ['/dashboard']);
      expect(Get.currentRoute, '/dashboard');
    },
  );

  testWidgets(
    'a first device with no Firebase accountUid at all still routes to '
    'dashboard unchanged, without ever calling readOwnDeviceIds',
    (tester) async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = DeviceIdentityRepository(db);
      // No accountUid -- mirrors a credential with no Firebase user
      // (SignInUseCase's own existing null-check, unchanged by this task).
      final signInUseCase = _StubSignInUseCase(repository);
      final metadataService = _StubFirebaseMetadataService(
        (uid) async => {'should-never-be-reached'},
      );
      final controller = LoginController(
        signInUseCase,
        metadataService: metadataService,
        deviceIdentityRepository: repository,
      );

      final reached = <String>[];
      await pumpLoginFlow(tester, controller, reached);

      expect(reached, ['/dashboard']);
      expect(metadataService.capturedUid, isNull);
    },
  );
}
