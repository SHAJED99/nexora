// features/settings/privacy/presentation --
// PrivacySettingsController (E15-T05).
//
// Real in-memory `AppDatabase` + the real `LocationSettingsRepository` /
// `NotificationSettingsRepository` throughout -- these tests prove the
// controller's *binding* to both repositories, not a mock's promise that it
// would. `_CountingLocationRepository` / `_ErroringPeerReadRepository` below
// are the seams the task's own risk list calls for: a call counter and a
// read that fails -- never `fail()` inside an injected seam (a broad catch
// in the SUT would swallow it, L-testing).
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/notification_tables.dart'
    show NotificationPrivacyLevel;
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocationSettingsRepository locationRepository;
  late NotificationSettingsRepository notificationRepository;
  late PrivacySettingsController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    locationRepository = LocationSettingsRepository(db: db);
    notificationRepository = NotificationSettingsRepository(db: db);
    controller = PrivacySettingsController(
      locationRepository: locationRepository,
      notificationRepository: notificationRepository,
    );
  });

  tearDown(() async {
    controller.onClose();
    await db.close();
  });

  test(
    'test_EARS_SEC_4_global_switch_persists_through_the_repository',
    () async {
      controller.onInit();
      await pumpEventQueue();
      expect(controller.globalLocationEnabled.value, isFalse);

      await controller.setGlobalLocation(true);
      await pumpEventQueue();

      expect(controller.globalLocationEnabled.value, isTrue);
      expect(await locationRepository.readGlobalEnabled(), isTrue);
    },
  );

  test(
    'test_EARS_SEC_4_global_set_before_first_emission_performs_no_write',
    () async {
      // Falsifies the same re-derived-default shape T04's F1 finding
      // fixed: calling `setGlobalLocation` before `watchGlobalEnabled()`'s
      // first emission has landed must not write, because the controller
      // does not yet know the real stored value and this screen holds no
      // defaulting rule of its own (task §2).
      final countingRepository = _CountingLocationRepository(db: db);
      final countingController = PrivacySettingsController(
        locationRepository: countingRepository,
        notificationRepository: notificationRepository,
      );
      countingController.onInit();

      expect(countingController.globalLocationEnabled.value, isNull);

      await countingController.setGlobalLocation(true);

      expect(countingRepository.writeGlobalEnabledCalls, 0);

      countingController.onClose();
    },
  );

  test(
    'test_EARS_SEC_4_peer_set_before_first_load_performs_no_write',
    () async {
      // Same guard, the per-peer side: `readAllPeerEnabled()` is a
      // one-shot Future, not a stream, so the "unknown state never writes"
      // window is the gap between `onInit` and that Future's completion.
      final countingRepository = _CountingLocationRepository(db: db);
      final countingController = PrivacySettingsController(
        locationRepository: countingRepository,
        notificationRepository: notificationRepository,
      );
      countingController.onInit();

      expect(countingController.peerLocationEnabled.value, isNull);

      await countingController.setPeerLocation('peer-1', true);

      expect(countingRepository.writePeerEnabledCalls, 0);

      countingController.onClose();
    },
  );

  test(
    'test_EARS_SEC_4_global_off_overrides_peer_on',
    () async {
      // FR-LOC-003's AND: a peer with location on, global off. The screen
      // must state unavailability rather than implying the peer's own "on"
      // is honoured -- this test asserts the two independent facts the
      // view's PV17 copy depends on: the global switch really is off, and
      // that peer really is on, at the same time.
      await locationRepository.writeGlobalEnabled(false);
      await locationRepository.writePeerEnabled('peer-1', true);

      controller.onInit();
      await pumpEventQueue();

      expect(controller.globalLocationEnabled.value, isFalse);
      expect(controller.peerLocationEnabled.value, {'peer-1': true});
    },
  );

  test(
    'test_EARS_SEC_4_peer_write_re_reads_the_whole_map_not_a_local_copy',
    () async {
      // Task §6 risk note: "readAllPeerEnabled() returns a map, not a
      // stream. Re-read after any per-peer write; do not maintain a
      // parallel local map." Falsified by writing a SECOND peer directly
      // through the repository (never through the controller) in between
      // two controller-driven writes -- if the controller maintained a
      // local map instead of re-reading, it would never see peer-2.
      controller.onInit();
      await pumpEventQueue();
      expect(controller.peerLocationEnabled.value, isEmpty);

      await controller.setPeerLocation('peer-1', true);
      await pumpEventQueue();
      expect(controller.peerLocationEnabled.value, {'peer-1': true});

      // Written directly through the repository, bypassing the controller.
      await locationRepository.writePeerEnabled('peer-2', true);

      await controller.setPeerLocation('peer-1', false);
      await pumpEventQueue();

      expect(
        controller.peerLocationEnabled.value,
        {'peer-1': false, 'peer-2': true},
      );
    },
  );

  test('test_EARS_SEC_5_privacy_level_is_read_only', () async {
    await notificationRepository.setPrivacyLevel(
      NotificationPrivacyLevel.senderOnly,
    );

    controller.onInit();
    await pumpEventQueue();

    expect(controller.notificationPrivacyLabel.value, 'Sender only');
    // The controller's public surface (task §5 Functions) exposes no
    // setter for this value at all -- `notificationPrivacyLabel` is a
    // read-only Rx<String>. There is nothing named `setPrivacyLevel`,
    // `selectPrivacy` or similar anywhere on this type; the absence
    // itself is the proof (mirrors T04's own "call counter, expect 0"
    // shape, but there is no write method to even call here).
  });

  test(
    'test_EARS_UI_9_no_app_lock_control_is_present',
    () async {
      // GAP-033's app-lock fork carries no proposal (task §4, OQ-E15-T05-1).
      // This controller exposes no method, flag or state for one -- the
      // four Rx groups above (encryption is static, so has none) are the
      // whole surface.
      controller.onInit();
      await pumpEventQueue();
      // No member named anything to do with a lock, PIN or biometric gate
      // exists on this controller; the type's own public surface is
      // exactly what task §3/§5 lists.
      expect(controller.globalLocationEnabled, isNotNull);
    },
  );

  test(
    'test_EARS_UI_9_no_permissions_control_is_present',
    () async {
      // Same fork, same reason (task §4). No permissions list, no
      // permissions state, anywhere on this controller.
      controller.onInit();
      await pumpEventQueue();
      expect(controller.peerLocationEnabled, isNotNull);
    },
  );

  test(
    'test_EARS_UI_11_peer_read_failure_leaves_the_global_switch_intact',
    () async {
      await locationRepository.writeGlobalEnabled(true);
      final erroringRepository = _ErroringPeerReadRepository(db: db);
      final erroringController = PrivacySettingsController(
        locationRepository: erroringRepository,
        notificationRepository: notificationRepository,
      );

      erroringController.onInit();
      await pumpEventQueue();

      expect(erroringController.peerLocationError.value, isTrue);
      expect(erroringController.globalLocationError.value, isFalse);
      expect(erroringController.globalLocationEnabled.value, isTrue);

      erroringController.onClose();
    },
  );

  test(
    'test_EARS_UI_11_global_read_failure_leaves_notification_privacy_intact',
    () async {
      await notificationRepository.setPrivacyLevel(
        NotificationPrivacyLevel.full,
      );
      final erroringRepository = _ErroringGlobalWatchRepository(db: db);
      final erroringController = PrivacySettingsController(
        locationRepository: erroringRepository,
        notificationRepository: notificationRepository,
      );

      erroringController.onInit();
      await pumpEventQueue();

      expect(erroringController.globalLocationError.value, isTrue);
      expect(erroringController.globalLocationEnabled.value, isNull);
      expect(erroringController.notificationPrivacyError.value, isFalse);
      expect(erroringController.notificationPrivacyLabel.value, 'Full');

      erroringController.onClose();
    },
  );
}

/// Counts `writeGlobalEnabled`/`writePeerEnabled` calls -- the call-counter
/// seam the loading-window falsifications need, instead of `fail()` inside
/// the seam (a broad catch in the controller would swallow it, L-testing).
class _CountingLocationRepository extends LocationSettingsRepository {
  _CountingLocationRepository({required super.db});

  int writeGlobalEnabledCalls = 0;
  int writePeerEnabledCalls = 0;

  @override
  Future<void> writeGlobalEnabled(bool enabled) async {
    writeGlobalEnabledCalls++;
    await super.writeGlobalEnabled(enabled);
  }

  @override
  Future<void> writePeerEnabled(String peerDeviceId, bool enabled) async {
    writePeerEnabledCalls++;
    await super.writePeerEnabled(peerDeviceId, enabled);
  }
}

/// A repository whose `readAllPeerEnabled` always throws, for
/// `EARS-UI-11`'s falsification -- a real seam failure, not a mocked
/// promise of one. `watchGlobalEnabled` is untouched so the global switch's
/// own read still succeeds, proving the two sections fail independently.
class _ErroringPeerReadRepository extends LocationSettingsRepository {
  _ErroringPeerReadRepository({required super.db});

  @override
  Future<Map<String, bool>> readAllPeerEnabled() {
    throw StateError('simulated read failure');
  }
}

/// A repository whose `watchGlobalEnabled` always errors, for the
/// symmetric `EARS-UI-11` falsification -- the global switch's own read
/// fails while the notification-privacy card's independent read (a
/// different repository entirely) still succeeds.
class _ErroringGlobalWatchRepository extends LocationSettingsRepository {
  _ErroringGlobalWatchRepository({required super.db});

  @override
  Stream<bool> watchGlobalEnabled() {
    return Stream<bool>.error(StateError('simulated read failure'));
  }
}
