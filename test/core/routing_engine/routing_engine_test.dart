// E04-T02 — RoutingEngine tests (FR-ROUTE-001/002/005/006/009), tested
// entirely against T01's NetworkSimulator per task §1/§4 — no real
// transport. Per T01's review flags for this task:
//   - SimulatedLink has no ==/hashCode -> we read individual link fields,
//     never compare SimulatedLink instances.
//   - tick() is a bare counter with no sampling hook -> the migration
//     stability window is driven by this engine's own count of
//     `considerMigration` calls (one call = one sample), never by
//     NetworkSimulator.tick()/_tickCount.
//   - send() ignores payload / is per-message not per-byte -> a dummy
//     payload is passed on every simulated send.
//   - no battery-accumulator reset -> a fresh NetworkSimulator per test.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/routing_engine/simulation/network_simulator.dart';
import 'package:nexora/core/routing_engine/simulation/simulated_link.dart';

/// Feeds one directed simulated link's measured factors into [engine] as a
/// link-state record — `from` defaults to the engine's own `selfId` for a
/// direct-neighbor measurement, or names another node when seeding
/// multi-hop graph knowledge (this engine's documented extension, see
/// `routing_engine.dart`'s `recordLinkMeasurement` doc comment).
void _recordFromSimulatedLink(
  RoutingEngine engine,
  NetworkSimulator sim,
  String fromId,
  String toId,
) {
  final link = sim.linkBetween(fromId, toId);
  expect(link, isNotNull, reason: 'test setup: link $fromId->$toId missing');
  engine.recordLinkMeasurement(
    toId,
    latencyMs: link!.latencyMs,
    lossRate: link.packetLossRate,
    batteryDrain: link.batteryDrainPerMessage,
    from: fromId,
  );
}

void main() {
  group('EARS-ROUTE-1 — computeRoute', () {
    test(
      'test_EARS_ROUTE_1_computes_multihop_route_when_no_direct_link',
      () {
        // A -> B -> C, no direct A -> C link at all: the only way to reach
        // C is the 2-hop relay through B.
        final sim = NetworkSimulator(seed: 1);
        sim.setLink(
          'A',
          'B',
          const SimulatedLink(
            latencyMs: 30,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        sim.setLink(
          'B',
          'C',
          const SimulatedLink(
            latencyMs: 40,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );

        final engine = RoutingEngine(selfId: 'A');
        _recordFromSimulatedLink(engine, sim, 'A', 'B');
        _recordFromSimulatedLink(engine, sim, 'B', 'C');

        final route = engine.computeRoute('C', TrafficProfile.interactive);

        expect(route, isNotNull);
        expect(route!.hops, ['B', 'C']);
        expect(route.destinationId, 'C');

        // Prove the relay actually works over the simulator: one send()
        // per hop, per T01's contract (multi-hop pathfinding is this
        // task's job, T01 only simulates one hop at a time).
        final payload = Uint8List.fromList([1, 2, 3]);
        var result = sim.send('A', route.hops.first, payload);
        expect(result, isA<SendResultDelivered>());
        for (var i = 0; i < route.hops.length - 1; i++) {
          result = sim.send(route.hops[i], route.hops[i + 1], payload);
          expect(result, isA<SendResultDelivered>());
        }
      },
    );

    test(
      'test_EARS_ROUTE_1_prefers_direct_link_over_a_worse_relay',
      () {
        // A direct A -> C link exists and is cheap; a relay through B also
        // exists but is far more expensive. The engine must pick the
        // direct link.
        final sim = NetworkSimulator(seed: 2);
        sim.setLink(
          'A',
          'C',
          const SimulatedLink(
            latencyMs: 20,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.05,
          ),
        );
        sim.setLink(
          'A',
          'B',
          const SimulatedLink(
            latencyMs: 500,
            packetLossRate: 0.4,
            batteryDrainPerMessage: 3.0,
          ),
        );
        sim.setLink(
          'B',
          'C',
          const SimulatedLink(
            latencyMs: 500,
            packetLossRate: 0.4,
            batteryDrainPerMessage: 3.0,
          ),
        );

        final engine = RoutingEngine(selfId: 'A');
        _recordFromSimulatedLink(engine, sim, 'A', 'C');
        _recordFromSimulatedLink(engine, sim, 'A', 'B');
        _recordFromSimulatedLink(engine, sim, 'B', 'C');

        final route = engine.computeRoute('C', TrafficProfile.interactive);

        expect(route, isNotNull);
        expect(route!.hops, ['C']);
      },
    );

    test('test_EARS_ROUTE_1_returns_null_when_partitioned', () {
      // A -> B exists; C is registered as a node but has no link from
      // anywhere reachable from A (a genuinely partitioned component).
      final sim = NetworkSimulator(seed: 3);
      sim.setLink(
        'A',
        'B',
        const SimulatedLink(
          latencyMs: 30,
          packetLossRate: 0.0,
          batteryDrainPerMessage: 0.1,
        ),
      );
      sim.addNode('C');

      final engine = RoutingEngine(selfId: 'A');
      _recordFromSimulatedLink(engine, sim, 'A', 'B');

      final route = engine.computeRoute('C', TrafficProfile.interactive);

      expect(route, isNull);
    });

    test(
      'test_EARS_ROUTE_1_returns_null_when_relay_link_removed_mid_route',
      () {
        // A -> B -> C exists, then the B -> C link is removed entirely
        // (T01's removeLink, distinct from merely going down) — the
        // engine must stop offering the now-broken relay.
        final sim = NetworkSimulator(seed: 4);
        sim.setLink(
          'A',
          'B',
          const SimulatedLink(
            latencyMs: 30,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        sim.setLink(
          'B',
          'C',
          const SimulatedLink(
            latencyMs: 40,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );

        final engine = RoutingEngine(selfId: 'A');
        _recordFromSimulatedLink(engine, sim, 'A', 'B');
        _recordFromSimulatedLink(engine, sim, 'B', 'C');

        expect(engine.computeRoute('C', TrafficProfile.interactive),
            isNotNull);

        sim.removeLink('B', 'C');
        engine.removeLink('B', 'C');

        expect(engine.computeRoute('C', TrafficProfile.interactive), isNull);
      },
    );
  });

  group('EARS-ROUTE-2 — considerMigration (make-before-break)', () {
    test('test_EARS_ROUTE_2_does_not_migrate_on_a_single_good_sample', () {
      final engine = RoutingEngine(selfId: 'A');
      engine.setActiveRoute(
        const Route(destinationId: 'dest', hops: ['X', 'dest'], cost: 100.0),
      );
      // Candidate route via Y, far below the 20% threshold in cost, but
      // only sampled once.
      engine.recordLinkMeasurement(
        'Y',
        latencyMs: 1,
        lossRate: 0.0,
        batteryDrain: 0.0,
        from: 'A',
      );
      engine.recordLinkMeasurement(
        'dest',
        latencyMs: 1,
        lossRate: 0.0,
        batteryDrain: 0.0,
        from: 'Y',
      );

      final decision =
          engine.considerMigration('dest', TrafficProfile.interactive);

      expect(decision, const MigrationDecision.stay());
    });

    test(
      'test_EARS_ROUTE_2_does_not_migrate_below_20_percent_improvement',
      () {
        // The candidate must be a route with DIFFERENT hops from the
        // active one, otherwise `considerMigration` short-circuits on the
        // hops-equality guard and the 20% threshold is never evaluated at
        // all (E04-T02 review finding F1: the original version of this
        // test reused the active route's own hops, so it stayed green even
        // with kMigrationImprovementThreshold mutated to 0.0).
        final engine = RoutingEngine(selfId: 'A');

        // Active route A -> X -> dest, cost derived by the engine itself.
        engine.recordLinkMeasurement(
          'X',
          latencyMs: 100,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'A',
        );
        engine.recordLinkMeasurement(
          'dest',
          latencyMs: 100,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'X',
        );
        final active = engine.computeRoute('dest', TrafficProfile.interactive);
        expect(active, isNotNull);
        engine.setActiveRoute(active!);

        // A genuinely distinct candidate A -> Y -> dest that is cheaper,
        // but only by ~5% — well under the 20% bar.
        engine.recordLinkMeasurement(
          'Y',
          latencyMs: 90,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'A',
        );
        engine.recordLinkMeasurement(
          'dest',
          latencyMs: 90,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'Y',
        );

        final candidate =
            engine.computeRoute('dest', TrafficProfile.interactive);
        expect(candidate, isNotNull);
        // Guard the test's own premise: a distinct, cheaper-but-not-20%
        // candidate. If either half stops holding, this test stops testing
        // the threshold and must fail loudly rather than silently pass.
        expect(candidate!.hops, isNot(active.hops));
        final improvement = 1 - candidate.cost / active.cost;
        expect(improvement, greaterThan(0.0));
        expect(improvement, lessThan(RoutingEngine.kMigrationImprovementThreshold));

        // Sample the "considerMigration" bar >=10 times — even sustained,
        // a below-threshold improvement must never trigger migration.
        MigrationDecision? last;
        for (var i = 0; i < 15; i++) {
          last = engine.considerMigration('dest', TrafficProfile.interactive);
        }

        expect(last, const MigrationDecision.stay());
      },
    );

    test(
      'test_EARS_ROUTE_2_migrates_when_active_route_itself_degrades',
      () {
        // Regression for E04-T02 review finding F2. The active route's
        // cost must be re-derived from the links known NOW, not read off
        // the stored Route's snapshot. Here the active direct link rots
        // badly while a much better relay appears: the engine must
        // migrate. Against the snapshot it never would, because the
        // snapshot still remembers the link as it was when it was good.
        final engine = RoutingEngine(selfId: 'A');
        engine.recordLinkMeasurement(
          'dest',
          latencyMs: 10,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'A',
        );
        final initial = engine.computeRoute('dest', TrafficProfile.interactive);
        expect(initial, isNotNull);
        engine.setActiveRoute(initial!);
        final snapshotCost = initial.cost;

        // The active direct link degrades severely...
        engine.recordLinkMeasurement(
          'dest',
          latencyMs: 5000,
          lossRate: 0.9,
          batteryDrain: 5.0,
          from: 'A',
        );
        // ...and a far better 2-hop relay via R becomes known.
        engine.recordLinkMeasurement(
          'R',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'A',
        );
        engine.recordLinkMeasurement(
          'dest',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'R',
        );

        final best = engine.computeRoute('dest', TrafficProfile.interactive);
        expect(best, isNotNull);
        // The premise: the relay is worse than the STALE snapshot (so a
        // snapshot-based comparison would refuse to migrate) but far
        // better than the active route's real current cost.
        expect(best!.cost, greaterThan(snapshotCost));

        MigrationDecision? last;
        for (var i = 0; i < RoutingEngine.kMigrationStabilityTicks; i++) {
          last = engine.considerMigration('dest', TrafficProfile.interactive);
        }

        expect(last, isA<MigrationDecisionMigrateTo>());
        expect((last! as MigrationDecisionMigrateTo).route.hops, ['R', 'dest']);
      },
    );

    test('test_EARS_ROUTE_2_migrates_only_after_stability_window', () {
      final engine = RoutingEngine(selfId: 'A');
      engine.setActiveRoute(
        const Route(destinationId: 'dest', hops: ['X', 'dest'], cost: 100.0),
      );
      // A genuinely >=20%-cheaper, stable candidate route the whole time.
      engine.recordLinkMeasurement(
        'Y',
        latencyMs: 1,
        lossRate: 0.0,
        batteryDrain: 0.0,
        from: 'A',
      );
      engine.recordLinkMeasurement(
        'dest',
        latencyMs: 1,
        lossRate: 0.0,
        batteryDrain: 0.0,
        from: 'Y',
      );

      for (var i = 1; i <= 9; i++) {
        final decision =
            engine.considerMigration('dest', TrafficProfile.interactive);
        expect(
          decision,
          const MigrationDecision.stay(),
          reason: 'sample $i must not trigger migration yet',
        );
      }

      final tenth =
          engine.considerMigration('dest', TrafficProfile.interactive);

      expect(tenth, isA<MigrationDecisionMigrateTo>());
      expect(
        (tenth as MigrationDecisionMigrateTo).route.hops,
        ['Y', 'dest'],
      );
    });

    test(
      'test_EARS_ROUTE_2_oscillating_candidate_never_triggers_migration',
      () {
        // Two candidates alternate being "the" improving route each
        // sample — the consecutive-sample counter must reset on every
        // switch, so migration never triggers even after many samples.
        final engine = RoutingEngine(selfId: 'A');
        engine.setActiveRoute(
          const Route(
            destinationId: 'dest',
            hops: ['X', 'dest'],
            cost: 100.0,
          ),
        );
        engine.recordLinkMeasurement(
          'Y',
          latencyMs: 1,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'A',
        );
        engine.recordLinkMeasurement(
          'Z',
          latencyMs: 1,
          lossRate: 0.0,
          batteryDrain: 0.0,
          from: 'A',
        );

        MigrationDecision? last;
        for (var i = 0; i < 20; i++) {
          // Alternate which of Y/Z is the cheaper next hop to `dest` each
          // sample, so the "best known alternative" flips every time.
          if (i.isEven) {
            engine.recordLinkMeasurement(
              'dest',
              latencyMs: 1,
              lossRate: 0.0,
              batteryDrain: 0.0,
              from: 'Y',
            );
            engine.removeLink('Z', 'dest');
          } else {
            engine.recordLinkMeasurement(
              'dest',
              latencyMs: 1,
              lossRate: 0.0,
              batteryDrain: 0.0,
              from: 'Z',
            );
            engine.removeLink('Y', 'dest');
          }
          last = engine.considerMigration('dest', TrafficProfile.interactive);
          expect(last, const MigrationDecision.stay());
        }
      },
    );
  });

  group('EARS-ROUTE-4 — onRouteFailure', () {
    test('test_EARS_ROUTE_4_returns_alternative_on_failure', () {
      final sim = NetworkSimulator(seed: 5);
      sim.setLink(
        'A',
        'B',
        const SimulatedLink(
          latencyMs: 20,
          packetLossRate: 0.0,
          batteryDrainPerMessage: 0.1,
        ),
      );
      sim.setLink(
        'A',
        'C',
        const SimulatedLink(
          latencyMs: 60,
          packetLossRate: 0.0,
          batteryDrainPerMessage: 0.2,
        ),
      );
      // Both B and C can reach `dest`.
      sim.setLink(
        'B',
        'dest',
        const SimulatedLink(
          latencyMs: 20,
          packetLossRate: 0.0,
          batteryDrainPerMessage: 0.1,
        ),
      );
      sim.setLink(
        'C',
        'dest',
        const SimulatedLink(
          latencyMs: 20,
          packetLossRate: 0.0,
          batteryDrainPerMessage: 0.1,
        ),
      );

      final engine = RoutingEngine(selfId: 'A');
      _recordFromSimulatedLink(engine, sim, 'A', 'B');
      _recordFromSimulatedLink(engine, sim, 'A', 'C');
      _recordFromSimulatedLink(engine, sim, 'B', 'dest');
      _recordFromSimulatedLink(engine, sim, 'C', 'dest');

      final initial = engine.computeRoute('dest', TrafficProfile.interactive);
      expect(initial, isNotNull);
      expect(initial!.hops.first, 'B'); // cheaper first hop

      engine.setActiveRoute(initial);

      // Simulate the active route's first hop failing (a `noRoute`
      // reported for A -> B) both in the simulator and the engine's view.
      sim.setLink('A', 'B', sim.linkBetween('A', 'B')!.copyWith(up: false));
      final result = sim.send('A', 'B', Uint8List.fromList([9]));
      expect(result, isA<SendResultNoRoute>());

      final alternative = engine.onRouteFailure('dest', TrafficProfile.interactive);

      expect(alternative, isNotNull);
      expect(alternative!.hops.first, 'C');
      expect(engine.activeRouteFor('dest'), alternative);
    });

    test('test_EARS_ROUTE_4_returns_null_when_no_alternative_exists', () {
      final engine = RoutingEngine(selfId: 'A');
      engine.recordLinkMeasurement(
        'B',
        latencyMs: 20,
        lossRate: 0.0,
        batteryDrain: 0.1,
        from: 'A',
      );
      engine.recordLinkMeasurement(
        'dest',
        latencyMs: 20,
        lossRate: 0.0,
        batteryDrain: 0.1,
        from: 'B',
      );

      final initial = engine.computeRoute('dest', TrafficProfile.interactive);
      expect(initial, isNotNull);
      engine.setActiveRoute(initial!);

      final alternative = engine.onRouteFailure('dest', TrafficProfile.interactive);

      expect(alternative, isNull);
      expect(engine.activeRouteFor('dest'), isNull);
    });
  });

  group('E04-B16 — identity aliases', () {
    RoutingEngine engineWithLinkTo(String selfId, String linkId) {
      final engine = RoutingEngine(selfId: selfId);
      engine.recordLinkMeasurement(
        linkId,
        latencyMs: 20,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );
      return engine;
    }

    test('test_E04_B16_identity_destination_routes_over_its_aliased_link', () {
      final engine = engineWithLinkTo('B', 'C-link');
      engine.recordIdentityAlias('C-link', 'C-identity');

      final route =
          engine.computeRoute('C-identity', TrafficProfile.interactive);

      expect(route, isNotNull);
      expect(route!.destinationId, 'C-identity');
      expect(route.hops, ['C-link']);
    });

    test('test_E04_B16_no_alias_means_no_route', () {
      final engine = engineWithLinkTo('B', 'C-link');
      expect(
        engine.computeRoute('C-identity', TrafficProfile.interactive),
        isNull,
      );
    });

    test('test_E04_B16_identity_claimed_by_two_links_is_ambiguous', () {
      final engine = engineWithLinkTo('B', 'C-link');
      engine.recordLinkMeasurement(
        'D-link',
        latencyMs: 20,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );
      engine.recordIdentityAlias('C-link', 'C-identity');
      engine.recordIdentityAlias('D-link', 'C-identity');

      expect(
        engine.computeRoute('C-identity', TrafficProfile.interactive),
        isNull,
      );
    });

    test('test_E04_B16_reannounce_replaces_and_forget_removes_the_alias', () {
      final engine = engineWithLinkTo('B', 'C-link');
      engine.recordIdentityAlias('C-link', 'old-identity');
      engine.recordIdentityAlias('C-link', 'new-identity');

      expect(
        engine.computeRoute('old-identity', TrafficProfile.interactive),
        isNull,
      );
      expect(
        engine.computeRoute('new-identity', TrafficProfile.interactive),
        isNotNull,
      );

      engine.forgetIdentityAlias('C-link');
      expect(
        engine.computeRoute('new-identity', TrafficProfile.interactive),
        isNull,
      );
    });

    test('test_E04_B16_route_failure_on_an_identity_destination_recovers',
        () {
      final engine = engineWithLinkTo('B', 'C-link');
      engine.recordIdentityAlias('C-link', 'C-identity');
      final route =
          engine.computeRoute('C-identity', TrafficProfile.interactive)!;
      engine.setActiveRoute(route);

      // The only link fails: no alternative, and no crash.
      expect(
        engine.onRouteFailure('C-identity', TrafficProfile.interactive),
        isNull,
      );
    });
  });
}
