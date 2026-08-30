// features/conversations/presentation — ConversationsController (E06-T10).
//
// Built against design/screens/conversations.md. Reads the live conversation
// list from `ConversationRepository.watchConversations()` (E06-T09) and, for
// display only, decrypts each conversation's last message via the stack's
// `CryptoService` (E03-T03) — the repository itself never decrypts anything
// (E06-T09 §2/§4). Decrypted plaintext lives ONLY in this controller's
// ephemeral in-memory view-model list (`conversations`); it is never
// persisted, logged, or written back to the database (task §2).
//
// Preview decryption note: `messages.ciphertext` is stored as the raw
// serialized `CiphertextMessage` bytes with no payload-type tag alongside it
// (unlike the wire format, `RelayPacketFrame.payloadType` — see
// `ciphertext_codec.dart`'s header). Reconstructing a `CiphertextMessage`
// from those bytes therefore tries `PreKeySignalMessage` first, then
// `SignalMessage.fromSerialized`, purely as a best-effort DISPLAY step — the
// task's own contract requires any decryption failure (a parse failure
// included) to degrade to "no preview" rather than an error row (task §2),
// so a wrong guess here is self-correcting: it throws, is caught, and the
// row still renders with name and time. This mirrors the already-logged,
// still-open gap in `receive_message_use_case.dart`'s header (no single
// type-discriminating reconstructor exists in `libsignal_protocol_dart`
// 0.8.2) rather than inventing a new persisted column, which is out of this
// task's `files:` fence and would be a schema migration (🧍 gate) regardless.
//
// A message this device SENT can also never be decrypted by this device's
// own CryptoService (Double Ratchet sessions are asymmetric — only the
// recipient's receiving chain can decrypt a message encrypted with the
// sender's sending chain), so an outgoing last-message naturally, honestly
// degrades to "no preview" too. This is expected, not a bug.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/conversation_summary.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message_envelope.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// Signal device-id half of every `SignalProtocolAddress` this app mints —
/// matches the same constant already declared independently in
/// `messaging_stack.dart`/`receive_message_use_case.dart` (Dart privacy
/// makes literal reuse across files impossible; same judgment call those
/// files already recorded).
const int _localSignalDeviceId = 1;

/// One row's worth of already-resolved display data — the Conversations
/// screen's view-model. `preview` is `null` when there is no message, or the
/// decrypt/parse step failed (task §2's graceful degrade).
class ConversationTile {
  const ConversationTile({
    required this.conversationId,
    required this.peerDeviceId,
    required this.displayName,
    required this.initials,
    required this.relationshipState,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    required this.lastMessageState,
    required this.unreadCount,
    required this.preview,
  });

  final String conversationId;
  final String peerDeviceId;

  /// `RelationshipRepository` has no display-name column yet
  /// (`design/gaps.md` GAP-003) — the peer's device id stands in for a name,
  /// same treatment already approved for the Devices screen.
  final String displayName;

  /// Contract element 15's `MS`-style initials, derived from [displayName]
  /// (GAP-003 — there is no avatar image source either).
  final String initials;

  final RelationshipState? relationshipState;
  final DateTime lastMessageAt;
  final bool lastMessageIsMine;
  final DeliveryState lastMessageState;
  final int unreadCount;
  final String? preview;

  factory ConversationTile.from(ConversationSummary s, {String? preview}) {
    return ConversationTile(
      conversationId: s.conversationId,
      peerDeviceId: s.peerDeviceId,
      displayName: s.peerDeviceId,
      initials: initialsOf(s.peerDeviceId),
      relationshipState: s.relationshipState,
      lastMessageAt: DateTime.fromMillisecondsSinceEpoch(s.lastMessageAt),
      lastMessageIsMine: s.lastMessageIsMine,
      lastMessageState: s.lastMessageState,
      unreadCount: s.unreadCount,
      preview: preview,
    );
  }
}

/// `MS`-style initials (element 15) from a device id — the closest thing to
/// a name this schema has pre-E04 (GAP-003). Alphanumeric characters only,
/// first one or two, uppercased.
String initialsOf(String name) {
  final alnum = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (alnum.isEmpty) return '?';
  return alnum.substring(0, alnum.length >= 2 ? 2 : 1).toUpperCase();
}

class ConversationsController extends GetxController {
  // The task's own contract fixes these three named-parameter labels
  // (`repo`/`crypto`/`stack`) — an initializing formal would force the
  // private field names below to match those labels exactly (losing the
  // leading underscore), so the assignment is written out instead.
  ConversationsController({
    required ConversationRepository repo,
    required CryptoService crypto,
    required MessagingStack stack,
  })  : _repo = repo, // ignore: prefer_initializing_formals
        _crypto = crypto, // ignore: prefer_initializing_formals
        _stack = stack; // ignore: prefer_initializing_formals

  final ConversationRepository _repo;
  final CryptoService _crypto;
  final MessagingStack _stack;

  /// Every loaded conversation, unfiltered — [conversations] is derived from
  /// this plus the current [search] query.
  final List<ConversationTile> _all = <ConversationTile>[];

  /// The one thing the view binds to (task contract).
  final RxList<ConversationTile> conversations = <ConversationTile>[].obs;

  /// True only until the first stream emission arrives (task §5 "loading:
  /// first stream emission pending") — never true again after that, so a
  /// later empty emission renders the empty state, not the spinner.
  final RxBool loading = true.obs;

  /// Non-empty when the stack is unavailable or the stream itself errors —
  /// an honest message per T03's `MessagingStackStatus`, never a blank
  /// screen (task §5).
  final RxString errorMessage = ''.obs;

  final RxString query = ''.obs;

  /// Element 4-5's `search` header action focuses this rather than opening a
  /// second, undesigned surface (view's own header note).
  final FocusNode searchFieldFocusNode = FocusNode();

  StreamSubscription<List<ConversationSummary>>? _subscription;

  /// Decrypted preview cache, keyed by message id — messages are immutable
  /// once stored, so a message id's preview (or confirmed absence, `null`)
  /// never needs re-decrypting (task §6 "cache by message id; decrypt only
  /// what changed").
  final Map<String, String?> _previewCache = <String, String?>{};

  @override
  void onInit() {
    super.onInit();
    if (!_stack.status.isReady) {
      final status = _stack.status;
      errorMessage.value = status is MessagingStackStatusUnavailable
          ? 'Messaging is unavailable: ${status.reason}'
          : 'Messaging is unavailable.';
      loading.value = false;
      return;
    }
    _subscription = _repo.watchConversations().listen(
      _onSummaries,
      onError: (Object _, StackTrace _) {
        errorMessage.value = 'Could not load conversations.';
        loading.value = false;
      },
    );
  }

  @override
  void onClose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    searchFieldFocusNode.dispose();
    super.onClose();
  }

  Future<void> _onSummaries(List<ConversationSummary> summaries) async {
    final tiles = <ConversationTile>[];
    for (final summary in summaries) {
      final preview = await _resolvePreview(summary);
      tiles.add(ConversationTile.from(summary, preview: preview));
    }
    _all
      ..clear()
      ..addAll(tiles);
    _applyFilter();
    errorMessage.value = '';
    loading.value = false;
  }

  /// Client-side filter over the already-loaded list (task contract) — no
  /// new query, no server round trip. An empty [q] restores the full list.
  void search(String q) {
    query.value = q;
    _applyFilter();
  }

  void _applyFilter() {
    final q = query.value.trim().toLowerCase();
    conversations.value = q.isEmpty
        ? List<ConversationTile>.from(_all)
        : _all
            .where((t) => t.displayName.toLowerCase().contains(q))
            .toList();
  }

  /// Navigates to `/chat/<conversationId>` (T11's route). Until T11 adds it,
  /// `Get.toNamed` on an unregistered route is a documented GetX no-op — the
  /// tap is inert, per this task's §3/§Deviations, not a new destination.
  void openConversation(String conversationId) {
    Get.toNamed('/chat/$conversationId');
  }

  /// Decrypts [summary]'s last message for display only (task §2). Returns
  /// `null` on any failure — no session, wrong ratchet chain (this device's
  /// own outgoing message), a parse failure, or a malformed envelope — so
  /// the row still renders with name and time (never an error row).
  Future<String?> _resolvePreview(ConversationSummary summary) async {
    if (_previewCache.containsKey(summary.lastMessageId)) {
      return _previewCache[summary.lastMessageId];
    }
    String? preview;
    try {
      final page = await _repo.messagesPage(summary.conversationId, limit: 1);
      if (page.isNotEmpty && page.first.id == summary.lastMessageId) {
        final ciphertextMessage = _decodeCiphertext(page.first.ciphertext);
        final plaintext = await _crypto.decrypt(
          SignalProtocolAddress(summary.peerDeviceId, _localSignalDeviceId),
          ciphertextMessage,
        );
        final envelope = MessageEnvelope.deserialize(plaintext);
        preview = utf8.decode(envelope.payload);
      }
    } catch (_) {
      // Graceful degrade — see this file's header note.
      preview = null;
    }
    _previewCache[summary.lastMessageId] = preview;
    return preview;
  }

  /// Best-effort reconstruction of whichever `CiphertextMessage` subtype
  /// [bytes] serializes — see this file's header for why no type tag is
  /// available to dispatch on explicitly at this call site.
  CiphertextMessage _decodeCiphertext(Uint8List bytes) {
    try {
      return PreKeySignalMessage(bytes);
    } catch (_) {
      return SignalMessage.fromSerialized(bytes);
    }
  }
}
