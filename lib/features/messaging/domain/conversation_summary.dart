// features/messaging/domain — ConversationSummary (E06-T09).
//
// The Conversations screen's and Dashboard's read-model row: one entry per
// conversation with at least one message, carrying the last message's
// *metadata* only (E06-T09 §2/§3). Ciphertext is opaque at this layer
// (E05-T01 §4); decryption for display is the screen layer's job with the
// stack's `CryptoService`. Putting a preview string here is how plaintext
// ends up in a read model a future background job might also call
// (E06-T09 §6 risk note) — this class deliberately carries NO `previewText`
// field, and none should ever be added to it.
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/domain/relationship.dart' as trust;

/// One row in the conversation list read model.
class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.peerDeviceId,
    required this.relationshipState,
    required this.lastMessageId,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    required this.lastMessageState,
    required this.unreadCount,
  });

  /// Opaque to callers, per E06-T09 §2 — for a 1:1 conversation this is
  /// currently always == [peerDeviceId], the only conversation shape this
  /// schema supports (`messages` has no `Conversations` table). E07 widens
  /// this id space for groups without changing what it means to a caller.
  final String conversationId;

  /// The remote device this conversation is with.
  final String peerDeviceId;

  /// This side's evaluated trust state for [peerDeviceId], or `null` when
  /// no relationship has ever been recorded for it (no row in
  /// `relationships` — distinct from an explicit
  /// [trust.RelationshipState.unknown] evaluation).
  final trust.RelationshipState? relationshipState;

  final String lastMessageId;

  /// Epoch-ms wall-clock time of the last message — the ordering key for
  /// the list (`ORDER BY lastMessageAt DESC`) and the keyset pagination
  /// cursor for the thread itself.
  final int lastMessageAt;

  /// True when the last message's sender is this device.
  final bool lastMessageIsMine;

  final DeliveryState lastMessageState;

  /// Messages from the peer whose `delivery_state` is not `read`. 0 for a
  /// conversation with no incoming messages.
  final int unreadCount;

  @override
  bool operator ==(Object other) =>
      other is ConversationSummary &&
      other.conversationId == conversationId &&
      other.peerDeviceId == peerDeviceId &&
      other.relationshipState == relationshipState &&
      other.lastMessageId == lastMessageId &&
      other.lastMessageAt == lastMessageAt &&
      other.lastMessageIsMine == lastMessageIsMine &&
      other.lastMessageState == lastMessageState &&
      other.unreadCount == unreadCount;

  @override
  int get hashCode => Object.hash(
        conversationId,
        peerDeviceId,
        relationshipState,
        lastMessageId,
        lastMessageAt,
        lastMessageIsMine,
        lastMessageState,
        unreadCount,
      );

  @override
  String toString() =>
      'ConversationSummary(conversationId: $conversationId, '
      'peerDeviceId: $peerDeviceId, relationshipState: $relationshipState, '
      'lastMessageId: $lastMessageId, lastMessageAt: $lastMessageAt, '
      'lastMessageIsMine: $lastMessageIsMine, '
      'lastMessageState: $lastMessageState, unreadCount: $unreadCount)';
}
