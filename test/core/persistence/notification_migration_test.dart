// Schema migration test for the v15->v16 notification-preferences step
// (E10-T02, EARS-NOTIFY-3/4).
//
// Follows the same hand-built-prior-schema, exact-set-equality shape
// `test/core/persistence/database_migration_test.dart` established for
// E08-T01's v13->v14 step and E09-T01's v14->v15 step (task §6 risk note:
// "the migration test must build the *previous* schema by hand and
// migrate ... asserting on a freshly-created v16 database proves nothing
// about upgrades").
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The full v15 schema -- everything E01-E09 created, in the exact shape
/// each table has as of schema version 15 (the version immediately before
/// this task's `notification_category_settings`/`notification_preferences`
/// step). Needed in full because `AppDatabase`'s `onUpgrade` guards every
/// earlier step with `from < N`, so opening a raw database at
/// `userVersion = 15` skips every step up to and including the
/// location-tables one (`from < 15`) and runs only the new `from < 16`
/// step.
void _createV15Tables(sqlite3.Database raw) {
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
}

/// Every table name that must exist pre-migration, per `_createV15Tables`
/// above -- the "before" side of the exact-set diff in
/// `test_EARS_NOTIFY_3_migration_seeds_conservative_defaults`.
const _preExistingTablesV15 = [
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
];

/// Rows this test seeds to prove the v15->v16 step touches nothing outside
/// the two new tables.
void _seedV15Data(sqlite3.Database raw) {
  raw.execute(
    "INSERT INTO device_identities (device_id, signed_in) VALUES ('v15-device', 1);",
  );
  raw.execute(
    "INSERT INTO messages "
    "(id, conversation_id, sender_device_id, sequence_number, ciphertext, created_at, delivery_state) "
    "VALUES ('msg-1', 'conv-1', 'device-A', 1, X'0102', 1000, 'queued');",
  );
  raw.execute(
    "INSERT INTO location_settings (id, global_enabled, updated_at) "
    "VALUES (1, 0, 1000);",
  );
}

/// All `sqlite_master` table names, as a set.
Future<Set<String>> _tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

const _expectedUserFacingCategories = [
  'message',
  'voiceMessage',
  'ptt',
  'incomingCall',
  'connectionRequest',
  'trustRequest',
  'groupEvent',
  'securityEvent',
  'storageWarning',
];

void main() {
  test(
    'test_EARS_NOTIFY_3_migration_seeds_conservative_defaults',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV15Tables(raw);
      _seedV15Data(raw);

      // Snapshot each pre-existing table's exact `CREATE TABLE` DDL text
      // from `sqlite_master` while still on the raw v15 handle -- proves
      // the post-migration comparison below is byte-identical, not merely
      // that a same-named table still exists (task §4: not a column, not
      // an index, not a comment).
      final preMigrationSql = <String, String>{
        for (final tableName in _preExistingTablesV15)
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

      raw.userVersion = 15;
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Force the lazy migration to run before inspecting sqlite_master.
      await db.customSelect('SELECT 1').get();

      // Exact set equality (task §3/§6): the tables added by this step are
      // *exactly* the two declared in §5, not a superset or subset.
      //
      // E11-T04 note (renumbered during the epic_11 -> development merge,
      // 2026-09-05): `AppDatabase.forTesting` always migrates a raw
      // database up to the *current* `schemaVersion` (17 as of this
      // renumbering, not 16) -- opening this v15 handle therefore also
      // runs the `from < 17` step, so the exact-set diff below legitimately
      // includes `device_revocations` too.
      //
      // E13-T01 note: same widening again -- current `schemaVersion` is now
      // 18, so opening this v15 handle also runs the `from < 18` step,
      // adding `rate_limit_counters` to the diff below.
      //
      // E13-B01 note: same widening a further time -- current
      // `schemaVersion` is now 19, so this v15 handle also runs the
      // `from < 19` step, which adds no new table (purely an index on the
      // already-existing `rate_limit_counters`).
      //
      // E14-T01 note (renumbered from `from < 18` to `from < 20` during the
      // epic_12/epic_13/epic_14 -> development merge, 2026-09-06): same
      // widening again -- current `schemaVersion` is now 20, so this v15
      // handle also runs the `from < 20` step, adding `version_policy_cache`
      // to the diff below.
      final postMigrationTables = await _tableNames(db);
      expect(
        postMigrationTables.difference(preMigrationTables),
        {
          'notification_category_settings',
          'notification_preferences',
          'device_revocations',
          'rate_limit_counters',
          'version_policy_cache',
        },
        reason: 'the v15->current-version upgrade must add exactly these '
            'tables (notifications from v15->v16, device_revocations from '
            'v16->v17, rate_limit_counters from v17->v18; v18->v19 adds an '
            'index only, no new table; version_policy_cache from v19->v20)',
      );

      // Nine user-facing categories, every one enabled -- no
      // `backgroundService` row (task §2, §4).
      final categoryRows =
          await db.select(db.notificationCategorySettings).get();
      expect(categoryRows, hasLength(9));
      expect(
        categoryRows.map((r) => r.category).toSet(),
        _expectedUserFacingCategories.toSet(),
      );
      expect(categoryRows.every((r) => r.enabled), isTrue);
      expect(
        categoryRows.any((r) => r.category == 'backgroundService'),
        isFalse,
      );

      // The singleton privacy row defaults to `hidden`.
      final preferenceRows = await db.select(db.notificationPreferences).get();
      expect(preferenceRows, hasLength(1));
      expect(preferenceRows.single.id, 0);
      expect(preferenceRows.single.privacyLevel, 'hidden');

      // Pre-existing tables + their pre-existing rows are untouched by this
      // step.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities.single.deviceId, 'v15-device');
      final messageRows = await db.select(db.messages).get();
      expect(messageRows, hasLength(1));
      expect(messageRows.single.id, 'msg-1');
      final locationSettingsRows = await db.select(db.locationSettings).get();
      expect(locationSettingsRows, hasLength(1));
      expect(locationSettingsRows.single.globalEnabled, isFalse);

      // Byte-identical schema check on every pre-existing table: no
      // altered/renamed/dropped column (task §4).
      for (final tableName in _preExistingTablesV15) {
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
    'test_EARS_NOTIFY_3_fresh_install_seeds_conservative_defaults',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final categoryRows =
          await db.select(db.notificationCategorySettings).get();
      expect(categoryRows, hasLength(9));
      expect(categoryRows.every((r) => r.enabled), isTrue);

      final preferenceRows = await db.select(db.notificationPreferences).get();
      expect(preferenceRows, hasLength(1));
      expect(preferenceRows.single.privacyLevel, 'hidden');
    },
  );
}
