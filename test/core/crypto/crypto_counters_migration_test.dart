// Migration test (E03-B01): hand-builds the pre-E03-B01 (v5) schema —
// device_identities, relationships, signal_identity, signal_signed_prekeys,
// signal_one_time_prekeys, signal_sessions, signal_trusted_identities, no
// crypto_counters table — and confirms opening it with AppDatabase migrates
// it to v6 without losing any existing data, per the pattern established in
// test/core/persistence/crypto_migration_test.dart.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
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

  // Added in review (E03-B02, Opus): the v6 -> v7 `addColumn` step was NOT
  // covered by any test. Both tests above start at userVersion 5, so they
  // take the `from < 6` branch, where `m.createTable(cryptoCounters)` builds
  // the table from the CURRENT Dart definition and already includes
  // `next_issued_one_time_pre_key_id` for free — the `from >= 6 && from < 7`
  // body never runs. Proven by mutation: deleting the `addColumn` call
  // entirely left the whole suite green at 68/68, while the real upgrade
  // path every already-shipped v6 install takes would then open a v7
  // database whose `crypto_counters` has no issue-cursor column, and the
  // first `getLocalPreKeyBundle()` would fail on a missing column. This
  // test starts at v6 — the one version where the column must actually be
  // added — and also pins that the B01 allocation counter is not disturbed.
  test(
      'test_EARS_SEC_3c_migration_v6_to_v7_adds_issue_cursor_column',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();
    // The exact v6 schema (post-E03-B01, pre-E03-B02): crypto_counters
    // exists but has only the allocation counter, no issue cursor.
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
    raw.execute('''
      CREATE TABLE crypto_counters (
        id INTEGER NOT NULL,
        next_one_time_pre_key_id INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute(
      "INSERT INTO device_identities (device_id, signed_in) VALUES ('pre-e03-b02-device', 0);",
    );
    // A live pool and an allocation counter already advanced past it, as a
    // real v6 install would have after one replenish.
    raw.execute(
      "INSERT INTO signal_one_time_prekeys (id, record) VALUES (7, X'00');",
    );
    raw.execute(
      "INSERT INTO crypto_counters (id, next_one_time_pre_key_id) VALUES (0, 21);",
    );
    raw.userVersion = 6;

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Opening at target schemaVersion 7 triggers onUpgrade(from: 6, to: 7).
    // Reading the table at all requires the new column to exist — this
    // select is the assertion that addColumn ran.
    final counterRows = await db.select(db.cryptoCounters).get();
    expect(counterRows, hasLength(1));
    // The issue cursor starts at the column default: no durable record of
    // what a pre-fix install already handed out exists (that IS E03-B02),
    // so the guarantee is forward-only from the upgrade.
    expect(counterRows.single.nextIssuedOneTimePreKeyId, 1);
    // The B01 allocation counter must survive the v7 upgrade untouched —
    // an additive column must not reset the high-water mark, or B01 comes
    // straight back.
    expect(counterRows.single.nextOneTimePreKeyId, 21);

    // Existing data intact.
    final deviceRow = await db.latestDeviceIdentity();
    expect(deviceRow!.deviceId, 'pre-e03-b02-device');
    final oneTimePreKeys = await db.select(db.signalOneTimePrekeys).get();
    expect(oneTimePreKeys.map((r) => r.id).toSet(), {7});

    // And the upgraded column is writable, not just readable — the issue
    // cursor has to be usable on an upgraded install, not only a fresh one.
    final store = DriftSignalProtocolStore(db);
    final issued = await store.issueOneTimePreKey();
    expect(issued, isNotNull);
    expect(issued!.id, 7);
    final afterIssue = await db.select(db.cryptoCounters).get();
    expect(afterIssue.single.nextIssuedOneTimePreKeyId, 8);
    expect(afterIssue.single.nextOneTimePreKeyId, 21);
  });
}
