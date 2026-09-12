// Schema migration test (E01-T01 review note). Every widget/unit test uses
// AppDatabase.forTesting(NativeDatabase.memory()), which always takes the
// onCreate path — nothing else exercises onUpgrade. The device this task
// was manually verified on is at schema v1 right now, so the v1->v2
// migration (adding `account_uid`) runs for real on its next launch. This
// test builds a v1 database by hand (the pre-E01-T01 schema, no
// account_uid column) and confirms opening it with AppDatabase migrates it
// to v2 without data loss.
//
// E08-T01 extends this file with the v13->v14 storage-tables step, in the
// same hand-built-prior-schema shape as
// test/core/persistence/group_tables_test.dart's
// test_EARS_GROUP_5_v12_upgrades_to_v13_additively -- but tightened per this
// task's §3/§8: the new test asserts **exact set equality** of the added
// tables and indexes (not merely that the expected ones exist), retiring the
// migration-test-completeness advisory the E07 tracker carried forward
// (E07 tracker §Carried-forward observations, 2026-08-31, S4).
//
// E09-T01 extends this file with the v14->v15 location-tables step, in the
// same hand-built-prior-schema, exact-set-equality shape (task §3, §8).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The full v13 schema -- everything E01-E07 created, in the exact shape
/// each table has as of schema version 13 (the version immediately before
/// this task's `storage_item_stats`/`storage_policy_settings`/
/// `storage_decisions` step). Needed in full (not just a subset) because
/// `AppDatabase`'s `onUpgrade` guards every earlier step with `from < N`, so
/// opening a raw database at `userVersion = 13` skips every step up to and
/// including the group-tables one (`from < 13`) and runs only the new
/// `from < 14` step.
void _createV13Tables(sqlite3.Database raw) {
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
      next_issued_one_time_pre_key_id INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE routes (
      destination_id TEXT NOT NULL,
      hops TEXT NOT NULL,
      last_cost REAL NOT NULL,
      last_measured_at INTEGER NOT NULL,
      stable_since_tick INTEGER NULL,
      PRIMARY KEY (destination_id, hops)
    );
  ''');
  raw.execute('''
    CREATE TABLE relay_packets (
      id TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      payload BLOB NULL,
      priority INTEGER NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      delivery_state TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE messages (
      id TEXT NOT NULL,
      conversation_id TEXT NOT NULL,
      sender_device_id TEXT NOT NULL,
      sequence_number INTEGER NOT NULL,
      ciphertext BLOB NOT NULL,
      created_at INTEGER NOT NULL,
      delivery_state TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_messages_conversation_created_at ON messages '
    '(conversation_id, created_at);',
  );
  raw.execute('''
    CREATE TABLE delivery_states (
      message_id TEXT NOT NULL,
      state TEXT NOT NULL,
      changed_at INTEGER NOT NULL,
      PRIMARY KEY (message_id, state)
    );
  ''');
  raw.execute('''
    CREATE TABLE sync_cursors (
      local_device_id TEXT NOT NULL,
      remote_device_id TEXT NOT NULL,
      conversation_id TEXT NOT NULL,
      last_confirmed_sequence_number INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (local_device_id, remote_device_id, conversation_id)
    );
  ''');
  raw.execute('''
    CREATE TABLE groups (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      created_by_device_id TEXT NOT NULL,
      membership_epoch INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE group_members (
      group_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      role TEXT NOT NULL,
      joined_at_epoch INTEGER NOT NULL,
      removed_at_epoch INTEGER NULL,
      PRIMARY KEY (group_id, device_id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_group_members_current ON group_members '
    '(group_id, removed_at_epoch);',
  );
  raw.execute(
    'CREATE UNIQUE INDEX idx_group_single_owner ON group_members (group_id) '
    "WHERE role = 'owner' AND removed_at_epoch IS NULL;",
  );
  raw.execute('''
    CREATE TABLE group_sender_keys (
      group_id TEXT NOT NULL,
      sender_device_id TEXT NOT NULL,
      membership_epoch INTEGER NOT NULL,
      record BLOB NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (group_id, sender_device_id, membership_epoch)
    );
  ''');
  raw.execute('''
    CREATE TABLE group_events (
      id TEXT NOT NULL,
      group_id TEXT NOT NULL,
      epoch INTEGER NOT NULL,
      kind TEXT NOT NULL,
      actor_device_id TEXT NOT NULL,
      subject_device_id TEXT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_group_events_group_epoch ON group_events '
    '(group_id, epoch);',
  );
}

/// Every table name that must exist pre-migration, per `_createV13Tables`
/// above -- the "before" side of the exact-set diff in
/// `test_EARS_STORE_3_v13_upgrades_to_v14_additively`.
const _preExistingTables = [
  'device_identities',
  'relationships',
  'signal_identity',
  'signal_signed_prekeys',
  'signal_one_time_prekeys',
  'signal_sessions',
  'signal_trusted_identities',
  'crypto_counters',
  'routes',
  'relay_packets',
  'messages',
  'delivery_states',
  'sync_cursors',
  'groups',
  'group_members',
  'group_sender_keys',
  'group_events',
];

/// Rows this test seeds to prove the v13->v14 step touches nothing outside
/// the three new tables.
void _seedV13Data(sqlite3.Database raw) {
  raw.execute(
    "INSERT INTO device_identities (device_id, signed_in) VALUES ('v13-device', 1);",
  );
  raw.execute(
    "INSERT INTO messages "
    "(id, conversation_id, sender_device_id, sequence_number, ciphertext, created_at, delivery_state) "
    "VALUES ('msg-1', 'conv-1', 'device-A', 1, X'0102', 1000, 'queued');",
  );
}

/// The full v14 schema -- everything E01-E08 created, in the exact shape
/// each table has as of schema version 14 (the version immediately before
/// this task's `location_settings`/`location_peer_settings`/
/// `location_fixes` step). Built as v13 (`_createV13Tables`) plus E08-T01's
/// three storage tables, for the same reason `_createV13Tables` needs the
/// full v13 shape: `AppDatabase`'s `onUpgrade` guards every earlier step with
/// `from < N`, so opening a raw database at `userVersion = 14` skips every
/// step up to and including the storage-tables one (`from < 14`) and runs
/// only the new `from < 15` step.
void _createV14Tables(sqlite3.Database raw) {
  _createV13Tables(raw);
  raw.execute('''
    CREATE TABLE storage_item_stats (
      item_kind TEXT NOT NULL,
      item_id TEXT NOT NULL,
      last_accessed_at INTEGER NULL,
      access_count INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (item_kind, item_id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_storage_item_stats_last_accessed ON storage_item_stats '
    '(last_accessed_at);',
  );
  raw.execute('''
    CREATE TABLE storage_policy_settings (
      id INTEGER NOT NULL,
      mode TEXT NOT NULL,
      older_than_days INTEGER NULL,
      max_bytes INTEGER NULL,
      budget_bytes INTEGER NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE storage_decisions (
      id TEXT NOT NULL,
      decided_at INTEGER NOT NULL,
      mode TEXT NOT NULL,
      category_key TEXT NOT NULL,
      item_count INTEGER NOT NULL,
      bytes INTEGER NOT NULL,
      reason_code TEXT NOT NULL,
      reason_detail TEXT NULL,
      outcome TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_storage_decisions_decided_at ON storage_decisions '
    '(decided_at);',
  );
}

/// Every table name that must exist pre-migration for the v14->v15 test --
/// `_preExistingTables` (the v13 set) plus E08-T01's three storage tables.
final _preExistingTablesV14 = [
  ..._preExistingTables,
  'storage_item_stats',
  'storage_policy_settings',
  'storage_decisions',
];

/// Rows this test seeds to prove the v14->v15 step touches nothing outside
/// the three new tables -- same pre-existing rows as `_seedV13Data` plus one
/// row in a v14-only table.
void _seedV14Data(sqlite3.Database raw) {
  _seedV13Data(raw);
  raw.execute(
    "INSERT INTO storage_policy_settings (id, mode, updated_at) "
    "VALUES (1, 'smart', 1000);",
  );
}

/// All `sqlite_master` table names, as a set.
Future<Set<String>> _tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

/// All `sqlite_master` **named** index names (excludes SQLite's own
/// implicit `sqlite_autoindex_*` entries for PRIMARY KEY constraints, which
/// every new table with a non-`INTEGER PRIMARY KEY` mints automatically and
/// which are not part of this task's declared `@TableIndex` contract).
Future<Set<String>> _namedIndexNames(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name NOT LIKE 'sqlite_autoindex%'",
      )
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

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

  test(
    'test_EARS_STORE_3_v13_upgrades_to_v14_additively',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV13Tables(raw);
      _seedV13Data(raw);

      // Snapshot each pre-existing table's exact `CREATE TABLE` DDL text
      // from `sqlite_master` while still on the raw v13 handle -- this is
      // what makes the post-migration comparison below prove the DDL is
      // byte-identical, not merely that a same-named table still exists
      // (task §4: not a column, not an index, not a comment).
      final preMigrationSql = <String, String>{
        for (final tableName in _preExistingTables)
          tableName: raw
                  .select(
                    "SELECT sql FROM sqlite_master WHERE type='table' "
                    'AND name = ?',
                    [tableName],
                  )
                  .single['sql']
              as String,
      };
      // Queried from `sqlite_master` (not just `_preExistingTables`'
      // hard-coded list) because `_seedV13Data` above inserts into the
      // AUTOINCREMENT `device_identities` table, which lazily creates
      // SQLite's own `sqlite_sequence` bookkeeping table on first insert --
      // that table exists before this step's migration ever runs, so it
      // must be part of the "before" snapshot or the exact-set diff below
      // would wrongly blame this migration step for it.
      final preMigrationTables = {
        for (final row
            in raw.select("SELECT name FROM sqlite_master WHERE type='table'"))
          row['name'] as String,
      };
      final preMigrationIndexes = {
        for (final row in raw.select(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name NOT LIKE 'sqlite_autoindex%'",
        ))
          row['name'] as String,
      };

      raw.userVersion = 13;
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Force the lazy migration to run before inspecting sqlite_master.
      await db.customSelect('SELECT 1').get();

      // Exact set equality (this task's §3/§8 tightening): the tables added
      // by this step are *exactly* the three declared in §5, not a superset
      // or subset. A stray extra table (or a missing one) fails this
      // assertion even though every individually-named `expect(...isTrue)`
      // style check in E07-T01's own test would have missed it.
      //
      // E09-T01 note: `AppDatabase.forTesting` always migrates a raw
      // database up to the *current* `schemaVersion` (15 as of this task,
      // not 14) -- there is no way to stop `onUpgrade` at an intermediate
      // version through the public API. Opening this v13 handle therefore
      // also runs the `from < 15` step, so the exact-set diff below
      // legitimately includes E09-T01's three location tables/one index too.
      // This still proves what it always proved (no stray table, no altered
      // pre-existing DDL) -- it is no longer proof of the v13->v14 step in
      // total isolation from the step that came after it. The next task to
      // bump `schemaVersion` inherits the same widening and should extend
      // these sets the same way.
      //
      // E10-T02 note: same widening again -- current `schemaVersion` is now
      // 16, so opening this v13 handle also runs the `from < 16` step,
      // adding the two notification-preference tables to the diff below.
      //
      // E11-T04 note (renumbered during the epic_11 -> development merge,
      // 2026-09-05): same widening a third time -- current `schemaVersion`
      // is now 17, so opening this v13 handle also runs the `from < 17`
      // step, adding `device_revocations` to the diff below.
      //
      // E13-T01 note: same widening a fourth time -- current `schemaVersion`
      // is now 18, so opening this v13 handle also runs the `from < 18`
      // step, adding `rate_limit_counters` to the diff below.
      //
      // E13-B01 note: same widening a fifth time -- current `schemaVersion`
      // is now 19, so this v13 handle also runs the `from < 19` step, which
      // adds no new table (purely an index on the already-existing
      // `rate_limit_counters`) but does add
      // `idx_rate_limit_counters_window_start` to the index diff below.
      //
      // E14-T01 note (renumbered from `from < 18` to `from < 20` during the
      // epic_12/epic_13/epic_14 -> development merge, 2026-09-06): same
      // widening a sixth time -- current `schemaVersion` is now 20, so this
      // v13 handle also runs the `from < 20` step, adding
      // `version_policy_cache` to the diff below.
      //
      // E04-B12 note: same widening a seventh time -- current
      // `schemaVersion` is now 21, so this v13 handle also runs the
      // `from >= 3 && from < 21` step. Unlike every widening note above,
      // this one adds NO new table (nothing added to the table-name diff
      // below) -- it adds one nullable column, `remote_self_device_id`, to
      // the ALREADY-existing `relationships` table instead. This is the
      // first schema-bumping task since this test was written to alter a
      // pre-existing table's own DDL rather than only adding new ones, so
      // `relationships` is excluded from the strict byte-identical loop
      // near the end of this test and checked separately, right after it.
      final postMigrationTables = await _tableNames(db);
      expect(
        postMigrationTables.difference(preMigrationTables),
        {
          'storage_item_stats',
          'storage_policy_settings',
          'storage_decisions',
          'location_settings',
          'location_peer_settings',
          'location_fixes',
          'notification_category_settings',
          'notification_preferences',
          'device_revocations',
          'rate_limit_counters',
          'version_policy_cache',
        },
        reason: 'the v13->current-version upgrade must add exactly these '
            'tables (storage from v13->v14, location from v14->v15, '
            'notifications from v15->v16, device_revocations from '
            'v16->v17, rate_limit_counters from v17->v18; v18->v19 adds an '
            'index only, no new table; version_policy_cache from v19->v20)',
      );

      // Same exact-set treatment for the declared indexes. Neither
      // notification table declares an index (notification_tables.dart),
      // so the v15->v16 step adds none here.
      final postMigrationIndexes = await _namedIndexNames(db);
      expect(
        postMigrationIndexes.difference(preMigrationIndexes),
        {
          'idx_storage_item_stats_last_accessed',
          'idx_storage_decisions_decided_at',
          'idx_location_fixes_captured_at',
          'idx_rate_limit_counters_window_start',
        },
        reason: 'the v13->current-version upgrade must add exactly these '
            'indexes (v18->v19, E13-B01, adds '
            'idx_rate_limit_counters_window_start)',
      );

      // The three new tables are usable through the real Dart definitions.
      expect(await db.select(db.storageItemStats).get(), isEmpty);
      expect(await db.select(db.storageDecisions).get(), isEmpty);
      final settingsRows = await db.select(db.storagePolicySettings).get();
      expect(settingsRows, hasLength(1));

      await db.into(db.storageItemStats).insert(
            StorageItemStatsCompanion.insert(
              itemKind: 'message',
              itemId: 'msg-1',
              accessCount: const Value(2),
            ),
          );
      final stat = await db.select(db.storageItemStats).getSingle();
      expect(stat.itemId, 'msg-1');
      expect(stat.lastAccessedAt, isNull);
      expect(stat.accessCount, 2);

      // Pre-existing tables + their pre-existing rows are untouched by this
      // step.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities.single.deviceId, 'v13-device');
      final messageRows = await db.select(db.messages).get();
      expect(messageRows, hasLength(1));
      expect(messageRows.single.id, 'msg-1');

      // Byte-identical schema check on every pre-existing table: the CREATE
      // TABLE SQL captured by sqlite_master for each must be exactly what
      // it was pre-migration (no altered/renamed/dropped column, per this
      // task's §4). Compares the actual DDL text against the pre-migration
      // snapshot taken above -- not just that a same-named table exists.
      for (final tableName in _preExistingTables) {
        // `relationships` is the one documented exception (E04-B12 note
        // above) -- checked separately immediately below instead.
        if (tableName == 'relationships') continue;
        final rows = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' "
              "AND name='$tableName'",
            )
            .get();
        expect(rows, hasLength(1), reason: '$tableName should still exist');
        expect(
          rows.single.read<String>('sql'),
          preMigrationSql[tableName],
          reason: '$tableName DDL should be byte-identical after migration',
        );
      }

      // `relationships`: E04-B12 legitimately adds one nullable column
      // (`remote_self_device_id`) to this pre-existing table -- asserted
      // explicitly against the exact DDL SQLite now reports, rather than
      // silently dropped from coverage.
      final relationshipsRows = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type='table' "
            "AND name='relationships'",
          )
          .get();
      expect(relationshipsRows, hasLength(1));
      expect(
        relationshipsRows.single.read<String>('sql'),
        'CREATE TABLE relationships (\n'
        '      device_id TEXT NOT NULL,\n'
        '      state TEXT NOT NULL,\n'
        '      updated_at INTEGER NOT NULL, "remote_self_device_id" TEXT NULL, "peer_name" TEXT NULL,\n'
        '      PRIMARY KEY (device_id)\n'
        '    )',
      );
    },
  );

  test(
    'test_EARS_STORE_4_default_policy_row_on_upgrade',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV13Tables(raw);
      _seedV13Data(raw);
      raw.userVersion = 13;
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final rows = await db.select(db.storagePolicySettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 1);
      expect(rows.single.mode, 'smart');
      expect(rows.single.budgetBytes, isNull);
    },
  );

  test(
    'test_EARS_STORE_4_default_policy_row_on_fresh_create',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final rows = await db.select(db.storagePolicySettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 1);
      expect(rows.single.mode, 'smart');
      expect(rows.single.budgetBytes, isNull);
    },
  );

  test(
    'test_EARS_LOC_6_v14_upgrades_to_v15_additively',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV14Tables(raw);
      _seedV14Data(raw);

      // Snapshot each pre-existing table's exact `CREATE TABLE` DDL text
      // from `sqlite_master` while still on the raw v14 handle -- this is
      // what makes the post-migration comparison below prove the DDL is
      // byte-identical, not merely that a same-named table still exists
      // (task §4: not a column, not an index, not a comment).
      final preMigrationSql = <String, String>{
        for (final tableName in _preExistingTablesV14)
          tableName: raw
                  .select(
                    "SELECT sql FROM sqlite_master WHERE type='table' "
                    'AND name = ?',
                    [tableName],
                  )
                  .single['sql']
              as String,
      };
      // Queried from `sqlite_master` (not just `_preExistingTablesV14`'s
      // hard-coded list) because `_seedV14Data` inserts into the
      // AUTOINCREMENT `device_identities` table, which lazily creates
      // SQLite's own `sqlite_sequence` bookkeeping table on first insert --
      // that table exists before this step's migration ever runs, so it
      // must be part of the "before" snapshot or the exact-set diff below
      // would wrongly blame this migration step for it.
      final preMigrationTables = {
        for (final row
            in raw.select("SELECT name FROM sqlite_master WHERE type='table'"))
          row['name'] as String,
      };
      final preMigrationIndexes = {
        for (final row in raw.select(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name NOT LIKE 'sqlite_autoindex%'",
        ))
          row['name'] as String,
      };

      raw.userVersion = 14;
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Force the lazy migration to run before inspecting sqlite_master.
      await db.customSelect('SELECT 1').get();

      // Exact set equality (this task's §3/§8): the tables added by this
      // step are *exactly* the three declared in §5, not a superset or
      // subset.
      //
      // E10-T02 note: same widening `test_EARS_STORE_3_...` above already
      // documents -- `AppDatabase.forTesting` migrates this v14 handle all
      // the way to the current `schemaVersion` (16), so the `from < 16`
      // step's two notification-preference tables legitimately appear in
      // this diff too.
      //
      // E11-T04 note (renumbered during the epic_11 -> development merge,
      // 2026-09-05): same widening a third time -- current `schemaVersion`
      // is now 17, so this v14 handle also runs the `from < 17` step,
      // adding `device_revocations` to the diff below.
      //
      // E13-T01 note: same widening a fourth time -- current `schemaVersion`
      // is now 18, so this v14 handle also runs the `from < 18` step,
      // adding `rate_limit_counters` to the diff below.
      //
      // E13-B01 note: same widening a fifth time -- current `schemaVersion`
      // is now 19, so this v14 handle also runs the `from < 19` step, which
      // adds no new table (purely an index on the already-existing
      // `rate_limit_counters`) but does add
      // `idx_rate_limit_counters_window_start` to the index diff below.
      //
      // E14-T01 note (renumbered from `from < 18` to `from < 20` during the
      // epic_12/epic_13/epic_14 -> development merge, 2026-09-06): same
      // widening a sixth time -- current `schemaVersion` is now 20, so this
      // v14 handle also runs the `from < 20` step, adding
      // `version_policy_cache` to the diff below.
      //
      // E04-B12 note: same widening a seventh time -- current
      // `schemaVersion` is now 21, so this v14 handle also runs the
      // `from >= 3 && from < 21` step, which adds no new table but does add
      // one nullable column (`remote_self_device_id`) to the ALREADY-
      // existing `relationships` table -- see `test_EARS_STORE_3_...`
      // above's identical note. `relationships` is excluded from the strict
      // byte-identical loop near the end of this test and checked
      // separately, right after it.
      final postMigrationTables = await _tableNames(db);
      expect(
        postMigrationTables.difference(preMigrationTables),
        {
          'location_settings',
          'location_peer_settings',
          'location_fixes',
          'notification_category_settings',
          'notification_preferences',
          'device_revocations',
          'rate_limit_counters',
          'version_policy_cache',
        },
        reason: 'the v14->current-version upgrade must add exactly these '
            'tables (location from v14->v15, notifications from v15->v16, '
            'device_revocations from v16->v17, rate_limit_counters from '
            'v17->v18; v18->v19 adds an index only, no new table; '
            'version_policy_cache from v19->v20)',
      );

      // Same exact-set treatment for the declared indexes.
      final postMigrationIndexes = await _namedIndexNames(db);
      expect(
        postMigrationIndexes.difference(preMigrationIndexes),
        {
          'idx_location_fixes_captured_at',
          'idx_rate_limit_counters_window_start',
        },
        reason: 'the v14->v15 step must add its one index, and the '
            'v18->v19 step (E13-B01) must add '
            'idx_rate_limit_counters_window_start',
      );

      // The three new tables are usable through the real Dart definitions.
      expect(await db.select(db.locationPeerSettings).get(), isEmpty);
      expect(await db.select(db.locationFixes).get(), isEmpty);
      final settingsRows = await db.select(db.locationSettings).get();
      expect(settingsRows, hasLength(1));
      expect(settingsRows.single.globalEnabled, isFalse);

      await db.into(db.locationFixes).insert(
            LocationFixesCompanion.insert(
              peerDeviceId: 'peer-1',
              latitude: 1.0,
              longitude: 1.0,
              capturedAt: 1000,
              receivedAt: 1000,
            ),
          );
      final fix = await db.select(db.locationFixes).getSingle();
      expect(fix.peerDeviceId, 'peer-1');
      expect(fix.accuracyM, isNull);

      // Pre-existing tables + their pre-existing rows are untouched by this
      // step.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities.single.deviceId, 'v13-device');
      final messageRows = await db.select(db.messages).get();
      expect(messageRows, hasLength(1));
      expect(messageRows.single.id, 'msg-1');
      final storageSettingsRows =
          await db.select(db.storagePolicySettings).get();
      expect(storageSettingsRows, hasLength(1));
      expect(storageSettingsRows.single.mode, 'smart');

      // Byte-identical schema check on every pre-existing table: the CREATE
      // TABLE SQL captured by sqlite_master for each must be exactly what it
      // was pre-migration (no altered/renamed/dropped column, per this
      // task's §4). Compares the actual DDL text against the pre-migration
      // snapshot taken above -- not just that a same-named table exists.
      for (final tableName in _preExistingTablesV14) {
        // `relationships` is the one documented exception (E04-B12 note
        // above) -- checked separately immediately below instead.
        if (tableName == 'relationships') continue;
        final rows = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' "
              "AND name='$tableName'",
            )
            .get();
        expect(rows, hasLength(1), reason: '$tableName should still exist');
        expect(
          rows.single.read<String>('sql'),
          preMigrationSql[tableName],
          reason: '$tableName DDL should be byte-identical after migration',
        );
      }

      // `relationships`: E04-B12 legitimately adds one nullable column
      // (`remote_self_device_id`) -- see `test_EARS_STORE_3_...` above's
      // identical assertion.
      final relationshipsRows = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type='table' "
            "AND name='relationships'",
          )
          .get();
      expect(relationshipsRows, hasLength(1));
      expect(
        relationshipsRows.single.read<String>('sql'),
        'CREATE TABLE relationships (\n'
        '      device_id TEXT NOT NULL,\n'
        '      state TEXT NOT NULL,\n'
        '      updated_at INTEGER NOT NULL, "remote_self_device_id" TEXT NULL, "peer_name" TEXT NULL,\n'
        '      PRIMARY KEY (device_id)\n'
        '    )',
      );
    },
  );

  test(
    'test_EARS_LOC_3_default_settings_row_on_upgrade',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV14Tables(raw);
      _seedV14Data(raw);
      raw.userVersion = 14;
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final rows = await db.select(db.locationSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 1);
      expect(rows.single.globalEnabled, isFalse);
    },
  );

  test(
    'test_EARS_LOC_3_default_settings_row_on_fresh_create',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final rows = await db.select(db.locationSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 1);
      expect(rows.single.globalEnabled, isFalse);
    },
  );
}
