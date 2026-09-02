// E08-T01 — storage lifecycle tables (`storage_item_stats`,
// `storage_policy_settings`, `storage_decisions`). Fresh in-memory database
// per test (the onCreate path) -- the v13->v14 upgrade path itself is
// covered by test/core/persistence/database_migration_test.dart's
// test_EARS_STORE_3/4 tests. This file exercises the tables' own shape:
// nullability, defaults, and the single-row invariant on
// `storage_policy_settings` (task §5).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('storage_item_stats', () {
    test('an absent row means "never observed" -- no backfill from messages',
        () async {
      // Task §4: this task does not backfill from existing `messages` rows.
      // A fresh database has zero stat rows even though other tables may
      // hold data -- an absent row, not a zeroed one, is the honest
      // default.
      expect(await db.select(db.storageItemStats).get(), isEmpty);
    });

    test('lastAccessedAt defaults to NULL, never 0, and accessCount to 0',
        () async {
      await db.into(db.storageItemStats).insert(
            StorageItemStatsCompanion.insert(
              itemKind: 'message',
              itemId: 'msg-1',
            ),
          );
      final row = await db.select(db.storageItemStats).getSingle();
      expect(row.lastAccessedAt, isNull);
      expect(row.accessCount, 0);
    });

    test('primary key is (itemKind, itemId) -- a duplicate pair conflicts',
        () async {
      await db.into(db.storageItemStats).insert(
            StorageItemStatsCompanion.insert(
              itemKind: 'message',
              itemId: 'msg-1',
            ),
          );
      await expectLater(
        db.into(db.storageItemStats).insert(
              StorageItemStatsCompanion.insert(
                itemKind: 'message',
                itemId: 'msg-1',
              ),
            ),
        throwsA(isA<sqlite3.SqliteException>()),
      );
    });

    test('the same itemId under a different itemKind is a distinct row',
        () async {
      await db.into(db.storageItemStats).insert(
            StorageItemStatsCompanion.insert(
              itemKind: 'message',
              itemId: 'shared-id',
            ),
          );
      await db.into(db.storageItemStats).insert(
            StorageItemStatsCompanion.insert(
              itemKind: 'relayPacket',
              itemId: 'shared-id',
            ),
          );
      expect(await db.select(db.storageItemStats).get(), hasLength(2));
    });

    test('lastAccessedAt and accessCount are writable once observed',
        () async {
      await db.into(db.storageItemStats).insert(
            StorageItemStatsCompanion.insert(
              itemKind: 'message',
              itemId: 'msg-1',
              lastAccessedAt: const Value(5000),
              accessCount: const Value(3),
            ),
          );
      final row = await db.select(db.storageItemStats).getSingle();
      expect(row.lastAccessedAt, 5000);
      expect(row.accessCount, 3);
    });
  });

  group('storage_policy_settings', () {
    test(
        'exactly one row exists on a fresh database, mode smart, budgetBytes null',
        () async {
      final rows = await db.select(db.storagePolicySettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 1);
      expect(rows.single.mode, 'smart');
      expect(rows.single.budgetBytes, isNull);
      expect(rows.single.olderThanDays, isNull);
      expect(rows.single.maxBytes, isNull);
    });

    test('a second row (id != 1) is not the schema-enforced single row, '
        'but id=1 is the only one the app ever creates', () async {
      // The schema does not forbid a second id -- "exactly one active
      // policy" is an invariant the app maintains by only ever touching
      // id=1 (task §2), not one SQLite enforces on its own beyond the PK.
      // This test documents that boundary rather than asserting a
      // constraint this task never added.
      await db.into(db.storagePolicySettings).insert(
            StoragePolicySettingsCompanion.insert(
              id: const Value(2),
              mode: 'overSizeMb',
              updatedAt: 1000,
            ),
          );
      final rows = await db.select(db.storagePolicySettings).get();
      expect(rows, hasLength(2));
    });

    test('re-inserting id=1 conflicts with the migration-seeded default row',
        () async {
      await expectLater(
        db.into(db.storagePolicySettings).insert(
              StoragePolicySettingsCompanion.insert(
                id: const Value(1),
                mode: 'olderThanDays',
                updatedAt: 1000,
              ),
            ),
        throwsA(isA<sqlite3.SqliteException>()),
      );
    });

    test('mode can be updated in place on the single row', () async {
      await (db.update(db.storagePolicySettings)
            ..where((t) => t.id.equals(1)))
          .write(
        StoragePolicySettingsCompanion(
          mode: const Value('olderThanDays'),
          olderThanDays: const Value(45),
          updatedAt: Value(2000),
        ),
      );
      final row = await db.select(db.storagePolicySettings).getSingle();
      expect(row.mode, 'olderThanDays');
      expect(row.olderThanDays, 45);
      // budgetBytes stays NULL -- untouched by this update, not overwritten.
      expect(row.budgetBytes, isNull);
    });
  });

  group('storage_decisions', () {
    test('a decision row carries measured bytes and a machine-key reason',
        () async {
      await db.into(db.storageDecisions).insert(
            StorageDecisionsCompanion.insert(
              id: 'dec-1',
              decidedAt: 1000,
              mode: 'smart',
              categoryKey: 'relayCache',
              itemCount: 10,
              bytes: 20480,
              reasonCode: 'olderThanDays',
              reasonDetail: const Value('45'),
              outcome: 'planned',
            ),
          );
      final row = await db.select(db.storageDecisions).getSingle();
      expect(row.categoryKey, 'relayCache');
      expect(row.reasonCode, 'olderThanDays');
      expect(row.reasonDetail, '45');
      expect(row.outcome, 'planned');
      expect(row.bytes, 20480);
    });

    test('reasonDetail is nullable for a reason with no parameter',
        () async {
      await db.into(db.storageDecisions).insert(
            StorageDecisionsCompanion.insert(
              id: 'dec-2',
              decidedAt: 1000,
              mode: 'smart',
              categoryKey: 'messages',
              itemCount: 1,
              bytes: 100,
              reasonCode: 'noLongerRequired',
              outcome: 'applied',
            ),
          );
      final row = await db.select(db.storageDecisions).getSingle();
      expect(row.reasonDetail, isNull);
    });

    test('id is the primary key -- a duplicate id conflicts', () async {
      await db.into(db.storageDecisions).insert(
            StorageDecisionsCompanion.insert(
              id: 'dec-3',
              decidedAt: 1000,
              mode: 'smart',
              categoryKey: 'messages',
              itemCount: 1,
              bytes: 100,
              reasonCode: 'noLongerRequired',
              outcome: 'applied',
            ),
          );
      await expectLater(
        db.into(db.storageDecisions).insert(
              StorageDecisionsCompanion.insert(
                id: 'dec-3',
                decidedAt: 2000,
                mode: 'smart',
                categoryKey: 'relayCache',
                itemCount: 2,
                bytes: 200,
                reasonCode: 'olderThanDays',
                outcome: 'skipped',
              ),
            ),
        throwsA(isA<sqlite3.SqliteException>()),
      );
    });
  });
}
