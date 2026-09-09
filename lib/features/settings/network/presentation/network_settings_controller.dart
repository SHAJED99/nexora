// features/settings/network/presentation -- FR-ROUTE-010's screen
// controller (E15-T08, `design/screens/settings-network.md`, GAP-036). Two
// read-only cards over already-shipped services: `TransportService`
// (`core/transport/transport_service.dart`) for Transports, plus
// `TransportService.linkQuality` + `RoutingEngine.activeRouteFor`
// (`core/routing_engine/routing_engine.dart`) for Active routes. Neither
// card offers a control (task §4, `EARS-ROUTE-14`) and neither substitutes a
// default for a missing measurement (task §4, `EARS-ROUTE-13`) --
// [LinkMeasurement] models "not measured" as a distinct type, never a
// sentinel like `0`.
//
// The two cards are wired to DIFFERENT streams on purpose, not merely for
// convenience: Transports reads `discoveredDevices`/`lostDevices` and
// Active routes reads `linkQuality` (+ the synchronous `activeRouteFor`
// call). This keeps `EARS-UI-11`'s "a failed read of one section never
// clears another" real rather than aspirational -- a failure on one stream
// cannot reach the other card's state, because neither card's error flag is
// written from the other card's subscription.
//
// `RoutingEngine.activeRouteFor` is per-destination (task §6 risk note): it
// has no "all routes" accessor, and none is added here (`RoutingEngine` is
// not in this task's `files:`). Peers to check are the ones this controller
// has actually heard a `LinkQuality` measurement for -- `linkQuality`
// already carries `deviceId`, so it doubles as this screen's own knowledge
// of "destinations worth asking `activeRouteFor` about" without adding a
// second enumeration API anywhere.
import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/transport/transport_service.dart';

/// NW6's own row: one `TransportType` this device has ever reported seeing
/// a device over, and whether at least one such device is currently
/// discovered. A type never reported at all (task §4: "no entry is
/// synthesised for a transport the platform did not report") never appears
/// here -- [NetworkSettingsController._seenTypes] only grows on a real
/// `onDeviceDiscovered` event.
class TransportStatus {
  const TransportStatus({required this.type, required this.available});

  final TransportType type;

  /// `true` (`Available`) while at least one currently-discovered device
  /// uses this transport; `false` (`Unavailable`) once every such device
  /// has been lost. Never `null` -- unlike [LinkMeasurement], availability
  /// is always knowable once a type has been seen at all.
  final bool available;
}

/// NW13's "or `Not measured`" as a real type, not a magic number
/// (`EARS-ROUTE-13`, task §6's "the default-substitution reflex"). A
/// widget cannot accidentally render this as `0` the way it could an `int?`
/// defaulted with `?? 0`.
sealed class LinkMeasurement {
  const LinkMeasurement();

  const factory LinkMeasurement.measured({
    required int latencyMs,
    required double lossRate,
  }) = MeasuredLink;

  const factory LinkMeasurement.notMeasured() = NotMeasuredLink;
}

class MeasuredLink extends LinkMeasurement {
  const MeasuredLink({required this.latencyMs, required this.lossRate});

  final int latencyMs;
  final double lossRate;
}

class NotMeasuredLink extends LinkMeasurement {
  const NotMeasuredLink();
}

/// NW11's own row: a destination this device currently has an active route
/// to, its hop count (`hopCount == 1` renders NW12's `Direct`; anything else
/// renders `N hops` -- never `1 hops`, task §4), and NW13's measurement.
class RouteSummary {
  const RouteSummary({
    required this.destinationId,
    required this.hopCount,
    required this.measurement,
  });

  final String destinationId;
  final int hopCount;
  final LinkMeasurement measurement;
}

/// FR-ROUTE-010's screen controller. Holds no second copy of any routing
/// decision and no defaulting rule of its own -- every value it exposes is
/// read straight from [transport]/[routing] (task §2).
class NetworkSettingsController extends GetxController {
  NetworkSettingsController({required this.transport, required this.routing});

  final TransportService transport;
  final RoutingEngine routing;

  /// NW6's list. `null` would be a genuine "loading" state, but neither
  /// `discoveredDevices` nor `lostDevices` offers a one-shot snapshot to
  /// gate on (both are forward-only event streams, unlike a repository's
  /// `Future`-based read) -- so this starts empty, exactly like the
  /// `empty` state NW7 renders, and stays that way until a real device is
  /// discovered. Documented in this task's own Deviations rather than
  /// inventing a synthetic loading delay this app's real services do not
  /// have.
  final RxList<TransportStatus> transports = <TransportStatus>[].obs;

  /// `true` once `discoveredDevices` or `lostDevices` has errored. NW15
  /// replaces the Transports card's list only (`EARS-UI-11`) -- the Active
  /// routes card below is driven entirely by a different stream and stays
  /// rendered.
  final RxBool transportsError = false.obs;

  /// NW11's list. Same "no snapshot to gate on" note as [transports].
  final RxList<RouteSummary> routes = <RouteSummary>[].obs;

  /// `true` once `linkQuality` has errored, or `activeRouteFor` has thrown.
  /// Independent of [transportsError] -- see file header.
  final RxBool routesError = false.obs;

  /// Every `TransportType` this device has EVER reported a discovered
  /// device over. Grows only; `_liveCountByType` (not this set) tracks
  /// whether a seen type is currently available.
  final Set<TransportType> _seenTypes = {};

  /// `deviceId -> TransportType`, so [_onDeviceLost] (which only carries an
  /// id) can find the right type to decrement.
  final Map<String, TransportType> _deviceTypes = {};

  /// Count of currently-discovered devices per type; a type is `Available`
  /// while its count is `> 0`.
  final Map<TransportType, int> _liveCountByType = {};

  /// Every peer id this controller has received at least one `LinkQuality`
  /// measurement for -- the Active routes card's own destination list (file
  /// header).
  final Set<String> _knownPeerIds = {};

  /// The most recent `LinkQuality` per peer id, for NW13's measured branch.
  final Map<String, LinkQuality> _linkQualityByDeviceId = {};

  StreamSubscription<TransportDevice>? _discoveredSub;
  StreamSubscription<String>? _lostSub;
  StreamSubscription<LinkQuality>? _linkQualitySub;

  @override
  void onInit() {
    super.onInit();
    _discoveredSub = transport.discoveredDevices.listen(
      _onDeviceDiscovered,
      onError: (Object _, StackTrace _) => transportsError.value = true,
    );
    _lostSub = transport.lostDevices.listen(
      _onDeviceLost,
      onError: (Object _, StackTrace _) => transportsError.value = true,
    );
    _linkQualitySub = transport.linkQuality.listen(
      _onLinkQuality,
      onError: (Object _, StackTrace _) => routesError.value = true,
    );
  }

  void _onDeviceDiscovered(TransportDevice device) {
    _deviceTypes[device.id] = device.type;
    _seenTypes.add(device.type);
    _liveCountByType[device.type] = (_liveCountByType[device.type] ?? 0) + 1;
    _recomputeTransports();
  }

  void _onDeviceLost(String deviceId) {
    final type = _deviceTypes.remove(deviceId);
    if (type != null) {
      final current = _liveCountByType[type] ?? 0;
      _liveCountByType[type] = current > 0 ? current - 1 : 0;
    }
    _recomputeTransports();
  }

  void _recomputeTransports() {
    transports.value = [
      for (final type in TransportType.values)
        if (_seenTypes.contains(type))
          TransportStatus(
            type: type,
            available: (_liveCountByType[type] ?? 0) > 0,
          ),
    ];
  }

  void _onLinkQuality(LinkQuality quality) {
    _knownPeerIds.add(quality.deviceId);
    _linkQualityByDeviceId[quality.deviceId] = quality;
    _recomputeRoutes();
  }

  void _recomputeRoutes() {
    try {
      final summaries = <RouteSummary>[];
      for (final peerId in _knownPeerIds) {
        final route = routing.activeRouteFor(peerId);
        if (route == null) continue;
        // A direct route's only hop IS the destination -- the one case
        // where `linkQuality` (a direct-neighbor measurement) actually
        // corresponds to this route. A multi-hop route has no aggregate
        // measurement anywhere in this build (`RouteCostCalculator`'s own
        // per-hop factors are private to `RoutingEngine`, task §6) -- that
        // is a real, current fact about what this app can measure, not an
        // invented distinction.
        final quality = _linkQualityByDeviceId[peerId];
        final measurement = (route.hops.length == 1 && quality != null)
            ? LinkMeasurement.measured(
                latencyMs: quality.latencyMs,
                lossRate: quality.lossRate,
              )
            : const LinkMeasurement.notMeasured();
        summaries.add(
          RouteSummary(
            destinationId: peerId,
            hopCount: route.hops.length,
            measurement: measurement,
          ),
        );
      }
      routes.value = summaries;
    } catch (_) {
      routesError.value = true;
    }
  }

  @override
  void onClose() {
    unawaited(_discoveredSub?.cancel());
    unawaited(_lostSub?.cancel());
    unawaited(_linkQualitySub?.cancel());
    super.onClose();
  }
}
