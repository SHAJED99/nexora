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

  void _handleServiceStateChanged(ServiceState newState) =>
      _stateController.add(newState);

  /// Releases the stream controller. Does not tear down the Pigeon
  /// `BackgroundEventsApi` handler registration — same caveat as
  /// `TransportService.dispose`/`NotificationService.dispose`: callers that
  /// create throwaway instances (e.g. tests) should pass a distinct
  /// `messageChannelSuffix` per instance.
  Future<void> dispose() async {
    await _stateController.close();
  }
}

class _EventsHandler extends BackgroundEventsApi {
  _EventsHandler(this._service);
  final BackgroundService _service;

  @override
  void onServiceStateChanged(ServiceState state) =>
      _service._handleServiceStateChanged(state);
}
