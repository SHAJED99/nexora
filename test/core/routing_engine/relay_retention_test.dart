// E04-B02 — regression tests for `RelayEngine.reclaimPayloads()`.
//
// The bug: `sweepExpired()` only ever touched `queued` rows. Nothing
// reclaimed a `relay_packets` row (or its `payload` BLOB) once it reached a
// terminal state (`forwarding` / `delivered` / `expired`) — a relay device
// accumulated other peers' ciphertext bytes indefinitely, contradicting
// `epic.md`'s own "local only, ephemeral" data-model claim.
//
// 🧍-resolved 2026-08-27: reclaim (null the `payload` BLOB), not delete —
// keep the row for E13 diagnostics. Retention window: reclaim as soon as a
// terminal-state row passes its own `expires_at`, no additional grace
// period beyond the packet's original TTL.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/routing_engine/simulation/network_simulator.dart';
import 'package:nexora/core/routing_engine/simulation/simulated_link.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('FR-ROUTE-004 — reclaimPayloads() retention', () {
    test(
      'test_FR_ROUTE_004_expired_forwarding_packet_payload_is_reclaimed',
      () async {
        // Exact §Repro from the task file: a 2-hop route (A->B->D) so the
        // forward lands in `forwarding` (not `delivered`), then the clock
        // is advanced 365 days past a 1-minute TTL.
        final sim = NetworkSimulator(seed: 101);
        sim.setLink(
          'A',
          'B',
          const SimulatedLink(
            latencyMs: 10,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        sim.setLink(
          'B',
          'D',
          const SimulatedLink(
            latencyMs: 10,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );

        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 10,
          lossRate: 0.0,
          batteryDrain: 0.1,
          from: 'A',
        );
        routingEngine.recordLinkMeasurement(
          'D',
          latencyMs: 10,
          lossRate: 0.0,
          batteryDrain: 0.1,
          from: 'B',
        );

        var fakeNow = DateTime(2026, 1, 1);
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (hop, bytes) async => true,
          clock: () => fakeNow,
        );

        final id = await relay.enqueue(
          'D',
          Uint8List.fromList([1, 2, 3]),
          0,
          const Duration(minutes: 1),
        );

        await relay.processQueue();
        var row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(
          row.deliveryState,
          RelayDeliveryState.forwarding.name,
          reason: 'setup sanity: a 2-hop route must land in forwarding, not '
              'delivered',
        );
        expect(row.payload, orderedEquals([1, 2, 3]));

        // Advance far past the 1-minute TTL.
        fakeNow = fakeNow.add(const Duration(days: 365));

        final reclaimed = await relay.reclaimPayloads();
        expect(reclaimed, 1);

        row = await (db.select(db.relayPackets)..where((t) => t.id.equals(id)))
            .getSingle();
        expect(
          row.payload,
          isNull,
          reason: 'a year-old expired forwarding-state packet must no '
              'longer hold its payload after a reclaim pass',
        );
        // The row itself — including its state — survives, for diagnostics.
        expect(row.deliveryState, RelayDeliveryState.forwarding.name);
        expect(row.destinationId, 'D');
        expect(row.sizeBytes, 3);
      },
    );

    test(
      'test_FR_ROUTE_004_delivered_packet_payload_is_reclaimed',
      () async {
        // Direct 1-hop route -> lands in `delivered`.
        final sim = NetworkSimulator(seed: 103);
        sim.setLink(
          'A',
          'B',
          const SimulatedLink(
            latencyMs: 10,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 10,
          lossRate: 0.0,
          batteryDrain: 0.1,
          from: 'A',
        );

        var fakeNow = DateTime(2026, 1, 1);
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (hop, bytes) async => true,
          clock: () => fakeNow,
        );

        final id = await relay.enqueue(
          'B',
          Uint8List.fromList([9, 9]),
          0,
          const Duration(minutes: 1),
        );

        await relay.processQueue();
        var row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.delivered.name);
        expect(row.payload, isNotNull);

        fakeNow = fakeNow.add(const Duration(days: 1));

        final reclaimed = await relay.reclaimPayloads();
        expect(reclaimed, 1);

        row = await (db.select(db.relayPackets)..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.payload, isNull);
        expect(row.deliveryState, RelayDeliveryState.delivered.name);
      },
    );

    test(
      'test_FR_ROUTE_004_live_queued_packet_payload_is_untouched',
      () async {
        // Critical negative case: an unexpired `queued` packet (never
        // forwarded — no route exists) must NOT have its payload touched,
        // or the fix would eat in-flight traffic.
        final routingEngine = RoutingEngine(selfId: 'A');

        final fakeNow = DateTime(2026, 1, 1);
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (hop, bytes) async => true,
          clock: () => fakeNow,
        );

        final id = await relay.enqueue(
          'UNREACHABLE',
          Uint8List.fromList([5, 5, 5]),
          0,
          const Duration(minutes: 10),
        );

        // Never processed / never expired — still well within its TTL.
        final reclaimed = await relay.reclaimPayloads();
        expect(
          reclaimed,
          0,
          reason: 'a live, unexpired queued packet must never be reclaimed',
        );

        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);
        expect(
          row.payload,
          orderedEquals([5, 5, 5]),
          reason: 'in-flight queued traffic must keep its payload intact',
        );
      },
    );

    test(
      'test_FR_ROUTE_004_expired_queued_packet_payload_is_untouched_by_'
      'reclaim',
      () async {
        // Even a `queued` row that is itself past its `expires_at` (but not
        // yet swept to `expired` by sweepExpired()) must not be touched by
        // reclaimPayloads() — it is deliberately scoped to terminal states
        // only, per the task's root-cause analysis.
        final routingEngine = RoutingEngine(selfId: 'A');

        var fakeNow = DateTime(2026, 1, 1);
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (hop, bytes) async => true,
          clock: () => fakeNow,
        );

        final id = await relay.enqueue(
          'UNREACHABLE',
          Uint8List.fromList([7]),
          0,
          const Duration(seconds: 1),
        );
        fakeNow = fakeNow.add(const Duration(minutes: 5));

        final reclaimed = await relay.reclaimPayloads();
        expect(reclaimed, 0);

        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);
        expect(row.payload, orderedEquals([7]));
      },
    );

    // Added by the reviewer (E04-B02 re-verification, 2026-08-27). The
    // builder's three named tests cover `forwarding` and `delivered` but
    // never exercise the third terminal state the contract names,
    // `expired` — and that state is the one reached via a SECOND method
    // (`sweepExpired()`), so it also pins the sweep -> reclaim ordering
    // contract that the two methods split between them.
    test(
      'test_FR_ROUTE_004_sweepExpired_then_reclaim_reclaims_expired_payload',
      () async {
        final routingEngine = RoutingEngine(selfId: 'A');
        var fakeNow = DateTime(2026, 1, 1);
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (hop, bytes) async => true,
          clock: () => fakeNow,
        );

        final id = await relay.enqueue(
          'UNREACHABLE',
          Uint8List.fromList([4, 2]),
          0,
          const Duration(seconds: 1),
        );
        fakeNow = fakeNow.add(const Duration(minutes: 5));

        // Reclaim-before-sweep is a no-op: the row is still nominally
        // `queued`, so its payload is deliberately out of reclaim's scope.
        expect(
          await relay.reclaimPayloads(),
          0,
          reason: 'reclaim must not front-run sweepExpired() on a queued row',
        );

        // sweepExpired() transitions it to the terminal `expired` state...
        expect(await relay.sweepExpired(), 1);
        // ...and only then is the payload reclaimable — no grace period
        // beyond the packet's own (already elapsed) TTL.
        expect(await relay.reclaimPayloads(), 1);

        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.payload, isNull);
        expect(
          row.deliveryState,
          RelayDeliveryState.expired.name,
          reason: 'the diagnostic row (state/destination/size) survives',
        );
        expect(row.destinationId, 'UNREACHABLE');
        expect(row.sizeBytes, 2);

        // Idempotent: a second pass finds nothing left to reclaim (the
        // `payload.isNotNull()` guard), so a scheduler calling this on a
        // timer never re-writes rows it already cleaned.
        expect(await relay.reclaimPayloads(), 0);
      },
    );
  });
}
