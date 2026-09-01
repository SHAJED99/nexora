// E04-T02 — RouteCostCalculator unit tests (FR-ROUTE-002, OQ-E04-1).
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';

void main() {
  group('RouteCostCalculator', () {
    test('test_cost_calculator_interactive_profile_weights_latency', () {
      // Two routes with equal reliability/battery/hop count but very
      // different latency: under `interactive`, the higher-latency route
      // must cost strictly more (latency is the dominant term).
      const lowLatency = RouteCostFactors(
        latencyMs: 20,
        reliability: 0.95,
        batteryDrainRate: 0.1,
        hopCount: 1,
      );
      const highLatency = RouteCostFactors(
        latencyMs: 2000,
        reliability: 0.95,
        batteryDrainRate: 0.1,
        hopCount: 1,
      );

      final lowCost = RouteCostCalculator.cost(
        factors: lowLatency,
        profile: TrafficProfile.interactive,
      );
      final highCost = RouteCostCalculator.cost(
        factors: highLatency,
        profile: TrafficProfile.interactive,
      );

      expect(highCost, greaterThan(lowCost));

      // The latency delta alone (1980ms) must visibly dominate the
      // interactive-profile cost gap, proving latency is weighted heavily
      // rather than washed out by the other terms.
      expect(highCost - lowCost, greaterThan(5.0));
    });

    test(
      'test_cost_calculator_bulk_profile_weights_reliability_and_battery',
      () {
        // Two routes with identical latency/hop count but very different
        // reliability+battery: under `bulk`, the unreliable/battery-hungry
        // route must cost strictly more, and the gap must be larger under
        // `bulk` than under `interactive` for the same factors (proving
        // the profiles genuinely differ, not just relabel the same
        // weights).
        const good = RouteCostFactors(
          latencyMs: 500,
          reliability: 0.99,
          batteryDrainRate: 0.05,
          hopCount: 1,
        );
        const bad = RouteCostFactors(
          latencyMs: 500,
          reliability: 0.5,
          batteryDrainRate: 2.0,
          hopCount: 1,
        );

        final bulkGood = RouteCostCalculator.cost(
          factors: good,
          profile: TrafficProfile.bulk,
        );
        final bulkBad = RouteCostCalculator.cost(
          factors: bad,
          profile: TrafficProfile.bulk,
        );
        final interactiveGood = RouteCostCalculator.cost(
          factors: good,
          profile: TrafficProfile.interactive,
        );
        final interactiveBad = RouteCostCalculator.cost(
          factors: bad,
          profile: TrafficProfile.interactive,
        );

        expect(bulkBad, greaterThan(bulkGood));
        expect(
          bulkBad - bulkGood,
          greaterThan(interactiveBad - interactiveGood),
        );
      },
    );

    test('cost is a pure function of its inputs (no I/O, deterministic)', () {
      const factors = RouteCostFactors(
        latencyMs: 100,
        reliability: 0.9,
        batteryDrainRate: 0.2,
        hopCount: 2,
      );
      final a = RouteCostCalculator.cost(
        factors: factors,
        profile: TrafficProfile.interactive,
      );
      final b = RouteCostCalculator.cost(
        factors: factors,
        profile: TrafficProfile.interactive,
      );
      expect(a, b);
    });

    test('test_existing_profiles_are_unchanged', () {
      // E07-T10 appends `TrafficProfile.realtime` to this enum. This test
      // re-proves the exact same interactive/bulk comparisons this file's
      // own pre-existing tests above establish still hold -- comparisons
      // only, never a literal cost number (task file §6/§9): a third
      // switch arm must not perturb the `interactive`/`bulk` arms it sits
      // beside.
      const lowLatency = RouteCostFactors(
        latencyMs: 20,
        reliability: 0.95,
        batteryDrainRate: 0.1,
        hopCount: 1,
      );
      const highLatency = RouteCostFactors(
        latencyMs: 2000,
        reliability: 0.95,
        batteryDrainRate: 0.1,
        hopCount: 1,
      );
      expect(
        RouteCostCalculator.cost(
          factors: highLatency,
          profile: TrafficProfile.interactive,
        ),
        greaterThan(
          RouteCostCalculator.cost(
            factors: lowLatency,
            profile: TrafficProfile.interactive,
          ),
        ),
      );

      const good = RouteCostFactors(
        latencyMs: 500,
        reliability: 0.99,
        batteryDrainRate: 0.05,
        hopCount: 1,
      );
      const bad = RouteCostFactors(
        latencyMs: 500,
        reliability: 0.5,
        batteryDrainRate: 2.0,
        hopCount: 1,
      );
      final bulkGood =
          RouteCostCalculator.cost(factors: good, profile: TrafficProfile.bulk);
      final bulkBad =
          RouteCostCalculator.cost(factors: bad, profile: TrafficProfile.bulk);
      final interactiveGood = RouteCostCalculator.cost(
        factors: good,
        profile: TrafficProfile.interactive,
      );
      final interactiveBad = RouteCostCalculator.cost(
        factors: bad,
        profile: TrafficProfile.interactive,
      );
      expect(bulkBad, greaterThan(bulkGood));
      expect(
        bulkBad - bulkGood,
        greaterThan(interactiveBad - interactiveGood),
      );

      // Route-choice regression, matching the task file §8's own framing
      // ("interactive and bulk pick exactly the routes they picked
      // before"): given a pair of route options, `interactive` and `bulk`
      // must each still prefer the SAME option they always did -- adding a
      // third profile must not flip either one's preference.
      const optionA = RouteCostFactors(
        latencyMs: 30,
        reliability: 0.99,
        batteryDrainRate: 0.2,
        hopCount: 1,
      );
      const optionB = RouteCostFactors(
        latencyMs: 30,
        reliability: 0.6,
        batteryDrainRate: 3.0,
        hopCount: 3,
      );
      expect(
        RouteCostCalculator.cost(
              factors: optionA,
              profile: TrafficProfile.interactive,
            ) <
            RouteCostCalculator.cost(
              factors: optionB,
              profile: TrafficProfile.interactive,
            ),
        isTrue,
      );
      expect(
        RouteCostCalculator.cost(factors: optionA, profile: TrafficProfile.bulk) <
            RouteCostCalculator.cost(
              factors: optionB,
              profile: TrafficProfile.bulk,
            ),
        isTrue,
      );
    });

    test('lower is better: fewer hops costs less, all else equal', () {
      const oneHop = RouteCostFactors(
        latencyMs: 50,
        reliability: 0.9,
        batteryDrainRate: 0.1,
        hopCount: 1,
      );
      const threeHops = RouteCostFactors(
        latencyMs: 50,
        reliability: 0.9,
        batteryDrainRate: 0.1,
        hopCount: 3,
      );
      final oneHopCost = RouteCostCalculator.cost(
        factors: oneHop,
        profile: TrafficProfile.bulk,
      );
      final threeHopCost = RouteCostCalculator.cost(
        factors: threeHops,
        profile: TrafficProfile.bulk,
      );
      expect(threeHopCost, greaterThan(oneHopCost));
    });
  });
}
