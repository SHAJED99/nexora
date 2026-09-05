// Tests for BackgroundPolicy.plan (E10-T10, EARS-PLAT-12/EARS-PLAT-13).
//
// Pure function, no I/O, no platform channel -- every case in the task
// file's own §5 cadence table is exercised directly against
// `BackgroundPolicy.plan`. `messaging_coordinator_background_test.dart`
// covers the mechanical side (rescheduling the real `Timer.periodic`, no
// second driver); this file covers the DECISION only.
//
// E10-B02 addition: the bottom of this file also covers the SEAM the pure
// function alone can never prove -- that `BackgroundLifecycleObserver`
// actually calls `TransportService.startDiscovery()`/`stopDiscovery()` in
// response to the plan it computes (route (c) of that bug: "deleting this
// entire block fails no test today"). Those tests drive the real
// `BackgroundLifecycleObserver` (`lib/app/bindings.dart`) against a real
// `TransportService` (mocked at the platform-channel boundary, same pattern
// as `transport_service_test.dart`) and a fake `BackgroundControl`.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/app/bindings.dart';
import 'package:nexora/core/background/background_policy.dart';
import 'package:nexora/core/background/background_service.dart'
    show BackgroundControl;
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/background/generated/background_api.g.dart'
    show ServiceState;
import 'package:nexora/core/background/power_state.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';

/// A [BackgroundControl] double for the E10-B02 cold-start regression test:
/// [powerState] reports a fixed reading and BOTH streams never emit --
/// modelling a device that was ALREADY in Doze/Battery Saver before this
/// process existed, so no `ACTION_DEVICE_IDLE_MODE_CHANGED`-shaped
/// transition was ever observed. `BackgroundStub` (`background_stub.dart`,
/// out of this bug's `files:` fence) cannot model this on its own: its
/// `emitPowerState` always pushes onto the stream too, and its constructor
/// has no lever to seed a one-shot [powerState] reading without one.
class _NoTransitionBackgroundControl implements BackgroundControl {
  _NoTransitionBackgroundControl(this._fixedPowerState);

  final PowerState _fixedPowerState;

  final StreamController<ServiceState> _stateController =
      StreamController<ServiceState>.broadcast();
  final StreamController<PowerState> _powerStateController =
      StreamController<PowerState>.broadcast();

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Future<PowerState> powerState() async => _fixedPowerState;

  @override
  Stream<PowerState> get powerStates => _powerStateController.stream;

  @override
  Future<bool> start() async => true;

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isRunning() async => false;

  Future<void> dispose() async {
    await _stateController.close();
    await _powerStateController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var compositionSuffixCounter = 0;
  String nextCompositionSuffix() =>
      'bg-policy-composition-${compositionSuffixCounter++}';

  /// Builds a real `MessagingStack` (real `TransportService`, real
  /// `MessagingCoordinator`) against an in-memory database, mirroring
  /// `messaging_coordinator_background_test.dart`'s own `newStack` helper --
  /// this is the standard way this codebase drives `BackgroundLifecycleObserver`
  /// against real collaborators instead of an in-Dart fake for `coordinator`
  /// and `transport` (neither has a public fake/mock double in this repo).
  Future<MessagingStack> newCompositionStack(
    String suffix, {
    Duration tickInterval = const Duration(seconds: 60),
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final transport = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    return MessagingStack.create(
      db: db,
      selfDeviceId: 'device-b02-$suffix',
      transport: transport,
      coordinatorTickInterval: tickInterval,
    );
  }

  /// Mocks the native side of `TransportApi.startDiscovery`/`stopDiscovery`
  /// on [suffix]'s channel (same pattern as `transport_service_test.dart`),
  /// recording each call, in order, into [calls] and replying success.
  void mockDiscoveryChannels(String suffix, List<String> calls) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.startDiscovery.$suffix',
      (ByteData? _) async {
        calls.add('start');
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]);
      },
    );
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.stopDiscovery.$suffix',
      (ByteData? _) async {
        calls.add('stop');
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]);
      },
    );
  }

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
    test(
      'stoppedBySystem, no restricted-band signal -> foreground value, '
      'discovery still allowed',
      () {
        // Task file §5 table (corrected by E10-B02): "service
        // stoppedBySystem -> foreground value" overrides only the
        // *interval* -- there is no foreground service left to throttle, so
        // a slower interval would only slow the in-process timer for no
        // reason. With no restricted-band signal present, discovery stays
        // allowed exactly as before.
        final plan = BackgroundPolicy.plan(
          power: clear(),
          service: ServiceState.stoppedBySystem,
          lifecycle: AppLifecycleState.paused,
        );
        expect(plan.tickInterval, const Duration(seconds: 60));
        expect(plan.discoveryAllowed, isTrue);
      },
    );

    // E10-B02, route (a) -- this is the INVERSION of what this test used to
    // assert (`background_policy_test.dart:156-174` on `development` @
    // `e62f91f`): the old assertion was `discoveryAllowed: isTrue` here,
    // which is the bug. `stoppedBySystem` means the foreground SERVICE
    // died, not the process -- the Dart isolate (and the tick that fires
    // inside it) is still alive, which is the only reason this event can
    // ever be observed at all. The system is most likely to have killed the
    // service BECAUSE Doze/Battery Saver/a background restriction is
    // active, so this is exactly the moment `startDiscovery()` must not
    // fire. Confirmed to fail on today's (pre-fix) code -- see this task's
    // Run log.
    test(
      'Doze + stoppedBySystem -> discoveryAllowed false, tickInterval '
      'still the foreground value',
      () {
        final plan = BackgroundPolicy.plan(
          power: PowerState(
            deviceIdle: true,
            powerSaveMode: false,
            backgroundRestricted: false,
            ignoringBatteryOptimizations: false,
            screenLocked: false,
          ),
          service: ServiceState.stoppedBySystem,
          lifecycle: AppLifecycleState.paused,
        );
        expect(plan.tickInterval, const Duration(seconds: 60));
        expect(plan.discoveryAllowed, isFalse);
      },
    );

    test(
      'Battery Saver + stoppedBySystem -> discoveryAllowed false, '
      'tickInterval still the foreground value',
      () {
        final plan = BackgroundPolicy.plan(
          power: PowerState(
            deviceIdle: false,
            powerSaveMode: true,
            backgroundRestricted: false,
            ignoringBatteryOptimizations: false,
            screenLocked: false,
          ),
          service: ServiceState.stoppedBySystem,
          lifecycle: AppLifecycleState.paused,
        );
        expect(plan.tickInterval, const Duration(seconds: 60));
        expect(plan.discoveryAllowed, isFalse);
      },
    );

    test(
      'backgroundRestricted + stoppedBySystem -> discoveryAllowed false, '
      'same as Doze/Battery Saver',
      () {
        final plan = BackgroundPolicy.plan(
          power: PowerState(
            deviceIdle: false,
            powerSaveMode: false,
            backgroundRestricted: true,
            ignoringBatteryOptimizations: false,
            screenLocked: false,
          ),
          service: ServiceState.stoppedBySystem,
          lifecycle: AppLifecycleState.paused,
        );
        expect(plan.tickInterval, const Duration(seconds: 60));
        expect(plan.discoveryAllowed, isFalse);
      },
    );

    test(
      'all three restricted signals + stoppedBySystem -> discoveryAllowed '
      'false (the exact combination the old table row got wrong)',
      () {
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
        expect(plan.discoveryAllowed, isFalse);
      },
    );
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

  group('E10_B02_route_c_seam_calls_transport_start_stop_discovery', () {
    // EARS-PLAT-13: "the system SHALL NOT start peer discovery" is a claim
    // about `TransportService.startDiscovery()`/`stopDiscovery()` actually
    // being called, not about `BackgroundPolicy.plan`'s returned `bool`
    // alone (every other test in this file only proves the latter). This
    // drives the real `BackgroundLifecycleObserver` from
    // `lib/app/bindings.dart` against a real `TransportService` (mocked at
    // the platform-channel boundary) so deleting the `if/else` block in
    // `_applyPlan` -- E10-B02's own "fails no test today" finding -- fails
    // these tests.
    test(
      'test_EARS_PLAT_13_seam_clear_doze_clear_calls_start_stop_start',
      () async {
        final suffix = nextCompositionSuffix();
        final calls = <String>[];
        mockDiscoveryChannels(suffix, calls);
        final stack = await newCompositionStack(suffix);
        addTearDown(stack.dispose);
        addTearDown(stack.coordinator.stop);

        final backgroundStub = BackgroundStub();
        addTearDown(backgroundStub.dispose);
        final observer = BackgroundLifecycleObserver(
          coordinator: stack.coordinator,
          transport: stack.transport,
          service: backgroundStub,
        );
        addTearDown(observer.stop);

        // Clear: `BackgroundStub` defaults to `allClearPowerState()`,
        // `ServiceState.stopped`, and this observer's own
        // `AppLifecycleState.resumed` default -- the unrestricted
        // foreground row -- `discoveryAllowed: true`.
        observer.start();
        await Future<void>.delayed(Duration.zero);
        expect(calls, ['start']);

        // Doze: discovery must be stopped.
        backgroundStub.emitPowerState(
          PowerState(
            deviceIdle: true,
            powerSaveMode: false,
            backgroundRestricted: false,
            ignoringBatteryOptimizations: false,
            screenLocked: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(calls, ['start', 'stop']);

        // Clear again: discovery must resume.
        backgroundStub.emitPowerState(clear());
        await Future<void>.delayed(Duration.zero);
        expect(calls, ['start', 'stop', 'start']);
      },
    );

    // E10-B02, route (b): a cold start while the device is ALREADY in Doze
    // never sees a transition event -- `control.powerStates` here never
    // emits at all -- so the only way `BackgroundLifecycleObserver` can
    // ever learn about it is the one-shot `powerState()` read this bug adds
    // to `start()`. Must fail on today's (pre-fix) code, whose `start()`
    // only subscribes to the streams.
    test(
      'test_EARS_PLAT_13_cold_start_in_doze_never_calls_startDiscovery',
      () async {
        final suffix = nextCompositionSuffix();
        final calls = <String>[];
        mockDiscoveryChannels(suffix, calls);
        final stack = await newCompositionStack(
          suffix,
          tickInterval: const Duration(milliseconds: 20),
        );
        addTearDown(stack.dispose);
        addTearDown(stack.coordinator.stop);
        await stack.coordinator.start();

        final doze = PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: false,
          screenLocked: false,
        );
        final control = _NoTransitionBackgroundControl(doze);
        addTearDown(control.dispose);
        final observer = BackgroundLifecycleObserver(
          coordinator: stack.coordinator,
          transport: stack.transport,
          service: control,
        );
        addTearDown(observer.stop);

        // Let the fast (20ms) initial interval fire at least once, proving
        // the coordinator really is ticking quickly BEFORE the fix applies
        // any restriction -- otherwise "no further ticks" below would be
        // vacuously true.
        await Future<void>.delayed(const Duration(milliseconds: 70));
        expect(stack.coordinator.counters.ticks, greaterThan(0));

        observer.start();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // EARS-PLAT-13: startDiscovery() must never have been called.
        expect(calls, isNot(contains('start')));

        // The interval must have been lengthened to
        // `BackgroundPolicy.restrictedInterval` (300s). There is no public
        // getter for `MessagingCoordinator`'s current interval
        // (`messaging_coordinator.dart` is out of this bug's `files:`
        // fence), so this is proven indirectly: snapshot the tick count now
        // that the restricted plan has been applied, wait several multiples
        // of the OLD 20ms interval, and confirm no further ticks occurred.
        // Pre-fix (interval left unchanged at 20ms), this window would show
        // several more ticks.
        final ticksAfterApply = stack.coordinator.counters.ticks;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(stack.coordinator.counters.ticks, ticksAfterApply);
      },
    );
  });
}
