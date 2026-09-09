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
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart'
    show SettingsSectionCard;

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
    'test_EARS_PLAT_15_initial_loading_state_renders_unknown_before_first_read',
    () {
      // The falsification test for this task: BEFORE the first real
      // `PowerState` read has resolved, all three rows must already read
      // `unknown`. It proves the synchronous loading-state initial value is
      // unknown, NOT that a genuinely-unreported-by-the-platform restriction
      // (as opposed to a reported-off one) can be distinguished after a
      // PowerState read completes - because PowerState's fields are plain bool
      // and cannot currently carry that distinction (see controller header
      // comment lines 22-33).
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
    'test_EARS_PLAT_15_unknown_renders_as_text_not_off',
    (tester) async {
      // `BackgroundStub.powerState()`'s own default resolves immediately
      // (to `allClearPowerState()`), so a plain `BackgroundStub` turns every
      // restriction to a definite `off` within the same pumped frame that
      // mounts the view -- there is no window left in which to observe
      // `Unknown` actually rendered. `_NeverRespondingPowerStateStub` holds
      // that read open indefinitely (a `Completer` that is never
      // completed), keeping the controller in the genuine, real
      // pre-first-read loading state for as long as the test needs it --
      // exactly the state `EARS-PLAT-15`'s `Unknown` value is contractually
      // required to render as (task §3), and exactly the state Finding 3's
      // renamed test (`test_EARS_PLAT_15_initial_loading_state_renders_unknown_before_first_read`,
      // above) proves at the controller level. This test proves the SAME
      // thing at the rendered-widget level instead.
      Get.testMode = true;
      final neverRespondingService = _NeverRespondingPowerStateStub();
      final viewController =
          BatterySettingsController(service: neverRespondingService);
      Get.put<BatterySettingsController>(viewController);

      await tester.pumpWidget(const GetMaterialApp(home: BatterySettingsView()));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      expect(find.text('Unknown'), findsNWidgets(3));
      expect(find.text('Off'), findsNothing);

      // FALSIFICATION PROCEDURE:
      // Temporarily revert battery_settings_view.dart's RestrictionValue.unknown
      // branch in _valueLabel to return 'Off' instead of 'Unknown'. Run this test
      // and observe RED (fails because 'Unknown' is 0, 'Off' is 3). Revert the
      // view file change and confirm the test passes GREEN again.

      viewController.onClose();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      Get.reset();
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
      // card. We walk the actual rendered element tree and count every
      // hit-testable gesture surface (`GestureDetector`, `InkWell`/
      // `InkResponse`, a raw `Listener` with a pointer callback, or a
      // `Semantics` node with `onTap`/`onLongPress` set) -- scoped to
      // descendants of this screen's own `SettingsSectionCard`s only, never
      // the whole tree. Scoping this way sidesteps having to reason about
      // how many widget-tree entries the shared shell's OWN legitimate back
      // affordance (`_BackRow`'s single `InkWell`, which lives OUTSIDE every
      // `SettingsSectionCard`) fans out into internally -- Flutter's real
      // `InkWell` implementation is not one widget but several nested ones
      // (`Semantics` + `GestureDetector` + `Listener`), so counting the
      // whole tree and asserting "exactly 1" is unreliable; asserting ZERO
      // inside the screen's own cards is not. A widget-TYPE denylist
      // (`Switch`/`Checkbox`/etc, the prior version of this test) is
      // defeatable by wrapping a row in a raw `Listener(onPointerDown: ...)`
      // -- L-frontend-001, the exact gaming shape this rewrite defends
      // against.
      //
      // FALSIFICATION PROCEDURE (confirmed manually before this fix landed):
      // temporarily wrap one `_RestrictionRow` (or the `_BackgroundOperationBody`
      // state label) in `battery_settings_view.dart` with
      // `Listener(onPointerDown: (_) {}, child: ...)`, run this test, and
      // observe it go RED (count becomes >0 instead of 0) -- then revert the
      // view file change and confirm it is GREEN again.
      expect(_countGestureSurfacesInside(find.byType(SettingsSectionCard)), 0);

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

/// `powerState()`'s one-shot read never resolves (a `Completer` that is
/// never completed) -- unlike the real `BackgroundStub`, whose default
/// resolves immediately, this keeps the controller in a genuine,
/// indefinitely-held pre-first-read loading state, the only state this
/// build can ever render `Unknown` in (Finding 3's own documented limit,
/// header comment lines 22-33). `powerStates`'s stream stays real/unused
/// -- nothing calls `emitPowerState` in this test, so it never fires.
class _NeverRespondingPowerStateStub extends BackgroundStub {
  @override
  Future<PowerState> powerState() => Completer<PowerState>().future;
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

/// Counts every hit-testable gesture surface living inside [scope]'s
/// matches (and their descendants) -- see the comment at this file's own
/// `test_EARS_PLAT_16_no_control_is_rendered` for why this is scoped rather
/// than counted over the whole tree.
int _countGestureSurfacesInside(Finder scope) {
  bool isActiveGestureDetector(Widget w) =>
      w is GestureDetector &&
      (w.onTap != null ||
          w.onDoubleTap != null ||
          w.onLongPress != null ||
          w.onTapDown != null);
  bool isActiveInkResponse(Widget w) =>
      w is InkResponse &&
      (w.onTap != null || w.onDoubleTap != null || w.onLongPress != null);
  bool isActiveListener(Widget w) =>
      w is Listener && (w.onPointerDown != null || w.onPointerUp != null);
  bool isActiveSemantics(Widget w) =>
      w is Semantics &&
      (w.properties.onTap != null || w.properties.onLongPress != null);

  return find
          .descendant(
            of: scope,
            matching: find.byWidgetPredicate(isActiveGestureDetector),
          )
          .evaluate()
          .length +
      find
          .descendant(
            of: scope,
            matching: find.byWidgetPredicate(isActiveInkResponse),
          )
          .evaluate()
          .length +
      find
          .descendant(
            of: scope,
            matching: find.byWidgetPredicate(isActiveListener),
          )
          .evaluate()
          .length +
      find
          .descendant(
            of: scope,
            matching: find.byWidgetPredicate(isActiveSemantics),
          )
          .evaluate()
          .length;
}
