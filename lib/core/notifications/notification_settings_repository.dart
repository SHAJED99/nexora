// core/notifications -- the single reader/writer of
// `notification_category_settings` / `notification_preferences` (E10-T02,
// ADR-0001).
//
// This is a settings store only. It does not post, build or suppress any
// notification -- `E10-T03` is the only consumer of what this repository
// returns -- and it never imports
// `lib/core/notifications/notification_service.dart` (task §4). It also
// never decrypts anything, for any reason (task §4).
//
// Fail-open vs fail-safe are *deliberately different* here (task §6): an
// unknown **category** resolves to enabled (a missing notification is worse
// than an extra one); an unknown **privacy level** resolves to `hidden` (a
// leaked preview is worse than a vague one). Do not unify them.
library;

import 'package:drift/drift.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/notification_tables.dart';

/// The only reader/writer of `notification_category_settings` and
/// `notification_preferences` (task §3). `E10-T02`'s migration seeds nine
/// enabled category rows plus the `hidden` singleton on both `onCreate` and
/// `onUpgrade`, but this repository never assumes that invariant holds --
/// every read resolves an absent row explicitly rather than trusting the
/// migration to have run (task §5 contract: "never `full` by accident").
class NotificationSettingsRepository {
  NotificationSettingsRepository({required this.db});

  /// The app's `AppDatabase` instance (injected, never constructed here --
  /// matches `StorageSettingsRepository`'s own precedent, E08-T05).
  final AppDatabase db;

  /// `notification_preferences`'s single-row table id (`notification_tables.dart`,
  /// `NotificationPreferences.id`, "always `0`").
  static const int _preferencesRowId = 0;

  /// The stored flag for [category]; `true` when no row exists -- fail-open
  /// for a category added to `NotificationCategory` after this migration
  /// ran (task §5 contract).
  Future<bool> isEnabled(NotificationCategory category) async {
    final row = await (db.select(db.notificationCategorySettings)
          ..where((t) => t.category.equals(category.name)))
        .getSingleOrNull();
    return row?.enabled ?? true;
  }

  /// Upserts [category]'s flag (task §5 contract).
  Future<void> setEnabled(NotificationCategory category, bool enabled) async {
    await db.into(db.notificationCategorySettings).insertOnConflictUpdate(
          NotificationCategorySettingsCompanion.insert(
            category: category.name,
            enabled: Value(enabled),
          ),
        );
  }

  /// The singleton row's privacy level; `hidden` when the row is missing or
  /// the stored string is unrecognised -- never `full` by accident, never
  /// throws (task §5 contract, EARS-NOTIFY-4).
  Future<NotificationPrivacyLevel> privacyLevel() async {
    final row = await (db.select(db.notificationPreferences)
          ..where((t) => t.id.equals(_preferencesRowId)))
        .getSingleOrNull();
    final stored = row?.privacyLevel;
    if (stored == null) return NotificationPrivacyLevel.hidden;
    return NotificationPrivacyLevel.values
        .firstWhere((v) => v.name == stored,
            orElse: () => NotificationPrivacyLevel.hidden);
  }

  /// Upserts the singleton privacy-level row (task §5 contract).
  Future<void> setPrivacyLevel(NotificationPrivacyLevel level) async {
    await db.into(db.notificationPreferences).insertOnConflictUpdate(
          NotificationPreferencesCompanion.insert(
            id: const Value(_preferencesRowId),
            privacyLevel: Value(level.name),
          ),
        );
  }

  /// Drift-backed watch of [category]'s flag, so a future settings screen
  /// needs no polling (task §5 contract). Emits `true` for the same
  /// fail-open reason [isEnabled] does when no row exists yet.
  Stream<bool> watchEnabled(NotificationCategory category) {
    return (db.select(db.notificationCategorySettings)
          ..where((t) => t.category.equals(category.name)))
        .watchSingleOrNull()
        .map((row) => row?.enabled ?? true);
  }
}
