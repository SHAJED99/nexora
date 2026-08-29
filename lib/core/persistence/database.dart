// core/persistence — Drift database (ADR-0001).
//
// Genesis walking skeleton: exactly one table, one real write, one real
// read. Later epics add tables for conversations/messages/etc. here, never
// by hand-editing generated output.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'crypto_tables.dart';
import 'message_tables.dart';
import 'relationships_table.dart';
import 'relay_tables.dart';
import 'routing_tables.dart';
import 'sync_tables.dart';

part 'database.g.dart';

/// One row per locally-created device identity. This is the walking
/// skeleton's proof that UI -> controller -> use case -> repository ->
/// Drift is wired end to end (E00-T05) — not a real identity/session model.
/// The real device-identity/session store belongs to `core/auth` in a
/// feature epic (ADR-0005).
class DeviceIdentities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  BoolColumn get signedIn => boolean().withDefault(const Constant(false))();
  DateTimeColumn get signedInAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  // E01-T01: links a device identity to the Firebase Auth account it was
  // signed in under. Nullable/additive (schema v2) — ADR-0005: this is a
  // queryable account-id <-> device-id mapping only (FR-AUTH-004, multiple
  // devices per account are independent rows); the device identity itself
  // never derives from or depends on this column or the Firebase session.
  TextColumn get accountUid => text().nullable()();
}

@DriftDatabase(tables: [
  DeviceIdentities,
  Relationships,
  SignalIdentity,
  SignalSignedPrekeys,
  SignalOneTimePrekeys,
  SignalSessions,
  SignalTrustedIdentities,
  CryptoCounters,
  Routes,
  RelayPackets,
  Messages,
  DeliveryStates,
  SyncCursors,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor — an in-memory executor, no filesystem I/O.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Additive only — no drop/backfill, per docs/conventions.md
            // "Schema migrations" (FR-VER-003).
            await m.addColumn(deviceIdentities, deviceIdentities.accountUid);
          }
          if (from < 3) {
            // E02-T01: new `relationships` table — additive, no changes to
            // existing tables.
            await m.createTable(relationships);
          }
          if (from < 4) {
            // E03-T01: Signal protocol store tables — additive, no changes
            // to existing tables (ADR-0003, docs/conventions.md "Schema
            // migrations").
            await m.createTable(signalIdentity);
            await m.createTable(signalSignedPrekeys);
            await m.createTable(signalOneTimePrekeys);
            await m.createTable(signalSessions);
          }
          if (from < 5) {
            // E03-T01b: durable remote-peer identity trust — additive, no
            // changes to existing tables (closes OQ-E03-T01-1).
            await m.createTable(signalTrustedIdentities);
          }
          if (from < 6) {
            // E03-B01: dedicated monotonic-counter table — additive, no
            // changes to existing tables. Fixes one-time-prekey id reuse
            // after the pool drains (root cause: id allocation was derived
            // from live rows only).
            await m.createTable(cryptoCounters);

            // Seed the counter from whatever one-time prekeys already
            // exist on this device at migration time, so an install
            // upgrading with a still-live (unconsumed) pool doesn't
            // immediately collide with itself on the next replenish — the
            // counter must never go backward relative to ids this device
            // has already issued. A device with no prekeys yet (or none
            // ever generated) leaves the table empty; the store treats an
            // absent row as "start at 1".
            final maxExisting = await customSelect(
              'SELECT MAX(id) AS max_id FROM signal_one_time_prekeys',
            ).getSingleOrNull();
            final maxExistingId = maxExisting?.data['max_id'] as int?;
            if (maxExistingId != null) {
              await into(cryptoCounters).insert(
                CryptoCountersCompanion.insert(
                  id: const Value(0),
                  nextOneTimePreKeyId: Value(maxExistingId + 1),
                ),
              );
            }
          }
          if (from >= 6 && from < 7) {
            // E03-B02: distribution-side issue cursor — additive column,
            // default 1 (matches a fresh `crypto_counters` row). No backfill
            // needed: an install upgrading with prekeys already handed to
            // peers has no durable record of which ones (that's the bug
            // this fixes), so the cursor starts at 1 like a fresh device.
            // Worst case on upgrade, a prekey issued pre-fix and still
            // in-flight could be reissued once; the fix's guarantee is
            // forward-only from here.
            //
            // Guarded to `from >= 6`: an install upgrading from before v6
            // never had `crypto_counters` at all, so `createTable`
            // (from < 6, above) already creates it with this device's
            // *current* full Dart table definition — column included. Only
            // an install that already had the v6 table (created without
            // this column) needs it added here; adding it unconditionally
            // would double-add the column for anyone jumping from < v6
            // straight to v7 (`duplicate column name`).
            await m.addColumn(
              cryptoCounters,
              cryptoCounters.nextIssuedOneTimePreKeyId,
            );
          }
          if (from < 8) {
            // E04-T02: new `routes` table — additive, no changes to
            // existing tables (docs/conventions.md "Schema migrations").
            await m.createTable(routes);
          }
          if (from < 9) {
            // E04-T04: new `relay_packets` table — additive, no changes to
            // existing tables (docs/conventions.md "Schema migrations").
            await m.createTable(relayPackets);
          }
          if (from < 10) {
            // E04-B02: `relay_packets.payload` becomes nullable so
            // `RelayEngine.reclaimPayloads()` can null out a terminal-state
            // row's ciphertext once it passes its own `expires_at`, without
            // dropping the row itself (kept for E13 diagnostics per T04
            // §3). SQLite has no ALTER COLUMN, so loosening an existing
            // NOT NULL column requires the standard rebuild: create the new
            // shape, copy every existing row across (including installs
            // that upgrade straight from < v9 and therefore never had this
            // table until the `from < 9` step just above ran), drop the
            // old table, rename the new one into place. Guarded to `from >=
            // 9`: an install jumping from < v9 already gets the *current*
            // Dart table definition (nullable payload included) from
            // `createTable` above, so running this rebuild unconditionally
            // would operate on a table that already has the right shape.
            if (from >= 9) {
              // Reviewer (E04-B02, 2026-08-27): the four rebuild statements
              // MUST be atomic. Drift does not wrap `onUpgrade` in a
              // transaction (`drift/src/runtime/executor/helpers/engines.dart`
              // `_runMigrations` calls `beforeOpen` directly), and it only
              // bumps `user_version` *after* onUpgrade returns. Un-wrapped, a
              // crash/kill between any two of these statements (a realistic
              // window on a large `relay_packets` table) leaves
              // `user_version` at 9 with a stale `relay_packets_v10` already
              // present — and the retry on next launch then dies on
              // `table relay_packets_v10 already exists`, bricking the
              // database permanently. Worse, a crash between the DROP and
              // the RENAME leaves no `relay_packets` at all. Inside a
              // transaction the step is all-or-nothing: a failure rolls the
              // whole rebuild back, `user_version` stays 9, and the next
              // launch retries from a clean v9 state.
              await m.database.transaction(() async {
                await m.database.customStatement(
                  'CREATE TABLE relay_packets_v10 ('
                  'id TEXT NOT NULL, '
                  'destination_id TEXT NOT NULL, '
                  'payload BLOB NULL, '
                  'priority INTEGER NOT NULL, '
                  'size_bytes INTEGER NOT NULL, '
                  'created_at INTEGER NOT NULL, '
                  'expires_at INTEGER NOT NULL, '
                  'delivery_state TEXT NOT NULL, '
                  'PRIMARY KEY (id)'
                  ');',
                );
                // Column-order-dependent by design: the `SELECT *` order
                // above is the v9 DDL order, which is identical to the new
                // table's order and to `$RelayPacketsTable.$columns`
                // (id, destination_id, payload, priority, size_bytes,
                // created_at, expires_at, delivery_state). Any future
                // reordering of `relay_tables.dart` must not touch this
                // frozen historical step.
                await m.database.customStatement(
                  'INSERT INTO relay_packets_v10 SELECT * FROM relay_packets;',
                );
                await m.database.customStatement('DROP TABLE relay_packets;');
                await m.database.customStatement(
                  'ALTER TABLE relay_packets_v10 RENAME TO relay_packets;',
                );
              });
            }
          }
          if (from < 11) {
            // E05-T01: new `messages` + `delivery_states` tables --
            // additive, no changes to existing tables (docs/conventions.md
            // "Schema migrations"). `createTable` only issues the CREATE
            // TABLE statement -- it does NOT create the
            // `idx_messages_conversation_created_at` index declared via
            // `@TableIndex` on the Messages table (indexes are separate
            // `DatabaseSchemaEntity` objects, only created via
            // `create`/`createAll`). So the index is created explicitly
            // here too, with `IF NOT EXISTS` because the generated
            // `createIndex` statement (database.g.dart) has no such guard
            // and is not retry-safe across a failed-then-retried migration.
            await m.createTable(messages);
            await m.createTable(deliveryStates);
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS '
              'idx_messages_conversation_created_at ON messages '
              '(conversation_id, created_at);',
            );
          }
          if (from < 12) {
            // E05-T04: new `sync_cursors` table -- additive only, no changes
            // to existing tables (docs/conventions.md "Schema migrations").
            // Purely additive `createTable`, unlike E04-B02's v9->v10
            // rebuild (which needed an explicit transaction wrapper because
            // it dropped/renamed an existing table) -- there is nothing to
            // wrap in a transaction here since a single CREATE TABLE is
            // already atomic in SQLite.
            //
            // No index to create alongside this one: `SyncCursors` declares
            // no `@TableIndex` (see sync_tables.dart's comment) -- so unlike
            // the `from < 11` step above, there is no companion
            // `CREATE INDEX IF NOT EXISTS` needed here. (T01's round-1
            // finding was that `createTable` never creates a declared
            // index; the fix for *this* table is simply not declaring one,
            // confirmed deliberately, not by omission.)
            await m.createTable(syncCursors);
          }
        },
      );

  /// Inserts a fresh device-identity row and returns its id. Genesis-scope:
  /// one device identity per app install is enough to prove the write path;
  /// real device-identity lifecycle (ADR-0005) is a feature-epic concern.
  Future<int> createDeviceIdentity(String deviceId) {
    return into(deviceIdentities).insert(
      DeviceIdentitiesCompanion.insert(deviceId: deviceId),
    );
  }

  /// Marks the given device identity as signed in "now", optionally
  /// recording the Firebase account uid (E01-T01).
  Future<void> markSignedIn(int id, {String? accountUid}) {
    return (update(deviceIdentities)..where((t) => t.id.equals(id))).write(
      DeviceIdentitiesCompanion(
        signedIn: const Value(true),
        signedInAt: Value(DateTime.now()),
        // absent (not null) when no uid is passed, so a caller that omits
        // accountUid never clobbers an existing account link on the row.
        accountUid: accountUid == null
            ? const Value.absent()
            : Value(accountUid),
      ),
    );
  }

  /// Reads back the most recently created device identity, if any.
  Future<DeviceIdentity?> latestDeviceIdentity() {
    return (select(deviceIdentities)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'nexora.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
