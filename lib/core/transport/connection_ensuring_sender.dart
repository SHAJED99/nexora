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
  ConnectionEnsuringSender({
    required this.connect,
    required this.send,
    this.connectTimeout = _defaultConnectTimeout,
  });

  final ConnectFn connect;
  final RelaySendFn send;

  /// Device ids this instance currently believes have an open socket.
  /// Removed on a failed send so the next attempt reconnects rather than
  /// repeating the identical failure forever. This is a conservative
  /// heuristic, not a proven fact about the underlying socket in every
  /// case: a native write that TIMES OUT does tear the socket down and
  /// emit `DISCONNECTED` (`BluetoothTransport.kt`'s own timeout branch), but
  /// a write that fails with a plain `IOException` returns `false` while
  /// the native socket is left in place, still keyed in `openSockets`, with
  /// no event emitted at all (review finding, E04-B05) -- forgetting it
  /// here anyway is still the right call for THIS class's own contract
  /// (never trust a failed send blindly), it just means the next
  /// [connect] may be reconnecting a device the native side never actually
  /// dropped. That native-side gap (a possible stale-but-still-open socket,
  /// and the leaked read thread parked on it) is a real, disclosed
  /// follow-up outside this file's own fence -- `BluetoothTransport.kt` is
  /// untouched by this task.
  final Set<String> _connectedDeviceIds = {};

  /// One in-flight [connect] future per device -- coalescing, same shape
  /// as `PrekeyExchange.ensureSession`'s own `_pending` map (this
  /// codebase's established pattern for "don't start a second concurrent
  /// attempt at the same real-world action while one is already running").
  /// Without this, two packets queued to the same destination in the same
  /// `RelayEngine.processQueue()` pass would each call `connect()`
  /// independently, racing to open two sockets to the same peer.
  final Map<String, Future<bool>> _pendingConnects = {};

  /// Default bound on how long a single [connect] attempt is awaited
  /// (review finding, E04-B05): `TransportService.connect` itself has no
  /// timeout on its own settle future, so a connect that never settles at
  /// all (its native thread hits an `Error` outside the three `Exception`
  /// types it already catches) would otherwise wedge [_pendingConnects] for
  /// that device forever, and every later packet queued to it behind
  /// `RelayEngine.processQueue()`'s own sequential `for` loop. A timeout
  /// here surfaces that as an ordinary failed connect instead. Overridable
  /// via the constructor so a test can use a short duration instead of
  /// waiting out the real production value.
  static const _defaultConnectTimeout = Duration(seconds: 30);
  final Duration connectTimeout;

  Future<bool> _ensureConnected(String deviceId) {
    if (_connectedDeviceIds.contains(deviceId)) {
      return Future.value(true);
    }
    final existing = _pendingConnects[deviceId];
    if (existing != null) return existing;

    final future = _runConnect(deviceId).whenComplete(() {
      _pendingConnects.remove(deviceId);
    });
    _pendingConnects[deviceId] = future;
    return future;
  }

  /// Runs a single [connect] attempt for [deviceId], bounded by
  /// [connectTimeout]. Deliberately a plain `async` function (rather than
  /// chaining `.timeout()`/`.then()` directly onto [connect]'s own future)
  /// so a thrown error is caught by THIS function's own `try`/`catch` and
  /// turned into a normal `false` return before it ever reaches
  /// [_ensureConnected]'s caller -- chaining combinators directly produced
  /// an unhandled-async-error report from the test zone even though
  /// [ensureConnectedAndSend]'s own `try`/`catch` still correctly received
  /// the same error afterward (observed regression when [connectTimeout]
  /// was added; this shape does not reproduce it).
  Future<bool> _runConnect(String deviceId) async {
    try {
      final connected = await _callConnect(deviceId).timeout(
        connectTimeout,
        onTimeout: () => false,
      );
      if (connected) _connectedDeviceIds.add(deviceId);
      return connected;
    } catch (e) {
      ObservabilityService.instance.logError(
        'transport.ensure_connected_failed',
        cause: e,
      );
      return false;
    }
  }

  /// Calls [connect] through an explicit `Future<bool>`-returning `async`
  /// wrapper rather than `.timeout()`ing [connect]'s own return value
  /// directly. A [ConnectFn] that always throws (never returns normally --
  /// exactly a test double for "connect always fails", and the shape any
  /// real permanently-unreachable-peer path also takes) is reified by Dart
  /// as `Future<Never>`, not `Future<bool>`, despite [ConnectFn]'s own
  /// declared signature -- calling `.timeout(onTimeout: () => false)`
  /// directly on that narrower runtime type throws a *separate* `TypeError`
  /// synchronously ("`() => bool` is not a subtype of `() => Future<Never>`
  /// (or similar)") before `.timeout()` ever subscribes to the original
  /// future, leaving [connect]'s own thrown exception with no listener at
  /// all -- reported by the Dart zone as a genuinely unhandled error a beat
  /// later, even though the TypeError itself lands in this method's own
  /// `try`/`catch` and looks handled (observed regression: this exact
  /// combination is exercised by
  /// `connection_ensuring_sender_test.dart`'s own "a connect() that throws"
  /// case). This wrapper's `async` return type is declared `Future<bool>`
  /// explicitly, so the future `.timeout()` sees is always genuinely
  /// `Future<bool>` regardless of what [connect]'s own concrete
  /// implementation infers.
  Future<bool> _callConnect(String deviceId) async => connect(deviceId);

  /// The actual `RelaySendFn`-shaped function to wire into
  /// `RelayEngine(send: ...)`. Connects first if not already connected
  /// (or waits on an in-flight connect to the same peer), then sends.
  /// Never throws -- a connect failure or a send failure both surface as
  /// `false`, exactly what `RelayEngine._attempt` already expects and
  /// handles (queue, retry via an alternate route, or leave queued).
  /// [_ensureConnected] itself can never throw ([_runConnect]'s own
  /// `try`/`catch` already converts any connect failure to `false` and logs
  /// it there), so only the [send] leg below needs its own guard.
  Future<bool> ensureConnectedAndSend(
    String nextHopId,
    Uint8List payload,
  ) async {
    final connected = await _ensureConnected(nextHopId);
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
