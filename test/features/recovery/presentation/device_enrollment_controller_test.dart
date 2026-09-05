// features/recovery/presentation — E12-T03 (FR-RECOVER-001/
// FR-RECOVER-002), fixed by E12-B03.
//
// `FirebaseMetadataService.readEnrollmentGrant` is stubbed at its own raw
// read seam (`readEnrollmentGrantData`) so these tests never touch a real
// `FirebaseDatabase`/platform channel -- same seam-stubbing pattern
// `firebase_metadata_service_test.dart` already uses for its own reader
// tests.
//
// Navigation (EARS-RECOVER-10) is proven with a real `GetMaterialApp`,
// same pattern `conversations_groups_test.dart`/
// `login_controller_enrollment_gate_test.dart` use: a `getPages` list
// records which route was actually reached, then `Get.currentRoute` is
// asserted.
//
// `pollInterval`/`maxPolls` are always overridden to small values in these
// tests -- `flutter_test`'s `testWidgets` runs inside an automatic
// `FakeAsync` zone, so `tester.pump(duration)` advances the `Timer.periodic`
// this controller creates without any real wall-clock wait (same reasoning
// `background_policy_test.dart`'s composition tests document for their own
// real `Timer.periodic`, which uses real delays instead because it runs
// under plain `test()`, not `testWidgets()`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_controller.dart';

/// A test double for `FirebaseMetadataService.readEnrollmentGrant` (E12-B03)
/// -- reports a fixed, controllable grant-node value instead of touching a
/// real `FirebaseDatabase`/platform channel. Counts calls so the dispose
/// test can prove polling actually stopped.
class _StubFirebaseMetadataService extends FirebaseMetadataService {
  _StubFirebaseMetadataService(this._raw);

  final Object? _raw;
  int readCalls = 0;

  @override
  Future<Object?> readEnrollmentGrantData(String uid, String newDeviceId) async {
    readCalls++;
    return _raw;
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    // Disposes any controller still registered via Get.put -- this is what
    // actually stops a still-running Timer.periodic before the test ends
    // (same pattern dashboard_controller_test.dart documents for its own
    // Get.reset() teardown).
    Get.reset();
  });

  Future<void> pumpEnrollmentFlow(
    WidgetTester tester,
    DeviceEnrollmentController controller,
    List<String> reached,
  ) async {
    // The real `GetMaterialApp` (and its Navigator) must exist BEFORE
    // `DeviceEnrollmentController` is put -- `onInit()` starts polling
    // immediately, synchronously on `Get.put`, and `Get.offNamed` is a
    // no-op with no navigator attached yet.
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/device-enrollment',
        getPages: [
          GetPage<dynamic>(
            name: '/device-enrollment',
            page: () => const SizedBox.shrink(),
          ),
          GetPage<dynamic>(
            name: '/dashboard',
            page: () {
              reached.add('/dashboard');
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
    Get.put<DeviceEnrollmentController>(controller);
    addTearDown(controller.onClose);
    await tester.pump();
  }

  group('checkApproval (E12-B03)', () {
    test(
      'test_EARS_RECOVER_1_a_real_grant_node_reads_as_approved',
      () async {
        final stub = _StubFirebaseMetadataService({
          'approvedByDeviceId': 'trusted-device',
          'approvedAt': 1000,
        });
        final controller = DeviceEnrollmentController(
          accountUid: 'uid-1',
          thisDeviceId: 'this-device',
          firebaseMetadataService: stub,
        );
        addTearDown(controller.onClose);

        expect(await controller.checkApproval(), isTrue);
      },
    );

    test(
      'test_EARS_RECOVER_1_no_grant_node_reads_as_not_approved',
      () async {
        // E12-B03 regression: before this fix, `checkApproval()` went
        // through `RelationshipSyncService.pull`/`ConflictResolver
        // .resolveTrust`, which could never raise trust for a device with
        // no local relationship row -- this and the tests below prove the
        // NEW mechanism (a direct grant-node read) behaves correctly
        // instead, independent of that broken path.
        final stub = _StubFirebaseMetadataService(null);
        final controller = DeviceEnrollmentController(
          accountUid: 'uid-1',
          thisDeviceId: 'this-device',
          firebaseMetadataService: stub,
        );
        addTearDown(controller.onClose);

        expect(await controller.checkApproval(), isFalse);
      },
    );

    test(
      'malformed grant data (not a Map, or missing approvedByDeviceId) '
      'reads as not approved, never throws',
      () async {
        final controllerA = DeviceEnrollmentController(
          accountUid: 'uid-1',
          thisDeviceId: 'this-device',
          firebaseMetadataService:
              _StubFirebaseMetadataService('not-a-map'),
        );
        addTearDown(controllerA.onClose);
        expect(await controllerA.checkApproval(), isFalse);

        final controllerB = DeviceEnrollmentController(
          accountUid: 'uid-1',
          thisDeviceId: 'this-device',
          firebaseMetadataService:
              _StubFirebaseMetadataService({'approvedAt': 1000}),
        );
        addTearDown(controllerB.onClose);
        expect(await controllerB.checkApproval(), isFalse);
      },
    );
  });

  testWidgets(
    'test_EARS_RECOVER_10_approval_detected_navigates_to_dashboard',
    (tester) async {
      final stub = _StubFirebaseMetadataService({
        'approvedByDeviceId': 'trusted-device',
        'approvedAt': 1000,
      });
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        firebaseMetadataService: stub,
        pollInterval: const Duration(milliseconds: 10),
      );

      final reached = <String>[];
      await pumpEnrollmentFlow(tester, controller, reached);
      await tester.pump(const Duration(milliseconds: 20));

      expect(reached, ['/dashboard']);
      expect(Get.currentRoute, '/dashboard');
      expect(controller.state.value, EnrollmentState.waiting);
    },
  );

  testWidgets(
    'not yet approved stays in waiting and keeps polling on the bounded '
    'interval',
    (tester) async {
      final stub = _StubFirebaseMetadataService(null);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        firebaseMetadataService: stub,
        pollInterval: const Duration(milliseconds: 10),
        maxPolls: 100,
      );

      final reached = <String>[];
      await pumpEnrollmentFlow(tester, controller, reached);
      await tester.pump(const Duration(milliseconds: 55));

      expect(controller.state.value, EnrollmentState.waiting);
      expect(reached, isEmpty);
      expect(stub.readCalls, greaterThan(1));
    },
  );

  testWidgets(
    'exhausting the bounded poll budget with no approval moves to denied '
    'and stops polling',
    (tester) async {
      final stub = _StubFirebaseMetadataService(null);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        firebaseMetadataService: stub,
        pollInterval: const Duration(milliseconds: 5),
        maxPolls: 3,
      );

      final reached = <String>[];
      await pumpEnrollmentFlow(tester, controller, reached);
      await tester.pump(const Duration(milliseconds: 60));

      expect(controller.state.value, EnrollmentState.denied);
      final callsAtDenied = stub.readCalls;
      expect(callsAtDenied, greaterThanOrEqualTo(3));

      // Bounded: further ticks must not keep calling readEnrollmentGrant
      // once denied.
      await tester.pump(const Duration(milliseconds: 60));
      expect(stub.readCalls, callsAtDenied);
    },
  );

  group('test_EARS_RECOVER_11_continue_without_history_shows_no_recovery_notice', () {
    test('from waiting', () async {
      final stub = _StubFirebaseMetadataService(null);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        firebaseMetadataService: stub,
        pollInterval: const Duration(seconds: 30),
      );
      addTearDown(controller.onClose);

      expect(controller.state.value, EnrollmentState.waiting);
      controller.continueWithoutHistory();

      expect(controller.state.value, EnrollmentState.noRecoveryNotice);
    });

    test('from denied', () async {
      final stub = _StubFirebaseMetadataService(null);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        firebaseMetadataService: stub,
        pollInterval: const Duration(seconds: 30),
      );
      addTearDown(controller.onClose);

      // Force straight into `denied` without waiting on any real/fake
      // timer -- exhaust the poll budget via direct calls.
      controller.state.value = EnrollmentState.denied;
      controller.continueWithoutHistory();

      expect(controller.state.value, EnrollmentState.noRecoveryNotice);
    });
  });

  test(
    'test_device_enrollment_poll_stops_on_dispose',
    () async {
      final stub = _StubFirebaseMetadataService(null);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        firebaseMetadataService: stub,
        pollInterval: const Duration(milliseconds: 10),
        maxPolls: 1000,
      );

      controller.onInit();
      // Real time here (plain test(), no FakeAsync zone) -- let a handful
      // of real polls actually happen.
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(stub.readCalls, greaterThan(0));

      controller.onClose();
      final callsAtDispose = stub.readCalls;

      // Long enough for several more intervals to have fired if the timer
      // were still alive.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(stub.readCalls, callsAtDispose);
    },
  );
}
