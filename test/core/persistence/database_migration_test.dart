// Schema migration test (E01-T01 review note). Every widget/unit test uses
// AppDatabase.forTesting(NativeDatabase.memory()), which always takes the
// onCreate path — nothing else exercises onUpgrade. The device this task
// was manually verified on is at schema v1 right now, so the v1->v2
// migration (adding `account_uid`) runs for real on its next launch. This
// test builds a v1 database by hand (the pre-E01-T01 schema, no
// account_uid column) and confirms opening it with AppDatabase migrates it
// to v2 without data loss.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test('v1 -> v2 migration adds account_uid without losing existing rows',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();
    // The exact v1 schema (pre-E01-T01): no account_uid column.
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
      "INSERT INTO device_identities (device_id, signed_in) VALUES ('pre-migration-device', 0);",
    );
    raw.userVersion = 1;

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Opening at target schemaVersion 2 triggers onUpgrade(from: 1, to: 2).
    final row = await db.latestDeviceIdentity();

    expect(row, isNotNull);
    expect(row!.deviceId, 'pre-migration-device');
    // The pre-existing row survived the migration with no account link —
    // absent, not an accidentally-written empty string.
    expect(row.accountUid, isNull);

    // The migrated column is now writable for new rows.
    final newId = await db.createDeviceIdentity('post-migration-device');
    await db.markSignedIn(newId, accountUid: 'uid-123');
    final latest = await db.latestDeviceIdentity();
    expect(latest!.accountUid, 'uid-123');
  });
}
