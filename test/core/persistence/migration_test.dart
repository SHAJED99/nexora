// Whole-upgrade-chain tests covering the v24 `trust_settings` step
// (E02-T04, `Q-FUNC-011`) as the LAST link of a full v1 -> v24 cascade.
//
// **These are not the v23 -> v24 verification.** That one lives in
// `migration_v23_to_v24_verification_test.dart`, which builds a database
// that really is at 23 and upgrades only the final step -- the production
// path for an existing install. The tests here start a raw handle at
// `userVersion = 1` and let every `from < N` step run in one call, so what
// they actually prove is broader but different: that a very old install
// cascades all the way to the current schema and still lands on the
// `trust_settings` default.
//
// Both names below were corrected on 2026-09-28 after a review found they
// overstated what the bodies do (the first said "23_to_24" while starting
// at 1; the second said it confirmed "a fresh open of the SAME
// already-migrated database" while never re-opening anything). The bodies
// are unchanged and still worth keeping -- the cascade rehearsal is real
// coverage that the v23-only test deliberately does not provide. Only the
// claims were brought back in line with the code.
//
// Shape follows `message_migration_test.dart`'s own second test
// (`test_message_migration_v7_to_v11_creates_messages_tables_fresh`), the
// established precedent for "an install jumping from an old version".
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
    'test_migration_v1_cascade_to_v24_creates_trust_settings_with_the_'
    'default_row',
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
    'test_migration_leaves_the_seeded_row_writable_to_a_non_default_value',
    () async {
      // What this actually proves: after the cascade has seeded the row,
      // a write of `false` through the normal update path sticks on the
      // SAME open handle. That is worth having -- it catches a seeded row
      // that is somehow read-only or absent -- but it is NOT re-entrancy
      // coverage, because nothing here closes and re-opens the database.
      //
      // The `insertOrIgnore` retry-safety property (a genuinely fresh open
      // of an already-migrated database must not reset a user's
      // deliberate `false` back to the default) is proved in
      // `migration_v23_to_v24_verification_test.dart`'s second test, which
      // uses a file-backed database precisely so it can close and re-open.
      // An in-memory handle cannot survive a close, which is why this test
      // never made that claim true.
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
