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
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/manual_policy.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';

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

  group(
    'E08-B07 round-1 review — safe past the SQLite bind-variable limit '
    '(post-E08-B03 chunking)',
    () {
      // Round-1 review found that this fix, on its own, reproduces the exact
      // SQL-variable-limit regression E08-B03's own round-1 review caught
      // elsewhere: removing `_planOlderThan`'s 500-item cap means a single
      // `RetentionCandidateGroup` can now hold every genuinely-aged item in
      // a kind, unbounded -- and `RetentionExecutor`'s `IN (...)`-style
      // queries (`deleteMessageItems`, `_deleteBookkeeping`,
      // `_splitByDeliveryState`) each bind one SQL variable per id. Past
      // SQLite's `SQLITE_MAX_VARIABLE_NUMBER` (32766 in this build), an
      // unchunked query throws `SqliteException(1): too many SQL
      // variables`. E08-B03's merged fix (`af02704`) chunks every one of
      // those queries into <=500-id batches, which is what makes this fix
      // safe to ship without reintroducing an early-termination cap that
      // would defeat E08-B07's own purpose.
      //
      // This test proves the fix end-to-end: a real `AppDatabase`, a real
      // `StorageInventory`, `ManualPolicy.plan` producing the (now
      // unbounded) group, and `RetentionExecutor.apply` actually deleting
      // it -- not `_planOlderThan` in isolation. 40,000 (> 32,766) is
      // comfortably past the bind-variable ceiling.
      test(
        'test_E08_B07_end_to_end_apply_selects_and_deletes_all_aged_items_'
        'past_the_sqlite_variable_limit',
        () async {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);

          const agedCount = 40000;
          const freshCount = 100;
          const bytesPerItem = 10;

          final agedIds = List<String>.generate(
            agedCount,
            (i) => 'm-${i.toString().padLeft(6, '0')}',
          );
          final freshIds = List<String>.generate(
            freshCount,
            (i) => 'fresh-${i.toString().padLeft(4, '0')}',
          );

          await db.batch((batch) {
            batch.insertAll(db.messages, [
              // Aged: spread of ages, all older than the 30-day cutoff --
              // one minute apart, oldest (index 0) to newest-of-aged
              // (index agedCount - 1, still older than cutoff).
              for (var i = 0; i < agedCount; i++)
                MessagesCompanion.insert(
                  id: agedIds[i],
                  conversationId: 'conv-1',
                  senderDeviceId: 'device-1',
                  sequenceNumber: 1,
                  ciphertext: Uint8List.fromList(
                    List<int>.filled(bytesPerItem, 0x41),
                  ),
                  createdAt: cutoffEpochMs - (agedCount - i) * 60 * 1000,
                  deliveryState: DeliveryState.stored.name,
                ),
              // Fresh: created after the cutoff, must survive the pass.
              for (var i = 0; i < freshCount; i++)
                MessagesCompanion.insert(
                  id: freshIds[i],
                  conversationId: 'conv-1',
                  senderDeviceId: 'device-1',
                  sequenceNumber: 1,
                  ciphertext: Uint8List.fromList(
                    List<int>.filled(bytesPerItem, 0x41),
                  ),
                  createdAt: cutoffEpochMs + (i + 1) * 60 * 1000,
                  deliveryState: DeliveryState.stored.name,
                ),
            ]);
          });

          final inventory = StorageInventory(
            db: db,
            databaseFileBytes: () async => 0,
          );
          final snapshot = await inventory.snapshot();

          final settings = StoragePolicySettingRow(
            id: 1,
            mode: 'olderThanDays',
            olderThanDays: olderThanDays,
            maxBytes: null,
            budgetBytes: null,
            updatedAt: 0,
          );

          // Plan through the REAL `itemsOfKind`, not a fake -- proves the
          // fixed `_planOlderThan` call site pages correctly against the
          // real, bounded-per-call SQL query it was written against.
          final plan = await const ManualPolicy().plan(
            mode: StorageMode.olderThanDays,
            snapshot: snapshot,
            items: inventory.itemsOfKind,
            settings: settings,
            nowEpochMs: nowEpochMs,
          );

          expect(plan.groups, hasLength(1));
          expect(
            plan.groups.single.itemCount,
            agedCount,
            reason: 'the whole aged set must be selected, not just the '
                'first 500 -- the under-deletion bug this task fixes',
          );

          final executor = RetentionExecutor(
            db: db,
            log: StorageDecisionLog(db: db),
          );

          // The load-bearing assertion: this must complete without
          // throwing. Pre-E08-B03, an unchunked `RetentionExecutor` would
          // throw `SqliteException(1): too many SQL variables` here (see
          // the falsification test below), rolling back the whole group
          // and permanently, silently failing every subsequent
          // `olderThanDays` pass for this kind.
          final outcome = await executor.apply(
            plan,
            allowedKinds: const <StorageItemKind>{StorageItemKind.message},
            nowEpochMs: nowEpochMs,
          );

          expect(outcome.skippedGroups, isEmpty);
          expect(outcome.appliedGroups, hasLength(1));
          expect(outcome.appliedGroups.single.itemCount, agedCount);
          expect(outcome.bytesReclaimed, agedCount * bytesPerItem);

          // Every aged message is gone; every fresh one survives.
          final remaining = await db.select(db.messages).get();
          expect(remaining, hasLength(freshCount));
          expect(
            remaining.map((r) => r.id).toSet(),
            freshIds.toSet(),
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      // Falsification: proves the mechanism that made the original fix
      // (paging `_planOlderThan` with no cap, pre-E08-B03) a real
      // regression. A single unchunked `isIn(...)` delete over the SAME
      // id count `RetentionExecutor` would have received from this fix,
      // run directly against `db.delete`, throws exactly the documented
      // `SqliteException` -- confirming that a `RetentionExecutor` without
      // E08-B03's chunking (i.e. the code this fix would have shipped
      // against, had B03 not merged first) really would have thrown for
      // this scenario, rather than merely being asserted to.
      test(
        'test_E08_B07_falsification_an_unchunked_delete_at_this_id_count_'
        'throws',
        () async {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);

          const agedCount = 40000;
          final agedIds = List<String>.generate(
            agedCount,
            (i) => 'm-${i.toString().padLeft(6, '0')}',
          );

          await db.batch((batch) {
            batch.insertAll(db.messages, [
              for (final id in agedIds)
                MessagesCompanion.insert(
                  id: id,
                  conversationId: 'conv-1',
                  senderDeviceId: 'device-1',
                  sequenceNumber: 1,
                  ciphertext: Uint8List.fromList(
                    List<int>.filled(10, 0x41),
                  ),
                  createdAt: 0,
                  deliveryState: DeliveryState.stored.name,
                ),
            ]);
          });

          // The exact shape `RetentionExecutor.deleteMessageItems` used
          // BEFORE E08-B03's chunking fix: one `isIn(...)` call over the
          // WHOLE id list, no chunking.
          Future<void> unchunkedDelete(List<String> ids) =>
              (db.delete(db.messages)..where((t) => t.id.isIn(ids))).go();

          await expectLater(
            unchunkedDelete(agedIds),
            throwsA(
              predicate(
                (Object e) =>
                    e.toString().contains('too many SQL variables') ||
                    e.toString().toLowerCase().contains('sqliteexception'),
                'an SqliteException about too many SQL variables',
              ),
            ),
            reason:
                'proves that WITHOUT E08-B03\'s chunking fix, a delete over '
                'a group this size (exactly what E08-B07\'s fix now hands '
                'RetentionExecutor) would have thrown -- this fix is only '
                'safe because E08-B03 merged first',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
  );
}
