// test/core/storage — E08-T05, ManualPolicy's two non-default modes.
//
// ManualPolicy.plan() is a pure-Dart async function whose only I/O is the
// injected `items` callback -- no real AppDatabase needed. Every test here
// builds its inputs as plain Dart values and a fake in-memory `items`
// function, mirroring smart_mode_policy_test.dart's style.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/manual_policy.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart';

const _dayMs = 24 * 60 * 60 * 1000;

StorageItem _message({
  required String id,
  required int createdAt,
  int bytes = 100,
  String conversationId = 'conv-default',
}) {
  return StorageItem(
    kind: StorageItemKind.message,
    id: id,
    conversationId: conversationId,
    bytes: bytes,
    createdAt: createdAt,
    isTemporary: false,
  );
}

StoragePolicySettingRow _settings({
  required String mode,
  int? olderThanDays,
  int? maxBytes,
}) {
  return StoragePolicySettingRow(
    id: 1,
    mode: mode,
    olderThanDays: olderThanDays,
    maxBytes: maxBytes,
    budgetBytes: null,
    updatedAt: 0,
  );
}

/// A fake `StorageInventory.itemsOfKind`-shaped callback backed by a fixed
/// in-memory list, applying the same `olderThanEpochMs` pushdown filter the
/// real implementation does.
Future<List<StorageItem>> Function(
  StorageItemKind kind, {
  int? olderThanEpochMs,
}) _fakeItems(List<StorageItem> allItems) {
  return (StorageItemKind kind, {int? olderThanEpochMs}) async {
    return allItems.where((item) {
      if (item.kind != kind) return false;
      if (olderThanEpochMs != null && item.createdAt >= olderThanEpochMs) {
        return false;
      }
      return true;
    }).toList();
  };
}

void main() {
  const policy = ManualPolicy();
  const nowEpochMs = 1000 * _dayMs;

  group('StorageMode.smart is rejected', () {
    test('plan() throws StateError for StorageMode.smart', () {
      expect(
        () => policy.plan(
          mode: StorageMode.smart,
          snapshot: StorageInventorySnapshot(
            classTotals: const [],
            databaseFileBytes: 0,
            measuredAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
          ),
          items: _fakeItems(const []),
          settings: _settings(mode: 'smart'),
          nowEpochMs: nowEpochMs,
        ),
        throwsStateError,
      );
    });
  });

  group('EARS-STORE-12 — olderThanDays selects only by age', () {
    test('test_EARS_STORE_12_older_than_selects_only_by_age', () async {
      // A recent item (5 days old) stays; an old item (60 days old) is a
      // candidate -- and stays a candidate even though it is "frequently
      // accessed" in the outside world, because ManualPolicy.plan never
      // receives access-frequency data at all (task §2: a manual policy
      // considers only its own single stated rule, unlike Smart Mode).
      final recentItem = _message(
        id: 'recent',
        createdAt: nowEpochMs - (5 * _dayMs),
      );
      final oldButFrequentlyAccessedItem = _message(
        id: 'old-but-hot',
        createdAt: nowEpochMs - (60 * _dayMs),
      );
      final items = [recentItem, oldButFrequentlyAccessedItem];

      final snapshot = StorageInventorySnapshot(
        classTotals: [
          StorageClassTotal(
            kind: StorageItemKind.message,
            itemCount: items.length,
            bytes: items.fold<int>(0, (s, i) => s + i.bytes),
          ),
        ],
        databaseFileBytes: 0,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
      );

      final plan = await policy.plan(
        mode: StorageMode.olderThanDays,
        snapshot: snapshot,
        items: _fakeItems(items),
        settings: _settings(mode: 'olderThanDays', olderThanDays: 45),
        nowEpochMs: nowEpochMs,
      );

      expect(plan.mode, 'olderThanDays');
      expect(plan.groups, hasLength(1));
      final group = plan.groups.single;
      expect(group.reason, RetentionReason.olderThan);
      expect(group.itemIds, ['old-but-hot']);
      expect(group.itemCount, 1);
      expect(group.bytes, oldButFrequentlyAccessedItem.bytes);
      expect(group.reasonDetail, '45');

      // Never scores Smart Mode's factors.
      expect(plan.availableFactors, isEmpty);
      expect(plan.unavailableFactors, isEmpty);
    });

    test('a kind with zero items today contributes no group', () async {
      final snapshot = StorageInventorySnapshot(
        classTotals: const [
          StorageClassTotal(
            kind: StorageItemKind.relayPayload,
            itemCount: 0,
            bytes: 0,
          ),
        ],
        databaseFileBytes: 0,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
      );

      final plan = await policy.plan(
        mode: StorageMode.olderThanDays,
        snapshot: snapshot,
        items: _fakeItems(const []),
        settings: _settings(mode: 'olderThanDays', olderThanDays: 1),
        nowEpochMs: nowEpochMs,
      );

      expect(plan.groups, isEmpty);
      expect(plan.totalBytes, 0);
    });
  });

  group('EARS-STORE-12 — overSizeMb selects oldest-first until under cap', () {
    test('test_EARS_STORE_12_over_size_selects_oldest_first_until_under_cap',
        () async {
      // Four items, 100 bytes each, cap at 250 bytes -- 100 bytes over.
      // Oldest-first removal must remove exactly the two oldest (200 bytes)
      // to land at 200 <= 250... but removing only the single oldest lands
      // at 300 > 250, so two removals are required to get under the cap.
      final oldest = _message(id: 'a', createdAt: 1000, bytes: 100);
      final second = _message(id: 'b', createdAt: 2000, bytes: 100);
      final third = _message(id: 'c', createdAt: 3000, bytes: 100);
      final newest = _message(id: 'd', createdAt: 4000, bytes: 100);
      final items = [newest, third, oldest, second]; // deliberately unsorted

      final snapshot = StorageInventorySnapshot(
        classTotals: [
          StorageClassTotal(
            kind: StorageItemKind.message,
            itemCount: items.length,
            bytes: 400,
          ),
        ],
        databaseFileBytes: 0,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
      );

      final plan = await policy.plan(
        mode: StorageMode.overSizeMb,
        snapshot: snapshot,
        items: _fakeItems(items),
        settings: _settings(mode: 'overSizeMb', maxBytes: 250),
        nowEpochMs: nowEpochMs,
      );

      expect(plan.groups, hasLength(1));
      final group = plan.groups.single;
      expect(group.reason, RetentionReason.overSizeLimit);
      expect(group.itemIds, ['a', 'b']); // the two oldest, sorted by id
      expect(group.bytes, 200);
      expect(group.reasonDetail, '250');
    });

    test('deterministic tie-break by id when createdAt is identical',
        () async {
      final tiedOld1 = _message(id: 'zzz', createdAt: 1000, bytes: 100);
      final tiedOld2 = _message(id: 'aaa', createdAt: 1000, bytes: 100);
      final newer = _message(id: 'mmm', createdAt: 2000, bytes: 100);
      final items = [newer, tiedOld1, tiedOld2];

      final snapshot = StorageInventorySnapshot(
        classTotals: const [
          StorageClassTotal(
            kind: StorageItemKind.message,
            itemCount: 3,
            bytes: 300,
          ),
        ],
        databaseFileBytes: 0,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
      );

      final plan = await policy.plan(
        mode: StorageMode.overSizeMb,
        snapshot: snapshot,
        items: _fakeItems(items),
        settings: _settings(mode: 'overSizeMb', maxBytes: 250),
        nowEpochMs: nowEpochMs,
      );

      // 300 total, cap 250 -- removing one of the tied-oldest pair (100
      // bytes) lands at 200 <= 250. The tie-break must pick 'aaa' (the
      // lexicographically smaller id) deterministically, never 'zzz'.
      final group = plan.groups.single;
      expect(group.itemIds, ['aaa']);
    });

    test('a kind under its cap contributes no group', () async {
      final item = _message(id: 'a', createdAt: 1000, bytes: 100);
      final snapshot = StorageInventorySnapshot(
        classTotals: const [
          StorageClassTotal(
            kind: StorageItemKind.message,
            itemCount: 1,
            bytes: 100,
          ),
        ],
        databaseFileBytes: 0,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
      );

      final plan = await policy.plan(
        mode: StorageMode.overSizeMb,
        snapshot: snapshot,
        items: _fakeItems([item]),
        settings: _settings(mode: 'overSizeMb', maxBytes: 1024),
        nowEpochMs: nowEpochMs,
      );

      expect(plan.groups, isEmpty);
    });
  });

  group('EARS-STORE-12 — determinism', () {
    test('test_EARS_STORE_12_manual_plan_is_deterministic', () async {
      final a = _message(id: 'a', createdAt: 1000, bytes: 100);
      final b = _message(id: 'b', createdAt: 2000, bytes: 100);
      final c = _message(id: 'c', createdAt: 3000, bytes: 100);

      final snapshot = StorageInventorySnapshot(
        classTotals: const [
          StorageClassTotal(
            kind: StorageItemKind.message,
            itemCount: 3,
            bytes: 300,
          ),
        ],
        databaseFileBytes: 0,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
      );
      final settings = _settings(mode: 'overSizeMb', maxBytes: 150);

      final plan1 = await policy.plan(
        mode: StorageMode.overSizeMb,
        snapshot: snapshot,
        items: _fakeItems([a, b, c]),
        settings: settings,
        nowEpochMs: nowEpochMs,
      );
      final plan2 = await policy.plan(
        mode: StorageMode.overSizeMb,
        snapshot: snapshot,
        items: _fakeItems([c, a, b]), // reversed order
        settings: settings,
        nowEpochMs: nowEpochMs,
      );

      expect(plan1.groups, hasLength(plan2.groups.length));
      for (var i = 0; i < plan1.groups.length; i++) {
        expect(plan1.groups[i].categoryKey, plan2.groups[i].categoryKey);
        expect(plan1.groups[i].reason, plan2.groups[i].reason);
        expect(plan1.groups[i].itemIds, plan2.groups[i].itemIds);
        expect(plan1.groups[i].bytes, plan2.groups[i].bytes);
      }
      expect(plan1.totalBytes, plan2.totalBytes);
    });
  });
}
