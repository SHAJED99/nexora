// E11-T04 -- v16->v17 migration test: new `device_revocations` table
// (additive, no changes to existing tables).
// (Renumbered during the epic_11 -> development merge, 2026-09-05: E09 and
// E10 each independently claimed v15/v16 against an earlier development
// baseline that predated this table, pushing this task's own step to v17.)
//
// Follows the pattern established in sync_migration_test.dart / the other
// per-task migration test files: hand-build the exact PRIOR-version (v16)
// schema with raw SQL, set `userVersion`, open it with `AppDatabase`, and
// assert both that the upgrade creates the new table in a usable shape and
// that pre-existing rows in old tables survived untouched.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The full v16 schema -- everything E01-E10 created, in the exact shape
/// each table has as of schema version 16 (the version immediately before
/// this task's `device_revocations` step, after the epic_11 -> development
/// renumbering). Needed in full (not just a subset) because `AppDatabase`'s
/// `onUpgrade` guards every earlier step with `from < N`, so opening a raw
/// database at `userVersion = 16` skips every step up to and including the
/// notification-tables one (`from < 16`) and runs only this task's new
/// `from < 17` step.
void _createV16Tables(sqlite3.Database raw) {
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
  // The default row the v13->v14 step inserts on upgrade (task §5 of E08-T01
  // -- the app must never have to cope with an absent settings row).
  raw.execute(
    "INSERT INTO storage_policy_settings (id, mode, updated_at) "
    "VALUES (1, 'smart', 1000);",
  );

  // E09-T01 (v14->v15): location-sharing tables.
  raw.execute('''
    CREATE TABLE location_settings (
      id INTEGER NOT NULL,
      global_enabled INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE location_peer_settings (
      peer_device_id TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (peer_device_id)
    );
  ''');
  raw.execute('''
    CREATE TABLE location_fixes (
      peer_device_id TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      accuracy_m REAL NULL,
      captured_at INTEGER NOT NULL,
      received_at INTEGER NOT NULL,
      PRIMARY KEY (peer_device_id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_location_fixes_captured_at ON location_fixes '
    '(captured_at);',
  );
  // The default row the v14->v15 step inserts on upgrade (task §5 of
  // E09-T01 -- the app must never have to cope with an absent settings
  // row).
  raw.execute(
    "INSERT INTO location_settings (id, global_enabled, updated_at) "
    "VALUES (1, 0, 1000);",
  );

  // E10-T02 (v15->v16): notification preference tables.
  raw.execute('''
    CREATE TABLE notification_category_settings (
      category TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (category)
    );
  ''');
  raw.execute('''
    CREATE TABLE notification_preferences (
      id INTEGER NOT NULL,
      privacy_level TEXT NOT NULL DEFAULT 'hidden',
      PRIMARY KEY (id)
    );
  ''');
  // The nine enabled category rows plus the `hidden` preferences singleton
  // the v15->v16 step seeds on upgrade (task §5 of E10-T02 -- same "app
  // never copes with an absent row" invariant as `storage_policy_settings`
  // / `location_settings` above).
  for (final category in const [
    'message',
    'voiceMessage',
    'ptt',
    'incomingCall',
    'connectionRequest',
    'trustRequest',
    'groupEvent',
    'securityEvent',
    'storageWarning',
  ]) {
    raw.execute(
      "INSERT INTO notification_category_settings (category, enabled) "
      "VALUES ('$category', 1);",
    );
  }
  raw.execute(
    "INSERT INTO notification_preferences (id, privacy_level) "
    "VALUES (0, 'hidden');",
  );
}

/// Every table name that must exist pre-migration, per `_createV16Tables`
/// above -- the "before" side of the exact-set diff below.
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
  'storage_item_stats',
  'storage_policy_settings',
  'storage_decisions',
  'location_settings',
  'location_peer_settings',
  'location_fixes',
  'notification_category_settings',
  'notification_preferences',
];

Future<Set<String>> _tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test(
    'test_migration_v16_to_v17_preserves_rows',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV16Tables(raw);

      // Pre-existing data in old tables, to prove this v16->v17 step
      // touches nothing outside the new table.
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('v14-device', 1);",
      );
      raw.execute(
        "INSERT INTO messages "
        "(id, conversation_id, sender_device_id, sequence_number, ciphertext, created_at, delivery_state) "
        "VALUES ('msg-1', 'conv-1', 'device-A', 1, X'0102', 1000, 'queued');",
      );

      // Snapshot each pre-existing table's exact `CREATE TABLE` DDL text
      // from `sqlite_master` while still on the raw v14 handle -- proves
      // the post-migration comparison below is byte-identical, not merely
      // that a same-named table still exists (task §4: additive only, no
      // existing column altered).
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
      final preMigrationTables = {
        for (final row
            in raw.select("SELECT name FROM sqlite_master WHERE type='table'"))
          row['name'] as String,
      };

      raw.userVersion = 16;
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // `AppDatabase.forTesting` always migrates a raw database up to the
      // *current* `schemaVersion` (20 as of the epic_12/epic_13/epic_14 ->
      // development merge, 2026-09-06, not 17) -- opening this v16 handle
      // therefore also runs the `from < 18`/`from < 19`/`from < 20` steps,
      // so the exact-set diff below legitimately includes
      // `rate_limit_counters` and `version_policy_cache` too (same
      // widening `database_migration_test.dart`/
      // `notification_migration_test.dart` already document). Force the
      // lazy migration to run before inspecting sqlite_master.
      await db.customSelect('SELECT 1').get();

      // Exactly these three new tables -- `device_revocations` (v16->v17,
      // no index, task §5, sync_tables.dart's "point lookup by PK needs no
      // secondary index" reasoning applies identically here),
      // `rate_limit_counters` (v17->v18, E13-T01, same no-index reasoning;
      // v18->v19 adds an index only, no new table) and
      // `version_policy_cache` (v19->v20, E14-T01, renumbered from
      // `from < 18` at this same merge, same no-index reasoning).
      final postMigrationTables = await _tableNames(db);
      expect(
        postMigrationTables.difference(preMigrationTables),
        {'device_revocations', 'rate_limit_counters', 'version_policy_cache'},
        reason: 'the v16->current-version upgrade must add exactly these '
            'tables (device_revocations from v16->v17, rate_limit_counters '
            'from v17->v18; v18->v19 adds an index only, no new table; '
            'version_policy_cache from v19->v20)',
      );

      // The new table is usable through the real Dart definition.
      expect(await db.select(db.deviceRevocations).get(), isEmpty);

      await db.into(db.deviceRevocations).insert(
            DeviceRevocationsCompanion.insert(
              deviceId: 'device-Z',
              revokedAt: DateTime.fromMillisecondsSinceEpoch(5000),
              source: 'local',
            ),
          );
      final row = await db.select(db.deviceRevocations).getSingle();
      expect(row.deviceId, 'device-Z');
      expect(row.source, 'local');

      // Old tables + their pre-existing rows are untouched by this step.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities.single.deviceId, 'v14-device');
      final messageRows = await db.select(db.messages).get();
      expect(messageRows, hasLength(1));
      expect(messageRows.single.id, 'msg-1');

      // The pre-existing storage-policy default row also survived.
      final settingsRows = await db.select(db.storagePolicySettings).get();
      expect(settingsRows, hasLength(1));
      expect(settingsRows.single.mode, 'smart');

      // Byte-identical schema check on every pre-existing table.
      for (final tableName in _preExistingTables) {
        // `relationships`: E04-B12 (current `schemaVersion` 21) legitimately
        // adds one nullable column (`remote_self_device_id`) -- excluded
        // here and asserted separately below, mirroring the identical
        // documented exception in
        // `test/core/persistence/database_migration_test.dart`.
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
    'test_migration_v13_to_v17_creates_device_revocations_table_via_intermediate_step',
    () async {
      // A real install jumping straight from v13 (pre-storage-tables) all
      // the way to the current schema (v17) must get every intermediate
      // step (`from < 14` through `from < 17`) applied in order.
      final raw = sqlite3.sqlite3.openInMemory();
      _createV16Tables(raw);
      // Roll this fixture back to v13 shape: drop the storage tables the
      // `from < 14` step is responsible for creating, so this test proves
      // that step runs too, not just `from < 15` in isolation.
      raw.execute('DROP TABLE storage_item_stats;');
      raw.execute('DROP TABLE storage_policy_settings;');
      raw.execute('DROP TABLE storage_decisions;');
      raw.userVersion = 13;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      expect(await db.select(db.deviceRevocations).get(), isEmpty);
      expect(await db.select(db.storagePolicySettings).get(), hasLength(1));

      await db.into(db.deviceRevocations).insert(
            DeviceRevocationsCompanion.insert(
              deviceId: 'device-Y',
              revokedAt: DateTime.fromMillisecondsSinceEpoch(1000),
              source: 'firebase',
            ),
          );
      final row = await db.select(db.deviceRevocations).getSingle();
      expect(row.deviceId, 'device-Y');
    },
  );
}
