// EARS-VER-20 (FR-VER-010) — emergency minimum-version enforcement.
//
// FR-VER-010 is the RETROACTIVE half of version enforcement: publishing a
// higher `minimumSupportedBuild` must mark builds that were previously fine as
// unsupported, without the device itself changing. That is the lever for
// forcing users off a build with a known vulnerability.
//
// `EARS-VER-6` already covers the STATIC evaluation (a build below the minimum
// reads `updateRequired`). It does not cover the transition, which is the part
// FR-VER-010 actually specifies: the same installed build, evaluated twice
// against two policies, must change verdict. A static check passes even in an
// implementation that only ever reads a fixed policy, so it cannot prove the
// emergency lever works.
//
// Both providers are injected fakes, matching
// `evaluate_version_state_use_case_test.dart`'s existing harness.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/version/domain/evaluate_version_state_use_case.dart';
import 'package:nexora/features/version/domain/version_state.dart';

VersionPolicy _policy({
  required int minimumSupportedBuild,
  required int updateAvailableBuild,
}) {
  return VersionPolicy(
    minimumSupportedBuild: minimumSupportedBuild,
    currentBuild: updateAvailableBuild,
    updateAvailableBuild: updateAvailableBuild,
    signature: 'unverified-in-this-test',
    updatedAt: 0,
  );
}

void main() {
  group('EvaluateVersionStateUseCase — emergency minimum enforcement', () {
    test(
      'test_EARS_VER_20_raising_the_minimum_retroactively_marks_a_previously_'
      'supported_build_unsupported',
      () async {
        // One device, one unchanging installed build.
        const installedBuild = 42;

        // The policy the device has cached today: build 42 is at both
        // thresholds, so it is fully up to date. Nothing to prompt.
        var policy = _policy(minimumSupportedBuild: 40, updateAvailableBuild: 42);

        final useCase = EvaluateVersionStateUseCase(
          // Re-read on every call, so raising the minimum below is observed
          // exactly the way a `refresh()` between launches would surface it.
          cachedPolicyProvider: () async => policy,
          installedBuildProvider: () async => installedBuild,
        );

        expect(
          await useCase.call(),
          VersionState.upToDate,
          reason: 'build 42 is at both thresholds before the emergency bump',
        );

        // The emergency: a vulnerability is found in build 42 and the
        // publisher raises the floor above it. The DEVICE has not changed.
        policy = _policy(minimumSupportedBuild: 43, updateAvailableBuild: 43);

        expect(
          await useCase.call(),
          VersionState.updateRequired,
          reason: 'FR-VER-010: raising minimumSupportedBuild above an already '
              'installed build must retroactively mark it unsupported — not '
              'merely updateAvailable, which is dismissible',
        );
      },
    );

    test(
      'test_EARS_VER_20_an_emergency_bump_outranks_the_update_available_'
      'threshold',
      () async {
        // Guards the ordering inside `call()`: if the `updateAvailableBuild`
        // comparison were evaluated first, an emergency bump would degrade to
        // a dismissible "update available" prompt and the vulnerable build
        // would keep running. The minimum must win.
        const installedBuild = 10;

        final useCase = EvaluateVersionStateUseCase(
          cachedPolicyProvider: () async =>
              _policy(minimumSupportedBuild: 20, updateAvailableBuild: 99),
          installedBuildProvider: () async => installedBuild,
        );

        expect(
          await useCase.call(),
          VersionState.updateRequired,
          reason: 'below BOTH thresholds must read updateRequired, never the '
              'softer updateAvailable',
        );
      },
    );
  });
}
