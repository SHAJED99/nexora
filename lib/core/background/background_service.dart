// core/background — Dart-idiomatic facade over the Pigeon-generated
// BackgroundApi/BackgroundEventsApi boundary (ADR-0004, ADR-0007,
// FR-PLAT-001, FR-PLAT-002, FR-PLAT-003).
//
// This is what E10-T10 calls to decide *when* the foreground service runs;
// nobody outside this file talks to `generated/background_api.g.dart`
// directly. Mirrors `core/notifications/notification_service.dart`'s shape
// deliberately (same native-behind-Pigeon pattern, ADR-0004).
//
// Adds NO scheduler, timer or isolate of its own — task §2/§4. The service
// this facade starts/stops keeps the process (and therefore
// `MessagingCoordinator`'s existing `Timer.periodic`) alive; it is not a
// second driver.
//
// Does NOT decide *when* to start the service (that is `E10-T10`, task §4)
// and does NOT request a battery-optimisation exemption (ADR-0007 §S2).
import 'dart:async';

import 'package:flutter/services.dart';

import 'generated/background_api.g.dart';

export 'generated/background_api.g.dart' show ServiceState;
export 'power_state.dart' show PowerState;

/// The shape `E10-T10`'s lifecycle-trigger logic depends on — shared by the
/// real [BackgroundService] and the in-memory [BackgroundStub]
/// (`background_stub.dart`) so downstream code can be built and tested
/// against the stub without any Pigeon/platform-channel wiring, then run
/// unchanged against the real service.
abstract class BackgroundControl {
  Future<bool> start();
  Future<void> stop();
  Future<bool> isRunning();
  Stream<ServiceState> get state;

  /// E10-T09: a one-shot snapshot for startup. Never throws — a signal
  /// unavailable on the running API level reads `false` (task §5/§6).
  Future<PowerState> powerState();

  /// E10-T09: what `E10-T10` subscribes to. Broadcast; emits on every
  /// observed transition, de-duplicated on equal consecutive states
  /// (task §5/§6, EARS-PLAT-11).
  Stream<PowerState> get powerStates;
}

/// Dart-idiomatic facade over the generated `BackgroundApi` (host calls) and
/// `BackgroundEventsApi` (native -> Dart events).
class BackgroundService implements BackgroundControl {
  /// [binaryMessenger] and [messageChannelSuffix] exist to let tests run
  /// multiple independent instances against mocked platform channels
  /// without one instance's registered handler clobbering another's — same
  /// pattern as `TransportService`/`NotificationService`.
  BackgroundService({
    BinaryMessenger? binaryMessenger,
    String messageChannelSuffix = '',
  })  : _api = BackgroundApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: messageChannelSuffix,
        ) {
    BackgroundEventsApi.setUp(
      _EventsHandler(this),
      binaryMessenger: binaryMessenger,
      messageChannelSuffix: messageChannelSuffix,
    );
  }

  final BackgroundApi _api;

  final StreamController<ServiceState> _stateController =
      StreamController<ServiceState>.broadcast();

  final StreamController<PowerState> _powerStateController =
      StreamController<PowerState>.broadcast();

  /// The last `PowerState` this facade emitted — de-duplication happens
  /// here too, not only on the Kotlin side, so this Dart-side contract
  /// (EARS-PLAT-11) holds regardless of what the platform channel actually
  /// delivered (task §5/§6).
  PowerState? _lastPowerState;

  /// So `E10-T10` can react to `stoppedBySystem` instead of assuming it
  /// never happens (task §5).
  @override
  Stream<ServiceState> get state => _stateController.stream;

  /// The only way anything in Dart starts the foreground service. Returns
  /// `false` — never throws — when the platform refused (missing
  /// permission, Android 12+ background-start restriction).
  @override
  Future<bool> start() => _api.startService();

  /// Stops the service and removes the ongoing notification.
  @override
  Future<void> stop() => _api.stopService();

  @override
  Future<bool> isRunning() => _api.isServiceRunning();

  @override
  Future<PowerState> powerState() => _api.powerState();

  @override
  Stream<PowerState> get powerStates => _powerStateController.stream;

  void _handleServiceStateChanged(ServiceState newState) =>
      _stateController.add(newState);

  void _handlePowerStateChanged(PowerState newState) {
    if (newState == _lastPowerState) return;
    _lastPowerState = newState;
    _powerStateController.add(newState);
  }

  /// Releases the stream controllers. Does not tear down the Pigeon
  /// `BackgroundEventsApi` handler registration — same caveat as
  /// `TransportService.dispose`/`NotificationService.dispose`: callers that
  /// create throwaway instances (e.g. tests) should pass a distinct
  /// `messageChannelSuffix` per instance.
  Future<void> dispose() async {
    await _stateController.close();
    await _powerStateController.close();
  }
}

class _EventsHandler extends BackgroundEventsApi {
  _EventsHandler(this._service);
  final BackgroundService _service;

  @override
  void onServiceStateChanged(ServiceState state) =>
      _service._handleServiceStateChanged(state);

  @override
  void onPowerStateChanged(PowerState state) =>
      _service._handlePowerStateChanged(state);
}
