// test/features/settings/account/domain — resolveInitialRoute (E15-T02).
//
// EARS-AUTH-8/9/10 on the pure function itself, plus EARS-AUTH-6 (launch
// half of FR-AUTH-009) as a composition-order test mirroring `main.dart`'s
// own literal call order — see that test's own header comment for exactly
// what it does and does not prove.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/app/main.dart' show initialRouteFor;
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

    test(
        'falsification (review round 2, F2): a duplicated predicate that '
        'only forwards the DESTINATION constant, not the DECISION, silently '
        'disagrees with a future blocking VersionState — a genuinely '
        'delegating shape cannot', () {
      // `VersionState` only has three real values today (`version_state
      // .dart`), so this test cannot add a real fourth blocking state
      // without touching a file outside this task's `files:` fence.
      // Instead it stands up a test-double `initialRouteFor`-shaped
      // function that treats a SECOND state (`upToDate`, chosen only
      // because it is easy to distinguish here) as blocking too —
      // simulating "a fourth blocking state was added to initialRouteFor" —
      // and proves the OLD, duplicated-predicate shape does not honour it,
      // while the genuinely-delegating shape (identical to production
      // `resolveInitialRoute` above) does.
      String hypotheticalInitialRouteFor(VersionState state) {
        if (state == VersionState.updateRequired ||
            state == VersionState.upToDate) {
          // Both now "block" in this hypothetical extended policy.
          return state == VersionState.updateRequired
              ? Routes.versionUpdateRequired
              : Routes.devices; // stand-in for "some other blocking screen"
        }
        return Routes.welcome;
      }

      // The OLD shape this review round rejected: re-implements the
      // predicate (`== updateRequired`) instead of asking
      // `hypotheticalInitialRouteFor` what it decided.
      String oldDuplicatedPredicateShape({
        required VersionState versionState,
        required bool hasLocalIdentity,
      }) {
        if (versionState == VersionState.updateRequired) {
          return hypotheticalInitialRouteFor(versionState);
        }
        return hasLocalIdentity ? Routes.dashboard : Routes.welcome;
      }

      // The FIXED shape (mirrors production `resolveInitialRoute` above):
      // asks the version function for its actual decision and only falls
      // through to the identity check on its own non-blocking default.
      String genuinelyDelegatingShape({
        required VersionState versionState,
        required bool hasLocalIdentity,
      }) {
        final versionRoute = hypotheticalInitialRouteFor(versionState);
        if (versionRoute != Routes.welcome) return versionRoute;
        return hasLocalIdentity ? Routes.dashboard : Routes.welcome;
      }

      const newBlockingState = VersionState.upToDate;
      final oldShapeRoute = oldDuplicatedPredicateShape(
        versionState: newBlockingState,
        hasLocalIdentity: true,
      );
      final fixedShapeRoute = genuinelyDelegatingShape(
        versionState: newBlockingState,
        hasLocalIdentity: true,
      );

      expect(
        oldShapeRoute,
        Routes.dashboard,
        reason: 'the OLD, duplicated-predicate shape must get this WRONG — '
            'it never re-consults hypotheticalInitialRouteFor for anything '
            'other than updateRequired, so a newly-blocking state silently '
            'falls through to the identity check and reaches /dashboard. '
            'If this assertion fails, the falsification proves nothing.',
      );
      expect(
        fixedShapeRoute,
        Routes.devices,
        reason: 'the genuinely-delegating shape (production '
            '`resolveInitialRoute`\'s own pattern) must honour the new '
            'blocking state instead — this is what a fourth blocking '
            '`VersionState` would look like in real production code',
      );
      expect(
        oldShapeRoute,
        isNot(fixedShapeRoute),
        reason: 'the whole point: the two shapes disagree on a value '
            'neither disagreed on before this hypothetical state existed — '
            'proving the old shape was only accidentally correct, not '
            'genuinely delegating',
      );
    });

    test(
        'the real production resolveInitialRoute agrees with initialRouteFor '
        "on every real VersionState value today — the two functions' "
        'outputs can never disagree, which the OLD duplicated-predicate '
        'shape only guaranteed by coincidence (there being just one '
        'blocking value)', () {
      for (final state in VersionState.values) {
        final versionOnlyRoute = initialRouteFor(state);
        for (final hasLocalIdentity in [true, false]) {
          final combinedRoute = resolveInitialRoute(
            versionState: state,
            hasLocalIdentity: hasLocalIdentity,
          );
          if (versionOnlyRoute != Routes.welcome) {
            expect(
              combinedRoute,
              versionOnlyRoute,
              reason: '$state is blocking per initialRouteFor — '
                  'resolveInitialRoute must return the exact same route '
                  'regardless of hasLocalIdentity=$hasLocalIdentity',
            );
          }
        }
      }
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
        'test_EARS_AUTH_6_pending_wipe_completion_failure_does_not_crash_'
        'main_and_forces_welcome_not_dashboard '
        '(review round 2, F1: mirrors main.dart\'s own guarded '
        'try/catch around completePendingWipe() — see that call site\'s own '
        'comment)', () async {
      // A real database file that genuinely exists (so
      // `_deleteDatabaseFilesAndSidecars` actually attempts a delete on it,
      // not a no-op on an absent path) plus an injected [deleteFile] that
      // always throws — the same shape `LocalDataWipeService.wipe()` wraps
      // as `AppFailure('session.local_wipe_failed', ...)`
      // (`local_data_wipe_service.dart:88`) for a real filesystem/permission
      // failure. This is the failure this test proves `main()`'s own guard
      // survives.
      final tempDir = await Directory.systemTemp.createTemp(
        'e15_t02_f1_wipe_failure_test',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final dbFile = File('${tempDir.path}/nexora.sqlite');
      await dbFile.create();
      final sentinel = File('${dbFile.path}.wipe_pending');

      final wipeService = LocalDataWipeService(
        databaseFile: () async => dbFile,
        deleteFile: (file) async {
          // A delete that always fails — forces `wipe()` into its own
          // `catch` (`local_data_wipe_service.dart:90`) every time, the
          // same way a real filesystem/permission failure would.
          throw const FileSystemException('simulated delete failure');
        },
      );
      // A sentinel exists (a wipe was pending) so `completePendingWipe()`
      // does not short-circuit as a no-op and actually reaches `wipe()`.
      await sentinel.create(recursive: true);

      // Mirrors `main()`'s own guard EXACTLY (`main.dart`'s
      // `completePendingWipe()` call site, review round 2 F1): a failure is
      // caught, logged (not asserted here — that is `ObservabilityService`'s
      // own concern, not this pure-composition test's), and forces
      // `hasLocalIdentity` to `false` for the routing decision below,
      // regardless of what a local identity read would otherwise have said.
      var pendingWipeCompletionFailed = false;
      try {
        await wipeService.completePendingWipe();
      } catch (_) {
        pendingWipeCompletionFailed = true;
      }

      expect(
        pendingWipeCompletionFailed,
        isTrue,
        reason: 'the simulated delete failure must actually have reached '
            'the catch — otherwise this test proves nothing about the '
            'guard',
      );

      // The critical assertion: even with a local identity present, a
      // failed pending-wipe completion must route to /welcome, never
      // /dashboard — "nothing else may be decided against a half-erased
      // device" (task file §2 step 1).
      const dbLocalIdentityReadWouldSayTrue = true; // a local identity IS
      // present on disk — the point of this test is that it must not
      // matter once the wipe-completion failed.
      final route = resolveInitialRoute(
        versionState: VersionState.upToDate,
        hasLocalIdentity:
            !pendingWipeCompletionFailed && dbLocalIdentityReadWouldSayTrue,
      );
      expect(
        route,
        Routes.welcome,
        reason: 'a pending-wipe-completion failure must force /welcome, '
            'exactly as if hasLocalIdentity were false, never /dashboard '
            'on a possibly half-wiped device',
      );

      // The sentinel is untouched by this catch block — `wipe()`'s own
      // retry-at-next-launch mechanism (task file's own contract, and the
      // review's explicit instruction) is not this fix's concern.
      expect(
        await sentinel.exists(),
        isTrue,
        reason: 'the sentinel must survive a failed completion so the next '
            'launch retries — this fix only stops main() from crashing and '
            'forces welcome, it must not clear the sentinel itself',
      );
    });

    test(
        'control: an UNGUARDED completePendingWipe() call genuinely throws '
        'on this same failure — proving main.dart\'s try/catch guards a '
        'real failure mode, not a vacuous one', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'e15_t02_f1_control_test',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final dbFile = File('${tempDir.path}/nexora.sqlite');
      await dbFile.create();
      final sentinel = File('${dbFile.path}.wipe_pending');
      await sentinel.create(recursive: true);

      final wipeService = LocalDataWipeService(
        databaseFile: () async => dbFile,
        deleteFile: (file) async {
          throw const FileSystemException('simulated delete failure');
        },
      );

      // Deliberately NO try/catch here — this is the shape `main.dart` had
      // BEFORE the F1 fix. It must throw (an `AppFailure`,
      // `local_data_wipe_service.dart:91`), proving the guard added around
      // this exact call in `main()` is necessary, not decorative.
      await expectLater(
        wipeService.completePendingWipe(),
        throwsA(anything),
        reason: 'without a guard, this call really does escape — which is '
            'exactly what would have crashed main() before runApp ever ran',
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
