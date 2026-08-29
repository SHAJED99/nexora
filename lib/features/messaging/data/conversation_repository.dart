// features/messaging/data — ConversationRepository (E06-T09).
//
// Pure READ model over the existing `messages` + `relationships` tables
// (lib/core/persistence/message_tables.dart,
// lib/core/persistence/relationships_table.dart). NOT a write path — no
// insert, update or delete lives here (E06-T09 §4); T02/T03's send/receive
// pipeline owns writes.
//
// There is no `Conversations` table and this file deliberately does not add
// one — that would be a schema migration, a human gate this task is
// forbidden to trigger (E06-T09 §2). A conversation's identity, for the
// only shape this schema supports (1:1), is fixed as `conversationId ==
// peerDeviceId`: `relationships.deviceId` is the only peer key in the
// schema, which makes the list <-> trust join a plain equality.
//
// This file NEVER decrypts anything and NEVER imports `CryptoService`
// (E06-T09 §4/§6) — `messages.ciphertext` is opaque here, exactly as it is
// in `Message` (E05-T01 §4). The preview-text problem stays out of scope on
// purpose: decryption for display belongs in the screen layer.
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/messaging/domain/conversation_summary.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message.dart';
import 'package:nexora/features/trust/domain/relationship.dart' as trust;

class ConversationRepository {
  ConversationRepository(this._db, {required this.selfDeviceId});

  final AppDatabase _db;

  /// This device's own device id — used to decide `lastMessageIsMine` and
  /// to exclude this device's own outgoing messages from [unreadCount].
  final String selfDeviceId;

  /// How long [watchConversations] waits after the last `messages` write
  /// before re-reading the list, so a burst of inserts collapses into one
  /// re-read instead of one per insert (E06-T09 §6 risk note).
  static const _defaultCoalesceWindow = Duration(milliseconds: 50);

  /// One row per `conversation_id` with at least one message, joined to
  /// `relationships`, blocked peers excluded, ordered by `lastMessageAt`
  /// descending. A single grouped query (window function + two aggregating
  /// CTEs) — never one query per conversation (E06-T09 §6 risk note /
  /// `test_EARS_COMM_17_list_is_a_single_query`).
  ///
  /// Ties on `created_at` (plausible on a fast device) are broken on `id`
  /// throughout, so the ordering is deterministic
  /// (`test_EARS_COMM_18_equal_timestamps_have_a_stable_order`'s sibling
  /// case for the list).
  Future<List<ConversationSummary>> listConversations() async {
    final rows = await _db
        .customSelect(
          _listConversationsSql,
          variables: [
            Variable.withString(selfDeviceId),
            Variable.withString(selfDeviceId),
          ],
          readsFrom: {_db.messages, _db.relationships},
        )
        .get();
    return rows.map(_summaryFromRow).toList();
  }

  /// The same rows as [listConversations], emitted again whenever `messages`
  /// changes — so the Conversations screen updates live instead of polling
  /// (EARS-COMM-19). `RelationshipRepository` exposes only one-shot futures
  /// today (this task does not touch that repository, out of fence); this
  /// watches `messages` and re-reads relationships on each emission.
  ///
  /// The raw table-write notification is coalesced with [coalesceWindow]
  /// before the actual (expensive) [listConversations] query runs, so a
  /// burst of writes produces one re-read, not one per write (E06-T09 §6 /
  /// `test_EARS_COMM_19_stream_emits_on_insert` and the burst-of-ten test).
  Stream<List<ConversationSummary>> watchConversations({
    Duration coalesceWindow = _defaultCoalesceWindow,
  }) {
    // A cheap ping, not the real query -- drift re-runs this on every write
    // to `messages`, but it is `SELECT 1`, not the grouped query, so a
    // chatty stream never amplifies into repeated full re-reads by itself.
    final ping = _db.customSelect(
      'SELECT 1',
      readsFrom: {_db.messages},
    ).watch();
    return _coalesce(ping, coalesceWindow)
        .asyncMap((_) => listConversations());
  }

  /// Keyset-paginated, newest-first thread page (docs/conventions.md
  /// "Pagination / large lists", E05-T01 §2) — never offset. [before] is
  /// the `created_at` of the oldest row already held by the caller; `null`
  /// for the first page. Ties on `created_at` are broken on `id` for a
  /// deterministic order
  /// (`test_EARS_COMM_18_equal_timestamps_have_a_stable_order`).
  Future<List<Message>> messagesPage(
    String conversationId, {
    int? before,
    int limit = 50,
  }) async {
    final query = _db.select(_db.messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);
    if (before != null) {
      query.where((t) => t.createdAt.isSmallerThanValue(before));
    }
    final rows = await query.get();
    return rows.map(_messageFromRow).toList();
  }

  /// Live newest page for the open chat view — same ordering/tie-break as
  /// [messagesPage], re-emitted whenever `messages` changes.
  Stream<List<Message>> watchConversation(
    String conversationId, {
    int limit = 50,
  }) {
    final query = _db.select(_db.messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);
    return query.watch().map((rows) => rows.map(_messageFromRow).toList());
  }

  /// Messages from the peer (i.e. not sent by [selfDeviceId]) whose
  /// `delivery_state` is not `read`. 0 for a conversation with no incoming
  /// messages.
  Future<int> unreadCount(String conversationId) async {
    final countExpr = _db.messages.id.count();
    final row = await (_db.selectOnly(_db.messages)
          ..addColumns([countExpr])
          ..where(
            _db.messages.conversationId.equals(conversationId) &
                _db.messages.senderDeviceId.equals(selfDeviceId).not() &
                _db.messages.deliveryState
                    .equals(DeliveryState.read.name)
                    .not(),
          ))
        .getSingle();
    return row.read(countExpr) ?? 0;
  }

  Message _messageFromRow(MessageRow row) => Message(
        id: row.id,
        conversationId: row.conversationId,
        senderDeviceId: row.senderDeviceId,
        sequenceNumber: row.sequenceNumber,
        ciphertext: row.ciphertext,
        createdAt: row.createdAt,
        deliveryState: DeliveryState.values.byName(row.deliveryState),
      );

  ConversationSummary _summaryFromRow(QueryRow row) {
    final conversationId = row.read<String>('conversation_id');
    final relationshipStateName =
        row.readNullable<String>('relationship_state');
    return ConversationSummary(
      conversationId: conversationId,
      // E06-T09 §2: conversationId == peerDeviceId for the only
      // conversation shape this schema supports (1:1).
      peerDeviceId: conversationId,
      relationshipState: relationshipStateName == null
          ? null
          : trust.RelationshipState.values.byName(relationshipStateName),
      lastMessageId: row.read<String>('last_message_id'),
      lastMessageAt: row.read<int>('last_message_at'),
      lastMessageIsMine: row.read<int>('last_message_is_mine') == 1,
      lastMessageState: DeliveryState.values.byName(
        row.read<String>('last_message_state'),
      ),
      unreadCount: row.read<int>('unread_count'),
    );
  }
}

/// The "last message per conversation" problem (classic
/// greatest-n-per-group) as one grouped query rather than N+1:
/// `last_msg` ranks every message within its conversation newest-first
/// (`created_at DESC, id DESC` — the deterministic tie-break, E06-T09 §6)
/// and keeps only rank 1; `unread` aggregates the peer's unread count per
/// conversation in the same pass; the outer `SELECT` joins both to
/// `relationships` and excludes `blocked` peers (FR-TRUST-003/FR-BLOCK-001).
/// A relationship-less conversation (`r.state IS NULL`) is still included —
/// only an explicit `blocked` excludes it.
const _listConversationsSql = '''
WITH last_msg AS (
  SELECT
    m.id AS id,
    m.conversation_id AS conversation_id,
    m.sender_device_id AS sender_device_id,
    m.created_at AS created_at,
    m.delivery_state AS delivery_state,
    ROW_NUMBER() OVER (
      PARTITION BY m.conversation_id
      ORDER BY m.created_at DESC, m.id DESC
    ) AS rn
  FROM messages m
),
unread AS (
  SELECT conversation_id, COUNT(*) AS unread_count
  FROM messages
  WHERE sender_device_id != ? AND delivery_state != 'read'
  GROUP BY conversation_id
)
SELECT
  lm.conversation_id AS conversation_id,
  lm.id AS last_message_id,
  lm.created_at AS last_message_at,
  CASE WHEN lm.sender_device_id = ? THEN 1 ELSE 0 END AS last_message_is_mine,
  lm.delivery_state AS last_message_state,
  COALESCE(u.unread_count, 0) AS unread_count,
  r.state AS relationship_state
FROM last_msg lm
LEFT JOIN unread u ON u.conversation_id = lm.conversation_id
LEFT JOIN relationships r ON r.device_id = lm.conversation_id
WHERE lm.rn = 1
  AND (r.state IS NULL OR r.state != 'blocked')
ORDER BY lm.created_at DESC, lm.id DESC
''';

/// Coalesces bursty [input] emissions into one emission per quiet
/// [window] — the last event in a burst wins, and is delivered [window]
/// after it (or after the burst quiets down), not immediately. No new
/// dependency: this is a small hand-rolled `Timer`-based transform rather
/// than pulling in `rxdart`/`stream_transform` as a direct dependency for
/// one operator.
Stream<T> _coalesce<T>(Stream<T> input, Duration window) {
  late final StreamController<T> controller;
  Timer? timer;
  StreamSubscription<T>? subscription;

  controller = StreamController<T>.broadcast(
    onListen: () {
      subscription = input.listen(
        (event) {
          timer?.cancel();
          timer = Timer(window, () {
            if (!controller.isClosed) controller.add(event);
          });
        },
        onError: controller.addError,
        onDone: () {
          timer?.cancel();
          controller.close();
        },
      );
    },
    onCancel: () {
      timer?.cancel();
      subscription?.cancel();
    },
  );
  return controller.stream;
}
