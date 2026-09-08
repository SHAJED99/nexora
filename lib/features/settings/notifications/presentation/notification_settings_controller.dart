// features/settings/notifications/presentation -- FR-NOTIFY-003's screen
// controller (E15-T04). Binds to `NotificationSettingsRepository`'s own
// streams; holds no second copy of any preference and no defaulting rule of
// its own (task §2) -- if a widget and the repository ever disagree, the
// repository wins and the widget is the bug.
import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/notification_tables.dart'
    show NotificationPrivacyLevel;

/// FR-NOTIFY-003's screen controller: nine category toggles (task §2's
/// "nine, not ten" rule -- see [categories]'s own doc) plus the
/// FR-NOTIFY-002 privacy-level selector. Every value this controller exposes
/// comes straight from [repository] -- no local defaulting, no second copy.
class NotificationSettingsController extends GetxController {
  NotificationSettingsController({required this.repository});

  final NotificationSettingsRepository repository;

  /// The nine user-facing values, in `settings-notifications.md`'s stated
  /// order (task §5 contract: "one place the nine-not-ten rule is
  /// expressed"). `NotificationCategory.backgroundService` never appears
  /// here -- task §2/§4, `notification_tables.dart`'s own header: Android
  /// requires that notification whenever the foreground service runs, so it
  /// is not a user preference.
  static const List<NotificationCategory> categories = [
    NotificationCategory.message,
    NotificationCategory.voiceMessage,
    NotificationCategory.ptt,
    NotificationCategory.incomingCall,
    NotificationCategory.connectionRequest,
    NotificationCategory.trustRequest,
    NotificationCategory.groupEvent,
    NotificationCategory.securityEvent,
    NotificationCategory.storageWarning,
  ];

  /// Per-category enabled state, `null` until that category's own
  /// `watchEnabled` stream has emitted at least once -- the `loading` state
  /// (task §5: "row states unpopulated", never a spinner).
  final Map<NotificationCategory, Rx<bool?>> _categoryEnabled = {
    for (final category in categories) category: Rx<bool?>(null),
  };

  /// `true` once any one category's `watchEnabled` stream has emitted an
  /// error. NT22 replaces every row in the Alerts card only when this is
  /// set -- the Privacy card is a separate read/subscription and is never
  /// affected by an Alerts-card failure (task §5, NT22; EARS-UI-11).
  final RxBool categoriesError = false.obs;

  /// The current privacy level, `null` until the first read completes (the
  /// `loading` state for the Privacy card).
  final Rx<NotificationPrivacyLevel?> privacy = Rx<NotificationPrivacyLevel?>(
    null,
  );

  /// `true` once the privacy read has failed. Independent of
  /// [categoriesError] -- a failure in one card never touches the other
  /// (task §5, NT22; EARS-UI-11).
  final RxBool privacyError = false.obs;

  final List<StreamSubscription<bool>> _subscriptions = [];

  @override
  void onInit() {
    super.onInit();
    for (final category in categories) {
      _subscriptions.add(
        repository
            .watchEnabled(category)
            .listen(
              (enabled) => _categoryEnabled[category]!.value = enabled,
              onError: (Object _, StackTrace _) {
                categoriesError.value = true;
              },
            ),
      );
    }
    unawaited(_loadPrivacy());
  }

  Future<void> _loadPrivacy() async {
    try {
      privacy.value = await repository.privacyLevel();
    } catch (_) {
      privacyError.value = true;
    }
  }

  /// The rendered state for [category]; `null` while loading (task §5's
  /// `loading` state -- the row's own state is left unpopulated, never
  /// guessed).
  bool? isEnabled(NotificationCategory category) =>
      _categoryEnabled[category]?.value;

  /// FR-NOTIFY-003's write path (task §5 contract). No local state is
  /// mutated here -- [repository]'s stream is what re-renders the row
  /// (EARS-NOTIFY-16).
  Future<void> toggle(NotificationCategory category) async {
    final current = _categoryEnabled[category]!.value ?? true;
    await repository.setEnabled(category, !current);
  }

  /// FR-NOTIFY-002's write path. `full` is storable at the repository
  /// layer, but this screen never writes it (EARS-NOTIFY-17,
  /// `settings-notifications.md`'s "not as a working feature" boundary) --
  /// storing it is not the same as honouring it (task §5 contract,
  /// `notification_tables.dart`'s own header).
  Future<void> selectPrivacy(NotificationPrivacyLevel level) async {
    if (level == NotificationPrivacyLevel.full) return;
    await repository.setPrivacyLevel(level);
    privacy.value = level;
  }

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.onClose();
  }
}
