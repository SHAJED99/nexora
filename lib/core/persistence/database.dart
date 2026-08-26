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

@DriftDatabase(tables: [DeviceIdentities])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor — an in-memory executor, no filesystem I/O.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Additive only — no drop/backfill, per docs/conventions.md
            // "Schema migrations" (FR-VER-003).
            await m.addColumn(deviceIdentities, deviceIdentities.accountUid);
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
