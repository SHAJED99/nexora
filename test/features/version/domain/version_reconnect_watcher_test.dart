// E14-B06 -- VersionReconnectWatcher tests (FR-VER-008's own "on reconnect
// ... re-evaluate" half, previously unimplemented).
//
// Same test-seam pattern as `version_policy_service_test.dart`/
// `version_update_controller_test.dart`: a real in-memory `AppDatabase` (so
// `VersionPolicyService.cached()`'s actual query runs, exactly as
// production does), with only the remote read (`readVersionPolicyData`)
// seamed. Connectivity is a plain `StreamController<bool>` -- no platform
// channel, no real `FirebaseDatabase`, required to drive this class at all.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/version/domain/version_reconnect_watcher.dart';

/// Returns a fixed payload from the read seam, so `refresh()` never touches
/// a real `FirebaseDatabase` -- copied pattern from
/// `version_policy_service_test.dart`/`version_update_controller_test.dart`.
class _FixedReadVersionPolicyService extends VersionPolicyService {
  _FixedReadVersionPolicyService({
    required super.database,
    required this.payload,
  });

  final Object? payload;

  @override
  Future<Object?> readVersionPolicyData() async => payload;
}

/// E14-B06 round 2 (F1 regression fixture): behaves exactly like
/// [_FixedReadVersionPolicyService], except [cached] throws on its FIRST
/// invocation only, then behaves normally on every later call -- simulating
/// a single transient failure inside `_reevaluate()`'s own composition
/// (`VersionPolicyService.cached` is `EvaluateVersionStateUseCase`'s
/// injected `cachedPolicyProvider`), without needing `refresh()` itself to
/// throw (it never does, `EARS-VER-4`).
class _FailsOnceThenSucceedsVersionPolicyService extends VersionPolicyService {
  _FailsOnceThenSucceedsVersionPolicyService({
    required super.database,
    required this.payload,
  });

  final Object? payload;
  int cachedCalls = 0;

  @override
  Future<Object?> readVersionPolicyData() async => payload;

  @override
  Future<VersionPolicy?> cached() async {
    cachedCalls++;
    if (cachedCalls == 1) {
      throw Exception('transient failure during first reconnect re-check');
    }
    return super.cached();
  }
}

Map<String, Object?> _payload({
  int minimumSupportedBuild = 100,
  int currentBuild = 120,
  int updateAvailableBuild = 130,
}) => {
      'minimumSupportedBuild': minimumSupportedBuild,
      'currentBuild': currentBuild,
      'updateAvailableBuild': updateAvailableBuild,
      'signature': 'sig-v1',
      'updatedAt': 1700000000000,
    };

void main() {
  group('VersionReconnectWatcher', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test(
        'test_reconnect_with_update_required_policy_navigates_to_mandatory_'
        'update_screen', () async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);

      // Far below `installedBuildProvider`'s `1` below -- guarantees
      // `UPDATE_REQUIRED` regardless of the exact threshold semantics, same
      // reasoning as `version_update_controller_test.dart`'s own fixture.
      final versionPolicyService = _FixedReadVersionPolicyService(
        database: db,
        payload: _payload(minimumSupportedBuild: 100),
      );

      var navigateCalls = 0;
      final watcher = VersionReconnectWatcher(
        connectivityStream: controller.stream,
        versionPolicyService: versionPolicyService,
        installedBuildProvider: () async => 1,
        onUpdateRequired: () => navigateCalls++,
      );
      watcher.start();
      addTearDown(watcher.stop);

      // A genuine reconnect: connected, THEN disconnected, THEN reconnected.
      controller.add(true);
      await pumpEventQueue();
      expect(
        navigateCalls,
        0,
        reason: 'the very first connectivity event must never itself count '
            'as a reconnect -- E14-B01 already owns the launch-time check',
      );

      controller.add(false);
      await pumpEventQueue();
      expect(navigateCalls, 0);

      controller.add(true);
      await pumpEventQueue();

      expect(
        navigateCalls,
        1,
        reason: 'a real disconnect -> connect transition must refresh, '
            're-evaluate, and navigate exactly once',
      );
    });

    test(
        'test_reconnect_with_unchanged_up_to_date_policy_does_not_navigate',
        () async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);

      // Installed build (`1000`) is above both thresholds -- UP_TO_DATE.
      final versionPolicyService = _FixedReadVersionPolicyService(
        database: db,
        payload: _payload(
          minimumSupportedBuild: 100,
          updateAvailableBuild: 130,
        ),
      );

      var navigateCalls = 0;
      final watcher = VersionReconnectWatcher(
        connectivityStream: controller.stream,
        versionPolicyService: versionPolicyService,
        installedBuildProvider: () async => 1000,
        onUpdateRequired: () => navigateCalls++,
      );
      watcher.start();
      addTearDown(watcher.stop);

      controller.add(true);
      await pumpEventQueue();
      controller.add(false);
      await pumpEventQueue();
      controller.add(true);
      await pumpEventQueue();

      expect(
        navigateCalls,
        0,
        reason: 'a reconnect against a still-fine policy must not navigate '
            'anywhere -- no regression to normal operation',
      );
    });

    test(
        'test_duplicate_connected_events_without_an_intervening_disconnect_'
        'do_not_re_trigger', () async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);

      final versionPolicyService = _FixedReadVersionPolicyService(
        database: db,
        payload: _payload(minimumSupportedBuild: 100),
      );

      var navigateCalls = 0;
      final watcher = VersionReconnectWatcher(
        connectivityStream: controller.stream,
        versionPolicyService: versionPolicyService,
        installedBuildProvider: () async => 1,
        onUpdateRequired: () => navigateCalls++,
      );
      watcher.start();
      addTearDown(watcher.stop);

      // Establish a genuine reconnect first (true, then false, then true --
      // same shape as the first test in this file) so `navigateCalls == 1`
      // reflects a real transition, not the cold-start false->true pair
      // this file's own F3 regression test below covers separately.
      controller.add(true);
      await pumpEventQueue();
      controller.add(false);
      await pumpEventQueue();
      controller.add(true);
      await pumpEventQueue();
      expect(navigateCalls, 1);

      // A second `true` with no intervening `false` is not a new reconnect.
      controller.add(true);
      await pumpEventQueue();
      expect(navigateCalls, 1);
    });

    test(
        'test_cold_start_false_then_true_sequence_does_not_duplicate_the_'
        'launch_time_check', () async {
      // E14-B06 round 2 (F3 regression): Firebase's `.info/connected`
      // characteristically emits `false` first at cold start (its initial
      // "not yet connected" value), then `true` once the socket actually
      // connects -- a textbook `false -> true` transition on this stream's
      // very first two events. The original fix's own claim ("a fresh
      // subscription can never re-fire E14-B01's launch-time check because
      // `_previouslyConnected` starts null") was false: that null-seeded
      // check alone does NOT protect against this specific two-event
      // sequence. This proves the actual fix (`_everConnected`) does.
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);

      final versionPolicyService = _FixedReadVersionPolicyService(
        database: db,
        payload: _payload(minimumSupportedBuild: 100),
      );

      var navigateCalls = 0;
      final watcher = VersionReconnectWatcher(
        connectivityStream: controller.stream,
        versionPolicyService: versionPolicyService,
        installedBuildProvider: () async => 1,
        onUpdateRequired: () => navigateCalls++,
      );
      watcher.start();
      addTearDown(watcher.stop);

      // The exact cold-start sequence: nothing precedes it.
      controller.add(false);
      await pumpEventQueue();
      controller.add(true);
      await pumpEventQueue();

      expect(
        navigateCalls,
        0,
        reason: 'the cold-start false->true settling sequence must not '
            'duplicate the launch-time check',
      );

      // A LATER, genuine disconnect -> reconnect must still fire normally.
      controller.add(false);
      await pumpEventQueue();
      controller.add(true);
      await pumpEventQueue();

      expect(
        navigateCalls,
        1,
        reason: 'a real reconnect after the cold-start settling sequence '
            'must still trigger exactly once',
      );
    });

    test(
        'test_a_thrown_error_during_reevaluation_does_not_permanently_kill_'
        'the_watcher', () async {
      // E14-B06 round 2 (F1 regression): `_pending = _pending.then(...)`
      // used to have no `onError` handler, so one rejection propagated
      // into `_pending`'s own Future and every SUBSEQUENT `.then` in the
      // chain short-circuited without running `_reevaluate()` again --
      // permanently and silently killing this watcher for the rest of the
      // session. Proves a SECOND, later reconnect still successfully
      // re-evaluates and navigates after a first reconnect's re-evaluation
      // throws.
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);

      final versionPolicyService = _FailsOnceThenSucceedsVersionPolicyService(
        database: db,
        payload: _payload(minimumSupportedBuild: 100),
      );

      var navigateCalls = 0;
      final watcher = VersionReconnectWatcher(
        connectivityStream: controller.stream,
        versionPolicyService: versionPolicyService,
        installedBuildProvider: () async => 1,
        onUpdateRequired: () => navigateCalls++,
      );
      watcher.start();
      addTearDown(watcher.stop);

      // Establish a connection, then a first genuine reconnect whose own
      // re-evaluation throws (`cachedCalls == 1`).
      controller.add(true);
      await pumpEventQueue();
      controller.add(false);
      await pumpEventQueue();
      controller.add(true);
      await pumpEventQueue();

      expect(
        navigateCalls,
        0,
        reason: 'the first reconnect\'s re-evaluation threw, so it must not '
            'have navigated',
      );

      // A SECOND, later reconnect must still work -- proving the watcher
      // survived the first failure rather than being silently and
      // permanently killed.
      controller.add(false);
      await pumpEventQueue();
      controller.add(true);
      await pumpEventQueue();

      expect(
        navigateCalls,
        1,
        reason: 'a later reconnect must still successfully re-evaluate and '
            'navigate after an earlier reconnect\'s re-evaluation failed',
      );
      expect(versionPolicyService.cachedCalls, 2);
    });

    test('test_stop_cancels_the_subscription_so_later_events_are_ignored',
        () async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);

      final versionPolicyService = _FixedReadVersionPolicyService(
        database: db,
        payload: _payload(minimumSupportedBuild: 100),
      );

      var navigateCalls = 0;
      final watcher = VersionReconnectWatcher(
        connectivityStream: controller.stream,
        versionPolicyService: versionPolicyService,
        installedBuildProvider: () async => 1,
        onUpdateRequired: () => navigateCalls++,
      );
      watcher.start();

      controller.add(false);
      await pumpEventQueue();
      watcher.stop();

      controller.add(true);
      await pumpEventQueue();

      expect(navigateCalls, 0);
    });
  });
}
