// core/routing_engine — routing engine (E04-T02).
//
// The mesh's decision-making core: given known links (populated via
// recordLinkMeasurement — either this device's own direct neighbors, or,
// for multi-hop graph knowledge, links reported for other node pairs; see
// the `from` param below), compute the lowest-cost path to a destination,
// decide when a better path is worth migrating to (make-before-break,
// OQ-E04-2), and recover when the active route fails (FR-ROUTE-009).
//
// This engine only decides paths and costs. It never sends or receives
// bytes (T04/T03's job) and never actually probes a candidate route before
// migrating — considerMigration returns a DECISION only; the caller (T04)
// is responsible for validating the candidate route (a real heartbeat/test
// send) before dropping the old one. See task §4's seam note.
import 'route_cost_calculator.dart';

/// An ordered path from this device to [destinationId]. [hops] lists the
/// relay node ids in order, ending with [destinationId] itself — an empty
/// list is never valid for a real route (use `null` instead, per
/// `computeRoute`'s contract).
class Route {
  final String destinationId;
  final List<String> hops;
  final double cost;

  const Route({
    required this.destinationId,
    required this.hops,
    required this.cost,
  });

  @override
  bool operator ==(Object other) {
    if (other is! Route) return false;
    if (other.destinationId != destinationId) return false;
    if (other.cost != cost) return false;
    if (other.hops.length != hops.length) return false;
    for (var i = 0; i < hops.length; i++) {
      if (other.hops[i] != hops[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(destinationId, cost, Object.hashAll(hops));

  @override
  String toString() =>
      'Route(destinationId: $destinationId, hops: $hops, cost: $cost)';
}

/// Outcome of `RoutingEngine.considerMigration` — a make-before-break
/// DECISION only (see file header). `stay()` means keep the current active
/// route; `migrateTo(route)` means the candidate has met the >=20%/>=10
/// sample bar and the caller should validate it before switching.
sealed class MigrationDecision {
  const MigrationDecision();

  const factory MigrationDecision.stay() = MigrationDecisionStay;
  const factory MigrationDecision.migrateTo(Route route) =
      MigrationDecisionMigrateTo;
}

final class MigrationDecisionStay extends MigrationDecision {
  const MigrationDecisionStay();

  @override
  bool operator ==(Object other) => other is MigrationDecisionStay;

  @override
  int get hashCode => (MigrationDecisionStay).hashCode;

  @override
  String toString() => 'MigrationDecision.stay()';
}

final class MigrationDecisionMigrateTo extends MigrationDecision {
  final Route route;
  const MigrationDecisionMigrateTo(this.route);

  @override
  bool operator ==(Object other) =>
      other is MigrationDecisionMigrateTo && other.route == route;

  @override
  int get hashCode => Object.hash(MigrationDecisionMigrateTo, route);

  @override
  String toString() => 'MigrationDecision.migrateTo($route)';
}

class _MigrationTracking {
  List<String> candidateHops;
  int consecutiveSamples;

  _MigrationTracking({
    required this.candidateHops,
    required this.consecutiveSamples,
  });
}

class RoutingEngine {
  /// >=20% cheaper, per OQ-E04-2 — TUNABLE, explicitly flagged (epic.md).
  static const double kMigrationImprovementThreshold = 0.20;

  /// >=10 consecutive samples holding the advantage, per OQ-E04-2 —
  /// TUNABLE. A "sample" is one `considerMigration` call — this engine
  /// never reads wall-clock time or the simulator's `tick()` (T01 review
  /// note: `tick()` has no per-tick sampling hook to correlate against), so
  /// production code drives this by calling `considerMigration` from its
  /// own periodic timer and tests drive it by calling it in a loop.
  static const int kMigrationStabilityTicks = 10;

  final String selfId;

  /// Directed adjacency of known link cost factors: `_knownLinks[a][b]` is
  /// the a->b link. Populated by `recordLinkMeasurement`.
  final Map<String, Map<String, RouteCostFactors>> _knownLinks = {};

  final Map<String, Route> _activeRoutes = {};
  final Map<String, _MigrationTracking> _migrationTracking = {};

  /// The most recent route a caller told us it is CURRENTLY transmitting
  /// over for a destination, via [noteAttemptedRoute] — deliberately kept
  /// separate from [_activeRoutes] (E04-B01). [_activeRoutes] is the
  /// validated "in use" route that [considerMigration] compares against;
  /// [_lastAttemptedRoute] exists solely so [onRouteFailure] can blame the
  /// correct first-hop link for a per-packet forward attempt (e.g.
  /// `RelayEngine`'s) that used whatever [computeRoute] currently returns,
  /// without that attempt being mistaken for a validated route switch.
  final Map<String, Route> _lastAttemptedRoute = {};

  RoutingEngine({required this.selfId});

  /// Updates this device's view of a direct neighbor's link quality
  /// (§3). `lossRate` (0.0-1.0) is converted to `reliability = 1 -
  /// lossRate`.
  ///
  /// [from] is scaffolding beyond §3's documented single-neighbor call
  /// shape: it defaults to [selfId] (the primary, documented use — this
  /// device recording one of its own direct neighbors), but a test or a
  /// future link-state-flooding integration can pass a different source
  /// node id to record a link this device has learned about between two
  /// *other* nodes. Multi-hop route computation (§6's risk: 3-node relay
  /// and partitioned-graph tests) is impossible without some way to
  /// populate links beyond this device's own 1-hop neighborhood, and no
  /// separate flooding mechanism is in this task's scope (T04/T03 own real
  /// transport) — this optional param is the minimal, additive way to seed
  /// that graph knowledge without inventing a second recording method.
  void recordLinkMeasurement(
    String neighborId, {
    required int latencyMs,
    required double lossRate,
    required double batteryDrain,
    String? from,
  }) {
    final source = from ?? selfId;
    _knownLinks.putIfAbsent(source, () => {})[neighborId] = RouteCostFactors(
      latencyMs: latencyMs,
      reliability: (1 - lossRate).clamp(0.0, 1.0),
      batteryDrainRate: batteryDrain,
      hopCount: 1,
    );
  }

  /// Removes a known directed link (e.g. a hop reporting `noRoute`, or a
  /// test simulating a partition) — the link is no longer considered when
  /// computing routes.
  void removeLink(String fromId, String toId) {
    _knownLinks[fromId]?.remove(toId);
  }

  /// The route currently tracked as "in use" for [destinationId], or
  /// `null` if none has been set. Scaffolding for testing
  /// `considerMigration`/`onRouteFailure` without a real transport layer —
  /// production code sets this once a caller (T04) has actually switched
  /// to a route (after probing, per the make-before-break seam in §4).
  Route? activeRouteFor(String destinationId) => _activeRoutes[destinationId];

  /// Explicitly marks [route] as the active route for its destination.
  /// Resets any in-progress migration-stability tracking for that
  /// destination, since switching routes starts a fresh comparison.
  ///
  /// Also discards any [noteAttemptedRoute] record for that destination
  /// (E04-B01 review): a validated switch makes an earlier per-packet
  /// attempt over a *different* path obsolete, and leaving it in place
  /// would make [onRouteFailure] blacklist the stale attempt's first hop
  /// instead of the route that actually just failed.
  void setActiveRoute(Route route) {
    _activeRoutes[route.destinationId] = route;
    _migrationTracking.remove(route.destinationId);
    _lastAttemptedRoute.remove(route.destinationId);
  }

  /// Records [route] as the link currently being transmitted over for its
  /// destination, WITHOUT implying a validated route switch (E04-B01).
  ///
  /// This exists for callers (e.g. `RelayEngine._attempt`) that need
  /// `onRouteFailure` to blame the correct first-hop link for a forward
  /// attempt that is just using whatever `computeRoute` currently returns —
  /// not a genuine, validated migration. Deliberately does NOT write to
  /// [_activeRoutes] (unlike [setActiveRoute]): [_activeRoutes] is what
  /// [considerMigration] compares the best-known route against, and a
  /// per-packet relay attempt runs on every `processQueue()` pass — writing
  /// `computeRoute`'s answer (already the cheapest known route) into
  /// [_activeRoutes] on every attempt would collapse the active/best gap
  /// immediately and permanently suppress `migrateTo` from ever being
  /// reached, which is the same defect this method exists to fix, just
  /// relocated rather than removed. See E04-B01's regression test
  /// `test_EARS_ROUTE_2_relay_traffic_does_not_reset_migration_window`.
  void noteAttemptedRoute(Route route) {
    _lastAttemptedRoute[route.destinationId] = route;
  }

  /// The lowest-cost known path to [destinationId] under [profile], or
  /// `null` if none exists (no known links form a path — e.g. a
  /// partitioned graph).
  Route? computeRoute(String destinationId, TrafficProfile profile) {
    return _bestRoute(destinationId, profile);
  }

  /// E04-B16: link id -> the peer identity (`selfDeviceId`) it announced.
  final Map<String, String> _identityByLink = {};

  /// E04-B16 (human decision 2026-09-15, "routing alias map"): records that
  /// the direct link [linkId] belongs to the peer whose announced identity is
  /// [selfDeviceId], so a packet addressed to that identity (E04-B12/B13/B15's
  /// addressing) can be routed over that link. The graph itself stays keyed by
  /// link ids; only the destination is resolved.
  ///
  /// Scoped deliberately narrowly, because this is a reverse lookup of a
  /// peer-asserted value (see E04-B13 §1a):
  /// - The caller records aliases only for `trusted`/`allowed` relationships,
  ///   so a stranger announcing someone else's identity never gets one.
  /// - Used ONLY to pick a next hop for forwarding. It never grants trust, and
  ///   never changes where decrypted content is filed. The payload stays
  ///   end-to-end encrypted, so a wrong alias can at worst delay a packet,
  ///   never expose it.
  /// - If two different links claim the same identity, the alias is treated
  ///   as ambiguous and resolves to nothing, rather than guessing.
  /// A link that re-announces a different identity replaces its old alias.
  void recordIdentityAlias(String linkId, String selfDeviceId) {
    _identityByLink[linkId] = selfDeviceId;
  }

  /// Forgets [linkId]'s alias (e.g. the relationship is no longer trusted).
  void forgetIdentityAlias(String linkId) {
    _identityByLink.remove(linkId);
  }

  /// The single link whose alias is [selfDeviceId], or `null` if none or
  /// more than one claims it.
  String? _linkForIdentity(String selfDeviceId) {
    String? found;
    for (final entry in _identityByLink.entries) {
      if (entry.value != selfDeviceId) continue;
      if (found != null) return null; // ambiguous
      found = entry.key;
    }
    return found;
  }

  /// Compares the currently-active route's cost against the best known
  /// alternative and applies the make-before-break rule (OQ-E04-2):
  /// migrate only once the alternative is >=20% cheaper AND has held that
  /// advantage for >=10 consecutive `considerMigration` samples. Returns
  /// the DECISION only — see file header for the probing seam.
  MigrationDecision considerMigration(
    String destinationId,
    TrafficProfile profile,
  ) {
    final active = _activeRoutes[destinationId];
    if (active == null) {
      // Nothing to migrate away from yet.
      return const MigrationDecision.stay();
    }

    // The active route's cost must be re-derived from the CURRENT known
    // links, never read off the stored Route. `Route.cost` is a snapshot
    // taken when the route was computed; if the active route's links have
    // since degraded, comparing against that stale snapshot makes a
    // genuinely-better alternative look insufficient and the engine stays
    // wedged on a rotten route forever (E04-T02 review finding F2 —
    // L-backend-003: when a cached value becomes the authority for a
    // property, re-audit every reader of it). A route whose links are no
    // longer known at all is not defensible: treat it as infinite cost.
    final activeCost = _currentCostOf(active.hops, profile) ?? double.infinity;

    final best = _bestRoute(destinationId, profile);
    final improved = best != null &&
        !_hopsEqual(best.hops, active.hops) &&
        best.cost <= activeCost * (1 - kMigrationImprovementThreshold);

    if (!improved) {
      _migrationTracking.remove(destinationId);
      return const MigrationDecision.stay();
    }

    final tracking = _migrationTracking[destinationId];
    if (tracking != null && _hopsEqual(tracking.candidateHops, best.hops)) {
      tracking.consecutiveSamples++;
    } else {
      _migrationTracking[destinationId] = _MigrationTracking(
        candidateHops: best.hops,
        consecutiveSamples: 1,
      );
    }

    final samples = _migrationTracking[destinationId]!.consecutiveSamples;
    if (samples >= kMigrationStabilityTicks) {
      _migrationTracking.remove(destinationId);
      return MigrationDecision.migrateTo(best);
    }
    return const MigrationDecision.stay();
  }

  /// FR-ROUTE-009: called when the active route to [destinationId] fails
  /// (a hop reported `noRoute` or repeated loss). Marks the failed route's
  /// first-hop link (this device's own next hop, the one it directly
  /// observed failing) as down, recomputes, and returns the next-best
  /// route — or `null` if none exists, so the caller can queue/retry
  /// rather than silently dropping the send.
  ///
  /// [profile] (E07-B02 fix) — the recovery route is computed under
  /// EXACTLY this profile, always supplied by the caller, who always knows
  /// it (`RelayEngine._attempt` passes its own `_profile`;
  /// `CallMigrationController.notifyRouteFailure` passes
  /// `TrafficProfile.realtime`). This method used to fall back to a sticky
  /// `_lastProfile[destinationId]` map written by `computeRoute`/
  /// `considerMigration` — but that map is shared across every caller for
  /// one destination, so an unrelated caller (e.g. the Dashboard's own
  /// connectivity poll, which calls `computeRoute(peerId, interactive)` for
  /// every known peer) could silently overwrite it and make a call's
  /// route-failure recovery pick the wrong profile purely because a
  /// different screen happened to be open (review finding, E07-B02). No
  /// caller-agnostic sticky state can ever be correct here — each call
  /// site's own profile is the only thing that can be.
  Route? onRouteFailure(String destinationId, TrafficProfile profile) {
    final failed = _lastAttemptedRoute[destinationId] ?? _activeRoutes[destinationId];
    if (failed != null && failed.hops.isNotEmpty) {
      removeLink(selfId, failed.hops.first);
    }
    final next = _bestRoute(destinationId, profile);
    if (next != null) {
      _activeRoutes[destinationId] = next;
    } else {
      _activeRoutes.remove(destinationId);
    }
    _migrationTracking.remove(destinationId);
    _lastAttemptedRoute.remove(destinationId);
    return next;
  }

  /// Current total cost of walking [hops] from [selfId] under [profile],
  /// summed from the links known RIGHT NOW — or `null` if any hop on the
  /// path is no longer a known link (the path is not currently viable).
  double? _currentCostOf(List<String> hops, TrafficProfile profile) {
    if (hops.isEmpty) return null;
    var total = 0.0;
    var node = selfId;
    for (final hop in hops) {
      final factors = _knownLinks[node]?[hop];
      if (factors == null) return null;
      total += RouteCostCalculator.cost(factors: factors, profile: profile);
      node = hop;
    }
    return total;
  }

  bool _hopsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Dijkstra's algorithm over `_knownLinks`, using
  /// `RouteCostCalculator.cost` as each edge's weight (each recorded link
  /// carries `hopCount: 1`, so a multi-hop route's total cost is the
  /// linear weighted-sum formula's natural sum over its edges).
  Route? _bestRoute(String destinationId, TrafficProfile profile) {
    final direct = _bestRouteToNode(destinationId, profile);
    if (direct != null) return direct;
    // E04-B16: a destination that is not itself a graph node may be a peer
    // identity with a recorded alias to one of this device's links. Every
    // lookup (computeRoute, considerMigration, onRouteFailure) goes through
    // here, so an identity-addressed destination behaves like any other.
    final linkId = _linkForIdentity(destinationId);
    if (linkId == null) return null;
    final viaLink = _bestRouteToNode(linkId, profile);
    if (viaLink == null) return null;
    return Route(
      destinationId: destinationId,
      hops: viaLink.hops,
      cost: viaLink.cost,
    );
  }

  Route? _bestRouteToNode(String destinationId, TrafficProfile profile) {
    if (destinationId == selfId) return null;

    final dist = <String, double>{selfId: 0.0};
    final prev = <String, String>{};
    final visited = <String>{};
    final frontier = <String>{selfId};

    while (frontier.isNotEmpty) {
      String? current;
      var currentDist = double.infinity;
      for (final node in frontier) {
        final d = dist[node] ?? double.infinity;
        if (d < currentDist) {
          currentDist = d;
          current = node;
        }
      }
      if (current == null) break;
      frontier.remove(current);
      if (!visited.add(current)) continue;
      if (current == destinationId) break;

      final neighbors = _knownLinks[current];
      if (neighbors == null) continue;
      for (final entry in neighbors.entries) {
        final next = entry.key;
        if (visited.contains(next)) continue;
        final edgeCost =
            RouteCostCalculator.cost(factors: entry.value, profile: profile);
        final candidateDist = currentDist + edgeCost;
        if (candidateDist < (dist[next] ?? double.infinity)) {
          dist[next] = candidateDist;
          prev[next] = current;
          frontier.add(next);
        }
      }
    }

    final totalCost = dist[destinationId];
    if (totalCost == null) return null;

    final hops = <String>[];
    var node = destinationId;
    while (node != selfId) {
      hops.add(node);
      final p = prev[node];
      if (p == null) return null; // unreachable — should not happen here
      node = p;
    }
    return Route(
      destinationId: destinationId,
      hops: hops.reversed.toList(),
      cost: totalCost,
    );
  }
}
