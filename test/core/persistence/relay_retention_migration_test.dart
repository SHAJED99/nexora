// E04-B02 — v9->v10 migration test: `relay_packets.payload` becomes
// nullable so `RelayEngine.reclaimPayloads()` can null it out on a
// terminal-state row past its own `expires_at`.
//
// Follows the pattern established in
// test/core/persistence/routing_migration_test.dart (itself following
// test/core/persistence/crypto_migration_test.dart and
// test/core/crypto/crypto_counters_migration_test.dart): hand-build the
// exact PRIOR-version schema with raw SQL, set `userVersion`, open it with
// `AppDatabase`, and assert both that the migrated shape is usable and that
// pre-existing rows survived.
//
// SQLite has no ALTER COLUMN, so this migration rebuilds the table (create
// new shape, copy rows, drop old, rename) — this test's job is to prove
// that rebuild preserves every column's data untouched, for rows in every
// delivery state, not just that the column ends up nullable.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The tables that exist in the v7 schema (everything E01-E03 created) —
/// copied from routing_migration_test.dart's own helper, since this test
/// needs the same base to build a v9 database on top of.
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

/// The exact v9 `relay_packets` DDL (E04-T04) — `payload` still NOT NULL,
/// pre-dating this bug's fix.
void _createRelayPacketsTableV9(sqlite3.Database raw) {
  raw.execute('''
    CREATE TABLE relay_packets (
      id TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      payload BLOB NOT NULL,
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
    'test_EARS_ROUTE_004_migration_v9_to_v10_makes_payload_nullable_'
    'keeping_rows',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV7Tables(raw);
      _createRoutesTable(raw);
      _createRelayPacketsTableV9(raw);

      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('v9-device', 1);",
      );
      raw.execute(
        "INSERT INTO routes (destination_id, hops, last_cost, last_measured_at) "
        "VALUES ('D', '[\"B\",\"D\"]', 7.25, 1234);",
      );
      // Real pre-existing rows in every delivery state a v9 install could
      // hold, including their (still non-null, at this point) payload
      // bytes — the migration must preserve all of this untouched, for
      // every state, not merely make the column accept NULL going forward.
      raw.execute(
        "INSERT INTO relay_packets "
        "(id, destination_id, payload, priority, size_bytes, created_at, expires_at, delivery_state) "
        "VALUES ('queued-1', 'D', X'010203', 5, 3, 1000, 9000, 'queued');",
      );
      raw.execute(
        "INSERT INTO relay_packets "
        "(id, destination_id, payload, priority, size_bytes, created_at, expires_at, delivery_state) "
        "VALUES ('forwarding-1', 'D', X'0405', 0, 2, 1000, 5000, 'forwarding');",
      );
      raw.execute(
        "INSERT INTO relay_packets "
        "(id, destination_id, payload, priority, size_bytes, created_at, expires_at, delivery_state) "
        "VALUES ('delivered-1', 'B', X'06', 0, 1, 1000, 5000, 'delivered');",
      );
      raw.userVersion = 9;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Opening at target schemaVersion 10 triggers onUpgrade(from: 9, to:
      // 10). All three pre-existing rows, including their payload bytes,
      // must have survived the rebuild untouched.
      final rows = await (db.select(db.relayPackets)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
      expect(rows, hasLength(3));

      final delivered = rows.firstWhere((r) => r.id == 'delivered-1');
      expect(delivered.destinationId, 'B');
      expect(delivered.payload, orderedEquals([6]));
      expect(delivered.priority, 0);
      expect(delivered.sizeBytes, 1);
      expect(delivered.createdAt, 1000);
      expect(delivered.expiresAt, 5000);
      expect(delivered.deliveryState, RelayDeliveryState.delivered.name);

      final forwarding = rows.firstWhere((r) => r.id == 'forwarding-1');
      expect(forwarding.payload, orderedEquals([4, 5]));
      expect(forwarding.deliveryState, RelayDeliveryState.forwarding.name);

      final queued = rows.firstWhere((r) => r.id == 'queued-1');
      expect(queued.payload, orderedEquals([1, 2, 3]));
      expect(queued.priority, 5);
      expect(queued.deliveryState, RelayDeliveryState.queued.name);

      // The column now actually accepts NULL — the whole point of the
      // migration — through the real Dart definition, not merely as an
      // empty shell with a drifted column type.
      await (db.update(db.relayPackets)
            ..where((t) => t.id.equals('forwarding-1')))
          .write(const RelayPacketsCompanion(payload: Value(null)));
      final updated = await (db.select(db.relayPackets)
            ..where((t) => t.id.equals('forwarding-1')))
          .getSingle();
      expect(updated.payload, null);
      // The rest of that row is untouched by the null-out.
      expect(updated.deliveryState, RelayDeliveryState.forwarding.name);
      expect(updated.sizeBytes, 2);

      // A fresh insert with a null payload also works directly, proving the
      // column constraint itself (not just an app-level Value(null)) was
      // relaxed.
      await db.into(db.relayPackets).insert(
            RelayPacketsCompanion.insert(
              id: 'expired-fresh',
              destinationId: 'Z',
              payload: const Value(null),
              priority: 0,
              sizeBytes: 0,
              createdAt: 2000,
              expiresAt: 2500,
              deliveryState: RelayDeliveryState.expired.name,
            ),
          );
      final fresh = await (db.select(db.relayPackets)
            ..where((t) => t.id.equals('expired-fresh')))
          .getSingle();
      expect(fresh.payload, null);

      // Other v7/v8 tables and their pre-existing rows are untouched by
      // this v9->v10 step, which is scoped to `relay_packets` alone.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities.single.deviceId, 'v9-device');
      final routeRows = await db.select(db.routes).get();
      expect(routeRows, hasLength(1));
      expect(routeRows.single.lastCost, 7.25);
    },
  );

  test(
    'test_EARS_ROUTE_004_migration_v7_to_v10_creates_relay_packets_'
    'with_nullable_payload',
    () async {
      // A real install jumping straight from a pre-E04 build (v7) to the
      // current schema (v10) must never enter the v9->v10 rebuild step at
      // all — `relay_packets` doesn't exist yet, so `createTable` (the
      // `from < 9` step) already creates it with the CURRENT Dart
      // definition, payload nullable included.
      final raw = sqlite3.sqlite3.openInMemory();
      _createV7Tables(raw);
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) VALUES ('v7-device', 1);",
      );
      raw.userVersion = 7;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      expect(await db.select(db.relayPackets).get(), isEmpty);
      await db.into(db.relayPackets).insert(
            RelayPacketsCompanion.insert(
              id: 'p1',
              destinationId: 'D',
              payload: const Value(null),
              priority: 0,
              sizeBytes: 0,
              createdAt: 1000,
              expiresAt: 9000,
              deliveryState: RelayDeliveryState.expired.name,
            ),
          );
      final row = await db.select(db.relayPackets).getSingle();
      expect(row.payload, null);

      expect(
        (await db.select(db.deviceIdentities).getSingle()).deviceId,
        'v7-device',
      );
    },
  );
}
