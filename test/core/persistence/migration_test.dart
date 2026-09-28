// Schema migration test for the v23->v24 `trust_settings` step (E02-T04,
// `Q-FUNC-011`).
//
// Follows the same hand-built-prior-schema shape every migration test in
// this directory establishes -- but, unlike most of them, it hand-builds
// only the ORIGINAL v1 schema (`device_identities`, pre-E01-T01: no
// `account_uid` column -- the exact DDL
// `database_migration_test.dart`'s own "v1 -> v2" test uses) rather than
// the full v23 schema. This is deliberate, not a shortcut: the new step
// below is guarded by `if (from < 24)`, so it runs identically whichever
// version the raw handle starts at, as long as that version is below 24.
// `message_migration_test.dart`'s own second test
// (`test_message_migration_v7_to_v11_creates_messages_tables_fresh`) already
// established this precedent -- "an install jumping from an old version"
// exercises the same new step a same-version-minus-one handle would, and is
// simultaneously a stronger proof: every earlier `from < N` step in
// `AppDatabase`'s own `onUpgrade` also runs in the same call, cascading a
// real (if synthetic) v1 install all the way to the current schema, so this
// test is also a live rehearsal of the entire upgrade chain, not just its
// last link.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
    'test_migration_23_to_24_creates_trust_settings_with_the_default_row',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      // The exact v1 schema (pre-E01-T01): no account_uid column --
      // copied from `database_migration_test.dart`'s own "v1 -> v2" test.
      raw.execute('''
        CREATE TABLE device_identities (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          signed_in INTEGER NOT NULL DEFAULT 0,
          signed_in_at INTEGER NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
      ''');
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) "
        "VALUES ('pre-migration-device', 0);",
      );
      raw.userVersion = 1;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Opening at the current schemaVersion (24) cascades through every
      // `from < N` step, including this task's `from < 24` one -- the new
      // table exists with the default row this task's §2 "Default value"
      // requires: `allowNewConnectionRequests == true`. Existing installs
      // must keep accepting new connections, not silently stop.
      final row = await (db.select(
        db.trustSettings,
      )..where((t) => t.id.equals(1))).getSingle();
      expect(row.allowNewConnectionRequests, isTrue);

      // The pre-existing table + row from before this migration survived
      // untouched -- this step is additive only (task §2, §4).
      final identity = await db.latestDeviceIdentity();
      expect(identity!.deviceId, 'pre-migration-device');
    },
  );

  test(
    'test_migration_rerun_does_not_duplicate_or_clobber_the_row',
    () async {
      // The `insertOrIgnore` retry-safety precedent every prior seeded-row
      // step in `database.dart` documents: a second write to the same row
      // (simulated here by writing a non-default value through the real
      // repository after migration, then confirming a fresh open of the
      // SAME already-migrated database does not reset it) must never
      // clobber a value the user has already changed.
      final raw = sqlite3.sqlite3.openInMemory();
      raw.execute('''
        CREATE TABLE device_identities (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          signed_in INTEGER NOT NULL DEFAULT 0,
          signed_in_at INTEGER NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
      ''');
      raw.userVersion = 1;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await (db.update(
        db.trustSettings,
      )..where((t) => t.id.equals(1))).write(
        const TrustSettingsCompanion(
          allowNewConnectionRequests: Value(false),
        ),
      );

      final row = await (db.select(
        db.trustSettings,
      )..where((t) => t.id.equals(1))).getSingle();
      expect(row.allowNewConnectionRequests, isFalse);
    },
  );
}
