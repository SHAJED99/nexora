// Migration tests (E04 bug sweep) — the E04 schema additions were the first
// in this project to ship with only fresh-schema (`onCreate`) coverage: both
// E04-T02's `routes` (v7->v8) and E04-T04's `relay_packets` (v8->v9) were
// exercised solely through `AppDatabase.forTesting(NativeDatabase.memory())`,
// which runs `onCreate`/`createAll` and never enters `onUpgrade` at all. A
// real install upgrading from an E03-era build (v7) or a mid-E04 build (v8)
// therefore took an `onUpgrade` path that no test had ever executed.
//
// These two tests close that gap, following the pattern established in
// test/core/persistence/crypto_migration_test.dart and
// test/core/crypto/crypto_counters_migration_test.dart: hand-build the exact
// PRIOR-version schema with raw SQL, set `userVersion`, open it with
// `AppDatabase`, and assert both that the new tables are usable and that
// pre-existing rows survived.
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The tables that exist in the v7 schema (everything E01-E03 created),
/// shared by both tests below. v8 additionally has `routes`; v9 additionally
/// has `relay_packets`.
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

/// The exact v8 `routes` DDL (E04-T02), for the v8->v9 test.
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

void main() {
  // E04-T02 shipped `routes` at schema v8 with fresh-creation coverage only.
  // This is the v7 install's path: neither `routes` nor `relay_packets`
  // exists, so onUpgrade must create both.
  test(
      'test_EARS_ROUTE_migration_v7_to_v9_creates_routes_and_relay_packets',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();
    _createV7Tables(raw);
    // Pre-existing data from the E01-E03 era, which an additive migration
    // must not disturb.
    raw.execute(
      "INSERT INTO device_identities (device_id, signed_in) VALUES ('pre-e04-device', 1);",
    );
    raw.execute(
      "INSERT INTO relationships (device_id, state, updated_at) VALUES ('peer-1', 'trusted', 1000);",
    );
    raw.execute(
      "INSERT INTO crypto_counters (id, next_one_time_pre_key_id, next_issued_one_time_pre_key_id) VALUES (0, 42, 17);",
    );
    raw.userVersion = 7;

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Opening at target schemaVersion 9 triggers onUpgrade(from: 7, to: 9),
    // which must run BOTH the `from < 8` and the `from < 9` steps. Selecting
    // from each table at all is the assertion that createTable ran — a
    // missing table throws here.
    expect(await db.select(db.routes).get(), isEmpty);
    expect(await db.select(db.relayPackets).get(), isEmpty);

    // ...and both are actually writable through the real Dart definitions,
    // not merely present as empty shells with drifted column types.
    await db.into(db.routes).insert(
          RoutesCompanion.insert(
            destinationId: 'D',
            hops: '["B","D"]',
            lastCost: 12.5,
            lastMeasuredAt: 2000,
          ),
        );
    expect((await db.select(db.routes).getSingle()).lastCost, 12.5);

    await db.into(db.relayPackets).insert(
          RelayPacketsCompanion.insert(
            id: 'p1',
            destinationId: 'D',
            payload: Uint8List.fromList([1, 2, 3]),
            priority: 0,
            sizeBytes: 3,
            createdAt: 1000,
            expiresAt: 9000,
            deliveryState: RelayDeliveryState.queued.name,
          ),
        );
    expect((await db.select(db.relayPackets).getSingle()).sizeBytes, 3);

    // The E01-E03 rows survived the additive upgrade untouched.
    final identities = await db.select(db.deviceIdentities).get();
    expect(identities, hasLength(1));
    expect(identities.single.deviceId, 'pre-e04-device');
    final counters = await db.select(db.cryptoCounters).get();
    expect(counters.single.nextOneTimePreKeyId, 42);
    expect(counters.single.nextIssuedOneTimePreKeyId, 17);
    expect(await db.select(db.relationships).get(), hasLength(1));
  });

  // E04-T04 shipped `relay_packets` at schema v9. This is the path taken by
  // an install that already ran a mid-E04 build (v8, `routes` present with
  // real rows): only the `from < 9` step may run, and it must not disturb
  // the existing `routes` data.
  test(
      'test_EARS_ROUTE_migration_v8_to_v9_adds_relay_packets_keeping_routes',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();
    _createV7Tables(raw);
    _createRoutesTable(raw);
    raw.execute(
      "INSERT INTO device_identities (device_id, signed_in) VALUES ('v8-device', 1);",
    );
    // A real route row a v8 install could already hold, including the
    // nullable `stable_since_tick` left unset.
    raw.execute(
      "INSERT INTO routes (destination_id, hops, last_cost, last_measured_at) "
      "VALUES ('D', '[\"B\",\"D\"]', 7.25, 1234);",
    );
    raw.userVersion = 8;

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Opening at target schemaVersion 9 triggers onUpgrade(from: 8, to: 9).
    // `relay_packets` must now exist and be writable...
    expect(await db.select(db.relayPackets).get(), isEmpty);
    await db.into(db.relayPackets).insert(
          RelayPacketsCompanion.insert(
            id: 'p1',
            destinationId: 'D',
            payload: Uint8List.fromList([9]),
            priority: 5,
            sizeBytes: 1,
            createdAt: 1000,
            expiresAt: 9000,
            deliveryState: RelayDeliveryState.queued.name,
          ),
        );
    expect((await db.select(db.relayPackets).getSingle()).priority, 5);

    // ...and the pre-existing v8 `routes` row must be intact, including the
    // still-null nullable column (the `from < 8` step must NOT have re-run
    // and recreated the table).
    final routeRows = await db.select(db.routes).get();
    expect(routeRows, hasLength(1));
    expect(routeRows.single.destinationId, 'D');
    expect(routeRows.single.hops, '["B","D"]');
    expect(routeRows.single.lastCost, 7.25);
    expect(routeRows.single.lastMeasuredAt, 1234);
    // `isNull` is ambiguous here (drift's query builder also exports one),
    // so assert the value directly.
    expect(routeRows.single.stableSinceTick, null);

    expect(
      (await db.select(db.deviceIdentities).getSingle()).deviceId,
      'v8-device',
    );
  });
}
