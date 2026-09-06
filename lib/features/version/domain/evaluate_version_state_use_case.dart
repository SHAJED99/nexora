// features/version/domain — EvaluateVersionStateUseCase (E14-T02,
// FR-VER-005, FR-VER-010).
//
// Turns `E14-T01`'s cached `VersionPolicy` plus the installed build number
// into one of the three `VersionState` values — pure domain logic, deciding
// nothing about UI or enforcement (task file §1).
//
// `FR-VER-010` (emergency retroactive enforcement) needs no special code
// here: this use case is stateless and re-derives the answer from whatever
// policy is cached every time [call] runs, so a fresh
// `minimumSupportedBuild` re-fetched via `E14-T01`'s `refresh()` makes a
// previously `upToDate` build re-evaluate as `updateRequired` on the very
// next evaluation "for free" (task file §2).
//
// Scope fence (task file §4): this use case does NOT call `refresh()` —
// only the already-cached policy is read; deciding when to refresh is
// `E14-T04`'s own wiring concern. It does NOT render UI or decide what
// happens in each state (`E14-T04`'s own job). It does NOT verify
// `VersionPolicy.signature` — `E14-T05`'s own task. It does NOT persist
// `VersionState` anywhere — derived fresh on every call, by design.
//
// Installed-build-number reader (task file §3/§6 Risks): at execution time
// this codebase has NO existing build-number-reading mechanism —
// `package_info_plus` appears only as a *transitive* dependency (pulled in
// by another package) in `pubspec.lock`, never declared directly in
// `pubspec.yaml`, and nothing under `lib/` imports `package_info_plus` or
// calls `PackageInfo`. Adding it as a direct dependency to read the
// installed build number here would be a new `pubspec.yaml` entry — a 🧍
// `new_dependency` human gate this task has no authority to clear
// silently.
//
// Rather than block this use case's own pure logic on that gate, the
// installed build number is taken as an injected, stubbed provider
// ([installedBuildProvider]) instead of being read internally — the same
// shape as [cachedPolicyProvider] below, which is `E14-T01`'s
// `VersionPolicyService.cached` passed in by the caller, not called
// directly here. Whichever task wires a live caller (`E14-T04`) supplies a
// real implementation of [installedBuildProvider] then, and is the one
// that must raise the `new_dependency` gate for `package_info_plus` (or an
// equivalent) at that point — not this task, and not silently.
//
// `prefer_initializing_formals` is intentionally not applied here, matching
// the same documented exclusion already used by
// `location_share_service.dart`/`call_signaling.dart`/
// `prekey_exchange.dart`/`relay_engine.dart` — the field names are
// prefixed (`_cachedPolicyProvider`/`_installedBuildProvider`) while the
// constructor's public named parameters match this file's documented call
// shape (`cachedPolicyProvider`/`installedBuildProvider`).
// ignore_for_file: prefer_initializing_formals
library;

import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/version/domain/version_state.dart';

/// Reads the currently cached version policy, or `null` if [refresh] has
/// never once succeeded. In practice this is `VersionPolicyService.cached`
/// (E14-T01), passed by the caller — this use case never constructs a
/// `VersionPolicyService` itself, keeping it a pure function of its inputs.
typedef CachedPolicyProvider = Future<VersionPolicy?> Function();

/// Reads the installed build number. Stubbed/injected deliberately — see
/// this file's header comment: no build-number-reading mechanism exists
/// yet in this codebase, and adding one is a 🧍 `new_dependency` gate for
/// whichever task wires a real implementation in.
///
/// `E14-B03` (`OQ-E14-B03-1`, resolved 2026-09-06): `null` is a real,
/// distinguishable outcome — "the installed build number could not be
/// read/parsed" — never smuggled through a sentinel `int` (the bug's own
/// finding: a `1 << 62` sentinel inside a normal-looking `int` return is
/// exactly what let a read failure silently fail OPEN unnoticed). [call]
/// below treats `null` as failing CLOSED whenever a policy is cached to
/// evaluate against.
typedef InstalledBuildProvider = Future<int?> Function();

/// `FR-VER-005`'s one pure decision point: `UP_TO_DATE` /
/// `UPDATE_AVAILABLE` / `UPDATE_REQUIRED`, driven by comparing the
/// installed build number against the cached policy's
/// `minimumSupportedBuild` and `updateAvailableBuild` (task file §2, exact
/// precedence order).
class EvaluateVersionStateUseCase {
  EvaluateVersionStateUseCase({
    required CachedPolicyProvider cachedPolicyProvider,
    required InstalledBuildProvider installedBuildProvider,
  })  : _cachedPolicyProvider = cachedPolicyProvider,
        _installedBuildProvider = installedBuildProvider;

  final CachedPolicyProvider _cachedPolicyProvider;
  final InstalledBuildProvider _installedBuildProvider;

  /// Applies the precedence rule (task file §2):
  /// 1. installed build < `minimumSupportedBuild` → [VersionState.updateRequired]
  /// 2. installed build < `updateAvailableBuild` → [VersionState.updateAvailable]
  /// 3. otherwise → [VersionState.upToDate]
  ///
  /// No cached policy at all (a fresh install that has never reached
  /// Firebase) → [VersionState.upToDate], fail-open by design (`EARS-VER-9`,
  /// `FR-VER-008`'s "offline use" framing) — the installed build number is
  /// never even read in that case. This precedent does NOT extend to an
  /// unreadable build number below — see the next paragraph
  /// (`E14-B03`/`OQ-E14-B03-1`).
  ///
  /// If a policy IS cached but [installedBuildProvider] cannot produce a
  /// build number — it resolves `null`, or its Future rejects — the result
  /// is [VersionState.updateRequired], never [VersionState.upToDate]
  /// (`E14-B03`, `OQ-E14-B03-1`, resolved 2026-09-06: "we could not read our
  /// own build number" is not the same claim as "we have never heard a
  /// policy", and under `FR-VER-010` — an emergency bump because the
  /// running build is unsafe — a device that cannot read its own build
  /// number is exactly the device that should not get the benefit of the
  /// doubt). The provider's Future is awaited inside its own `try` so a
  /// throwing injected provider degrades to the same fail-closed outcome as
  /// one that returns `null` cleanly, rather than crashing launch.
  ///
  /// Comparison is numeric (`int` vs `int`), never lexicographic —
  /// `"9" < "10"` is false as strings (task file §6 Risks).
  Future<VersionState> call() async {
    final policy = await _cachedPolicyProvider();
    if (policy == null) return VersionState.upToDate;

    int? installedBuild;
    try {
      installedBuild = await _installedBuildProvider();
    } catch (_) {
      installedBuild = null;
    }

    if (installedBuild == null) {
      return VersionState.updateRequired;
    }
    if (installedBuild < policy.minimumSupportedBuild) {
      return VersionState.updateRequired;
    }
    if (installedBuild < policy.updateAvailableBuild) {
      return VersionState.updateAvailable;
    }
    return VersionState.upToDate;
  }
}
