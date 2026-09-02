// test/core/storage — E08-B07 regression test.
//
// `ManualPolicy._planOlderThan` calls `items(kind, olderThanEpochMs: cutoff)`
// with no paging and no `oldestFirst`, so past `itemsOfKind`'s default
// 500-item bound it gets whatever the default-limited, newest-first query
// returns among the aged set -- the NEWEST 500 of the items older than the
// cutoff, not the OLDEST 500 (the ones a user asking to "delete data older
// than X days" would expect to go first). This is under-deletion (a valid
// but non-ideal set is removed), not wrong-deletion, unlike `E08-B01`.
//
// This test seeds more than `itemsOfKind`'s default limit's worth of items
// older than the cutoff, with a spread of ages beyond it, and asserts the
// selected ids for `olderThanDays` are the genuinely-oldest ones among the
// aged set. It fails on the pre-fix code with the documented
// `min=m-01000 max=m-01499`-shaped signature from `E08-B07.md`'s own repro,
// and passes after the fix (paged, oldest-first selection across the whole
// aged set, per `E08-B07.md`'s own Fix direction -- reusing `E08-B01`'s
// paging pattern rather than a new algorithm).
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/manual_policy.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart';

/// A fake `StorageInventory.itemsOfKind`-shaped callback that reproduces the
/// REAL implementation's bounded behaviour exactly: default `limit: 500`,
/// newest-first unless `oldestFirst: true`, `offset` paging, and pushes
/// `olderThanEpochMs` down as a filter. Unlike a fake that simply returns
/// every matching item unconditionally, this one is what makes the bug
/// reproducible at all -- the real `itemsOfKind` really does stop at 500
/// newest-of-matching items by default.
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
  const olderThanDays = 30;
  const cutoffEpochMs =
      nowEpochMs - olderThanDays * 24 * 60 * 60 * 1000;

  test(
    'test_E08_B07_older_than_selects_genuinely_oldest_past_500_aged_items',
    () async {
      // 1500 messages, all older than the 30-day cutoff, with a spread of
      // ages beyond it -- ids m-00000 (oldest) .. m-01499 (newest of the
      // aged set), exactly the reviewer's repro in E08-B07.md. Plus a block
      // of messages NOT older than the cutoff, to prove they stay excluded.
      const agedCount = 1500;
      const bytesPerItem = 2000;
      // Spread ages: oldest item is the furthest below cutoffEpochMs, newest
      // of the aged set is just short of the cutoff -- one minute of spread
      // per id, going from oldest to newest, all still older than the
      // cutoff.
      final agedItems = <StorageItem>[
        for (var i = 0; i < agedCount; i++)
          StorageItem(
            kind: StorageItemKind.message,
            id: _paddedId(i),
            conversationId: 'conv-1',
            bytes: bytesPerItem,
            createdAt: cutoffEpochMs - (agedCount - i) * 60 * 1000,
            isTemporary: false,
          ),
      ];
      // Not-aged block: created after the cutoff, must never be selected.
      final freshItems = <StorageItem>[
        for (var i = 0; i < 50; i++)
          StorageItem(
            kind: StorageItemKind.message,
            id: 'fresh-${i.toString().padLeft(5, '0')}',
            conversationId: 'conv-1',
            bytes: bytesPerItem,
            createdAt: cutoffEpochMs + (i + 1) * 60 * 1000,
            isTemporary: false,
          ),
      ];
      final allItems = [...agedItems, ...freshItems];
      final itemCount = allItems.length;
      final totalBytes = itemCount * bytesPerItem;

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
        mode: 'olderThanDays',
        olderThanDays: olderThanDays,
        maxBytes: null,
        budgetBytes: null,
        updatedAt: 0,
      );

      final plan = await policy.plan(
        mode: StorageMode.olderThanDays,
        snapshot: snapshot,
        items: _boundedFakeItems(allItems),
        settings: settings,
        nowEpochMs: nowEpochMs,
      );

      expect(plan.groups, hasLength(1));
      final group = plan.groups.single;
      expect(group.reason, RetentionReason.olderThan);

      // Every genuinely-aged item must be selected -- olderThanDays has no
      // early-termination cap, unlike overSizeMb's byte ceiling (E08-B07.md
      // §Fix direction): "everything older than X days" means the WHOLE
      // aged set, not just a page-size-bounded slice of it.
      final expectedIds = [for (var i = 0; i < agedCount; i++) _paddedId(i)]
        ..sort();
      expect(group.itemIds, expectedIds);
      expect(group.itemCount, agedCount);
      expect(group.bytes, agedCount * bytesPerItem);

      // The genuinely-oldest item must be present, and no fresh (not-aged)
      // item must ever be selected.
      expect(group.itemIds, contains('m-00000'));
      for (final fresh in freshItems) {
        expect(group.itemIds, isNot(contains(fresh.id)));
      }
    },
  );
}
