// core/transport -- ConnectionEnsuringSender (E04-B05, FR-DISC-001,
// EARS-TRANSPORT-3).
//
// `TransportService.connect(deviceId)` -- a real, already-implemented,
// already-reviewed method (E04-T03b) that requests a Bluetooth connection
// and awaits the real `onConnectionStateChanged` settle event -- had
// exactly zero production callers anywhere in this codebase. Native
// `BluetoothTransport.send()` requires an already-open socket
// (`openSockets[deviceId] ?: return false`) and returns `false`
// unconditionally otherwise. The net effect: `RelayEngine`'s own
// `send: resolvedTransport.send` (wired directly in `messaging_stack.dart`)
// could NEVER succeed for any real destination, ever -- discovery and
// trust verification both worked, but no message could ever actually
// leave the device. Confirmed live, on two physical devices, during a
// human-directed two-device Bluetooth test this session: a real message
// was composed and "sent" (queued locally), and never arrived on the
// peer, with zero Bluetooth-tagged log output on either device -- because
// `connect()` was never once called.
//
// This wraps two plain functions matching `TransportService.connect`/
// `.send`'s own signatures exactly (tear-offs, the same style
// `RelayEngine`'s own `RelaySendFn` already uses) so a caller shaped like
// `RelaySendFn` gets connect-then-send behavior for free, without
// `RelayEngine` itself ever needing to know a connection step exists —
// its own task file's contract (`E04-T04`) is untouched. A test injects
// fakes of each function directly; no fake `TransportService` needed.
//
// Scope fence: this does NOT change `RelayEngine`, `RoutingEngine`, or
// `BluetoothTransport.kt` -- all three already do exactly what their own
// task files specify. It does NOT add proactive/eager connection
// (connecting to every discovered device regardless of whether anything
// is ever queued to send to it) -- connection is established lazily, only
// when there is real data to hand off, matching this app's own
// battery-conscious mesh design (`ADR-0004`'s "opaque, store-and-forward"
// framing; a device with nothing queued for it is never worth an open
// socket). It does NOT add a keep-alive/heartbeat to detect a silently
// dropped connection proactively -- a stale, already-closed socket is
// discovered the next time something is actually sent (this class removes
// its own connected-state bookkeeping on a failed send, so the very next
// attempt reconnects rather than repeating the same failure forever).
import 'dart:async';
import 'dart:typed_data';

import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart' show RelaySendFn;

/// Matches `TransportService.connect`'s own signature exactly -- a plain
/// function type (tear-off), the same style `RelayEngine`'s own
/// `RelaySendFn` already uses, so a test can inject a fake without
/// constructing a full `TransportService` (which needs a live Pigeon
/// platform-channel binding).
typedef ConnectFn = Future<bool> Function(String deviceId);

/// Wraps [connect]/[send] into a single `RelaySendFn`-shaped function
/// (`ensureConnectedAndSend`) that connects first (once per device, not
/// once per send) and only then sends. Production wires both from the
/// same shared `TransportService` instance
/// (`resolvedTransport.connect`/`resolvedTransport.send`); tests wire
/// fakes of each independently.
class ConnectionEnsuringSender {
  ConnectionEnsuringSender({required this.connect, required this.send});

  final ConnectFn connect;
  final RelaySendFn send;

  /// Device ids this instance currently believes have an open socket.
  /// Removed on a failed send (the socket may have silently died) so the
  /// next attempt reconnects rather than repeating the identical failure
  /// forever -- `BluetoothTransport.send`'s own native doc comment: a
  /// stuck/failed write already tears the socket down and emits
  /// `DISCONNECTED` on the native side, so treating a failed [send] as
  /// "not connected anymore" here matches what actually happened, it does
  /// not merely guess at it.
  final Set<String> _connectedDeviceIds = {};

  /// One in-flight [connect] future per device -- coalescing, same shape
  /// as `PrekeyExchange.ensureSession`'s own `_pending` map (this
  /// codebase's established pattern for "don't start a second concurrent
  /// attempt at the same real-world action while one is already running").
  /// Without this, two packets queued to the same destination in the same
  /// `RelayEngine.processQueue()` pass would each call `connect()`
  /// independently, racing to open two sockets to the same peer.
  final Map<String, Future<bool>> _pendingConnects = {};

  Future<bool> _ensureConnected(String deviceId) {
    if (_connectedDeviceIds.contains(deviceId)) {
      return Future.value(true);
    }
    final existing = _pendingConnects[deviceId];
    if (existing != null) return existing;

    final future = connect(deviceId).then((connected) {
      if (connected) _connectedDeviceIds.add(deviceId);
      return connected;
    }).whenComplete(() {
      _pendingConnects.remove(deviceId);
    });
    _pendingConnects[deviceId] = future;
    return future;
  }

  /// The actual `RelaySendFn`-shaped function to wire into
  /// `RelayEngine(send: ...)`. Connects first if not already connected
  /// (or waits on an in-flight connect to the same peer), then sends.
  /// Never throws -- a connect failure or a send failure both surface as
  /// `false`, exactly what `RelayEngine._attempt` already expects and
  /// handles (queue, retry via an alternate route, or leave queued).
  Future<bool> ensureConnectedAndSend(
    String nextHopId,
    Uint8List payload,
  ) async {
    final bool connected;
    try {
      connected = await _ensureConnected(nextHopId);
    } catch (e) {
      ObservabilityService.instance.logError(
        'transport.ensure_connected_failed',
        cause: e,
      );
      return false;
    }
    if (!connected) return false;

    final bool sent;
    try {
      sent = await send(nextHopId, payload);
    } catch (e) {
      ObservabilityService.instance.logError(
        'transport.ensure_connected_send_failed',
        cause: e,
      );
      _connectedDeviceIds.remove(nextHopId);
      return false;
    }
    if (!sent) {
      _connectedDeviceIds.remove(nextHopId);
    }
    return sent;
  }
}
