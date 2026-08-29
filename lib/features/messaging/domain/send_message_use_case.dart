// features/messaging/domain — outgoing message queue (E05-T02).
//
// The one place a message goes from user intent to a Queued-then-Sent/Failed
// row (task file §1/§3): compose -> encrypt (E03's `CryptoService`) ->
// persist `Queued` (T01's `messages` table + `DeliveryStateMachine`) ->
// hand off to E04's `RelayEngine` -> `Sent`/`Failed`.
//
// This task does NOT reimplement E03's crypto or E04's relay/transport — it
// only calls them. It is wired to those real APIs through two small,
// function-typed seams ([MessageEncryptFn], [MessageEnqueueFn]) rather than
// depending on the concrete `CryptoService`/`RelayEngine` classes directly:
// production wiring (a later epic — no caller exists yet, task file §4)
// binds these to the real `CryptoService.instance.encrypt(...)` (wrapped to
// go from a device-id string to a `SignalProtocolAddress` and to
// `.serialize()` the returned `CiphertextMessage`) and to a `RelayEngine`
// instance's `enqueue` method directly — its signature already matches
// [MessageEnqueueFn] exactly, so no adapter is needed on that side. This
// task's own tests exercise the sequencing/state-machine/error-surfacing
// logic that belongs to *this* file, not E03/E04's internals, which already
// have their own test suites (this task's required_context: E03-T03,
// E04-T04).
//
// Does NOT call `establishSession` itself (task file §3/§4) — a `StateError`
// from [MessageEncryptFn] (the shape `CryptoService.encrypt` throws per
// E03-T03's own contract when no session exists) is surfaced as a clear
// `AppFailure('messaging.no_session')`, never a crash, and never silently
// worked around (see OQ-E05-T02-1).
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor: the fields are private (`_db`, `_selfDeviceId`, ...) while the
// constructor's public named parameters (`db`, `selfDeviceId`, ...) match
// this class's documented call shape (§5) — an initializing formal would
// rename those parameters to the private field names, breaking every call
// site. Matches the same pattern (and rationale) already established in
// `lib/core/routing_engine/relay_engine.dart` (E04-T04).
// ignore_for_file: prefer_initializing_formals
//
// Does NOT implement ack/retry/incoming handling/UI (task file §4) — a
// `Failed` transition here is terminal; every code path ends in a definite
// `Sent` or `Failed` state, never a message left stuck at `Queued` with no
// resolution (task file §6).
import 'package:drift/drift.dart';

import '../../../core/auth/google_auth_service.dart' show AppFailure;
import '../../../core/persistence/database.dart';
import 'delivery_state_machine.dart';
import 'message.dart';

/// The seam this use case needs from E03's `CryptoService.encrypt`
/// (`SignalProtocolAddress`, `Uint8List` -> `Future<CiphertextMessage>`),
/// narrowed to plain device-id strings and serialized bytes so this file
/// doesn't need to depend on `libsignal_protocol_dart` types directly.
/// Production wiring: `(recipientDeviceId, plaintext) async =>
/// (await CryptoService.instance.encrypt(SignalProtocolAddress(recipientDeviceId, 1),
/// plaintext)).serialize()`. Throws whatever `CryptoService.encrypt` itself
/// throws — in particular a [StateError] when no session exists yet for
/// `recipientDeviceId` (E03-T03's own documented contract), which this
/// use case maps to a clear [AppFailure] (task file §3 step 2).
typedef MessageEncryptFn = Future<Uint8List> Function(
  String recipientDeviceId,
  Uint8List plaintext,
);

/// The seam this use case needs from E04's `RelayEngine.enqueue` — its
/// signature already matches this exactly
/// (`enqueue(destination, payload, priority, ttl)`, returning the new
/// relay-packet id), so production wiring passes a `RelayEngine` instance's
/// `enqueue` method straight through with no adapter needed.
typedef MessageEnqueueFn = Future<String> Function(
  String destination,
  Uint8List payload,
  int priority,
  Duration ttl,
);

/// Compose -> encrypt -> persist `Queued` -> relay -> `Sent`/`Failed` (task
/// file §1/§3). One instance per device identity — [selfDeviceId] is this
/// device's own id, used as `messages.sender_device_id` and as the
/// per-conversation sequence-number partition key (T01's schema: monotonic
/// per `(conversationId, senderDeviceId)`).
class SendMessageUseCase {
  SendMessageUseCase({
    required AppDatabase db,
    required String selfDeviceId,
    required MessageEncryptFn encrypt,
    required MessageEnqueueFn enqueue,
    int priority = 0,
    Duration ttl = const Duration(days: 3),
    DateTime Function() clock = DateTime.now,
  })  : _db = db,
        _selfDeviceId = selfDeviceId,
        _encrypt = encrypt,
        _enqueue = enqueue,
        _priority = priority,
        _ttl = ttl,
        _clock = clock;

  final AppDatabase _db;
  final String _selfDeviceId;
  final MessageEncryptFn _encrypt;
  final MessageEnqueueFn _enqueue;
  final int _priority;
  final Duration _ttl;
  final DateTime Function() _clock;

  int _idCounter = 0;

  /// The one call site described by the task's §5 contract. Returns the
  /// persisted [Message] row, its `deliveryState` reflecting the final
  /// outcome (`sent` or `failed`) — never left at `queued` (task file §6).
  ///
  /// Throws `AppFailure('messaging.no_session')` if no E03 session exists
  /// yet with [recipientDeviceId] — surfaced clearly, not a crash, and no
  /// row is persisted for a message that could never be encrypted in the
  /// first place.
  Future<Message> call(
    String conversationId,
    String recipientDeviceId,
    Uint8List plaintext,
  ) async {
    final Uint8List ciphertext;
    try {
      ciphertext = await _encrypt(recipientDeviceId, plaintext);
    } on StateError catch (e) {
      // The shape `CryptoService.encrypt` throws when no session exists yet
      // (E03-T03's own documented contract) -- surfaced as a clear,
      // greppable AppFailure rather than a raw StateError reaching a caller
      // (docs/conventions.md "Error handling"; task file §3 step 2).
      throw AppFailure('messaging.no_session', cause: e);
    }

    final id = _generateId();
    final now = _clock();

    // Atomic sequence-number assignment + persist, in one transaction
    // (L-backend-003 / task §6's risk note: a naive read-then-write outside
    // a transaction lets two concurrent sends in the same conversation read
    // the same MAX() and both assign the same sequence_number). The
    // critical section is deliberately just the read + insert -- no
    // external call (crypto/relay) is ever made while this transaction is
    // open, so it stays short and never blocks on the network/relay step.
    //
    // T01's review flagged that `messages` has no DB-level UNIQUE
    // constraint on `(conversation_id, sender_device_id, sequence_number)`
    // (adding one is a schema migration, a 🧍 human gate, out of scope for
    // both T01 and this task) -- this transaction is the sole guard against
    // the race, per that note's own guidance to rely on transaction
    // discipline alone unless proven insufficient.
    final sequenceNumber = await _db.transaction(() async {
      final maxRow = await (_db.selectOnly(_db.messages)
            ..addColumns([_db.messages.sequenceNumber.max()])
            ..where(_db.messages.conversationId.equals(conversationId) &
                _db.messages.senderDeviceId.equals(_selfDeviceId)))
          .getSingleOrNull();
      final currentMax = maxRow?.read(_db.messages.sequenceNumber.max());
      final next = (currentMax ?? -1) + 1;

      await _db.into(_db.messages).insert(
            MessagesCompanion.insert(
              id: id,
              conversationId: conversationId,
              senderDeviceId: _selfDeviceId,
              sequenceNumber: next,
              ciphertext: ciphertext,
              createdAt: now.millisecondsSinceEpoch,
              deliveryState: DeliveryState.queued.name,
            ),
          );
      return next;
    });

    var message = Message(
      id: id,
      conversationId: conversationId,
      senderDeviceId: _selfDeviceId,
      sequenceNumber: sequenceNumber,
      ciphertext: ciphertext,
      createdAt: now.millisecondsSinceEpoch,
      deliveryState: DeliveryState.queued,
    );

    // Hand off to E04's relay engine -- deliberately outside the above
    // transaction so the Queued row is durably committed and independently
    // observable before this (potentially slow) step even starts (task
    // file §2: composition must be synchronous-feeling and always succeed
    // locally, regardless of connectivity).
    try {
      await _enqueue(recipientDeviceId, ciphertext, _priority, _ttl);
      message = await _applyTransition(message, DeliveryState.sent);
    } catch (_) {
      // Every code path through this use case must end in a definite state
      // -- a relay-enqueue failure never leaves the row stuck at Queued
      // with no resolution (task file §6).
      message = await _applyTransition(message, DeliveryState.failed);
    }

    return message;
  }

  Future<Message> _applyTransition(Message message, DeliveryState to) async {
    final updated = message.withDeliveryState(to);
    await (_db.update(_db.messages)..where((t) => t.id.equals(message.id)))
        .write(MessagesCompanion(deliveryState: Value(to.name)));
    return updated;
  }

  /// Timestamp + an in-process counter -- unique per instance without a new
  /// dependency (no `uuid` package is declared in `pubspec.yaml`; adding one
  /// would be a 🧍 `new_dependency` gate this task does not need to clear
  /// for an internal-only identifier). Matches the pattern already
  /// established by E04-T04's `RelayEngine._generateId`.
  String _generateId() =>
      '${_clock().microsecondsSinceEpoch}-${_idCounter++}';
}
