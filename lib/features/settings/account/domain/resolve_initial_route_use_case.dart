// features/settings/account/domain — resolveInitialRoute (E15-T02,
// FR-AUTH-010/011/012).
//
// The ONE place `main()` decides where a launch lands, extending
// `initialRouteFor` (`lib/app/main.dart`, E14-T04/`EARS-VER-10`) rather than
// standing up a second, competing routing decision beside it (task file §2:
// "Two functions deciding one route is how FR-VER-006's block gets
// bypassed by the one that runs first"). Concretely: this function asks
// `initialRouteFor` for the DECISION, not merely a constant — see below —
// so a future `VersionState` value `initialRouteFor` treats as blocking is
// automatically respected here too, without this file's own `if` needing to
// be updated to recognise it. Review round 2 (F2): an earlier version of
// this function re-implemented the `updateRequired` predicate itself
// (`if (versionState == VersionState.updateRequired) return
// initialRouteFor(versionState)`) — only the destination constant was
// delegated, the condition for reaching it was duplicated. That shape is
// harmless today (there are only three `VersionState` values, see
// `version_state.dart`), but the moment a fourth blocking state is added,
// `initialRouteFor` would correctly block it while the duplicated `==
// updateRequired` check here would not, silently routing that new blocking
// state to `/dashboard` — exactly the two-functions-deciding-one-route
// bypass this task file's own §2 warns against. The fix below asks
// `initialRouteFor` what it decided and only falls through to the identity
// check when `initialRouteFor` itself chose `Routes.welcome` — its own
// non-blocking default — so the two functions cannot disagree about
// whether a given `VersionState` blocks, only about what a non-blocking
// state routes to next.
//
// Pure and synchronous on purpose (task file §6 "the one-line-edit trap" /
// risk row 1): any async work this decision might look like it needs
// (completing a pending wipe, reading whether a local identity exists) is
// main()'s own responsibility, run and resolved to a plain `bool` BEFORE
// this function is ever called — never hidden inside an `await` in here,
// where it could silently race ahead of (or behind) the update-required
// check.
import 'package:nexora/app/main.dart' show initialRouteFor;
import 'package:nexora/app/routes.dart';
import 'package:nexora/features/version/domain/version_state.dart';

/// FR-AUTH-010 (skip to dashboard when an identity exists), FR-AUTH-012
/// (welcome when it does not), FR-AUTH-011 (never ahead of the mandatory
/// -update block, FR-VER-006) — one order-fixed, side-effect-free decision.
///
/// [hasLocalIdentity] must already reflect "unreadable identity treated as
/// no identity" (task file §6 risk row 2) — this function itself never
/// reads or awaits anything, so it cannot itself distinguish "no identity"
/// from "identity unreadable"; that distinction is main()'s own job, before
/// this is called.
String resolveInitialRoute({
  required VersionState versionState,
  required bool hasLocalIdentity,
}) {
  // Delegates the DECISION, not just the destination constant — see this
  // file's header comment (review round 2, F2). `initialRouteFor` returns
  // its own non-blocking default (`Routes.welcome`) for every
  // [VersionState] it does not treat as blocking; only when it returns that
  // exact default does this function go on to consult `hasLocalIdentity`.
  // Any OTHER value `initialRouteFor` might ever return — today only
  // `Routes.versionUpdateRequired`, but not re-checked by name here — is
  // returned as-is, unmodified and un-second-guessed, so a future blocking
  // `VersionState` added to `initialRouteFor` is honoured here automatically.
  final versionRoute = initialRouteFor(versionState);
  if (versionRoute != Routes.welcome) return versionRoute;
  // `hasLocalIdentity` is deliberately never consulted above (task file §2,
  // step 2): the mandatory-update screen (or any future blocking state)
  // wins regardless of what a local identity read would have said.
  return hasLocalIdentity ? Routes.dashboard : Routes.welcome;
}
