// core/routing_engine — route cost calculator (E04-T02, FR-ROUTE-002).
//
// Pure, no I/O — the single place the weighted-sum cost formula lives
// (OQ-E04-1, resolved in epics/E04-mesh-routing/epic.md):
//
//   cost = w1*latencyMs + w2*(1-reliability) + w3*batteryDrainRate
//        + w4*hopCount
//
// Two named weight profiles: `interactive` (1:1 chat — latency-weighted)
// and `bulk` (large transfers — reliability/battery-weighted). Lower cost
// is better. Weights below are placeholders, explicitly flagged tunable —
// not a second foundational decision (epic.md's resolution of OQ-E04-1).
enum TrafficProfile { interactive, bulk }

/// Per-hop/per-route cost inputs. `reliability` and `batteryDrainRate` are
/// expected in `0.0-1.0`; `latencyMs` and `hopCount` are non-negative.
class RouteCostFactors {
  final int latencyMs;
  final double reliability;
  final double batteryDrainRate;
  final int hopCount;

  const RouteCostFactors({
    required this.latencyMs,
    required this.reliability,
    required this.batteryDrainRate,
    required this.hopCount,
  });
}

/// Named, tunable weight sets — see the file header for the formula they
/// plug into. TUNABLE: these starting values are a task-sharding
/// implementation detail (epic.md OQ-E04-1), not a locked-in constant;
/// revisit once real usage data exists.
class _Weights {
  final double latency;
  final double unreliability;
  final double battery;
  final double hopCount;

  const _Weights({
    required this.latency,
    required this.unreliability,
    required this.battery,
    required this.hopCount,
  });
}

class RouteCostCalculator {
  /// `interactive` (1:1 chat): latency dominates — a slow route is felt
  /// immediately in a live conversation.
  static const _Weights _interactive = _Weights(
    latency: 0.01,
    unreliability: 10.0,
    battery: 2.0,
    hopCount: 1.0,
  );

  /// `bulk` (large transfers): reliability and battery dominate — a
  /// dropped/retried large transfer costs far more than a few extra ms.
  static const _Weights _bulk = _Weights(
    latency: 0.002,
    unreliability: 20.0,
    battery: 5.0,
    hopCount: 1.0,
  );

  /// Weighted-sum cost per the file header formula. Lower is better; pure
  /// function, no I/O, no randomness.
  static double cost({
    required RouteCostFactors factors,
    required TrafficProfile profile,
  }) {
    final weights = switch (profile) {
      TrafficProfile.interactive => _interactive,
      TrafficProfile.bulk => _bulk,
    };
    return weights.latency * factors.latencyMs +
        weights.unreliability * (1 - factors.reliability) +
        weights.battery * factors.batteryDrainRate +
        weights.hopCount * factors.hopCount;
  }
}
