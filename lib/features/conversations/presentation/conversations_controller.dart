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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/domain/group_message_envelope.dart';
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

  /// Builds a **personal** conversation's row. E07-T07 widened
  /// [ConversationSummary] to cover groups too, making
  /// [ConversationSummary.peerDeviceId] nullable — it is non-null exactly
  /// when `kind == ConversationKind.personal`. Both callers
  /// ([ConversationsController._onSummaries] and
  /// `DashboardController._onSummaries`) filter group rows out before
  /// calling this, because neither screen has a group row treatment yet —
  /// the Conversations screen's `Groups` section is E07-T08 (GAP-006), and
  /// this task does not invent one. The `?? s.conversationId` fallbacks are
  /// therefore unreachable by construction; they exist so a group row that
  /// ever did reach here degrades to the opaque conversation id (the only
  /// honest non-null stand-in this projection has) rather than crashing or
  /// rendering a faked peer id.
  factory ConversationTile.from(ConversationSummary s, {String? preview}) {
    assert(
      s.kind == ConversationKind.personal && s.peerDeviceId != null,
      'ConversationTile describes a personal conversation; group rows are '
      'E07-T08 and must be filtered out before this factory is called.',
    );
    final peerDeviceId = s.peerDeviceId ?? s.conversationId;
    return ConversationTile(
      conversationId: s.conversationId,
      peerDeviceId: peerDeviceId,
      displayName: peerDeviceId,
      initials: initialsOf(peerDeviceId),
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

/// GAP-009's approved delivery-tick glyph mapping — the SAME mapping
/// `chat_view.dart`'s/`dashboard_view.dart`'s own `_tickIconFor` implement
/// (byte-for-byte), exported here rather than duplicated a third time inside
/// `conversations_view.dart` (E06-B03 fixed this screen's tick mapping by
/// duplicating chat's function verbatim into the view; E07-T08 relocates
/// that single copy here instead of adding a fourth, so both the Personal
/// and the Groups sections read from exactly one definition in this
/// feature — never re-derived, never a second `switch`).
IconData tickIconFor(DeliveryState state) => switch (state) {
      DeliveryState.queued => Icons.radio_button_unchecked,
      DeliveryState.sent || DeliveryState.accepted || DeliveryState.stored =>
        Icons.check,
      DeliveryState.delivered => Icons.done_all,
      DeliveryState.read => Icons.done_all,
      DeliveryState.failed => Icons.error_outline,
    };

/// Paired colour split for [tickIconFor] — used by the Personal section only
/// (task §5's `GroupRowViewModel` contract has no colour field; see the
/// view's header note on why Groups rows render [tickIconFor]'s icon in one
/// neutral tone rather than this read/unread split).
Color tickColorFor(DeliveryState state) => state == DeliveryState.read
    ? NexoraColors.devicesTrustedGreen
    : NexoraColors.devicesMuted;

/// "10:42 AM" (today) / "Yesterday" / "Oct 12" (older) — the three example
/// formats the contract's own rows and its Groups section draw, without a
/// new `intl` dependency (rule 3 — none is added here). Exported so both
/// sections format identically from one definition; previously lived only
/// in `conversations_view.dart` for the Personal section's own inline call.
String relativeTimeLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final diffDays = today.difference(that).inDays;
  if (diffDays == 0) return _formatClock(dt);
  if (diffDays == 1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

String _formatClock(DateTime dt) {
  final hour24 = dt.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

/// One Groups-section row's already-resolved display data (task §5's exact
/// contract, field for field against `design/screens/conversations.md`
/// elements 22-33).
///
/// - [preview] is never null (unlike [ConversationTile.preview]) — a decrypt
///   failure or an own-outgoing message (this device can never decrypt its
///   own sender-key chain, mirroring the 1:1 asymmetry this file's header
///   documents — `group_crypto_service_test.dart`: "a single device is
///   never both the sender AND a receiver of its OWN chain") degrades to the
///   empty string rather than an error row, exactly the graceful-degrade
///   contract E06-T10 established for Personal.
/// - [senderPrefix] is null exactly when the group's last message is this
///   device's own — GAP-020's already-approved rule ("outgoing bubbles [get
///   no attribution line]; the design never labels the user to themselves"),
///   reused here rather than invented a second time for this row shape.
/// - [connectivityIcon] is `Icons.dns` for every row: no per-group
///   connectivity/route signal exists anywhere in [ConversationSummary] or
///   `GroupRepository` (this task's `files:` fence forbids adding one), so a
///   single, honest, uniform treatment is used rather than fabricating two
///   states from no data — the same judgment call GAP-003 already made for
///   the Devices/Personal-row avatar. `cloud_off` (the contract's other
///   optional glyph, contract §2) is never rendered for the same reason.
class GroupRowViewModel {
  const GroupRowViewModel({
    required this.conversationId,
    required this.name,
    required this.timestampLabel,
    required this.preview,
    this.senderPrefix,
    required this.connectivityIcon,
    required this.deliveryIcon,
  });

  final String conversationId;
  final String name;
  final String timestampLabel;
  final String preview;
  final String? senderPrefix;
  final IconData connectivityIcon;
  final IconData deliveryIcon;
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

  /// Constructed in [onInit] (needs `_stack.db`, only available once the
  /// stack is confirmed ready) — the Groups section's own read surface for
  /// a row's current `membershipEpoch` (needed to attempt a preview
  /// decrypt; task §5/§2).
  late final GroupRepository _groups = GroupRepository(_stack.db);

  /// Every loaded conversation, unfiltered — [conversations] is derived from
  /// this plus the current [search] query.
  final List<ConversationTile> _all = <ConversationTile>[];

  /// The one thing the view binds to (task contract).
  final RxList<ConversationTile> conversations = <ConversationTile>[].obs;

  /// The Groups section's rows (task §5 contract) — derived from the same
  /// widened `watchConversations()` stream, never filtered by [search]
  /// (the task does not extend the client-side search filter to Groups).
  final RxList<GroupRowViewModel> groups = <GroupRowViewModel>[].obs;

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

  /// Same caching discipline as [_previewCache] (task §6), kept separate
  /// since a group preview's decrypt inputs (`groupId`, `epoch`,
  /// `senderDeviceId`) differ from a personal preview's.
  final Map<String, String?> _groupPreviewCache = <String, String?>{};

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
    final groupRows = <GroupRowViewModel>[];
    // E07-T07 widened `watchConversations()` to emit group rows too, already
    // interleaved by recency across both kinds. Splitting here preserves
    // each section's own recency order (task §3 manual test) without a
    // second query.
    for (final summary in summaries) {
      if (summary.kind == ConversationKind.personal) {
        final preview = await _resolvePreview(summary);
        tiles.add(ConversationTile.from(summary, preview: preview));
      } else {
        groupRows.add(await _buildGroupRow(summary));
      }
    }
    _all
      ..clear()
      ..addAll(tiles);
    _applyFilter();
    groups.value = groupRows;
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
    // A 1:1 Double Ratchet session is addressed by the peer's device id, and
    // E07-T07 made that field null for a group row (a group has no single
    // peer). No peer id means no 1:1 session to decrypt against — that is
    // "no preview", the same graceful degrade this method already applies to
    // every other failure, not an error row. Group previews use the group
    // sender-key session instead — see [_resolveGroupPreview].
    final peerDeviceId = summary.peerDeviceId;
    if (peerDeviceId == null) {
      _previewCache[summary.lastMessageId] = null;
      return null;
    }
    String? preview;
    try {
      final page = await _repo.messagesPage(summary.conversationId, limit: 1);
      if (page.isNotEmpty && page.first.id == summary.lastMessageId) {
        final ciphertextMessage = _decodeCiphertext(page.first.ciphertext);
        final plaintext = await _crypto.decrypt(
          SignalProtocolAddress(peerDeviceId, _localSignalDeviceId),
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

  /// Builds one Groups-section row (task §5's `GroupRowViewModel` contract)
  /// from [summary]. The sender-name prefix (design element 26, "David
  /// Chen:") is assembled HERE, in the screen layer — never added to
  /// `ConversationSummary`/the repository (task §2, E07-T07 §2 restated) —
  /// from [ConversationSummary.lastMessageSenderDeviceId], which E07-T07
  /// exposed specifically so this row would not need a second query.
  Future<GroupRowViewModel> _buildGroupRow(ConversationSummary summary) async {
    final preview = await _resolveGroupPreview(summary);
    return GroupRowViewModel(
      conversationId: summary.conversationId,
      name: summary.groupName ?? summary.conversationId,
      timestampLabel: relativeTimeLabel(
        DateTime.fromMillisecondsSinceEpoch(summary.lastMessageAt),
      ),
      preview: preview ?? '',
      // GAP-020's already-approved rule, reused rather than re-derived:
      // outgoing messages carry no self-attribution. `lastMessageIsMine`
      // being true is exactly "the last message is this device's own".
      senderPrefix: summary.lastMessageIsMine
          ? null
          : '${summary.lastMessageSenderDeviceId}:',
      connectivityIcon: Icons.dns,
      deliveryIcon: tickIconFor(summary.lastMessageState),
    );
  }

  /// Decrypts a group row's last message for display only (task §2/§3),
  /// mirroring [_resolvePreview]'s exact division and graceful-degrade
  /// contract for the personal case: any failure — no chain held for that
  /// sender/epoch (`group.no_chain`, including this device's own outgoing
  /// messages, which this device can never decrypt under its own sending
  /// chain — see `GroupRowViewModel`'s own doc comment), a parse failure, or
  /// an unrecognized group — degrades to `null` ("no preview"), never an
  /// error row.
  Future<String?> _resolveGroupPreview(ConversationSummary summary) async {
    if (_groupPreviewCache.containsKey(summary.lastMessageId)) {
      return _groupPreviewCache[summary.lastMessageId];
    }
    String? preview;
    try {
      final group = await _groups.groupRow(summary.conversationId);
      final epoch = group?.membershipEpoch;
      if (epoch != null) {
        final page = await _repo.messagesPage(
          summary.conversationId,
          limit: 1,
        );
        if (page.isNotEmpty && page.first.id == summary.lastMessageId) {
          final plaintext = await _stack.groupCryptoService.decryptFromGroup(
            groupId: summary.conversationId,
            epoch: epoch,
            senderDeviceId: summary.lastMessageSenderDeviceId,
            bytes: page.first.ciphertext,
          );
          final envelope = GroupMessageEnvelope.deserialize(plaintext);
          preview = utf8.decode(envelope.body);
        }
      }
    } catch (_) {
      // Graceful degrade — see this method's own doc comment.
      preview = null;
    }
    _groupPreviewCache[summary.lastMessageId] = preview;
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
