// core/persistence — messages + delivery_states tables (ADR-0001, E05-T01).
//
// `messages`: one row per message (epic.md's Data model, FR-MSG-002/003/004).
// `ciphertext` is opaque, already-encrypted bytes -- E03 owns encryption;
// this layer, like E04's relay engine, only ever moves/stores opaque bytes
// (this task's §4). `delivery_state` stores a DeliveryState enum value's
// `.name` as text, per docs/conventions.md "Enums" -- never an integer
// index. Indexed on `(conversation_id, created_at)` for the keyset-paginated
// list query (`WHERE created_at < :cursor ORDER BY created_at DESC LIMIT
// :n`, docs/conventions.md "Pagination / large lists").
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
