// E04-B01 — regression tests for the RelayEngine/RoutingEngine seam defect:
// `RelayEngine._attempt` used to call `RoutingEngine.setActiveRoute()` on
// every forward attempt, purely as a side-channel so `onRouteFailure` blames
// the correct first-hop link. `setActiveRoute` also resets
// `RoutingEngine`'s migration-tracking state as a side effect (documented,
// correct behavior FOR A GENUINE ROUTE SWITCH) -- so relay traffic
// permanently suppressed EARS-ROUTE-2 / FR-ROUTE-006 make-before-break
// migration for any destination this device relays to.
//
// Must fail on `epic_04` commit cbc2efd (before the fix: relay_engine.dart
// calling `setActiveRoute` per attempt) and pass after (relay_engine.dart
// calling the new `RoutingEngine.noteAttemptedRoute` instead).
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/routing_engine/simulation/network_simulator.dart';
import 'package:nexora/core/routing_engine/simulation/simulated_link.dart';

/// Records `RelaySendFn` invocations without ever inspecting payload bytes
/// beyond identity, matching the pattern in `relay_engine_test.dart`.
class _SendCall {
  _SendCall(this.nextHopId, this.bytes);
  final String nextHopId;
  final Uint8List bytes;
}

RelaySendFn _recordingSend(
  NetworkSimulator sim,
  String selfId,
  List<_SendCall> calls,
) {
  return (nextHopId, bytes) async {
    calls.add(_SendCall(nextHopId, bytes));
    final result = sim.send(selfId, nextHopId, bytes);
    return result is SendResultDelivered;
  };
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('EARS-ROUTE-2 — relay traffic must not suppress migration', () {
    test(
      'test_EARS_ROUTE_2_relay_traffic_does_not_reset_migration_window',
      () async {
        // Step 3 no-relay control (task §Repro step 3): proves the baseline
        // documented behavior works, so a future regression that also
        // breaks the control cannot hide behind this test alone.
        final control = RoutingEngine(selfId: 'A');
        control.recordLinkMeasurement(
          'D',
          latencyMs: 1000,
          lossRate: 0.5,
          batteryDrain: 5.0,
        );
        control.recordLinkMeasurement(
          'B',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );
        control.recordLinkMeasurement(
          'D',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.1,
          from: 'B',
        );
        control.setActiveRoute(
          const Route(destinationId: 'D', hops: ['D'], cost: 999.0),
        );

        MigrationDecision? controlDecision;
        for (var i = 0; i < 10; i++) {
          controlDecision = control.considerMigration(
            'D',
            TrafficProfile.interactive,
          );
        }
        expect(
          controlDecision,
          isA<MigrationDecisionMigrateTo>(),
          reason: 'control: without relay traffic, the tenth '
              'considerMigration sample must return migrateTo',
        );

        // Step 4 (the defect): a fresh engine, same link setup, but with a
        // RelayEngine interleaving enqueue()/processQueue() between every
        // considerMigration() sample.
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'D',
          latencyMs: 1000,
          lossRate: 0.5,
          batteryDrain: 5.0,
        );
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );
        routingEngine.recordLinkMeasurement(
          'D',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.1,
          from: 'B',
        );
        routingEngine.setActiveRoute(
          const Route(destinationId: 'D', hops: ['D'], cost: 999.0),
        );

        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (hop, bytes) async => true,
        );

        MigrationDecision? decision;
        var migratedAtSample = -1;
        for (var i = 0; i < 60; i++) {
          decision = routingEngine.considerMigration(
            'D',
            TrafficProfile.interactive,
          );
          await relay.enqueue(
            'D',
            Uint8List.fromList([1, 2, 3]),
            0,
            const Duration(minutes: 5),
          );
          await relay.processQueue();

          if (decision is MigrationDecisionMigrateTo && migratedAtSample < 0) {
            migratedAtSample = i + 1;
          }
        }

        expect(
          migratedAtSample,
          greaterThan(0),
          reason: 'EARS-ROUTE-2/FR-ROUTE-006: interleaved relay activity is '
              'normal mesh operation and must not prevent migration from '
              'ever firing (defect: 60 samples with no migration)',
        );
        expect(
          migratedAtSample,
          lessThanOrEqualTo(10),
          reason: 'the candidate holds its advantage from the very first '
              'sample, so migration must fire within the documented bound '
              'of 10 consecutive samples, exactly as the no-relay control '
              'does',
        );
      },
    );
  });

  group('EARS-ROUTE-4 — relay send failure still blacklists first hop', () {
    test(
      'test_EARS_ROUTE_4_relay_send_failure_still_blacklists_first_hop',
      () async {
        // Pins the behavior the removed setActiveRoute call existed to
        // provide: onRouteFailure must still blame (and blacklist) the
        // correct first-hop link when a relay forward attempt fails, even
        // though relay_engine.dart no longer calls setActiveRoute.
        final sim = NetworkSimulator(seed: 31);
        sim.setLink(
          'A',
          'B',
          const SimulatedLink(
            latencyMs: 5,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
            up: false,
          ),
        );
        sim.setLink(
          'A',
          'C',
          const SimulatedLink(
            latencyMs: 20,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        sim.setLink(
          'C',
          'B',
          const SimulatedLink(
            latencyMs: 20,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );

        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );
        final linkAC = sim.linkBetween('A', 'C');
        final linkCB = sim.linkBetween('C', 'B');
        expect(linkAC, isNotNull);
        expect(linkCB, isNotNull);
        routingEngine.recordLinkMeasurement(
          'C',
          latencyMs: linkAC!.latencyMs,
          lossRate: linkAC.packetLossRate,
          batteryDrain: linkAC.batteryDrainPerMessage,
        );
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: linkCB!.latencyMs,
          lossRate: linkCB.packetLossRate,
          batteryDrain: linkCB.batteryDrainPerMessage,
          from: 'C',
        );

        // Sanity: the best-known route is still the (down) direct link,
        // since RoutingEngine only knows recorded cost factors, not the
        // simulator's own `up` flag.
        final initialRoute = routingEngine.computeRoute(
          'B',
          TrafficProfile.interactive,
        );
        expect(initialRoute!.hops, ['B']);

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
        );

        final id = await relay.enqueue(
          'B',
          Uint8List.fromList([4, 2]),
          0,
          const Duration(minutes: 5),
        );

        await relay.processQueue();

        expect(
          calls.map((c) => c.nextHopId).toList(),
          ['B', 'C'],
          reason: 'first attempt over the direct (dead) link, then a bounded '
              'retry over the alternative found via onRouteFailure -- this '
              'only happens if onRouteFailure correctly identifies B as the '
              'failed first hop to blacklist',
        );

        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(
          row.deliveryState,
          RelayDeliveryState.forwarding.name,
          reason: 'handed off successfully to an intermediate hop (C)',
        );

        // The direct A->B link must now be blacklisted in RoutingEngine's
        // own knowledge, proving onRouteFailure blamed the right link.
        expect(
          routingEngine.computeRoute('B', TrafficProfile.interactive)!.hops,
          ['C', 'B'],
        );
      },
    );

    test(
      'test_EARS_ROUTE_4_validated_switch_discards_stale_attempted_route',
      () {
        // Added by the E04-B01 review. `noteAttemptedRoute` introduced a
        // second source of truth for "which link just failed". If a
        // validated switch (setActiveRoute) does not discard an earlier
        // relay attempt record, onRouteFailure's
        // `_lastAttemptedRoute ?? _activeRoutes` preference blames the
        // STALE attempt's first hop instead of the route that actually
        // failed -- blacklisting a healthy link and leaving the dead one
        // in service. No production caller switches routes today, but
        // E05/E06 is exactly where one arrives (see E04-T04 §2).
        final engine = RoutingEngine(selfId: 'A');
        for (final hop in ['B', 'C']) {
          engine.recordLinkMeasurement(
            hop,
            latencyMs: 5,
            lossRate: 0.0,
            batteryDrain: 0.1,
          );
          engine.recordLinkMeasurement(
            'dest',
            latencyMs: 5,
            lossRate: 0.0,
            batteryDrain: 0.1,
            from: hop,
          );
        }

        // A relay packet was forwarded over the B path and did NOT fail,
        // so onRouteFailure never cleared the attempt record.
        engine.noteAttemptedRoute(
          const Route(destinationId: 'dest', hops: ['B', 'dest'], cost: 1.0),
        );

        // Later, a caller validates and switches to the C path.
        engine.setActiveRoute(
          const Route(destinationId: 'dest', hops: ['C', 'dest'], cost: 1.0),
        );

        // Now the ACTIVE (C) route fails.
        engine.onRouteFailure('dest', TrafficProfile.interactive);

        expect(
          engine.computeRoute('dest', TrafficProfile.interactive)!.hops.first,
          'B',
          reason: 'the failed A->C link must be the one blacklisted; the '
              'healthy A->B link (a stale attempt record) must not be',
        );
      },
    );
  });
}
