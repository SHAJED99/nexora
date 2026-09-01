// Tests for MessageSequenceReserver — the ONE sequence-number reservation
// transaction, extracted from `SendMessageUseCase.call`'s phase 1 to resolve
// OQ-E07-T06-1 (so the group send path calls it instead of duplicating it).
//
// The property under test is L-backend-003's: concurrent reservations for the
// same `(conversationId, senderDeviceId)` never collide. `SendMessageUseCase`'s
// own `test_sequence_numbers_distinct_under_concurrent_sends_same_conversation`
// proves it through the 1:1 use case; these prove it at the shared unit both
// call sites now share, plus the cross-call-site case that only exists because
// of the extraction: a 1:1 conversation id and a group id are the same column,
// so the partitioning has to hold across both.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message_sequence_reserver.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('test_reserve_starts_at_zero_and_inserts_a_queued_placeholder',
      () async {
    final reserver = MessageSequenceReserver(db: db, selfDeviceId: 'self');

    final n = await reserver.reserve(
      conversationId: 'conv-1',
      messageId: 'm-1',
      createdAtMs: 1000,
    );

    expect(n, 0);
    final row = await (db.select(db.messages)
          ..where((t) => t.id.equals('m-1')))
        .getSingle();
    expect(row.conversationId, 'conv-1');
    expect(row.senderDeviceId, 'self');
    expect(row.sequenceNumber, 0);
    expect(row.deliveryState, DeliveryState.queued.name);
    expect(row.ciphertext, isEmpty,
        reason: 'nothing is encrypted while the transaction is open');
    expect(row.createdAt, 1000);
  });

  test('test_reserve_is_monotonic_per_conversation_and_sender', () async {
    final reserver = MessageSequenceReserver(db: db, selfDeviceId: 'self');

    expect(
      await reserver.reserve(
          conversationId: 'c', messageId: 'a', createdAtMs: 1),
      0,
    );
    expect(
      await reserver.reserve(
          conversationId: 'c', messageId: 'b', createdAtMs: 2),
      1,
    );
    expect(
      await reserver.reserve(
          conversationId: 'c', messageId: 'c1', createdAtMs: 3),
      2,
    );

    // A different conversation (and, below, a different sender) partitions
    // independently -- the schema's contract is per PAIR, not per column.
    expect(
      await reserver.reserve(
          conversationId: 'other', messageId: 'd', createdAtMs: 4),
      0,
    );

    final otherSender =
        MessageSequenceReserver(db: db, selfDeviceId: 'someone-else');
    expect(
      await otherSender.reserve(
          conversationId: 'c', messageId: 'e', createdAtMs: 5),
      0,
    );
  });

  test(
      'test_concurrent_reservations_for_one_pair_never_collide',
      () async {
    // L-backend-003 / E05-T02 §6, at the shared unit: a naive read-then-write
    // outside a transaction would let every one of these observe the same
    // MAX() and claim the same number.
    final reserver = MessageSequenceReserver(db: db, selfDeviceId: 'self');

    final results = await Future.wait([
      for (var i = 0; i < 20; i++)
        reserver.reserve(
          conversationId: 'race',
          messageId: 'race-$i',
          createdAtMs: 100 + i,
        ),
    ]);

    expect(results.toSet(), hasLength(20),
        reason: 'every concurrent reservation must get a distinct number');
    expect(results.toSet(), List.generate(20, (i) => i).toSet(),
        reason: 'and the sequence must stay dense and monotonic from 0');

    final rows = await (db.select(db.messages)
          ..where((t) => t.conversationId.equals('race')))
        .get();
    expect(rows.map((r) => r.sequenceNumber).toSet(), hasLength(20));
  });

  test(
      'test_concurrent_reservations_across_two_reserver_instances_never_collide',
      () async {
    // The shape the extraction actually created: `SendMessageUseCase` and
    // `SendGroupMessageUseCase` each hold their OWN `MessageSequenceReserver`
    // instance over the same database. Two instances of ONE implementation is
    // still one guard -- the transaction, not the object, is what serializes.
    // Two independent implementations would not be, which is why there is
    // only one.
    final a = MessageSequenceReserver(db: db, selfDeviceId: 'self');
    final b = MessageSequenceReserver(db: db, selfDeviceId: 'self');

    final results = await Future.wait([
      for (var i = 0; i < 10; i++)
        (i.isEven ? a : b).reserve(
          conversationId: 'shared',
          messageId: 'shared-$i',
          createdAtMs: 200 + i,
        ),
    ]);

    expect(results.toSet(), hasLength(10));
  });
}
