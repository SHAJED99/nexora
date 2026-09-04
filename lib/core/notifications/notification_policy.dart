// core/notifications — the one place enablement and privacy are applied
// (E10-T03). Every notification source (T03-T07) constructs a
// `NotificationFacts` and hands it to this policy; no source decides for
// itself whether/how to post (task file §3).
//
// Pure and injectable: the only I/O this file performs is the
// `NotificationSettingsRepository` read (E10-T02). It never touches a
// platform channel and never imports `crypto_stub.dart` or anything else
// that can decrypt — see the task's own §4 ("does NOT decrypt, and does NOT
// add a decrypt path to any repository").
library;

import 'dart:convert';

import 'generated/notification_api.g.dart'
    show NotificationCategory, NotificationRequest;
import 'notification_settings_repository.dart';
import '../observability/observability_service.dart';
import '../persistence/notification_tables.dart' show NotificationPrivacyLevel;

/// The non-secret identifiers a notification source could gather for one
/// event (task file §5 contract). **No field may hold plaintext, and none
/// is nullable-because-decryption-failed** — a source that cannot fill a
/// field leaves it null and the policy degrades the copy accordingly.
class NotificationFacts {
  const NotificationFacts({
    required this.category,
    required this.conversationId,
    required this.peerDeviceId,
    required this.peerDisplayName,
    required this.stableId,
  });

  final NotificationCategory category;
  final String conversationId;
  final String? peerDeviceId;

  /// A name safe to show at `senderOnly` privacy — e.g. the device id that
  /// already stands in for a display name elsewhere in this app
  /// (`design/gaps.md` GAP-003: `RelationshipRepository` has no
  /// display-name column). Never plaintext extracted from message content.
  final String? peerDisplayName;

  /// A stable id derived from [conversationId] (see [stableNotificationId])
  /// so a second event for the same conversation replaces the prior
  /// notification instead of stacking a new one (task file §3).
  final int stableId;
}

/// Deterministic across runs and Dart SDK versions — an FNV-1a 32-bit hash
/// of [key]'s UTF-8 bytes, masked into the non-negative 31-bit range
/// Android's `Int`-typed notification id comfortably holds. Two conversation
/// ids can in principle collide (task file §6 risk); the accepted worst case
/// is two threads sharing one notification slot — a crash is not acceptable,
/// a shared slot is.
int stableNotificationId(String key) {
  const int fnvOffsetBasis = 0x811c9dc5;
  const int fnvPrime = 0x01000193;
  int hash = fnvOffsetBasis;
  for (final byte in utf8.encode(key)) {
    hash ^= byte;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// The one place enablement and privacy are applied (task file §3) — no
/// source decides for itself. [resolve]'s only I/O is [settings]; it never
/// touches a platform channel and never invokes anything that can decrypt.
class NotificationPolicy {
  NotificationPolicy({required this.settings});

  final NotificationSettingsRepository settings;

  /// Resolves [facts] into a request to post, or `null` when the category is
  /// disabled (EARS-NOTIFY-6). `full` privacy has no supported mechanism
  /// today (`OQ-E10-2` — plaintext is decrypted only in the screen layer,
  /// `E06-T09.md:64-68`) and is downgraded to `senderOnly`'s shape, recorded
  /// via one non-sensitive log call — disclosed, never silently approximated
  /// as `full` and never silently dropped.
  Future<NotificationRequest?> resolve(NotificationFacts facts) async {
    final bool enabled = await settings.isEnabled(facts.category);
    if (!enabled) return null;

    NotificationPrivacyLevel level = await settings.privacyLevel();
    if (level == NotificationPrivacyLevel.full) {
      ObservabilityService.instance.log(
        LogLevel.info,
        'notification.privacy_full_downgraded_to_sender_only',
      );
      level = NotificationPrivacyLevel.senderOnly;
    }

    final _Copy copy = _copyFor(facts, level);
    return NotificationRequest(
      id: facts.stableId,
      category: facts.category,
      title: copy.title,
      body: copy.body,
      ongoing: false,
    );
  }

  /// Copy per task file §5's table. Only `message` is implemented by this
  /// task — `full` is already folded into `senderOnly` by [resolve] before
  /// this is reached, so this method only ever sees `hidden` or
  /// `senderOnly`. Every other category is a future task's own class
  /// (T04-T07, none of which is wired to this policy by this task, and none
  /// of which has approved copy — `OQ-E10-1`); an unrecognised category
  /// degrades to the same content-free shape rather than throwing or
  /// inventing a class-specific string this task does not own.
  _Copy _copyFor(NotificationFacts facts, NotificationPrivacyLevel level) {
    switch (facts.category) {
      case NotificationCategory.message:
        if (level == NotificationPrivacyLevel.hidden) {
          return const _Copy('NEXORA', 'New message');
        }
        return _Copy(facts.peerDisplayName ?? 'NEXORA', 'New message');
      default:
        return const _Copy('NEXORA', 'Notification');
    }
  }
}

class _Copy {
  const _Copy(this.title, this.body);
  final String title;
  final String body;
}
