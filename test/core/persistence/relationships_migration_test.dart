// Schema migration test (E02-T01). Every widget/unit test uses
// AppDatabase.forTesting(NativeDatabase.memory()), which always takes the
// onCreate path — nothing else exercises onUpgrade. This test builds a v2
// database by hand (pre-E02-T01 schema, no `relationships` table) and
// confirms opening it with AppDatabase migrates it to v3 additively — no
// existing rows lost, and the new table usable afterward.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/trust/domain/relationship.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
    'v2 -> v3 migration adds relationships table without losing existing rows',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      // The exact v2 schema (pre-E02-T01): device_identities with
      // account_uid, no relationships table.
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
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('pre-migration-device', 0);",
      );
      raw.userVersion = 2;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Opening at target schemaVersion 3 triggers onUpgrade(from: 2, to: 3).
      final existingIdentity = await db.latestDeviceIdentity();
      expect(existingIdentity, isNotNull);
      expect(existingIdentity!.deviceId, 'pre-migration-device');

      // The new relationships table is usable after migration.
      await db.into(db.relationships).insertOnConflictUpdate(
            RelationshipsCompanion.insert(
              deviceId: 'device-post-migration',
              state: RelationshipState.trusted.name,
              updatedAt: DateTime.now(),
            ),
          );
      final row = await (db.select(db.relationships)
            ..where((t) => t.deviceId.equals('device-post-migration')))
          .getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.state, RelationshipState.trusted.name);
    },
  );
}
