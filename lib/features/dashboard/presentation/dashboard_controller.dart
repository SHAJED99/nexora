// features/dashboard/presentation — DashboardController (E06-T12, widened
// E08-T08).
//
// Built against design/screens/dashboard.md. This is the app's front door:
// FR-UI-004's simple connectivity reading (GAP-013), the Local Storage card
// (GAP-011, now fed real figures by E08-T08), and Recent Conversations — the
// SAME `ConversationRepository.watchConversations()` read model and the SAME
// `ConversationTile` view model T10's Conversations screen already defines
// (task §2/§6: two screens must not define the delivery-state glyph mapping
// twice, the exact "state defined in two documents" trap E05-B03 already
// was once). `ConversationTile`/`initialsOf` are imported directly from
// `conversations_controller.dart` rather than redeclared here.
//
// **NEVER SYNTHESIZE A MEASUREMENT (E04-B03's standing prohibition, applied
// here per task §2/§6).** On this screen:
// - `latencyMs` — real value from the most recent `LinkQuality` event on
//   `LinkQualityFeed.transport.linkQuality` (E06-T04's real producer), or
//   `null`. Never a literal like `24ms`.
// - The connectivity `reading` (GAP-013's three states) — derived from real,
//   currently-known transport/routing state (`LinkQualityFeed.transport`'s
//   `discoveredDevices`/`lostDevices` streams for "is any peer known at all"
//   and `LinkQualityFeed.routing.computeRoute` for "is any of them
//   reachable") — never a hardcoded `Connected`.
// - `storageUsage.percentUsed` — `GAP-026`'s answered fork (`OQ-E08-1`,
//   option (c) for this card): `storage_policy_settings.budget_bytes` is
//   NULL by default (no denominator), so `percentUsed` stays `null` and the
//   card shows the real measured byte total instead — never a fabricated
//   percentage presented as measured. `usedBytes`/`isMeasured` are E08-T08's
//   own widening: `usedBytes` is always `StorageInventory.totalBytes()`'s
//   real sum; `isMeasured` is `false` only before the controller's first
//   successful read (or after a read failure) — the honest "not yet
//   measured" fallback, never a zero presented as real (task §2, `GAP-011`'s
//   own placeholder pattern reused for this narrower purpose).
//
// **The card reads the storage domain; it never triggers a pass** (task
// §2/§4 — `EARS-STORE-2`/`FR-STORE-006`). `_loadStorageUsage` only calls
// `StorageManager.inventory.snapshot()` (a read-only SQL aggregate) and
// `StorageManager.settings.read()` (a read-only row fetch), and observes
// `StorageManager.latestPlan`/`.log.latestPass()` — the same values
// `MessagingCoordinator`'s own periodic tick already produced in the
// background. Nothing here calls `StorageManager.runPass`,
// `RetentionExecutor.apply`, or writes any row.
//
// **The "Will remove:" list is filtered, not the raw plan (task §2's "never
// re-implement policy in a widget" balanced against a real correctness
// risk).** `SmartModePolicy.plan()` (E08-T04) scores `message`-kind items by
// age/access/size regardless of mode — the mode-dependent exclusion
// (`OQ-E08-3(a)`: Smart Mode never deletes conversation content) is enforced
// downstream, by `StorageManager`/`RetentionExecutor` at apply time, not by
// the pure scorer. Showing `plan.groups` uncritically would therefore let a
// Smart Mode user read "Will remove: Messages" for content that categorically
// will never be removed under their active policy — exactly the false
// warning `FR-STORE-006`'s "informational" promise forbids. `_actionableGroups`
// mirrors the SAME two unconditional invariants `RetentionExecutor.apply`
// already enforces (never a new policy, never a new number): a `relayPayload`
// group is always `RelayEngine.reclaimPayloads`'s (E04-B02), and a `message`
// group is never actionable under a Smart Mode plan. This is exactly
// `design/screens/dashboard.md`'s own stated reasoning for why "Nothing to
// remove right now." is the expected default reading (GAP-025), not an
// invented filter.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart' show StorageDecisionRow;
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/storage_item.dart' show StorageItemKind;
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart'
    show StorageMode;
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

/// The Local Storage card's view model (E08-T08 §5 contract; widens
/// GAP-011's placeholder). `usedBytes` is always the real measured total from
/// `StorageInventory` (via `StorageManager`) — never estimated. `isMeasured`
/// is `false` only before the first successful read or after a read failure
/// (the honest fallback; `usedBytes` is meaningless in that case and MUST NOT
/// be rendered). `percentUsed` is non-null only when
/// `storage_policy_settings.budget_bytes` is set (`OQ-E08-1`/`GAP-026`) —
/// never computed against an invented denominator.
/// `policySummaryKey` is a machine key (never display copy itself) the view
/// maps to the design contract's `<Mode> - <parameter>` copy (element 18) —
/// keeping the actual strings out of the controller, per this task's own
/// "copy is character-for-character from the contract, never from a
/// controller" rule. `warningActive` says whether element 17's warning glyph
/// should render — element 18's policy-summary line renders unconditionally
/// regardless (`dashboard.md`'s own element table: only the glyph is
/// conditional).
class StorageUsageVm {
  const StorageUsageVm({
    required this.usedBytes,
    required this.isMeasured,
    this.percentUsed,
    required this.policySummaryKey,
    required this.warningActive,
  });

  final int usedBytes;
  final bool isMeasured;
  final int? percentUsed;
  final String policySummaryKey;
  final bool warningActive;
}

/// One category row FR-STORE-007's expanded explanation renders (GAP-025's
/// DX2-DX4) — a real candidate group from the latest actionable plan, never
/// a synthesized row. `reason`/`reasonDetail` are the SAME machine keys
/// `RetentionCandidateGroup` already carries (`retention_plan.dart`) — the
/// view, not this controller, maps them to the contract's copy.
class StorageDecisionVm {
  const StorageDecisionVm({
    required this.categoryKey,
    required this.bytes,
    required this.reason,
    required this.reasonDetail,
  });

  final String categoryKey;
  final int bytes;
  final RetentionReason reason;
  final String? reasonDetail;
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
    required StorageManager storage,
  })  : _stack = stack, // ignore: prefer_initializing_formals
        _repo = repo, // ignore: prefer_initializing_formals
        _links = links, // ignore: prefer_initializing_formals
        _crypto = crypto, // ignore: prefer_initializing_formals
        _storage = storage; // ignore: prefer_initializing_formals

  final MessagingStack _stack;
  final ConversationRepository _repo;
  final LinkQualityFeed _links;
  final CryptoService _crypto;
  final StorageManager _storage;

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
    usedBytes: 0,
    isMeasured: false,
    percentUsed: null,
    policySummaryKey: '',
    warningActive: false,
  ).obs;

  /// FR-STORE-007's expansion state — toggled only by [toggleStorageExpansion]
  /// (a tap), never set as a side effect of loading data.
  final RxBool storageExpanded = false.obs;

  /// What the expanded state renders (task §5 contract) — one entry per
  /// actionable category in the latest pass, most significant (largest
  /// [StorageDecisionVm.bytes]) first; empty before the first pass, or once
  /// the active policy has nothing actionable to report (GAP-025's DX7 —
  /// the expected default reading under Smart Mode).
  final RxList<StorageDecisionVm> storageExplanation = <StorageDecisionVm>[].obs;

  /// True only while `storage_decisions`' latest pass could not be read
  /// (mirrors [StorageUsageVm.isMeasured]'s read-failure fallback, but kept
  /// separate since a byte-total read and a decision-log read can fail
  /// independently) — renders DX8's `Couldn't read local storage. Try
  /// again.` in the expanded state rather than a silently-empty list.
  final RxBool storageExplanationError = false.obs;

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
  Worker? _storagePlanWorker;

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

    // The storage domain is independent of the messaging stack's own
    // readiness (task §2: "the card reads; it never triggers a pass") — read
    // it regardless of whether `_stack.status.isReady` below, so a degraded
    // messaging stack does not also blank out an otherwise-healthy storage
    // reading.
    unawaited(_loadStorageUsage());
    // Re-read whenever `MessagingCoordinator`'s own background tick produces
    // a new pass — never triggers one itself (`StorageManager.latestPlan` is
    // observe-only from this file's perspective).
    _storagePlanWorker = ever<RetentionPlan?>(
      _storage.latestPlan,
      (_) => unawaited(_loadStorageUsage()),
    );

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
    _storagePlanWorker?.dispose();
    super.onClose();
  }

  /// FR-UI-004's "one tap away" (GAP-012) — the whole Network Status card
  /// navigates to `/devices`, an already-built surface, rather than a new
  /// route-detail screen.
  void openNetworkDetail() {
    Get.toNamed('/devices');
  }

  /// FR-STORE-007's expansion (task §5 contract). Flips the expansion flag
  /// ONLY — never runs, applies or schedules anything
  /// (`EARS-STORE-2`/`FR-STORE-006`). The data it reveals was already loaded
  /// by [_loadStorageUsage]; tapping never re-reads, never re-plans.
  void toggleStorageExpansion() {
    storageExpanded.value = !storageExpanded.value;
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

  /// Reads (never writes) `StorageManager.inventory`/`.settings` for the
  /// collapsed card, and `StorageManager.latestPlan` **or**
  /// `StorageDecisionLog.latestPass()` for the expanded explanation — task
  /// §2/§4's "the card reads; it never triggers a pass". A failure anywhere
  /// in this method degrades to the honest `isMeasured: false` fallback
  /// rather than propagating (this is a display read, not something allowed
  /// to crash the dashboard).
  ///
  /// **`latestPlan` is in-memory and does not survive a relaunch** (round-1
  /// review finding F1): `StorageManager.runPass` returns `null` without
  /// touching `latestPlan` whenever the throttle window hasn't elapsed since
  /// the last recorded pass — the common case on any launch within
  /// `storagePassInterval` (6h) of the last background tick, not an edge
  /// case. `storage_decisions` itself is durable (a real table), so
  /// `latestPlan == null` falls back to reading
  /// `StorageDecisionLog.latestPass()` directly and reconstructing the
  /// explanation from those rows (`_decisionsFromLog`) rather than showing
  /// an empty list that contradicts real, already-recorded decisions.
  Future<void> _loadStorageUsage() async {
    try {
      final snapshot = await _storage.inventory.snapshot();
      final usedBytes = _storage.inventory.totalBytes(snapshot);
      final settings = await _storage.settings.read();
      final percentUsed = settings.budgetBytes == null
          ? null
          : ((usedBytes * 100) ~/ settings.budgetBytes!);

      final plan = _storage.latestPlan.value;
      final decisions = plan != null
          ? _decisionsFromGroups(_actionableGroups(plan))
          : _decisionsFromLog(await _storage.log.latestPass());

      storageUsage.value = StorageUsageVm(
        usedBytes: usedBytes,
        isMeasured: true,
        percentUsed: percentUsed,
        policySummaryKey: _policySummaryKeyFor(
          mode: settings.mode,
          olderThanDays: settings.olderThanDays,
          maxBytes: settings.maxBytes,
        ),
        warningActive: decisions.isNotEmpty,
      );

      storageExplanation
        ..clear()
        ..addAll(decisions);
      storageExplanationError.value = false;
    } catch (_) {
      storageUsage.value = const StorageUsageVm(
        usedBytes: 0,
        isMeasured: false,
        percentUsed: null,
        policySummaryKey: '',
        warningActive: false,
      );
      storageExplanation.clear();
      storageExplanationError.value = true;
    }
  }

  /// The in-memory path (a pass ran THIS process) — real
  /// `RetentionCandidateGroup`s, most significant (largest bytes) first.
  List<StorageDecisionVm> _decisionsFromGroups(
    List<RetentionCandidateGroup> groups,
  ) {
    final sorted = [...groups]..sort((a, b) => b.bytes.compareTo(a.bytes));
    return [
      for (final group in sorted)
        StorageDecisionVm(
          categoryKey: group.categoryKey,
          bytes: group.bytes,
          reason: group.reason,
          reasonDetail: group.reasonDetail,
        ),
    ];
  }

  /// The durable-log fallback path (F1 fix) — `StorageDecisionLog
  /// .latestPass()`'s rows, reconstructed into the same `StorageDecisionVm`
  /// shape `_decisionsFromGroups` produces, so the view cannot tell which
  /// path fed it. Filters mirror `_actionableGroups`'s own reasoning exactly
  /// (this file's header), applied to a logged row instead of a live
  /// `RetentionCandidateGroup`:
  /// - the zero-candidate sentinel row (`categoryKey: 'none'`,
  ///   `storage_decision_log.dart`'s own convention) is never a category;
  /// - `outcome: applied` means the items are already gone by the time this
  ///   reads — showing them as "Will remove" would describe the past as a
  ///   forecast, so they are excluded;
  /// - `categoryKey: 'relayCache'` is always `RelayEngine`'s, regardless of
  ///   pass or outcome (`RetentionExecutor`'s own invariant 1);
  /// - `categoryKey: 'messages'` logged under a Smart Mode pass
  ///   (`row.mode == StorageMode.smart.name`) is never actionable
  ///   (`OQ-E08-3(a)`, invariant 2) — the SAME two exclusions
  ///   `_actionableGroups` applies to a live plan, read here from the row's
  ///   own `mode`/`categoryKey` columns instead of a `RetentionCandidateGroup
  ///   .kind`, since the log has no `kind` column of its own
  ///   (`storage_tables.dart`'s schema: `mode`/`categoryKey`/`reasonCode`/
  ///   `reasonDetail`/`outcome`, not a `StorageItemKind`).
  /// Every remaining row (a genuine `planned` forecast, or a `skipped` row
  /// for a reason OTHER than the two structural exclusions above — e.g. an
  /// undelivered-message guard — is still real, still-present data the
  /// active policy would act on given the right conditions) is shown.
  List<StorageDecisionVm> _decisionsFromLog(List<StorageDecisionRow> rows) {
    final kept = <StorageDecisionVm>[];
    for (final row in rows) {
      if (row.categoryKey == 'none') continue;
      if (row.outcome == DecisionOutcome.applied.name) continue;
      if (row.categoryKey == 'relayCache') continue;
      if (row.categoryKey == 'messages' && row.mode == StorageMode.smart.name) {
        continue;
      }
      kept.add(
        StorageDecisionVm(
          categoryKey: row.categoryKey,
          bytes: row.bytes,
          reason: RetentionReason.values.byName(row.reasonCode),
          reasonDetail: row.reasonDetail,
        ),
      );
    }
    kept.sort((a, b) => b.bytes.compareTo(a.bytes));
    return kept;
  }

  /// Mirrors `RetentionExecutor.apply`'s own two unconditional invariants
  /// (`retention_executor.dart`'s header) so the "Will remove:" list never
  /// shows a category that will never actually be removed under the active
  /// policy — see this file's header for the full reasoning. Not a new
  /// policy: both exclusions are already-fixed, spec-mandated constants
  /// (`OQ-E08-3(a)`, `E04-B02`'s ownership of relay TTL), read here for
  /// display consistency, never re-scored.
  List<RetentionCandidateGroup> _actionableGroups(RetentionPlan plan) {
    final isSmart = plan.mode == StorageMode.smart.name;
    return [
      for (final group in plan.groups)
        if (group.kind != StorageItemKind.relayPayload &&
            !(isSmart && group.kind == StorageItemKind.message))
          group,
    ];
  }

  /// A machine key (never display copy — the view owns the actual strings,
  /// per this task's "copy from the contract, never from the controller"
  /// rule) naming the active policy plus its real parameter. `smart` reuses
  /// `SmartModeThresholds.ageThresholdDays` — the real value
  /// `SmartModePolicy` scores against, replacing GAP-011's static "10 days"
  /// placeholder with the actual threshold. The two manual modes reuse the
  /// mode names `design/screens/settings-storage.md`'s SS11 already measured
  /// from BRD §19 (this epic's own sibling derived contract), substituting
  /// the user's real parameter for BRD's own "X".
  String _policySummaryKeyFor({
    required String mode,
    required int? olderThanDays,
    required int? maxBytes,
  }) {
    switch (StorageMode.values.byName(mode)) {
      case StorageMode.smart:
        return 'smart:${_storage.smart.thresholds.ageThresholdDays}';
      case StorageMode.olderThanDays:
        return 'olderThanDays:${olderThanDays ?? 0}';
      case StorageMode.overSizeMb:
        final mb = (maxBytes ?? 0) ~/ (1024 * 1024);
        return 'overSizeMb:$mb';
    }
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
