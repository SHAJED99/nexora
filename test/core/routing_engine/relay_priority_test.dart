// E07-T10 — RelayPriority + RelayEngine.processQueue ordering/starvation
// tests (FR-CALL-002). Two things are proven here, per the task file:
//   1. `processQueue()` drains `(priority DESC, created_at ASC)` -- this
//      ordering already existed in `relay_engine.dart` before this task
//      (its query already had `OrderingTerm.desc(priority)` /
//      `.asc(createdAt)`), so `test_EARS_CALL_6_...` below is a
//      characterization test proving that pre-existing behaviour, not a
//      red-then-green fix (task file §6's own "check before you build").
//   2. The NEW starvation guard: a bounded `maxPacketsPerCycle` must not
//      let a continuous realtime stream starve a lower-priority backlog
//      forever (`_applyStarvationGuard`, new in this task).
//   3. `CallSignaling` (E07-T09) marks its outgoing frames at
//      `RelayPriority.realtime` when the frame goes through the shared
//      relay queue (this device is not the peer's direct neighbor).
//
// Test 1/2 use a bare `RoutingEngine` + a recording fake `RelaySendFn` --
// same minimal-harness style as `relay_engine_test.dart`'s own tests, no
// `NetworkSimulator` needed since these tests don't care about simulated
// link randomness, only about queue ordering.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/calls/call_session.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('EARS-CALL-6 — priority-ordered drain', () {
    test(
      'test_EARS_CALL_6_realtime_packets_drain_before_older_bulk_packets',
      () async {
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );

        final attemptOrder = <String>[];
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (nextHopId, bytes) async {
            attemptOrder.add(utf8.decode(bytes));
            return true;
          },
        );

        // Enqueued FIRST (older `created_at`) but at the bulk band.
        await relay.enqueue(
          'B',
          _bytes('bulk-old'),
          RelayPriority.bulk,
          const Duration(minutes: 5),
        );
        // Enqueued SECOND (newer `created_at`) but at the realtime band.
        await relay.enqueue(
          'B',
          _bytes('realtime-new'),
          RelayPriority.realtime,
          const Duration(minutes: 5),
        );

        await relay.processQueue();

        expect(
          attemptOrder,
          ['realtime-new', 'bulk-old'],
          reason: 'higher priority must be attempted first even though it '
              'was enqueued later -- (priority DESC, created_at ASC)',
        );
      },
    );

    test(
      'test_EARS_CALL_6_call_signaling_is_enqueued_at_the_realtime_band',
      () async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const suffix = 'relay-priority-call-signaling';
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
          (ByteData? message) async =>
              TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]),
        );

        final db2 = AppDatabase.forTesting(NativeDatabase.memory());
        final store = DriftSignalProtocolStore(db2);
        final stack = await MessagingStack.create(
          db: db2,
          selfDeviceId: 'device-a',
          store: store,
          cryptoService: CryptoService.withStore(store),
          transport: TransportService(
            binaryMessenger: messenger,
            messageChannelSuffix: suffix,
          ),
        );
        addTearDown(stack.dispose);

        // A structurally valid session so `invite()` gets past its own
        // `containsSession` guard -- mirrors `call_signaling_test.dart`'s
        // own "real second stack purely as a PreKeyBundle source" pattern.
        final peerDb = AppDatabase.forTesting(NativeDatabase.memory());
        final peerStore = DriftSignalProtocolStore(peerDb);
        final peerStack = await MessagingStack.create(
          db: peerDb,
          selfDeviceId: 'device-b',
          store: peerStore,
          cryptoService: CryptoService.withStore(peerStore),
          transport: TransportService(
            binaryMessenger: messenger,
            messageChannelSuffix: 'relay-priority-peer',
          ),
        );
        addTearDown(peerStack.dispose);
        await stack.cryptoService.establishSession(
          SignalProtocolAddress('device-b', 1),
          await peerStack.identityService.getLocalPreKeyBundle(),
        );

        // `device-b` is NOT this device's direct neighbor -- only reachable
        // via `device-relay` -- so `CallSignaling._sendFrame`'s route
        // computation returns a >1-hop route and takes the
        // `relayEngine.enqueue` branch (see call_signaling.dart's own
        // header for why the direct-neighbor case can never exercise this
        // branch: `computeRoute` needs graph knowledge this device only has
        // for a peer reachable through an intermediate hop).
        stack.routingEngine.recordLinkMeasurement(
          'device-relay',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );
        stack.routingEngine.recordLinkMeasurement(
          'device-b',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
          from: 'device-relay',
        );

        await stack.callSignaling.invite('device-b');

        final rows = await db2.select(db2.relayPackets).get();
        expect(
          rows,
          isNotEmpty,
          reason: 'a multi-hop call-signaling frame must be enqueued via '
              'the shared relay queue, not sent only directly',
        );
        expect(
          rows.every((r) => r.priority == RelayPriority.realtime),
          isTrue,
          reason: 'every call-signaling packet the relay queue holds must '
              'be enqueued at RelayPriority.realtime (FR-CALL-002)',
        );

        await db2.close();
        await peerDb.close();
      },
    );
  });

  group('multi-hop send-failure gating (review F4)', () {
    test(
      'test_call_signaling_multihop_send_failure_actually_throws_call_unreachable',
      () async {
        // Review finding F4 (round 1, contained half): `delivered` used to
        // be set `true` unconditionally right after `relayEngine.enqueue`,
        // so `call.unreachable` could never fire for a multi-hop peer even
        // when the underlying send provably failed. Mirrors
        // `test_EARS_CALL_6_call_signaling_is_enqueued_at_the_realtime_band`'s
        // multi-hop setup exactly, except every transport send is made to
        // fail -- so `RelayEngine._attempt`'s bounded retries are both
        // exhausted, the row is left `queued`, and `invite()` must end the
        // session with `CallEndReason.unreachable` instead of reporting
        // success.
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const suffix = 'relay-priority-call-signaling-failure';
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
          (ByteData? message) async =>
              TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[false]),
        );

        final db2 = AppDatabase.forTesting(NativeDatabase.memory());
        final store = DriftSignalProtocolStore(db2);
        final stack = await MessagingStack.create(
          db: db2,
          selfDeviceId: 'device-a',
          store: store,
          cryptoService: CryptoService.withStore(store),
          transport: TransportService(
            binaryMessenger: messenger,
            messageChannelSuffix: suffix,
          ),
        );
        addTearDown(stack.dispose);

        final peerDb = AppDatabase.forTesting(NativeDatabase.memory());
        final peerStore = DriftSignalProtocolStore(peerDb);
        final peerStack = await MessagingStack.create(
          db: peerDb,
          selfDeviceId: 'device-b',
          store: peerStore,
          cryptoService: CryptoService.withStore(peerStore),
          transport: TransportService(
            binaryMessenger: messenger,
            messageChannelSuffix: 'relay-priority-peer-failure',
          ),
        );
        addTearDown(peerStack.dispose);
        await stack.cryptoService.establishSession(
          SignalProtocolAddress('device-b', 1),
          await peerStack.identityService.getLocalPreKeyBundle(),
        );

        stack.routingEngine.recordLinkMeasurement(
          'device-relay',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );
        stack.routingEngine.recordLinkMeasurement(
          'device-b',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
          from: 'device-relay',
        );

        final session = await stack.callSignaling.invite('device-b');

        expect(
          session.endReason,
          CallEndReason.unreachable,
          reason: 'a multi-hop send that provably failed (both bounded '
              'retries exhausted) must surface as call.unreachable, not be '
              'reported as delivered',
        );

        final rows = await db2.select(db2.relayPackets).get();
        expect(rows, isNotEmpty);
        expect(
          rows.every((r) => r.deliveryState == RelayDeliveryState.queued.name),
          isTrue,
          reason: 'the packet never actually left this device -- it must '
              'still be sitting queued, not marked delivered/forwarding',
        );

        await db2.close();
        await peerDb.close();
      },
    );
  });

  group('direct-send path coverage (review F6)', () {
    test(
      'test_direct_send_call_signaling_is_not_blocked_by_a_bulk_backlog',
      () async {
        // Review finding F6 (round 1): the shipped tests only proved the
        // QUEUED multi-hop dispatch path -- the DIRECT-send path (this
        // file's own header concedes it is "what actually runs" in every
        // pre-existing scenario) had zero test proving it actually outranks
        // a sync backlog. This seeds a bulk backlog for a different
        // destination, then invites a peer with no recorded route
        // (`computeRoute` returns null -> `_sendFrame` takes the direct
        // `transport.send` branch, never touching the relay queue at all),
        // and asserts the transport observed the invite while the backlog
        // rows are still sitting `queued`.
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const suffix = 'relay-priority-direct-send';
        var sendCalls = 0;
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
          (ByteData? message) async {
            sendCalls++;
            return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
          },
        );
        // E04-B05: `CallSignaling._sendFrame`'s direct-neighbor branch now
        // goes through `_stack.directSend` (connect-then-send) -- mock
        // `[suffix]`'s own `TransportApi.connect` to accept and settle
        // immediately, mirroring `TransportService.connect`'s real
        // two-channel contract.
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.connect.$suffix',
          (ByteData? message) async {
            final args = TransportApi.pigeonChannelCodec.decodeMessage(message)!
                as List<Object?>;
            final deviceId = args[0]! as String;
            scheduleMicrotask(() {
              messenger.handlePlatformMessage(
                'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
                TransportEventsApi.pigeonChannelCodec.encodeMessage(
                  <Object?>[deviceId, ConnectionState.connected],
                )!,
                (ByteData? _) {},
              );
            });
            return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
          },
        );

        final db2 = AppDatabase.forTesting(NativeDatabase.memory());
        final store = DriftSignalProtocolStore(db2);
        final stack = await MessagingStack.create(
          db: db2,
          selfDeviceId: 'device-a',
          store: store,
          cryptoService: CryptoService.withStore(store),
          transport: TransportService(
            binaryMessenger: messenger,
            messageChannelSuffix: suffix,
          ),
        );
        addTearDown(stack.dispose);

        final peerDb = AppDatabase.forTesting(NativeDatabase.memory());
        final peerStore = DriftSignalProtocolStore(peerDb);
        final peerStack = await MessagingStack.create(
          db: peerDb,
          selfDeviceId: 'device-b',
          store: peerStore,
          cryptoService: CryptoService.withStore(peerStore),
          transport: TransportService(
            binaryMessenger: messenger,
            messageChannelSuffix: 'relay-priority-direct-peer',
          ),
        );
        addTearDown(peerStack.dispose);
        await stack.cryptoService.establishSession(
          SignalProtocolAddress('device-b', 1),
          await peerStack.identityService.getLocalPreKeyBundle(),
        );

        // Seed a bulk backlog for a DIFFERENT destination -- purely to prove
        // the direct-send path never waits on, or is blocked by, whatever
        // else is sitting in the shared relay queue. `device-b` gets no
        // `recordLinkMeasurement` at all, so `computeRoute` returns `null`
        // and `_sendFrame` takes the direct `transport.send` branch.
        const bulkCount = 50;
        for (var i = 0; i < bulkCount; i++) {
          await stack.relayEngine.enqueue(
            'someone-else',
            _bytes('bulk-$i'),
            RelayPriority.bulk,
            const Duration(hours: 1),
          );
        }

        await stack.callSignaling.invite('device-b');

        expect(
          sendCalls,
          1,
          reason: 'the direct-send path must reach the transport for the '
              'invite -- it must not be routed through the relay queue at '
              'all when the peer has no recorded multi-hop route',
        );
        final backlogRows = await (db2.select(db2.relayPackets)
              ..where((t) => t.destinationId.equals('someone-else')))
            .get();
        expect(backlogRows.length, bulkCount);
        expect(
          backlogRows
              .every((r) => r.deliveryState == RelayDeliveryState.queued.name),
          isTrue,
          reason: 'the bulk backlog for another destination must still be '
              'sitting queued -- the direct send must not wait for or be '
              'blocked by it in any way',
        );

        await db2.close();
        await peerDb.close();
      },
    );
  });

  group('EARS-CALL-8 — starvation guard', () {
    test(
      'test_EARS_CALL_8_bulk_queue_still_drains_under_continuous_realtime_load',
      () async {
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );

        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (nextHopId, bytes) async => true,
        );

        const bulkCount = 50;
        for (var i = 0; i < bulkCount; i++) {
          await relay.enqueue(
            'B',
            _bytes('bulk-$i'),
            RelayPriority.bulk,
            const Duration(hours: 1),
          );
        }

        Future<int> queuedCount() async {
          final rows = await (db.select(db.relayPackets)
                ..where((t) =>
                    t.deliveryState.equals(RelayDeliveryState.queued.name)))
              .get();
          return rows.length;
        }

        expect(await queuedCount(), bulkCount);

        // A continuous realtime stream: one fresh realtime packet arrives
        // before every single cycle, forever, for as long as the loop
        // below runs -- exactly the "40-minute call" scenario the task
        // file's starvation-guard note describes. A bounded per-cycle
        // budget with NO starvation guard would let this starve the bulk
        // backlog forever (realtime is always the newest AND the highest
        // priority, so it always sorts first).
        var cycle = 0;
        const maxCycles = 200; // generous bound -- hitting it is a failure.
        const budget = 5;
        while (await queuedCount() > 0 && cycle < maxCycles) {
          await relay.enqueue(
            'B',
            _bytes('call-$cycle'),
            RelayPriority.realtime,
            const Duration(seconds: 30),
          );
          await relay.processQueue(maxPacketsPerCycle: budget);
          cycle++;
        }

        expect(
          await queuedCount(),
          0,
          reason: 'the bulk backlog must fully drain even under a '
              'continuous realtime stream (task file §2 starvation guard) '
              '-- it must never be starved',
        );
        expect(
          cycle,
          lessThan(maxCycles),
          reason: 'must drain within a bounded number of cycles, not '
              'merely "eventually" in an unbounded limit',
        );

        final deliveredBulk = await (db.select(db.relayPackets)
              ..where((t) =>
                  t.deliveryState.equals(RelayDeliveryState.delivered.name)))
            .get();
        expect(
          deliveredBulk.where((r) => r.priority == RelayPriority.bulk).length,
          bulkCount,
          reason: 'every one of the original 50 bulk packets was actually '
              'delivered, not merely expired off the queue',
        );
      },
    );

    test(
      'test_starvation_guard_is_a_no_op_when_only_one_priority_band_is_queued',
      () async {
        // A pure top-band queue must still respect the bounded budget --
        // the guard's "reserve slots for a lower band" logic must not
        // accidentally shrink the budget when there is no lower band to
        // reserve for.
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );

        var attempts = 0;
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (nextHopId, bytes) async {
            attempts++;
            return true;
          },
        );

        for (var i = 0; i < 10; i++) {
          await relay.enqueue(
            'B',
            _bytes('realtime-$i'),
            RelayPriority.realtime,
            const Duration(minutes: 5),
          );
        }

        final attemptedThisCycle =
            await relay.processQueue(maxPacketsPerCycle: 4);
        expect(attemptedThisCycle, 4);
        expect(attempts, 4);
      },
    );
  });

  group('EARS-CALL-8 — starvation guard, three-plus bands (review F1)', () {
    test(
      'test_bottom_band_still_makes_progress_under_continuous_pressure_from_two_higher_bands',
      () async {
        // Review finding F1 (round 1): the earlier starvation guard merged
        // every non-top row into one "lower" bucket, still sorted
        // `(priority DESC, created_at ASC)`. With 3 distinct bands live
        // (realtime, interactive, bulk), `interactive` always sorted ahead
        // of `bulk` within that merged bucket, so the reserved slice for
        // "everything but top" was entirely consumed by `interactive` --
        // the reviewer proved zero `bulk` packets were ever attempted across
        // 200 cycles. This test reproduces exactly that shape and asserts
        // `bulk` still drains.
        //
        // Round-2 finding N1: the first version of this test only enqueued
        // ONE realtime row per cycle against `budget = 5`, so the top band
        // never came close to exhausting the cycle budget -- F2's rollover
        // (unused top-band share handed down to lower bands) alone was
        // enough to satisfy this test's shape even with F1's actual
        // per-band reserve reverted. Fixed by making the realtime arrival
        // rate per cycle exceed the whole budget
        // (`realtimeArrivalsPerCycle > budget`), so the top band is always
        // fat enough to consume every slot the reserve step leaves it --
        // there is never leftover budget for F2's rollover to hand down,
        // so `bulk`'s progress can only come from F1's genuine per-band
        // reserve. The loop condition also switched from "total queue
        // empty" to "bulk fully delivered", since a perpetually replenished
        // realtime stream (simulating a live call) never lets the total
        // queue reach zero -- exactly the scenario this guard exists for.
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );

        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (nextHopId, bytes) async => true,
        );

        const bulkCount = 50;
        for (var i = 0; i < bulkCount; i++) {
          await relay.enqueue(
            'B',
            _bytes('bulk-$i'),
            RelayPriority.bulk,
            const Duration(hours: 1),
          );
        }

        Future<int> stateCount(RelayDeliveryState state, {int? priority}) async {
          final rows = await (db.select(db.relayPackets)
                ..where((t) => t.deliveryState.equals(state.name)))
              .get();
          if (priority == null) return rows.length;
          return rows.where((r) => r.priority == priority).length;
        }

        Future<int> deliveredBulkCount() =>
            stateCount(RelayDeliveryState.delivered, priority: RelayPriority.bulk);

        // Every cycle, a fresh BURST of realtime packets (a live call
        // generating far more traffic than one cycle's whole budget can
        // possibly clear) AND a fresh interactive packet (an active chat)
        // arrive before the drain -- the three-band shape the reviewer's
        // probe used, strengthened per N1 so the top band is always fat
        // enough to exhaust the entire budget on its own. This means the
        // only way `bulk` ever gets a slot is via F1's genuine per-band
        // reserve -- F2's rollover has nothing left over to hand down.
        var cycle = 0;
        const maxCycles = 200;
        const budget = 5;
        const realtimeArrivalsPerCycle = 10; // > budget: exhausts it alone.
        while (await deliveredBulkCount() < bulkCount && cycle < maxCycles) {
          for (var i = 0; i < realtimeArrivalsPerCycle; i++) {
            await relay.enqueue(
              'B',
              _bytes('call-$cycle-$i'),
              RelayPriority.realtime,
              const Duration(seconds: 30),
            );
          }
          await relay.enqueue(
            'B',
            _bytes('chat-$cycle'),
            RelayPriority.interactive,
            const Duration(seconds: 30),
          );
          await relay.processQueue(maxPacketsPerCycle: budget);
          cycle++;
        }

        final deliveredBulk = await deliveredBulkCount();
        expect(
          deliveredBulk,
          bulkCount,
          reason: 'the bottom band must fully drain even with two higher '
              'bands continuously present and the top band alone able to '
              'exhaust the entire cycle budget -- a merged "everything but '
              'top" reserve lets the middle band starve the bottom one '
              'forever, and without a genuine per-band reserve there is no '
              'leftover top-band budget for a rollover step to rescue it',
        );
        expect(
          cycle,
          lessThan(maxCycles),
          reason: 'must drain within a bounded number of cycles',
        );
      },
    );
  });

  group('starvation guard budget usage (review F2)', () {
    test(
      'test_unused_top_band_budget_rolls_over_to_the_lower_band',
      () async {
        // Review finding F2 (round 1): `remainingForTop = budget -
        // reservedForLower` then `topBand.take(remainingForTop)` discarded
        // any slots the (smaller) top band didn't use, instead of letting
        // the lower band use them. The reviewer's probe: 1 realtime packet +
        // 50 bulk packets, budget 10 -> only 3 of 10 slots attempted. This
        // test asserts the *property* -- significantly more than 1 packet
        // attempted -- rather than pinning that exact old "3" number, since
        // the exact figure is an artifact of the buggy code, not a contract.
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );

        var attempts = 0;
        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (nextHopId, bytes) async {
            attempts++;
            return true;
          },
        );

        await relay.enqueue(
          'B',
          _bytes('realtime-only'),
          RelayPriority.realtime,
          const Duration(minutes: 5),
        );
        const bulkCount = 50;
        for (var i = 0; i < bulkCount; i++) {
          await relay.enqueue(
            'B',
            _bytes('bulk-$i'),
            RelayPriority.bulk,
            const Duration(hours: 1),
          );
        }

        final attemptedThisCycle =
            await relay.processQueue(maxPacketsPerCycle: 10);

        expect(
          attemptedThisCycle,
          greaterThan(3),
          reason: 'unused top-band budget must roll over to the lower band '
              'instead of being discarded -- the old code attempted only 3 '
              'of the 10 budgeted slots here',
        );
        expect(attempts, attemptedThisCycle);
      },
    );
  });

  group('unbounded processQueue() -- backward compatible default', () {
    test(
      'test_processQueue_with_no_budget_attempts_every_eligible_packet',
      () async {
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );

        final relay = RelayEngine(
          selfId: 'A',
          db: db,
          routingEngine: routingEngine,
          send: (nextHopId, bytes) async => true,
        );

        for (var i = 0; i < 12; i++) {
          await relay.enqueue(
            'B',
            _bytes('pkt-$i'),
            RelayPriority.bulk,
            const Duration(minutes: 5),
          );
        }

        final attempted = await relay.processQueue();
        expect(
          attempted,
          12,
          reason: 'no `maxPacketsPerCycle` means unbounded -- every '
              'existing call site (`messaging_coordinator.dart`) calls '
              'processQueue() with no arguments and must keep attempting '
              'every eligible packet in one pass, exactly as before this '
              'task',
        );
      },
    );
  });
}
