// test/core/storage — E08-T06, StorageManager (the composed facade).
//
// Builds every dependency from a real in-memory `AppDatabase` -- mirrors
// `storage_settings_repository_test.dart`/`storage_inventory_test.dart`'s
// own style. This file does not re-test `SmartModePolicy`/`ManualPolicy`'s
// own scoring logic (T04/T05 already do that exhaustively) -- only that
// `StorageManager` wires settings -> policy -> plan -> log -> (optional)
// apply correctly, and that the throttle is real and restart-safe.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';

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
  });
}
