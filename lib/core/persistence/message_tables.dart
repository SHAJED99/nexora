// core/persistence — messages + delivery_states tables (ADR-0001, E05-T01).
//
// `messages`: one row per message (epic.md's Data model, FR-MSG-002/003/004).
// `ciphertext` is opaque, already-encrypted bytes -- E03 owns encryption;
// this layer, like E04's relay engine, moves/stores opaque bytes.
// `delivery_state` stores a DeliveryState enum value's `.name` as text, per
// docs/conventions.md "Enums" -- never an integer index. Indexed on
// `(conversation_id, created_at)` for the keyset-paginated list query
// (`WHERE created_at < :cursor ORDER BY created_at DESC LIMIT :n`,
// docs/conventions.md "Pagination / large lists").
//
// `plaintext_payload` (E04-B18, additive nullable column, schema v23): the
// message's already-decrypted `MessageEnvelope.payload` bytes, written once
// -- at receive time (`ReceiveMessageUseCase`) or send time
// (`SendMessageUseCase`, which already has it from the user's own compose
// input) -- and never re-derived by decrypting `ciphertext` a second time.
// Root cause this column fixes: Signal Double Ratchet decrypt is a one-time,
// stateful operation (it advances the receiving chain and does not retain
// the message key for reuse); before this column existed, the chat screen
// had no way to redisplay a message's text except calling
// `CryptoService.decrypt` a SECOND time on the same stored `ciphertext` --
// which the crypto layer's own `CryptoDecryptFailureReason.duplicateMessage`
// exists specifically to detect and reject (`crypto_stub.dart`). See
// `E04-B18.md` for the full root-cause writeup and the security reasoning
// below.
//
// SECURITY NOTE (human-approved 2026-09-13, `E04-B18.md` §3): this
// supersedes the earlier stated intent that this table hold only opaque
// ciphertext. Storing a message's plaintext locally, at rest, alongside the
// device's own Signal Protocol private key material (`signal_identity`,
// `signal_sessions` -- neither of which is separately encrypted either) does
// not cross a new trust boundary: anyone who can already read this database
// can already decrypt every message, past and future, from the private keys
// alone. `plaintext_payload` only removes a redundant, protocol-unsafe
// SECOND decrypt step -- it does not expose plaintext to any reader that
// could not already reconstruct it. This does NOT change the separate,
// still-standing restriction that a background dispatcher (e.g. building a
// notification preview) must never read plaintext (`notification_tables.dart`
// / `E06-T09.md`) -- nothing outside the chat screen reads this column.
//
// `delivery_states`: one row per transition, so "when did this become
// Delivered" is queryable separately from the message's current state (this
// task's §3, epic.md's Data model). PK `(message_id, state)` -- a state is
// recorded once per message in the normal case (this task's §5); revisit if
// retries prove that wrong, not built speculatively here.
import 'package:drift/drift.dart';

@DataClassName('MessageRow')
@TableIndex(
  name: 'idx_messages_conversation_created_at',
  columns: {#conversationId, #createdAt},
)
class Messages extends Table {
  /// Client-generated, globally unique -- FR-MSG-003/EARS-MSG-2. Never
  /// server-assigned (this app has no server, ADR-0005).
  TextColumn get id => text()();

  TextColumn get conversationId => text()();

  TextColumn get senderDeviceId => text()();

  /// Monotonic per `(conversationId, senderDeviceId)`, assigned at compose
  /// time -- offline, no live transport required (FR-MSG-004/EARS-MSG-3,
  /// this task's §6 risk note). Assignment algorithm itself is T02's job;
  /// this column only needs to be a plain INTEGER a client can set locally.
  IntColumn get sequenceNumber => integer()();

  /// Opaque, already-encrypted bytes. Never decrypted or inspected by
  /// anything in this table's own file (this task's §4).
  BlobColumn get ciphertext => blob()();

  /// E04-B18: this message's already-decrypted `MessageEnvelope.payload`
  /// bytes -- see this file's header for the full root-cause and security
  /// reasoning. `null` for any row written before this column existed
  /// (never backfilled -- those messages' Double Ratchet keys are already
  /// consumed and cannot be recovered) and for any row a future writer
  /// deliberately chooses not to populate.
  BlobColumn get plaintextPayload => blob().nullable()();

  /// Epoch-ms wall-clock creation time -- keyset pagination cursor, never
  /// used for logical ordering (that's [sequenceNumber]'s job -- clock
  /// drift across devices makes wall-clock time unfit for that).
  IntColumn get createdAt => integer()();

  /// A `DeliveryState.name` string (Queued/Sent/Accepted/Delivered/Stored/
  /// Read/Failed, F-032) -- never written directly; always via
  /// `DeliveryStateMachine.transition`.
  TextColumn get deliveryState => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DeliveryStateRow')
class DeliveryStates extends Table {
  TextColumn get messageId => text()();

  /// A `DeliveryState.name` string, same convention as `messages
  /// .deliveryState`.
  TextColumn get state => text()();

  IntColumn get changedAt => integer()();

  @override
  Set<Column> get primaryKey => {messageId, state};
}
