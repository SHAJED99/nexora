// core/persistence -- notification preference tables (ADR-0001, E10-T02).
//
// `FR-NOTIFY-001` gives nine user-facing notification categories, each
// independently switchable, defaulting to enabled -- `backgroundService`
// (the tenth `NotificationCategory` value, `E10-T01`'s Pigeon boundary) is
// deliberately absent here: Android requires that notification whenever the
// foreground service runs, so it is not a user preference (task §2, §4).
//
// `FR-NOTIFY-002` gives one privacy level, closed set, defaulting to the
// conservative reading (`hidden`) -- and that default is load-bearing, not
// timid: `full` (sender name + message preview) has no supported mechanism
// today, because plaintext is decrypted only in the screen layer
// (`E06-T09.md:64-68`) and a background dispatcher (this epic) is exactly
// the kind of caller that constraint forbids. Storing the enum is not the
// same as honouring it (task §2) -- `E10-T03` is the consumer that decides
// what to do with a stored `full`.
//
// This file only declares shape: no notification is posted, built or
// suppressed here, and nothing here decrypts anything, ever (task §4).
import 'package:drift/drift.dart';

/// `FR-NOTIFY-002`'s three privacy levels, closed set, stored by `.name`
/// (docs/conventions.md "Enums": never an integer index).
///
/// - `full` -- sender name and message preview. No supported mechanism
///   today (see file header); stored as a value, not honoured by anything
///   this task builds.
/// - `senderOnly` -- who, not what.
/// - `hidden` -- neither ("New message"). The default, and the fail-safe
///   resolution for anything unrecognised (task §5, §6: an unknown
///   privacy level must resolve to `hidden`, never guess upward).
enum NotificationPrivacyLevel { full, senderOnly, hidden }

/// One row per user-facing `NotificationCategory`
/// (`lib/core/notifications/generated/notification_api.g.dart`), keyed by
/// the enum's `.name` string. An absent row means "not yet seeded" (e.g. a
/// category added to the enum after this migration ran) and the repository
/// treats that as **enabled** -- fail-open, because a missing notification
/// is worse than an extra one (task §6). This is the opposite fail
/// direction from [NotificationPreferences.privacyLevel] below, and that
/// asymmetry is deliberate, not an inconsistency.
@DataClassName('NotificationCategorySettingRow')
class NotificationCategorySettings extends Table {
  /// A `NotificationCategory.name` string. Never `backgroundService` (task
  /// §2) -- that category is not user-switchable and no row is seeded for
  /// it.
  TextColumn get category => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {category};
}

/// Single-row table (`id` always `0`) holding `FR-NOTIFY-002`'s privacy
/// level -- the same "exactly one global setting exists" shape as
/// `StoragePolicySettings` (E08-T01) and `LocationSettings` (E09-T01). The
/// migration inserts the one default row with `privacyLevel == 'hidden'` on
/// both `onCreate` and `onUpgrade` (task §5) so no reader ever has to cope
/// with an absent row -- but the repository still resolves a missing row to
/// `hidden` rather than assuming that invariant holds (task §5 contract:
/// "never `full` by accident").
@DataClassName('NotificationPreferenceRow')
class NotificationPreferences extends Table {
  IntColumn get id => integer()();

  TextColumn get privacyLevel =>
      text().withDefault(const Constant('hidden'))();

  @override
  Set<Column> get primaryKey => {id};
}
