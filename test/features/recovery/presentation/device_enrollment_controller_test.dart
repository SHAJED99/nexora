// features/recovery/presentation — E12-T03 (FR-RECOVER-001/
// FR-RECOVER-002). `RelationshipSyncService.pull` is stubbed at the same
// raw-read seam `relationship_sync_service_test.dart` already uses
// (`readRelationshipsData`) so these tests never touch a real
// `FirebaseDatabase`/platform channel -- `RelationshipRepository` runs
// against a real in-memory Drift database throughout, exactly like that
// file's own tests.
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
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/relationship_sync_service.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// Never returns any remote relationship data -- `pull` becomes a
/// deterministic no-op that never touches local state, so a test can
/// pre-seed `RelationshipRepository` directly and know `pull` will not
/// disturb it. Counts calls so the dispose test can prove polling actually
/// stopped.
class _NoOpRelationshipSyncService extends RelationshipSyncService {
  _NoOpRelationshipSyncService({required super.repository});

  int pullCalls = 0;

  @override
  Future<Object?> readRelationshipsData(String uid) async {
    pullCalls++;
    return null;
  }
}

AppDatabase _openTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

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

  group('checkApproval', () {
    test(
      'trusted local state after pull reads as approved',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        await repository.upsert('this-device', RelationshipState.trusted);
        final sync = _NoOpRelationshipSyncService(repository: repository);
        final controller = DeviceEnrollmentController(
          accountUid: 'uid-1',
          thisDeviceId: 'this-device',
          relationshipRepository: repository,
          relationshipSyncService: sync,
        );
        addTearDown(controller.onClose);

        expect(await controller.checkApproval(), isTrue);
      },
    );

    test(
      'allowed local state after pull also reads as approved',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        await repository.upsert('this-device', RelationshipState.allowed);
        final sync = _NoOpRelationshipSyncService(repository: repository);
        final controller = DeviceEnrollmentController(
          accountUid: 'uid-1',
          thisDeviceId: 'this-device',
          relationshipRepository: repository,
          relationshipSyncService: sync,
        );
        addTearDown(controller.onClose);

        expect(await controller.checkApproval(), isTrue);
      },
    );

    test(
      'no local relationship yet reads as not approved',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final sync = _NoOpRelationshipSyncService(repository: repository);
        final controller = DeviceEnrollmentController(
          accountUid: 'uid-1',
          thisDeviceId: 'this-device',
          relationshipRepository: repository,
          relationshipSyncService: sync,
        );
        addTearDown(controller.onClose);

        expect(await controller.checkApproval(), isFalse);
      },
    );

    test(
      'a blocked local state reads as not approved',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        await repository.upsert('this-device', RelationshipState.blocked);
        final sync = _NoOpRelationshipSyncService(repository: repository);
        final controller = DeviceEnrollmentController(
          accountUid: 'uid-1',
          thisDeviceId: 'this-device',
          relationshipRepository: repository,
          relationshipSyncService: sync,
        );
        addTearDown(controller.onClose);

        expect(await controller.checkApproval(), isFalse);
      },
    );
  });

  testWidgets(
    'test_EARS_RECOVER_10_approval_detected_navigates_to_dashboard',
    (tester) async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      await repository.upsert('this-device', RelationshipState.trusted);
      final sync = _NoOpRelationshipSyncService(repository: repository);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        relationshipRepository: repository,
        relationshipSyncService: sync,
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
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      final sync = _NoOpRelationshipSyncService(repository: repository);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        relationshipRepository: repository,
        relationshipSyncService: sync,
        pollInterval: const Duration(milliseconds: 10),
        maxPolls: 100,
      );

      final reached = <String>[];
      await pumpEnrollmentFlow(tester, controller, reached);
      await tester.pump(const Duration(milliseconds: 55));

      expect(controller.state.value, EnrollmentState.waiting);
      expect(reached, isEmpty);
      expect(sync.pullCalls, greaterThan(1));
    },
  );

  testWidgets(
    'exhausting the bounded poll budget with no approval moves to denied '
    'and stops polling',
    (tester) async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      final sync = _NoOpRelationshipSyncService(repository: repository);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        relationshipRepository: repository,
        relationshipSyncService: sync,
        pollInterval: const Duration(milliseconds: 5),
        maxPolls: 3,
      );

      final reached = <String>[];
      await pumpEnrollmentFlow(tester, controller, reached);
      await tester.pump(const Duration(milliseconds: 60));

      expect(controller.state.value, EnrollmentState.denied);
      final callsAtDenied = sync.pullCalls;
      expect(callsAtDenied, greaterThanOrEqualTo(3));

      // Bounded: further ticks must not keep calling pull once denied.
      await tester.pump(const Duration(milliseconds: 60));
      expect(sync.pullCalls, callsAtDenied);
    },
  );

  group('test_EARS_RECOVER_11_continue_without_history_shows_no_recovery_notice', () {
    test('from waiting', () async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      final sync = _NoOpRelationshipSyncService(repository: repository);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        relationshipRepository: repository,
        relationshipSyncService: sync,
        pollInterval: const Duration(seconds: 30),
      );
      addTearDown(controller.onClose);

      expect(controller.state.value, EnrollmentState.waiting);
      controller.continueWithoutHistory();

      expect(controller.state.value, EnrollmentState.noRecoveryNotice);
    });

    test('from denied', () async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      final sync = _NoOpRelationshipSyncService(repository: repository);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        relationshipRepository: repository,
        relationshipSyncService: sync,
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
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      final sync = _NoOpRelationshipSyncService(repository: repository);
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-1',
        thisDeviceId: 'this-device',
        relationshipRepository: repository,
        relationshipSyncService: sync,
        pollInterval: const Duration(milliseconds: 10),
        maxPolls: 1000,
      );

      controller.onInit();
      // Real time here (plain test(), no FakeAsync zone) -- let a handful
      // of real polls actually happen.
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(sync.pullCalls, greaterThan(0));

      controller.onClose();
      final callsAtDispose = sync.pullCalls;

      // Long enough for several more intervals to have fired if the timer
      // were still alive.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sync.pullCalls, callsAtDispose);
    },
  );
}
