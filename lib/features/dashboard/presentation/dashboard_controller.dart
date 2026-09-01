// features/dashboard/presentation — DashboardController (E06-T12).
//
// Built against design/screens/dashboard.md. This is the app's front door:
// FR-UI-004's simple connectivity reading (GAP-013), the Local Storage card
// (GAP-011, no data source until E08), and Recent Conversations — the SAME
// `ConversationRepository.watchConversations()` read model and the SAME
// `ConversationTile` view model T10's Conversations screen already defines
// (task §2/§6: two screens must not define the delivery-state glyph mapping
// twice, the exact "state defined in two documents" trap E05-B03 already
// was once). `ConversationTile`/`initialsOf` are imported directly from
// `conversations_controller.dart` rather than redeclared here.
//
// **NEVER SYNTHESIZE A MEASUREMENT (E04-B03's standing prohibition, applied
// here per task §2/§6).** Three numbers on this screen have no honest
// default:
// - `latencyMs` — real value from the most recent `LinkQuality` event on
//   `LinkQualityFeed.transport.linkQuality` (E06-T04's real producer), or
//   `null`. Never a literal like `24ms`.
// - The connectivity `reading` (GAP-013's three states) — derived from real,
//   currently-known transport/routing state (`LinkQualityFeed.transport`'s
//   `discoveredDevices`/`lostDevices` streams for "is any peer known at all"
//   and `LinkQualityFeed.routing.computeRoute` for "is any of them
//   reachable") — never a hardcoded `Connected`.
// - `storageUsage.percentUsed` — GAP-011: no storage quota/denominator
//   exists anywhere in this schema or spec to compute a percentage against
//   (the on-disk sqlite file's own byte size is measurable, but "% used"
//   needs a total to divide by, and inventing one would itself be exactly
//   the fabricated-figure defect this file's whole design avoids elsewhere
//   — see this task's own Deviations/Run log). `isMeasured` therefore stays
//   `false`, permanently, until E08 defines a real quota — never a fake
//   percentage presented as measured.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/conversations/presentation/conversations_controller.dart'
    show ConversationTile;
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/conversation_summary.dart';
import 'package:nexora/features/messaging/domain/message_envelope.dart';

/// Matches the same constant independently declared in
/// `conversations_controller.dart`/`chat_controller.dart`/
/// `messaging_stack.dart` — Dart's privacy model makes literal reuse across
/// files impossible (those files' own headers explain why); the same
/// judgment call is repeated here rather than left unexplained.
const int _localSignalDeviceId = 1;

/// GAP-013's three data-driven readings for the Network Status card —
/// `Connected` (as measured), `No peers nearby`, `No route to this peer`.
enum ConnectivityReading { connected, noPeers, noRoute }

/// The Network Status card's view model (task §5 contract). `latencyMs` is
/// `null` when no measurement exists yet — never a default (EARS-COMM-26).
/// `encryptionSecure` is true only when `MessagingStack.status` shows crypto
/// actually initialized (T03) — never assumed.
class NetworkStatusVm {
  const NetworkStatusVm({
    required this.reading,
    required this.latencyMs,
    required this.encryptionSecure,
  });

  final ConnectivityReading reading;
  final int? latencyMs;
  final bool encryptionSecure;
}

/// The Local Storage card's view model (task §5 contract / GAP-011).
/// `isMeasured == false` renders the disclosed placeholder, never a fake
/// number presented as measured.
class StorageUsageVm {
  const StorageUsageVm({required this.percentUsed, required this.isMeasured});

  final int? percentUsed;
  final bool isMeasured;
}

/// How many of `watchConversations()`'s rows the Recent Conversations
/// section renders — matches `design/screens/dashboard.md`'s own three
/// example rows (elements 20-34).
const int kDashboardRecentConversationCount = 3;

class DashboardController extends GetxController {
  DashboardController({
    required MessagingStack stack,
    required ConversationRepository repo,
    required LinkQualityFeed links,
    required CryptoService crypto,
  })  : _stack = stack, // ignore: prefer_initializing_formals
        _repo = repo, // ignore: prefer_initializing_formals
        _links = links, // ignore: prefer_initializing_formals
        _crypto = crypto; // ignore: prefer_initializing_formals

  final MessagingStack _stack;
  final ConversationRepository _repo;
  final LinkQualityFeed _links;
  final CryptoService _crypto;

  final Rx<NetworkStatusVm> networkStatus = const NetworkStatusVm(
    reading: ConnectivityReading.noPeers,
    latencyMs: null,
    encryptionSecure: false,
  ).obs;

  /// The one thing the Recent Conversations section binds to (task §5
  /// contract) — the SAME `ConversationTile` type T10's Conversations screen
  /// defines and renders, so the two screens cannot disagree about ordering,
  /// blocked-exclusion, or the delivery-state glyph mapping (task §6 risk).
  final RxList<ConversationTile> recent = <ConversationTile>[].obs;

  final Rx<StorageUsageVm> storageUsage = const StorageUsageVm(
    percentUsed: null,
    isMeasured: false,
  ).obs;

  /// True only until the first `watchConversations()` emission arrives —
  /// same "loading: first stream emission pending" contract
  /// `ConversationsController`/`ChatController` already establish, so a
  /// later empty emission still renders the (empty) Recent Conversations
  /// section, not the spinner.
  final RxBool loading = true.obs;

  /// Non-empty when the stack is unavailable — an honest message, never a
  /// blank screen (EARS-COMM-27).
  final RxString errorMessage = ''.obs;

  StreamSubscription<List<ConversationSummary>>? _conversationsSub;
  StreamSubscription<TransportDevice>? _discoveredSub;
  StreamSubscription<String>? _lostSub;
  StreamSubscription<LinkQuality>? _linkQualitySub;

  /// Every peer the transport has reported discovered and not yet lost —
  /// real, currently-known state, never a synthesized count. Empty means
  /// GAP-013's "No peers nearby" reading.
  final Set<String> _knownPeerIds = <String>{};

  /// The most recent real `LinkQuality` event's latency, or `null` if none
  /// has arrived yet (EARS-COMM-26). Never defaulted.
  int? _latestLatencyMs;

  /// Decrypted-preview cache, keyed by message id — same reasoning
  /// `ConversationsController._previewCache` already documents (messages are
  /// immutable once stored).
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

    // Idempotent (LinkQualityFeed.start()'s own contract) — in production
    // this is the SAME already-started singleton `bindings.dart` (E06-T04)
    // registers, so this is a harmless no-op there; in a test that
    // constructs a fresh `LinkQualityFeed`, this is what actually closes the
    // transport.linkQuality -> RoutingEngine.recordLinkMeasurement loop this
    // screen's own `computeRoute` calls depend on.
    _links.start();

    _conversationsSub = _repo.watchConversations().listen(
      _onSummaries,
      onError: (Object _, StackTrace _) {
        errorMessage.value = 'Could not load recent conversations.';
        loading.value = false;
      },
    );

    _discoveredSub = _links.transport.discoveredDevices.listen((device) {
      _knownPeerIds.add(device.id);
      _recomputeNetworkStatus();
    });
    _lostSub = _links.transport.lostDevices.listen((deviceId) {
      _knownPeerIds.remove(deviceId);
      _recomputeNetworkStatus();
    });
    _linkQualitySub = _links.transport.linkQuality.listen((quality) {
      _latestLatencyMs = quality.latencyMs;
      _recomputeNetworkStatus();
    });

    _recomputeNetworkStatus();
  }

  @override
  void onClose() {
    unawaited(_conversationsSub?.cancel());
    unawaited(_discoveredSub?.cancel());
    unawaited(_lostSub?.cancel());
    unawaited(_linkQualitySub?.cancel());
    super.onClose();
  }

  /// FR-UI-004's "one tap away" (GAP-012) — the whole Network Status card
  /// navigates to `/devices`, an already-built surface, rather than a new
  /// route-detail screen.
  void openNetworkDetail() {
    Get.toNamed('/devices');
  }

  void _recomputeNetworkStatus() {
    final reading = _knownPeerIds.isEmpty
        ? ConnectivityReading.noPeers
        : (_hasRouteToAnyKnownPeer()
            ? ConnectivityReading.connected
            : ConnectivityReading.noRoute);
    networkStatus.value = NetworkStatusVm(
      reading: reading,
      latencyMs: _latestLatencyMs,
      encryptionSecure: _stack.status.isReady,
    );
  }

  /// GAP-013's "connected" reading: at least one currently-known peer has a
  /// real, currently-computable route. Uses the real `RoutingEngine` this
  /// `LinkQualityFeed` already feeds (E06-T04) — never a placeholder route.
  bool _hasRouteToAnyKnownPeer() {
    for (final peerId in _knownPeerIds) {
      if (_links.routing.computeRoute(peerId, TrafficProfile.interactive) !=
          null) {
        return true;
      }
    }
    return false;
  }

  Future<void> _onSummaries(List<ConversationSummary> summaries) async {
    // E07-T07 widened `watchConversations()` to emit group rows too. Recent
    // Conversations renders the SAME `ConversationTile` the Conversations
    // screen's Personal section does, and no group row treatment exists yet
    // (E07-T08 / GAP-006), so group rows are filtered out **before** the
    // take — filtering after it would silently shrink the section below its
    // designed three rows. This keeps today's behaviour identical and
    // renders no group as if it were a peer; whether the Dashboard should
    // eventually surface groups here is a design question for the task that
    // owns a group row, not one answered by omission here.
    final top = summaries
        .where((s) => s.kind == ConversationKind.personal)
        .take(kDashboardRecentConversationCount);
    final tiles = <ConversationTile>[];
    for (final summary in top) {
      final preview = await _resolvePreview(summary);
      tiles.add(ConversationTile.from(summary, preview: preview));
    }
    recent
      ..clear()
      ..addAll(tiles);
    errorMessage.value = '';
    loading.value = false;
  }

  /// Same graceful-degrade decryption as `ConversationsController`'s own
  /// `_resolvePreview` (this file's header — duplicated per Dart's privacy
  /// model, not a second, diverging implementation of the state machine):
  /// any failure (no session, wrong ratchet chain, a parse failure) degrades
  /// to `null` so the row still renders with name and time.
  Future<String?> _resolvePreview(ConversationSummary summary) async {
    if (_previewCache.containsKey(summary.lastMessageId)) {
      return _previewCache[summary.lastMessageId];
    }
    // Same guard, same reason as `ConversationsController._resolvePreview`:
    // E07-T07's group rows carry no `peerDeviceId`, so there is no 1:1
    // session to address, and "no preview" is this method's existing,
    // documented degrade rather than a new behaviour.
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
      preview = null;
    }
    _previewCache[summary.lastMessageId] = preview;
    return preview;
  }

  CiphertextMessage _decodeCiphertext(Uint8List bytes) {
    try {
      return PreKeySignalMessage(bytes);
    } catch (_) {
      return SignalMessage.fromSerialized(bytes);
    }
  }
}
