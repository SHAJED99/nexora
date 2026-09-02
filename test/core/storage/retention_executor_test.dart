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
class _ThrowingDeleteExecutor extends RetentionExecutor {
  _ThrowingDeleteExecutor({required super.db, required super.log});

  @override
  Future<void> deleteMessageItems(List<String> ids) {
    throw Exception('simulated delete failure');
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
      await _seedMessage(db, id: 'm-1', state: DeliveryState.stored, bytes: 40);
      final throwingExecutor =
          _ThrowingDeleteExecutor(db: db, log: log);
      final plan = _plan(
        mode: 'olderThanDays',
        groups: [
          _group(kind: StorageItemKind.message, itemIds: ['m-1'], bytes: 40),
        ],
      );

      await expectLater(
        () => throwingExecutor.apply(
          plan,
          allowedKinds: {StorageItemKind.message},
          nowEpochMs: 5000,
        ),
        throwsException,
      );

      // The decision row must already be durable even though the delete
      // itself failed (task §2/§6 risk note) -- falsifiable: removing the
      // log-before-delete ordering in `RetentionExecutor.apply` (moving the
      // delete loop before the `log.recordPass` calls) makes this fail.
      final rows = await db.select(db.storageDecisions).get();
      expect(rows, isNotEmpty);
      expect(rows.any((r) => r.outcome == DecisionOutcome.applied.name), isTrue);

      // What was NOT deleted: the message row must still exist, since the
      // delete itself never actually completed.
      final stillThere =
          await (db.select(db.messages)..where((t) => t.id.equals('m-1')))
              .getSingleOrNull();
      expect(stillThere, isNotNull);
    });

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
  });
}
