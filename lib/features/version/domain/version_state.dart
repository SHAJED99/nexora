// features/version/domain — VersionState (E14-T02, FR-VER-005).
//
// The one closed set `EvaluateVersionStateUseCase` produces. Stored by
// `.name` per `docs/conventions.md` "Enums" — this is an in-memory-only
// value with no persistence in this task (task file §3), noted for
// whichever later task, if any, ever stores it.
library;

/// The three states `FR-VER-005` names, in ascending severity order:
/// [upToDate] < [updateAvailable] < [updateRequired].
enum VersionState {
  /// Installed build is at or above both thresholds — nothing to do.
  upToDate,

  /// Installed build is below `updateAvailableBuild` but at or above
  /// `minimumSupportedBuild` — an update exists but is not mandatory.
  updateAvailable,

  /// Installed build is below `minimumSupportedBuild` — the app must not
  /// be allowed to keep running unpatched (enforcement is `E14-T04`'s own
  /// concern; this task only names the state).
  updateRequired,
}
