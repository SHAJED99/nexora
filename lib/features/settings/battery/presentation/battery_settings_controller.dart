// features/settings/battery/presentation -- FR-PLAT-004's screen
// controller (E15-T08, `design/screens/settings-battery.md`, GAP-037). Two
// read-only cards over already-shipped services: `BackgroundControl`
// (`core/background/background_service.dart` -- the real `BackgroundService`
// in production, `BackgroundStub` in tests) for background-operation state
// and the three `FR-PLAT-002` restrictions, plus `BackgroundPolicy.plan`
// (`core/background/background_policy.dart`, a pure function, E10-T10) for
// the current plan. Neither card offers a control (task §4, `EARS-PLAT-16`)
// -- this screen does not reimplement, and does not appear to override,
// Doze/Battery Saver/background-execution restrictions.
//
// This controller tracks `AppLifecycleState`/`ServiceState`/`PowerState`
// itself (`with WidgetsBindingObserver`), the SAME three signals
// `BackgroundLifecycleObserver` (`lib/app/bindings.dart`, not in this
// task's `files:`) already tracks -- but this is a second, independent,
// READ-ONLY observer: it never calls `service.start()`/`stop()`,
// `MessagingCoordinator.setTickInterval`, or
// `TransportService.startDiscovery()`/`stopDiscovery()`. Those writes stay
// `BackgroundLifecycleObserver`'s alone; this class only computes what
// `BackgroundPolicy.plan` decides ON, never applies it.
//
// `RestrictionValue.unknown` is `EARS-PLAT-15`'s "unreported restriction"
// (task §3 contract) modeled as a real, reachable value: BT10's three rows
// render immediately (their NAMES are fixed, never derived from data), each
// starting `unknown` until this controller's first real `PowerState`
// arrives -- exactly what "unreported" means before that first report has
// happened. Once a `PowerState` has been read, every field is a definite
// `bool` (`power_state.dart`'s own documented contract: an unsupported
// signal on the running API level reads `false`, not a distinguishable
// "unknown") -- so this build cannot produce `unknown` again AFTER a
// successful read, only before one. That is a real, current fact about
// what `PowerState`'s shipped shape can report, not an invented limitation;
// see this task's own Deviations note.
import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:get/get.dart';
import 'package:nexora/core/background/background_policy.dart';
import 'package:nexora/core/background/background_service.dart';

/// BT10's own value space -- `FR-PLAT-002`'s three names, no more and no
/// fewer (task §3 contract). `unknown` is a real value, never a failure.
enum RestrictionValue { on, off, unknown }

/// BT10's own row: one of `Doze` / `Battery Saver` / `Background
/// restricted`, plus its current [RestrictionValue].
class RestrictionStatus {
  const RestrictionStatus({required this.name, required this.value});

  final String name;
  final RestrictionValue value;
}

/// FR-PLAT-004's screen controller. Holds no second copy of any platform
/// decision and applies nothing -- every value it exposes is read straight
/// from [service] or computed by [BackgroundPolicy.plan] (task §2).
class BatterySettingsController extends GetxController
    with WidgetsBindingObserver {
  BatterySettingsController({required this.service});

  final BackgroundControl service;

  /// BT6. `null` until `isRunning()`'s one-shot read completes -- the real
  /// `loading` state (task §5: "values unpopulated"), since this IS a
  /// `Future`-backed snapshot, unlike `TransportService`'s pure event
  /// streams (contrast `NetworkSettingsController`'s own header note).
  final Rx<bool?> backgroundRunning = Rx<bool?>(null);

  /// `true` once `service.state`'s stream, or the initial `isRunning()`
  /// read, has failed. BT13 replaces BT6/BT7's value only (`EARS-UI-11`) --
  /// the Restrictions/Current-plan card below is driven by a separate
  /// signal (`PowerState`) and stays rendered.
  final RxBool backgroundRunningError = false.obs;

  /// BT10 -- exactly three rows, always present (task §3 contract), each
  /// starting `unknown` until the first real `PowerState` arrives (file
  /// header).
  final RxList<RestrictionStatus> restrictions = <RestrictionStatus>[
    const RestrictionStatus(name: 'Doze', value: RestrictionValue.unknown),
    const RestrictionStatus(
      name: 'Battery Saver',
      value: RestrictionValue.unknown,
    ),
    const RestrictionStatus(
      name: 'Background restricted',
      value: RestrictionValue.unknown,
    ),
  ].obs;

  /// `true` once `service.powerStates`'s stream, or the initial
  /// `powerState()` read, has failed. BT13 replaces BT10/BT11's value only
  /// -- independent of [backgroundRunningError] (`EARS-UI-11`).
  final RxBool restrictionsError = false.obs;

  /// BT11 -- `BackgroundPolicy.plan`'s own one-line rendering. `null` until
  /// BOTH a `PowerState` and a `ServiceState` are known (the plan needs
  /// both, task §3), the same "unpopulated until known" loading treatment.
  final Rx<String?> plan = Rx<String?>(null);

  PowerState? _powerState;
  ServiceState? _serviceState;

  /// Defaults to `resumed` -- this controller is constructed and its
  /// observer attached during screen build, so a fresh open is a
  /// foreground open (mirrors `BackgroundLifecycleObserver`'s own default,
  /// `bindings.dart`).
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  StreamSubscription<ServiceState>? _stateSubscription;
  StreamSubscription<PowerState>? _powerSubscription;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _stateSubscription = service.state.listen(
      _onServiceStateChanged,
      onError: (Object _, StackTrace _) => backgroundRunningError.value = true,
    );
    _powerSubscription = service.powerStates.listen(
      _onPowerStateChanged,
      onError: (Object _, StackTrace _) => restrictionsError.value = true,
    );
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    try {
      final running = await service.isRunning();
      backgroundRunning.value = running;
      _serviceState = running ? ServiceState.running : ServiceState.stopped;
      _recomputePlan();
    } catch (_) {
      backgroundRunningError.value = true;
    }
    try {
      final power = await service.powerState();
      _onPowerStateChanged(power);
    } catch (_) {
      restrictionsError.value = true;
    }
  }

  void _onServiceStateChanged(ServiceState state) {
    _serviceState = state;
    backgroundRunning.value = state == ServiceState.running;
    _recomputePlan();
  }

  void _onPowerStateChanged(PowerState state) {
    _powerState = state;
    restrictions.value = [
      RestrictionStatus(
        name: 'Doze',
        value: state.deviceIdle ? RestrictionValue.on : RestrictionValue.off,
      ),
      RestrictionStatus(
        name: 'Battery Saver',
        value: state.powerSaveMode ? RestrictionValue.on : RestrictionValue.off,
      ),
      RestrictionStatus(
        name: 'Background restricted',
        value: state.backgroundRestricted
            ? RestrictionValue.on
            : RestrictionValue.off,
      ),
    ];
    _recomputePlan();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _recomputePlan();
  }

  void _recomputePlan() {
    final power = _powerState;
    final serviceState = _serviceState;
    if (power == null || serviceState == null) return;
    final computed = BackgroundPolicy.plan(
      power: power,
      service: serviceState,
      lifecycle: _lifecycle,
    );
    plan.value = _renderPlan(computed);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stateSubscription?.cancel());
    unawaited(_powerSubscription?.cancel());
    super.onClose();
  }
}

/// BT11's one-line rendering of a [BackgroundPlan] -- "the why is the app
/// doing less right now answer" (`settings-battery.md`).
String _renderPlan(BackgroundPlan plan) {
  final seconds = plan.tickInterval.inSeconds;
  final discovery = plan.discoveryAllowed ? 'allowed' : 'paused';
  return 'Checks every ${seconds}s; peer discovery $discovery.';
}
