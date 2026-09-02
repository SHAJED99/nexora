// core/calls — make-before-break call route migration (E07-T11,
// FR-CALL-003).
//
// ⛔ **Read the task file's own header first.** This is the CONTROL half of
// make-before-break only. It drives `RoutingEngine.considerMigration` on a
// timer, validates a candidate with a real round-trip probe, switches, and
// only then tears down the old route — and it drives the `CallMediaTransport`
// seam through the exact same sequence a real media transport will one day
// implement. It does NOT carry audio, does NOT choose a media transport, and
// with today's `NullCallMediaTransport` every migration correctly stops at
// the media-attach step and stays on the old route — the honest v1 outcome
// while `OQ-E07-3` is open (`OQ-E07-12`), not a bug.
//
// **The contractual sequence (task file §5, binding, not reorderable):**
//   `considerMigration -> noteAttemptedRoute -> probe -> echo received ->
//   setActiveRoute -> media.attach(new) -> health live -> media.detach(old)`
//
// **This controller is a caller, never a re-implementer, of E04's/E07-T10's
// logic** (task file §4): `RoutingEngine.considerMigration` already applies
// its own improvement-ratio threshold and its own consecutive-sample
// stability rule (both TUNABLE, owned by E04) -- this file adds no second
// heuristic, no hysteresis of its own, and no "force migrate" API. Neither
// that ratio's literal value nor a second window-length constant is ever
// re-declared anywhere under this directory (task file §9's own self-review
// grep check for exactly that).
//
// **Every failure path resolves to "stay on the current route" and NEVER
// ends the call** (task file §3/§6/§8 EARS-CALL-10) -- probe timeout, media
// attach failure, and a stop()/candidate-lost race mid-switch are all
// caught, counted, and abandoned via `CallSession.recordMigrationEvent`,
// never via `CallSession.endLocally`. `RoutingEngine.setActiveRoute` is
// called once the probe echo is received (per the contractual order above,
// BEFORE the media steps); if a media step subsequently fails, this
// controller compensates by calling `RoutingEngine.setActiveRoute` again
// with the OLD route, so the routing engine's own idea of "active" ends up
// exactly where it started (task file §3: "leave the active route exactly
// as it was") even though the ordered sequence put the switch before the
// media check.
//
// **Route failure is a different, mandatory path** (FR-ROUTE-009, task file
// §2/§4): `notifyRouteFailure` delegates straight to
// `RoutingEngine.onRouteFailure` and does not run any part of the migration
// sequence above -- conflating the two is exactly the mistake the task file
// calls out ("how an opportunistic optimisation ends up in the crash path").
//
// **Only one migration in flight at a time** (task file §3/§6): a timer tick
// (or a direct `evaluateOnce()` call) that lands while a migration is
// already running is dropped, not queued -- see `_migrationInFlight`.
//
// **A late echo must never be applied** (task file §6): `_awaitProbeEcho`
// cancels its `CallSignaling.pathProbeEchoes` subscription the instant its
// own bounded timeout fires, so an echo arriving after that instant is never
// observed by this controller at all, regardless of what a stray listener
// elsewhere might do with it.
import 'dart:async';

import '../routing_engine/route_cost_calculator.dart' show TrafficProfile;
import '../routing_engine/routing_engine.dart';
import 'call_session.dart';
import 'call_signaling.dart';

/// The result of one migration evaluation (task file §5) -- exposed so a
/// test can drive the sequence deterministically via [CallMigrationController.evaluateOnce]
/// instead of waiting on the timer.
enum MigrationOutcome {
  /// `considerMigration` returned `stay()`, or a migration was already in
  /// flight and this tick was dropped (task file §3/§6).
  stayed,

  /// A candidate was found but its validation probe never echoed within
  /// [CallMigrationController.probeTimeout].
  probeFailed,

  /// The probe validated, the route switched, but the media transport could
  /// not attach the candidate (or never reported it live).
  mediaFailed,

  /// The full ordered sequence completed: the call is now on the new route
  /// and the old one has been detached.
  migrated,
}

/// Drives FR-CALL-003's make-before-break sequence for one [CallSession]
/// (task file §1/§3). Constructed once per call attempt, [start]ed when the
/// session reaches [CallState.active], [stop]ped on `ending`/`ended` (either
/// by the caller or automatically -- see [start]'s own doc comment).
class CallMigrationController {
  CallMigrationController({
    required this.routing,
    required this.signaling,
    required this.media,
    this.tickInterval = const Duration(seconds: 1),
    this.probeTimeout = const Duration(milliseconds: 1500),
  });

  final RoutingEngine routing;
  final CallSignaling signaling;
  final CallMediaTransport media;

  /// How often [evaluateOnce] is driven from [start]'s own timer. Injected,
  /// never a literal at a call site (task file §5, the
  /// `MessagingStack.coordinatorTickInterval` pattern). Also sets the
  /// real-world width of `RoutingEngine`'s own consecutive-sample stability
  /// window (a public constant on that class, not re-declared here), since
  /// that engine counts `considerMigration` *calls*, not wall-clock time
  /// (task file §2's own note).
  final Duration tickInterval;

  /// How long [evaluateOnce] waits for a candidate's probe echo before
  /// abandoning the attempt (task file §5). Injected, never a literal.
  final Duration probeTimeout;

  // -- Counters (task file §3) --------------------------------------------
  int callMigrationAttempted = 0;
  int callMigrationProbeTimeout = 0;
  int callMigrationMediaFailed = 0;
  int callMigrationCompleted = 0;
  int callMigrationAbandoned = 0;

  Timer? _timer;
  CallSession? _session;
  StreamSubscription<CallState>? _stateSub;
  bool _migrationInFlight = false;

  /// Bumped every time [stop] runs, and captured at the start of every
  /// [evaluateOnce] call -- the seam that lets an in-flight probe/media wait
  /// notice it has been superseded (by `stop()`, e.g. the call ending mid-
  /// migration) and abandon quietly rather than applying a decision the
  /// controller has already moved on from (task file §6: "candidate lost
  /// mid-switch").
  int _generation = 0;

  /// Starts driving migration for [session] (task file §3: "started when a
  /// `CallSession` reaches `active`"). Also seeds `RoutingEngine`'s notion of
  /// the active route for this destination via `RoutingEngine.setActiveRoute`
  /// -- task file §6's own named silent-no-op trap:
  /// `RoutingEngine.considerMigration` requires an active route already
  /// registered (`_activeRoutes[destinationId]`) or it always returns
  /// `stay()`, so without this call migration would never trigger and every
  /// test would pass vacuously. Automatically [stop]s itself once [session]
  /// reaches `ending`/`ended`, so a caller that forgets to call [stop]
  /// explicitly still never leaks the timer.
  void start(CallSession session) {
    _session = session;
    final seed = routing.computeRoute(session.peerDeviceId, TrafficProfile.realtime);
    if (seed != null) {
      routing.setActiveRoute(seed);
      session.recordActiveRoute(seed);
    }
    _timer = Timer.periodic(tickInterval, (_) {
      unawaited(evaluateOnce());
    });
    _stateSub = session.states.listen((state) {
      if (state == CallState.ending || state == CallState.ended) {
        unawaited(stop());
      }
    });
  }

  /// The completer backing whichever of [_awaitProbeEcho]/[_awaitMediaLive]
  /// is currently waiting, if any -- [stop] completes it early (`false`) so
  /// an in-flight probe/health wait is actually cancelled immediately
  /// rather than merely being left to run out its own timeout naturally
  /// (task file §5: "cancels the timer and every in-flight probe", not
  /// "makes the timer's eventual result get ignored").
  Completer<bool>? _pendingWait;

  /// Cancels the timer and every in-flight probe (task file §5) -- safe to
  /// call twice, and safe to call while [evaluateOnce] is mid-flight:
  /// bumping [_generation] makes the in-flight `evaluateOnce` notice it has
  /// been superseded once its (now-completed-early) wait resolves, and
  /// abandon without touching the route or the session.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _stateSub?.cancel();
    _stateSub = null;
    _generation++;
    _migrationInFlight = false;
    final pending = _pendingWait;
    if (pending != null && !pending.isCompleted) {
      pending.complete(false);
    }
  }

  /// Delegates a "the active route failed outright" signal straight to
  /// `RoutingEngine.onRouteFailure` (FR-ROUTE-009) -- task file §2/§4: this
  /// is the mandatory break-then-make recovery path, entirely distinct from
  /// this controller's own optional, opportunistic migration sequence, and
  /// this controller never reimplements it. Updates
  /// [CallSession.activeRoute] to match if a next route was found; does
  /// nothing to [CallSession.migrations] -- a route failure is not a
  /// migration attempt.
  Route? notifyRouteFailure() {
    final session = _session;
    if (session == null) return null;
    final next = routing.onRouteFailure(session.peerDeviceId);
    if (next != null) {
      session.recordActiveRoute(next);
    }
    return next;
  }

  /// Runs exactly one evaluation of the make-before-break sequence (task
  /// file §5) -- exposed so a test can drive it deterministically instead of
  /// waiting on [start]'s timer. A tick that lands while a migration is
  /// already in flight is dropped, not queued (task file §3/§6): returns
  /// [MigrationOutcome.stayed] immediately without calling
  /// `considerMigration` again.
  Future<MigrationOutcome> evaluateOnce() async {
    final session = _session;
    if (session == null || _migrationInFlight) {
      return MigrationOutcome.stayed;
    }

    // Step 1: considerMigration -- E04's own decision, never re-implemented
    // here (task file §2/§4).
    final decision = routing.considerMigration(
      session.peerDeviceId,
      TrafficProfile.realtime,
    );
    if (decision is! MigrationDecisionMigrateTo) {
      return MigrationOutcome.stayed;
    }
    final candidate = decision.route;
    // `considerMigration` only ever returns `migrateTo` when an active route
    // is already registered for this destination (RoutingEngine's own
    // contract) -- so this is always non-null in this branch.
    final oldRoute = routing.activeRouteFor(session.peerDeviceId)!;

    _migrationInFlight = true;
    final myGeneration = ++_generation;
    try {
      // Step 2: noteAttemptedRoute -- records the candidate as "currently
      // being transmitted over" WITHOUT implying a validated switch yet
      // (E04-B01's own distinction; see `routing_engine.dart`'s doc comment
      // on that method).
      routing.noteAttemptedRoute(candidate);
      callMigrationAttempted++;
      session.recordMigrationEvent(CallMigrationAttempted(candidate));

      // Steps 3-4: probe -> echo received. "Validate means a packet made
      // the round trip on the candidate route, not that the route was
      // computed" (task file §2).
      final echoed = await _awaitProbeEcho(session);
      if (_superseded(myGeneration)) return MigrationOutcome.stayed;
      if (!echoed) {
        callMigrationProbeTimeout++;
        return _abandon(session, 'probeTimeout', MigrationOutcome.probeFailed);
      }
      session.recordMigrationEvent(CallMigrationValidated(candidate));

      // Step 5: setActiveRoute -- per the contractual order this happens
      // BEFORE the media steps. If a media step below fails, this
      // controller compensates by restoring `oldRoute` so RoutingEngine's
      // own bookkeeping ends up exactly where it started (this file's own
      // header note).
      routing.setActiveRoute(candidate);

      // Step 6: media.attach(new).
      final attachFailure = await media.attach(session);
      if (_superseded(myGeneration)) return MigrationOutcome.stayed;
      if (attachFailure != null) {
        routing.setActiveRoute(oldRoute);
        callMigrationMediaFailed++;
        return _abandon(session, 'mediaFailed', MigrationOutcome.mediaFailed);
      }

      // Step 7: await CallMediaHealth.live.
      final live = await _awaitMediaLive(myGeneration);
      if (_superseded(myGeneration)) return MigrationOutcome.stayed;
      if (!live) {
        routing.setActiveRoute(oldRoute);
        callMigrationMediaFailed++;
        return _abandon(session, 'mediaFailed', MigrationOutcome.mediaFailed);
      }

      // Step 8: media.detach(old) -- only now, with the new route proven
      // live, is the old route torn down (task file §2/§6's named #1 risk).
      await media.detach();
      session.recordActiveRoute(candidate);
      callMigrationCompleted++;
      session.recordMigrationEvent(CallMigrationCompleted(candidate));
      return MigrationOutcome.migrated;
    } finally {
      _migrationInFlight = false;
    }
  }

  /// `true` once [stop] has run since [myGeneration] was captured -- the
  /// call has ended, or another `stop()`/`start()` cycle has superseded
  /// this in-flight attempt. An evaluation that notices this abandons
  /// silently: it must not touch the route or emit an event for a decision
  /// nobody is listening for any more (task file §6: "candidate lost
  /// mid-switch").
  bool _superseded(int myGeneration) => myGeneration != _generation;

  MigrationOutcome _abandon(
    CallSession session,
    String reason,
    MigrationOutcome outcome,
  ) {
    callMigrationAbandoned++;
    session.recordMigrationEvent(CallMigrationAbandoned(reason));
    return outcome;
  }

  /// Sends the validation probe and waits for its echo, bounded by
  /// [probeTimeout] (task file §5/§6). The subscription to
  /// `CallSignaling.pathProbeEchoes` is cancelled the instant this method
  /// returns -- by either the echo arriving or the timeout firing -- so an
  /// echo that arrives after this method has already returned `false` is
  /// never observed by this controller (task file §6's named risk: "a late
  /// echo applied after the controller moved on will switch the route out
  /// from under a completed decision").
  Future<bool> _awaitProbeEcho(CallSession session) async {
    final sent = await signaling.sendPathProbe(session.callId, session.peerDeviceId);
    if (!sent) return false;

    final completer = Completer<bool>();
    _pendingWait = completer;
    final sub = signaling.pathProbeEchoes.listen((callId) {
      if (callId == session.callId && !completer.isCompleted) {
        completer.complete(true);
      }
    });
    final timer = Timer(probeTimeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await sub.cancel();
      if (identical(_pendingWait, completer)) {
        _pendingWait = null;
      }
    }
  }

  /// Waits for [CallMediaHealth.live] on [media]'s own health stream,
  /// bounded by [probeTimeout] (task file §5: "await `CallMediaHealth.live`").
  /// The listener is attached BEFORE this method is ever reached (see
  /// [evaluateOnce]'s call to `media.attach` immediately prior) is not
  /// actually required here since `attach`'s own `Future` has already
  /// resolved by this point and a real transport is expected to report
  /// health asynchronously afterwards; a synchronous `NullCallMediaTransport`
  /// emission that happened during `attach` itself would be missed by a
  /// broadcast stream with no listener yet, but `NullCallMediaTransport`
  /// never emits `live` at all, so that ordering detail cannot hide a false
  /// positive for the one shipped implementation. A fake transport used in
  /// tests that emits `live` synchronously inside `attach` before this
  /// listener attaches must instead emit it asynchronously (e.g. via a
  /// microtask or `Timer.run`) for this method to observe it -- documented
  /// on the fake in the test file.
  Future<bool> _awaitMediaLive(int myGeneration) async {
    final completer = Completer<bool>();
    _pendingWait = completer;
    final sub = media.health.listen((health) {
      if (health == CallMediaHealth.live && !completer.isCompleted) {
        completer.complete(true);
      }
    });
    final timer = Timer(probeTimeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await sub.cancel();
      if (identical(_pendingWait, completer)) {
        _pendingWait = null;
      }
    }
  }
}
