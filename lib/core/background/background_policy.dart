// core/background — E10-T10: the whole adaptive-cadence decision, pure and
// unit-testable (ADR-0007, FR-PLAT-002, NFR-BATT-001).
//
// `BackgroundPolicy.plan` is a pure function from the three signals this
// epic already made observable -- `PowerState` (E10-T09), `ServiceState`
// (E10-T08) and Flutter's own `AppLifecycleState` -- to a `BackgroundPlan`.
// No I/O, no platform channel, no Timer: every number here is a proposal a
// human reviewer checks against the task file's own §5 table, not a
// measurement (`NFR-BATT-001` stays `[NEEDS NUMBER]` -- see that table's own
// header). Applying the plan (setting the coordinator's tick interval,
// gating discovery) is `lib/app/bindings.dart`'s job, not this file's.
//
// Cadence table (task file §5) -- most-restrictive condition wins when
// several hold:
//   foreground                                  -> 60s  / discovery yes
//   background, service running, screen on      -> 60s  / discovery yes
//   background, screen locked                    -> 120s / discovery yes
//   Battery Saver on                              -> 300s / discovery NO
//   Doze (deviceIdle)                             -> 300s / discovery NO
//   background restricted                         -> 300s / discovery NO
//   service stoppedBySystem                       -> foreground value / NO
//                                                     if Battery
//                                                     Saver/Doze/restricted
//                                                     also holds, else yes
//                                                     (E10-B02: corrected --
//                                                     `stoppedBySystem` means
//                                                     the foreground service
//                                                     died, NOT that the
//                                                     process/tick stopped;
//                                                     the Dart isolate and
//                                                     its tick survive, so
//                                                     discovery must still
//                                                     honour the restricted
//                                                     band)
import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'generated/background_api.g.dart' show ServiceState;
import 'power_state.dart';

/// The whole cadence decision (task file §5): how long the coordinator's
/// existing `Timer.periodic` should wait between ticks, and whether peer
/// discovery should run at all right now.
class BackgroundPlan {
  const BackgroundPlan({
    required this.tickInterval,
    required this.discoveryAllowed,
  });

  final Duration tickInterval;
  final bool discoveryAllowed;

  @override
  bool operator ==(Object other) =>
      other is BackgroundPlan &&
      other.tickInterval == tickInterval &&
      other.discoveryAllowed == discoveryAllowed;

  @override
  int get hashCode => Object.hash(tickInterval, discoveryAllowed);

  @override
  String toString() =>
      'BackgroundPlan(tickInterval: $tickInterval, discoveryAllowed: $discoveryAllowed)';
}

/// `BackgroundPolicy.plan` -- the ONLY place the cadence table lives (task
/// file §3: "The cadence table lives here and nowhere else").
class BackgroundPolicy {
  BackgroundPolicy._();

  /// E06-T06's human-endorsed foreground floor -- unchanged by this task
  /// (task file §4: "Does NOT change the 60 s foreground floor").
  static const Duration foregroundInterval = Duration(seconds: 60);

  /// Background, screen locked, otherwise unrestricted.
  static const Duration screenLockedInterval = Duration(seconds: 120);

  /// Battery Saver, Doze, or a per-app background restriction -- the most
  /// restrictive band. Every one of these three numbers is an unmeasured,
  /// conservative default (task file §5's own header) -- the human can
  /// change any one of them in this one table.
  static const Duration restrictedInterval = Duration(seconds: 300);

  /// Pure function from `(power, service, lifecycle)` to a [BackgroundPlan].
  /// No I/O -- fully unit-testable (task file §3/§5).
  static BackgroundPlan plan({
    required PowerState power,
    required ServiceState service,
    required AppLifecycleState lifecycle,
  }) {
    // Battery Saver / Doze / background-restricted -- the most restrictive
    // band for DISCOVERY, evaluated up front so it can never be bypassed by
    // the `stoppedBySystem` branch below (E10-B02, route (a)):
    // `stoppedBySystem` means the *foreground service* died -- the Dart
    // isolate, and the tick that fires inside it, are still alive (that is
    // the only reason this observer can ever see the event at all:
    // `ForegroundMeshService.onDestroy` -> `emitState` -> `eventsApi` ->
    // `BackgroundLifecycleObserver._onServiceStateChanged`). The system is
    // most likely to have killed the service BECAUSE Doze/Battery Saver/an
    // OEM background restriction is active, so this is precisely the moment
    // discovery must not turn the radio on.
    final bool restricted =
        power.powerSaveMode || power.deviceIdle || power.backgroundRestricted;

    // "service stoppedBySystem -> foreground value" (task file §5 table) --
    // checked next because it overrides the *interval* decided by every
    // other condition: there is no foreground service left to throttle, so
    // proposing a slower interval here would only slow down the in-process
    // foreground timer for no reason. `discoveryAllowed` is NOT
    // unconditional, though (E10-B02) -- it still honours the restricted
    // band computed above.
    if (service == ServiceState.stoppedBySystem) {
      return BackgroundPlan(
        tickInterval: foregroundInterval,
        discoveryAllowed: !restricted,
      );
    }

    if (restricted) {
      return const BackgroundPlan(
        tickInterval: restrictedInterval,
        discoveryAllowed: false,
      );
    }

    // "background, screen locked" -- next most restrictive of the remaining
    // rows. Foreground-with-screen-locked is not a real Android state (the
    // app cannot be resumed while the screen is locked), so gating this on
    // `lifecycle != resumed` matches the table without inventing a case the
    // table never lists.
    final bool backgrounded = lifecycle != AppLifecycleState.resumed;
    if (backgrounded && power.screenLocked) {
      return const BackgroundPlan(
        tickInterval: screenLockedInterval,
        discoveryAllowed: true,
      );
    }

    // "foreground" and "background, service running, screen on" share the
    // same row (task file §5 table) -- both are the unrestricted 60s floor.
    return const BackgroundPlan(
      tickInterval: foregroundInterval,
      discoveryAllowed: true,
    );
  }
}
