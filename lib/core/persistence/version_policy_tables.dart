// core/persistence -- version-policy local offline cache (E14-T01).
//
// `FR-VER-008`: cache the last known valid version policy locally for
// offline use; on reconnect, fetch and re-evaluate. Single-row table,
// `id` always `1`, the same "exactly one settings row" shape as
// `StoragePolicySettings` (E08-T01), `LocationSettings` (E09-T01) and
// `NotificationPreferences` (E10-T02) -- unlike those tables, this task's
// migration inserts NO default row on `onCreate`/`onUpgrade` (task §5,
// §3): a fresh device has no policy to seed from, and an absent row means
// "never successfully fetched", a real and distinct state
// `VersionPolicyService.cached()` must be able to return (`null`), not a
// gap the app papers over with a made-up default.
//
// This file only declares shape: no Firebase I/O, no state-machine logic
// (`E14-T02`'s own job), no signature verification (`E14-T05`'s own job) --
// `signature` is stored as raw, unverified text (task §4).
import 'package:drift/drift.dart';

/// The one cached copy of `config/version_policy`
/// (`FirebasePaths.versionPolicy`), keyed by the fixed row id `1`.
@DataClassName('VersionPolicyCacheRow')
class VersionPolicyCache extends Table {
  IntColumn get id => integer()();

  IntColumn get minimumSupportedBuild => integer()();

  IntColumn get currentBuild => integer()();

  IntColumn get updateAvailableBuild => integer()();

  TextColumn get signature => text()();

  /// Epoch-millis `updatedAt` from the remote policy payload -- the
  /// server/ops-published value, not this device's own fetch time.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
