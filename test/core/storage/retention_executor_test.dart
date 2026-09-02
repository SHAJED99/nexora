// test/core/storage — E08-T06, RetentionExecutor.
//
// Every test seeds a real in-memory `AppDatabase.forTesting(NativeDatabase
// .memory())` and asserts against real rows -- this file's own contract
// (task §6 risk: "a deletion bug here is unrecoverable user data loss") means
// every test that asserts a delete must also assert what was NOT deleted
// (task's own explicit falsification-style review instruction).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_item.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart'
    show StorageMode;
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';

Uint8List _bytes(int length, [int fill = 0x41]) =>
    Uint8List.fromList(List<int>.filled(length, fill));

Future<void> _seedMessage(
  AppDatabase db, {
  required String id,
  required DeliveryState state,
  int bytes = 100,
  String conversationId = 'conv-1',
  int createdAt = 1000,
}) {
  return db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: conversationId,
          senderDeviceId: 'device-1',
          sequenceNumber: 1,
          ciphertext: _bytes(bytes),
          createdAt: createdAt,
          deliveryState: state.name,
        ),
      );
}

Future<void> _seedRelayPacket(AppDatabase db, {required String id}) {
  return db.into(db.relayPackets).insert(
        RelayPacketsCompanion.insert(
          id: id,
          destinationId: 'dest-1',
          payload: Value(_bytes(50, 0x00)),
          priority: 1,
          sizeBytes: 50,
          createdAt: 1000,
          expiresAt: 61000,
          deliveryState: 'queued',
        ),
      );
}

RetentionCandidateGroup _group({
  required StorageItemKind kind,
  required List<String> itemIds,
  String categoryKey = 'messages',
  RetentionReason reason = RetentionReason.olderThan,
  String? reasonDetail = '45',
  int bytes = 100,
}) {
  return RetentionCandidateGroup(
    categoryKey: categoryKey,
    kind: kind,
    itemIds: itemIds,
    itemCount: itemIds.length,
    bytes: bytes * itemIds.length,
    reason: reason,
    reasonDetail: reasonDetail,
  );
}

RetentionPlan _plan({
  required String mode,
  required List<RetentionCandidateGroup> groups,
}) {
  final totalBytes = groups.fold<int>(0, (sum, g) => sum + g.bytes);
  return RetentionPlan(
    mode: mode,
    groups: groups,
    totalBytes: totalBytes,
    availableFactors: const {},
    unavailableFactors: const {},
    computedAt: DateTime.fromMillisecondsSinceEpoch(2000),
  );
}

/// A [RetentionExecutor] whose [deleteMessageItems] always throws -- used to
/// prove the log-before-delete ordering is real (this file's header;
/// `deleteMessageItems`'s own doc comment in `retention_executor.dart`).
/// A [StorageDecisionLog] that fails only when asked to write the
/// `outcome: applied` row -- the OTHER half of `apply()`'s per-group
/// `db.transaction()`. Every existing F1 test breaks the *delete* side; this
/// one breaks the *log* side, which is what actually proves the write is
/// transactional rather than merely ordered delete-then-log (E08 bug sweep,
/// 2026-09-02 -- the E08-T06 round-2 carried-forward observation).
class _AppliedRowFailingLog extends StorageDecisionLog {
  _AppliedRowFailingLog({required super.db});

  @override
  Future<String> recordPass(
    RetentionPlan plan, {
    required DecisionOutcome outcome,
    required int nowEpochMs,
  }) {
    if (outcome == DecisionOutcome.applied) {
      throw Exception('simulated decision-row write failure');
    }
    return super.recordPass(plan, outcome: outcome, nowEpochMs: nowEpochMs);
  }
}

class _ThrowingDeleteExecutor extends RetentionExecutor {
  _ThrowingDeleteExecutor({required super.db, required super.log});

  @override
  Future<void> deleteMessageItems(List<String> ids) {
    throw Exception('simulated delete failure');
  }
}

/// Throws only for a delete call that would touch [failingIds] -- lets a
/// multi-group `apply()` call succeed for some groups and fail for others,
/// proving the per-group atomicity fix (F1: round-1 review) is real.
class _SelectivelyThrowingExecutor extends RetentionExecutor {
  _SelectivelyThrowingExecutor({
    required super.db,
    required super.log,
    required this.failingIds,
  });

  final Set<String> failingIds;

  @override
  Future<void> deleteMessageItems(List<String> ids) async {
    if (ids.any(failingIds.contains)) {
      throw Exception('simulated delete failure for $ids');
    }
    await super.deleteMessageItems(ids);
  }
}

void main() {
  late AppDatabase db;
  late StorageDecisionLog log;
  late RetentionExecutor executor;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    log = StorageDecisionLog(db: db);
    executor = RetentionExecutor(db: db, log: log);
  });

  tearDown(() async {
    await db.close();
  });

  group('EARS-STORE-13 — decisions logged, allow-list enforced', () {
    test('test_EARS_STORE_13_decisions_are_logged_before_deletes', () async {
      // A group whose delete fails must NEVER get a durable `applied`
      // decision row (F1, round-1 review) -- it must get a TRUTHFUL
      // `skipped` row instead, and `apply()` must not abort (it recovers
      // and returns normally rather than propagating the delete failure).
      await _seedMessage(db, id: 'm-1', state: DeliveryState.stored, bytes: 40);
      final throwingExecutor = _ThrowingDeleteExecutor(db: db, log: log);
      final plan = _plan(
        mode: 'olderThanDays',
        groups: [
          _group(kind: StorageItemKind.message, itemIds: ['m-1'], bytes: 40),
        ],
      );

      final outcome = await throwingExecutor.apply(
        plan,
        allowedKinds: {StorageItemKind.message},
        nowEpochMs: 5000,
      );

      expect(outcome.appliedGroups, isEmpty);
      expect(outcome.skippedGroups, hasLength(1));
      expect(outcome.skippedGroups.single.why, contains('delete failed'));

      // A decision row for this group must exist -- but it must be
      // `skipped`, never `applied` (falsifiable: reverting the F1 fix --
      // batch-logging `applied` upfront before any delete runs -- makes
      // this row read `applied` even though nothing was actually deleted).
      final rows = await db.select(db.storageDecisions).get();
      expect(rows, isNotEmpty);
      expect(rows.any((r) => r.outcome == DecisionOutcome.applied.name), isFalse,
          reason: 'a failed delete must never leave a false applied row');
      expect(rows.any((r) => r.outcome == DecisionOutcome.skipped.name), isTrue);

      // What was NOT deleted: the message row must still exist, since the
      // delete itself never actually completed.
      final stillThere =
          await (db.select(db.messages)..where((t) => t.id.equals('m-1')))
              .getSingleOrNull();
      expect(stillThere, isNotNull);
    });

    test(
      'test_EARS_STORE_13_a_mid_pass_delete_failure_never_falsely_marks_a_'
      'sibling_group_applied',
      () async {
        // F1 regression (round-1 review): two candidate groups; the SECOND
        // group's delete throws. The first group must still be genuinely
        // applied (deleted + logged applied); the second must be skipped
        // with a truthful reason, NEVER logged applied.
        await _seedMessage(db, id: 'm-1', state: DeliveryState.stored, bytes: 40);
        await _seedMessage(db, id: 'm-2', state: DeliveryState.stored, bytes: 40);
        final selectivelyThrowingExecutor = _SelectivelyThrowingExecutor(
          db: db,
          log: log,
          failingIds: {'m-2'},
        );
        final plan = _plan(
          mode: 'olderThanDays',
          groups: [
            _group(
              kind: StorageItemKind.message,
              itemIds: ['m-1'],
              categoryKey: 'messages',
              bytes: 40,
            ),
            _group(
              kind: StorageItemKind.message,
              itemIds: ['m-2'],
              categoryKey: 'messages',
              reason: RetentionReason.rarelyAccessed,
              reasonDetail: '30',
              bytes: 40,
            ),
          ],
        );

        final outcome = await selectivelyThrowingExecutor.apply(
          plan,
          allowedKinds: {StorageItemKind.message},
          nowEpochMs: 5000,
        );

        expect(outcome.appliedGroups, hasLength(1));
        expect(outcome.appliedGroups.single.itemIds, ['m-1']);
        expect(outcome.skippedGroups, hasLength(1));
        expect(outcome.skippedGroups.single.group.itemIds, ['m-2']);

        // m-1 genuinely deleted; m-2 genuinely still there.
        final remaining = await db.select(db.messages).get();
        expect(remaining.map((r) => r.id).toSet(), {'m-2'});

        // The log must never claim m-2 was applied -- only m-1.
        final rows = await db.select(db.storageDecisions).get();
        final appliedRows =
            rows.where((r) => r.outcome == DecisionOutcome.applied.name);
        expect(appliedRows, hasLength(1));
        final skippedRows =
            rows.where((r) => r.outcome == DecisionOutcome.skipped.name);
        expect(skippedRows, isNotEmpty);
      },
    );

    test(
      'test_EARS_STORE_13_group_outside_allow_list_is_skipped_with_reason',
      () async {
        await _seedMessage(db, id: 'm-1', state: DeliveryState.stored);
        final plan = _plan(
          mode: 'olderThanDays',
          groups: [
            _group(kind: StorageItemKind.message, itemIds: ['m-1']),
          ],
        );

        final outcome = await executor.apply(
          plan,
          allowedKinds: const <StorageItemKind>{}, // message not authorised
          nowEpochMs: 5000,
        );

        expect(outcome.appliedGroups, isEmpty);
        expect(outcome.skippedGroups, hasLength(1));
        expect(outcome.skippedGroups.single.group.itemIds, ['m-1']);
        expect(
          outcome.skippedGroups.single.why,
          contains('not authorised'),
        );

        final stillThere =
            await (db.select(db.messages)..where((t) => t.id.equals('m-1')))
                .getSingleOrNull();
        expect(stillThere, isNotNull, reason: 'never deleted -- outside allow-list');

        final rows = await db.select(db.storageDecisions).get();
        expect(
          rows.any(
            (r) =>
                r.categoryKey == 'messages' &&
                r.outcome == DecisionOutcome.skipped.name &&
                r.reasonCode == RetentionReason.olderThan.name,
          ),
          isTrue,
          reason: 'the group\'s own reason must be preserved, never dropped',
        );
      },
    );

    test('test_EARS_STORE_13_empty_allow_list_deletes_nothing', () async {
      await _seedMessage(db, id: 'm-1', state: DeliveryState.stored);
      await _seedMessage(db, id: 'm-2', state: DeliveryState.read);
      await _seedRelayPacket(db, id: 'r-1');

      final plan = _plan(
        mode: 'smart',
        groups: [
          _group(
            kind: StorageItemKind.message,
            itemIds: ['m-1', 'm-2'],
            reason: RetentionReason.rarelyAccessed,
            reasonDetail: '30',
          ),
          _group(
            kind: StorageItemKind.relayPayload,
            itemIds: ['r-1'],
            categoryKey: 'relayCache',
            reason: RetentionReason.noLongerRequired,
            reasonDetail: null,
          ),
        ],
      );

      // Smart Mode's own allow-list is always empty (OQ-E08-T06-1).
      final outcome = await executor.apply(
        plan,
        allowedKinds: const <StorageItemKind>{},
        nowEpochMs: 5000,
      );

      expect(outcome.appliedGroups, isEmpty);
      expect(outcome.bytesReclaimed, 0);

      final messages = await db.select(db.messages).get();
      expect(messages, hasLength(2), reason: 'nothing deleted under an empty allow-list');
      final packets = await db.select(db.relayPackets).get();
      expect(packets, hasLength(1));
      expect(packets.single.payload, isNotNull);
    });

    test(
      'test_EARS_STORE_13_smart_mode_never_deletes_message_kind_items',
      () async {
        await _seedMessage(db, id: 'm-1', state: DeliveryState.stored);
        final plan = _plan(
          mode: 'smart',
          groups: [
            _group(kind: StorageItemKind.message, itemIds: ['m-1']),
          ],
        );

        // Even a caller that (incorrectly, or after a future change widens
        // Smart Mode's allow-list for some OTHER kind) passes `message` in
        // allowedKinds must still see it skipped for a plan whose own
        // `mode` is Smart Mode -- OQ-E08-T06-1's own wording: "regardless
        // of what allow-list a caller might otherwise pass".
        final outcome = await executor.apply(
          plan,
          allowedKinds: const <StorageItemKind>{StorageItemKind.message},
          nowEpochMs: 5000,
        );

        expect(outcome.appliedGroups, isEmpty);
        expect(outcome.skippedGroups, hasLength(1));
        final stillThere =
            await (db.select(db.messages)..where((t) => t.id.equals('m-1')))
                .getSingleOrNull();
        expect(stillThere, isNotNull);
      },
    );

    test(
      'test_EARS_STORE_13_manual_mode_may_delete_message_kind_items',
      () async {
        await _seedMessage(db, id: 'm-1', state: DeliveryState.stored);
        // The identical candidate shape as the Smart Mode test above --
        // only `plan.mode` differs -- proving the mode-dependent split is
        // real, not just documented (task's own explicit instruction).
        final plan = _plan(
          mode: StorageMode.olderThanDays.name,
          groups: [
            _group(kind: StorageItemKind.message, itemIds: ['m-1']),
          ],
        );

        final outcome = await executor.apply(
          plan,
          allowedKinds: const <StorageItemKind>{StorageItemKind.message},
          nowEpochMs: 5000,
        );

        expect(outcome.appliedGroups, hasLength(1));
        expect(outcome.appliedGroups.single.itemIds, ['m-1']);
        expect(outcome.skippedGroups, isEmpty);

        final stillThere =
            await (db.select(db.messages)..where((t) => t.id.equals('m-1')))
                .getSingleOrNull();
        expect(stillThere, isNull, reason: 'Manual Mode authorised this delete');
      },
    );

    test(
      'test_EARS_STORE_13_empty_plan_sentinel_is_never_logged_applied',
      () async {
        // F2 regression (round-1 review): a genuinely empty plan (nothing
        // to report at all -- the common Smart Mode shape, since Smart
        // Mode never has anything in candidatesToApply on this build) must
        // still advance the throttle clock with a sentinel row, but that
        // sentinel must NEVER read `outcome: applied` -- nothing was ever
        // applied.
        final plan = _plan(mode: 'smart', groups: const []);

        final outcome = await executor.apply(
          plan,
          allowedKinds: const <StorageItemKind>{},
          nowEpochMs: 5000,
        );

        expect(outcome.appliedGroups, isEmpty);
        expect(outcome.bytesReclaimed, 0);

        final rows = await db.select(db.storageDecisions).get();
        expect(rows, isNotEmpty, reason: 'the throttle clock must still advance');
        expect(
          rows.any((r) => r.outcome == DecisionOutcome.applied.name),
          isFalse,
          reason: 'a pass that deleted nothing must never claim applied',
        );
      },
    );
  });

  group('EARS-STORE-14 — delivery-state guard + relay ownership', () {
    test('test_EARS_STORE_14_undelivered_message_is_never_deleted', () async {
      await _seedMessage(db, id: 'm-queued', state: DeliveryState.queued);
      await _seedMessage(db, id: 'm-sent', state: DeliveryState.sent);
      await _seedMessage(db, id: 'm-failed', state: DeliveryState.failed);
      await _seedMessage(db, id: 'm-stored', state: DeliveryState.stored);

      final plan = _plan(
        mode: StorageMode.olderThanDays.name,
        groups: [
          _group(
            kind: StorageItemKind.message,
            itemIds: ['m-queued', 'm-sent', 'm-failed', 'm-stored'],
          ),
        ],
      );

      // Manual Mode explicitly authorises `message` -- but the delivery-
      // state guard is independent of that authorisation (task §2/§6).
      final outcome = await executor.apply(
        plan,
        allowedKinds: const <StorageItemKind>{StorageItemKind.message},
        nowEpochMs: 5000,
      );

      expect(outcome.appliedGroups, hasLength(1));
      expect(outcome.appliedGroups.single.itemIds, ['m-stored']);

      expect(outcome.skippedGroups, hasLength(1));
      expect(
        outcome.skippedGroups.single.group.itemIds,
        ['m-failed', 'm-queued', 'm-sent'],
      );
      expect(
        outcome.skippedGroups.single.why,
        contains('terminal delivered state'),
      );

      final remaining = await db.select(db.messages).get();
      final remainingIds = remaining.map((r) => r.id).toSet();
      expect(remainingIds, {'m-queued', 'm-sent', 'm-failed'});
      expect(remainingIds.contains('m-stored'), isFalse);
    });

    test('test_EARS_STORE_14_relay_payloads_are_never_touched', () async {
      await _seedRelayPacket(db, id: 'r-1');
      final plan = _plan(
        mode: StorageMode.overSizeMb.name,
        groups: [
          _group(
            kind: StorageItemKind.relayPayload,
            itemIds: ['r-1'],
            categoryKey: 'relayCache',
            reason: RetentionReason.overSizeLimit,
            reasonDetail: '5242880',
          ),
        ],
      );

      // Even though this hypothetical caller authorises relayPayload
      // explicitly, this executor must still never touch it (invariant 1,
      // this file's own header) -- E04-B02/E06-T06 own that TTL exclusively.
      final outcome = await executor.apply(
        plan,
        allowedKinds: const <StorageItemKind>{StorageItemKind.relayPayload},
        nowEpochMs: 5000,
      );

      expect(outcome.appliedGroups, isEmpty);
      expect(outcome.skippedGroups, hasLength(1));
      expect(
        outcome.skippedGroups.single.why,
        contains('RelayEngine.reclaimPayloads'),
      );

      final packets = await db.select(db.relayPackets).get();
      expect(packets, hasLength(1));
      expect(packets.single.payload, isNotNull);
    });

    test(
      'test_E08_B03_delete_removes_delivery_states_and_storage_item_stats_'
      'orphans',
      () async {
        // E08-B03 repro, reproduced literally: 3 messages, each with the
        // bookkeeping rows the real app writes for a stored message
        // (`MessagingCoordinator.recordStored` -> one `delivery_states` row;
        // `StorageAccessRecorder` -> one `storage_item_stats` row). Before
        // this fix, `deleteMessageItems` only ever deleted from `messages`,
        // leaving `delivery_states: 3, storage_item_stats: 3` behind forever
        // (this file's own repro signature, task file's Actual section).
        const ids = ['m-00000', 'm-00001', 'm-00002'];
        for (final id in ids) {
          await _seedMessage(db, id: id, state: DeliveryState.stored, bytes: 40);
          await db.into(db.deliveryStates).insert(
                DeliveryStatesCompanion.insert(
                  messageId: id,
                  state: DeliveryState.stored.name,
                  changedAt: 1000,
                ),
              );
          await db.into(db.storageItemStats).insert(
                StorageItemStatsCompanion.insert(
                  itemKind: StorageItemKind.message.name,
                  itemId: id,
                  lastAccessedAt: const Value(1000),
                  accessCount: const Value(1),
                ),
              );
        }

        // Preconditions -- the repro's literal signature, so a passing
        // assertion below cannot be vacuous.
        expect(await db.select(db.messages).get(), hasLength(3));
        expect(await db.select(db.deliveryStates).get(), hasLength(3));
        expect(await db.select(db.storageItemStats).get(), hasLength(3));

        final plan = _plan(
          mode: StorageMode.olderThanDays.name,
          groups: [
            _group(kind: StorageItemKind.message, itemIds: ids, bytes: 40),
          ],
        );

        final outcome = await executor.apply(
          plan,
          allowedKinds: const <StorageItemKind>{StorageItemKind.message},
          nowEpochMs: 5000,
        );

        expect(outcome.appliedGroups, hasLength(1));
        expect(outcome.appliedGroups.single.itemIds, ids);

        expect(await db.select(db.messages).get(), isEmpty);
        expect(
          await db.select(db.deliveryStates).get(),
          isEmpty,
          reason: 'orphaned delivery_states rows must be cleaned up '
              '(E08-B03)',
        );
        expect(
          await db.select(db.storageItemStats).get(),
          isEmpty,
          reason: 'orphaned storage_item_stats rows must be cleaned up '
              '(E08-B03)',
        );
      },
    );

    test(
      'test_E08_B03_bookkeeping_cleanup_never_touches_a_different_message\'s_'
      'rows',
      () async {
        // Deletes only 'm-1'; 'm-2' (undelivered, never a candidate) must
        // keep every one of its own bookkeeping rows -- proving the cleanup
        // is scoped to the deleted ids, never the whole table.
        await _seedMessage(db, id: 'm-1', state: DeliveryState.stored, bytes: 40);
        await _seedMessage(db, id: 'm-2', state: DeliveryState.queued, bytes: 40);
        for (final id in ['m-1', 'm-2']) {
          await db.into(db.deliveryStates).insert(
                DeliveryStatesCompanion.insert(
                  messageId: id,
                  state: DeliveryState.stored.name,
                  changedAt: 1000,
                ),
              );
          await db.into(db.storageItemStats).insert(
                StorageItemStatsCompanion.insert(
                  itemKind: StorageItemKind.message.name,
                  itemId: id,
                  lastAccessedAt: const Value(1000),
                  accessCount: const Value(1),
                ),
              );
        }

        final plan = _plan(
          mode: StorageMode.olderThanDays.name,
          groups: [
            _group(kind: StorageItemKind.message, itemIds: ['m-1', 'm-2'], bytes: 40),
          ],
        );

        final outcome = await executor.apply(
          plan,
          allowedKinds: const <StorageItemKind>{StorageItemKind.message},
          nowEpochMs: 5000,
        );

        expect(outcome.appliedGroups.single.itemIds, ['m-1']);

        final remainingStates = await db.select(db.deliveryStates).get();
        expect(remainingStates.map((r) => r.messageId).toSet(), {'m-2'});
        final remainingStats = await db.select(db.storageItemStats).get();
        expect(remainingStats.map((r) => r.itemId).toSet(), {'m-2'});
      },
    );

    test(
      'test_E08_B03_bookkeeping_cleanup_is_atomic_with_the_message_delete',
      () async {
        // Falsifies the atomicity claim: force the group's own `applied`
        // decision row write to fail (the same fault injection F1's own
        // test above uses) and confirm the message row AND both bookkeeping
        // rows survive together -- proving the cleanup runs INSIDE the same
        // `apply()` per-group `db.transaction()`, not as a separate,
        // non-atomic step that could half-apply.
        await _seedMessage(db, id: 'm-1', state: DeliveryState.stored, bytes: 40);
        await db.into(db.deliveryStates).insert(
              DeliveryStatesCompanion.insert(
                messageId: 'm-1',
                state: DeliveryState.stored.name,
                changedAt: 1000,
              ),
            );
        await db.into(db.storageItemStats).insert(
              StorageItemStatsCompanion.insert(
                itemKind: StorageItemKind.message.name,
                itemId: 'm-1',
                lastAccessedAt: const Value(1000),
                accessCount: const Value(1),
              ),
            );

        final failingLog = _AppliedRowFailingLog(db: db);
        final executorOverFailingLog =
            RetentionExecutor(db: db, log: failingLog);
        final plan = _plan(
          mode: StorageMode.olderThanDays.name,
          groups: [
            _group(kind: StorageItemKind.message, itemIds: ['m-1'], bytes: 40),
          ],
        );

        final outcome = await executorOverFailingLog.apply(
          plan,
          allowedKinds: const <StorageItemKind>{StorageItemKind.message},
          nowEpochMs: 5000,
        );

        expect(outcome.appliedGroups, isEmpty);

        expect(
          await db.select(db.messages).get(),
          hasLength(1),
          reason: 'the delete rolled back -- its bookkeeping cleanup must '
              'have rolled back with it, in the same transaction',
        );
        expect(await db.select(db.deliveryStates).get(), hasLength(1));
        expect(await db.select(db.storageItemStats).get(), hasLength(1));
      },
    );

    test(
      'test_EARS_STORE_13_a_delete_whose_decision_row_fails_to_write_is_'
      'rolled_back',
      () async {
        // The half of the F1 fix no existing test covers (E08-T06 round-2
        // carried-forward, added by the E08 bug sweep). The other F1 tests
        // break the DELETE and assert the `applied` row never appears; this
        // one breaks the `applied` ROW WRITE and asserts the delete never
        // becomes durable. Only a real `db.transaction()` wrapper can make
        // both true at once -- delete-then-log without a transaction passes
        // every other test in this file and fails this one.
        //
        // Falsified (E08 sweep Run log): removing `apply()`'s
        // `db.transaction(() async { ... })` wrapper -- keeping the same
        // delete-then-log order and the same try/catch -- leaves all 11
        // pre-existing executor tests green and fails exactly this test's
        // `expect(survivor, isNotNull)`, for the right reason (the message
        // row is gone).
        await _seedMessage(db, id: 'm-1', state: DeliveryState.stored, bytes: 40);
        final failingLog = _AppliedRowFailingLog(db: db);
        final executorOverFailingLog =
            RetentionExecutor(db: db, log: failingLog);
        final plan = _plan(
          mode: StorageMode.olderThanDays.name,
          groups: [
            _group(kind: StorageItemKind.message, itemIds: ['m-1'], bytes: 40),
          ],
        );

        // Precondition: the row really is there, and really is a legal
        // deletion candidate -- so a passing assertion below cannot be
        // vacuous.
        expect(
          await (db.select(db.messages)..where((t) => t.id.equals('m-1')))
              .getSingleOrNull(),
          isNotNull,
        );

        final outcome = await executorOverFailingLog.apply(
          plan,
          allowedKinds: const <StorageItemKind>{StorageItemKind.message},
          nowEpochMs: 5000,
        );

        // The pass does not crash, and does not claim the group was applied.
        expect(outcome.appliedGroups, isEmpty);
        expect(outcome.bytesReclaimed, 0);
        expect(outcome.skippedGroups, hasLength(1));

        // The load-bearing assertion: the delete rolled back with its own
        // decision row. `retention_executor.dart`'s header states this
        // exactly -- "a delete whose decision row fails to write never
        // happens either".
        final survivor =
            await (db.select(db.messages)..where((t) => t.id.equals('m-1')))
                .getSingleOrNull();
        expect(
          survivor,
          isNotNull,
          reason: 'the delete must roll back when its own applied decision '
              'row cannot be written -- otherwise storage_decisions has no '
              'record at all of a delete that really happened',
        );

        // And the log is not silent about the group either: a truthful
        // `skipped` row is written outside the rolled-back transaction.
        final rows = await db.select(db.storageDecisions).get();
        expect(
          rows.any((r) => r.outcome == DecisionOutcome.applied.name),
          isFalse,
        );
        expect(
          rows.any((r) => r.outcome == DecisionOutcome.skipped.name),
          isTrue,
        );
      },
    );
  });
}
