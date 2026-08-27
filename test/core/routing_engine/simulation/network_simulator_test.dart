// Tests for NetworkSimulator / SimulatedLink (E04-T01, EARS-SIM-1/2/3,
// FR-VER-004).
//
// Pure-Dart, no platform dependency, no wall-clock — every scenario here
// must stay reproducible: no DateTime.now(), no unseeded Random() anywhere
// in this diff.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/routing_engine/simulation/network_simulator.dart';
import 'package:nexora/core/routing_engine/simulation/simulated_link.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  test('test_EARS_SIM_1_same_seed_same_outcomes', () {
    // Two independent NetworkSimulator instances built from the same seed
    // must produce byte-identical *sequences* of loss/delivery decisions —
    // not merely the same final outcome. EARS-SIM-1 is about the sequence,
    // so the whole list is the assertion.
    List<SendResult> runSequence(int seed, {required double lossRate}) {
      final sim = NetworkSimulator(seed: seed);
      sim.setLink(
        'A',
        'B',
        SimulatedLink(
          latencyMs: 50,
          packetLossRate: lossRate,
          batteryDrainPerMessage: 1.0,
        ),
      );
      return [for (var i = 0; i < 20; i++) sim.send('A', 'B', bytes)];
    }

    final resultA = runSequence(42, lossRate: 0.5);
    final resultB = runSequence(42, lossRate: 0.5);
    expect(resultA, equals(resultB));

    // Guard against the assertion above passing vacuously: at a 0.5 loss
    // rate over 20 sends the sequence must contain BOTH outcomes, otherwise
    // "identical sequences" would be trivially true of a constant.
    expect(resultA, contains(const SendResult.lost()));
    expect(resultA, contains(const SendResult.delivered(50)));

    // And the same at a different loss rate, so determinism isn't an
    // artifact of one particular rate.
    expect(
      runSequence(7, lossRate: 0.3),
      equals(runSequence(7, lossRate: 0.3)),
    );

    // Battery accumulation is part of the reproducible state too: the same
    // seed must charge the same total drain.
    double drainForSeed(int seed) {
      final sim = NetworkSimulator(seed: seed);
      sim.setLink(
        'A',
        'B',
        const SimulatedLink(
          latencyMs: 50,
          packetLossRate: 0.5,
          batteryDrainPerMessage: 1.0,
        ),
      );
      for (var i = 0; i < 20; i++) {
        sim.send('A', 'B', bytes);
      }
      return sim.batteryDrainedFor('A');
    }

    expect(drainForSeed(42), equals(drainForSeed(42)));
  });

  test(
    'test_EARS_SIM_1_different_seeds_can_diverge',
    () {
      // Not a strict requirement that they always differ, but with enough
      // sends at a mid-range loss rate, two different seeds should produce
      // a different sequence of outcomes at least once — otherwise the
      // seed isn't actually driving the randomness.
      List<SendResult> outcomesFor(int seed) {
        final sim = NetworkSimulator(seed: seed);
        sim.setLink(
          'A',
          'B',
          const SimulatedLink(
            latencyMs: 10,
            packetLossRate: 0.5,
            batteryDrainPerMessage: 0.1,
          ),
        );
        return [for (var i = 0; i < 30; i++) sim.send('A', 'B', bytes)];
      }

      final seed1 = outcomesFor(1);
      final seed2 = outcomesFor(2);
      expect(seed1, isNot(equals(seed2)));
    },
  );

  test('test_EARS_SIM_2_down_link_returns_no_route_then_recovers', () {
    final sim = NetworkSimulator(seed: 1);
    sim.setLink(
      'A',
      'B',
      const SimulatedLink(
        latencyMs: 20,
        packetLossRate: 0.0,
        batteryDrainPerMessage: 0.2,
      ),
    );

    // Up: delivers.
    expect(sim.send('A', 'B', bytes), equals(const SendResult.delivered(20)));

    // Partition: set the link down.
    sim.setLink(
      'A',
      'B',
      const SimulatedLink(
        latencyMs: 20,
        packetLossRate: 0.0,
        batteryDrainPerMessage: 0.2,
        up: false,
      ),
    );
    sim.tick();
    expect(sim.send('A', 'B', bytes), equals(const SendResult.noRoute()));
    expect(sim.send('A', 'B', bytes), equals(const SendResult.noRoute()));

    // Heal: set the link back up.
    sim.setLink(
      'A',
      'B',
      const SimulatedLink(
        latencyMs: 20,
        packetLossRate: 0.0,
        batteryDrainPerMessage: 0.2,
      ),
    );
    sim.tick();
    expect(sim.send('A', 'B', bytes), equals(const SendResult.delivered(20)));
  });

  test('test_EARS_SIM_3_battery_accumulates_on_successful_sends', () {
    final sim = NetworkSimulator(seed: 3);
    sim.setLink(
      'A',
      'B',
      const SimulatedLink(
        latencyMs: 5,
        packetLossRate: 0.0,
        batteryDrainPerMessage: 1.5,
      ),
    );

    expect(sim.batteryDrainedFor('A'), equals(0.0));

    sim.send('A', 'B', bytes);
    expect(sim.batteryDrainedFor('A'), equals(1.5));

    sim.send('A', 'B', bytes);
    sim.send('A', 'B', bytes);
    expect(sim.batteryDrainedFor('A'), equals(4.5));

    // The receiving node never accrues drain from this send.
    expect(sim.batteryDrainedFor('B'), equals(0.0));
  });

  test(
    'test_EARS_SIM_3_battery_not_charged_on_lost_or_no_route_sends',
    () {
      final sim = NetworkSimulator(seed: 5);
      sim.setLink(
        'A',
        'B',
        const SimulatedLink(
          latencyMs: 5,
          packetLossRate: 1.0, // always lost
          batteryDrainPerMessage: 2.0,
        ),
      );

      final result = sim.send('A', 'B', bytes);
      expect(result, equals(const SendResult.lost()));
      expect(sim.batteryDrainedFor('A'), equals(0.0));

      // No link at all from C to D.
      final noRoute = sim.send('C', 'D', bytes);
      expect(noRoute, equals(const SendResult.noRoute()));
      expect(sim.batteryDrainedFor('C'), equals(0.0));
    },
  );

  test('test_send_missing_link_returns_no_route', () {
    final sim = NetworkSimulator(seed: 9);
    sim.addNode('A');
    sim.addNode('B');

    expect(sim.send('A', 'B', bytes), equals(const SendResult.noRoute()));

    // Directional: A->B set but not B->A.
    sim.setLink(
      'A',
      'B',
      const SimulatedLink(
        latencyMs: 5,
        packetLossRate: 0.0,
        batteryDrainPerMessage: 0.1,
      ),
    );
    expect(sim.send('A', 'B', bytes), equals(const SendResult.delivered(5)));
    expect(sim.send('B', 'A', bytes), equals(const SendResult.noRoute()));
  });

  test('test_links_are_independently_configurable_per_direction', () {
    // Task §5: "directional, A->B may differ from B->A". Presence/absence is
    // not enough — the two directions must carry independent properties.
    final sim = NetworkSimulator(seed: 17);
    sim.setLink(
      'A',
      'B',
      const SimulatedLink(
        latencyMs: 5,
        packetLossRate: 0.0,
        batteryDrainPerMessage: 1.0,
      ),
    );
    sim.setLink(
      'B',
      'A',
      const SimulatedLink(
        latencyMs: 250,
        packetLossRate: 0.0,
        batteryDrainPerMessage: 4.0,
      ),
    );

    // Different latency per direction.
    expect(sim.send('A', 'B', bytes), equals(const SendResult.delivered(5)));
    expect(sim.send('B', 'A', bytes), equals(const SendResult.delivered(250)));

    // Different battery cost, charged to the sender of each direction only.
    expect(sim.batteryDrainedFor('A'), equals(1.0));
    expect(sim.batteryDrainedFor('B'), equals(4.0));

    // Taking one direction down leaves the other usable — an asymmetric
    // partition, which is the case T02's route selection has to survive.
    sim.setLink('A', 'B', sim.linkBetween('A', 'B')!.copyWith(up: false));
    expect(sim.send('A', 'B', bytes), equals(const SendResult.noRoute()));
    expect(sim.send('B', 'A', bytes), equals(const SendResult.delivered(250)));
  });

  test('test_removeLink_makes_send_return_no_route', () {
    final sim = NetworkSimulator(seed: 11);
    sim.setLink(
      'A',
      'B',
      const SimulatedLink(
        latencyMs: 5,
        packetLossRate: 0.0,
        batteryDrainPerMessage: 0.1,
      ),
    );
    expect(sim.send('A', 'B', bytes), equals(const SendResult.delivered(5)));

    sim.removeLink('A', 'B');
    expect(sim.send('A', 'B', bytes), equals(const SendResult.noRoute()));
  });

  test('test_tick_advances_tick_count', () {
    final sim = NetworkSimulator(seed: 13);
    expect(sim.tickCount, equals(0));
    sim.tick();
    sim.tick();
    expect(sim.tickCount, equals(2));
  });

  test('test_simulatedLink_copyWith_overrides_only_given_fields', () {
    const original = SimulatedLink(
      latencyMs: 10,
      packetLossRate: 0.1,
      batteryDrainPerMessage: 0.5,
      up: true,
    );

    final down = original.copyWith(up: false);
    expect(down.latencyMs, equals(10));
    expect(down.packetLossRate, equals(0.1));
    expect(down.batteryDrainPerMessage, equals(0.5));
    expect(down.up, isFalse);

    final fasterLink = original.copyWith(latencyMs: 99);
    expect(fasterLink.latencyMs, equals(99));
    expect(fasterLink.packetLossRate, equals(0.1));
  });
}
