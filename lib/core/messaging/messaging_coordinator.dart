// core/messaging — MessagingCoordinator (E06-T06, closes E05-B02).
//
// Nothing in this codebase has ever called `RelayEngine.processQueue()`,
// `sweepExpired()` or `reclaimPayloads()` in production (E05-B02's own
// exhaustive grep proved it), so a message composed offline queued forever
// and E04-B02's retention guarantee never ran on any schedule. This file is
// the driver that stops that: it is the one component that actually invokes
// those three lifecycle methods, advances `SyncCursorService`'s cursor at
// the point a message is durably stored, appends `delivery_states` rows, and
// discharges `InboundPipeline.start()`'s obligation (deliberately left
// uncalled by E06-T05, per that task's own §4/§5).
//
// **Trigger model — `OQ-E06-T06-1`, resolved 2026-08-29 to option (c).** A
// tick runs immediately on a route/connectivity-change event, AND a
// `Timer.periodic(tickInterval)` floor guarantees `sweepExpired()`/
// `reclaimPayloads()` still run on a schedule even with zero mesh traffic.
// Foreground-only: no `WorkManager`, no foreground service, no wake lock,
// no new dependency, no new Android manifest permission (task file §4 — that
// is E10's scope, not annexed here). With the app closed, nothing forwards
// and nothing reclaims; that is the explicit, named cost of choosing (c)
// over (d) and must be stated in the app's own release notes, not implied
// away.
//
// **The route/connectivity-change half of the trigger, concretely.**
// `RoutingEngine` (E04-T02) exposes no stream of its own — recomputing a
// route is a synchronous, on-demand query (`computeRoute`), not an event
// source. The actual moment "a route might now exist" becomes observable in
// this codebase is at the transport layer: `TransportService
// .discoveredDevices` (a new peer becomes known) and, per already-discovered
// peer, `TransportService.connectionState(id)` settling into `connected`
// (mirrors `InboundPipeline`'s own discovery -> connection-state chain,
// `inbound_pipeline.dart:213-240`, but this coordinator keeps its own
// subscriptions rather than reaching into that file's private state, since
// this task must not modify `InboundPipeline` — task file §4). A tick fires
// on both.
//
// **Tick order is fixed and non-negotiable** (E04-B02's own established
// order, task file §2/§3): `processQueue()` -> `sweepExpired()` ->
// `reclaimPayloads()`. Correctness-neutral but one cycle better for reclaim
// latency (E04-B02's review). Re-entrancy: [tick] returns the SAME in-flight
// `Future` to a caller that arrives while a pass is already running, rather
// than starting a second overlapping pass — a slow pass over a radio must
// never be re-entered by the next trigger (task file §6 risk). [stop] awaits
// that same in-flight future, which is exactly "await an in-flight tick"
// (task file §3) with no separate bookkeeping needed for it.
//
// **`counters.forwarded` is derived, not reported.** `RelayEngine
// .processQueue()` returns `Future<void>` — it does not report how many
// packets it moved (task file §4: this task must not modify `RelayEngine`
// to add one). The only production-safe way to learn "how many packets left
// `queued` because of this pass" without changing that contract is to count
// `queued` rows immediately before and immediately after the call and take
// the drop — a packet only leaves `queued` via a successful forward
// (`RelayEngine._attempt`'s `_setState` to `forwarding`/`delivered`) within
// `processQueue()` itself; `sweepExpired()` and `reclaimPayloads()` run
// afterward in the same pass and are counted separately, so this reads only
// the delta `processQueue()` itself caused.
//
// **`reconcileQueuedMessages()`'s join key.** The crash window this closes
// (E05-T02 review, observation 3) is: `SendMessageUseCase.call` committed a
// `Queued` `messages` row and successfully called `RelayEngine.enqueue`, but
// the process died before the final `Sent` transition. `relay_packets` has
// no `message_id` column (E06-T03's `messaging_stack.dart` header, judgment
// call 2, already establishes why: a relay packet's own `id` is a
// *per-hop* queue-row key, never a wire-level end-to-end identifier, so
// there is no foreign key to join on even in principle). What IS shared
// between the two rows for the exact bytes one `SendMessageUseCase.call`
// produced is the ciphertext itself: `send_message_use_case.dart:288` hands
// `RelayEngine.enqueue` the very same `ciphertext` bytes it just wrote into
// `messages.ciphertext` two lines above. A `Queued` message whose exact
// `ciphertext` also exists as some `relay_packets.payload` is therefore
// provably the message that crashed after a successful enqueue — this is a
// real join, not a heuristic, and needs no schema change (task file §5).
//
// **`delivery_states` writer — `recordStored`.** Appends one row per
// transition the coordinator itself observes: the completed outcome of an
// outbound send (a caller — T11's chat screen, not built here per task file
// §4 UI fence — hands this coordinator `SendMessageUseCase.call`'s result)
// and every inbound delivery (`InboundPipeline.delivered`, subscribed
// automatically in [start]). Never writes `messages.delivery_state`
// directly (task file §3) — that column is `SendMessageUseCase`'s /
// `ReceiveMessageUseCase`'s own, already written through
// `DeliveryStateMachine` (`message.dart:63-64`) before this coordinator ever
// sees the message. [reconcileQueuedMessages] is the one place this
// coordinator DOES write `messages.delivery_state` (there is no other
// component that could ever discover and close that specific crash window),
// and it does so only via `DeliveryStateMachine.transition` — never a raw
// string write — so an illegal transition throws instead of silently
// corrupting the column.
//
// **Never throws.** [recordStored]'s two writes (`SyncCursorService
// .recordLocalProgress` is already documented never-throws, E05-T04; the
// `delivery_states` insert is a local, schema-validated write) are each
// wrapped so a failure here can never fail the message that triggered it
// (task file §6 risk) — the message is already durably stored by the time
// this runs either way.
//
// **Concurrent-caller audit (task file §6 risk — the counter/cursor class,
// recurrence 5).** `SyncCursorService.recordLocalProgress` was E05-T04's own
// lost-update defect (read -> await -> write), already fixed with a single
// guarded upsert statement (`sync_cursor_service.dart:142-171`) whose
// monotonic guard is evaluated by SQLite atomically as part of the same
// statement that performs the write — there is no read-then-write window
// left for two overlapping callers to race through, regardless of how many
// new callers this task adds. This task adds exactly two new call sites
// (outbound via [recordStored], inbound via the `delivered` subscription in
// [start]) that can now genuinely interleave — a message arriving from the
// mesh at the same instant a queued send completes. Audit of every OTHER
// reader of `sync_cursors` (grep -rln "syncCursors|SyncCursors|sync_cursors"
// lib/ — see this task's Run log for the full result): only
// `SyncCursorService` itself and `messaging_stack.dart` (construction only)
// reference the table; no sibling reader derives "next"/"available" from it
// today, so there is nothing else to re-audit (L-backend-003 recurrence
// 1-4's failure mode). The remaining risk is purely the writer's own
// atomicity (recurrence 5's failure mode), which is already closed at the
// SQL-statement level, independent of caller count — proven again here, not
// merely assumed, by `test_EARS_COMM_12_concurrent_stores_do_not_lose_a_cursor_update`
// exercising it through this coordinator's own new call path.
//
// **E08-T06 addition: an optional storage pass, appended after this file's
// existing tick work.** [storageManager] is a public, mutable, nullable
// field -- not a constructor parameter -- deliberately: `MessagingStack
// .create()` (this task's own fence excludes `messaging_stack.dart`, so its
// existing `MessagingCoordinator(...)` construction call cannot change)
// already fully constructs this coordinator before `AppBinding
// .dependencies()` ever runs (E06-T03's composition-root ordering, this
// file's own header above). `AppBinding` sets this field once, after
// building `StorageManager` from the already-registered `AppDatabase`, and
// before calling `coordinator.start()` -- the same "already-built instance,
// registered, never reconstructed" discipline `bindings.dart`'s own header
// already documents for `AppDatabase`/`MessagingStack`. When set, [tick]
// calls `StorageManager.runPass` once per pass, strictly AFTER
// `processQueue`/`sweepExpired`/`reclaimPayloads` (task file §4: no
// reordering of this file's existing tick steps) and inside its own,
// separate try/catch -- a storage-pass failure is isolated from, and can
// never retroactively fail, the messaging work that already completed in
// this same tick (task file §6 risk: "An exception in the storage pass must
// not abort the coordinator tick"; `EARS-STORE-15`).
//
// Does NOT modify `RelayEngine`, `RoutingEngine`, `SendMessageUseCase`,
// `ReceiveMessageUseCase` or `InboundPipeline` (task file §4) — every
// dependency below is called exactly as its own epic left it. Does NOT
// implement Android background execution (E10's scope). Does NOT send
// acknowledgements or advance a message past `Sent` (E06-T08). Does NOT
// implement the multi-device gap-fill protocol (`OQ-E06-T06-2`, deferred to
// E11). Does NOT write `RelayDeliveryState.failed` (`OQ-E06-T06-3`,
// deferred). Does NOT retry, back off, or re-order the relay queue —
// `processQueue()` owns queue semantics; this file owns only *when* it runs.
//
// **E10-T10 addition: `setTickInterval` reschedules the SAME
// `Timer.periodic`, and is the only change this task makes to this file**
// (task file §3/§5). `_tickInterval` is therefore no longer `final` --
// nothing else about `start()`/`tick()`/`stop()` changes shape: no
// reordering of `processQueue`/`sweepExpired`/`reclaimPayloads`, no new
// state, no second driver (`E08-T06.md:119-120`'s refusal, and this file's
// own header above, both still hold). Rescheduling never cancels or awaits
// whichever pass is currently in flight -- `_inFlightTick`'s re-entrancy
// coalescing (this file's header, "Tick order is fixed") is completely
// unaffected by which interval the NEXT timer firing uses.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `relay_engine.dart` and `inbound_pipeline.dart`: the fields are private
// (`_stack`, `_inbound`, ...) while the constructor's public named
// parameters (`stack`, `inbound`, ...) match this task's documented §5
// contract exactly.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../routing_engine/relay_engine.dart';
import '../storage/storage_manager.dart';
import '../transport/transport_service.dart';
import '../../features/messaging/domain/delivery_state_machine.dart';
import '../../features/messaging/domain/message.dart';
import 'inbound_pipeline.dart';
import 'messaging_stack.dart';

/// "Is the loop alive?" without a debugger (task file §5). Mutated only by
/// [MessagingCoordinator] itself.
class CoordinatorCounters {
  /// Number of [MessagingCoordinator.tick] passes that actually ran (i.e.
  /// were not swallowed by the re-entrancy guard).
  int ticks = 0;

  /// Sum, across every tick, of how many `relay_packets` rows left `queued`
  /// as a direct result of that tick's `processQueue()` call (see this
  /// file's header for how this is derived).
  int forwarded = 0;

  /// Sum, across every tick, of `sweepExpired()`'s own return value.
  int swept = 0;

  /// Sum, across every tick, of `reclaimPayloads()`'s own return value.
  int reclaimed = 0;

  /// Number of ticks whose pass threw before completing. The loop itself
  /// never stops because of one (EARS-COMM-13).
  int tickFailures = 0;

  /// Number of ticks whose storage pass (E08-T06 addition) threw. Counted
  /// separately from [tickFailures] since a storage-pass failure must never
  /// be conflated with, or abort, this tick's messaging work
  /// (`EARS-STORE-15`).
  int storagePassFailures = 0;

  /// Total messages moved `queued` -> `sent` by [MessagingCoordinator
  /// .reconcileQueuedMessages] across every call (normally just the one
  /// [MessagingCoordinator.start] makes).
  int reconciled = 0;
}

/// The relay-queue/inbound-pipeline/sync-cursor driver (see this file's
/// header). Exactly one instance drives one [MessagingStack] (task file §3);
/// [MessagingStack.create] constructs and exposes it — see
/// `messaging_stack.dart`.
class MessagingCoordinator {
  MessagingCoordinator({
    required MessagingStack stack,
    required InboundPipeline inbound,
    required Duration tickInterval,
    DateTime Function() clock = DateTime.now,
  })  : _stack = stack,
        _inbound = inbound,
        _tickInterval = tickInterval,
        _clock = clock;

  final MessagingStack _stack;
  final InboundPipeline _inbound;

  /// The current floor between ticks -- mutable ONLY via [setTickInterval]
  /// (E10-T10's whole contribution to this file). Everything else in this
  /// class treats it exactly as before: read once, when `start()` builds the
  /// `Timer.periodic`.
  Duration _tickInterval;
  final DateTime Function() _clock;

  bool _started = false;

  Timer? _timer;

  StreamSubscription<TransportDevice>? _discoverySubscription;

  /// One `connectionState(id)` subscription per device id ever discovered
  /// while running, mirroring `InboundPipeline`'s own leak-avoidance
  /// reasoning (`inbound_pipeline.dart:142-146`) but kept independently —
  /// this task must not reach into that file's private state (§4).
  final Map<String, StreamSubscription<ConnectionState>>
      _connectionSubscriptions = <String, StreamSubscription<ConnectionState>>{};

  StreamSubscription<Message>? _deliveredSubscription;

  /// Non-null exactly while a [tick] pass is running — a second caller that
  /// arrives during that window is handed this SAME future rather than
  /// starting a second, overlapping pass (this file's header: re-entrancy).
  Future<void>? _inFlightTick;

  final CoordinatorCounters counters = CoordinatorCounters();

  /// Set by `AppBinding` after construction (this file's header, E08-T06
  /// addition) -- null until then, and in every test that does not care
  /// about the storage pass. When non-null, [tick] drives it, once per
  /// pass, strictly after this file's existing three messaging steps.
  StorageManager? storageManager;

  /// Begins driving the mesh (task file §3/§5): calls `InboundPipeline
  /// .start()` (E06-T05's obligation, discharged here), subscribes to its
  /// `delivered` stream so every inbound message advances the sync cursor
  /// and gets a `delivery_states` row automatically, opens the
  /// route/connectivity-change event triggers, starts the `tickInterval`
  /// timer floor, and runs [reconcileQueuedMessages] exactly once. Idempotent
  /// — a second call is a no-op (mirrors `InboundPipeline.start()`'s own
  /// idempotency, task file §6 risk: this may be called from a lifecycle
  /// callback that fires more than once).
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _inbound.start();
    _deliveredSubscription = _inbound.delivered.listen((Message message) {
      unawaited(recordStored(message));
    });

    _discoverySubscription =
        _stack.transport.discoveredDevices.listen(_onDeviceDiscovered);
    _timer = Timer.periodic(_tickInterval, (_) => unawaited(tick()));

    await reconcileQueuedMessages();
  }

  /// Cancels every subscription and the timer, awaits any in-flight [tick],
  /// then stops the inbound pipeline (task file §3). Test-only in spirit —
  /// mirrors `InboundPipeline.stop()`'s own "production never calls this"
  /// note — but harmless to call from a real lifecycle teardown too.
  Future<void> stop() async {
    _started = false;

    _timer?.cancel();
    _timer = null;

    await _discoverySubscription?.cancel();
    _discoverySubscription = null;

    for (final subscription in _connectionSubscriptions.values) {
      await subscription.cancel();
    }
    _connectionSubscriptions.clear();

    await _deliveredSubscription?.cancel();
    _deliveredSubscription = null;

    // Await whichever pass is currently running, if any, before handing
    // control back to the caller (task file §3: "cancels everything, awaits
    // an in-flight tick").
    await _inFlightTick;

    await _inbound.stop();
  }

  /// E10-T10: the ONLY change this task makes to this file (task file §3/§5)
  /// -- reschedules the SAME `Timer.periodic` `start()` set up, onto
  /// [interval]. Never adds a second timer, never touches `tick()`'s own
  /// body, ordering or re-entrancy guard. A tick already in flight when this
  /// is called keeps running to completion under the OLD interval's own
  /// firing that started it -- only the NEXT scheduled firing uses the new
  /// interval (task file §5: "a tick in flight is not cancelled").
  ///
  /// A no-op if [interval] already equals the current one (nothing to
  /// reschedule) or if `start()` has not been called yet / `stop()` already
  /// ran (there is no live `Timer` to reschedule -- the value is still
  /// recorded for whenever `start()` next runs).
  void setTickInterval(Duration interval) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(
        interval,
        'interval',
        'must be greater than Duration.zero',
      );
    }
    if (interval == _tickInterval) return;
    _tickInterval = interval;

    if (_timer == null) return;
    _timer!.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => unawaited(tick()));
  }

  void _onDeviceDiscovered(TransportDevice device) {
    if (_connectionSubscriptions.containsKey(device.id)) return;
    _connectionSubscriptions[device.id] = _stack.transport
        .connectionState(device.id)
        .listen((ConnectionState state) {
      if (state == ConnectionState.connected) {
        // A route may now exist that did not a moment ago — tick
        // immediately rather than waiting for the timer floor (this file's
        // header: option (c)'s event-driven half).
        unawaited(tick());
      }
    });
  }

  /// One full pass: `processQueue()` -> `sweepExpired()` ->
  /// `reclaimPayloads()` (E04-B02's established order), never overlapping
  /// with itself. Never throws (EARS-COMM-13) — a failing pass increments
  /// [CoordinatorCounters.tickFailures] and the next trigger still runs a
  /// fresh pass.
  Future<void> tick() {
    final inFlight = _inFlightTick;
    if (inFlight != null) return inFlight;

    final future = _runTick();
    _inFlightTick = future;
    return future;
  }

  Future<void> _runTick() async {
    counters.ticks++;
    try {
      try {
        final beforeQueued = await _countQueued();
        await _stack.relayEngine.processQueue();
        final afterQueued = await _countQueued();
        if (afterQueued < beforeQueued) {
          counters.forwarded += beforeQueued - afterQueued;
        }

        counters.swept += await _stack.relayEngine.sweepExpired();
        counters.reclaimed += await _stack.relayEngine.reclaimPayloads();
      } catch (_) {
        // One bad pass must never kill the loop (EARS-COMM-13) — counted as
        // metadata, never rethrown.
        counters.tickFailures++;
      }

      // E08-T06 addition: appended strictly after the messaging work above
      // (task file §4 — no reordering of processQueue/sweepExpired/
      // reclaimPayloads), in its own try/catch so a storage-pass failure is
      // isolated from — and can never retroactively fail — the messaging
      // work this tick already completed (EARS-STORE-15, task file §6
      // risk).
      final storage = storageManager;
      if (storage != null) {
        try {
          await storage.runPass(nowEpochMs: _clock().millisecondsSinceEpoch);
        } catch (_) {
          counters.storagePassFailures++;
        }
      }
    } finally {
      _inFlightTick = null;
    }
  }

  Future<int> _countQueued() async {
    final row = await (_stack.db.selectOnly(_stack.db.relayPackets)
          ..addColumns([_stack.db.relayPackets.id.count()])
          ..where(_stack.db.relayPackets.deliveryState
              .equals(RelayDeliveryState.queued.name)))
        .getSingle();
    return row.read(_stack.db.relayPackets.id.count()) ?? 0;
  }

  /// Closes E05-T02 review observation 3's crash window (task file §2/§3):
  /// a `messages` row still `queued` whose relay packet was already
  /// durably enqueued (identified by ciphertext equality — see this file's
  /// header for why that, not a foreign key, is the real join here) is
  /// moved to `sent`. Does not re-send, re-encrypt or re-enqueue anything
  /// (task file §3) — the packet is already sitting in `relay_packets`;
  /// only the `messages` row's own stale `queued` state was wrong.
  /// Idempotent: a second call reconciles zero, since a row already moved to
  /// `sent` no longer matches the `queued` filter below.
  Future<int> reconcileQueuedMessages() async {
    final queuedMessages = await (_stack.db.select(_stack.db.messages)
          ..where((t) =>
              t.deliveryState.equals(DeliveryState.queued.name)))
        .get();

    var reconciledCount = 0;
    final now = _clock().millisecondsSinceEpoch;

    for (final message in queuedMessages) {
      final matchingPacket = await (_stack.db.select(_stack.db.relayPackets)
            ..where((t) => t.payload.equals(message.ciphertext))
            ..limit(1))
          .getSingleOrNull();
      if (matchingPacket == null) continue;

      // Validated via DeliveryStateMachine (task file §3) rather than a raw
      // string write — throws (surfacing loudly, not silently corrupting the
      // column) if `queued -> sent` is ever not the legal next state for
      // this row, which today it always is.
      final nextState =
          DeliveryStateMachine.transition(DeliveryState.queued, DeliveryState.sent);

      await (_stack.db.update(_stack.db.messages)
            ..where((t) => t.id.equals(message.id)))
          .write(MessagesCompanion(deliveryState: Value(nextState.name)));

      await _appendDeliveryState(message.id, nextState, now);
      reconciledCount++;
    }

    counters.reconciled += reconciledCount;
    return reconciledCount;
  }

  /// The single store point E05-B02 asked for (task file §3): advances the
  /// sync cursor and appends a `delivery_states` row for [message]'s current
  /// (already-legal, already-applied elsewhere) delivery state. Called
  /// automatically for every inbound delivery (see [start]); the outbound
  /// half is this method's own public contract, for whichever caller (T11's
  /// chat screen, not built here — task file §4 UI fence) hands this
  /// coordinator `SendMessageUseCase.call`'s result. Never throws (task file
  /// §6: a failure here must not fail the message that triggered it).
  Future<void> recordStored(Message message) async {
    try {
      await _stack.syncCursors.recordLocalProgress(
        message.conversationId,
        message.senderDeviceId,
        message.sequenceNumber,
      );
    } catch (_) {
      // SyncCursorService.recordLocalProgress is documented never-throws
      // (E05-T04) — this catch is defensive, not expected to ever fire, but
      // the message must survive regardless (task file §6).
    }

    try {
      await _appendDeliveryState(
        message.id,
        message.deliveryState,
        _clock().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Same contract: a local, schema-validated insert should never throw,
      // but if it somehow does, the message this observed must not be
      // affected by it.
    }
  }

  /// Inserts (or, for the same `(messageId, state)` pair observed twice,
  /// updates the timestamp on) one `delivery_states` row. Never writes
  /// `messages.delivery_state` — that column belongs to whichever use case
  /// already validated and applied the transition via
  /// `DeliveryStateMachine`/`Message.withDeliveryState` before this
  /// coordinator ever sees the message (task file §3), with the single
  /// documented exception of [reconcileQueuedMessages], which is this
  /// coordinator's own transition to make.
  Future<void> _appendDeliveryState(
    String messageId,
    DeliveryState state,
    int changedAtMs,
  ) {
    return _stack.db.into(_stack.db.deliveryStates).insert(
          DeliveryStatesCompanion.insert(
            messageId: messageId,
            state: state.name,
            changedAt: changedAtMs,
          ),
          onConflict: DoUpdate(
            (old) => DeliveryStatesCompanion(changedAt: Value(changedAtMs)),
          ),
        );
  }
}
