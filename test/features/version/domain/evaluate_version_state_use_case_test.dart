// EARS-VER-6..9 (FR-VER-005, FR-VER-008) — E14-T02.
//
// Both providers are injected fakes: [CachedPolicyProvider] stands in for
// `VersionPolicyService.cached` (E14-T01) and [InstalledBuildProvider]
// stands in for the not-yet-wired build-number reader (see
// evaluate_version_state_use_case.dart's header comment — no such reader
// exists yet in this codebase, so this task's own tests do not depend on
// one either).
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
    signature: 'unverified-in-this-task',
    updatedAt: 0,
  );
}

EvaluateVersionStateUseCase _useCase({
  required VersionPolicy? policy,
  required int installedBuild,
}) {
  return EvaluateVersionStateUseCase(
    cachedPolicyProvider: () async => policy,
    installedBuildProvider: () async => installedBuild,
  );
}

void main() {
  group('EvaluateVersionStateUseCase', () {
    test('test_EARS_VER_6_below_minimum_is_update_required', () async {
      final useCase = _useCase(
        policy: _policy(minimumSupportedBuild: 20, updateAvailableBuild: 30),
        installedBuild: 19,
      );

      expect(await useCase.call(), VersionState.updateRequired);
    });

    test(
      'test_EARS_VER_7_below_available_threshold_is_update_available',
      () async {
        final useCase = _useCase(
          policy: _policy(
            minimumSupportedBuild: 20,
            updateAvailableBuild: 30,
          ),
          installedBuild: 25,
        );

        expect(await useCase.call(), VersionState.updateAvailable);
      },
    );

    test('test_EARS_VER_8_at_or_above_both_is_up_to_date', () async {
      // installed == updateAvailableBuild: rule 2 requires a strict `<`,
      // so being AT the threshold (not below it) must NOT read as
      // updateAvailable -- it falls through to upToDate.
      final atAvailable = _useCase(
        policy: _policy(minimumSupportedBuild: 20, updateAvailableBuild: 30),
        installedBuild: 30,
      );
      final aboveBoth = _useCase(
        policy: _policy(minimumSupportedBuild: 20, updateAvailableBuild: 30),
        installedBuild: 99,
      );

      expect(await atAvailable.call(), VersionState.upToDate);
      expect(await aboveBoth.call(), VersionState.upToDate);
    });

    test('test_EARS_VER_9_no_cached_policy_is_up_to_date', () async {
      final useCase = _useCase(policy: null, installedBuild: 1);

      expect(await useCase.call(), VersionState.upToDate);
    });

    test(
      'test_build_number_comparison_is_numeric_not_lexicographic',
      () async {
        // Lexicographic string comparison would say "9" > "10" is false
        // the other way ("9" < "10" as strings is false, since '9' > '1'
        // as the first character) -- a naive `.toString()` compare would
        // wrongly conclude 9 is NOT below a minimum of 10 and return
        // upToDate. Numeric comparison must catch this.
        final useCase = _useCase(
          policy: _policy(minimumSupportedBuild: 10, updateAvailableBuild: 20),
          installedBuild: 9,
        );

        expect(await useCase.call(), VersionState.updateRequired);
      },
    );

    test('does not read the installed build when no policy is cached', () async {
      var buildProviderCalls = 0;
      final useCase = EvaluateVersionStateUseCase(
        cachedPolicyProvider: () async => null,
        installedBuildProvider: () async {
          buildProviderCalls++;
          return 1;
        },
      );

      final result = await useCase.call();

      expect(result, VersionState.upToDate);
      expect(buildProviderCalls, 0);
    });
  });
}
