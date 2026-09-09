// features/settings/battery/presentation -- BatterySettingsController
// (E15-T08). Real `BackgroundStub` throughout (E10-T08's own in-memory
// `BackgroundControl` double) -- these tests prove the controller's
// *binding* to the shipped facade, not a mock's promise that it would.
// `_ErroringServiceStateStub`/`_ErroringPowerStateStub` below are the two
// independent failure seams `EARS-UI-11`'s independence claim needs; never
// `fail()` inside an injected seam (a broad catch in the controller would
// swallow it, L-testing).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/background/background_policy.dart';
import 'package:nexora/core/background/background_service.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/background/power_state.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_controller.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackgroundStub service;
  late BatterySettingsController controller;

  setUp(() {
    service = BackgroundStub();
    controller = BatterySettingsController(service: service);
  });

  tearDown(() {
    controller.onClose();
  });

  test(
    'test_EARS_PLAT_15_unreported_restriction_renders_unknown',
    () {
      // The falsification test for this task: BEFORE the first real
      // `PowerState` read has resolved, all three rows must already read
      // `unknown` -- "unreported" (task §3 contract), not defaulted `off`.
      controller.onInit();

      expect(controller.restrictions.length, 3);
      expect(
        controller.restrictions.map((r) => r.value).toSet(),
        {RestrictionValue.unknown},
      );
    },
  );

  test(
    'test_EARS_PLAT_15_exactly_three_restrictions_are_listed',
    () async {
      controller.onInit();
      service.emitPowerState(
        PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.restrictions.length, 3);
      expect(
        controller.restrictions.map((r) => r.name).toSet(),
        {'Doze', 'Battery Saver', 'Background restricted'},
      );
      final doze = controller.restrictions.firstWhere((r) => r.name == 'Doze');
      expect(doze.value, RestrictionValue.on);
      final saver =
          controller.restrictions.firstWhere((r) => r.name == 'Battery Saver');
      expect(saver.value, RestrictionValue.off);
    },
  );

  test(
    'test_background_running_reflects_isRunning',
    () async {
      await service.start();
      controller.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.backgroundRunning.value, isTrue);
    },
  );

  test(
    'test_background_running_is_null_before_the_first_read',
    () {
      controller.onInit();
      expect(controller.backgroundRunning.value, isNull);
    },
  );

  test(
    'test_current_plan_matches_BackgroundPolicy_once_both_signals_are_known',
    () async {
      controller.onInit();
      service.emitPowerState(allClearPowerState());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final expected = BackgroundPolicy.plan(
        power: allClearPowerState(),
        service: ServiceState.stopped,
        lifecycle: AppLifecycleState.resumed,
      );
      expect(controller.plan.value, isNotNull);
      expect(controller.plan.value, contains('${expected.tickInterval.inSeconds}s'));
      expect(
        controller.plan.value,
        contains(expected.discoveryAllowed ? 'allowed' : 'paused'),
      );
    },
  );

  test(
    'test_EARS_UI_11_power_state_read_failure_leaves_background_running_intact',
    () async {
      final erroringService = _ErroringPowerStateStub();
      final erroringController = BatterySettingsController(service: erroringService);
      erroringController.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(erroringController.restrictionsError.value, isTrue);
      expect(erroringController.backgroundRunningError.value, isFalse);
      expect(erroringController.backgroundRunning.value, isFalse);

      erroringController.onClose();
    },
  );

  test(
    'test_EARS_UI_11_service_state_read_failure_leaves_restrictions_intact',
    () async {
      final erroringService = _ErroringServiceStateStub();
      final erroringController = BatterySettingsController(service: erroringService);
      erroringController.onInit();
      erroringService.emitPowerState(
        PowerState(
          deviceIdle: false,
          powerSaveMode: true,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(erroringController.backgroundRunningError.value, isTrue);
      expect(erroringController.restrictionsError.value, isFalse);
      final saver =
          erroringController.restrictions.firstWhere((r) => r.name == 'Battery Saver');
      expect(saver.value, RestrictionValue.on);

      erroringController.onClose();
    },
  );

  testWidgets(
    'test_EARS_PLAT_16_no_control_is_rendered',
    (tester) async {
      Get.testMode = true;
      final viewController = BatterySettingsController(service: service);
      Get.put<BatterySettingsController>(viewController);
      service.emitPowerState(
        PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: true,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        ),
      );
      await service.start();

      await tester.pumpWidget(const GetMaterialApp(home: BatterySettingsView()));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      expect(find.text('Battery'), findsOneWidget);
      // EARS-PLAT-16: no button, switch or tappable ROW anywhere on either
      // card. `SettingsSubScreenScaffold`'s own back affordance (SH1/SH2)
      // is an `InkWell` too (task §3's shared shell, not this screen's own
      // content) -- excluded here deliberately, the same way
      // `settings-battery.md`'s own §Prohibition scopes "no control" to
      // this screen's two cards, not the shell it composes.
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(InkWell), findsOneWidget); // the shell's own back affordance, only

      viewController.onClose();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      Get.reset();
    },
  );
}

/// A `BackgroundControl` whose `powerStates`/`powerState()` always fail --
/// `service.state` stays real and functional, proving the two cards fail
/// independently.
class _ErroringPowerStateStub extends BackgroundStub {
  @override
  Future<PowerState> powerState() {
    throw StateError('simulated read failure');
  }

  @override
  Stream<PowerState> get powerStates =>
      Stream<PowerState>.error(StateError('simulated read failure'));
}

/// The symmetric seam: `state`/`isRunning()` always fail, `powerStates`
/// stays real.
class _ErroringServiceStateStub extends BackgroundStub {
  @override
  Future<bool> isRunning() {
    throw StateError('simulated read failure');
  }

  @override
  Stream<ServiceState> get state =>
      Stream<ServiceState>.error(StateError('simulated read failure'));
}
