// Tests for MessagingCoordinator.setTickInterval and the
// BackgroundLifecycleObserver composition-root wiring it feeds (E10-T10,
// EARS-PLAT-12/EARS-PLAT-14).
//
// `background_policy_test.dart` covers the pure cadence DECISION
// (`BackgroundPolicy.plan`); this file covers the MECHANICS: rescheduling
// the coordinator's own already-existing `Timer.periodic` (never a second
// one), safety while a tick is in flight, that the retention pass
// (`reclaimPayloads`) keeps running regardless of app lifecycle, and the
// one-shot reconcile after a `stoppedBySystem` event.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/app/bindings.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'coordinator-bg-${suffixCounter++}';

  Future<MessagingStack> newStack(
    String selfDeviceId,
    String suffix, {
    Duration tickInterval = const Duration(seconds: 60),
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final transport =
        TransportService(binaryMessenger: messenger, messageChannelSuffix: suffix);
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: selfDeviceId,
      transport: transport,
      coordinatorTickInterval: tickInterval,
    );
    expect(stack.status, const MessagingStackStatus.ready());
    return stack;
  }

  group('test_EARS_PLAT_12_no_second_timer_created', () {
    test(
      'repeated setTickInterval calls never leave more than one timer firing',
      () async {
        // Start with an interval long enough that the initial `start()`
        // timer never fires during this test.
        final stack = await newStack(
          'device-a',
          nextSuffix(),
          tickInterval: const Duration(minutes: 10),
        );
        addTearDown(stack.dispose);
        addTearDown(stack.coordinator.stop);

        await stack.coordinator.start();
        expect(stack.coordinator.counters.ticks, 0);

        // Simulate several power-state/lifecycle transitions arriving in
        // quick succession -- each one calls setTickInterval, exactly as
        // `BackgroundLifecycleObserver._applyPlan` would.
        const fastInterval = Duration(milliseconds: 25);
        stack.coordinator.setTickInterval(const Duration(milliseconds: 40));
        stack.coordinator.setTickInterval(const Duration(milliseconds: 30));
        stack.coordinator.setTickInterval(fastInterval);

        // If `setTickInterval` ever created a SECOND timer instead of
        // rescheduling the existing one (task file §4's single most likely
        // wrong turn), three rapid calls above would leave up to four
        // timers all firing at roughly `fastInterval`, and the tick count
        // over this window would be several times what one timer alone
        // could produce. One timer firing every 25ms for ~300ms produces at
        // most ~12 ticks (each tick also does real async DB work, so fewer
        // is normal); four coexisting timers would comfortably clear 30+.
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(
          stack.coordinator.counters.ticks,
          inInclusiveRange(1, 16),
          reason: 'tick count outside the single-timer band -- suggests '
              'more than one periodic driver is running',
        );
      },
    );
  });

  group('test_EARS_PLAT_12_interval_change_during_inflight_tick_is_safe', () {
    test(
      'rescheduling mid-tick does not cancel, double, or defeat re-entrancy',
      () async {
        final suffix = nextSuffix();
        final transport = _ControlledSendTransport(
          binaryMessenger: messenger,
          messageChannelSuffix: suffix,
        );
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final stack = await MessagingStack.create(
          db: db,
          selfDeviceId: 'device-a',
          transport: transport,
          coordinatorTickInterval: const Duration(minutes: 10),
        );
        expect(stack.status, const MessagingStackStatus.ready());
        addTearDown(stack.dispose);

        stack.routingEngine.recordLinkMeasurement(
          'device-b',
          latencyMs: 20,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );
        await stack.relayEngine.enqueue(
          'device-b',
          Uint8List.fromList([1, 2, 3]),
          0,
          const Duration(days: 1),
        );

        transport.gate = Completer<void>();

        // A pass begins and blocks inside `processQueue()`'s own `send`.
        final inFlight = stack.coordinator.tick();

        // A power-state change arrives while that pass is still running --
        // exactly the scenario task file §6's risk names.
        stack.coordinator.setTickInterval(const Duration(seconds: 5));

        // The in-flight pass must not have been cancelled, doubled, or
        // otherwise disturbed by the reschedule.
        await Future<void>.delayed(Duration.zero);
        expect(transport.sendCallCount, 1);

        transport.gate!.complete();
        await inFlight;

        expect(stack.coordinator.counters.ticks, 1);
        expect(transport.sendCallCount, 1);
        final rows = await stack.db.select(stack.db.relayPackets).get();
        expect(rows.single.deliveryState, RelayDeliveryState.delivered.name);

        // The new interval took effect for the NEXT tick, not the one that
        // was already in flight -- a fresh, explicit tick still runs
        // cleanly (nothing about the coordinator was left in a broken
        // state by rescheduling mid-pass).
        await stack.coordinator.tick();
        expect(stack.coordinator.counters.ticks, 2);
      },
    );
  });

  group('test_EARS_PLAT_14_reclaim_runs_while_backgrounded', () {
    setUp(Get.reset);
    tearDown(Get.reset);

    test(
      'reclaimPayloads runs from the real timer once genuinely paused '
      'AND the foreground service is running -- never a hand-called tick()',
      () async {
        // F5 (E10-B07): the previous version of this test established
        // NEITHER half of NFR-SEC-001's own precondition -- no
        // `AppLifecycleState`, no `ServiceState`, no
        // `BackgroundLifecycleObserver` anywhere in it -- and drove
        // `reclaimPayloads` by calling `stack.coordinator.tick()` directly.
        // That only re-proved what `messaging_coordinator_test.dart`
        // already covers before E10 existed; it could not fail if a future
        // change silently gated the tick (or the observer's own wiring)
        // on the app being foregrounded.
        //
        // This version drives the SAME two signals through the real
        // `BackgroundLifecycleObserver` this epic ships
        // (`app/bindings.dart`) -- `didChangeAppLifecycleState(paused)`
        // and a `BackgroundStub` genuinely reporting `ServiceState
        // .running` -- and then lets the coordinator's own already-live
        // `Timer.periodic` fire on its own. Nothing below calls
        // `coordinator.tick()` by hand.
        final stack = await newStack(
          'device-a',
          nextSuffix(),
          // Long enough that start()'s own timer cannot fire before the
          // background+running precondition below is established.
          tickInterval: const Duration(minutes: 10),
        );
        addTearDown(stack.dispose);
        addTearDown(stack.coordinator.stop);

        await stack.coordinator.start();

        final backgroundStub = BackgroundStub();
        AppBinding(
          db: stack.db,
          messagingStack: stack,
          backgroundControl: backgroundStub,
        ).dependencies();
        final observer = Get.find<BackgroundLifecycleObserver>();
        addTearDown(observer.stop);

        // The real observer callback -- not a test-only lever -- exactly
        // as `WidgetsBinding` would invoke it on a genuine backgrounding.
        observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        // `_setDesiredRunning(true)` above called `_service.start()`
        // unawaited; let that (and the `ServiceState.running` event it
        // emits back through the observer) settle.
        await Future<void>.delayed(Duration.zero);
        expect(
          await backgroundStub.isRunning(),
          isTrue,
          reason: 'the foreground-service half of the precondition must be '
              'genuinely true, not assumed',
        );

        // Enqueue the already-expired packet only NOW, after the
        // backgrounded+running state is genuinely established -- so its
        // reclaim below can only be the product of a tick that happens
        // AFTER this point.
        final now = DateTime.now();
        await stack.relayEngine.enqueue(
          'device-b',
          Uint8List.fromList([9, 9, 9]),
          0,
          const Duration(seconds: -30), // already expired at insert
        );
        final before = await stack.db.select(stack.db.relayPackets).get();
        expect(before.single.payload, isNotNull);
        expect(
          before.single.expiresAt,
          lessThanOrEqualTo(now.millisecondsSinceEpoch),
        );

        // `_applyPlan()` (triggered above) just rescheduled the timer onto
        // a genuine, unmeasured PRODUCTION cadence value
        // (`background_policy.dart`'s own table, 60-300s) -- waiting for
        // that in real time would make this test take minutes. Speeding
        // up the ALREADY-armed timer is the same test-speed technique
        // `test_EARS_PLAT_12_no_second_timer_created` above already uses;
        // it does not re-establish or fake the backgrounded/running
        // precondition proven above, only how soon the next real firing
        // happens.
        stack.coordinator.setTickInterval(const Duration(milliseconds: 30));

        // Let the real Timer.periodic fire on its own.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final after = await stack.db.select(stack.db.relayPackets).get();
        expect(after.single.deliveryState, RelayDeliveryState.expired.name);
        expect(after.single.payload, isNull);
        expect(stack.coordinator.counters.reclaimed, greaterThanOrEqualTo(1));
      },
    );
  });

  group(
    'test_EARS_PLAT_14_reconcile_runs_once_after_stopped_by_system',
    () {
      setUp(Get.reset);
      tearDown(Get.reset);

      test(
        'a stoppedBySystem event reconciles exactly once, not on every '
        'duplicate event',
        () async {
          final stack = await newStack('device-a', nextSuffix());
          addTearDown(stack.dispose);
          addTearDown(stack.coordinator.stop);

          // Cold-start reconcile (MessagingCoordinator.start()'s own,
          // pre-existing job -- not this task's addition) runs first and is
          // awaited here so the baseline below is deterministic. No crash
          // -window row exists yet, so this reconciles zero.
          await stack.coordinator.start();
          final baseline = stack.coordinator.counters.reconciled;
          expect(baseline, 0);

          final backgroundStub = BackgroundStub();
          AppBinding(
            db: stack.db,
            messagingStack: stack,
            backgroundControl: backgroundStub,
          ).dependencies();
          addTearDown(() => Get.find<BackgroundLifecycleObserver>().stop());

          // Hand-build one crash-window row (E05-T02 review observation 3's
          // shape, same as `messaging_coordinator_test.dart`'s own
          // `test_start_reconciles_the_crash_window_once`): a `Queued`
          // `messages` row whose relay packet was already durably enqueued.
          Future<void> plantCrashWindowMessage(String id, int byte) async {
            final ciphertext = Uint8List.fromList([byte, byte, byte]);
            await stack.db.into(stack.db.messages).insert(
                  MessagesCompanion.insert(
                    id: id,
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
          }

          await plantCrashWindowMessage('m-crash-a', 41);

          // First stoppedBySystem event: the observer's own new call site
          // (this task's only new reconcile trigger -- the cold-start one
          // above already existed) must reconcile this row.
          backgroundStub.simulateStoppedBySystem();
          await Future<void>.delayed(Duration.zero);
          expect(stack.coordinator.counters.reconciled, baseline + 1);
          final afterFirst = await (stack.db.select(stack.db.messages)
                ..where((t) => t.id.equals('m-crash-a')))
              .getSingle();
          expect(afterFirst.deliveryState, DeliveryState.sent.name);

          // Plant a SECOND crash-window row, then fire a DUPLICATE
          // stoppedBySystem event (the state was already `stoppedBySystem`,
          // so this models a spurious repeat, not a genuine new
          // transition). Task file §6 risk: "reconciling on every resume is
          // wasteful" -- if the duplicate were not suppressed, this row
          // would be swept too and the counter would move again.
          await plantCrashWindowMessage('m-crash-b', 42);
          backgroundStub.simulateStoppedBySystem();
          await Future<void>.delayed(Duration.zero);
          expect(
            stack.coordinator.counters.reconciled,
            baseline + 1,
            reason: 'a duplicate stoppedBySystem event must not trigger a '
                'second reconcile pass',
          );
          final stillQueued = await (stack.db.select(stack.db.messages)
                ..where((t) => t.id.equals('m-crash-b')))
              .getSingle();
          expect(stillQueued.deliveryState, DeliveryState.queued.name);
        },
      );
    },
  );
}

/// Mirrors `messaging_coordinator_test.dart`'s own `_ControlledSendTransport`
/// -- a `TransportService` whose `send` blocks on [gate] so a tick can be
/// held deliberately in flight.
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
