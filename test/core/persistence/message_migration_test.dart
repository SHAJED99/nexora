// E05-T01 — v10->v11 migration test: new `messages` + `delivery_states`
// tables (additive, no changes to existing tables).
//
// Follows the pattern established in
// test/core/persistence/relay_retention_migration_test.dart (itself
// following routing_migration_test.dart / crypto_migration_test.dart):
// hand-build the exact PRIOR-version (v10) schema with raw SQL, set
// `userVersion`, open it with `AppDatabase`, and assert both that the
// upgrade creates the new tables in a usable shape and that pre-existing
// rows in old tables survived untouched.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The tables that exist in the v7 schema (everything E01-E03 created) --
/// copied from relay_retention_migration_test.dart's own helper.
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

void main() {
  test(
    'test_message_migration_adds_tables',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV7Tables(raw);
      _createRoutesTable(raw);
      _createRelayPacketsTableV10(raw);

      // Pre-existing data in old tables, to prove this v10->v11 step
      // touches nothing outside the two new tables.
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('v10-device', 1);",
      );
      raw.execute(
        "INSERT INTO routes (destination_id, hops, last_cost, last_measured_at) "
        "VALUES ('D', '[\"B\",\"D\"]', 7.25, 1234);",
      );
      raw.execute(
        "INSERT INTO relay_packets "
        "(id, destination_id, payload, priority, size_bytes, created_at, expires_at, delivery_state) "
        "VALUES ('relay-1', 'D', X'0102', 5, 2, 1000, 9000, 'queued');",
      );
      raw.userVersion = 10;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Opening at target schemaVersion 11 triggers onUpgrade(from: 10, to:
      // 11). The new tables must exist and be usable through the real
      // Dart definitions.
      expect(await db.select(db.messages).get(), isEmpty);
      expect(await db.select(db.deliveryStates).get(), isEmpty);

      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'msg-1',
              conversationId: 'conv-1',
              senderDeviceId: 'device-A',
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList([9, 9, 9]),
              createdAt: 5000,
              deliveryState: DeliveryState.queued.name,
            ),
          );
      await db.into(db.deliveryStates).insert(
            DeliveryStatesCompanion.insert(
              messageId: 'msg-1',
              state: DeliveryState.queued.name,
              changedAt: 5000,
            ),
          );

      final message = await db.select(db.messages).getSingle();
      expect(message.id, 'msg-1');
      expect(message.conversationId, 'conv-1');
      expect(message.senderDeviceId, 'device-A');
      expect(message.sequenceNumber, 1);
      expect(message.ciphertext, orderedEquals([9, 9, 9]));
      expect(message.createdAt, 5000);
      expect(message.deliveryState, DeliveryState.queued.name);

      final historyRow = await db.select(db.deliveryStates).getSingle();
      expect(historyRow.messageId, 'msg-1');
      expect(historyRow.state, DeliveryState.queued.name);
      expect(historyRow.changedAt, 5000);

      // Old tables + their pre-existing rows are untouched by this step.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities.single.deviceId, 'v10-device');
      final routeRows = await db.select(db.routes).get();
      expect(routeRows, hasLength(1));
      expect(routeRows.single.lastCost, 7.25);
      final relayRows = await db.select(db.relayPackets).get();
      expect(relayRows, hasLength(1));
      expect(relayRows.single.deliveryState, RelayDeliveryState.queued.name);

      // The `from < 11` step must create the index alongside the table --
      // `createTable` alone does not (drift 2.34.3: indexes are separate
      // `DatabaseSchemaEntity`s, only created via `create`/`createAll`).
      final indexRows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='idx_messages_conversation_created_at'",
          )
          .get();
      expect(indexRows, hasLength(1));
    },
  );

  test(
    'test_message_migration_v7_to_v11_creates_messages_tables_fresh',
    () async {
      // A real install jumping straight from a pre-E04 build (v7) to the
      // current schema (v11) must get `messages`/`delivery_states` created
      // fresh via `createTable` (the `from < 11` step), same as every other
      // later table.
      final raw = sqlite3.sqlite3.openInMemory();
      _createV7Tables(raw);
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('v7-device', 1);",
      );
      raw.userVersion = 7;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      expect(await db.select(db.messages).get(), isEmpty);
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'msg-fresh',
              conversationId: 'conv-fresh',
              senderDeviceId: 'device-Z',
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList([1]),
              createdAt: 1000,
              deliveryState: DeliveryState.queued.name,
            ),
          );
      final row = await db.select(db.messages).getSingle();
      expect(row.id, 'msg-fresh');

      expect(
        (await db.select(db.deviceIdentities).getSingle()).deviceId,
        'v7-device',
      );

      // This install already had v7 tables on disk, so opening at v11
      // drives onUpgrade (not onCreate) and still runs through the same
      // `from < 11` step as the v10->v11 test above -- assert the index
      // here too so a regression in that step can't hide behind only one
      // of the two paths being checked.
      final indexRows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='idx_messages_conversation_created_at'",
          )
          .get();
      expect(indexRows, hasLength(1));
    },
  );
}
