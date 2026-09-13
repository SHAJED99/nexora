// features/messaging/domain — outgoing message queue (E05-T02).
//
// The one place a message goes from user intent to a Queued-then-Sent/Failed
// row (task file §1/§3): compose -> reserve a sequence number + persist
// `Queued` -> serialize the shared wire envelope (`message_envelope.dart`,
// E05-B01) -> encrypt it (E03's `CryptoService`) -> hand off to E04's
// `RelayEngine` -> `Sent`/`Failed`.
//
// FIXED BY E05-B01: this file used to encrypt the caller's raw `plaintext`
// directly, never building a `MessageEnvelope` at all -- so nothing this use
// case sent could ever be deserialized by `ReceiveMessageUseCase` on the
// other end (see E05-B01.md for the full defect/repro). It now builds and
// serializes a `MessageEnvelope` (id, conversationId, sequenceNumber,
// payload) and encrypts THAT.
//
// Ordering constraint this fix had to solve (E05-B01 §Proposed fix
// direction): the envelope must carry the sequence number, but the sequence
// number used to be assigned *inside* a transaction *after* encryption. The
// fix reorders this to: reserve the sequence number (read `MAX` + insert a
// `Queued` placeholder row) inside a transaction FIRST, then build the
// envelope and encrypt it OUTSIDE any transaction, then update that same
// row's `ciphertext` column with the real bytes. This keeps the
// transactional critical section exactly what it always was -- a DB-only
// read + insert, with no crypto call ever held open inside it -- so the
// L-backend-003 / task §6 concurrency guarantee (independently verified by
// T02's own review via drift source-level analysis and a 60-way concurrent
// stress probe) is unchanged: two concurrent `call()`s still cannot both
// observe the same `MAX(sequence_number)` before either inserts, because
// that read+insert is still the only thing happening inside the transaction.
//
// One consequence of reserving before encrypting: if encryption then fails
// (no E03 session yet), the sequence number has already been consumed and a
// row already inserted -- unlike before this fix, a row now exists for a
// message that could never be encrypted. It is never left at `Queued`,
// though: this file transitions it to `Failed` before rethrowing, so every
// code path still ends in a definite state (task file §6) and the earlier
// no-session test (`test_no_session_surfaces_app_failure_not_crash`, which
// only asserts no row is left `Queued`, not that no row exists) still holds.
//
// A SECOND, undisclosed-until-now consequence of the same reorder (E05-B01
// review round 2, F2): there is now a genuine crash window between phase 1's
// commit (sequence number reserved, `Queued` row inserted with placeholder
// `ciphertext: Uint8List(0)`) and phase 3's `UPDATE` that writes the real
// ciphertext. If the process is killed in that window -- after phase 1
// commits, before phase 3 runs -- a `Queued` row with EMPTY ciphertext
// persists durably, and NOTHING in today's schema distinguishes it from a
// normal, healthy `Queued` row (both are `Queued` with no other marker).
// This was not possible pre-E05-B01: no row existed at all until encryption
// had already succeeded. This is not fixed here -- there is no caller wiring
// this use case to a real transport yet (task file §4), so nothing reads or
// retries `Queued` rows today -- but it is a real gap for whoever builds a
// retry/outbox scanner (E06, most likely per T02/T03's own §4 scope fences):
// that scanner must treat a `Queued` row with empty/short `ciphertext` as
// "encryption never completed, re-run from the envelope" rather than as a
// row merely awaiting relay delivery. See E05-T02.md §6 Risks.
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
// `Sent` or `Failed` *row state*, never a message left stuck at `Queued`
// with no resolution (task file §6). `Sent` here means only "durably
// accepted into this device's local relay queue" (task file §2, corrected
// by E05-B03) — `RelayEngine.enqueue()` is a bare, local INSERT that does
// not consult a route, open a connection, or touch a radio, so reaching
// `Sent` is NOT a delivery guarantee, NOT proof a route exists, and NOT
// proof any byte left this device. It says nothing about what happens
// after enqueue (that is `RelayEngine.processQueue()`'s job, not observed
// here).
import 'package:drift/drift.dart';

import '../../../core/auth/google_auth_service.dart' show AppFailure;
import '../../../core/persistence/database.dart';
import 'delivery_state_machine.dart';
import 'message.dart';
import 'message_envelope.dart';
import 'message_sequence_reserver.dart';

/// The seam this use case needs from E03's `CryptoService.encrypt`
/// (`SignalProtocolAddress`, `Uint8List` -> `Future<CiphertextMessage>`),
/// narrowed to plain device-id strings and serialized bytes so this file
/// doesn't need to depend on `libsignal_protocol_dart` types directly.
/// Production wiring: `(recipientDeviceId, envelopeBytes) async =>
/// (await CryptoService.instance.encrypt(SignalProtocolAddress(recipientDeviceId, 1),
/// envelopeBytes)).serialize()`. The second parameter is the *serialized
/// `MessageEnvelope`* (E05-B01), not the caller's raw `plaintext` -- see the
/// file header for why. Throws whatever `CryptoService.encrypt` itself
/// throws — in particular a [StateError] when no session exists yet for
/// `recipientDeviceId` (E03-T03's own documented contract), which this
/// use case maps to a clear [AppFailure] (task file §3 step 2).
typedef MessageEncryptFn = Future<Uint8List> Function(
  String recipientDeviceId,
  Uint8List envelopeBytes,
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

  /// The one sequence-number reservation transaction, shared with
  /// `SendGroupMessageUseCase` (OQ-E07-T06-1). See
  /// `message_sequence_reserver.dart`.
  late final MessageSequenceReserver _reserver = MessageSequenceReserver(
    db: _db,
    selfDeviceId: _selfDeviceId,
  );

  int _idCounter = 0;

  /// The one call site described by the task's §5 contract. Returns the
  /// persisted [Message] row, its `deliveryState` reflecting the final
  /// outcome (`sent` or `failed`) — never left at `queued` (task file §6).
  ///
  /// Throws `AppFailure('messaging.no_session')` if no E03 session exists
  /// yet with [recipientDeviceId] — surfaced clearly, not a crash. As of
  /// E05-B01, a row IS persisted in this case (the sequence number is
  /// reserved before encryption is attempted, see the file header) but is
  /// transitioned straight to `Failed`, never left at `Queued`.
  Future<Message> call(
    String conversationId,
    String recipientDeviceId,
    Uint8List plaintext,
  ) async {
    final id = _generateId();
    final now = _clock();

    // Phase 1 (E05-B01): reserve the sequence number + persist a `Queued`
    // placeholder row, atomically, BEFORE any crypto call -- this is the
    // ordering fix. The envelope encrypted in phase 2 must carry this
    // sequence number, so the number has to be known first; but the
    // transactional critical section that guards it must stay exactly what
    // it was (L-backend-003 / task §6's risk note: a naive read-then-write
    // outside a transaction lets two concurrent sends in the same
    // conversation read the same MAX() and both assign the same
    // sequence_number) -- a DB-only read + insert, with no external call
    // (crypto/relay) ever made while this transaction is open.
    //
    // T01's review flagged that `messages` has no DB-level UNIQUE
    // constraint on `(conversation_id, sender_device_id, sequence_number)`
    // (adding one is a schema migration, a 🧍 human gate, out of scope for
    // both T01 and this task) -- this transaction is the sole guard against
    // the race, per that note's own guidance to rely on transaction
    // discipline alone unless proven insufficient.
    // OQ-E07-T06-1: this transaction's body now lives in
    // `message_sequence_reserver.dart` — ONE implementation, called from here
    // (1:1) and from `SendGroupMessageUseCase.send` (groups). It was inlined
    // here until E07-T06 needed the same reservation from the group send path
    // and found no way to call it; the behaviour, ordering and transactional
    // critical section are byte-for-byte what they were, only the location
    // changed. See that file's header for why a second copy is never allowed.
    final sequenceNumber = await _reserver.reserve(
      conversationId: conversationId,
      messageId: id,
      createdAtMs: now.millisecondsSinceEpoch,
    );

    var message = Message(
      id: id,
      conversationId: conversationId,
      senderDeviceId: _selfDeviceId,
      sequenceNumber: sequenceNumber,
      ciphertext: Uint8List(0),
      createdAt: now.millisecondsSinceEpoch,
      deliveryState: DeliveryState.queued,
      plaintextPayload: plaintext,
    );

    // E04-B18 (review round 1, nit 2): persist the caller's own plaintext
    // right away, BEFORE phase 2's encrypt call can throw -- this device
    // already knows it (typed into the composer, never
    // encrypted-then-received), so there is no reason it should only
    // survive a successful encrypt. Without this, a `no_session` failure
    // below left a `Failed` row with `plaintextPayload: NULL`, the one
    // remaining case where this device could not redisplay its own
    // composed text. A separate, small write outside the reservation
    // transaction (`message_sequence_reserver.dart`'s own single
    // responsibility is sequence numbers, shared with group sends --
    // deliberately not widened here for a 1:1-only concern).
    await (_db.update(_db.messages)..where((t) => t.id.equals(id)))
        .write(MessagesCompanion(plaintextPayload: Value(plaintext)));

    // Phase 2 (E05-B01): build + serialize the envelope now that the
    // sequence number is known, then encrypt it -- deliberately OUTSIDE any
    // transaction, same as before this fix, so the crypto call never holds
    // the DB lock open.
    final envelope = MessageEnvelope(
      id: id,
      conversationId: conversationId,
      sequenceNumber: sequenceNumber,
      payload: plaintext,
    );

    final Uint8List ciphertext;
    try {
      ciphertext = await _encrypt(recipientDeviceId, envelope.serialize());
    } on StateError catch (e) {
      // The shape `CryptoService.encrypt` throws when no session exists yet
      // (E03-T03's own documented contract). The sequence number is already
      // reserved and a placeholder row already persisted (phase 1 above) --
      // unlike before E05-B01, that reservation can't be undone without
      // reintroducing the race this ordering was chosen to avoid, so the
      // reserved row is transitioned to Failed (never left at Queued, task
      // file §6) before surfacing a clear, greppable AppFailure rather than
      // a raw StateError reaching a caller (docs/conventions.md "Error
      // handling"; task file §3 step 2).
      await _applyTransition(message, DeliveryState.failed);
      throw AppFailure('messaging.no_session', cause: e);
    }

    // Phase 3: persist the real ciphertext over the placeholder -- the row
    // stays Queued at this point, now genuinely encrypted and ready to hand
    // off. `plaintextPayload` was already written above, before phase 2 --
    // not repeated here.
    await (_db.update(_db.messages)..where((t) => t.id.equals(id)))
        .write(MessagesCompanion(ciphertext: Value(ciphertext)));
    message = Message(
      id: message.id,
      conversationId: message.conversationId,
      senderDeviceId: message.senderDeviceId,
      sequenceNumber: message.sequenceNumber,
      ciphertext: ciphertext,
      createdAt: message.createdAt,
      deliveryState: message.deliveryState,
      plaintextPayload: plaintext,
    );

    // Hand off to E04's relay engine -- deliberately outside any
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
