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
