// test/core/storage — E08-B01 regression test.
//
// `ManualPolicy._planOverSize` pools `itemsOfKind` with no paging, so past
// `itemsOfKind`'s default 500-item bound it sorts oldest-first *within the
// newest 500* rather than across the whole kind -- selecting the wrong
// items for deletion entirely (the reviewer's own bug-sweep repro: 600
// messages, cap forces ~76 removed, but the wrong 76 -- ids m-00100..m-00175
// instead of the genuinely-oldest m-00000..m-00075).
//
// This test seeds more than `itemsOfKind`'s default limit's worth of items
// in one kind and asserts the selected ids for `overSizeMb` are the
// genuinely-oldest ones. It fails on the pre-fix code with the documented
// `m-00100`..`m-00175` signature, and passes after the fix (paged,
// oldest-first selection across the whole kind, per `E08-B01.md`'s own Fix
// direction).
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/manual_policy.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart';

/// A fake `StorageInventory.itemsOfKind`-shaped callback that reproduces the
/// REAL implementation's bounded behaviour exactly: default `limit: 500`,
/// newest-first unless `oldestFirst: true`, `offset` paging. Unlike a fake
/// that simply returns every matching item unconditionally, this one is
/// what makes the bug reproducible at all -- the real `itemsOfKind` really
/// does stop at 500 newest items by default.
StorageItemsFetcher _boundedFakeItems(List<StorageItem> allItems) {
  return (
    StorageItemKind kind, {
    int limit = 500,
    int? olderThanEpochMs,
    bool oldestFirst = false,
    int offset = 0,
  }) async {
    var matching = allItems.where((item) {
      if (item.kind != kind) return false;
      if (olderThanEpochMs != null && item.createdAt >= olderThanEpochMs) {
        return false;
      }
      return true;
    }).toList();
    matching.sort((a, b) {
      final byAge = oldestFirst
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt);
      if (byAge != 0) return byAge;
      return a.id.compareTo(b.id);
    });
    if (offset >= matching.length) return const [];
    final end = (offset + limit).clamp(0, matching.length);
    return matching.sublist(offset, end);
  };
}

String _paddedId(int i) => 'm-${i.toString().padLeft(5, '0')}';

void main() {
  const policy = ManualPolicy();
  const nowEpochMs = 1000 * 24 * 60 * 60 * 1000;

  test(
    'test_E08_B01_over_size_selects_genuinely_oldest_past_500_items',
    () async {
      // 600 messages, 2000 bytes each, ids m-00000 (oldest) .. m-00599
      // (newest) -- exactly the bug-sweep repro in E08-B01.md.
      const itemCount = 600;
      const bytesPerItem = 2000;
      final items = <StorageItem>[
        for (var i = 0; i < itemCount; i++)
          StorageItem(
            kind: StorageItemKind.message,
            id: _paddedId(i),
            conversationId: 'conv-1',
            bytes: bytesPerItem,
            createdAt: i, // ascending: index 0 is genuinely oldest
            isTemporary: false,
          ),
      ];
      const totalBytes = itemCount * bytesPerItem; // 1,200,000
      const maxBytes = 1048576; // 1 MiB -- 151,424 bytes over cap

      final snapshot = StorageInventorySnapshot(
        classTotals: [
          StorageClassTotal(
            kind: StorageItemKind.message,
            itemCount: itemCount,
            bytes: totalBytes,
          ),
        ],
        databaseFileBytes: 0,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
      );

      final settings = StoragePolicySettingRow(
        id: 1,
        mode: 'overSizeMb',
        olderThanDays: null,
        maxBytes: maxBytes,
        budgetBytes: null,
        updatedAt: 0,
      );

      final plan = await policy.plan(
        mode: StorageMode.overSizeMb,
        snapshot: snapshot,
        items: _boundedFakeItems(items),
        settings: settings,
        nowEpochMs: nowEpochMs,
      );

      expect(plan.groups, hasLength(1));
      final group = plan.groups.single;
      expect(group.reason, RetentionReason.overSizeLimit);

      // The genuinely-oldest 76 items -- m-00000 .. m-00075 -- must be the
      // ones selected. The pre-fix code selects m-00100 .. m-00175 instead
      // (the oldest-sorted subset of the newest-500 pool), which is
      // disjoint from the correct answer.
      final expectedIds = [for (var i = 0; i < 76; i++) _paddedId(i)];
      expect(group.itemIds, expectedIds);
      expect(group.itemCount, 76);
      expect(group.bytes, 76 * bytesPerItem);

      // The genuinely-oldest item must be present, and the wrong-window
      // item the pre-fix bug selects instead must not be.
      expect(group.itemIds, contains('m-00000'));
      expect(group.itemIds, isNot(contains('m-00100')));
    },
  );
}
