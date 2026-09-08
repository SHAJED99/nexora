// test/features/settings/account/domain — resolveInitialRoute (E15-T02).
//
// EARS-AUTH-8/9/10 on the pure function itself, plus EARS-AUTH-6 (launch
// half of FR-AUTH-009) as a composition-order test mirroring `main.dart`'s
// own literal call order — see that test's own header comment for exactly
// what it does and does not prove.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/app/routes.dart';
import 'package:nexora/core/session/local_data_wipe_service.dart';
import 'package:nexora/features/settings/account/domain/resolve_initial_route_use_case.dart';
import 'package:nexora/features/version/domain/version_state.dart';

void main() {
  group('resolveInitialRoute', () {
    test('test_EARS_AUTH_8_identity_present_routes_to_dashboard', () {
      final route = resolveInitialRoute(
        versionState: VersionState.upToDate,
        hasLocalIdentity: true,
      );
      expect(route, Routes.dashboard);
    });

    test(
        'test_EARS_AUTH_9_update_required_wins_with_an_identity_present '
        '— the precedence test', () {
      final route = resolveInitialRoute(
        versionState: VersionState.updateRequired,
        hasLocalIdentity: true,
      );
      expect(
        route,
        Routes.versionUpdateRequired,
        reason: 'the mandatory-update block must win regardless of a local '
            'identity — this is the one that must not be allowed to rot',
      );
    });

    test('test_EARS_AUTH_9_update_required_wins_without_an_identity', () {
      final route = resolveInitialRoute(
        versionState: VersionState.updateRequired,
        hasLocalIdentity: false,
      );
      expect(route, Routes.versionUpdateRequired);
    });

    test('test_EARS_AUTH_10_no_identity_routes_to_welcome', () {
      final route = resolveInitialRoute(
        versionState: VersionState.upToDate,
        hasLocalIdentity: false,
      );
      expect(route, Routes.welcome);
    });

    test(
        'updateAvailable (non-blocking) with an identity still reaches '
        'the dashboard — the update-required branch is the ONLY thing '
        'that may pre-empt the identity check', () {
      final route = resolveInitialRoute(
        versionState: VersionState.updateAvailable,
        hasLocalIdentity: true,
      );
      expect(route, Routes.dashboard);
    });

    test(
        'falsification: reversing the update-required check and the '
        'identity check would make test_EARS_AUTH_9_* fail', () {
      // Task file §7's own falsification item. Simulates what the buggy,
      // reversed order would have returned — hasLocalIdentity checked
      // FIRST, updateRequired only as a fallback — and proves that shape
      // fails the exact precedence test above (returns dashboard, not the
      // mandatory-update route), so a future edit that accidentally
      // reintroduces this order is caught, not silently green.
      String reversedOrderRoute({
        required VersionState versionState,
        required bool hasLocalIdentity,
      }) {
        if (hasLocalIdentity) return Routes.dashboard;
        return versionState == VersionState.updateRequired
            ? Routes.versionUpdateRequired
            : Routes.welcome;
      }

      final buggyRoute = reversedOrderRoute(
        versionState: VersionState.updateRequired,
        hasLocalIdentity: true,
      );
      expect(
        buggyRoute,
        isNot(Routes.versionUpdateRequired),
        reason: 'proves the reversed order really is wrong — it must NOT '
            'produce the correct answer, or this falsification proves '
            'nothing',
      );
      // ...and the real function, given the same inputs, gets it right.
      final correctRoute = resolveInitialRoute(
        versionState: VersionState.updateRequired,
        hasLocalIdentity: true,
      );
      expect(correctRoute, Routes.versionUpdateRequired);
    });
  });

  group('EARS-AUTH-6 — pending wipe completed before any routing decision', () {
    test(
        'test_EARS_AUTH_6_pending_wipe_completed_before_routing '
        '(mirrors main.dart\'s own literal call order: '
        'LocalDataWipeService().completePendingWipe() runs, and finishes, '
        'strictly before the identity read that feeds resolveInitialRoute — '
        'see main.dart\'s own comment at that call site for the production '
        'wiring this test does not itself execute)', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'e15_t02_wipe_order_test',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final dbFile = File('${tempDir.path}/nexora.sqlite');
      await dbFile.create();
      final sentinel = File('${dbFile.path}.wipe_pending');
      await sentinel.create();

      final wipeService = LocalDataWipeService(
        databaseFile: () async => dbFile,
      );

      final order = <String>[];

      Future<void> completePendingWipeStep() async {
        order.add('wipe-start');
        await wipeService.completePendingWipe();
        order.add('wipe-done');
      }

      Future<bool> readHasLocalIdentityStep() async {
        order.add('identity-read');
        return true;
      }

      // The order main.dart's own source performs: complete any pending
      // wipe, THEN read the identity, THEN decide the route.
      await completePendingWipeStep();
      final hasLocalIdentity = await readHasLocalIdentityStep();
      final route = resolveInitialRoute(
        versionState: VersionState.upToDate,
        hasLocalIdentity: hasLocalIdentity,
      );

      expect(order, ['wipe-start', 'wipe-done', 'identity-read']);
      expect(route, Routes.dashboard);
      expect(
        await sentinel.exists(),
        isFalse,
        reason: 'the pending wipe must have genuinely completed (sentinel '
            'removed), not merely been called, before this test claims the '
            'ordering held',
      );
      expect(
        await dbFile.exists(),
        isFalse,
        reason: 'a real interrupted wipe leaves no database file behind '
            'either — completePendingWipe() finished the erase, it did not '
            'just clear the sentinel',
      );
    });

    test(
        'test_EARS_AUTH_6_pending_wipe_is_a_noop_when_nothing_is_pending_and_'
        'routing_still_proceeds', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'e15_t02_wipe_order_noop_test',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final dbFile = File('${tempDir.path}/nexora.sqlite');
      // No sentinel, no db file: the common case, a launch with nothing
      // pending. completePendingWipe() must still be safe to call
      // unconditionally in main() (it is called every launch, not only
      // when a wipe is known to be pending).
      final wipeService = LocalDataWipeService(
        databaseFile: () async => dbFile,
      );

      await wipeService.completePendingWipe();
      final route = resolveInitialRoute(
        versionState: VersionState.upToDate,
        hasLocalIdentity: false,
      );

      expect(route, Routes.welcome);
    });
  });
}
