// EARS-VER-10/11/12 (FR-VER-006, FR-VER-007) — E14-T04.
//
// `EARS-VER-10` (WHEN `UPDATE_REQUIRED` at launch THE system SHALL route
// to `/version-update-required`) is proven against `app/main.dart`'s own
// `initialRouteFor(VersionState)` — the pure mapping pulled out of `main()`
// specifically so this fenced test file can assert it directly, without
// booting Firebase/`AppDatabase`/`MessagingStack` the way running `main()`
// itself would require (`Q-E14-T04-1`, resolved 2026-09-05: both
// `package_info_plus` and `in_app_update` are now human-approved and
// wired). What is fully testable independent of either dependency is this
// controller's OWN behaviour: it starts whatever launcher it is given
// (EARS-VER-12), and it never exposes any way to navigate away on its own
// (EARS-VER-11's controller half — the view's own non-dismissibility,
// `PopScope(canPop: false)`, is a widget-tree property asserted directly
// against `VersionUpdateView` below, not something a plain `GetxController`
// unit test could reach).
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/app/main.dart'
    show
        evaluateVersionStateAtLaunch,
        initialRouteFor,
        readInstalledBuildNumber;
import 'package:nexora/app/routes.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/core/services/version_policy_signature_verifier.dart';
import 'package:nexora/features/version/domain/version_state.dart';
import 'package:nexora/features/version/presentation/version_update_controller.dart';
import 'package:nexora/features/version/presentation/version_update_view.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// E14-B01's own test seam (`version_policy_service_test.dart`'s pattern,
/// reused here rather than re-invented): overrides the read seam so
/// [VersionPolicyService.refresh] never touches a real `FirebaseDatabase`,
/// while everything else -- the real Drift table, `cached()`'s real query --
/// runs exactly as `main.dart`'s own composition does.
///
/// E14-T03: gained a `signatureVerifier` pass-through -- every payload
/// below is now genuinely Ed25519-signed (`signedPayload`), since a
/// literal `'sig-v1'` string never verifies against any key and would
/// make `refresh()` fail closed.
class _FixedReadVersionPolicyService extends VersionPolicyService {
  _FixedReadVersionPolicyService({
    required super.database,
    required this.payload,
    super.signatureVerifier,
  });

  final Object? payload;

  @override
  Future<Object?> readVersionPolicyData() async => payload;
}

void main() {
  final algorithm = Ed25519();
  late SimpleKeyPair keyPair;
  late VersionPolicySignatureVerifier verifier;

  Future<Map<String, Object?>> signedPayload({
    int minimumSupportedBuild = 100,
    int currentBuild = 120,
    int updateAvailableBuild = 130,
    int updatedAt = 1700000000000,
  }) async {
    final message = VersionPolicySignatureVerifier.canonicalMessage(
      minimumSupportedBuild: minimumSupportedBuild,
      currentBuild: currentBuild,
      updateAvailableBuild: updateAvailableBuild,
      updatedAt: updatedAt,
    );
    final signature = await algorithm.sign(message, keyPair: keyPair);
    return {
      'minimumSupportedBuild': minimumSupportedBuild,
      'currentBuild': currentBuild,
      'updateAvailableBuild': updateAvailableBuild,
      'signature': base64.encode(signature.bytes),
      'updatedAt': updatedAt,
    };
  }

  setUpAll(() async {
    keyPair = await algorithm.newKeyPairFromSeed(List.filled(32, 13));
    final publicKeyBytes = (await keyPair.extractPublicKey()).bytes;
    verifier = VersionPolicySignatureVerifier(
      publicKeyBytesOverride: publicKeyBytes,
    );
  });

  group('initialRouteFor (EARS-VER-10)', () {
    test(
        'test_EARS_VER_10_update_required_routes_to_mandatory_screen',
        () {
      expect(
        initialRouteFor(VersionState.updateRequired),
        Routes.versionUpdateRequired,
      );
    });

    test(
        'test_up_to_date_and_update_available_route_to_the_normal_startup_flow',
        () {
      expect(initialRouteFor(VersionState.upToDate), Routes.welcome);
      expect(initialRouteFor(VersionState.updateAvailable), Routes.welcome);
    });
  });

  group('E14-B01 — main.dart\'s real launch composition, end to end', () {
    test(
        'test_EARS_VER_3_4_5_refresh_populates_the_cache_so_launch_routes_'
        'to_the_mandatory_update_screen', () async {
      // A real Drift database -- `VersionPolicyService.cached()` runs its
      // actual query against it, exactly as `main.dart` does. Only the
      // remote read (`readVersionPolicyData`) is seamed, same as
      // `version_policy_service_test.dart`'s own pattern.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final versionPolicyService = _FixedReadVersionPolicyService(
        database: db,
        // Far below `installedBuildProvider`'s `1` below -- guarantees
        // `UPDATE_REQUIRED` regardless of the exact threshold semantics.
        payload: await signedPayload(),
        signatureVerifier: verifier,
      );

      // Calls `main.dart`'s OWN `evaluateVersionStateAtLaunch` -- the exact
      // function `main()` itself calls -- rather than re-implementing its
      // steps here. Before E14-B01's fix, that function never called
      // `.refresh()` at all -- so `.cached()` below returned `null`,
      // `EvaluateVersionStateUseCase` took its fail-open `upToDate` branch,
      // and this test failed asserting `Routes.welcome` instead of
      // `Routes.versionUpdateRequired`. A test that instead re-derived the
      // same steps inline would pass either way and prove nothing about
      // `main.dart`'s own wiring.
      final versionState = await evaluateVersionStateAtLaunch(
        versionPolicyService,
        () async => 1,
      );

      expect(versionState, VersionState.updateRequired);
      expect(
        initialRouteFor(versionState),
        Routes.versionUpdateRequired,
      );
    });
  });

  group(
    'E14-B03 — an unreadable installed build number fails CLOSED '
    '(OQ-E14-B03-1)',
    () {
      test(
          'test_E14_B03_throwing_installed_build_provider_is_update_required',
          () async {
        // A policy IS cached (`minimumSupportedBuild` seeded below) --
        // `OQ-E14-B03-1`'s resolution only concerns this case, never the
        // separate no-cached-policy fail-open (`EARS-VER-9`, untouched by
        // this fix).
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final versionPolicyService = _FixedReadVersionPolicyService(
          database: db,
          payload: await signedPayload(),
          signatureVerifier: verifier,
        );

        // Before this bug's fix, `EvaluateVersionStateUseCase.call()`
        // awaited `_installedBuildProvider()` with no `try`/`catch` of its
        // own, so a throwing provider like this one propagated straight out
        // of `evaluateVersionStateAtLaunch` as an uncaught exception --
        // this test failed on today's HEAD by throwing, never by asserting
        // the wrong `VersionState`.
        final versionState = await evaluateVersionStateAtLaunch(
          versionPolicyService,
          () async => throw StateError('platform channel error'),
        );

        expect(versionState, VersionState.updateRequired);
        expect(
          initialRouteFor(versionState),
          Routes.versionUpdateRequired,
        );
      });

      test(
          'test_E14_B03_non_numeric_build_number_is_update_required',
          () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final versionPolicyService = _FixedReadVersionPolicyService(
          database: db,
          payload: await signedPayload(),
          signatureVerifier: verifier,
        );

        // A valid `CFBundleVersion` shape (task file's own repro §1) --
        // `PackageInfo.buildNumber` is a `String` with no numeric
        // guarantee. Before this bug's fix, `_readInstalledBuildNumber`'s
        // `int.parse` threw a `FormatException`, was caught, and returned
        // the `1 << 62` sentinel -- comfortably above `minimumSupportedBuild`
        // -- so this test failed asserting `VersionState.upToDate` instead
        // of `updateRequired` on today's HEAD.
        PackageInfo.setMockInitialValues(
          appName: 'nexora',
          packageName: 'com.nexora.app',
          version: '1.0.3',
          buildNumber: '1.0.3',
          buildSignature: '',
        );

        final versionState = await evaluateVersionStateAtLaunch(
          versionPolicyService,
          readInstalledBuildNumber,
        );

        expect(versionState, VersionState.updateRequired);
        expect(
          initialRouteFor(versionState),
          Routes.versionUpdateRequired,
        );
      });
    },
  );

  group('VersionUpdateController', () {
    test('test_EARS_VER_12_update_now_starts_immediate_update_flow',
        () async {
      var launcherCalled = 0;
      final controller = VersionUpdateController(
        launcher: () async => launcherCalled++,
      );

      await controller.startImmediateUpdate();

      expect(launcherCalled, 1);
    });

    test(
        'test_launcher_failure_is_swallowed_and_logged_not_rethrown '
        '(the screen has no other affordance to fall back to)', () async {
      final controller = VersionUpdateController(
        launcher: () async => throw StateError('platform call failed'),
      );

      // Must not throw -- there is nothing else for the caller (the
      // button's onPressed) to do with a rethrown error, and the contract
      // (task file §5) says the failure is logged, the screen stays.
      await controller.startImmediateUpdate();
    });

    test(
        'test_launcher_is_never_called_until_startImmediateUpdate_is_'
        'invoked (no auto-start on construction)', () async {
      var launcherCalled = 0;
      VersionUpdateController(launcher: () async => launcherCalled++);

      expect(launcherCalled, 0);
    });
  });

  group('VersionUpdateView — non-dismissible (EARS-VER-11)', () {
    testWidgets(
        'test_EARS_VER_11_back_gesture_and_button_do_not_dismiss',
        (tester) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      Get.put<VersionUpdateController>(
        VersionUpdateController(launcher: () async {}),
      );

      // A real previous route on the navigation stack, exactly the
      // scenario EARS-VER-11 guards against: if this screen were ever
      // dismissible, the back gesture/button would reveal `_Behind`.
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/behind',
          getPages: [
            GetPage<dynamic>(name: '/behind', page: () => const _Behind()),
            GetPage<dynamic>(
              name: '/version-update-required',
              page: () => const VersionUpdateView(),
            ),
          ],
        ),
      );
      Get.toNamed('/version-update-required');
      await tester.pumpAndSettle();

      expect(find.byType(VersionUpdateView), findsOneWidget);
      expect(find.byType(_Behind), findsNothing);

      // The Android hardware/software back button and the system back
      // gesture both funnel through `Navigator.maybePop` /
      // `PopScope.canPop` -- simulating the platform "pop route" system
      // channel message is the same path either one takes.
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byType(VersionUpdateView),
        findsOneWidget,
        reason: 'the back gesture/button must not pop this route',
      );
      expect(
        find.byType(_Behind),
        findsNothing,
        reason: 'no affordance on this screen may reveal a previous route',
      );

      // Structural absence, not merely "didn't navigate away": there is no
      // second button, no icon button, and no dismiss/close affordance at
      // all — exactly one tappable control on the whole screen.
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
    });
  });
}

class _Behind extends StatelessWidget {
  const _Behind();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('behind'));
}
