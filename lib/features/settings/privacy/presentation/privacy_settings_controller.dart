// features/settings/privacy/presentation -- FR-SEC-005's screen controller
// (E15-T05). Three cards, one writable (task §2):
//
// - Encryption (PV3-PV8) is static text -- ADR-0003's accepted protocol
//   choice, never a read, never a write, never a control.
// - Notification privacy (PV9-PV12) is READ ONLY here: [notificationPrivacyLabel]
//   is a getter with no setter. PV12 only navigates to
//   `/settings/notifications`; `E15-T04`'s screen is the one writer of that
//   preference (task §2 -- "one setting, one writer").
// - Location sharing (PV13-PV21) is the only writable surface:
//   [globalLocationEnabled]/[setGlobalLocation] (FR-LOC-001) and
//   [peerLocationEnabled]/[setPeerLocation] (FR-LOC-002), both delegating to
//   `LocationSettingsRepository` -- the sole source of truth. This screen
//   holds no second copy of a preference and no defaulting rule of its own
//   (task §2/§6): if a widget and a repository ever disagree, the
//   repository wins and the widget is the bug.
import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/notification_tables.dart'
    show NotificationPrivacyLevel;
import 'package:nexora/features/location/data/location_settings_repository.dart';

/// FR-SEC-005's screen controller.
class PrivacySettingsController extends GetxController {
  PrivacySettingsController({
    required this.locationRepository,
    required this.notificationRepository,
  });

  final LocationSettingsRepository locationRepository;
  final NotificationSettingsRepository notificationRepository;

  /// FR-LOC-001's global switch, `null` until `watchGlobalEnabled()` has
  /// emitted at least once -- the `loading` state (task §5: "values
  /// unpopulated", never a spinner).
  final Rx<bool?> globalLocationEnabled = Rx<bool?>(null);

  /// `true` once the global switch's own stream has emitted an error. Kept
  /// independent of [peerLocationError] and [notificationPrivacyError] --
  /// a failure in one section never touches another, and this switch's own
  /// last-known value is never cleared by a failed read of something else
  /// (task §5 `error` state; EARS-UI-11).
  final RxBool globalLocationError = false.obs;

  /// FR-LOC-002's per-peer map, keyed by `peerDeviceId`, `null` until
  /// `readAllPeerEnabled()`'s first read completes -- the `loading` state
  /// for the per-person list. A peer absent from the map has never
  /// configured a setting (`LocationSettingsRepository`'s own distinction,
  /// task §6); this screen renders only the peers present in the map
  /// (PV19, "one per peer with a location setting"). An empty, successfully
  /// loaded map is the `empty` state (PV20), not an error.
  final Rx<Map<String, bool>?> peerLocationEnabled = Rx<Map<String, bool>?>(
    null,
  );

  /// `true` once the per-peer read (or a re-read after a write) has failed.
  final RxBool peerLocationError = false.obs;

  /// PV11's read-only label -- `''` until the first read completes (the
  /// `loading` state for this row). No setter exists on this controller
  /// (task §4: PV12 navigates, it never writes `setPrivacyLevel`).
  final RxString notificationPrivacyLabel = ''.obs;

  /// `true` once the notification-privacy read has failed.
  final RxBool notificationPrivacyError = false.obs;

  StreamSubscription<bool>? _globalSubscription;

  @override
  void onInit() {
    super.onInit();
    _globalSubscription = locationRepository.watchGlobalEnabled().listen(
      (enabled) => globalLocationEnabled.value = enabled,
      onError: (Object _, StackTrace _) {
        globalLocationError.value = true;
      },
    );
    unawaited(_loadPeerLocations());
    unawaited(_loadNotificationPrivacy());
  }

  Future<void> _loadPeerLocations() async {
    try {
      final peers = await locationRepository.readAllPeerEnabled();
      peerLocationEnabled.value = peers;
    } catch (_) {
      peerLocationError.value = true;
    }
  }

  Future<void> _loadNotificationPrivacy() async {
    try {
      final level = await notificationRepository.privacyLevel();
      notificationPrivacyLabel.value = _labelFor(level);
    } catch (_) {
      notificationPrivacyError.value = true;
    }
  }

  static String _labelFor(NotificationPrivacyLevel level) {
    switch (level) {
      case NotificationPrivacyLevel.hidden:
        return 'Hidden';
      case NotificationPrivacyLevel.senderOnly:
        return 'Sender only';
      case NotificationPrivacyLevel.full:
        return 'Full';
    }
  }

  /// FR-LOC-001's write path (task §5 contract). While
  /// [globalLocationEnabled] has not yet emitted (still `null`, the
  /// `loading` state), the current value is genuinely unknown -- this
  /// screen holds no defaulting rule of its own (task §2), so writing here
  /// could silently clobber the real stored value before it is even known.
  /// Unknown state never writes, mirroring
  /// `NotificationSettingsController.toggle`'s own guard (this task's
  /// carried-forward F1 finding) -- the view additionally keeps the switch's
  /// own tap target inert (nullable `onTap`) while this is `null`, so the
  /// guard below is a backstop, not the only line of defence.
  Future<void> setGlobalLocation(bool enabled) async {
    if (globalLocationEnabled.value == null) return;
    await locationRepository.writeGlobalEnabled(enabled);
  }

  /// FR-LOC-002's write path. Same unknown-state guard as
  /// [setGlobalLocation] -- while [peerLocationEnabled] has not yet loaded,
  /// this screen does not know which peers exist yet and must not write.
  /// After a successful write, re-reads the whole map through
  /// `LocationSettingsRepository.readAllPeerEnabled` rather than mutating a
  /// local copy (task §6 risk note: "do not maintain a parallel local
  /// map").
  Future<void> setPeerLocation(String peerDeviceId, bool enabled) async {
    if (peerLocationEnabled.value == null) return;
    await locationRepository.writePeerEnabled(peerDeviceId, enabled);
    try {
      final peers = await locationRepository.readAllPeerEnabled();
      peerLocationEnabled.value = peers;
    } catch (_) {
      peerLocationError.value = true;
    }
  }

  @override
  void onClose() {
    _globalSubscription?.cancel();
    super.onClose();
  }
}
