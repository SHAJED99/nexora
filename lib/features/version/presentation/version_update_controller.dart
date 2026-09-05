// features/version/presentation — VersionUpdateController (E14-T04,
// FR-VER-006/FR-VER-007).
//
// The mandatory-update screen's one action: start the platform's Google
// Play in-app update "Immediate Update" flow (task file §5's one function,
// `startImmediateUpdate()`).
//
// **Blocked dependency (task file §2/§6, rule 3 🧍 `new_dependency`):** the
// real Immediate Update flow needs the `in_app_update` package (or
// equivalent) — there is no first-party Flutter binding for the Google Play
// in-app update API in this project today, and adding one to `pubspec.yaml`
// is a human gate this task has no authority to clear unilaterally. Rather
// than block this controller's own logic on that gate, the actual platform
// call is taken as an injected [ImmediateUpdateLauncher] — the same shape
// `EvaluateVersionStateUseCase` (E14-T02) already uses for its own
// `InstalledBuildProvider`/`CachedPolicyProvider` — so this file's own
// behaviour (start the flow, log+swallow a failure, never crash, never
// navigate away) is fully built and tested now. Whichever task wires a real
// `in_app_update`-backed launcher in supplies it here and is the one that
// must clear the `pubspec.yaml` gate — not this task, and not silently. See
// this task's `## Open Questions` for the exact blocking detail.
import 'package:get/get.dart';
import 'package:nexora/core/observability/observability_service.dart';

/// Starts the platform's Immediate Update flow. Injected/stubbed — see this
/// file's header comment.
typedef ImmediateUpdateLauncher = Future<void> Function();

class VersionUpdateController extends GetxController {
  // `prefer_initializing_formals` intentionally not applied here, matching
  // `EvaluateVersionStateUseCase`'s own documented exclusion (this task's
  // required context) — `launcher` is this constructor's public call-shape
  // name (task file §5 `startImmediateUpdate()`'s own doc), while the field
  // stays underscore-prefixed.
  VersionUpdateController({required ImmediateUpdateLauncher launcher})
      // ignore: prefer_initializing_formals
      : _launcher = launcher;

  final ImmediateUpdateLauncher _launcher;

  /// Task file §5's one function signature. A failure is logged
  /// (`ObservabilityService`) and swallowed — this screen has no other
  /// affordance, so the user's only option after a failure is to tap
  /// `Update now` again; there is nothing else for this controller to do.
  Future<void> startImmediateUpdate() async {
    try {
      await _launcher();
    } catch (e) {
      ObservabilityService.instance.logError(
        'version_update.immediate_update_failed',
        cause: e,
      );
    }
  }
}
