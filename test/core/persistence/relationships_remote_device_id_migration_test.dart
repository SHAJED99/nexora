// Schema migration test (E04-B12, Option A part 1/2). Every widget/unit
// test uses AppDatabase.forTesting(NativeDatabase.memory()), which always
// takes the onCreate path -- nothing else exercises onUpgrade. This test
// builds a v20 database by hand (pre-E04-B12 schema: `relationships` with
// no `remote_self_device_id` column) and confirms opening it with
// AppDatabase migrates it to v21 additively -- no existing row lost or
// altered, and the new column usable afterward. Follows the exact pattern
// `test/core/persistence/relationships_migration_test.dart` (E02-T01) and
// `test/core/persistence/crypto_migration_test.dart` (the `from >= 6 &&
// from < 7` addColumn step) already established for a v(n)->v(n+1) test
// with no table rebuild needed.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
    'test_E04_B12_migration_v20_to_v21_adds_remote_self_device_id_column',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      // The exact pre-E04-B12 (v20) `relationships` schema -- no
      // `remote_self_device_id` column.
      raw.execute('''
        CREATE TABLE device_identities (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          signed_in INTEGER NOT NULL DEFAULT 0,
          signed_in_at INTEGER NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          account_uid TEXT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE relationships (
          device_id TEXT NOT NULL,
          state TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (device_id)
        );
      ''');
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('pre-b12-device', 1);",
      );
      // A real pre-existing relationship row an upgrading install could
      // already hold -- must survive untouched, per the task's own
      // "existing rows are unaffected" contract (no backfill).
      raw.execute(
        "INSERT INTO relationships (device_id, state, updated_at) "
        "VALUES ('AA:BB:CC:DD:EE:01', 'trusted', 5000);",
      );
      raw.userVersion = 20;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Opening at target schemaVersion 21 triggers onUpgrade(from: 20, to: 21).
      final rows = await db.select(db.relationships).get();
      expect(rows, hasLength(1));
      final existingRow = rows.single;
      expect(existingRow.deviceId, 'AA:BB:CC:DD:EE:01');
      expect(existingRow.state, 'trusted');
      // Drift's default DateTimeColumn representation stores seconds since
      // epoch (matching `device_identities.created_at`'s own
      // `strftime('%s', 'now')` default elsewhere in this file) -- the raw
      // `5000` inserted above is therefore 5000 SECONDS, not milliseconds.
      expect(
        existingRow.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(5000 * 1000),
      );
      // The pre-existing row was NOT backfilled -- it simply has not
      // announced yet (task file §2).
      expect(existingRow.remoteSelfDeviceId, null);

      // The new column is genuinely usable after migration, not merely
      // present as an inert shell.
      await (db.update(db.relationships)
            ..where((t) => t.deviceId.equals('AA:BB:CC:DD:EE:01')))
          .write(
        const RelationshipsCompanion(
          remoteSelfDeviceId: Value('real-self-device-id-123'),
        ),
      );
      final updated = await (db.select(db.relationships)
            ..where((t) => t.deviceId.equals('AA:BB:CC:DD:EE:01')))
          .getSingle();
      expect(updated.remoteSelfDeviceId, 'real-self-device-id-123');
      // The rest of the row is untouched by that targeted write.
      expect(updated.state, 'trusted');

      // A brand-new row can also be inserted with the column populated
      // directly (identity_announce.dart's own first-contact path).
      await db.into(db.relationships).insertOnConflictUpdate(
            RelationshipsCompanion.insert(
              deviceId: 'BB:CC:DD:EE:FF:02',
              state: 'unknown',
              updatedAt: DateTime.now(),
              remoteSelfDeviceId: const Value('brand-new-peer-id'),
            ),
          );
      final newRow = await (db.select(db.relationships)
            ..where((t) => t.deviceId.equals('BB:CC:DD:EE:FF:02')))
          .getSingle();
      expect(newRow.remoteSelfDeviceId, 'brand-new-peer-id');

      // Pre-existing, unrelated data survived the upgrade untouched.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities, hasLength(1));
      expect(identities.single.deviceId, 'pre-b12-device');
    },
  );
}
