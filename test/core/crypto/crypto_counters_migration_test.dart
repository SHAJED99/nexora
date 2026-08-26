// Migration test (E03-B01): hand-builds the pre-E03-B01 (v5) schema —
// device_identities, relationships, signal_identity, signal_signed_prekeys,
// signal_one_time_prekeys, signal_sessions, signal_trusted_identities, no
// crypto_counters table — and confirms opening it with AppDatabase migrates
// it to v6 without losing any existing data, per the pattern established in
// test/core/persistence/crypto_migration_test.dart.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
      'test_EARS_SEC_3c_migration_adds_crypto_counters_table',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();
    // The exact v5 schema (pre-E03-B01).
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
    raw.execute('''
      CREATE TABLE signal_identity (
        id INTEGER NOT NULL,
        identity_key_pair BLOB NOT NULL,
        registration_id INTEGER NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_signed_prekeys (
        id INTEGER NOT NULL,
        record BLOB NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_one_time_prekeys (
        id INTEGER NOT NULL,
        record BLOB NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_sessions (
        address_name TEXT NOT NULL,
        address_device_id INTEGER NOT NULL,
        record BLOB NOT NULL,
        PRIMARY KEY (address_name, address_device_id)
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_trusted_identities (
        address_name TEXT NOT NULL,
        address_device_id INTEGER NOT NULL,
        identity_key BLOB NOT NULL,
        PRIMARY KEY (address_name, address_device_id)
      );
    ''');
    raw.execute(
      "INSERT INTO device_identities (device_id, signed_in) VALUES ('pre-e03-b01-device', 0);",
    );
    // A *gapped* pre-existing pool on purpose: ids 1 and 9 live, 2..8
    // already consumed by peers. The backfill must key off MAX(id), not
    // COUNT(*) — with a single row at id 1 both give 2, so a
    // `COUNT(*) + 1` implementation would pass the assertion below
    // while still reissuing ids 2..9 that peers already hold
    // (E03-B01 review).
    raw.execute(
      "INSERT INTO signal_one_time_prekeys (id, record) VALUES (1, X'00');",
    );
    raw.execute(
      "INSERT INTO signal_one_time_prekeys (id, record) VALUES (9, X'00');",
    );
    raw.userVersion = 5;

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Opening at target schemaVersion 6 triggers onUpgrade(from: 5, to: 6).
    final deviceRow = await db.latestDeviceIdentity();
    expect(deviceRow, isNotNull);
    expect(deviceRow!.deviceId, 'pre-e03-b01-device');

    final oneTimePreKeys = await db.select(db.signalOneTimePrekeys).get();
    expect(oneTimePreKeys.map((r) => r.id).toSet(), {1, 9});

    // The new crypto_counters table exists and is usable. Because this
    // device already had live (unconsumed) one-time prekeys, the migration
    // backfills the counter to start strictly above the HIGHEST id it ever
    // issued — an install upgrading with a still-live pool must never
    // collide with itself on the next replenish (the same "never reuse an
    // issued id" guarantee the bug fix exists for, applied at migration
    // time).
    final counterRows = await db.select(db.cryptoCounters).get();
    expect(counterRows, hasLength(1));
    expect(counterRows.single.nextOneTimePreKeyId, 10);
  });

  test(
      'test_EARS_SEC_3c_migration_leaves_counter_unseeded_when_pool_already_empty',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();
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
    raw.execute('''
      CREATE TABLE signal_identity (
        id INTEGER NOT NULL,
        identity_key_pair BLOB NOT NULL,
        registration_id INTEGER NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_signed_prekeys (
        id INTEGER NOT NULL,
        record BLOB NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_one_time_prekeys (
        id INTEGER NOT NULL,
        record BLOB NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_sessions (
        address_name TEXT NOT NULL,
        address_device_id INTEGER NOT NULL,
        record BLOB NOT NULL,
        PRIMARY KEY (address_name, address_device_id)
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_trusted_identities (
        address_name TEXT NOT NULL,
        address_device_id INTEGER NOT NULL,
        identity_key BLOB NOT NULL,
        PRIMARY KEY (address_name, address_device_id)
      );
    ''');
    // No rows in signal_one_time_prekeys at all — a fresh-ish install that
    // never generated a pool, or one that had already fully drained it
    // before upgrading.
    raw.userVersion = 5;

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Force the migration to run.
    await db.select(db.signalOneTimePrekeys).get();

    // No live rows to backfill from — the counter table stays empty, and
    // DriftSignalProtocolStore.allocateOneTimePreKeyIds treats an absent
    // row as "start at 1".
    expect(await db.select(db.cryptoCounters).get(), isEmpty);
  });
}
