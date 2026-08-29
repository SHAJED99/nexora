// E05-T04 -- v11->v12 migration test: new `sync_cursors` table (additive,
// no changes to existing tables).
//
// Follows the pattern established in message_migration_test.dart (itself
// following relay_retention_migration_test.dart / routing_migration_test.dart
// / crypto_migration_test.dart): hand-build the exact PRIOR-version (v11)
// schema with raw SQL, set `userVersion`, open it with `AppDatabase`, and
// assert both that the upgrade creates the new table in a usable shape and
// that pre-existing rows in old tables survived untouched.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The tables that exist in the v7 schema (everything E01-E03 created) --
/// copied from message_migration_test.dart's own helper.
void _createV7Tables(sqlite3.Database raw) {
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
}

/// The exact v8 `routes` DDL (E04-T02).
void _createRoutesTable(sqlite3.Database raw) {
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
}

/// The exact v10 `relay_packets` DDL (E04-B02: `payload` nullable).
void _createRelayPacketsTableV10(sqlite3.Database raw) {
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
}

/// The exact v11 `messages` + `delivery_states` DDL (E05-T01), including the
/// `idx_messages_conversation_created_at` index that step's migration
/// creates explicitly.
void _createMessagesTablesV11(sqlite3.Database raw) {
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
  raw.execute('''
    CREATE TABLE delivery_states (
      message_id TEXT NOT NULL,
      state TEXT NOT NULL,
      changed_at INTEGER NOT NULL,
      PRIMARY KEY (message_id, state)
    );
  ''');
  raw.execute(
    'CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_at '
    'ON messages (conversation_id, created_at);',
  );
}

void main() {
  test(
    'test_sync_migration_adds_sync_cursors_table',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV7Tables(raw);
      _createRoutesTable(raw);
      _createRelayPacketsTableV10(raw);
      _createMessagesTablesV11(raw);

      // Pre-existing data in old tables, to prove this v11->v12 step
      // touches nothing outside the new table.
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('v11-device', 1);",
      );
      raw.execute(
        "INSERT INTO messages "
        "(id, conversation_id, sender_device_id, sequence_number, ciphertext, created_at, delivery_state) "
        "VALUES ('msg-1', 'conv-1', 'device-A', 1, X'0102', 1000, 'queued');",
      );
      raw.userVersion = 11;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Opening at target schemaVersion 12 triggers onUpgrade(from: 11, to:
      // 12). The new table must exist and be usable through the real Dart
      // definition.
      expect(await db.select(db.syncCursors).get(), isEmpty);

      await db.into(db.syncCursors).insert(
            SyncCursorsCompanion.insert(
              localDeviceId: 'device-A',
              remoteDeviceId: 'device-B',
              conversationId: 'conv-1',
              lastConfirmedSequenceNumber: 5,
              updatedAt: 9000,
            ),
          );

      final cursor = await db.select(db.syncCursors).getSingle();
      expect(cursor.localDeviceId, 'device-A');
      expect(cursor.remoteDeviceId, 'device-B');
      expect(cursor.conversationId, 'conv-1');
      expect(cursor.lastConfirmedSequenceNumber, 5);
      expect(cursor.updatedAt, 9000);

      // Old tables + their pre-existing rows are untouched by this step.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities.single.deviceId, 'v11-device');
      final messageRows = await db.select(db.messages).get();
      expect(messageRows, hasLength(1));
      expect(messageRows.single.id, 'msg-1');
      expect(messageRows.single.deliveryState, DeliveryState.queued.name);
    },
  );

  test(
    'test_sync_migration_v7_to_v12_creates_sync_cursors_table_fresh',
    () async {
      // A real install jumping straight from a pre-E04 build (v7) to the
      // current schema (v12) must get `sync_cursors` created fresh via
      // `createTable` (the `from < 12` step), same as every other later
      // table.
      final raw = sqlite3.sqlite3.openInMemory();
      _createV7Tables(raw);
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('v7-device', 1);",
      );
      raw.userVersion = 7;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      expect(await db.select(db.syncCursors).get(), isEmpty);
      await db.into(db.syncCursors).insert(
            SyncCursorsCompanion.insert(
              localDeviceId: 'device-Z',
              remoteDeviceId: 'device-Y',
              conversationId: 'conv-fresh',
              lastConfirmedSequenceNumber: 1,
              updatedAt: 1000,
            ),
          );
      final row = await db.select(db.syncCursors).getSingle();
      expect(row.localDeviceId, 'device-Z');

      expect(
        (await db.select(db.deviceIdentities).getSingle()).deviceId,
        'v7-device',
      );
    },
  );

  test(
    'test_sync_cursors_primary_key_is_composite_device_pair_conversation',
    () async {
      // Inserting twice with the same (local, remote, conversation) triple
      // must upsert/collide on the PK rather than create two rows -- proves
      // the composite PK declared in sync_tables.dart actually took effect
      // through the migration, not just in the in-memory `onCreate` path.
      final raw = sqlite3.sqlite3.openInMemory();
      _createV7Tables(raw);
      raw.userVersion = 7;
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await db.into(db.syncCursors).insert(
            SyncCursorsCompanion.insert(
              localDeviceId: 'A',
              remoteDeviceId: 'B',
              conversationId: 'C',
              lastConfirmedSequenceNumber: 1,
              updatedAt: 1000,
            ),
          );
      await db.into(db.syncCursors).insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              localDeviceId: 'A',
              remoteDeviceId: 'B',
              conversationId: 'C',
              lastConfirmedSequenceNumber: 2,
              updatedAt: 2000,
            ),
          );

      final rows = await db.select(db.syncCursors).get();
      expect(rows, hasLength(1));
      expect(rows.single.lastConfirmedSequenceNumber, 2);
    },
  );
}
