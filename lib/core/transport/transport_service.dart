// core/transport — Dart-idiomatic facade over the Pigeon-generated
// TransportApi/TransportEventsApi boundary (ADR-0004, FR-PLAT-003).
//
// This is what feature code (routing engine, relay, UI — future epics)
// imports; nobody outside this file talks to `generated/transport_api.g.dart`
// directly. The loopback native implementation behind this boundary
// (T03a) proves the plumbing; T03b/T03c swap in real Bluetooth without
// changing this facade's shape.
import 'dart:async';

import 'package:flutter/services.dart';

import 'generated/transport_api.g.dart';

export 'generated/transport_api.g.dart'
    show TransportDevice, TransportType, ConnectionState;

class _ConnectionStateEvent {
  _ConnectionStateEvent(this.deviceId, this.state);
  final String deviceId;
  final ConnectionState state;
}

class _IncomingDataEvent {
  _IncomingDataEvent(this.deviceId, this.bytes);
  final String deviceId;
  final Uint8List bytes;
}

/// Dart-idiomatic facade over the generated `TransportApi` (host calls) and
/// `TransportEventsApi` (native -> Dart events). Exposes streams instead of
/// raw Pigeon callback registration, and awaits the eventual connection-state
/// event instead of assuming `connect()` completes synchronously — real
/// Bluetooth (T03b) cannot promise a synchronous accept, so this shape must
/// not assume one either, even though today's loopback `connect()` always
/// succeeds immediately underneath.
class TransportService {
  /// [binaryMessenger] and [messageChannelSuffix] exist to let tests run
  /// multiple independent instances against mocked platform channels without
  /// one instance's registered handler clobbering another's.
  TransportService({
    BinaryMessenger? binaryMessenger,
    String messageChannelSuffix = '',
  })  : _api = TransportApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: messageChannelSuffix,
        ) {
    TransportEventsApi.setUp(
      _EventsHandler(this),
      binaryMessenger: binaryMessenger,
      messageChannelSuffix: messageChannelSuffix,
    );
  }

  final TransportApi _api;

  final StreamController<TransportDevice> _discoveredController =
      StreamController<TransportDevice>.broadcast();
  final StreamController<String> _lostController =
      StreamController<String>.broadcast();
  final StreamController<_ConnectionStateEvent> _connectionStateController =
      StreamController<_ConnectionStateEvent>.broadcast();
  final StreamController<_IncomingDataEvent> _dataController =
      StreamController<_IncomingDataEvent>.broadcast();

  /// Emits a device each time the native layer reports one discovered
  /// (`onDeviceDiscovered`). EARS-TRANSPORT-2.
  Stream<TransportDevice> get discoveredDevices => _discoveredController.stream;

  /// Emits a device id each time the native layer reports it lost.
  Stream<String> get lostDevices => _lostController.stream;

  Future<void> startDiscovery() => _api.startDiscovery();

  Future<void> stopDiscovery() => _api.stopDiscovery();

  /// Requests a connection and awaits the eventual `onConnectionStateChanged`
  /// event for [deviceId] settling into `connected` or `failed` — never
  /// assumes `TransportApi.connect()`'s synchronous return means the
  /// connection is actually up, since a real transport can't promise that.
  Future<bool> connect(String deviceId) async {
    // Subscribe BEFORE issuing the host call. The settled-state event and
    // `connect()`'s own reply travel over two independent channels, so a
    // transport that settles fast — an already-connected peer, a cached
    // link, a synchronous failure — can push `onConnectionStateChanged`
    // before the reply is delivered to Dart. A subscription opened after
    // `await _api.connect(...)` would miss that event and this future would
    // never complete.
    final Completer<bool> settled = Completer<bool>();
    final StreamSubscription<_ConnectionStateEvent> sub =
        _connectionStateController.stream
            .where((_ConnectionStateEvent e) => e.deviceId == deviceId)
            .listen(
      (_ConnectionStateEvent e) {
        if (settled.isCompleted) return;
        if (e.state == ConnectionState.connected) {
          settled.complete(true);
        } else if (e.state == ConnectionState.failed) {
          settled.complete(false);
        }
      },
      onDone: () {
        // Service disposed before the connection settled.
        if (!settled.isCompleted) settled.complete(false);
      },
    );

    try {
      final bool accepted = await _api.connect(deviceId);
      if (!accepted) return false;
      return await settled.future;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect(String deviceId) => _api.disconnect(deviceId);

  /// Wraps `TransportApi.send`. EARS-TRANSPORT-1.
  Future<bool> send(String deviceId, Uint8List bytes) =>
      _api.send(deviceId, bytes);

  /// Per-device incoming-bytes stream, wraps `onDataReceived` filtered by
  /// [deviceId]. EARS-TRANSPORT-1.
  Stream<Uint8List> incomingData(String deviceId) => _dataController.stream
      .where((_IncomingDataEvent e) => e.deviceId == deviceId)
      .map((_IncomingDataEvent e) => e.bytes);

  Stream<ConnectionState> connectionState(String deviceId) =>
      _connectionStateController.stream
          .where((_ConnectionStateEvent e) => e.deviceId == deviceId)
          .map((_ConnectionStateEvent e) => e.state);

  void _handleDeviceDiscovered(TransportDevice device) =>
      _discoveredController.add(device);

  void _handleDeviceLost(String deviceId) => _lostController.add(deviceId);

  void _handleConnectionStateChanged(String deviceId, ConnectionState state) =>
      _connectionStateController.add(_ConnectionStateEvent(deviceId, state));

  void _handleDataReceived(String deviceId, Uint8List bytes) =>
      _dataController.add(_IncomingDataEvent(deviceId, bytes));

  /// Releases the stream controllers. Does not tear down the Pigeon
  /// `TransportEventsApi` handler registration (Pigeon has no per-instance
  /// unregister short of calling `setUp(null, ...)`), so callers that create
  /// throwaway instances (e.g. tests) should pass a distinct
  /// `messageChannelSuffix` per instance instead of relying on dispose to
  /// isolate them.
  Future<void> dispose() async {
    await _discoveredController.close();
    await _lostController.close();
    await _connectionStateController.close();
    await _dataController.close();
  }
}

class _EventsHandler extends TransportEventsApi {
  _EventsHandler(this._service);
  final TransportService _service;

  @override
  void onDeviceDiscovered(TransportDevice device) =>
      _service._handleDeviceDiscovered(device);

  @override
  void onDeviceLost(String deviceId) => _service._handleDeviceLost(deviceId);

  @override
  void onConnectionStateChanged(String deviceId, ConnectionState state) =>
      _service._handleConnectionStateChanged(deviceId, state);

  @override
  void onDataReceived(String deviceId, Uint8List bytes) =>
      _service._handleDataReceived(deviceId, bytes);

  // E04-B03: `onLinkQuality` was added to the Pigeon contract so a
  // production link-quality signal has somewhere to land, but no native
  // implementation emits it yet (contract-only, see pigeons/transport.dart).
  // Intentionally a no-op here rather than a new stream/getter — wiring a
  // real consumer (RoutingEngine.recordLinkMeasurement) is E05's job, and
  // adding unused Dart-facade plumbing now would be scope creep on a
  // contract-only bug fix. This override exists purely so
  // `_EventsHandler`, which implements the abstract `TransportEventsApi`,
  // still compiles.
  @override
  void onLinkQuality(String deviceId, int latencyMs, double lossRate) {}
}
