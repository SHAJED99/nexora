// core/background — in-memory BackgroundService double (E10-T08).
//
// This is what `E10-T10`'s lifecycle-trigger logic tests against; without
// it that task would be as unrunnable-without-hardware as E04-T03b/c.
// Implements the same `BackgroundControl` shape as the real
// [BackgroundService] (`background_service.dart`) so a caller built against
// this stub runs unchanged against the real Pigeon-backed service.
import 'dart:async';

import 'background_service.dart';

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

  @override
  Stream<ServiceState> get state => _stateController.stream;

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
  }
}
