// features/version/domain — VersionReconnectWatcher (E14-B06, FR-VER-008).
//
// `FR-VER-008`'s own second half — "on reconnect it shall fetch the current
// policy and re-evaluate" — has no implementation anywhere in this codebase
// (`E14-B01`'s fix explicitly and correctly fenced this out, launch-time
// only). This class is that missing half: a reconnect *event*-driven
// re-check, never a timer/poller (this bug's own "does NOT do" fence).
//
// "Reconnect" here means reconnection to the exact source
// `VersionPolicyService.refresh()` reads from — the Realtime Database
// connection Firebase's own `.info/connected` special path already reports
// (see `FirebasePaths.infoConnected()`'s own doc comment for why this is
// reused rather than a new connectivity primitive/dependency). It does NOT
// mean a mesh-transport reconnect (`TransportService`/`LinkQualityFeed`) —
// that stream reports per-device Bluetooth/WiFi-Direct link state between
// this app and peer devices, an entirely different signal from "can this
// app reach the Firebase project that publishes the version policy".
//
// Scope fence, same as `E14-B01`'s own: this class does NOT change
// `evaluateVersionStateAtLaunch`/`initialRouteFor` in `lib/app/main.dart`,
// does NOT add any polling/`Timer`, and does NOT touch
// `EvaluateVersionStateUseCase`/`VersionPolicyService`/`VersionUpdateView`/
// `VersionUpdateController` — it only composes them, exactly the way
// `main.dart`'s own launch-time path already does, from a different trigger.
//
// `prefer_initializing_formals` is intentionally not applied here, same
// documented exclusion as `evaluate_version_state_use_case.dart`/
// `location_share_service.dart`/`relay_engine.dart`: the constructor's
// public named parameters match this file's own call-shape naming, while
// the fields backing them are prefixed (`_connectivityStream`, etc).
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/version/domain/evaluate_version_state_use_case.dart';
import 'package:nexora/features/version/domain/version_state.dart';

/// Drives a re-check of the version policy on genuine reconnect — a
/// transition from "disconnected" to "connected" on the injected
/// connectivity stream — and, if the fresh evaluation now comes back
/// [VersionState.updateRequired], invokes [onUpdateRequired] so the caller
/// can force navigation.
///
/// [connectivityStream] is injected rather than constructed here (the same
/// seam shape as [CachedPolicyProvider]/[InstalledBuildProvider] elsewhere in
/// this feature) — the real caller (`lib/app/main.dart`) supplies Firebase's
/// own `.info/connected` stream; tests supply a plain
/// `StreamController<bool>`, no platform channel required.
class VersionReconnectWatcher {
  VersionReconnectWatcher({
    required Stream<bool> connectivityStream,
    required VersionPolicyService versionPolicyService,
    required InstalledBuildProvider installedBuildProvider,
    required void Function() onUpdateRequired,
  })  : _connectivityStream = connectivityStream,
        _versionPolicyService = versionPolicyService,
        _installedBuildProvider = installedBuildProvider,
        _onUpdateRequired = onUpdateRequired;

  final Stream<bool> _connectivityStream;
  final VersionPolicyService _versionPolicyService;
  final InstalledBuildProvider _installedBuildProvider;
  final void Function() _onUpdateRequired;

  StreamSubscription<bool>? _subscription;

  /// `null` until the first event arrives. Tracks the raw previous value of
  /// [connectivityStream], updated on every event regardless of whether it
  /// ends up counting as a reconnect.
  bool? _previouslyConnected;

  /// E14-B06 round 2 (F3): whether this watcher has EVER observed a `true`
  /// event. A raw `false -> true` transition test alone is not enough to
  /// avoid duplicating `E14-B01`'s own launch-time check: Firebase's
  /// `.info/connected` characteristically emits `false` first at cold
  /// start (its "not yet connected" initial value) and then `true` once the
  /// socket actually connects -- and that pair, on its own, is textually a
  /// `false -> true` transition even though it is really this stream's
  /// FIRST-EVER successful connection, not a genuine reconnect. Gating on
  /// [_everConnected] means the first `true` this stream ever reports never
  /// counts as a reconnect no matter how many `false` events preceded it
  /// (cold start's `false, true` included) -- only a `true` that follows a
  /// `false` AFTER a connection has already been established once counts.
  /// (The originally shipped version of this file claimed the `null`-seeded
  /// `_previouslyConnected` check above was, on its own, sufficient to avoid
  /// ever duplicating the launch-time check -- that claim was wrong; this
  /// flag is the actual fix.)
  bool _everConnected = false;

  /// Serializes overlapping `_onConnectivityChanged` runs so two rapid
  /// reconnect events cannot both be mid-`refresh()`/evaluate at once —
  /// `_previouslyConnected` is only updated synchronously per event, but the
  /// `await`s inside the handler mean a second event could otherwise start
  /// its own refresh/evaluate/navigate before the first one finishes.
  Future<void> _pending = Future<void>.value();

  /// Subscribes to [connectivityStream]. Idempotent-adjacent: calling this
  /// twice without [stop] in between would leak a subscription, same as
  /// `BackgroundLifecycleObserver.start()` — callers are expected to call it
  /// once, mirroring that class's own contract.
  void start() {
    _subscription = _connectivityStream.listen(_onConnectivityChanged);
  }

  /// Cancels the subscription. Safe to call even if [start] was never
  /// called, or was already stopped.
  void stop() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _onConnectivityChanged(bool connected) {
    final isReconnect =
        connected && _everConnected && _previouslyConnected == false;
    if (connected) _everConnected = true;
    _previouslyConnected = connected;
    if (!isReconnect) return;

    // E14-B06 round 2 (F1): a rejection here used to propagate straight
    // into `_pending`'s own Future, so every SUBSEQUENT `.then` in this
    // chain short-circuited without ever running `_reevaluate()` again --
    // one failed re-evaluation would silently and permanently kill this
    // watcher for the rest of the session, with no logging anywhere.
    // `catchError` keeps the chain alive (the awaited `_pending` Future
    // always resolves, never rejects) so one failure degrades to "this one
    // reconnect's re-check was skipped", not "no reconnect check ever runs
    // again".
    _pending = _pending.then((_) => _reevaluate()).catchError((
      Object e,
      StackTrace st,
    ) {
      ObservabilityService.instance.logError(
        'version.reconnect_reevaluation_failed',
        cause: e,
      );
    });
  }

  /// `refresh()` then re-evaluate, exactly `main.dart`'s own
  /// `evaluateVersionStateAtLaunch` composition (`EvaluateVersionStateUseCase`
  /// over `VersionPolicyService.cached`) — reused, not re-implemented, so a
  /// regression in either stays a single-place fix. `refresh()` is already
  /// best-effort, timeout-bounded and never-throwing (`EARS-VER-4`), so a
  /// reconnect event that turns out to still have no real connectivity (a
  /// flaky transition) degrades to a no-op re-check, never a hang or crash.
  Future<void> _reevaluate() async {
    await _versionPolicyService.refresh();
    final evaluateVersionState = EvaluateVersionStateUseCase(
      cachedPolicyProvider: _versionPolicyService.cached,
      installedBuildProvider: _installedBuildProvider,
    );
    final state = await evaluateVersionState.call();
    if (state == VersionState.updateRequired) {
      _onUpdateRequired();
    }
  }
}
