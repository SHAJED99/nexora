// features/messaging/domain — the ONE sequence-number reservation
// transaction (extracted for OQ-E07-T06-1).
//
// `messages.sequence_number` is monotonic per `(conversation_id,
// sender_device_id)` (E05-T01's schema contract). There is no DB-level UNIQUE
// constraint backing that invariant — adding one is a schema migration and a
// 🧍 human gate, deliberately out of scope since E05-T01 — so the ONLY thing
// guarding it is that the read of `MAX(sequence_number)` and the insert that
// consumes the next value happen inside a single transaction, with no
// external call (crypto, relay, transport) ever made while it is open. That
// is L-backend-003's whole subject: a naive read-then-write outside a
// transaction lets two concurrent sends in the same conversation observe the
// same MAX() and both write the same number.
//
// An invariant guarded by "everybody remembers to write the same transaction"
// has as many guards as it has copies, which is to say none. Before this
// file, that transaction was inlined in `SendMessageUseCase.call`'s phase 1
// over its own private fields, so `SendGroupMessageUseCase` (E07-T06) could
// not call it — it left the reservation as an unbound injected seam and
// raised `OQ-E07-T06-1` rather than copy the body, exactly as its task file
// instructed. This class is that question's answer: ONE implementation, TWO
// call sites (`SendMessageUseCase.call` for 1:1, `SendGroupMessageUseCase.send`
// for groups, where `conversationId` is the group id — E07-T01 §2). Nothing
// else in this repo may open its own reservation transaction; anything that
// needs a sequence number calls this.
//
// The same discipline `message_envelope.dart` already carries for the wire
// format (one definition shared by the sending and receiving halves, after
// E05-B01 proved what two divergent implementations cost).
//
// `prefer_initializing_formals` is intentionally not applied, matching
// `send_message_use_case.dart`/`relay_engine.dart`'s own documented
// exclusion: the fields are private while the constructor's named parameters
// are the public call shape.
// ignore_for_file: prefer_initializing_formals
import 'package:drift/drift.dart';

import '../../../core/persistence/database.dart';
import 'delivery_state_machine.dart';

/// Reserves the next `messages.sequence_number` for a given conversation and
/// this device, and durably inserts the `Queued` placeholder row that
/// consumes it — atomically, in one transaction.
///
/// One instance per device identity: [selfDeviceId] is the
/// `sender_device_id` half of the partition key.
class MessageSequenceReserver {
  MessageSequenceReserver({
    required AppDatabase db,
    required String selfDeviceId,
  })  : _db = db,
        _selfDeviceId = selfDeviceId;

  final AppDatabase _db;
  final String _selfDeviceId;

  /// Reserve and return the next sequence number for
  /// `(conversationId, selfDeviceId)`, inserting a `Queued` row for
  /// [messageId] that consumes it.
  ///
  /// The row's `ciphertext` is an empty placeholder: the caller has not
  /// encrypted anything yet, and must not, while this transaction is open
  /// (see this file's header). The caller overwrites it once encryption
  /// succeeds, or transitions the row to `Failed` if it does not — a row is
  /// never left at `Queued` with no resolution (E05-T02 §6).
  Future<int> reserve({
    required String conversationId,
    required String messageId,
    required int createdAtMs,
  }) {
    return _db.transaction(() async {
      final maxRow = await (_db.selectOnly(_db.messages)
            ..addColumns([_db.messages.sequenceNumber.max()])
            ..where(_db.messages.conversationId.equals(conversationId) &
                _db.messages.senderDeviceId.equals(_selfDeviceId)))
          .getSingleOrNull();
      final currentMax = maxRow?.read(_db.messages.sequenceNumber.max());
      final next = (currentMax ?? -1) + 1;

      await _db.into(_db.messages).insert(
            MessagesCompanion.insert(
              id: messageId,
              conversationId: conversationId,
              senderDeviceId: _selfDeviceId,
              sequenceNumber: next,
              ciphertext: Uint8List(0),
              createdAt: createdAtMs,
              deliveryState: DeliveryState.queued.name,
            ),
          );
      return next;
    });
  }
}
