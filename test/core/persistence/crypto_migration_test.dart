// Migration test (E03-T01, EARS-SEC-3a): hand-builds the pre-E03-T01 (v3)
// schema — device_identities, relationships, no signal_* tables — and
// confirms opening it with AppDatabase migrates it to v4 without losing
// any existing data, per the pattern established in
// test/core/persistence/database_migration_test.dart.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
      'test_EARS_SEC_3a_migration_adds_signal_tables',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();
    // The exact v3 schema (pre-E03-T01): device_identities + relationships,
    // no signal_* tables.
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
      "INSERT INTO device_identities (device_id, signed_in) VALUES ('pre-e03-device', 0);",
    );
    raw.execute(
      "INSERT INTO relationships (device_id, state, updated_at) "
      "VALUES ('peer-device', 'trusted', strftime('%s', 'now'));",
    );
    raw.userVersion = 3;

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Opening at target schemaVersion 4 triggers onUpgrade(from: 3, to: 4).
    final deviceRow = await db.latestDeviceIdentity();
    expect(deviceRow, isNotNull);
    expect(deviceRow!.deviceId, 'pre-e03-device');

    final relationships = await db.select(db.relationships).get();
    expect(relationships, hasLength(1));
    expect(relationships.single.deviceId, 'peer-device');

    // The new signal_* tables exist and are usable after the migration.
    expect(await db.select(db.signalIdentity).get(), isEmpty);
    expect(await db.select(db.signalSignedPrekeys).get(), isEmpty);
    expect(await db.select(db.signalOneTimePrekeys).get(), isEmpty);
    expect(await db.select(db.signalSessions).get(), isEmpty);
  });
}
