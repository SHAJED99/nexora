// core/persistence -- location sharing tables (E09-T01).
//
// Direct unit coverage of the three Dart table definitions in
// location_tables.dart, run through a fresh in-memory database (onCreate
// path). Migration-shape coverage (v14 -> v15, exact table/index set,
// byte-identical pre-existing DDL, default row on both onCreate and
// onUpgrade) lives in database_migration_test.dart per task §8.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('LocationSettings', () {
    test(
      'test_EARS_LOC_3_default_settings_row_on_fresh_create',
      () async {
        final rows = await db.select(db.locationSettings).get();
        expect(rows, hasLength(1));
        expect(rows.single.id, 1);
        expect(rows.single.globalEnabled, isFalse);
      },
    );

    test('global_enabled asserted through the generated Dart bool type',
        () async {
      final row = await db.select(db.locationSettings).getSingle();
      // Guards against the §6 risk note: BOOLEAN in SQLite is an INTEGER: a
      // test comparing against 0 in a context where Drift already mapped the
      // column would pass for the wrong reason. This compares against the
      // real Dart `bool` the generated row type exposes.
      expect(row.globalEnabled, isA<bool>());
      expect(row.globalEnabled, false);
    });
  });

  group('LocationPeerSettings', () {
    test('no row for a peer -- absent means not enabled, never queried true',
        () async {
      final rows = await db.select(db.locationPeerSettings).get();
      expect(rows, isEmpty);
    });

    test('insert then update by primary key (peer_device_id) replaces, '
        'does not add a second row', () async {
      await db.into(db.locationPeerSettings).insert(
            LocationPeerSettingsCompanion.insert(
              peerDeviceId: 'peer-1',
              enabled: const Value(true),
              updatedAt: 1000,
            ),
          );
      await db.into(db.locationPeerSettings).insertOnConflictUpdate(
            LocationPeerSettingsCompanion.insert(
              peerDeviceId: 'peer-1',
              enabled: const Value(false),
              updatedAt: 2000,
            ),
          );

      final rows = await db.select(db.locationPeerSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.enabled, isFalse);
      expect(rows.single.updatedAt, 2000);
    });

    test('two peers coexist as independent rows', () async {
      await db.into(db.locationPeerSettings).insert(
            LocationPeerSettingsCompanion.insert(
              peerDeviceId: 'peer-1',
              enabled: const Value(true),
              updatedAt: 1000,
            ),
          );
      await db.into(db.locationPeerSettings).insert(
            LocationPeerSettingsCompanion.insert(
              peerDeviceId: 'peer-2',
              enabled: const Value(false),
              updatedAt: 1000,
            ),
          );

      final rows = await db.select(db.locationPeerSettings).get();
      expect(rows, hasLength(2));
    });
  });

  group('LocationFixes', () {
    test(
      'test_EARS_LOC_5_second_fix_for_peer_replaces_not_appends',
      () async {
        await db.into(db.locationFixes).insert(
              LocationFixesCompanion.insert(
                peerDeviceId: 'peer-1',
                latitude: 1.0,
                longitude: 1.0,
                capturedAt: 1000,
                receivedAt: 1000,
              ),
            );
        await db.into(db.locationFixes).insertOnConflictUpdate(
              LocationFixesCompanion.insert(
                peerDeviceId: 'peer-1',
                latitude: 2.0,
                longitude: 2.0,
                capturedAt: 2000,
                receivedAt: 2000,
              ),
            );

        final rows = await db.select(db.locationFixes).get();
        expect(rows, hasLength(1));
        expect(rows.single.latitude, 2.0);
        expect(rows.single.longitude, 2.0);
        expect(rows.single.capturedAt, 2000);
        expect(rows.single.receivedAt, 2000);
      },
    );

    test(
      'test_EARS_LOC_5_fixes_for_two_peers_coexist',
      () async {
        await db.into(db.locationFixes).insert(
              LocationFixesCompanion.insert(
                peerDeviceId: 'peer-1',
                latitude: 1.0,
                longitude: 1.0,
                capturedAt: 1000,
                receivedAt: 1000,
              ),
            );
        await db.into(db.locationFixes).insert(
              LocationFixesCompanion.insert(
                peerDeviceId: 'peer-2',
                latitude: 2.0,
                longitude: 2.0,
                capturedAt: 1000,
                receivedAt: 1000,
              ),
            );

        final rows = await db.select(db.locationFixes).get();
        expect(rows, hasLength(2));
      },
    );

    test('accuracy_m NULL round-trips as null, never 0', () async {
      await db.into(db.locationFixes).insert(
            LocationFixesCompanion.insert(
              peerDeviceId: 'peer-1',
              latitude: 1.0,
              longitude: 1.0,
              capturedAt: 1000,
              receivedAt: 1000,
              // accuracyM omitted -- absent, not zero.
            ),
          );

      final row = await db.select(db.locationFixes).getSingle();
      expect(row.accuracyM, isNull);
    });

    test('accuracy_m round-trips a real value when provided', () async {
      await db.into(db.locationFixes).insert(
            LocationFixesCompanion.insert(
              peerDeviceId: 'peer-1',
              latitude: 1.0,
              longitude: 1.0,
              accuracyM: const Value(12.5),
              capturedAt: 1000,
              receivedAt: 1000,
            ),
          );

      final row = await db.select(db.locationFixes).getSingle();
      expect(row.accuracyM, 12.5);
    });

    test('captured_at and received_at are independent columns', () async {
      await db.into(db.locationFixes).insert(
            LocationFixesCompanion.insert(
              peerDeviceId: 'peer-1',
              latitude: 1.0,
              longitude: 1.0,
              capturedAt: 1000,
              receivedAt: 5000,
            ),
          );

      final row = await db.select(db.locationFixes).getSingle();
      expect(row.capturedAt, 1000);
      expect(row.receivedAt, 5000);
      expect(row.capturedAt, isNot(row.receivedAt));
    });
  });
}
