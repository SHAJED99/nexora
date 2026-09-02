// features/dashboard/presentation — DashboardView (E06-T12). Built against
// design/screens/dashboard.md. Elements referenced by number below are that
// contract's "Elements — the build checklist" table (46 printed rows / 63
// captured in the golden).
//
// Every colour/style below either reuses an existing `NexoraColors`/
// `NexoraTextStyles` constant that already matches the contract's measured
// value exactly, or is a new value measured directly from this contract's
// own token table and declared locally in THIS file — `lib/core/design/
// tokens.dart` is intentionally NOT in this task's `files:` fence, the same
// precedent `conversations_view.dart`/`chat_view.dart` already established.
//
// Approved gaps this screen renders knowingly-incomplete or data-driven, per
// `design/gaps.md`:
// - GAP-011/GAP-025/GAP-026 (E08-T08) — the Local Storage card is now fed
//   real figures. `45% used` (element 16) has no denominator
//   (`storage_policy_settings.budget_bytes` is NULL by default, `OQ-E08-1`),
//   so per `GAP-026`'s answered fork (option (c) for this card) it renders
//   the real measured byte total instead — `N MB used`, never a fabricated
//   percentage — a disclosed deviation from the design's measured `45% used`
//   string. `Smart Mode - Older than 10 days` (element 18) becomes the
//   active policy's real summary (`_policySummaryText`), another disclosed
//   copy finding per `GAP-011`'s approved resolution. The card is a tap
//   target (no new glyph — `GAP-012`'s precedent) that toggles `GAP-025`'s
//   derived expanded state in place; that state is not part of the golden
//   and is invisible to `make design-verify` until a second golden is
//   extracted (`dashboard.md`'s own header on the derived section). No
//   "Clean Now", no confirmation, no delete affordance anywhere on this
//   card, not even disabled (`FR-STORE-006`/`EARS-STORE-2`) — tapping only
//   ever flips `DashboardController.toggleStorageExpansion`'s local flag.
// - GAP-012 — the whole Network Status card is the tap target for
//   `/devices`, FR-UI-004's "one tap away" detail surface.
// - GAP-013 — three data-driven connectivity readings (`Connected`,
//   `No peers nearby`, `No route to this peer`); `Latency`'s value is the
//   real most-recent measurement or the disclosed placeholder "Not measured
//   yet", never `24ms`.
// - GAP-003 (reused from Devices/Conversations) — no display-name/avatar
//   data source pre-E04: every row uses `MS`-style initials, never the
//   design's image treatment.
// - GAP-009 (reused from Chat) — the delivery-tick glyph mapping for
//   outgoing rows is read from `ConversationTile.lastMessageState` and
//   rendered with the SAME icon/colour function `chat_view.dart`'s
//   `_tickIconFor`/`_tickColorFor` already establishes (duplicated here per
//   Dart's privacy model — see `_tickIconFor` below — never redefined with
//   different semantics).
//
// Every interactive element below is `InkWell`/`Material` — never
// `Listener`. T10's independent reviewer found that `Listener` never enters
// the gesture arena (a scroll/drag would fire as a tap) and contributes zero
// accessibility semantics; T11 did not repeat it and neither does this file,
// even where it costs design-fidelity gate score against T01's
// `flutter_probe_dumper.dart` `_isInteractive`/`insideInteractive`
// icon-swallowing limitation (documented, not worked around, in this task's
// Run log).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/core/storage/retention_plan.dart' show RetentionReason;
import 'package:nexora/features/conversations/presentation/conversations_controller.dart'
    show ConversationTile;
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'dashboard_controller.dart';

/// Network-status/local-storage card fill — rgb(248, 249, 255), == the
/// measured value of `NexoraColors.welcomeButtonBg`, reused by value since
/// `tokens.dart` is out of this task's `files:` fence.
const _cardFill = Color(0xFFF8F9FF);

/// Recent-conversation row fill — rgb(239, 244, 255), == `NexoraColors
/// .loginBg`'s measured value.
const _rowFill = Color(0xFFEFF4FF);

/// Card/row border — rgba(11, 28, 48, 0.1), measured on this screen's own
/// contract (5 uses: both cards plus header/nav borders).
const _cardBorder = Color(0x1A0B1C30);

/// Avatar-slot backdrop circle behind initials (GAP-003) — rgb(211, 228,
/// 254), == `NexoraColors.welcomeTextPrimary`'s measured value, reused by
/// value for the same reason as `_cardFill` above.
const _avatarBackdrop = Color(0xFFD3E4FE);

/// `Encryption` label colour — rgb(0, 83, 56), not matched by any existing
/// `NexoraColors` constant.
const _encryptionLabelColor = Color(0xFF005338);

/// The connected-state dot — rgb(0, 101, 145), not matched by any existing
/// `NexoraColors` constant. GAP-013's non-connected readings reuse
/// `NexoraColors.loginBody` (== the contract's own muted rgb(70, 69, 85)
/// token) instead of a second new colour.
const _connectedDotColor = Color(0xFF006591);

const _sectionHeadingStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginHeading,
);

const _cardSubtitleStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBody,
);

const _cardValueStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBody,
);

const _readingTextStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginHeading,
);

const _encryptionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: _encryptionLabelColor,
);

const _timestampStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBody,
);

const _navInactiveStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBody,
);

const _navActiveStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.welcomeTextAccent,
);

/// GAP-025 DX2 — "the recent-conversation row title" style, as the derived
/// contract literally measures it: `14px` `w500` `rgb(11, 28, 48)`. Distinct
/// from `NexoraTextStyles.devicesDeviceName` (16px) which this screen's own
/// Recent Conversations rows use — the contract cites the row-title
/// *treatment*, not that exact token, so this is declared locally at the
/// size the contract actually measures.
const _storageCategoryLabelStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginHeading,
);

/// GAP-025 DX3 — "the timestamp treatment" (elements 22/27/32) plus
/// `JetBrains Mono`, per the contract's own citation. No font asset is
/// bundled for `JetBrains Mono` anywhere in this project (`pubspec.yaml`
/// carries no `fonts:` section) — declaring the family name is honest intent
/// per the contract's citation; Flutter falls back to the platform default
/// when the family is unavailable, matching how every other text style in
/// this file already renders.
const _storageByteStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBody,
  fontFamily: 'JetBrains Mono',
);

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardFill,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: Obx(() {
                if (controller.errorMessage.value.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        controller.errorMessage.value,
                        style: NexoraTextStyles.devicesSectionSubtitle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  children: [
                    _NetworkStatusCard(controller: controller),
                    const SizedBox(height: 16),
                    _LocalStorageCard(controller: controller),
                    const SizedBox(height: 20),
                    const Text(
                      'Recent Conversations',
                      style: _sectionHeadingStyle,
                    ),
                    const SizedBox(height: 12),
                    _RecentConversations(controller: controller),
                  ],
                );
              }),
            ),
            const _BottomNav(),
          ],
        ),
      ),
    );
  }
}

/// Elements 1-4: `hub` icon + "NEXORA", and a round icon button whose
/// destination the design does not name (no design/gaps.md entry covers it,
/// and this task's own `files:` fence does not cover a new destination) —
/// rendered present and tappable with the same "not yet available"
/// affordance GAP-004/GAP-010 already established for an undefined action,
/// rather than inventing a destination.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _cardFill,
        border: Border.fromBorderSide(BorderSide(color: _cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(Icons.hub, size: 24, color: NexoraColors.loginBrand),
            ),
          ),
          const Text(
            'NEXORA',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: NexoraColors.loginBrand,
            ),
          ),
          const Spacer(),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => Get.snackbar(
                'Not available',
                'This isn\'t available yet.',
                snackPosition: SnackPosition.BOTTOM,
              ),
              borderRadius: BorderRadius.circular(9999),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    Icons.lock,
                    size: 24,
                    color: NexoraColors.loginBrand,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Elements 5-14: the whole card is the FR-UI-004/GAP-012 tap target for
/// `/devices`.
class _NetworkStatusCard extends StatelessWidget {
  const _NetworkStatusCard({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: controller.openNetworkDetail,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: Obx(() {
            final vm = controller.networkStatus.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Network Status', style: _sectionHeadingStyle),
                const Text(
                  'Primary Node Connection',
                  style: _cardSubtitleStyle,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Element 7's literal glyph is "circle" (a Material
                    // Symbols icon), not a plain decorated box — using
                    // `Icons.circle` here (rather than a `BoxDecoration`
                    // circle) matches the design's own element shape and
                    // reads its colour as foreground, the same way the
                    // golden capture does.
                    Icon(Icons.circle, size: 16, color: _dotColorFor(vm.reading)),
                    const SizedBox(width: 8),
                    Text(_readingLabelFor(vm.reading), style: _readingTextStyle),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.lock,
                      size: 18,
                      color: _encryptionLabelColor,
                    ),
                    const SizedBox(width: 6),
                    const Text('Encryption', style: _encryptionLabelStyle),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        vm.encryptionSecure ? 'Secure' : 'Not secure',
                        style: _cardValueStyle,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.speed,
                      size: 18,
                      color: NexoraColors.loginBody,
                    ),
                    const SizedBox(width: 6),
                    const Text('Latency', style: _cardSubtitleStyle),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        vm.latencyMs == null
                            ? 'Not measured yet'
                            : '${vm.latencyMs}ms',
                        style: _cardValueStyle,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// GAP-013's approved copy: "Connected" (as measured), "No peers nearby",
/// "No route to this peer".
String _readingLabelFor(ConnectivityReading reading) => switch (reading) {
      ConnectivityReading.connected => 'Connected',
      ConnectivityReading.noPeers => 'No peers nearby',
      ConnectivityReading.noRoute => 'No route to this peer',
    };

/// GAP-013: the connected dot uses the contract's own measured colour; both
/// non-connected readings reuse the existing muted `loginBody` token — no
/// new colour for them.
Color _dotColorFor(ConnectivityReading reading) =>
    reading == ConnectivityReading.connected
        ? _connectedDotColor
        : NexoraColors.loginBody;

/// Elements 15-18 (`GAP-011`/`GAP-026` collapsed) + the derived
/// `warning-expanded` state (`GAP-025`, `FR-STORE-007`). The whole card is
/// the tap target that toggles the expansion in place — no new glyph is
/// drawn, matching `GAP-012`'s already-established precedent on this same
/// screen (`dashboard.md`'s own §Derived state: "no expand/collapse glyph is
/// drawn"). **No "Clean Now", no apply-now, no confirmation, no delete
/// affordance anywhere in this widget, not even disabled**
/// (`FR-STORE-006`/`EARS-STORE-2`) — the only `onTap` here calls
/// `controller.toggleStorageExpansion`, which flips a local flag and nothing
/// else (see that method's own doc comment).
class _LocalStorageCard extends StatelessWidget {
  const _LocalStorageCard({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: controller.toggleStorageExpansion,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Local Storage', style: _sectionHeadingStyle),
              const SizedBox(height: 8),
              Obx(() {
                final vm = controller.storageUsage.value;
                return Text(
                  !vm.isMeasured
                      ? 'Not yet measured'
                      : (vm.percentUsed != null
                          ? '${vm.percentUsed}% used'
                          : '${_formatMb(vm.usedBytes)} MB used'),
                  style: _cardValueStyle,
                );
              }),
              const SizedBox(height: 8),
              Obx(() {
                final vm = controller.storageUsage.value;
                return Row(
                  children: [
                    if (vm.warningActive) ...[
                      const Icon(
                        Icons.warning,
                        size: 18,
                        color: NexoraColors.loginBody,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        _policySummaryText(vm.policySummaryKey),
                        style: _cardSubtitleStyle,
                      ),
                    ),
                  ],
                );
              }),
              Obx(() {
                if (!controller.storageExpanded.value) {
                  return const SizedBox.shrink();
                }
                return _StorageExplanation(controller: controller);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// `GAP-025`'s derived expansion body (DX1-DX8). Reads-only:
/// `DashboardController.storageExplanation`/`.storageExpanded` are both
/// populated/toggled without ever running, applying or scheduling a
/// retention pass (this file's header, `EARS-STORE-2`).
class _StorageExplanation extends StatelessWidget {
  const _StorageExplanation({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.storageExplanationError.value) {
        return const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            "Couldn't read local storage. Try again.",
            style: NexoraTextStyles.devicesSectionSubtitle,
            textAlign: TextAlign.center,
          ),
        );
      }
      final decisions = controller.storageExplanation;
      if (decisions.isEmpty) {
        // GAP-025 DX7 — the expected default reading (this file's header
        // and `dashboard_controller.dart`'s own filtering reasoning), not a
        // rare edge case: replaces DX1-DX6 when there is nothing actionable
        // to report, or no pass has run yet.
        return const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Nothing to remove right now.',
            style: NexoraTextStyles.devicesSectionSubtitle,
            textAlign: TextAlign.center,
          ),
        );
      }
      final totalBytes = decisions.fold<int>(0, (sum, d) => sum + d.bytes);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Will remove:', style: _cardSubtitleStyle),
            const SizedBox(height: 8),
            for (var i = 0; i < decisions.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _StorageDecisionRow(decision: decisions[i]),
            ],
            const SizedBox(height: 12),
            const Text('Why:', style: _cardSubtitleStyle),
            const SizedBox(height: 4),
            Text(
              'Removing these would free up ${_formatMb(totalBytes)} MB.',
              style: NexoraTextStyles.devicesSectionSubtitle,
            ),
          ],
        ),
      );
    });
  }
}

class _StorageDecisionRow extends StatelessWidget {
  const _StorageDecisionRow({required this.decision});

  final StorageDecisionVm decision;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _categoryLabelFor(decision.categoryKey),
            style: _storageCategoryLabelStyle,
          ),
        ),
        const SizedBox(width: 8),
        Text('${_formatMb(decision.bytes)} MB', style: _storageByteStyle),
        const SizedBox(width: 8),
        Text(
          _reasonTextFor(decision.reason, decision.reasonDetail),
          style: _cardSubtitleStyle,
        ),
      ],
    );
  }
}

/// GAP-025's proposed category labels — "no BRD source, the BRD's worked
/// example is media only" (dashboard.md §Copy). `messages`/`databaseFile`
/// are the only two `categoryKey`s this build's policies can ever produce
/// (`smart_mode_policy.dart`/`manual_policy.dart`'s shared
/// `_categoryKeyFor`); any other key falls back to itself rather than a
/// blank label, since a category with no producer in this build should never
/// silently disappear from an explanation surface (`FR-STORE-007`).
String _categoryLabelFor(String categoryKey) => switch (categoryKey) {
      'messages' => 'Messages',
      'databaseFile' => 'Database file',
      _ => categoryKey,
    };

/// GAP-025's reason copy — `Older than N days` / `Over the size limit` are
/// the contract's own format strings; `Rarely accessed` / `No longer
/// required` are BRD §20/§22's verbatim reason strings (dashboard.md
/// §Copy). `storagePressure` has no approved copy yet (`OQ-E08-4`'s
/// neighbourhood, dashboard.md §Open 1) — reported honestly rather than
/// invented, since `budget_bytes` is NULL by default and this branch is not
/// reachable in this build's shipped configuration.
String _reasonTextFor(RetentionReason reason, String? reasonDetail) =>
    switch (reason) {
      RetentionReason.olderThan => 'Older than ${reasonDetail ?? '0'} days',
      RetentionReason.rarelyAccessed => 'Rarely accessed',
      RetentionReason.noLongerRequired => 'No longer required',
      RetentionReason.overSizeLimit => 'Over the size limit',
      RetentionReason.storagePressure => 'Storage running low',
    };

/// `dashboard.md` element 18's `<Mode> - <parameter>` FORMAT contract
/// (§Copy: "the format is the contract, the number is data") —
/// `DashboardController._policySummaryKeyFor`'s machine key is parsed here so
/// the actual copy lives in the view, never the controller. `Smart Mode -
/// Older than N days` keeps the design's own measured mode word and shape
/// (`GAP-011`'s resolution); the two manual modes reuse
/// `design/screens/settings-storage.md` SS11's own BRD-§19-verbatim mode
/// names (this epic's sibling derived contract), substituting the user's
/// real parameter for BRD's own "X" placeholder.
String _policySummaryText(String policySummaryKey) {
  final parts = policySummaryKey.split(':');
  if (parts.length != 2) return '';
  final mode = parts[0];
  final parameter = parts[1];
  return switch (mode) {
    'smart' => 'Smart Mode - Older than $parameter days',
    'olderThanDays' => 'Delete data older than $parameter days',
    'overSizeMb' => 'Delete old data when storage exceeds $parameter MB',
    _ => '',
  };
}

/// Binary MiB, matching `StorageSettingsRepository.minMaxBytes`'s own
/// established "1 MiB = 1,048,576 bytes" conversion (that file's own header:
/// "the one and only conversion point ... never convert twice") — this is
/// the one further MB-facing display conversion that file's own header
/// anticipates a UI task would need, applied consistently rather than
/// re-deriving a second convention. Never renders a negative or fabricated
/// value; a non-zero byte count that rounds to 0 MB shows `<1` rather than
/// `0`, so a genuinely non-empty class never reads as nothing.
String _formatMb(int bytes) {
  if (bytes <= 0) return '0';
  final mb = bytes / (1024 * 1024);
  final rounded = mb.round();
  return rounded < 1 ? '<1' : '$rounded';
}

/// Elements 19-34: heading + loading / empty / real rows from the shared
/// `ConversationRepository.watchConversations()` read model (task §2/§6 —
/// the SAME read model and the SAME `ConversationTile` T10's Conversations
/// screen uses). Reuses GAP-007's approved empty treatment rather than a
/// second one (task §5).
class _RecentConversations extends StatelessWidget {
  const _RecentConversations({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.loading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final tiles = controller.recent;
      if (tiles.isEmpty) {
        // GAP-007's already-approved empty treatment, reused rather than a
        // second, diverging empty state (task §5).
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No conversations yet',
              style: NexoraTextStyles.devicesSectionSubtitle,
            ),
          ),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _RecentConversationRow(tile: tiles[i]),
          ],
        ],
      );
    });
  }
}

class _RecentConversationRow extends StatelessWidget {
  const _RecentConversationRow({required this.tile});

  final ConversationTile tile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _rowFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => Get.toNamed('/chat/${tile.conversationId}'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: NexoraColors.devicesRowBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _avatarBackdrop,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  tile.initials,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: NexoraColors.loginBrand,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tile.displayName,
                            style: NexoraTextStyles.devicesDeviceName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_relativeTime(tile.lastMessageAt), style: _timestampStyle),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _RecentRowStatusLine(tile: tile),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elements 23-24/28-29/33-34's line: a delivery tick (mine only, GAP-009's
/// mapping) + preview text — except a genuinely `Queued` own message, which
/// the design draws with its own fixed copy (element 34) instead of a
/// preview, exactly as measured.
class _RecentRowStatusLine extends StatelessWidget {
  const _RecentRowStatusLine({required this.tile});

  final ConversationTile tile;

  @override
  Widget build(BuildContext context) {
    final isMineQueued = tile.lastMessageIsMine &&
        tile.lastMessageState == DeliveryState.queued;
    return Row(
      children: [
        if (tile.lastMessageIsMine) ...[
          Icon(
            _tickIconFor(tile.lastMessageState),
            size: 14,
            color: _tickColorFor(tile.lastMessageState),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            isMineQueued
                ? 'Message queued — will send when connected.'
                : (tile.preview ?? ''),
            style: NexoraTextStyles.devicesSectionSubtitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// GAP-009's approved glyph mapping, read from the SAME `DeliveryState`
/// `ConversationTile.lastMessageState` already carries — the exact function
/// `chat_view.dart`'s `_tickIconFor`/`_tickColorFor` implements, duplicated
/// here per Dart's privacy model (this file's header) rather than defined a
/// second, potentially-diverging way (task §6's named risk).
IconData _tickIconFor(DeliveryState state) => switch (state) {
      DeliveryState.queued => Icons.radio_button_unchecked,
      DeliveryState.sent || DeliveryState.accepted || DeliveryState.stored =>
        Icons.check,
      DeliveryState.delivered => Icons.done_all,
      DeliveryState.read => Icons.done_all,
      DeliveryState.failed => Icons.error_outline,
    };

Color _tickColorFor(DeliveryState state) => state == DeliveryState.read
    ? NexoraColors.devicesTrustedGreen
    : NexoraColors.loginBody;

/// Elements 35-46: Dashboard/Conversations/Devices/Settings — Dashboard is
/// the active tab.
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _cardFill,
        border: Border.fromBorderSide(BorderSide(color: _cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              active: true,
              onTap: () {},
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.chat,
              label: 'Conversations',
              active: false,
              onTap: () => Get.toNamed('/conversations'),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.router,
              label: 'Devices',
              active: false,
              onTap: () => Get.toNamed('/devices'),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.settings,
              label: 'Settings',
              active: false,
              onTap: () => Get.toNamed('/settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? NexoraColors.welcomeTextAccent : NexoraColors.loginBody;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 2),
        Text(label, style: active ? _navActiveStyle : _navInactiveStyle),
      ],
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: active
              ? BoxDecoration(
                  color: NexoraColors.devicesActiveNavBg,
                  borderRadius: BorderRadius.circular(9999),
                )
              : null,
          child: content,
        ),
      ),
    );
  }
}

/// "12:45" (today) / "Yesterday" / "Oct 12" (older) — same three formats
/// `conversations_view.dart`'s own `_relativeTime`/`_formatClock` already
/// implement, duplicated here per Dart's privacy model (this file's header),
/// without a new `intl` dependency (rule 3 — none added here).
String _relativeTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final diffDays = today.difference(that).inDays;
  if (diffDays == 0) return _formatClock(dt);
  if (diffDays == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
