// core/routing_engine — link-quality feed (E06-T04).
//
// The subscription E04-B03 named and E05 never wrote: turns
// `TransportService.linkQuality` events (real RSSI/latency/loss from
// `BluetoothTransport.kt`, or `LoopbackTransport.kt`'s deterministic
// stand-in) into `RoutingEngine.recordLinkMeasurement` calls. Without a
// subscriber closing this loop, `RoutingEngine._knownLinks` stays empty on
// a real device and `computeRoute()` always returns `null` — see the task
// file's §2 for why this has been dropped twice already (E04-B03, E05).
//
// This feed makes exactly one translation decision (§3 of the task file):
// `batteryDrain` is not observable from the transport, so it passes a
// documented neutral constant rather than inventing a reading — see
// [kUnmeasuredBatteryDrainNeutral] and OQ-E06-T04-1.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../transport/transport_service.dart';
import 'routing_engine.dart';

class LinkQualityFeed {
  /// `batteryDrain` has no producer in the transport (OQ-E06-T04-1,
  /// resolved 2026-08-29, option (a)): this neutral constant is passed for
  /// every recorded measurement so `batteryDrainRate` contributes equally
  /// to every neighbour's cost and the *measured* factors (latency, loss)
  /// decide the ranking — the formula degrades to a battery-blind ranking
  /// rather than faking a reading. `RouteCostFactors.batteryDrainRate`
  /// documents its expected range as `0.0-1.0`; `0.0` means "no battery
  /// penalty applied," the most literal reading of "neutral." Real
  /// per-peer battery reporting (option (c) — exchanged in the frame
  /// header) is deferred to whichever future epic first exercises
  /// battery-aware routing; it must land as its own task.
  static const double kUnmeasuredBatteryDrainNeutral = 0.0;

  LinkQualityFeed({required this.transport, required this.routing});

  final TransportService transport;
  final RoutingEngine routing;
  StreamSubscription<LinkQuality>? _subscription;

  /// E04-B37: one `connectionState` subscription per neighbour this feed has
  /// recorded a measurement for, so the routing graph can forget the link
  /// when that connection ends.
  ///
  /// Without this, `removeLink` had no production caller on the link-down
  /// path at all — its only other callers are `onRouteFailure` (a *route*
  /// failure, not a link going down) and the test-only `NetworkSimulator`.
  /// `_knownLinks` therefore kept a dead peer forever, `computeRoute` kept
  /// returning a path over it, and every caller asking "is there a route to
  /// this peer?" got a stale `yes`. Observed live 2026-09-18: with the peer's
  /// Bluetooth off and its socket closed, the Dashboard still read
  /// "Connected" 90 s later (E04-B37; evidence in E04-B36's run log).
  final Map<String, StreamSubscription<ConnectionState>> _connectionSubs =
      <String, StreamSubscription<ConnectionState>>{};

  /// Subscribes to [TransportService.linkQuality]. Idempotent: a second
  /// call while already subscribed is a no-op, so a caller that calls
  /// `start()` more than once (e.g. bindings re-running under test) never
  /// ends up with two subscriptions double-recording the same event.
  void start() {
    if (_subscription != null) return;
    _subscription = transport.linkQuality.listen(_onMeasurement);
  }

  /// Cancels the subscription. Required so tests do not leak subscriptions
  /// between cases.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    // E04-B37: the per-neighbour connection-state subscriptions belong to
    // this object too, and leak the same way if they are not cancelled here.
    for (final StreamSubscription<ConnectionState> sub
        in _connectionSubs.values) {
      await sub.cancel();
    }
    _connectionSubs.clear();
  }

  /// E04-B37: starts following [deviceId]'s connection state, once, so the
  /// routing graph learns when this link goes down. Idempotent per device: a
  /// neighbour reporting a measurement every few seconds must not accumulate
  /// one subscription per measurement.
  void _watchConnectionState(String deviceId) {
    if (_connectionSubs.containsKey(deviceId)) return;
    _connectionSubs[deviceId] = transport
        .connectionState(deviceId)
        .listen((ConnectionState state) => _onConnectionState(deviceId, state));
  }

  /// E04-B37: removes the `selfId -> deviceId` link from the routing graph
  /// when that connection ends.
  ///
  /// Only `disconnected` and `failed` remove. `connecting`/`connected` must
  /// not: a link that is mid-handshake or healthy is still a link, and
  /// removing it here would make the graph flap on every ordinary connect.
  /// A peer that comes back re-records its link through the existing
  /// measurement path, so nothing needs to re-add it explicitly.
  void _onConnectionState(String deviceId, ConnectionState state) {
    if (state != ConnectionState.disconnected &&
        state != ConnectionState.failed) {
      return;
    }
    routing.removeLink(routing.selfId, deviceId);
  }

  void _onMeasurement(LinkQuality quality) {
    if (!_isWithinBounds(quality)) {
      // EARS-ROUTE-12: reject loudly rather than substitute a default —
      // never silently drop nor pass nonsense into the cost formula.
      // `debugPrint` (not `throw`): a malformed value from a native layer
      // this task cannot control must not crash the feed's subscription or
      // propagate an exception across a stream listener callback.
      debugPrint(
        'LinkQualityFeed: rejecting out-of-range measurement for '
        '${quality.deviceId} (latencyMs=${quality.latencyMs}, '
        'lossRate=${quality.lossRate}) — not recorded.',
      );
      return;
    }
    routing.recordLinkMeasurement(
      quality.deviceId,
      latencyMs: quality.latencyMs,
      lossRate: quality.lossRate,
      batteryDrain: kUnmeasuredBatteryDrainNeutral,
    );
    // E04-B37: a neighbour we have recorded a link for is exactly the set
    // whose disappearance the routing graph must hear about.
    _watchConnectionState(quality.deviceId);
  }

  /// `latencyMs` must be non-negative; `lossRate` must be a `0.0-1.0` ratio
  /// (§6 risk: loopback and Bluetooth must not diverge in units — a
  /// percentage would silently pass a looser check and corrupt the cost
  /// formula, so this is a hard bound, not a clamp).
  bool _isWithinBounds(LinkQuality quality) =>
      quality.latencyMs >= 0 &&
      quality.lossRate >= 0.0 &&
      quality.lossRate <= 1.0;
}
