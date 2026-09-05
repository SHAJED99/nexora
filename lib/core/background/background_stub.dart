// core/background — in-memory BackgroundService double (E10-T08).
//
// This is what `E10-T10`'s lifecycle-trigger logic tests against; without
// it that task would be as unrunnable-without-hardware as E04-T03b/c.
// Implements the same `BackgroundControl` shape as the real
// [BackgroundService] (`background_service.dart`) so a caller built against
// this stub runs unchanged against the real Pigeon-backed service.
import 'dart:async';

import 'background_service.dart';
import 'power_state.dart';

/// An in-memory [BackgroundControl] that tracks the simulated service state
/// and never touches a platform channel. Configure [canStart] to simulate
/// the platform refusing to start the service (missing permission, Android
/// 12+ background-start restriction): while false, [start] resolves `false`
/// and records nothing, mirroring the real host's contract of never
/// throwing for a refusal.
class BackgroundStub implements BackgroundControl {
  BackgroundStub({this.canStart = true});

  /// Whether the simulated platform allows starting the service.
  bool canStart;

  ServiceState _current = ServiceState.stopped;

  final StreamController<ServiceState> _stateController =
      StreamController<ServiceState>.broadcast();

  /// Count of [start] calls that actually started the service (i.e. were
  /// not already running) — lets a test assert idempotence without a native
  /// service to inspect.
  int startCallCount = 0;

  /// E10-T09: the simulated power state, all-clear until a test calls
  /// [emitPowerState]. This is the lever `E10-T10`'s hardware-free tests
  /// depend on (task §5).
  PowerState _powerState = allClearPowerState();

  final StreamController<PowerState> _powerStateController =
      StreamController<PowerState>.broadcast();

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Future<PowerState> powerState() async => _powerState;

  @override
  Stream<PowerState> get powerStates => _powerStateController.stream;

  /// Test-only: simulate the platform observing a new [PowerState] (task
  /// §5). De-duplicated on equal consecutive states, mirroring the real
  /// [BackgroundService]'s contract (EARS-PLAT-11) so a test written
  /// against this stub still holds against the real service.
  void emitPowerState(PowerState state) {
    if (state == _powerState) return;
    _powerState = state;
    _powerStateController.add(state);
  }

  @override
  Future<bool> start() async {
    if (_current == ServiceState.running) {
      // Double-start is idempotent (task §6): report success without
      // re-starting anything or emitting a redundant event.
      return true;
    }
    if (!canStart) {
      _emit(ServiceState.stopped);
      return false;
    }
    startCallCount++;
    _emit(ServiceState.starting);
    _emit(ServiceState.running);
    return true;
  }

  @override
  Future<void> stop() async {
    _emit(ServiceState.stopped);
  }

  @override
  Future<bool> isRunning() async => _current == ServiceState.running;

  /// Test-only: simulate the system killing the service out from under the
  /// app (EARS-PLAT-8) — a real caller never triggers this directly.
  void simulateStoppedBySystem() {
    _emit(ServiceState.stoppedBySystem);
  }

  void _emit(ServiceState newState) {
    _current = newState;
    _stateController.add(newState);
  }

  Future<void> dispose() async {
    await _stateController.close();
    await _powerStateController.close();
  }
}
