// features/chat/presentation — ChatController (E06-T11, "the wedge").
//
// Built against design/screens/chat.md. This is the first screen that
// actually sends and receives text through the real stack:
// `PrekeyExchange.ensureSession` (T07) -> `SendMessageUseCase.call`
// (E05-T02) -> persisted `queued` then `sent`/`failed` -> the coordinator's
// tick (T06) forwards it when a route exists. This controller never
// encrypts, frames or enqueues anything itself (task §2) and never calls
// `processQueue()` or subscribes to the transport directly (task §4).
//
// **Ordering (FR-MSG-004, EARS-COMM-1's sequence-order test).**
// `ConversationRepository.watchConversation` orders rows by
// `created_at DESC, id DESC` (`conversation_repository.dart`) — that is a
// keyset-pagination order, not the logical order this screen must render.
// `sequence_number` is monotonic only per `(conversationId,
// senderDeviceId)` (`message.dart`'s own dartdoc), so it cannot alone total-
// order two different senders' interleaved rows (no cross-party correlation
// exists in this schema). [_orderForDisplay] therefore compares by
// `sequenceNumber` for two rows from the SAME sender (correcting exactly the
// hazard this task's own test constructs: packets from one peer arriving
// out of the mesh in a different order than they were composed in) and
// falls back to `createdAt` only to interleave rows from the two different
// parties, where no sequence correlation exists. This is a real, disclosed
// limitation of the per-sender sequence-number design (E05-T01), not a bug
// introduced here — logged in this task's Run log / Deviations.
//
// **Decryption for display only (NFR-SEC-001).** Plaintext lives ONLY in
// [messages]' `ChatBubble.text` — an ephemeral, in-memory view-model list.
// It is never written back to `messages.ciphertext`, never logged, and
// never leaves this controller / the widget tree it feeds
// (`test_no_plaintext_is_persisted_or_logged`).
//
// **`ensureSession` can block for seconds (task §6 Risks).** [send] does
// NOT await `ensureSession` before returning control to the caller in a way
// that blocks the composer: the message is persisted `Queued` (via
// `SendMessageUseCase.call`, which reserves the row before any network
// round trip) and `ensureSession`/`SendMessageUseCase` run to completion in
// the background; the row exists immediately either way, driven by the live
// `watchConversation` stream, not by this method's own return.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/crypto/crypto_failures.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/messaging/delivery_ack.dart';
import 'package:nexora/core/messaging/prekey_exchange.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message.dart';
import 'package:nexora/features/messaging/domain/message_envelope.dart';
import 'package:nexora/features/messaging/domain/send_message_use_case.dart';

/// Matches the same constant independently declared in every other file
/// that mints a `SignalProtocolAddress` (`messaging_stack.dart`,
/// `conversations_controller.dart`, `prekey_exchange.dart`'s
/// `_remoteSignalDeviceId`) — Dart's privacy model makes literal reuse
/// across files impossible (those files' own headers explain why); the same
/// judgment call is repeated here rather than left unexplained.
const int _remoteSignalDeviceId = 1;

/// One row's worth of already-resolved display data — the Chat screen's
/// view-model (task §5 contract: "id, isMine, decrypted text, timestamp,
/// deliveryState"). `text` is `null` when decryption failed (graceful
/// degrade, same treatment `ConversationsController` already established for
/// its preview) — the row still renders, with a placeholder, never dropped.
@immutable
class ChatBubble {
  const ChatBubble({
    required this.id,
    required this.isMine,
    required this.text,
    required this.timestamp,
    required this.deliveryState,
    required this.sequenceNumber,
    required this.senderDeviceId,
  });

  final String id;
  final bool isMine;
  final String? text;
  final DateTime timestamp;
  final DeliveryState deliveryState;
  final int sequenceNumber;
  final String senderDeviceId;
}

class ChatController extends GetxController {
  ChatController({
    required this.conversationId,
    required ConversationRepository repo,
    required SendMessageUseCase send,
    required PrekeyExchange sessions,
    required CryptoService crypto,
    required DeliveryAckService acks,
  })  : _repo = repo, // ignore: prefer_initializing_formals
        _send = send, // ignore: prefer_initializing_formals
        _sessions = sessions, // ignore: prefer_initializing_formals
        _crypto = crypto, // ignore: prefer_initializing_formals
        _acks = acks; // ignore: prefer_initializing_formals

  final String conversationId;
  final ConversationRepository _repo;
  final SendMessageUseCase _send;
  final PrekeyExchange _sessions;
  final CryptoService _crypto;
  final DeliveryAckService _acks;

  /// This device's own id. The task's own §5 contract signature carries no
  /// separate `selfDeviceId`/`stack` parameter (unlike
  /// `ConversationsController`'s `stack`) — [ConversationRepository] already
  /// exposes it as a public field (`conversation_repository.dart`), so it is
  /// read from there rather than inventing a new constructor parameter.
  String get _selfDeviceId => _repo.selfDeviceId;

  /// The peer's device id — this schema's only conversation shape is 1:1,
  /// with `conversationId == peerDeviceId` (the same convention
  /// `ConversationRepository`/`DeliveryAckService` already established).
  String get _peerDeviceId => conversationId;

  /// The one binding target (task §5 contract) — ordered per this file's
  /// header note, never re-sorted by the view.
  final RxList<ChatBubble> messages = <ChatBubble>[].obs;

  /// True only until the first stream emission arrives — mirrors
  /// `ConversationsController`'s own "loading: first emission pending"
  /// contract, so a later empty emission renders the empty state
  /// (GAP-008), not the spinner.
  final RxBool loading = true.obs;

  /// Non-empty when the stack/stream itself is unavailable — an honest
  /// message, never a blank screen (task §5 "States required").
  final RxString errorMessage = ''.obs;

  /// Non-empty immediately after a failed [send] — the composer's own,
  /// specific, non-fatal reason (EARS-COMM-25). Cleared on the next attempt.
  final RxString sendError = ''.obs;

  StreamSubscription<List<Message>>? _subscription;

  /// Decrypted-text cache, keyed by message id — messages are immutable
  /// once stored (same reasoning `ConversationsController._previewCache`
  /// already documents), so a message id's plaintext (or confirmed decrypt
  /// failure, `null`) never needs re-decrypting.
  final Map<String, String?> _plaintextCache = <String, String?>{};

  /// The last rows [_onMessages] received from the live stream, merged with
  /// anything [loadOlder] paged in — the source [_renderPending] rebuilds
  /// [messages] from. Kept separately from [messages] itself because
  /// [messages] also carries [_pendingOptimistic] entries the DB has never
  /// seen (see [send]'s header note).
  List<Message> _lastRows = <Message>[];

  /// Locally-synthesized bubbles for a [send] still in flight, keyed by a
  /// synthetic id (`local-N`, never a real message id) so each can be
  /// reconciled/dropped once — and only once — the real row it stands in
  /// for is known, rather than ever rendering as a second, duplicate
  /// bubble. See [send]'s header note (task §6 Risks: "the message row
  /// exists either way").
  final Map<String, ChatBubble> _pendingOptimistic = <String, ChatBubble>{};

  int _localIdSeq = 0;

  @override
  void onInit() {
    super.onInit();
    _subscription = _repo.watchConversation(conversationId).listen(
      _onMessages,
      onError: (Object _, StackTrace _) {
        errorMessage.value = 'Could not load this conversation.';
        loading.value = false;
      },
    );
  }

  @override
  void onClose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.onClose();
  }

  Future<void> _onMessages(List<Message> rows) async {
    _lastRows = rows;
    await _renderPending();
    errorMessage.value = '';
    loading.value = false;
  }

  /// Builds display bubbles for [rows] alone — no pending/optimistic
  /// entries, no sort. Shared by [_onMessages], [loadOlder] and
  /// [_renderPending] so there is exactly one place that knows how a
  /// `Message` row becomes a `ChatBubble`.
  Future<List<ChatBubble>> _bubblesFor(List<Message> rows) async {
    final bubbles = <ChatBubble>[];
    for (final row in rows) {
      final text = await _resolvePlaintext(row);
      bubbles.add(
        ChatBubble(
          id: row.id,
          isMine: row.senderDeviceId == _selfDeviceId,
          text: text,
          timestamp: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
          deliveryState: row.deliveryState,
          sequenceNumber: row.sequenceNumber,
          senderDeviceId: row.senderDeviceId,
        ),
      );
    }
    return bubbles;
  }

  /// Rebuilds [messages] from [_lastRows] plus any still-in-flight
  /// [_pendingOptimistic] entries. Called both when the live stream emits
  /// ([_onMessages]) and when [send] adds, resolves or drops an optimistic
  /// bubble — so the composer never has a frame where a just-submitted
  /// message row genuinely does not exist on screen (task §6 Risks).
  Future<void> _renderPending() async {
    final bubbles = await _bubblesFor(_lastRows);
    bubbles.addAll(_pendingOptimistic.values);
    bubbles.sort(_orderForDisplay);
    messages.value = bubbles;
  }

  /// See this file's header for why `sequenceNumber` (same sender) and
  /// `timestamp` (cross-sender interleave) are combined rather than either
  /// alone.
  int _orderForDisplay(ChatBubble a, ChatBubble b) {
    if (a.senderDeviceId == b.senderDeviceId) {
      return a.sequenceNumber.compareTo(b.sequenceNumber);
    }
    return a.timestamp.compareTo(b.timestamp);
  }

  /// `ensureSession -> SendMessageUseCase` — the wedge, in one call (task §5
  /// contract). Never throws to the view (task §5: "every failure becomes a
  /// named, displayable reason") — every failure is caught and surfaced via
  /// [sendError], and the composed [text] is never discarded on failure
  /// (EARS-COMM-25): the caller (the view) keeps it in the text field until
  /// this completes.
  ///
  /// **`ensureSession` can block for seconds (task §6 Risks, and this is
  /// the finding this fix closes).** No row exists in `messages` — a plain
  /// `SendMessageUseCase.call` reserve-then-persist — for the entire
  /// duration `ensureSession` is in flight, which is exactly the first-
  /// contact scenario (EARS-COMM-23) `ensureSession` exists for, up to its
  /// own 20s timeout. A locally-synthesized [ChatBubble] (`Queued`) is
  /// therefore inserted into [messages] BEFORE `ensureSession` is even
  /// awaited, keyed by a synthetic `local-N` id private to this call
  /// ([_pendingOptimistic]) so it can never collide with a real message id.
  /// Once `SendMessageUseCase.call` returns the real, persisted row, that
  /// row is merged into [_lastRows] directly and the optimistic entry is
  /// dropped in the SAME synchronous step (no `await` between the two) —
  /// so there is never a frame with both the optimistic bubble and the real
  /// one visible, and never a frame with neither. On any failure — no
  /// session, bundle unavailable, blocked peer, timeout, or an untrusted-
  /// identity/crypto failure — the optimistic bubble is simply dropped: no
  /// row was ever durably reserved for a peer refused before
  /// `SendMessageUseCase.call` even ran (the blocked-peer case, refused
  /// inside `ensureSession` itself), and where `SendMessageUseCase.call`
  /// DID reserve a row before failing internally (task file's own
  /// `send_message_use_case.dart` header: a `Failed` row can be left behind
  /// by an encryption failure), that real `Failed` row arrives on its own
  /// via the live stream — rendering it a second time from stale local
  /// state here would be the duplicate this fix exists to prevent, not a
  /// fix for it.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    sendError.value = '';

    final localId = 'local-${_localIdSeq++}';
    _pendingOptimistic[localId] = ChatBubble(
      id: localId,
      isMine: true,
      text: trimmed,
      timestamp: DateTime.now(),
      deliveryState: DeliveryState.queued,
      sequenceNumber: _optimisticSequenceNumber,
      senderDeviceId: _selfDeviceId,
    );
    await _renderPending();

    try {
      // `ensureSession` can block for seconds (a bundle round trip over a
      // mesh, task §6 Risks) — awaited here, but the composer is never
      // blocked on it: the `Queued` bubble above already exists before
      // this line runs.
      await _sessions.ensureSession(_peerDeviceId);
      final message = await _send.call(
        conversationId,
        _peerDeviceId,
        Uint8List.fromList(utf8.encode(trimmed)),
      );
      // An outgoing message can never be decrypted by THIS device's own
      // `CryptoService` — Double Ratchet sessions are asymmetric, the same
      // note `ConversationsController` already documents for its own
      // preview step. This device already knows [trimmed] (it just typed
      // it), so the cache is seeded directly from the persisted [message]'s
      // own id rather than attempting — and always failing — a decrypt
      // round trip on its own outgoing ciphertext.
      _plaintextCache[message.id] = trimmed;
      _pendingOptimistic.remove(localId);
      _mergeLocalRow(message);
      await _renderPending();
    } on AppFailure catch (e) {
      await _dropOptimistic(localId, _reasonFor(e.code));
    } on TimeoutException {
      await _dropOptimistic(
        localId,
        'Could not reach this device in time. Try again.',
      );
    } on CryptoDecryptFailure catch (e) {
      await _dropOptimistic(
        localId,
        e.reason == CryptoDecryptFailureReason.untrustedIdentity
            ? 'This device\'s security key changed unexpectedly. Message not sent.'
            : 'Could not secure this message. Try again.',
      );
    } catch (_) {
      await _dropOptimistic(localId, 'Could not send this message. Try again.');
    }
  }

  /// Comfortably larger than any real `sequence_number` (per-sender, starts
  /// at 0 — `send_message_use_case.dart`) so a still-`Queued` optimistic
  /// bubble sorts after every one of this device's own already-persisted
  /// messages in [_orderForDisplay]; it is never itself persisted or
  /// compared against another device's rows (cross-sender comparisons use
  /// [ChatBubble.timestamp], not this).
  static const int _optimisticSequenceNumber = 1 << 31;

  /// Folds a just-persisted [message] into [_lastRows] immediately, keyed
  /// by id, rather than waiting for `watchConversation`'s own next
  /// emission — see [send]'s header note on why this must happen in the
  /// same synchronous step as dropping the optimistic bubble.
  void _mergeLocalRow(Message message) {
    final byId = {for (final row in _lastRows) row.id: row};
    byId[message.id] = message;
    _lastRows = byId.values.toList();
  }

  /// Drops a [send] call's optimistic bubble on failure and surfaces
  /// [reason] via [sendError] (EARS-COMM-25) — see [send]'s header note.
  Future<void> _dropOptimistic(String localId, String reason) async {
    _pendingOptimistic.remove(localId);
    await _renderPending();
    sendError.value = reason;
  }

  String _reasonFor(String code) => switch (code) {
        'messaging.no_session' =>
          'Could not start a secure session with this device.',
        'messaging.bundle_unavailable' =>
          'This device is not reachable right now. Try again later.',
        'messaging.peer_blocked' => 'You have blocked this contact.',
        _ => 'Could not send this message. Try again.',
      };

  /// Keyset scrollback via `messagesPage` (task §5 contract). Older pages
  /// are folded into [_lastRows] (the SAME source [_renderPending] rebuilds
  /// from) rather than only into [messages] directly — otherwise the next
  /// [_renderPending] call (a live stream emission, or a later [send])
  /// would rebuild from [_lastRows] alone and silently drop whatever this
  /// method had paged in. Decryption still uses the SAME cache, so a page
  /// already resolved is never re-decrypted.
  Future<void> loadOlder() async {
    if (messages.isEmpty) return;
    final oldest = messages.reduce(
      (a, b) => a.timestamp.isBefore(b.timestamp) ? a : b,
    );
    final oldestMs = oldest.timestamp.millisecondsSinceEpoch;
    final page = await _repo.messagesPage(conversationId, before: oldestMs);
    if (page.isEmpty) return;
    final byId = {for (final row in _lastRows) row.id: row};
    for (final row in page) {
      byId[row.id] = row;
    }
    _lastRows = byId.values.toList();
    await _renderPending();
  }

  /// Read-receipt hook (T08) — a no-op while `kReadReceiptsEnabled` is
  /// false (`OQ-E06-T08-1`); wired now so enabling it later is one constant
  /// (task §5 contract).
  void onMessageDisplayed(String messageId) {
    unawaited(_acks.markRead(messageId));
  }

  /// Decrypts [row]'s ciphertext for display only (NFR-SEC-001). Returns
  /// `null` on any failure — no session, wrong ratchet chain (this device's
  /// own outgoing message, which this device can never decrypt — Double
  /// Ratchet sessions are asymmetric, same note `ConversationsController`
  /// already documents), a parse failure, or an empty placeholder
  /// (`SendMessageUseCase`'s phase-1 `Uint8List(0)` row before phase 3
  /// writes the real ciphertext) — so the row still renders (with a
  /// placeholder), never as an error row.
  Future<String?> _resolvePlaintext(Message row) async {
    if (_plaintextCache.containsKey(row.id)) {
      return _plaintextCache[row.id];
    }
    String? text;
    if (row.ciphertext.isNotEmpty) {
      try {
        final address = SignalProtocolAddress(
          row.senderDeviceId == _selfDeviceId
              ? _peerDeviceId
              : row.senderDeviceId,
          _remoteSignalDeviceId,
        );
        final ciphertextMessage = _decodeCiphertext(row.ciphertext);
        final plaintext = await _crypto.decrypt(address, ciphertextMessage);
        final envelope = MessageEnvelope.deserialize(plaintext);
        text = utf8.decode(envelope.payload);
      } catch (_) {
        // Graceful degrade — see this method's own doc comment. Never
        // logged (NFR-SEC-001: no plaintext, no decrypt-failure detail that
        // could carry it, ever reaches a log).
        text = null;
      }
    }
    _plaintextCache[row.id] = text;
    return text;
  }

  CiphertextMessage _decodeCiphertext(Uint8List bytes) {
    try {
      return PreKeySignalMessage(bytes);
    } catch (_) {
      return SignalMessage.fromSerialized(bytes);
    }
  }
}
