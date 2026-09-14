// E04-T04 — RelayEngine tests (FR-ROUTE-003/004), tested against T01's
// NetworkSimulator + T02's RoutingEngine together per this task's §6 risk
// note: real Bluetooth isn't needed to prove queue/priority/expiry/retry
// logic, and using it would make these tests as unrunnable-without-hardware
// as T03b/c's.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/routing_engine/simulation/network_simulator.dart';
import 'package:nexora/core/routing_engine/simulation/simulated_link.dart';
import 'package:nexora/features/trust/domain/relationship.dart'
    show RelationshipState;

/// One record of a captured `RelaySendFn` invocation, for tests asserting
/// call order and exact bytes without RelayEngine (or this helper) ever
/// interpreting the payload's contents.
class _SendCall {
  _SendCall(this.nextHopId, this.bytes);
  final String nextHopId;
  final Uint8List bytes;
}

/// Wraps `NetworkSimulator.send(selfId, ...)` as a `RelaySendFn`, recording
/// every call (hop id + the exact bytes handed to it, untouched) into
/// [calls] for assertions.
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

/// Feeds one directed simulated link's measured factors into [engine],
/// matching `routing_engine_test.dart`'s own helper.
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
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('EARS-ROUTE-3 — payload never inspected/parsed', () {
    test('test_EARS_ROUTE_3_payload_passes_through_unparsed', () async {
      // Deliberately not a valid "encrypted message" shape of any kind —
      // just garbage bytes, including invalid UTF-8 and structurally
      // meaningless content, so a passing test cannot be explained by the
      // engine happening to tolerate a well-formed envelope.
      final garbage = Uint8List.fromList(
        List<int>.generate(64, (i) => (i * 137 + 91) % 256),
      );

      final sim = NetworkSimulator(seed: 7);
      sim.setLink(
        'A',
        'B',
        const SimulatedLink(
          latencyMs: 20,
          packetLossRate: 0.0,
          batteryDrainPerMessage: 0.1,
        ),
      );
      final routingEngine = RoutingEngine(selfId: 'A');
      _recordFromSimulatedLink(routingEngine, sim, 'A', 'B');

      final calls = <_SendCall>[];
      final relay = RelayEngine(
        selfId: 'A',
        db: db,
        routingEngine: routingEngine,
        send: _recordingSend(sim, 'A', calls),
      );

      await relay.enqueue('B', garbage, 0, const Duration(minutes: 5));
      await relay.processQueue();

      expect(calls, hasLength(1));
      expect(calls.single.nextHopId, 'B');
      // Byte-identical, not merely equal-length or re-encoded.
      expect(calls.single.bytes, orderedEquals(garbage));

      final rows = await db.select(db.relayPackets).get();
      expect(rows.single.deliveryState, RelayDeliveryState.delivered.name);
      // The stored row itself is the same opaque bytes too — never
      // transformed on the way into or out of persistence.
      expect(rows.single.payload, orderedEquals(garbage));
    });
  });

  group('EARS-ROUTE-4b — unreachable/expired packets', () {
    test(
      'test_EARS_ROUTE_4b_unreachable_packet_stays_queued_until_ttl',
      () async {
        // No link to 'Z' is ever recorded -> computeRoute returns null ->
        // the packet must stay queued, not be dropped.
        final sim = NetworkSimulator(seed: 3);
        final routingEngine = RoutingEngine(selfId: 'A');

        var fakeNow = DateTime(2026, 1, 1);
        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
          clock: () => fakeNow,
        );

        final id = await relay.enqueue(
          'Z',
          Uint8List.fromList([1, 2, 3]),
          0,
          const Duration(minutes: 10),
        );

        await relay.processQueue();
        expect(calls, isEmpty, reason: 'no known route -> never attempted');
        var row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);

        // Time passes, but not past the TTL yet, and still no route.
        fakeNow = fakeNow.add(const Duration(minutes: 5));
        await relay.processQueue();
        row = await (db.select(db.relayPackets)..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);
        expect(calls, isEmpty);

        // A sweep before the TTL elapses must not touch it.
        final sweptEarly = await relay.sweepExpired();
        expect(sweptEarly, 0);
        row = await (db.select(db.relayPackets)..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);
      },
    );

    test(
      'test_EARS_ROUTE_4b_expired_packet_marked_expired_not_forwarded',
      () async {
        // A real, working route exists -- if the packet weren't expired,
        // processQueue() would forward it successfully. This proves
        // expiry is honored even when forwarding is otherwise possible.
        final sim = NetworkSimulator(seed: 5);
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
        _recordFromSimulatedLink(routingEngine, sim, 'A', 'B');

        var fakeNow = DateTime(2026, 1, 1);
        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
          clock: () => fakeNow,
        );

        final id = await relay.enqueue(
          'B',
          Uint8List.fromList([9, 9, 9]),
          0,
          const Duration(seconds: 1),
        );

        // Advance well past expiry before the packet is ever processed.
        fakeNow = fakeNow.add(const Duration(seconds: 2));

        await relay.processQueue();
        expect(
          calls,
          isEmpty,
          reason: 'expired packets must never be forwarded even with a '
              'valid route',
        );

        var row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(
          row.deliveryState,
          RelayDeliveryState.queued.name,
          reason: 'processQueue() only skips expired packets; sweepExpired() '
              'is the sole writer of the expired state',
        );

        final swept = await relay.sweepExpired();
        expect(swept, 1);
        row = await (db.select(db.relayPackets)..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.expired.name);
      },
    );
  });

  group('priority + age ordering', () {
    test(
      'test_priority_order_higher_priority_forwarded_first',
      () async {
        final sim = NetworkSimulator(seed: 11);
        sim.setLink(
          'A',
          'LOW_DEST',
          const SimulatedLink(
            latencyMs: 10,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        sim.setLink(
          'A',
          'HIGH_DEST',
          const SimulatedLink(
            latencyMs: 10,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        final routingEngine = RoutingEngine(selfId: 'A');
        _recordFromSimulatedLink(routingEngine, sim, 'A', 'LOW_DEST');
        _recordFromSimulatedLink(routingEngine, sim, 'A', 'HIGH_DEST');

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
        );

        // Low-priority packet enqueued FIRST (older), high-priority second
        // (newer) -- priority must win over age.
        await relay.enqueue(
          'LOW_DEST',
          Uint8List.fromList([1]),
          0,
          const Duration(minutes: 5),
        );
        await relay.enqueue(
          'HIGH_DEST',
          Uint8List.fromList([2]),
          10,
          const Duration(minutes: 5),
        );

        await relay.processQueue();

        expect(calls, hasLength(2));
        expect(
          calls[0].nextHopId,
          'HIGH_DEST',
          reason: 'higher priority must be attempted before the older, '
              'lower-priority packet',
        );
        expect(calls[1].nextHopId, 'LOW_DEST');
      },
    );

    test(
      'test_priority_order_same_priority_falls_back_to_oldest_first',
      () async {
        final sim = NetworkSimulator(seed: 13);
        sim.setLink(
          'A',
          'FIRST_DEST',
          const SimulatedLink(
            latencyMs: 10,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        sim.setLink(
          'A',
          'SECOND_DEST',
          const SimulatedLink(
            latencyMs: 10,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        final routingEngine = RoutingEngine(selfId: 'A');
        _recordFromSimulatedLink(routingEngine, sim, 'A', 'FIRST_DEST');
        _recordFromSimulatedLink(routingEngine, sim, 'A', 'SECOND_DEST');

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
        );

        await relay.enqueue(
          'FIRST_DEST',
          Uint8List.fromList([1]),
          5,
          const Duration(minutes: 5),
        );
        await relay.enqueue(
          'SECOND_DEST',
          Uint8List.fromList([2]),
          5,
          const Duration(minutes: 5),
        );

        await relay.processQueue();

        expect(calls, hasLength(2));
        expect(calls[0].nextHopId, 'FIRST_DEST');
        expect(calls[1].nextHopId, 'SECOND_DEST');
      },
    );
  });

  group('route-failure retry', () {
    test(
      'test_route_failure_triggers_alternative_via_routing_engine',
      () async {
        // The direct A->B link is DOWN in the simulator (any real send over
        // it deterministically returns `noRoute`), but RoutingEngine's own
        // knowledge of it (recorded separately, as real link-state gossip
        // would arrive) is of a cheap, healthy link -- `up` is a simulator
        // transmission property, not one of the recorded cost factors, so
        // this is a legitimate "the route looked fine, the send itself
        // failed" scenario, not a contrived cost mismatch. A relay path
        // A->C->B is real and healthy. On the direct send's failure,
        // RoutingEngine.onRouteFailure must blacklist the dead A->B link
        // and hand back the A->C->B alternative within the SAME
        // processQueue() pass.
        final sim = NetworkSimulator(seed: 17);
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
        // Recorded as a cheap, healthy link (real values are latencyMs: 5,
        // packetLossRate: 0.0 -- the same regardless of `up`, since `up`
        // is not part of what recordLinkMeasurement captures).
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );
        _recordFromSimulatedLink(routingEngine, sim, 'A', 'C');
        _recordFromSimulatedLink(routingEngine, sim, 'C', 'B');

        // Sanity: the engine's best-known route is still the (down) direct
        // link, since RoutingEngine only knows the recorded cost factors,
        // not the simulator's own `up` flag.
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
              'retry over the alternative found via onRouteFailure',
        );

        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(
          row.deliveryState,
          RelayDeliveryState.forwarding.name,
          reason: 'handed off successfully to an intermediate hop (C), not '
              'the destination itself',
        );

        // The engine's own state now reflects the failure recovery too.
        expect(
          routingEngine.computeRoute('B', TrafficProfile.interactive)!.hops,
          ['C', 'B'],
        );
      },
    );

    test(
      'test_route_failure_with_no_alternative_stays_queued',
      () async {
        // Only ever one path (direct), and it always fails (down in the
        // simulator) -- there is no alternative for onRouteFailure to hand
        // back.
        final sim = NetworkSimulator(seed: 19);
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
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 5,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
        );

        final id = await relay.enqueue(
          'B',
          Uint8List.fromList([1]),
          0,
          const Duration(minutes: 5),
        );

        await relay.processQueue();

        expect(calls, hasLength(1), reason: 'no alternative -> no retry');
        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);
      },
    );
  });

  test(
    'enqueue returns a usable id and the row is queued immediately',
    () async {
      final sim = NetworkSimulator(seed: 23);
      final routingEngine = RoutingEngine(selfId: 'A');
      final relay = RelayEngine(
        selfId: 'A',
        db: db,
        routingEngine: routingEngine,
        send: _recordingSend(sim, 'A', <_SendCall>[]),
      );

      final id = await relay.enqueue(
        'B',
        Uint8List.fromList([1, 2, 3]),
        3,
        const Duration(minutes: 1),
      );

      expect(id, isNotEmpty);
      final row =
          await (db.select(db.relayPackets)..where((t) => t.id.equals(id)))
              .getSingle();
      expect(row.destinationId, 'B');
      expect(row.priority, 3);
      expect(row.sizeBytes, 3);
      expect(row.deliveryState, RelayDeliveryState.queued.name);
    },
  );

  group('E04-B23 — route bootstrap for an already-known contact', () {
    test(
      'test_E04_B23_known_contact_with_no_route_gets_a_direct_send_attempt',
      () async {
        // No link to 'B' is ever recorded (mirrors the unreachable-packet
        // test above) -- but 'B' IS a trusted relationship, unlike that
        // test's stranger 'Z'. This is the exact real-world shape the live
        // two-device session found: a real, already-bonded contact whose
        // link measurement this process has never recorded (e.g. after an
        // app restart, or the only prior connection having dropped) could
        // never have a message leave the device at all -- not even a
        // failed native connect was ever attempted, since `_attempt`
        // returned before `_send` was ever reached.
        await db.into(db.relationships).insert(
              RelationshipsCompanion.insert(
                deviceId: 'B',
                state: 'trusted',
                updatedAt: DateTime(2026, 1, 1),
              ),
            );

        final sim = NetworkSimulator(seed: 11);
        sim.setLink(
          'A',
          'B',
          const SimulatedLink(
            latencyMs: 15,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        final routingEngine = RoutingEngine(selfId: 'A');
        // Deliberately NOT calling recordLinkMeasurement -- computeRoute
        // must return null here, exactly the case this fix handles.

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
        );

        final id = await relay.enqueue(
          'B',
          Uint8List.fromList([9, 9, 9]),
          0,
          const Duration(minutes: 10),
        );

        await relay.processQueue();

        expect(
          calls,
          hasLength(1),
          reason:
              'a known (trusted/allowed) contact must get a direct send '
              'attempt even with no measured route',
        );
        expect(calls.single.nextHopId, 'B');
        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.delivered.name);
      },
    );

    test(
      'test_E04_B23_unknown_stranger_with_no_route_still_gets_no_attempt',
      () async {
        // No relationship row at all for 'Z' -- the no-eager-connect
        // behaviour E04-B07 established must stay exactly as it was for
        // anyone this device has no relationship with at all. This is the
        // negative-space companion to the test above: same "no route"
        // starting condition, different (absent) relationship, different
        // outcome.
        final sim = NetworkSimulator(seed: 13);
        final routingEngine = RoutingEngine(selfId: 'A');

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
        );

        final id = await relay.enqueue(
          'Z',
          Uint8List.fromList([1]),
          0,
          const Duration(minutes: 10),
        );

        await relay.processQueue();

        expect(calls, isEmpty, reason: 'no relationship at all -> no attempt');
        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);
      },
    );

    test(
      'test_E04_B23_blocked_relationship_with_no_route_still_gets_no_attempt',
      () async {
        // Review round-1 finding N2: the DoD claims absent/unknown/blocked
        // relationships are all unaffected, but only the absent case
        // ('Z' above) was actually pinned by a test. `blocked` is the
        // security-sensitive one -- a relationship this device has
        // actively revoked trust from must never get an eager-connect
        // attempt just because no route happens to exist.
        await db.into(db.relationships).insert(
              RelationshipsCompanion.insert(
                deviceId: 'B',
                state: 'blocked',
                updatedAt: DateTime(2026, 1, 1),
              ),
            );

        final sim = NetworkSimulator(seed: 19);
        final routingEngine = RoutingEngine(selfId: 'A');

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
        );

        final id = await relay.enqueue(
          'B',
          Uint8List.fromList([1]),
          0,
          const Duration(minutes: 10),
        );

        await relay.processQueue();

        expect(calls, isEmpty, reason: 'blocked -> no attempt, ever');
        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);
      },
    );

    test(
      'test_E04_B23_relationship_state_string_literals_match_the_enum',
      () {
        // Review round-1 finding N3: relay_engine.dart deliberately
        // compares against the raw strings 'trusted'/'allowed' rather
        // than importing RelationshipState (to keep this file's own
        // narrow dependency surface -- see its own doc comment). This
        // pins that string choice against the actual enum encoding
        // `RelationshipRepository.upsert` writes, so a future rename of
        // the enum's values shows up here instead of silently breaking
        // the raw-string comparison.
        expect(RelationshipState.trusted.name, 'trusted');
        expect(RelationshipState.allowed.name, 'allowed');
      },
    );

    test(
      'test_E04_B23_known_contact_direct_attempt_fails_stays_queued',
      () async {
        // 'B' is trusted, but no link is set up in the simulator at all --
        // NetworkSimulator.send must report failure (no path), and the
        // packet must stay queued exactly like any other failed hop
        // (§3/§6), not transition to a new failure state.
        await db.into(db.relationships).insert(
              RelationshipsCompanion.insert(
                deviceId: 'B',
                state: 'allowed',
                updatedAt: DateTime(2026, 1, 1),
              ),
            );

        final sim = NetworkSimulator(seed: 17);
        final routingEngine = RoutingEngine(selfId: 'A');

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'A', calls),
        );

        final id = await relay.enqueue(
          'B',
          Uint8List.fromList([1]),
          0,
          const Duration(minutes: 10),
        );

        await relay.processQueue();

        expect(calls, hasLength(1));
        final row = await (db.select(db.relayPackets)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.deliveryState, RelayDeliveryState.queued.name);
      },
    );
  });

  group('E04-B16 — multi-hop relay of an identity-addressed packet', () {
    test(
      'test_E04_B16_intermediate_relay_forwards_to_the_aliased_next_hop',
      () async {
        // A -> B -> C. B is the intermediate relay: it holds a packet A
        // addressed to C's announced identity (E04-B12/B13/B15 addressing),
        // while B's own routing graph only knows transport link ids.
        final sim = NetworkSimulator(seed: 16);
        sim.setLink(
          'B',
          'C-link',
          const SimulatedLink(
            latencyMs: 15,
            packetLossRate: 0.0,
            batteryDrainPerMessage: 0.1,
          ),
        );
        final routingEngine = RoutingEngine(selfId: 'B');
        _recordFromSimulatedLink(routingEngine, sim, 'B', 'C-link');
        routingEngine.recordIdentityAlias('C-link', 'C-identity');

        final calls = <_SendCall>[];
        final relay = RelayEngine(
          selfId: 'B',
          db: db,
          routingEngine: routingEngine,
          send: _recordingSend(sim, 'B', calls),
        );

        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        await relay.enqueue('C-identity', bytes, 0, const Duration(minutes: 5));
        await relay.processQueue();

        expect(calls, hasLength(1));
        expect(calls.single.nextHopId, 'C-link');
        expect(calls.single.bytes, orderedEquals(bytes));
        final rows = await db.select(db.relayPackets).get();
        expect(rows.single.deliveryState, RelayDeliveryState.delivered.name);
      },
    );
  });
}
