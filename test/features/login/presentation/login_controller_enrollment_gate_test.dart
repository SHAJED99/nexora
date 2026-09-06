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
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/observability/observability_service.dart';
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

/// E12-B01 regression fixture: mirrors the real `SignInUseCase.call` +
/// `FirebaseMetadataService.registerDevice` pair closely enough to
/// reproduce the bug's own registry accumulation (its "Reviewer probe":
/// `launch 1 -> registry=1`, `launch 2 -> registry=2`, ...) across
/// multiple simulated app launches — local Drift write
/// (`createDeviceIdentity`/`markSignedIn`), then an ADDITIVE registration
/// of `deviceId` into a shared registry set, exactly what a real relaunch
/// does across multiple real launches of `LoginController`, without
/// needing Google/Firebase network calls.
class _RegistryTrackingSignInUseCase extends SignInUseCase {
  _RegistryTrackingSignInUseCase(
    this._deviceIdentityRepository,
    this._registry, {
    required this.accountUid,
  }) : super(_deviceIdentityRepository);

  final DeviceIdentityRepository _deviceIdentityRepository;
  final Set<String> _registry;
  final String accountUid;

  @override
  Future<void> call(String deviceId) async {
    final id = await _deviceIdentityRepository.createDeviceIdentity(deviceId);
    await _deviceIdentityRepository.markSignedIn(id, accountUid: accountUid);
    _registry.add(deviceId);
  }
}

/// Reads back whatever `_RegistryTrackingSignInUseCase` has accumulated —
/// the registry IS the "other registered device ids" source of truth for
/// this fixture, same role `FirebaseMetadataService.readOwnDeviceIds`
/// plays for real against Firebase.
class _RegistryBackedMetadataService extends FirebaseMetadataService {
  _RegistryBackedMetadataService(this._registry);

  final Set<String> _registry;

  @override
  Future<Set<String>> readOwnDeviceIds(String uid) async => Set.of(_registry);
}

/// E12-B08 (Defect 1) regression fixture: a `DeviceIdentityRepository`
/// whose `latestDeviceIdentity()` always throws, simulating a Drift error
/// or corrupt row on the read `LoginController` performs both before
/// minting a device id (E12-B01) and after sign-in (E12-T03/E12-B08).
class _ThrowingDeviceIdentityRepository extends DeviceIdentityRepository {
  _ThrowingDeviceIdentityRepository(super.db);

  @override
  Future<DeviceIdentity?> latestDeviceIdentity() {
    throw StateError('simulated Drift read failure');
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

  testWidgets(
    'test_EARS_RECOVER_9_returning_device_reaches_dashboard_on_every_relaunch',
    (tester) async {
      // E12-B01 regression: before the fix, every launch minted a brand
      // new random device id, so the registry grew by one per launch and
      // the enrollment gate misfired from launch 2 onward. This proves
      // 6 consecutive launches on the SAME account/device all reach
      // `/dashboard`, and that the registry never grows past its first
      // entry.
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = DeviceIdentityRepository(db);
      final registry = <String>{};
      final signInUseCase = _RegistryTrackingSignInUseCase(
        repository,
        registry,
        accountUid: 'uid-1',
      );
      final metadataService = _RegistryBackedMetadataService(registry);

      for (var launch = 1; launch <= 6; launch++) {
        // Each iteration simulates a brand-new app launch: Get's own
        // routing/dependency state (NOT this test's repository/registry,
        // which are plain local objects standing in for real persisted
        // state) must be fully reset, or the navigator retains the
        // previous launch's `/dashboard` as its current route and never
        // re-fires the `getPages` callback this test asserts against.
        if (launch > 1) {
          // Fully unmount the previous launch's widget tree before
          // resetting Get's routing/dependency state, or the leftover
          // element tree and Get's internal navigator disagree about what
          // is currently mounted.
          await tester.pumpWidget(const SizedBox.shrink());
          Get.reset();
        }
        final controller = LoginController(
          signInUseCase,
          metadataService: metadataService,
          deviceIdentityRepository: repository,
        );

        final reached = <String>[];
        await pumpLoginFlow(tester, controller, reached);

        expect(
          reached,
          ['/dashboard'],
          reason:
              'launch $launch should reach /dashboard, registry='
              '${registry.length} (${registry.join(', ')})',
        );
        expect(Get.currentRoute, '/dashboard');
      }

      // The same device id was reused on every launch -- the registry
      // never accumulated a second entry for this one device.
      expect(registry, hasLength(1));
    },
  );

  testWidgets(
    'test_EARS_AUTH_3_device_identity_read_failure_falls_through_to_dashboard',
    (tester) async {
      // E12-B08 (Defect 1) regression: a throwing `DeviceIdentityRepository`
      // must not turn a succeeded sign-in into a mapped failure -- it must
      // fall through to `/dashboard`, and the failure must be logged
      // (E12-B08 Defect 2's own fix: the read failure paths in this method
      // now log via `ObservabilityService`, captured here through Dart's
      // zone `print` hook since `ObservabilityService` has no test seam of
      // its own -- see this file's Run log for why one wasn't added).
      final logs = <String>[];
      await ObservabilityService.instance.init();

      await runZoned(
        () async {
          final db = _openTestDatabase();
          addTearDown(db.close);
          final repository = DeviceIdentityRepository(db);
          final signInUseCase = _StubSignInUseCase(
            repository,
            accountUid: 'uid-1',
          );
          final metadataService = _StubFirebaseMetadataService(
            (uid) async => {'should-never-be-reached'},
          );
          final throwingRepository = _ThrowingDeviceIdentityRepository(
            _openTestDatabase(),
          );
          final controller = LoginController(
            signInUseCase,
            metadataService: metadataService,
            deviceIdentityRepository: throwingRepository,
          );

          final reached = <String>[];
          await pumpLoginFlow(tester, controller, reached);

          expect(reached, ['/dashboard']);
          expect(Get.currentRoute, '/dashboard');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ),
      );

      expect(
        logs.any(
          (line) => line.contains('recovery.device_identity_read_failed'),
        ),
        isTrue,
        reason:
            'expected the pre-sign-in identity read failure to be logged, '
            'got: $logs',
      );
      expect(
        logs.any(
          (line) => line.contains('recovery.device_identity_lookup_failed'),
        ),
        isTrue,
        reason:
            'expected the post-sign-in identity lookup failure to be '
            'logged, got: $logs',
      );
    },
  );
}
