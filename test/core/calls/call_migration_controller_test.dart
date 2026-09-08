// Tests for CallMigrationController (E07-T11, FR-CALL-003, EARS-CALL-1/9/10/11).
//
// **Harness choice, and why.** `CallMigrationController`'s contract (task
// file §5) requires a CONCRETE `CallSignaling`, not an interface -- so every
// test here backs it with a real (throwaway, single-device, never wired to
// any transport) `MessagingStack`, but overrides `CallSignaling.sendPathProbe`
// / `.pathProbeEchoes` on a small subclass (`_FakeSignaling`, neither method
// is private nor final) so the probe/echo round trip is deterministic and
// fast, with no real crypto session or mocked Pigeon channel needed. This
// mirrors `call_signaling_test.dart`'s own documented "purely local" harness
// choice for scenarios where the interesting behaviour does not require a
// real two-device wire round trip -- here, that behaviour is entirely
// `CallMigrationController`'s own sequencing, which is agnostic to how the
// probe bytes actually travel. `CallSignalingFrame`'s wire encoding of the
// two new kinds this task adds is still exercised for real: (a) the round
// trip test below, and (b) `call_signaling_test.dart`'s own pre-existing
// `'every kind round-trips to its own tag'` test iterates `CallSignalKind.values`,
// so it automatically covers `pathProbe`/`pathProbeEcho` too, with zero edits
// to that file (out of this task's `files:` fence).
//
// `RoutingEngine`/`CallMediaTransport` are never re-implemented or re-tuned
// here (task file §4) -- `_RecordingRoutingEngine` only overrides four
// methods to append markers to a shared order log, then delegates to `super`
// for the real E04 decision logic every time; `_RecordingCallMediaTransport`
// is a fresh, fully test-owned implementation of the abstract seam E07-T09
// already defines, exactly as `NullCallMediaTransport` is.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/calls/call_migration_controller.dart';
import 'package:nexora/core/calls/call_session.dart';
import 'package:nexora/core/calls/call_signaling.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';

/// Records `considerMigration` (only when it actually decides to migrate --
/// otherwise the stability-window warm-up calls would flood every order
/// assertion with noise), `noteAttemptedRoute`, `setActiveRoute` and
/// `onRouteFailure` into [log], then always delegates to `super` for the
/// real E04 decision -- never reimplements or re-tunes it (task file §4).
class _RecordingRoutingEngine extends RoutingEngine {
  _RecordingRoutingEngine({required super.selfId, this.log});

  final List<String>? log;

  @override
  MigrationDecision considerMigration(
    String destinationId,
    TrafficProfile profile,
  ) {
    final result = super.considerMigration(destinationId, profile);
    if (result is MigrationDecisionMigrateTo) {
      log?.add('considerMigration');
    }
    return result;
  }

  @override
  void noteAttemptedRoute(Route route) {
    log?.add('noteAttemptedRoute');
    super.noteAttemptedRoute(route);
  }

  @override
  void setActiveRoute(Route route) {
    log?.add('setActiveRoute');
    super.setActiveRoute(route);
  }

  @override
  Route? onRouteFailure(String destinationId, TrafficProfile profile) {
    log?.add('onRouteFailure');
    return super.onRouteFailure(destinationId, profile);
  }
}

/// A test-owned `CallMediaTransport` (E07-T09's seam) that records
/// `attach`/`detach` order and can be configured to fail or to never report
/// [CallMediaHealth.live] -- the two shapes EARS-CALL-10 requires every test
/// to attack. By default `live` is emitted via a real [Timer], never
/// [scheduleMicrotask] and never synchronously inside [attach] itself --
/// this is a deliberate CHOICE for the "happy path" tests, not a
/// requirement of the controller's own contract: since the E07-B03/O1 fix,
/// the health-live subscription is set up BEFORE `attach` is even called,
/// so a transport emitting synchronously (see [emitLiveSynchronouslyInsideAttach])
/// is now correctly observed too -- see the dedicated O1 test for that
/// case specifically.
class _RecordingCallMediaTransport implements CallMediaTransport {
  _RecordingCallMediaTransport({
    this.log,
    this.attachFails = false,
    this.emitsLive = true,
    this.liveDelay = const Duration(milliseconds: 5),
    this.emitLiveSynchronouslyInsideAttach = false,
    this.attachGate,
  });

  final List<String>? log;
  final bool attachFails;
  final bool emitsLive;
  final Duration liveDelay;

  /// E07-B03 (review finding O3): when set, [attach] awaits this completer
  /// before returning -- lets a test hold `evaluateOnce` paused exactly at
  /// step 6, so it can call [CallMigrationController.stop] mid-flight and
  /// assert the resulting `stayed` outcome correctly restores the OLD
  /// route rather than leaving `RoutingEngine` pointed at the candidate.
  final Completer<void>? attachGate;

  /// E07-B03 (review finding O1): when `true`, [CallMediaHealth.live] is
  /// added to [health] SYNCHRONOUSLY, before [attach] ever returns --
  /// exactly the ordering a real transport might use, and exactly the case
  /// that used to be silently lost when the controller only subscribed to
  /// [health] AFTER `attach`'s own `Future` had already resolved.
  final bool emitLiveSynchronouslyInsideAttach;

  int attachCalls = 0;
  int detachCalls = 0;

  /// E07-B03 (review finding O2): the exact [Route] each call passed --
  /// lets a test prove the candidate/old-route identity is threaded
  /// through explicitly rather than inferred from `session.activeRoute`
  /// (which still holds the OLD route at attach time, by design).
  final List<Route?> attachedRoutes = [];
  final List<Route?> detachedRoutes = [];
  final StreamController<CallMediaHealth> _healthController =
      StreamController<CallMediaHealth>.broadcast();

  @override
  Future<AppFailure?> attach(CallSession session, Route? route) async {
    attachCalls++;
    attachedRoutes.add(route);
    log?.add('mediaAttach');
    final gate = attachGate;
    if (gate != null) await gate.future;
    if (attachFails) {
      return const AppFailure('media.fake_attach_failed');
    }
    if (emitLiveSynchronouslyInsideAttach) {
      log?.add('healthLive');
      _healthController.add(CallMediaHealth.live);
    } else if (emitsLive) {
      Timer(liveDelay, () {
        if (_healthController.isClosed) return;
        log?.add('healthLive');
        _healthController.add(CallMediaHealth.live);
      });
    }
    return null;
  }

  @override
  Future<void> detach(Route? route) async {
    detachCalls++;
    detachedRoutes.add(route);
    log?.add('mediaDetach');
  }

  @override
  Stream<CallMediaHealth> get health => _healthController.stream;

  Future<void> dispose() => _healthController.close();
}

/// A `CallSignaling` subclass overriding only [sendPathProbe]/
/// [pathProbeEchoes] (task file §5's own `CallSignaling.sendPathProbe`/
/// `pathProbeEchoes` are ordinary public methods, not private or final) so
/// the probe/echo round trip is deterministic and needs no real crypto
/// session or transport -- see this file's header. The echo, like
/// [_RecordingCallMediaTransport]'s `live` event, is emitted via a real
/// [Timer] rather than synchronously, so a `probeTimeout` shorter than
/// [echoDelay] genuinely times out instead of racing a same-tick delivery.
class _FakeSignaling extends CallSignaling {
  _FakeSignaling({required super.stack, this.log});

  final List<String>? log;
  final List<String> sentProbeCallIds = [];
  bool sendSucceeds = true;
  bool autoEcho = true;
  Duration echoDelay = const Duration(milliseconds: 5);

  final StreamController<String> _echoController =
      StreamController<String>.broadcast();

  @override
  Future<bool> sendPathProbe(String callId, String peerDeviceId) async {
    sentProbeCallIds.add(callId);
    log?.add('probeSent');
    if (sendSucceeds && autoEcho) {
      Timer(echoDelay, () {
        if (_echoController.isClosed) return;
        _echoController.add(callId);
      });
    }
    return sendSucceeds;
  }

  @override
  Stream<String> get pathProbeEchoes => _echoController.stream;

  Future<void> dispose() => _echoController.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var dbCounter = 0;

  Future<MessagingStack> newThrowawayStack() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftSignalProtocolStore(db);
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'device-a-${dbCounter++}',
      store: store,
      cryptoService: CryptoService.withStore(store),
    );
    return stack;
  }

  /// A bare, [CallState.active] session never tracked by any `CallSignaling`
  /// -- constructed directly, exactly like `call_session_test.dart`'s own
  /// helpers, so nothing in E07-T09's `_track`/`NullCallMediaTransport`
  /// machinery (a completely different, unrelated seam from this
  /// controller's own `media` parameter) can end it out from under a test.
  CallSession activeSession({
    String callId = 'call-1',
    String peerDeviceId = 'device-b',
  }) {
    final session = CallSession(
      callId: callId,
      peerDeviceId: peerDeviceId,
      isOutgoing: true,
      clock: DateTime.now,
    );
    session.onEvent(CallSignalKind.invite);
    session.onEvent(CallSignalKind.accept);
    expect(session.state, CallState.active);
    return session;
  }

  /// Seeds a direct A->B link (the route that will become "active" once
  /// [CallMigrationController.start] seeds it) that is clearly worse than a
  /// two-hop A->C->B path -- >20% cheaper even under `realtime`'s hop-count
  /// weight (task file §2), so `considerMigration` reliably decides
  /// `migrateTo` once its stability window is satisfied.
  void seedWorseDirectRoute(RoutingEngine routing) {
    routing.recordLinkMeasurement(
      'device-b',
      latencyMs: 500,
      lossRate: 0.6,
      batteryDrain: 0.5,
    );
  }

  void seedBetterTwoHopRoute(RoutingEngine routing) {
    routing.recordLinkMeasurement(
      'device-c',
      latencyMs: 5,
      lossRate: 0.0,
      batteryDrain: 0.1,
    );
    routing.recordLinkMeasurement(
      'device-b',
      latencyMs: 5,
      lossRate: 0.0,
      batteryDrain: 0.1,
      from: 'device-c',
    );
  }

  /// Runs `evaluateOnce()` [RoutingEngine.kMigrationStabilityTicks] - 1
  /// times (each must return `stayed` -- the candidate has not yet held its
  /// advantage long enough) before the caller's own decisive call. Asserts
  /// each warm-up call actually stayed, so a mistake in the seeded topology
  /// (e.g. the candidate isn't actually >=20% cheaper) fails loudly here
  /// rather than producing a confusing failure on the decisive call.
  Future<void> warmUpStabilityWindow(CallMigrationController controller) async {
    for (var i = 0; i < RoutingEngine.kMigrationStabilityTicks - 1; i++) {
      final outcome = await controller.evaluateOnce();
      expect(
        outcome,
        MigrationOutcome.stayed,
        reason: 'warm-up call ${i + 1} should not have migrated yet',
      );
    }
  }

  group('CallSignalingFrame serialization (E07-T11)', () {
    test(
        'pathProbe and pathProbeEcho round-trip through serialize/deserialize',
        () {
      for (final kind in [
        CallSignalKind.pathProbe,
        CallSignalKind.pathProbeEcho,
      ]) {
        final frame = CallSignalingFrame(
          kind: kind,
          callId: 'call-xyz',
          fromDeviceId: 'device-a',
          createdAtMs: 42,
        );
        final decoded = CallSignalingFrame.deserialize(frame.serialize());
        expect(decoded.kind, kind);
        expect(decoded.callId, 'call-xyz');
        expect(decoded.fromDeviceId, 'device-a');
        expect(decoded.createdAtMs, 42);
      }
    });
  });

  group('test_EARS_CALL_1 -- make-before-break ordering', () {
    test('test_EARS_CALL_1_migration_completes_in_the_contract_order',
        () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final order = <String>[];
      final routing = _RecordingRoutingEngine(selfId: 'device-a', log: order);
      final signaling = _FakeSignaling(stack: stack, log: order);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport(log: order);
      addTearDown(media.dispose);
      final echoLogSub =
          signaling.pathProbeEchoes.listen((_) => order.add('echoReceived'));
      addTearDown(echoLogSub.cancel);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 200),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);

      await warmUpStabilityWindow(controller);
      order.clear();

      final outcome = await controller.evaluateOnce();

      expect(outcome, MigrationOutcome.migrated);
      expect(order, [
        'considerMigration',
        'noteAttemptedRoute',
        'probeSent',
        'echoReceived',
        'setActiveRoute',
        'mediaAttach',
        'healthLive',
        'mediaDetach',
      ]);
    });

    test(
        'test_EARS_CALL_1_old_route_is_still_attached_until_the_new_one_is_live',
        () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final order = <String>[];
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport(log: order, liveDelay: const Duration(milliseconds: 30));
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 500),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);

      final outcome = await controller.evaluateOnce();

      expect(outcome, MigrationOutcome.migrated);
      // `detach` must never be recorded before `healthLive` -- the old route
      // stays attached for the whole window while the new one is unproven.
      expect(order.indexOf('mediaDetach'), greaterThan(order.indexOf('healthLive')));
      expect(media.attachCalls, 1);
      expect(media.detachCalls, 1);
    });

    test(
        'test_E07_B03_attach_and_detach_carry_the_correct_route_identity_not_session_activeRoute',
        () async {
      // Review finding O2: `attach`/`detach` must be told exactly which
      // route to bring up/tear down -- `session.activeRoute` cannot serve
      // this purpose, since at the moment `attach` is called for the
      // CANDIDATE, `session.activeRoute` still holds the OLD route (it is
      // only updated after the new route is proven live, by design).
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport();
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 500),
      );
      addTearDown(controller.stop);
      controller.start(session);
      // `start()` seeds the direct one-hop route as active -- capture it
      // before the candidate ever exists, so this test compares against
      // the REAL old route rather than assuming its shape.
      final oldRoute = routing.activeRouteFor('device-b')!;
      expect(oldRoute.hops, ['device-b']);

      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);
      final outcome = await controller.evaluateOnce();
      expect(outcome, MigrationOutcome.migrated);

      final candidate = routing.activeRouteFor('device-b')!;
      expect(candidate.hops, ['device-c', 'device-b']);
      expect(candidate, isNot(oldRoute));

      // The whole point of O2: attach got the CANDIDATE, detach got the
      // OLD route -- neither one guessed from `session.activeRoute`,
      // which at attach time still held `oldRoute` (proof: `activeRoute`
      // wasn't updated to `candidate` until AFTER this migration
      // completed, per `evaluateOnce`'s own step 8, well after `attach`
      // was called at step 6).
      expect(media.attachedRoutes, [candidate]);
      expect(media.detachedRoutes, [oldRoute]);
    });

    test(
        'test_E07_B03_a_health_live_event_emitted_synchronously_inside_attach_is_not_lost',
        () async {
      // Review finding O1: before this fix, the health-live subscription
      // was only ever attached AFTER `media.attach`'s own `Future` had
      // already resolved. A real transport that reports `live`
      // SYNCHRONOUSLY inside `attach` -- entirely plausible for whichever
      // implementation eventually answers `OQ-E07-3` -- would be missed by
      // a broadcast stream with no listener yet, and the migration would
      // time out even though media genuinely came up.
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport(
        emitLiveSynchronouslyInsideAttach: true,
      );
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        // Short enough that, without the O1 fix, this test would time out
        // and report `mediaFailed` rather than hang -- a fast, deterministic
        // falsification signal instead of a slow one.
        probeTimeout: const Duration(milliseconds: 200),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);

      final outcome = await controller.evaluateOnce();

      expect(outcome, MigrationOutcome.migrated);
      expect(media.detachCalls, 1);
    });

    test(
        'test_E07_B03_stop_landing_mid_attach_restores_the_old_route',
        () async {
      // Review finding O3: `setActiveRoute(candidate)` runs at step 5,
      // BEFORE the media steps -- so a `stop()` (call ending mid-migration)
      // landing while `media.attach` is still in flight must restore
      // `oldRoute`, exactly like the sibling `attachFailure != null`
      // branch already does. Before this fix, this exact branch silently
      // left `RoutingEngine` pointed at a candidate route nobody validated
      // as actually live.
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack);
      addTearDown(signaling.dispose);
      final attachGate = Completer<void>();
      final media = _RecordingCallMediaTransport(attachGate: attachGate);
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(seconds: 5),
      );
      controller.start(session);
      final oldRoute = routing.activeRouteFor('device-b')!;

      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);

      // Don't await yet -- evaluateOnce() is now paused inside
      // media.attach(), with `routing.setActiveRoute(candidate)` (step 5)
      // already applied.
      final outcomeFuture = controller.evaluateOnce();
      // `_FakeSignaling`'s own default `echoDelay` (5ms) must elapse before
      // the probe echo arrives and step 5/6 run.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(media.attachCalls, 1, reason: 'attach must be in flight now');
      expect(
        routing.activeRouteFor('device-b'),
        isNot(oldRoute),
        reason: 'step 5 already switched to the candidate',
      );

      // The call ends mid-migration.
      await controller.stop();
      attachGate.complete();
      final outcome = await outcomeFuture;

      expect(outcome, MigrationOutcome.stayed);
      expect(
        routing.activeRouteFor('device-b'),
        oldRoute,
        reason: 'O3: a stop() landing here must restore the old route, '
            'not leave RoutingEngine pointed at an unvalidated candidate',
      );
    });

    test('test_EARS_CALL_1_call_state_stays_active_across_a_migration',
        () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport();
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 200),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);

      expect(session.state, CallState.active);
      final outcome = await controller.evaluateOnce();
      expect(outcome, MigrationOutcome.migrated);
      expect(session.state, CallState.active);
      expect(session.activeRoute?.hops, ['device-c', 'device-b']);
    });
  });

  group('test_EARS_CALL_9 -- probe validation', () {
    test('test_EARS_CALL_9_probe_timeout_means_no_setActiveRoute', () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final order = <String>[];
      final routing = _RecordingRoutingEngine(selfId: 'device-a', log: order);
      final signaling = _FakeSignaling(stack: stack)..autoEcho = false;
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport();
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);
      final routeBefore = routing.activeRouteFor('device-b');
      order.clear();

      final events = <CallMigrationEvent>[];
      final sub = session.migrations.listen(events.add);
      addTearDown(sub.cancel);

      final outcome = await controller.evaluateOnce();
      // Broadcast-stream events added synchronously/near-synchronously to
      // an `await`-resuming caller are not guaranteed delivered to a
      // listener by the time that `await` resolves -- the SAME "pump the
      // event queue" note E07-T09's own run log already recorded for this
      // codebase's broadcast-stream tests. `pumpEventQueue()`, not a single
      // microtask/`Future.delayed`, is what actually drains it.
      await pumpEventQueue();

      expect(outcome, MigrationOutcome.probeFailed);
      expect(order, isNot(contains('setActiveRoute')));
      expect(routing.activeRouteFor('device-b'), routeBefore);
      expect(controller.callMigrationProbeTimeout, 1);
      expect(controller.callMigrationAbandoned, 1);
      expect(events.whereType<CallMigrationAbandoned>().single.reason,
          'probeTimeout');
      expect(session.state, CallState.active);
    });

    test('test_EARS_CALL_9_late_echo_after_timeout_is_ignored', () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack)
        ..echoDelay = const Duration(milliseconds: 150);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport();
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);
      final routeBefore = routing.activeRouteFor('device-b');

      final outcome = await controller.evaluateOnce();
      expect(outcome, MigrationOutcome.probeFailed);

      // The echo the fake scheduled at construction time (150ms) has not
      // arrived yet (probeTimeout was only 30ms) -- wait past it now and
      // confirm it changed nothing: no late setActiveRoute, no media attach,
      // no second migration event, no crash.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(routing.activeRouteFor('device-b'), routeBefore);
      expect(media.attachCalls, 0);
      expect(session.state, CallState.active);

      // The controller must still be usable afterwards -- a late echo must
      // not leave any internal state stuck. `considerMigration`'s own
      // stability counter restarted from 1 the moment it returned
      // `migrateTo` for the first attempt (RoutingEngine's own contract), so
      // the very next call correctly reports `stayed` again rather than
      // hanging or throwing -- proof the controller is not wedged.
      final secondOutcome = await controller.evaluateOnce();
      expect(secondOutcome, MigrationOutcome.stayed);
    });
  });

  group('test_EARS_CALL_10 -- media attachment failure', () {
    test('test_EARS_CALL_10_media_attach_failure_leaves_the_old_route_active',
        () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport(attachFails: true);
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 200),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);
      final routeBefore = routing.activeRouteFor('device-b');

      final events = <CallMigrationEvent>[];
      final sub = session.migrations.listen(events.add);
      addTearDown(sub.cancel);

      final outcome = await controller.evaluateOnce();
      await pumpEventQueue();

      expect(outcome, MigrationOutcome.mediaFailed);
      // Compensated back -- RoutingEngine's own "active route" ends up
      // exactly where it started, even though `setActiveRoute(candidate)`
      // ran earlier in the contractual sequence (this file's own header).
      expect(routing.activeRouteFor('device-b'), routeBefore);
      expect(media.detachCalls, 0);
      expect(controller.callMigrationMediaFailed, 1);
      expect(controller.callMigrationAbandoned, 1);
      expect(events.whereType<CallMigrationAbandoned>().single.reason,
          'mediaFailed');
      expect(session.state, CallState.active);
    });

    test('test_EARS_CALL_10_null_media_transport_never_migrates', () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack);
      addTearDown(signaling.dispose);
      final media = NullCallMediaTransport();

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 200),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);
      final routeBefore = routing.activeRouteFor('device-b');

      final outcome = await controller.evaluateOnce();

      // `NullCallMediaTransport.attach` always fails and never emits `live`
      // (task file §2, §8) -- the controller must stay on the old route
      // rather than migrating blind, and the call must not end (E07-T11's
      // correction to `NullCallMediaTransport`: it no longer ends the
      // session itself -- see that class's own doc comment).
      expect(outcome, MigrationOutcome.mediaFailed);
      expect(routing.activeRouteFor('device-b'), routeBefore);
      expect(session.state, CallState.active);
      expect(session.endReason, isNull);
    });

    test('test_EARS_CALL_10_no_failure_path_ends_the_call', () async {
      Future<void> runScenario(
        String label,
        _RecordingCallMediaTransport Function() buildMedia, {
        bool stopMidFlight = false,
        bool autoEcho = true,
      }) async {
        final stack = await newThrowawayStack();
        final routing = _RecordingRoutingEngine(selfId: 'device-a');
        final signaling = _FakeSignaling(stack: stack)..autoEcho = autoEcho;
        final media = buildMedia();

        seedWorseDirectRoute(routing);
        final session = activeSession();
        final controller = CallMigrationController(
          routing: routing,
          signaling: signaling,
          media: media,
          tickInterval: const Duration(hours: 1),
          probeTimeout: const Duration(milliseconds: 30),
        );
        controller.start(session);
        seedBetterTwoHopRoute(routing);
        await warmUpStabilityWindow(controller);

        if (stopMidFlight) {
          final future = controller.evaluateOnce();
          await Future<void>.delayed(const Duration(milliseconds: 2));
          await controller.stop();
          final outcome = await future;
          expect(outcome, MigrationOutcome.stayed, reason: label);
        } else {
          final outcome = await controller.evaluateOnce();
          expect(outcome, isNot(MigrationOutcome.migrated), reason: label);
        }

        expect(session.state, CallState.active, reason: label);
        expect(session.endReason, isNull, reason: label);

        await controller.stop();
        await signaling.dispose();
        await media.dispose();
        await stack.dispose();
      }

      await runScenario(
        'probe never echoes',
        () => _RecordingCallMediaTransport(),
        autoEcho: false,
      );
      await runScenario(
        'media attach fails',
        () => _RecordingCallMediaTransport(attachFails: true),
      );
      await runScenario(
        'media attaches but never reports live',
        () => _RecordingCallMediaTransport(emitsLive: false),
      );
      await runScenario(
        'candidate lost mid-switch (stop() during an in-flight migration)',
        () => _RecordingCallMediaTransport(
          liveDelay: const Duration(milliseconds: 500),
        ),
        stopMidFlight: true,
      );
    });
  });

  group('test_EARS_CALL_11 -- route failure delegation', () {
    test('test_EARS_CALL_11_route_failure_delegates_to_on_route_failure',
        () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final order = <String>[];
      final routing = _RecordingRoutingEngine(selfId: 'device-a', log: order);
      final signaling = _FakeSignaling(stack: stack, log: order);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport(log: order);
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      seedBetterTwoHopRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
      );
      addTearDown(controller.stop);
      controller.start(session);
      order.clear();

      final next = controller.notifyRouteFailure();

      // Delegates straight to `RoutingEngine.onRouteFailure` -- never the
      // migration sequence (task file §2/§4): no probe, no media touch, no
      // `noteAttemptedRoute`/`setActiveRoute` of this controller's own.
      expect(order, ['onRouteFailure']);
      expect(signaling.sentProbeCallIds, isEmpty);
      expect(media.attachCalls, 0);
      expect(next, isNotNull);
      expect(session.activeRoute, next);
    });
  });

  group('serialization / concurrency invariants', () {
    test('test_only_one_migration_in_flight', () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack)
        ..echoDelay = const Duration(milliseconds: 60);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport(
        liveDelay: const Duration(milliseconds: 5),
      );
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 500),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);
      await warmUpStabilityWindow(controller);

      final first = controller.evaluateOnce();
      // A tick landing while the first migration is still in flight must be
      // dropped, not queued (task file §3/§6).
      final second = await controller.evaluateOnce();
      expect(second, MigrationOutcome.stayed);

      final firstOutcome = await first;
      expect(firstOutcome, MigrationOutcome.migrated);
      expect(signaling.sentProbeCallIds.length, 1);
    });

    test('test_stability_window_is_the_engines_not_a_second_one', () async {
      final stack = await newThrowawayStack();
      addTearDown(stack.dispose);
      final routing = _RecordingRoutingEngine(selfId: 'device-a');
      final signaling = _FakeSignaling(stack: stack);
      addTearDown(signaling.dispose);
      final media = _RecordingCallMediaTransport();
      addTearDown(media.dispose);

      seedWorseDirectRoute(routing);
      final session = activeSession();
      final controller = CallMigrationController(
        routing: routing,
        signaling: signaling,
        media: media,
        tickInterval: const Duration(hours: 1),
        probeTimeout: const Duration(milliseconds: 200),
      );
      addTearDown(controller.stop);
      controller.start(session);
      seedBetterTwoHopRoute(routing);

      // Fewer than `kMigrationStabilityTicks` evaluations of a genuinely
      // better candidate must never migrate -- proof this controller adds
      // no threshold or hysteresis of its own (task file §4's own grep
      // check: `grep -n "0.20\|StabilityTicks" lib/core/calls/` must return
      // zero hits).
      for (var i = 0; i < RoutingEngine.kMigrationStabilityTicks - 1; i++) {
        expect(await controller.evaluateOnce(), MigrationOutcome.stayed);
      }
      expect(await controller.evaluateOnce(), MigrationOutcome.migrated);
    });
  });
}
