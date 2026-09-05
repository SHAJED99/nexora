// Pigeon schema — Dart<->Kotlin notification boundary (ADR-0004, FR-PLAT-003,
// FR-NOTIFY-001).
//
// This file is the source of truth for the generated bindings; never hand-
// edit `lib/core/notifications/generated/notification_api.g.dart` or the
// generated Kotlin output — regenerate from here instead, same convention as
// Drift's `.g.dart` files (docs/conventions.md). Same shape as
// `pigeons/transport.dart` (E04-T03a), deliberately: this is the
// notification twin of that transport boundary.
//
// Regenerate with:
//   dart run pigeon \
//     --input pigeons/notifications.dart \
//     --dart_out lib/core/notifications/generated/notification_api.g.dart \
//     --kotlin_out android/app/src/main/kotlin/com/nexora/nexora/notifications/NotificationApi.g.kt \
//     --kotlin_package com.nexora.nexora.notifications
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/notifications/generated/notification_api.g.dart',
    dartPackageName: 'nexora',
    kotlinOut:
        'android/app/src/main/kotlin/com/nexora/nexora/notifications/NotificationApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.nexora.nexora.notifications'),
  ),
)

/// The notification classes FR-NOTIFY-001 names, one Android notification
/// channel per category (created once at attach, `NotificationChannels.kt`).
/// `backgroundService` is a tenth category for `E10-T08`'s mandatory ongoing
/// foreground-service notification — declared here so T08 adds no channel
/// plumbing of its own. This task does not decide *when* any category is
/// used (E10-T01 §4) — that is T03-T08.
enum NotificationCategory {
  message,
  voiceMessage,
  ptt,
  incomingCall,
  connectionRequest,
  trustRequest,
  groupEvent,
  securityEvent,
  storageWarning,
  backgroundService,
}

/// A single notification post/replace request. [id] is stable per logical
/// notification — re-posting the same [id] replaces the prior post (Android
/// `NotificationManagerCompat.notify(id, ...)` semantics), it is not an
/// auto-incrementing counter.
class NotificationRequest {
  NotificationRequest({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.ongoing,
  });

  final int id;
  final NotificationCategory category;
  final String title;
  final String body;

  /// True only for `backgroundService` — an ongoing notification the user
  /// cannot swipe away, per Android's foreground-service contract (E10-T08).
  final bool ongoing;
}

/// Host-side API: Dart calls into native Kotlin.
@HostApi()
abstract class NotificationApi {
  /// Idempotent: creates one `NotificationChannel` per [NotificationCategory]
  /// if it does not already exist. Safe to call on every attach.
  void ensureChannels();

  /// True when notifications may be posted right now. On API < 33 (no
  /// runtime permission exists) this is always true; on API 33+ it reflects
  /// whether `POST_NOTIFICATIONS` has been granted.
  bool hasPermission();

  /// Triggers the system permission prompt on API 33+. No-op on API < 33.
  /// The result reaches Dart via `NotificationEventsApi.onPermissionResult`.
  void requestPermission();

  /// Posts (or replaces, by [NotificationRequest.id]) a notification.
  /// Returns false — and does not throw — when the host refused to post
  /// (no permission, or the user disabled notifications for the app/channel).
  bool post(NotificationRequest request);

  /// Withdraws a previously posted notification by id. No-op if [id] was
  /// never posted or was already withdrawn.
  void cancel(int id);
}

/// Flutter-side API: native Kotlin calls into Dart.
@FlutterApi()
abstract class NotificationEventsApi {
  /// Fired once the runtime permission prompt (`requestPermission()`)
  /// resolves, forwarded from `MainActivity.onRequestPermissionsResult`.
  void onPermissionResult(bool granted);

  /// Fired when the user taps a posted notification. Delivered to Dart and
  /// otherwise unconsumed as of E10-T01 (`OQ-E10-T01-1`) — no approved design
  /// says where a tap should land.
  void onNotificationTapped(int id, NotificationCategory category);
}
