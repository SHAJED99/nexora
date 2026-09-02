// test/core/storage — E08-B02 regression test.
//
// `StorageManager.runPass`'s Smart Mode branch called `inventory.itemsOfKind`
// with no `limit`/paging, so past 500 items per kind it silently scored only
// the newest 500 -- exactly backwards for the `olderThan` factor, which
// looks for the OLDEST items. The reviewer's own bug-sweep repro: 2000
// dormant, genuinely-aged messages produce a plan reporting only 500
// candidates / 50 000 bytes against a true 2000 / 200 000 (a 4x
// under-report).
//
// This test seeds more than the default limit's worth of genuinely-aged
// items and asserts the plan's candidate count and totalBytes match the
// real SQL ground truth -- not the truncated-window figure. It fails on the
// pre-fix code with the documented `500` / `50000` signature, and passes
// after the fix (StorageManager pages fully through each kind before
// handing items to SmartModePolicy, per E08-B02.md's own Fix direction).
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart' show SmartModeThresholds;
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';

Uint8List _bytes(int length) => Uint8List.fromList(List<int>.filled(length, 0x41));

Future<void> _seedMessage(
  AppDatabase db, {
  required String id,
  required int bytes,
  required int createdAt,
}) {
  return db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: 'conv-1',
          senderDeviceId: 'device-1',
          sequenceNumber: 1,
          ciphertext: _bytes(bytes),
          createdAt: createdAt,
          deliveryState: 'stored',
        ),
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

  test(
    'test_E08_B02_smart_mode_plan_matches_sql_ground_truth_past_500_items',
    () async {
      const dayMs = 24 * 60 * 60 * 1000;
      const nowEpochMs = 200000000000;
      const itemCount = 2000;
      const bytesPerItem = 100;

      // All 2000 messages are dormant (their conversation's last activity
      // is 90 days old, well outside the 14-day active-conversation
      // shield) and genuinely older than the 45-day age threshold -- distinct
      // `createdAt` values so a bounded, newest-first read would pick a
      // deterministic (and wrong) subset.
      final baseCreatedAt = nowEpochMs - (90 * dayMs);
      for (var i = 0; i < itemCount; i++) {
        await _seedMessage(
          db,
          id: 'm-${i.toString().padLeft(5, '0')}',
          bytes: bytesPerItem,
          createdAt: baseCreatedAt + i * 1000,
        );
      }

      final log = StorageDecisionLog(db: db);
      final manager = StorageManager(
        settings: StorageSettingsRepository(db: db),
        inventory: StorageInventory(db: db, databaseFileBytes: () async => 0),
        smart: SmartModePolicy(thresholds: SmartModeThresholds.defaults()),
        executor: RetentionExecutor(db: db, log: log),
        log: log,
      );

      // Smart Mode is the fresh-install default -- no setMode() call needed.
      final plan = await manager.runPass(nowEpochMs: nowEpochMs, apply: false);
      expect(plan, isNotNull);

      // Real SQL ground truth for "genuinely older than the age threshold"
      // -- computed independently of anything StorageManager/SmartModePolicy
      // do internally, so this is a true oracle, not a restatement of the
      // production code under test.
      const ageThresholdDays = 45; // SmartModeThresholds.defaults()
      final cutoffEpochMs = nowEpochMs - (ageThresholdDays * dayMs);
      final groundTruth = await db
          .customSelect(
            'SELECT COUNT(*) AS item_count, '
            'COALESCE(SUM(LENGTH(ciphertext)), 0) AS total_bytes '
            'FROM messages WHERE created_at < ?',
            variables: [Variable.withInt(cutoffEpochMs)],
            readsFrom: {db.messages},
          )
          .getSingle();
      final trueCandidateCount = groundTruth.read<int>('item_count');
      final trueTotalBytes = groundTruth.read<int>('total_bytes');

      expect(trueCandidateCount, itemCount, reason: 'sanity: every seeded item is aged');
      expect(trueTotalBytes, itemCount * bytesPerItem);

      // The plan's own reported totals must match the SQL ground truth --
      // not the truncated-window figure (500 / 50 000) the pre-fix code
      // reports.
      expect(
        plan!.totalBytes,
        trueTotalBytes,
        reason:
            'pre-fix code under-reports as 500 * $bytesPerItem = 50000 -- '
            'only the newest 500 of $itemCount aged items were scored',
      );
      final candidateCount =
          plan.groups.fold<int>(0, (sum, g) => sum + g.itemCount);
      expect(
        candidateCount,
        trueCandidateCount,
        reason: 'pre-fix code under-reports as 500, not the true $itemCount',
      );
    },
  );
}
