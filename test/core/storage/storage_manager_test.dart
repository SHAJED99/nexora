// test/core/storage — E08-T06, StorageManager (the composed facade).
//
// Builds every dependency from a real in-memory `AppDatabase` -- mirrors
// `storage_settings_repository_test.dart`/`storage_inventory_test.dart`'s
// own style. This file does not re-test `SmartModePolicy`/`ManualPolicy`'s
// own scoring logic (T04/T05 already do that exhaustively) -- only that
// `StorageManager` wires settings -> policy -> plan -> log -> (optional)
// apply correctly, and that the throttle is real and restart-safe.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart' show StorageItemKind;
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';

/// Records every `storage_item_stats` `SELECT` this test's `AppDatabase`
/// runs, and how many rows each one returned (E08-B03) -- lets a test assert
/// `_accessStats` reads a bounded, item-scoped slice of the table rather than
/// materializing it whole, without needing to make the private method
/// itself visible across a library boundary.
class _CountingInterceptor extends QueryInterceptor {
  final List<int> storageItemStatsRowCounts = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (statement.contains('storage_item_stats')) {
      storageItemStatsRowCounts.add(rows.length);
    }
    return rows;
  }
}

Uint8List _bytes(int length) => Uint8List.fromList(List<int>.filled(length, 0x41));

Future<void> _seedMessage(
  AppDatabase db, {
  required String id,
  int bytes = 100,
  int createdAt = 1000,
  DeliveryState state = DeliveryState.stored,
}) {
  return db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: 'conv-1',
          senderDeviceId: 'device-1',
          sequenceNumber: 1,
          ciphertext: _bytes(bytes),
          createdAt: createdAt,
          deliveryState: state.name,
        ),
      );
}

StorageManager _buildManager(
  AppDatabase db, {
  Duration storagePassInterval = const Duration(hours: 6),
}) {
  final log = StorageDecisionLog(db: db);
  return StorageManager(
    settings: StorageSettingsRepository(db: db),
    inventory: StorageInventory(db: db, databaseFileBytes: () async => 0),
    smart: SmartModePolicy(thresholds: SmartModeThresholds.defaults()),
    executor: RetentionExecutor(db: db, log: log),
    log: log,
    storagePassInterval: storagePassInterval,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('StorageManager.runPass — mode selection, logging, throttle', () {
    test(
      'test_storage_manager_smart_mode_plans_but_never_deletes_a_message',
      () async {
        // Smart Mode is the fresh-install default (E08-T01) -- no
        // setMode() call needed.
        await _seedMessage(db, id: 'm-1', createdAt: 0); // very old
        final manager = _buildManager(db);

        final plan = await manager.runPass(nowEpochMs: 200000000000);

        expect(plan, isNotNull);
        expect(plan!.mode, StorageMode.smart.name);
        expect(manager.latestPlan.value, same(plan));

        // Whatever Smart Mode's scorer selected, nothing was ever deleted --
        // OQ-E08-3(a)'s allow-list is always empty for Smart Mode.
        final remaining = await db.select(db.messages).get();
        expect(remaining, hasLength(1));
      },
    );

    test(
      'test_storage_manager_manual_mode_applies_its_own_explicit_rule',
      () async {
        final settings = StorageSettingsRepository(db: db);
        await settings.setMode(StorageMode.olderThanDays, olderThanDays: 1);

        final oldEnoughMs =
            200000000000 - const Duration(days: 2).inMilliseconds;
        await _seedMessage(db, id: 'm-old', createdAt: oldEnoughMs);
        await _seedMessage(db, id: 'm-new', createdAt: 200000000000);

        final manager = _buildManager(db);
        final plan = await manager.runPass(nowEpochMs: 200000000000);

        expect(plan, isNotNull);
        expect(plan!.mode, StorageMode.olderThanDays.name);

        final remaining = await db.select(db.messages).get();
        final remainingIds = remaining.map((r) => r.id).toSet();
        expect(remainingIds, {'m-new'});
      },
    );

    test('test_storage_manager_apply_false_plans_without_deleting', () async {
      final settings = StorageSettingsRepository(db: db);
      await settings.setMode(StorageMode.olderThanDays, olderThanDays: 1);
      final oldEnoughMs =
          200000000000 - const Duration(days: 2).inMilliseconds;
      await _seedMessage(db, id: 'm-old', createdAt: oldEnoughMs);

      final manager = _buildManager(db);
      final plan = await manager.runPass(nowEpochMs: 200000000000, apply: false);

      expect(plan, isNotNull);
      expect(plan!.groups, isNotEmpty);

      final remaining = await db.select(db.messages).get();
      expect(remaining, hasLength(1), reason: 'apply: false must never delete');

      final rows = await db.select(db.storageDecisions).get();
      expect(rows.any((r) => r.outcome == DecisionOutcome.planned.name), isTrue);
    });

    test(
      'test_storage_manager_pass_is_throttled_and_survives_restart',
      () async {
        final manager = _buildManager(
          db,
          storagePassInterval: const Duration(hours: 6),
        );

        final firstPlan = await manager.runPass(nowEpochMs: 1000000000000);
        expect(firstPlan, isNotNull);

        // Same manager instance, well within the throttle window.
        final secondPlan = await manager.runPass(
          nowEpochMs: 1000000000000 + 1000,
        );
        expect(secondPlan, isNull, reason: 'throttled -- too soon since the last pass');

        // A brand-new StorageManager instance (simulating a process
        // restart -- no in-memory state survives) over the SAME db must
        // still honor the throttle, because it reads
        // `storage_decisions.decided_at`, not an in-memory field (task §6
        // risk note).
        final restarted = _buildManager(
          db,
          storagePassInterval: const Duration(hours: 6),
        );
        final thirdPlan = await restarted.runPass(
          nowEpochMs: 1000000000000 + 2000,
        );
        expect(thirdPlan, isNull, reason: 'throttle must survive a restart');

        // Well past the interval -- a new pass runs.
        final fourthPlan = await restarted.runPass(
          nowEpochMs: 1000000000000 +
              const Duration(hours: 7).inMilliseconds,
        );
        expect(fourthPlan, isNotNull);
      },
    );

    test(
      'test_storage_manager_zero_candidate_pass_still_advances_the_throttle',
      () async {
        // No messages, no relay packets, no candidates at all -- the pass
        // must still write enough to `storage_decisions` to move
        // `decided_at` forward, or the throttle would never engage (task §6
        // risk note).
        final manager = _buildManager(db);

        final firstPlan = await manager.runPass(nowEpochMs: 1000000000000);
        expect(firstPlan, isNotNull);
        expect(firstPlan!.groups, isEmpty);

        final secondPlan = await manager.runPass(
          nowEpochMs: 1000000000000 + 1000,
        );
        expect(secondPlan, isNull, reason: 'a zero-candidate pass must still throttle');
      },
    );

    test(
      'test_E08_B03_access_stats_query_is_bounded_not_a_full_table_scan',
      () async {
        // E08-B03 defect #2: `_accessStats()` used to run
        // `SELECT * FROM storage_item_stats` unconditionally -- live on
        // every Smart Mode pass regardless of any delete having happened,
        // and directly contradicting `storage_inventory.dart`'s own stated
        // discipline ("a history large enough to be worth managing is a
        // history too large to materialize"). This intercepts every SQL
        // `SELECT` this pass runs against `storage_item_stats` and asserts
        // the total rows read back is bounded by the handful of REAL items
        // Smart Mode is actually scoring, never by the size of the table.
        final interceptor = _CountingInterceptor();
        final boundedDb = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(interceptor),
        );
        addTearDown(boundedDb.close);

        // The only 3 items this pass will ever enumerate (`_allItemsOfKind`
        // pages fully through real `messages` rows) -- each with its own
        // real stats row, exactly as `StorageAccessRecorder` writes.
        const realIds = ['m-1', 'm-2', 'm-3'];
        for (final id in realIds) {
          await _seedMessage(boundedDb, id: id, createdAt: 0);
          await boundedDb.into(boundedDb.storageItemStats).insert(
                StorageItemStatsCompanion.insert(
                  itemKind: StorageItemKind.message.name,
                  itemId: id,
                  lastAccessedAt: const Value(500),
                  accessCount: const Value(1),
                ),
              );
        }

        // A large number of stale rows for ids that will NEVER be
        // enumerated again -- the exact shape `storage_item_stats` grows
        // into over time (E08-B03's own defect #1, before its fix). The
        // bounded query must never read these just to score the 3 real
        // items above.
        for (var i = 0; i < 500; i++) {
          await boundedDb.into(boundedDb.storageItemStats).insert(
                StorageItemStatsCompanion.insert(
                  itemKind: StorageItemKind.message.name,
                  itemId: 'stale-$i',
                  lastAccessedAt: const Value(500),
                  accessCount: const Value(1),
                ),
              );
        }

        final manager = _buildManager(boundedDb);
        final plan =
            await manager.runPass(nowEpochMs: 200000000000, apply: false);

        expect(plan, isNotNull);
        expect(
          interceptor.storageItemStatsRowCounts,
          isNotEmpty,
          reason: 'the pass must read storage_item_stats at least once',
        );
        final totalRowsRead = interceptor.storageItemStatsRowCounts
            .fold<int>(0, (sum, n) => sum + n);
        expect(
          totalRowsRead,
          lessThanOrEqualTo(realIds.length),
          reason: 'bounded to the items the plan is actually scoring -- '
              'must never read the 500 stale/orphan rows (E08-B03). A '
              'full-table `SELECT * FROM storage_item_stats` (the pre-fix '
              'code) would read all ${realIds.length + 500} rows here.',
        );
      },
    );

    test(
      'test_E08_B03_F1_access_stats_chunks_past_the_sqlite_variable_limit',
      () async {
        // Round-1 review F1: `_accessStats`'s `t.itemId.isIn(ids)` used to
        // bind one SQL variable per id in a SINGLE query over the WHOLE
        // per-kind id set -- and `_allItemsOfKind` (E08-B01/B02) deliberately
        // pages through a WHOLE kind with no upper bound, so a device with
        // enough stored history legitimately exceeds SQLite's own
        // `SQLITE_MAX_VARIABLE_NUMBER` (32766 in this build). The unchunked
        // code threw `SqliteException(1): too many SQL variables` BEFORE
        // `log.recordPass` ever ran -- so `storage_decisions` never
        // advanced, the 6-hour throttle never moved, and (since
        // `MessagingCoordinator` only counts the failure rather than
        // crashing) every subsequent pass would repeat the same failure
        // silently, forever, for exactly the "heavy user" this bug exists
        // to help. 33,000 (> 32766) is the reviewer's own probe threshold.
        final chunkedDb = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(chunkedDb.close);

        const n = 33000;
        final ids = List<String>.generate(
          n,
          (i) => 'm-${i.toString().padLeft(6, '0')}',
        );

        await chunkedDb.batch((batch) {
          batch.insertAll(chunkedDb.messages, [
            for (final id in ids)
              MessagesCompanion.insert(
                id: id,
                conversationId: 'conv-1',
                senderDeviceId: 'device-1',
                sequenceNumber: 1,
                ciphertext: _bytes(10),
                createdAt: 0,
                deliveryState: DeliveryState.stored.name,
              ),
          ]);
          batch.insertAll(chunkedDb.storageItemStats, [
            for (final id in ids)
              StorageItemStatsCompanion.insert(
                itemKind: StorageItemKind.message.name,
                itemId: id,
                lastAccessedAt: const Value(500),
                accessCount: const Value(1),
              ),
          ]);
        });

        final manager = _buildManager(chunkedDb);

        // Must complete without throwing -- the load-bearing assertion.
        // `Future.value` immediately below is unreachable if `runPass`
        // throws; `expect`'s own control flow makes the throw itself the
        // failure, so no explicit try/catch is needed for this to fail
        // loudly and for the right reason.
        final plan = await manager.runPass(
          nowEpochMs: 200000000000,
          apply: false,
        );

        expect(plan, isNotNull);
        final rows = await chunkedDb.select(chunkedDb.storageDecisions).get();
        expect(
          rows.any((r) => r.outcome == DecisionOutcome.planned.name),
          isTrue,
          reason: 'the pass must reach log.recordPass -- proof it never '
              'threw before getting there',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
