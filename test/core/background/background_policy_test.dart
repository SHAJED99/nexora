// Tests for BackgroundPolicy.plan (E10-T10, EARS-PLAT-12/EARS-PLAT-13).
//
// Pure function, no I/O, no platform channel -- every case in the task
// file's own §5 cadence table is exercised directly against
// `BackgroundPolicy.plan`. `messaging_coordinator_background_test.dart`
// covers the mechanical side (rescheduling the real `Timer.periodic`, no
// second driver); this file covers the DECISION only.
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/background/background_policy.dart';
import 'package:nexora/core/background/generated/background_api.g.dart'
    show ServiceState;
import 'package:nexora/core/background/power_state.dart';

void main() {
  PowerState clear() => allClearPowerState();

  group('test_EARS_PLAT_12_foreground_restores_60s', () {
    // EARS-PLAT-12 (FR-PLAT-002, NFR-BATT-001): the unrestricted foreground
    // row -- E06-T06's human-endorsed 60s floor, unchanged by this task
    // (task file §4).
    test('foreground, all-clear power, service running', () {
      final plan = BackgroundPolicy.plan(
        power: clear(),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.resumed,
      );
      expect(plan.tickInterval, const Duration(seconds: 60));
      expect(plan.discoveryAllowed, isTrue);
    });

    test('background, service running, screen on -- same 60s row', () {
      // Task file §5 table: "background, service running, screen on" shares
      // the unrestricted-60s row with foreground.
      final plan = BackgroundPolicy.plan(
        power: clear(),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.paused,
      );
      expect(plan.tickInterval, const Duration(seconds: 60));
      expect(plan.discoveryAllowed, isTrue);
    });
  });

  group('test_EARS_PLAT_12_screen_locked_lengthens_interval', () {
    test('background + screen locked -> 120s, discovery still allowed', () {
      final plan = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: false,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: true,
        ),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.paused,
      );
      expect(plan.tickInterval, const Duration(seconds: 120));
      expect(plan.discoveryAllowed, isTrue);
    });

    test('foreground + screen locked is not a real state -- treated as the'
        ' unrestricted row since lifecycle says resumed', () {
      // Android cannot resume the app while the screen is locked, so this
      // combination should never occur in production; BackgroundPolicy
      // still resolves it deterministically (task file §3: pure function,
      // total over its inputs) rather than throwing.
      final plan = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: false,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: true,
        ),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.resumed,
      );
      expect(plan.tickInterval, const Duration(seconds: 60));
      expect(plan.discoveryAllowed, isTrue);
    });
  });

  group('test_EARS_PLAT_12_doze_lengthens_interval', () {
    test('deviceIdle (Doze) -> 300s, discovery suppressed', () {
      final plan = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        ),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.paused,
      );
      expect(plan.tickInterval, const Duration(seconds: 300));
      expect(plan.discoveryAllowed, isFalse);
    });

    test('Doze wins over a simultaneous screen-locked reading', () {
      // Task file §5: "Most-restrictive condition wins when several hold."
      final plan = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: true,
        ),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.paused,
      );
      expect(plan.tickInterval, const Duration(seconds: 300));
      expect(plan.discoveryAllowed, isFalse);
    });
  });

  group('test_EARS_PLAT_12_battery_saver_lengthens_interval', () {
    test('powerSaveMode (Battery Saver) -> 300s, discovery suppressed', () {
      final plan = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: false,
          powerSaveMode: true,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        ),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.resumed,
      );
      expect(plan.tickInterval, const Duration(seconds: 300));
      expect(plan.discoveryAllowed, isFalse);
    });
  });

  group('test_EARS_PLAT_12_background_restricted_lengthens_interval', () {
    test('backgroundRestricted -> 300s, discovery suppressed', () {
      final plan = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: false,
          powerSaveMode: false,
          backgroundRestricted: true,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        ),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.paused,
      );
      expect(plan.tickInterval, const Duration(seconds: 300));
      expect(plan.discoveryAllowed, isFalse);
    });
  });

  group('test_EARS_PLAT_12_stopped_by_system_restores_foreground_value', () {
    test('stoppedBySystem -> foreground value regardless of power state', () {
      // Task file §5 table: "service stoppedBySystem -> foreground value
      // (nothing is running anyway) -> yes" -- overrides even a
      // simultaneous Doze/Battery-Saver reading, since there is no service
      // left to throttle.
      final plan = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: true,
          powerSaveMode: true,
          backgroundRestricted: true,
          ignoringBatteryOptimizations: false,
          screenLocked: true,
        ),
        service: ServiceState.stoppedBySystem,
        lifecycle: AppLifecycleState.paused,
      );
      expect(plan.tickInterval, const Duration(seconds: 60));
      expect(plan.discoveryAllowed, isTrue);
    });
  });

  group('test_EARS_PLAT_13_discovery_suppressed_in_doze', () {
    test('discoveryAllowed is false the instant deviceIdle flips true', () {
      final restricted = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        ),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.paused,
      );
      expect(restricted.discoveryAllowed, isFalse);
    });
  });

  group('test_EARS_PLAT_13_discovery_resumes_on_doze_exit', () {
    test('discoveryAllowed returns to true once deviceIdle clears', () {
      final duringDoze = BackgroundPolicy.plan(
        power: PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        ),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.paused,
      );
      expect(duringDoze.discoveryAllowed, isFalse);

      final afterDoze = BackgroundPolicy.plan(
        power: clear(),
        service: ServiceState.running,
        lifecycle: AppLifecycleState.paused,
      );
      expect(afterDoze.discoveryAllowed, isTrue);
      expect(afterDoze.tickInterval, const Duration(seconds: 60));
    });
  });

  group('BackgroundPlan value equality', () {
    test('two plans with the same fields are ==', () {
      const a = BackgroundPlan(
        tickInterval: Duration(seconds: 60),
        discoveryAllowed: true,
      );
      const b = BackgroundPlan(
        tickInterval: Duration(seconds: 60),
        discoveryAllowed: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different discoveryAllowed is not ==', () {
      const a = BackgroundPlan(
        tickInterval: Duration(seconds: 60),
        discoveryAllowed: true,
      );
      const b = BackgroundPlan(
        tickInterval: Duration(seconds: 60),
        discoveryAllowed: false,
      );
      expect(a == b, isFalse);
    });
  });
}
