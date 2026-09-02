// features/messaging/domain — ConversationSummary (E06-T09, widened E07-T07).
//
// The Conversations screen's and Dashboard's read-model row: one entry per
// conversation with at least one message, carrying the last message's
// *metadata* only (E06-T09 §2/§3). Ciphertext is opaque at this layer
// (E05-T01 §4); decryption for display happens in the screen layer with the
// stack's `CryptoService`. Putting a preview string here is how plaintext
// ends up in a read model a future background job might also call
// (E06-T09 §6 risk note) — this class deliberately carries NO `previewText`
// field, and none should ever be added to it.
//
// E07-T07 widens this class to cover both conversation kinds E06-T09
// documented `conversationId` as opaque specifically to allow (E06-T09 §2):
// a group has no single peer and no single relationship state, so
// [peerDeviceId]/[relationshipState] become nullable rather than faked, and
// [kind]/[groupName]/[memberCount] carry what a group row needs instead.
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/domain/relationship.dart' as trust;

/// Which of the two conversation shapes this schema supports a row is.
/// Persisted nowhere — this is a read-model-only distinction computed by
/// [ConversationRepository]'s widened union query, never stored as a column
/// (docs/conventions.md "Enums" governs persisted enums; this one isn't).
enum ConversationKind { personal, group }

/// One row in the conversation list read model — a personal (1:1) or a
/// group conversation, distinguished by [kind].
class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.kind,
    this.peerDeviceId,
    this.relationshipState,
    this.groupName,
    this.memberCount,
    required this.lastMessageId,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    required this.lastMessageSenderDeviceId,
    required this.lastMessageState,
    required this.unreadCount,
  });

  /// Opaque to callers, per E06-T09 §2 — for a 1:1 conversation this is
  /// always == [peerDeviceId] (the only conversation shape E06 supported);
  /// for a group (E07-T01 §2) this is the group's `groups.id`, a locally
  /// minted, `g:`-prefixed id living in the same widened id space.
  final String conversationId;

  /// Which conversation shape this row is. Personal-only fields
  /// ([peerDeviceId], [relationshipState]) are null for a group row;
  /// group-only fields ([groupName], [memberCount]) are null for a personal
  /// row — a group has no single peer or relationship state, and a 1:1
  /// conversation has no group name or member count, and faking either
  /// would be a lie the screen would then render.
  final ConversationKind kind;

  /// The remote device this conversation is with. Null for [kind] ==
  /// [ConversationKind.group].
  final String? peerDeviceId;

  /// This side's evaluated trust state for [peerDeviceId], or `null` when
  /// no relationship has ever been recorded for it (no row in
  /// `relationships` — distinct from an explicit
  /// [trust.RelationshipState.unknown] evaluation), or when [kind] ==
  /// [ConversationKind.group] (a group has no single relationship state).
  final trust.RelationshipState? relationshipState;

  /// `groups.name` for a group row. Null for [kind] ==
  /// [ConversationKind.personal].
  final String? groupName;

  /// Current (non-removed) member count for a group row. Null for [kind] ==
  /// [ConversationKind.personal].
  final int? memberCount;

  final String lastMessageId;

  /// Epoch-ms wall-clock time of the last message — the ordering key for
  /// the list (`ORDER BY lastMessageAt DESC`) and the keyset pagination
  /// cursor for the thread itself.
  final int lastMessageAt;

  /// True when the last message's sender is this device.
  final bool lastMessageIsMine;

  /// The device id of the last message's sender — already implied by
  /// [lastMessageIsMine] for the 1:1 case, made explicit so the screen can
  /// render a group row's `<name>:` preview prefix without a second query
  /// (E07-T07 §3).
  final String lastMessageSenderDeviceId;

  final DeliveryState lastMessageState;

  /// Messages from the peer (personal) or from other members (group) whose
  /// `delivery_state` is not `read`. 0 for a conversation with no incoming
  /// messages.
  final int unreadCount;

  @override
  bool operator ==(Object other) =>
      other is ConversationSummary &&
      other.conversationId == conversationId &&
      other.kind == kind &&
      other.peerDeviceId == peerDeviceId &&
      other.relationshipState == relationshipState &&
      other.groupName == groupName &&
      other.memberCount == memberCount &&
      other.lastMessageId == lastMessageId &&
      other.lastMessageAt == lastMessageAt &&
      other.lastMessageIsMine == lastMessageIsMine &&
      other.lastMessageSenderDeviceId == lastMessageSenderDeviceId &&
      other.lastMessageState == lastMessageState &&
      other.unreadCount == unreadCount;

  @override
  int get hashCode => Object.hash(
        conversationId,
        kind,
        peerDeviceId,
        relationshipState,
        groupName,
        memberCount,
        lastMessageId,
        lastMessageAt,
        lastMessageIsMine,
        lastMessageSenderDeviceId,
        lastMessageState,
        unreadCount,
      );

  @override
  String toString() =>
      'ConversationSummary(conversationId: $conversationId, kind: $kind, '
      'peerDeviceId: $peerDeviceId, relationshipState: $relationshipState, '
      'groupName: $groupName, memberCount: $memberCount, '
      'lastMessageId: $lastMessageId, lastMessageAt: $lastMessageAt, '
      'lastMessageIsMine: $lastMessageIsMine, '
      'lastMessageSenderDeviceId: $lastMessageSenderDeviceId, '
      'lastMessageState: $lastMessageState, unreadCount: $unreadCount)';
}
