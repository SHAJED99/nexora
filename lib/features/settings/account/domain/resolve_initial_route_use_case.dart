// features/settings/account/domain — resolveInitialRoute (E15-T02,
// FR-AUTH-010/011/012).
//
// The ONE place `main()` decides where a launch lands, extending
// `initialRouteFor` (`lib/app/main.dart`, E14-T04/`EARS-VER-10`) rather than
// standing up a second, competing routing decision beside it (task file §2:
// "Two functions deciding one route is how FR-VER-006's block gets
// bypassed by the one that runs first"). Concretely: the `updateRequired`
// branch is not re-implemented here — it is delegated straight to
// `initialRouteFor`, so the exact same already-tested mapping
// (`test_EARS_VER_10_update_required_routes_to_mandatory_screen`) decides
// that branch, unmodified, forever in precedence over the identity check
// below it.
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
  if (versionState == VersionState.updateRequired) {
    // Delegates to the existing, independently-tested mapping — see this
    // file's header comment. `hasLocalIdentity` is deliberately never
    // consulted on this branch (task file §2, step 2): the mandatory-update
    // screen wins regardless of what a local identity read would have said.
    return initialRouteFor(versionState);
  }
  return hasLocalIdentity ? Routes.dashboard : Routes.welcome;
}
