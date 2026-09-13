// features/messaging/data — ConversationRepository (E06-T09, widened
// E07-T07).
//
// Pure READ model over the existing `messages` + `relationships` tables
// (lib/core/persistence/message_tables.dart,
// lib/core/persistence/relationships_table.dart), now also `groups` +
// `group_members` (lib/core/persistence/group_tables.dart, E07-T01). NOT a
// write path — no insert, update or delete lives here (E06-T09 §4); T02/T03's
// send/receive pipeline owns personal writes, E07-T06's send/receive pipeline
// owns group writes.
//
// There is no `Conversations` table and this file deliberately does not add
// one — that would be a schema migration, a human gate this task is
// forbidden to trigger (E06-T09 §2). A conversation's identity, for 1:1, is
// fixed as `conversationId == peerDeviceId`: `relationships.deviceId` is the
// only peer key in the schema, which makes the list <-> trust join a plain
// equality. For a group (E07-T01 §2), `conversationId == groups.id`, a
// locally minted, `g:`-prefixed id in the same widened, opaque id space
// E06-T09 documented specifically so this widening would not require
// rewriting the screens.
//
// This file NEVER decrypts anything and NEVER imports `CryptoService`
// (E06-T09 §4/§6) — `messages.ciphertext` is opaque here, exactly as it is
// in `Message` (E05-T01 §4). The preview-text problem stays out of scope on
// purpose: decryption for display belongs in the screen layer. This holds
// for the group case too (E07-T07 §2/§4): the sender-name prefix the design
// draws for a group row is assembled in the screen layer from the member
// list this projection exposes, not decrypted here.
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

  /// How long [watchConversations] waits after the last `messages`/`groups`/
  /// `group_members` write before re-reading the list, so a burst of writes
  /// collapses into one re-read instead of one per write (E06-T09 §6 risk
  /// note; widened to the group tables by E07-T07 §6 without widening the
  /// coalesce window itself).
  static const _defaultCoalesceWindow = Duration(milliseconds: 50);

  /// One row per conversation (personal or group) with at least one message,
  /// ordered by `lastMessageAt` descending, in a single grouped query — the
  /// same `last_msg`/`unread` CTEs from E06-T09 are computed once and
  /// referenced by both halves of a `UNION ALL`, never one query per
  /// conversation and never a second round trip for the group half
  /// (E07-T07 §6 risk note / `test_EARS_COMM_33_list_is_still_a_single_query`,
  /// `test_EARS_COMM_17_list_is_a_single_query`).
  ///
  /// Personal half: joined to `relationships`, blocked *peers* excluded
  /// (FR-BLOCK-001, unchanged from E06-T09), and a conversation id that is
  /// actually a group id is excluded here (it is picked up by the group half
  /// instead — see the `NOT EXISTS` guard in [_listConversationsSql]).
  ///
  /// Group half: joined to `groups`/`group_members`, deleted groups excluded
  /// (`groups.is_deleted`, E07-T01 §2), current member count aggregated, and
  /// a blocked member does **not** exclude the group itself — blocking is
  /// asymmetric by design (E07-T07 §2; the mutual-invisibility question for
  /// messages *inside* a group thread is `OQ-E07-10`, out of this task's
  /// scope).
  ///
  /// Ties on `created_at` (plausible on a fast device) are broken on the
  /// message `id` throughout, so the ordering is deterministic
  /// (`test_EARS_COMM_18_equal_timestamps_have_a_stable_order`'s sibling
  /// case for the list).
  Future<List<ConversationSummary>> listConversations() async {
    final rows = await _db
        .customSelect(
          _listConversationsSql,
          variables: [
            Variable.withString(selfDeviceId),
            Variable.withString(selfDeviceId),
            Variable.withString(selfDeviceId),
          ],
          readsFrom: {
            _db.messages,
            _db.relationships,
            _db.groups,
            _db.groupMembers,
          },
        )
        .get();
    return rows.map(_summaryFromRow).toList();
  }

  /// The same rows as [listConversations], emitted again whenever `messages`,
  /// `groups` or `group_members` changes — so the Conversations screen
  /// updates live instead of polling (EARS-COMM-19, EARS-COMM-34). A group
  /// rename or a membership change moves the list without a new message
  /// arriving. `RelationshipRepository` exposes only one-shot futures today
  /// (this task does not touch that repository, out of fence); this watches
  /// the three tables and re-reads everything on each emission.
  ///
  /// The raw table-write notification is coalesced with [coalesceWindow]
  /// before the actual (expensive) [listConversations] query runs, so a
  /// burst of writes across any of the three watched tables produces one
  /// re-read, not one per write (E06-T09 §6 /
  /// `test_EARS_COMM_19_stream_emits_on_insert` and the burst-of-ten test;
  /// E07-T07 §6 — widening the watched-table set without widening the
  /// coalesce window is what would turn a membership burst into a query
  /// storm).
  Stream<List<ConversationSummary>> watchConversations({
    Duration coalesceWindow = _defaultCoalesceWindow,
  }) {
    // A cheap ping, not the real query -- drift re-runs this on every write
    // to any of the three watched tables, but it is `SELECT 1`, not the
    // grouped query, so a chatty stream never amplifies into repeated full
    // re-reads by itself.
    final ping = _db.customSelect(
      'SELECT 1',
      readsFrom: {_db.messages, _db.groups, _db.groupMembers},
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
  ///
  /// No signature change for E07-T07: [conversationId] is opaque, and a
  /// group id is one (E06-T09 §2 / E07-T01 §2) —
  /// `test_messages_page_works_unchanged_on_a_group_conversation_id` proves
  /// it rather than assuming it.
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
        plaintextPayload: row.plaintextPayload,
      );

  ConversationSummary _summaryFromRow(QueryRow row) {
    final conversationId = row.read<String>('conversation_id');
    final kindName = row.read<String>('kind');
    final relationshipStateName =
        row.readNullable<String>('relationship_state');
    return ConversationSummary(
      conversationId: conversationId,
      kind: ConversationKind.values.byName(kindName),
      // E06-T09 §2 / E07-T01 §2: null for a group row -- a group has no
      // single peer.
      peerDeviceId: row.readNullable<String>('peer_device_id'),
      relationshipState: relationshipStateName == null
          ? null
          : trust.RelationshipState.values.byName(relationshipStateName),
      groupName: row.readNullable<String>('group_name'),
      memberCount: row.readNullable<int>('member_count'),
      lastMessageId: row.read<String>('last_message_id'),
      lastMessageAt: row.read<int>('last_message_at'),
      lastMessageIsMine: row.read<int>('last_message_is_mine') == 1,
      lastMessageSenderDeviceId:
          row.read<String>('last_message_sender_device_id'),
      lastMessageState: DeliveryState.values.byName(
        row.read<String>('last_message_state'),
      ),
      unreadCount: row.read<int>('unread_count'),
    );
  }
}

/// The "last message per conversation" problem (classic
/// greatest-n-per-group) as one grouped query rather than N+1: `last_msg`
/// ranks every message within its conversation newest-first (`created_at
/// DESC, id DESC` — the deterministic tie-break, E06-T09 §6) and keeps only
/// rank 1; `unread` aggregates the peer/other-members' unread count per
/// conversation in the same pass; `member_counts` aggregates each group's
/// current (non-removed) member count. `last_msg`, `unread` and
/// `member_counts` do not care whether `conversation_id` is a peer device id
/// or a group id (E06-T09's `conversationId` is opaque, E07-T01 §2) — they
/// are computed once and referenced by BOTH halves of the `UNION ALL` below,
/// so widening to groups adds a second `SELECT` branch over the same CTEs
/// rather than a second round trip (E07-T07 §6 /
/// `test_EARS_COMM_33_list_is_still_a_single_query`).
///
/// The personal branch joins `relationships` and excludes `blocked` peers
/// (FR-TRUST-003/FR-BLOCK-001, unchanged from E06-T09) and excludes any
/// conversation id that is actually a group id (`NOT EXISTS ... groups`) so
/// a group's messages are never double-counted as a personal row too. The
/// group branch joins `groups`/`group_members`, excludes `is_deleted`
/// groups, and does **not** filter on any member's relationship state — a
/// group containing a blocked peer stays listed (E07-T07 §2, deliberately
/// asymmetric from the personal branch).
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
),
member_counts AS (
  SELECT group_id, COUNT(*) AS member_count
  FROM group_members
  WHERE removed_at_epoch IS NULL
  GROUP BY group_id
)
SELECT
  'personal' AS kind,
  lm.conversation_id AS conversation_id,
  lm.conversation_id AS peer_device_id,
  r.state AS relationship_state,
  NULL AS group_name,
  NULL AS member_count,
  lm.id AS last_message_id,
  lm.created_at AS last_message_at,
  CASE WHEN lm.sender_device_id = ? THEN 1 ELSE 0 END AS last_message_is_mine,
  lm.sender_device_id AS last_message_sender_device_id,
  lm.delivery_state AS last_message_state,
  COALESCE(u.unread_count, 0) AS unread_count
FROM last_msg lm
LEFT JOIN unread u ON u.conversation_id = lm.conversation_id
LEFT JOIN relationships r ON r.device_id = lm.conversation_id
WHERE lm.rn = 1
  AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id = lm.conversation_id)
  AND (r.state IS NULL OR r.state != 'blocked')

UNION ALL

SELECT
  'group' AS kind,
  lm.conversation_id AS conversation_id,
  NULL AS peer_device_id,
  NULL AS relationship_state,
  g.name AS group_name,
  COALESCE(mc.member_count, 0) AS member_count,
  lm.id AS last_message_id,
  lm.created_at AS last_message_at,
  CASE WHEN lm.sender_device_id = ? THEN 1 ELSE 0 END AS last_message_is_mine,
  lm.sender_device_id AS last_message_sender_device_id,
  lm.delivery_state AS last_message_state,
  COALESCE(u.unread_count, 0) AS unread_count
FROM last_msg lm
JOIN groups g ON g.id = lm.conversation_id
LEFT JOIN unread u ON u.conversation_id = lm.conversation_id
LEFT JOIN member_counts mc ON mc.group_id = lm.conversation_id
WHERE lm.rn = 1
  AND g.is_deleted = 0

ORDER BY last_message_at DESC, last_message_id DESC
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
