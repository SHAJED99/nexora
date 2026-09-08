// Tests for MessagingCoordinator (E06-T06, EARS-MSG-1/EARS-COMM-11/12/13).
//
// This is the regression suite E05-B02 specifies and could not write itself
// (its own §Regression test note: "deferred until the human picks the
// trigger model, because the test must assert the chosen contract, not a
// guessed one"). `OQ-E06-T06-1` resolved to option (c): event-driven ticks
// on route/connectivity-change plus a `tickInterval` timer floor
// (`Duration(seconds: 60)` in production, injected here per test).
//
// `test_EARS_MSG_1_queued_message_forwards_once_a_route_exists` below is the
// exact test named in the task file's own §8 test plan and MUST fail to
// compile on `development` @ `35710f7` -- confirmed (see this task's Run
// log): `lib/core/messaging/messaging_coordinator.dart` does not exist
// there at all.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/app/bindings.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);

/// Mocks the native side of `TransportApi.send` on [suffix]'s channel to
/// always accept the send (mirrors `transport_service_test.dart`'s own
/// `test_EARS_TRANSPORT_1_loopback_roundtrip` handler, minus its
/// `onDataReceived` echo, which these tests don't need). Without a handler
/// registered, `TransportService.send` throws `MissingPluginException` and
/// `RelayEngine._attempt` catches that as an ordinary failed send -- so
/// every test that expects an ACTUAL forward over the real
/// `MessagingStack.create` -> `TransportService.send` wiring (not a fully
/// in-Dart fake) needs this.
void _mockSendAlwaysSucceeds(TestDefaultBinaryMessenger messenger, String suffix) {
  messenger.setMockMessageHandler(
    'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
    (ByteData? message) async =>
        TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]),
  );
}

/// E04-B05: `RelayEngine`'s send path now goes through
/// `ConnectionEnsuringSender`, which calls `TransportApi.connect` before
/// `TransportApi.send`. Mocks the native side of `connect` to accept
/// immediately, then fire the real two-channel settle event
/// (`TransportEventsApi.onConnectionStateChanged` -> `connected`), mirroring
/// `TransportService.connect`'s own real contract (`transport_service_test.dart`).
void _mockConnectAlwaysSucceeds(TestDefaultBinaryMessenger messenger, String suffix) {
  messenger.setMockMessageHandler(
    'dev.flutter.pigeon.nexora.TransportApi.connect.$suffix',
    (ByteData? message) async {
      final args = TransportApi.pigeonChannelCodec.decodeMessage(message)!
          as List<Object?>;
      final deviceId = args[0]! as String;
      scheduleMicrotask(() {
        messenger.handlePlatformMessage(
          'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
          TransportEventsApi.pigeonChannelCodec
              .encodeMessage(<Object?>[deviceId, ConnectionState.connected])!,
          (ByteData? _) {},
        );
      });
      return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
    },
  );
}

/// A `TransportService` whose `send` is entirely under the test's control --
/// completes only when the test resolves [gate] (or immediately, if [gate]
/// is left `null`) -- so a `RelayEngine.processQueue()` pass driven through
/// this transport can be made deliberately slow (task file §6 risk: "test it
/// with a deliberately slow fake") without needing real Bluetooth or a
/// `NetworkSimulator`, since the coordinator only ever reaches `RelayEngine`
/// through `MessagingStack`, and `MessagingStack.create` wires
/// `RelayEngine`'s `send` straight from `TransportService.send`
/// (`messaging_stack.dart`'s own header).
class _ControlledSendTransport extends TransportService {
  _ControlledSendTransport({
    required super.binaryMessenger,
    required super.messageChannelSuffix,
  });

  Completer<void>? gate;
  int sendCallCount = 0;

  // E04-B05: `RelayEngine`'s send path now goes through
  // `ConnectionEnsuringSender`, which calls `connect()` before `send()`.
  // This fake only ever needed to control `send()`'s own timing/count; a
  // connect that always succeeds keeps that behavior unchanged.
  @override
  Future<bool> connect(String deviceId) async => true;

  @override
  Future<bool> send(String deviceId, Uint8List bytes) async {
    sendCallCount++;
    if (gate != null) {
      await gate!.future;
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'coordinator-${suffixCounter++}';

  /// Builds a ready `MessagingStack` with a directly-recorded neighbor link
  /// to [neighborId] (so `RoutingEngine.computeRoute` has a real one-hop
  /// route to send over) and, optionally, a caller-supplied [transport] so
  /// a test can control `send`'s timing.
  Future<MessagingStack> newStack(
    String selfDeviceId,
    String suffix, {
    String? neighborId,
    TransportService? transport,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final resolvedTransport = transport ??
        TransportService(binaryMessenger: messenger, messageChannelSuffix: suffix);
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: selfDeviceId,
      transport: resolvedTransport,
      coordinatorTickInterval: const Duration(seconds: 60),
    );
    expect(stack.status, const MessagingStackStatus.ready());
    if (neighborId != null) {
      stack.routingEngine.recordLinkMeasurement(
        neighborId,
        latencyMs: 20,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );
    }
    return stack;
  }

  group('EARS-MSG-1 — the queue actually gets a driver', () {
    test(
      'test_EARS_MSG_1_queued_message_forwards_once_a_route_exists',
      () async {
        // No route recorded yet -- exactly E05-B02's repro: a message
        // composed offline stays `queued` forever without a driver.
        final suffix = nextSuffix();
        final stack = await newStack('device-a', suffix);
        addTearDown(stack.dispose);
        _mockSendAlwaysSucceeds(messenger, suffix);
        _mockConnectAlwaysSucceeds(messenger, suffix);

        await stack.cryptoService.establishSession(
          const SignalProtocolAddress('device-b', 1),
          await _freshPeerBundle(),
        );

        await stack.sendMessage.call(
          'conv-1',
          'device-b',
          _plaintext('offline compose'),
        );

        final packetsBeforeRoute =
            await stack.db.select(stack.db.relayPackets).get();
        expect(packetsBeforeRoute, hasLength(1));
        expect(
          packetsBeforeRoute.single.deliveryState,
          RelayDeliveryState.queued.name,
        );

        // A tick with no route must leave the packet queued (nothing to
        // forward over) -- proves this suite isn't vacuously green because
        // the packet never had a chance to move.
        await stack.coordinator.tick();
        final stillQueued = await stack.db.select(stack.db.relayPackets).get();
        expect(stillQueued.single.deliveryState, RelayDeliveryState.queued.name);

        // A route now becomes available (mirrors "bring the peer in range").
        stack.routingEngine.recordLinkMeasurement(
          'device-b',
          latencyMs: 15,
          lossRate: 0.0,
          batteryDrain: 0.05,
        );

        await stack.coordinator.tick();
        final afterFirstTick =
            await stack.db.select(stack.db.relayPackets).get();
        expect(afterFirstTick.single.deliveryState, isNot(RelayDeliveryState.queued.name));
        expect(
          afterFirstTick.single.deliveryState,
          RelayDeliveryState.delivered.name,
        );

        // A second tick must not re-forward an already-delivered packet --
        // `RelayEngine.processQueue()` only ever selects `queued` rows, so
        // this also proves the coordinator isn't doing anything extra that
        // would resend it.
        await stack.coordinator.tick();
        final afterSecondTick =
            await stack.db.select(stack.db.relayPackets).get();
        expect(
          afterSecondTick.single.deliveryState,
          RelayDeliveryState.delivered.name,
        );
      },
    );
  });

  group('EARS-COMM-11 — sweep + reclaim run on the same schedule', () {
    test(
      'test_EARS_COMM_11_expired_packets_swept_and_payloads_reclaimed',
      () async {
        final stack = await newStack('device-a', nextSuffix());
        addTearDown(stack.dispose);

        final now = DateTime.now();
        await stack.relayEngine.enqueue(
          'device-b',
          Uint8List.fromList([1, 2, 3]),
          0,
          const Duration(seconds: -30), // already expired at insert
        );
        // Sanity: the row exists and is queued with a real payload before
        // the tick runs, and is genuinely already past its own expiry.
        final before = await stack.db.select(stack.db.relayPackets).get();
        expect(before, hasLength(1));
        expect(before.single.payload, isNotNull);
        expect(before.single.expiresAt, lessThanOrEqualTo(now.millisecondsSinceEpoch));

        await stack.coordinator.tick();

        final after = await stack.db.select(stack.db.relayPackets).get();
        expect(after.single.deliveryState, RelayDeliveryState.expired.name);
        // reclaimPayloads runs in the SAME tick, after sweepExpired
        // (E04-B02's established order) -- the payload should already be
        // nulled, not left until a second tick.
        expect(after.single.payload, isNull);
        expect(stack.coordinator.counters.swept, 1);
        expect(stack.coordinator.counters.reclaimed, 1);
      },
    );
  });

  group('EARS-COMM-12 — sync cursor advances at the store point', () {
    test('test_EARS_COMM_12_cursor_advances_on_send_and_on_receive', () async {
      final stack = await newStack('device-a', nextSuffix());
      addTearDown(stack.dispose);

      final outbound = Message(
        id: 'm-out-1',
        conversationId: 'conv-1',
        senderDeviceId: 'device-a',
        sequenceNumber: 3,
        ciphertext: Uint8List.fromList([1]),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        deliveryState: DeliveryState.sent,
      );
      await stack.coordinator.recordStored(outbound);

      final selfCursor =
          await stack.syncCursors.cursorFor('conv-1', 'device-a');
      expect(selfCursor, isNotNull);
      expect(selfCursor!.lastConfirmedSequenceNumber, 3);

      final inbound = Message(
        id: 'm-in-1',
        conversationId: 'conv-1',
        senderDeviceId: 'device-c',
        sequenceNumber: 7,
        ciphertext: Uint8List.fromList([2]),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        deliveryState: DeliveryState.accepted,
      );
      await stack.coordinator.recordStored(inbound);

      final remoteCursor =
          await stack.syncCursors.cursorFor('conv-1', 'device-c');
      expect(remoteCursor, isNotNull);
      expect(remoteCursor!.lastConfirmedSequenceNumber, 7);
    });

    test(
      'test_EARS_COMM_12_concurrent_stores_do_not_lose_a_cursor_update',
      () async {
        // The required falsification test (implement/SKILL.md §6 / task
        // file §6 risk, recurrence 5's lineage): two overlapping
        // `recordStored` calls through THIS coordinator's own new call path
        // (not SyncCursorService directly, which E05-T04 already proved
        // safe alone) at sequence 10 and 4 for the same conversation/device
        // pair -- the cursor must end at 10, never 4, regardless of which
        // completes first. `recordLocalProgress`'s guarded single-statement
        // upsert (sync_cursor_service.dart:142-171) is what makes this safe;
        // this test proves the coordinator's added concurrency does not
        // reopen the read-then-write window that fix closed.
        final stack = await newStack('device-a', nextSuffix());
        addTearDown(stack.dispose);

        Message msg(int sequenceNumber) => Message(
              id: 'm-$sequenceNumber',
              conversationId: 'conv-1',
              senderDeviceId: 'device-b',
              sequenceNumber: sequenceNumber,
              ciphertext: Uint8List.fromList([sequenceNumber]),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              deliveryState: DeliveryState.accepted,
            );

        await Future.wait([
          stack.coordinator.recordStored(msg(10)),
          stack.coordinator.recordStored(msg(4)),
        ]);

        final cursor = await stack.syncCursors.cursorFor('conv-1', 'device-b');
        expect(cursor, isNotNull);
        expect(cursor!.lastConfirmedSequenceNumber, 10);
      },
    );
  });

  group('delivery_states gets a writer', () {
    test(
      'test_delivery_states_rows_are_appended_for_each_transition',
      () async {
        final stack = await newStack('device-a', nextSuffix());
        addTearDown(stack.dispose);

        final sentMessage = Message(
          id: 'm-sent-1',
          conversationId: 'conv-1',
          senderDeviceId: 'device-a',
          sequenceNumber: 1,
          ciphertext: Uint8List.fromList([9]),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          deliveryState: DeliveryState.sent,
        );
        await stack.coordinator.recordStored(sentMessage);

        final acceptedMessage = Message(
          id: 'm-accepted-1',
          conversationId: 'conv-1',
          senderDeviceId: 'device-c',
          sequenceNumber: 1,
          ciphertext: Uint8List.fromList([8]),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          deliveryState: DeliveryState.accepted,
        );
        await stack.coordinator.recordStored(acceptedMessage);

        final rows = await stack.db.select(stack.db.deliveryStates).get();
        expect(rows, hasLength(2));
        final byMessage = {for (final r in rows) r.messageId: r.state};
        expect(byMessage['m-sent-1'], DeliveryState.sent.name);
        expect(byMessage['m-accepted-1'], DeliveryState.accepted.name);
      },
    );
  });

  group('EARS-COMM-13 — one bad pass never stops the loop', () {
    test('test_EARS_COMM_13_a_failing_pass_does_not_stop_the_loop', () async {
      final suffix = nextSuffix();
      final stack = await newStack('device-a', suffix, neighborId: 'device-b');
      addTearDown(stack.dispose);
      _mockSendAlwaysSucceeds(messenger, suffix);
      _mockConnectAlwaysSucceeds(messenger, suffix);

      // `RelayEngine.processQueue()`/`sweepExpired()`/`reclaimPayloads()`
      // are each deliberately defensive against a bad SEND already
      // (E04-T04's own contract: `_attempt`'s own `try`/`catch` around
      // `_send`, `relay_engine.dart:186-197`) -- this task must not modify
      // `RelayEngine` (§4) to make it throw on purpose either. The only
      // honest way to prove THIS coordinator's own per-tick guard is real
      // is to fail a step it is actually responsible for driving: the DB
      // query `_countQueued()` runs immediately before
      // `processQueue()`. Renaming `relay_packets` out from under it (then
      // back) forces a genuine `SqliteException` mid-pass without touching
      // `RelayEngine` at all.
      await stack.db.customStatement(
        'ALTER TABLE relay_packets RENAME TO relay_packets_hidden',
      );

      await stack.coordinator.tick();
      expect(stack.coordinator.counters.tickFailures, 1);
      expect(stack.coordinator.counters.ticks, 1);

      // Pass 2 -- the loop must still be alive: restore the table and prove
      // a normal packet still forwards, with tickFailures unchanged (this
      // second pass succeeds cleanly).
      await stack.db.customStatement(
        'ALTER TABLE relay_packets_hidden RENAME TO relay_packets',
      );
      await stack.relayEngine.enqueue(
        'device-b',
        Uint8List.fromList([1, 2, 3]),
        0,
        const Duration(days: 1),
      );

      await stack.coordinator.tick();
      expect(stack.coordinator.counters.tickFailures, 1);
      expect(stack.coordinator.counters.ticks, 2);
      final rows = await stack.db.select(stack.db.relayPackets).get();
      expect(rows.single.deliveryState, RelayDeliveryState.delivered.name);
    });
  });

  group('tick() re-entrancy guard', () {
    test('test_tick_is_not_re_entrant', () async {
      final suffix = nextSuffix();
      final transport = _ControlledSendTransport(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      final stack = await newStack(
        'device-a',
        suffix,
        neighborId: 'device-b',
        transport: transport,
      );
      addTearDown(stack.dispose);

      await stack.relayEngine.enqueue(
        'device-b',
        Uint8List.fromList([1, 2, 3]),
        0,
        const Duration(days: 1),
      );

      transport.gate = Completer<void>();

      // First tick starts a pass that will block inside `processQueue()`'s
      // own `send` call until the test releases the gate.
      final firstTick = stack.coordinator.tick();
      // A second trigger arrives while the first pass is still in flight --
      // the exact "tick interval shorter than the pass" scenario (task
      // file §6 risk) -- deterministically, not by racing a real Timer.
      final secondTick = stack.coordinator.tick();

      // Let both futures' microtasks settle before releasing the gate, so
      // the guard's synchronous check has definitely already run for the
      // second call.
      await Future<void>.delayed(Duration.zero);
      expect(transport.sendCallCount, 1);

      transport.gate!.complete();
      await Future.wait([firstTick, secondTick]);

      // Exactly one pass ever ran, even though tick() was invoked twice
      // while the first was still in flight.
      expect(transport.sendCallCount, 1);
      expect(stack.coordinator.counters.ticks, 1);
    });
  });

  group('start() reconciliation', () {
    test('test_start_reconciles_the_crash_window_once', () async {
      final suffix = nextSuffix();
      final stack = await newStack('device-a', suffix);
      addTearDown(stack.dispose);
      addTearDown(stack.coordinator.stop);

      // Hand-build the exact crash shape E05-T02's review observation 3
      // describes: a `Queued` message whose relay packet was already
      // durably enqueued before the process died, so the final `Sent`
      // transition never happened.
      final ciphertext = Uint8List.fromList([4, 5, 6]);
      await stack.db.into(stack.db.messages).insert(
            MessagesCompanion.insert(
              id: 'm-crash-1',
              conversationId: 'conv-1',
              senderDeviceId: 'device-a',
              sequenceNumber: 1,
              ciphertext: ciphertext,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              deliveryState: DeliveryState.queued.name,
            ),
          );
      await stack.relayEngine.enqueue(
        'device-b',
        ciphertext,
        0,
        const Duration(days: 1),
      );

      await stack.coordinator.start();

      final afterFirstStart =
          await (stack.db.select(stack.db.messages)
                ..where((t) => t.id.equals('m-crash-1')))
              .getSingle();
      expect(afterFirstStart.deliveryState, DeliveryState.sent.name);
      expect(stack.coordinator.counters.reconciled, 1);

      final deliveryStateRows = await (stack.db.select(stack.db.deliveryStates)
            ..where((t) => t.messageId.equals('m-crash-1')))
          .get();
      expect(deliveryStateRows, hasLength(1));
      expect(deliveryStateRows.single.state, DeliveryState.sent.name);

      // A second start() must be a no-op (idempotent per the task's own
      // contract) and reconcile zero the second time.
      final reconciledSecondTime = await stack.coordinator.reconcileQueuedMessages();
      expect(reconciledSecondTime, 0);
    });

    test('test_start_calls_inbound_pipeline_start', () async {
      final suffix = nextSuffix();
      final sender = await newStack('device-x', nextSuffix());
      addTearDown(sender.dispose);
      final receiver = await newStack('device-y', suffix);
      addTearDown(receiver.dispose);
      addTearDown(receiver.coordinator.stop);

      await sender.cryptoService.establishSession(
        const SignalProtocolAddress('device-y', 1),
        await receiver.identityService.getLocalPreKeyBundle(),
      );
      final sent = await sender.sendMessage.call(
        'conv-1',
        'device-y',
        _plaintext('via coordinator start'),
      );

      await receiver.coordinator.start();

      final deliveredFuture = receiver.inbound.delivered.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError(
          'InboundPipeline.start() was not called by MessagingCoordinator.start()',
        ),
      );

      final receiverTransportSuffix = suffix;
      _pushDiscovered(messenger, receiverTransportSuffix, 'device-x');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      _pushConnectionState(
        messenger,
        receiverTransportSuffix,
        'device-x',
        ConnectionState.connected,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      _pushIncomingData(
        messenger,
        receiverTransportSuffix,
        'device-x',
        sent.ciphertext,
      );

      final delivered = await deliveredFuture;
      expect(delivered.senderDeviceId, 'device-x');

      // The auto-subscription this coordinator sets up on `start()` must
      // have advanced the sync cursor and appended a delivery_states row
      // without anyone calling recordStored manually.
      final cursor = await receiver.syncCursors.cursorFor('conv-1', 'device-x');
      expect(cursor, isNotNull);
      expect(cursor!.lastConfirmedSequenceNumber, delivered.sequenceNumber);
    });
  });

  group(
    'EARS-STORE-15 — the storage manager is wired from the composition root',
    () {
      // This is the exact composition-root defect class (`E07-B03`,
      // `OQ-E06-T06-4`) E08-T06 exists to close for good (task file §2):
      // every test below resolves `StorageManager` through `AppBinding
      // .dependencies()` + `Get.find`, never from a hand-built object.
      setUp(Get.reset);
      tearDown(Get.reset);

      test(
        'test_EARS_STORE_15_app_binding_registers_storage_manager',
        () async {
          final stack = await newStack('device-a', nextSuffix());
          addTearDown(stack.dispose);
          addTearDown(stack.coordinator.stop);

          AppBinding(db: stack.db, messagingStack: stack).dependencies();

          final manager = Get.find<StorageManager>();
          expect(manager, isNotNull);
          // The SAME instance AppBinding registered is what the coordinator
          // actually drives -- not a second, disconnected one.
          expect(identical(stack.coordinator.storageManager, manager), isTrue);
        },
      );

      test(
        'test_EARS_STORE_15_coordinator_tick_runs_a_storage_pass',
        () async {
          final stack = await newStack('device-a', nextSuffix());
          addTearDown(stack.dispose);
          addTearDown(stack.coordinator.stop);

          AppBinding(db: stack.db, messagingStack: stack).dependencies();

          await stack.coordinator.tick();

          final rows = await stack.db.select(stack.db.storageDecisions).get();
          expect(
            rows,
            isNotEmpty,
            reason: 'the tick must have driven a real storage pass through '
                'the registered StorageManager',
          );
        },
      );

      test(
        'test_EARS_STORE_15_storage_pass_failure_does_not_abort_tick',
        () async {
          final suffix = nextSuffix();
          final stack =
              await newStack('device-a', suffix, neighborId: 'device-b');
          addTearDown(stack.dispose);
          _mockSendAlwaysSucceeds(messenger, suffix);
          _mockConnectAlwaysSucceeds(messenger, suffix);

          await stack.relayEngine.enqueue(
            'device-b',
            Uint8List.fromList([1, 2, 3]),
            0,
            const Duration(days: 1),
          );

          // A throwing storage manager, set directly on the coordinator
          // (this test does not need AppBinding -- it only needs to prove
          // the coordinator's own isolation, EARS-STORE-15's other half).
          stack.coordinator.storageManager =
              _ThrowingStorageManager(stack.db);

          await stack.coordinator.tick();

          expect(stack.coordinator.counters.storagePassFailures, 1);
          expect(
            stack.coordinator.counters.tickFailures,
            0,
            reason: 'a storage-pass failure must never be counted as, or '
                'cause, a messaging tick failure',
          );
          // The messaging work this same tick did BEFORE the storage pass
          // ran must have completed regardless.
          final rows = await stack.db.select(stack.db.relayPackets).get();
          expect(rows.single.deliveryState, RelayDeliveryState.delivered.name);
        },
      );

      test('test_EARS_STORE_15_pass_is_throttled_across_ticks', () async {
        final stack = await newStack('device-a', nextSuffix());
        addTearDown(stack.dispose);
        addTearDown(stack.coordinator.stop);

        AppBinding(db: stack.db, messagingStack: stack).dependencies();

        await stack.coordinator.tick();
        final afterFirst =
            await stack.db.select(stack.db.storageDecisions).get();
        expect(afterFirst, isNotEmpty);

        await stack.coordinator.tick();
        final afterSecond =
            await stack.db.select(stack.db.storageDecisions).get();
        // The default storagePassInterval is hours; back-to-back ticks in
        // this test are milliseconds apart -- the second pass must be
        // throttled, recording nothing new.
        expect(afterSecond.length, afterFirst.length);
      });
    },
  );

  group(
    'E04-B07 — an accepted connection from an already-known peer still '
    'drives an immediate tick, not just the timer floor',
    () {
      test(
        'test_E04_B07_trusted_peer_connected_with_no_prior_discovery_still_ticks_immediately',
        () async {
          final suffix = nextSuffix();
          final stack = await newStack('device-a', suffix, neighborId: 'device-b');
          addTearDown(stack.dispose);
          addTearDown(stack.coordinator.stop);
          _mockSendAlwaysSucceeds(messenger, suffix);
          _mockConnectAlwaysSucceeds(messenger, suffix);

          // The receiver already trusts device-b -- e.g. from a previous
          // process run -- but THIS run never calls `_pushDiscovered` for
          // it (E04-B06's own accept-loop scenario: the peer dialled IN).
          await RelationshipRepository(
            stack.db,
          ).upsert('device-b', RelationshipState.trusted);

          await stack.cryptoService.establishSession(
            const SignalProtocolAddress('device-b', 1),
            await _freshPeerBundle(),
          );
          await stack.sendMessage.call(
            'conv-1',
            'device-b',
            _plaintext('should go out on the accepted connection event'),
          );
          final beforeConnect =
              await stack.db.select(stack.db.relayPackets).get();
          expect(beforeConnect.single.deliveryState, RelayDeliveryState.queued.name);

          // `coordinator.start()` seeds `_connectionSubscriptions` from
          // already-known relationships (E04-B07's own fix) -- await it so
          // that seeding has genuinely completed before the connection
          // event fires, not racing it.
          await stack.coordinator.start();

          // Simulate an ACCEPTED connection: onConnectionStateChanged
          // fires directly, with no onDeviceDiscovered for this device id
          // at all in this process run. `coordinatorTickInterval` is 60s
          // (this file's own `newStack` default) -- if this event does not
          // drive an immediate `tick()`, the packet stays `queued` for the
          // whole timer floor, which this test's own timeout would catch.
          _pushConnectionState(
            messenger,
            suffix,
            'device-b',
            ConnectionState.connected,
          );

          final delivered = await _waitUntil(
            () async {
              final rows = await stack.db.select(stack.db.relayPackets).get();
              return rows.single.deliveryState == RelayDeliveryState.delivered.name;
            },
            timeout: const Duration(seconds: 5),
            onTimeout: () => throw StateError(
              'E04-B07 regression: an accepted connection from an '
              'already-trusted, non-freshly-discovered peer did not drive '
              'an immediate tick -- the packet is still waiting on the '
              '60s timer floor',
            ),
          );
          expect(delivered, isTrue);
        },
      );
    },
  );
}

/// Polls [check] every 20ms until it returns `true` or [timeout] elapses,
/// in which case [onTimeout] is called (expected to throw). Used instead of
/// a single fixed `Future.delayed` wait so this test settles as soon as the
/// event-driven tick actually runs, rather than always paying a fixed delay.
Future<bool> _waitUntil(
  Future<bool> Function() check, {
  required Duration timeout,
  required Never Function() onTimeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await check()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  onTimeout();
}

/// A [StorageManager] whose [runPass] always throws -- proves
/// `MessagingCoordinator`'s own isolation of the storage pass
/// (`test_EARS_STORE_15_storage_pass_failure_does_not_abort_tick`) without
/// needing a real failure to occur deep inside the storage stack.
class _ThrowingStorageManager extends StorageManager {
  _ThrowingStorageManager(AppDatabase db)
      : super(
          settings: StorageSettingsRepository(db: db),
          inventory: StorageInventory(db: db, databaseFileBytes: () async => 0),
          smart: SmartModePolicy(thresholds: SmartModeThresholds.defaults()),
          executor: RetentionExecutor(db: db, log: StorageDecisionLog(db: db)),
          log: StorageDecisionLog(db: db),
        );

  @override
  Future<RetentionPlan?> runPass({required int nowEpochMs, bool apply = true}) {
    throw Exception('simulated storage pass failure');
  }
}

/// Small helper matching `messaging_stack_test.dart`'s own out-of-band
/// session-establishment pattern -- builds a fresh `_bob`-shaped party's
/// prekey bundle so `establishSession` can be called without depending on a
/// second full `MessagingStack`. Kept file-local since it only exists to
/// keep the tests above from needing yet another remote-party scaffold class
/// for the single-stack tests that don't otherwise need a real peer.
Future<PreKeyBundle> _freshPeerBundle() async {
  // Builds a throwaway second identity purely so the caller's
  // `establishSession` has a real bundle to consume -- this identity never
  // participates in the test beyond that, matching
  // `messaging_stack_test.dart`'s own `_RemoteParty` pattern in spirit but
  // without needing its own MessagingStack.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final store = DriftSignalProtocolStore(db);
  final identity = IdentityService(db, store);
  await identity.ensureLocalIdentity();
  await identity.ensureSignedPreKey();
  await identity.replenishOneTimePreKeys();
  return identity.getLocalPreKeyBundle();
}

void _pushDiscovered(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
) {
  final device = TransportDevice(
    id: deviceId,
    displayName: deviceId,
    type: TransportType.bluetooth,
  );
  final ByteData message =
      TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!;
  messenger.handlePlatformMessage(
    'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
    message,
    (ByteData? _) {},
  );
}

void _pushConnectionState(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
  ConnectionState state,
) {
  final ByteData message = TransportEventsApi.pigeonChannelCodec
      .encodeMessage(<Object?>[deviceId, state])!;
  messenger.handlePlatformMessage(
    'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
    message,
    (ByteData? _) {},
  );
}

void _pushIncomingData(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
  Uint8List bytes,
) {
  final ByteData message = TransportEventsApi.pigeonChannelCodec
      .encodeMessage(<Object?>[deviceId, bytes])!;
  messenger.handlePlatformMessage(
    'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$suffix',
    message,
    (ByteData? _) {},
  );
}
