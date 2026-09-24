// features/conversations/presentation — built against
// design/screens/conversations.md. Elements referenced by number below are
// that contract's "Elements — the build checklist" table (45 rows).
//
// `design/thresholds.yaml` and the contract itself are unchanged (rule 2)
// — every colour/style below either reuses an existing `NexoraColors`/
// `NexoraTextStyles` constant that already matches the contract's measured
// value exactly, or is a new value measured directly from this contract's
// own token table and declared locally in THIS file. `lib/core/design/
// tokens.dart` is intentionally NOT in this task's `files:` fence (see the
// task frontmatter) — adding shared tokens there is a later screen's
// housekeeping, not a reason to touch a file outside this task's contract.
//
// Approved gaps this screen renders knowingly-incomplete, per
// `design/gaps.md`:
// - GAP-006 — the `Groups` heading (element 21) stays unconditionally, in
//   BOTH the data and the empty state (rule 2 / design-fidelity rule 3 —
//   never delete a measured element to satisfy the data layer). E07-T08
//   closes this gap's "rows deferred to E07" clause: the Groups section now
//   renders real rows (elements 22-33) when `controller.groups` is
//   non-empty, and GAP-006's own approved "No groups yet" copy otherwise.
// - GAP-007 — the Personal section shows "No conversations yet" instead of
//   the design's two example rows when there are none.
// - GAP-003 (reused from the Devices screen) — there is no avatar-image or
//   display-name data source pre-E04, so every row uses the `MS`-style
//   initials treatment (element 15's shape), never the image treatment
//   (element 9) — the task's own §3 names this explicitly. The Groups
//   section inherits the same absence for its per-row leading glyph: no
//   per-group connectivity/route signal exists anywhere in this
//   projection, so `conversations_controller.dart`'s `GroupRowViewModel`
//   documents rendering `Icons.dns` uniformly rather than fabricating the
//   design's two distinct leading-glyph states (`dns`/`group_off`) from no
//   data, and never rendering the optional `cloud_off` glyph at all for the
//   same reason (E07-T08 §9 Deviations).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'conversations_controller.dart';

/// Search-field / row-card fill — rgb(229, 238, 255), measured on this
/// screen's own contract (5 uses: the search field plus each populated
/// row's card). Not the same value as any existing `NexoraColors` constant.
const _fieldAndRowFill = Color(0xFFE5EEFF);

/// `Personal`/`Groups` section-heading colour — rgb(234, 241, 255), which is
/// exactly `NexoraColors.settingsHeadingText`'s measured value, reused here
/// by value rather than by name since `tokens.dart` is out of this task's
/// `files:` fence.
const _sectionHeadingColor = Color(0xFFEAF1FF);

/// Each row's own card border is rgba(199, 196, 216, 0.1) — the SAME value
/// as `NexoraColors.devicesRowBorder`, confirmed against this screen's own
/// golden probe (`design/golden/conversations/default@390x844/probe.json`).
/// Reused by value below since `tokens.dart` is out of this task's `files:`
/// fence.
///
/// The avatar-slot backdrop circle behind initials (a 48×48 `radius:9999px`
/// div the golden probe carries but the printed contract table omits,
/// like several other structural wrapper divs) is rgb(203, 219, 245).
const _rowBorder = Color(0x1AC7C4D8);
const _avatarBackdrop = Color(0xFFCBDBF5);
const _headerBorder = Color(0x1AC7C4D8);

/// A group row's leading glyph colour — rgb(0, 70, 102), the `dns` example
/// row's measured colour (element 22). Used uniformly per
/// `GroupRowViewModel.connectivityIcon`'s own doc comment (no per-group
/// connectivity signal exists to pick between the design's two example
/// states).
const _groupIconColor = Color(0xFF004666);

/// Element 26's sender-name prefix ("David Chen:") — 14px w500
/// rgb(11, 28, 48), i.e. `NexoraColors.loginHeading` by value.
const _senderPrefixStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginHeading,
);

const _sectionHeadingStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w500,
  color: _sectionHeadingColor,
);

const _timestampStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBody,
);

const _searchHintStyle = TextStyle(
  fontSize: 14,
  color: NexoraColors.devicesMuted,
);

const _navInactiveStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.devicesMuted,
);

const _navActiveStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Colors.white,
);

class ConversationsView extends GetView<ConversationsController> {
  const ConversationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.settingsPageBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  _SearchField(controller: controller),
                  const SizedBox(height: 20),
                  const Text('Personal', style: _sectionHeadingStyle),
                  const SizedBox(height: 12),
                  _PersonalSection(controller: controller),
                  const SizedBox(height: 20),
                  const Text('Groups', style: _sectionHeadingStyle),
                  const SizedBox(height: 12),
                  // GAP-006 — heading kept unconditionally (above); the
                  // empty-state copy or the real rows render below,
                  // per E07-T08.
                  _GroupsSection(controller: controller),
                ],
              ),
            ),
            _BottomNav(),
          ],
        ),
      ),
    );
  }
}

/// Elements 1-3: `hub` icon + "NEXORA", element 4-5: the `search` action,
/// plus E07-T16's create-group button (approved 2026-09-25, not in the
/// measured table -- see the inline note below).
///
/// Built with `InkWell` (correct gesture-arena participation + semantics —
/// see the task's Run log / Deviation notes for why an earlier `Listener`
/// draft was reverted). If the design-fidelity probe's tap-target handling
/// drops nested icon/text elements inside a real `InkWell`, that is a T01
/// probe defect (flagged in the Run log for the orchestrator), not something
/// this file works around by reshaping the widget tree.
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final ConversationsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NexoraColors.devicesHeaderBg,
        border: Border.fromBorderSide(BorderSide(color: _headerBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.hub,
                size: 24,
                color: NexoraColors.welcomeHeading,
              ),
            ),
          ),
          const Text('NEXORA', style: NexoraTextStyles.devicesBrandTitle),
          const Spacer(),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => controller.searchFieldFocusNode.requestFocus(),
              borderRadius: BorderRadius.circular(9999),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    Icons.search,
                    size: 24,
                    color: NexoraColors.welcomeHeading,
                  ),
                ),
              ),
            ),
          ),
          // E07-T16 — the create-group entry point. NOT in this screen's
          // measured element table, and deliberately not added to it: the
          // human approved the affordance on 2026-09-25 with the explicit
          // instruction to treat the measured delta honestly rather than
          // edit the contract to conceal it. `design-verify SCREEN=
          // conversations` reports it as an extra element; the finding
          // traces to `design/screens/group-create.md` §Open / GAP-018.
          //
          // Every value here is already in use on this screen: the 48x48
          // r9999px button shape of elements 1/4, and the 24px
          // `rgb(195, 192, 255)` glyph treatment of elements 2/5. `add` is
          // an existing glyph (chat.md element 27). Appended AFTER search so
          // elements 4-5 keep their measured positions.
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: controller.openCreateGroup,
              borderRadius: BorderRadius.circular(9999),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    Icons.add,
                    size: 24,
                    color: NexoraColors.welcomeHeading,
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

/// Element 6-7: the search icon + "Search conversations..." field.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final ConversationsController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: controller.searchFieldFocusNode,
      onChanged: controller.search,
      style: const TextStyle(fontSize: 14, color: NexoraColors.loginHeading),
      decoration: InputDecoration(
        hintText: 'Search conversations...',
        hintStyle: _searchHintStyle,
        prefixIcon: const Icon(
          Icons.search,
          size: 24,
          color: NexoraColors.devicesMuted,
        ),
        filled: true,
        fillColor: _fieldAndRowFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Elements 8-20: the "Personal" heading's content — loading / error / empty
/// (GAP-007) / the real rows from `watchConversations()`.
class _PersonalSection extends StatelessWidget {
  const _PersonalSection({required this.controller});

  final ConversationsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.loading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (controller.errorMessage.value.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              controller.errorMessage.value,
              style: NexoraTextStyles.devicesSectionSubtitle,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      final tiles = controller.conversations;
      if (tiles.isEmpty) {
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
            _ConversationRow(tile: tiles[i], controller: controller),
          ],
        ],
      );
    });
  }
}

/// One conversation row — elements 9-15 (or 16-20)'s structure: initials
/// (GAP-003), name, timestamp, delivery tick (mine only), preview, lock.
///
/// Tap handled via `InkWell` inside a transparent `Material` — real
/// gesture-arena participation (a scroll/drag no longer fires this as a
/// tap) and real semantics (`tap` action + `isButton`). See the task's Run
/// log for why an earlier `Listener` draft was reverted.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.tile, required this.controller});

  final ConversationTile tile;
  final ConversationsController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => controller.openConversation(tile.conversationId),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _fieldAndRowFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _rowBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                // `BorderRadius.circular(9999)` rather than `shape:
                // BoxShape.circle` — both render identically for a square box,
                // but the probe's decoration reader (T01) only reports the
                // literal `borderRadius` value for a non-circle shape, so this
                // is what lets the captured radius match the contract's own
                // "9999px" convention for a fully-round element.
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
                        Text(
                          _relativeTime(tile.lastMessageAt),
                          style: _timestampStyle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (tile.lastMessageIsMine) ...[
                          Icon(
                            tickIconFor(tile.lastMessageState),
                            size: 16,
                            color: tickColorFor(tile.lastMessageState),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            tile.preview ?? '',
                            style: NexoraTextStyles.devicesSectionSubtitle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock,
                          size: 20,
                          color: NexoraColors.welcomeHeading,
                        ),
                      ],
                    ),
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

/// Elements 22-33: the "Groups" heading's content — GAP-006's approved empty
/// treatment, or the real per-group rows built by
/// `ConversationsController._buildGroupRow`.
class _GroupsSection extends StatelessWidget {
  const _GroupsSection({required this.controller});

  final ConversationsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.groups;
      if (rows.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No groups yet',
              style: NexoraTextStyles.devicesSectionSubtitle,
            ),
          ),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _GroupRow(row: rows[i], controller: controller),
          ],
        ],
      );
    });
  }
}

/// One group row — elements 22-27 (or 28-33)'s structure: leading
/// connectivity glyph (`GroupRowViewModel.connectivityIcon`'s own doc
/// comment — uniformly `Icons.dns`, no per-group signal exists), name,
/// timestamp, delivery tick (GAP-009's shared mapping, reused via
/// `tickIconFor` from `conversations_controller.dart` — never a second
/// `switch`), optional sender-name prefix, preview, trailing lock.
///
/// Tap handled via `InkWell` inside a transparent `Material`, exactly like
/// `_ConversationRow` — real gesture-arena participation and real semantics
/// (design-fidelity Rule 5 / L-frontend-001: never a raw `Listener` to score
/// better against the probe).
///
/// **Non-navigating (E07-B01).** `controller.openGroup` acknowledges the tap
/// with a SnackBar instead of routing to `/chat/:id` — the destination
/// screen's `ChatController` is 1:1-only (E06-T11) and cannot render or send
/// a group conversation (GAP-020, gated on `OQ-E07-13`). The row itself is
/// unchanged from the design contract — same fill, border, icon, text — only
/// the tap's destination differs, so no design element is added or removed.
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.row, required this.controller});

  final GroupRowViewModel row;
  final ConversationsController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => controller.openGroup(row.name),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _fieldAndRowFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _rowBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: Icon(
                    row.connectivityIcon,
                    size: 24,
                    color: _groupIconColor,
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
                            row.name,
                            style: NexoraTextStyles.devicesDeviceName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(row.timestampLabel, style: _timestampStyle),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          row.deliveryIcon,
                          size: 16,
                          color: NexoraColors.devicesMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (row.senderPrefix != null)
                                  TextSpan(
                                    text: '${row.senderPrefix} ',
                                    style: _senderPrefixStyle,
                                  ),
                                TextSpan(
                                  text: row.preview,
                                  style: NexoraTextStyles.devicesSectionSubtitle,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock,
                          size: 20,
                          color: NexoraColors.welcomeHeading,
                        ),
                      ],
                    ),
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

/// Elements 34-45: Dashboard/Conversations/Devices/Settings. Conversations
/// is the active tab (element 37's filled pill); Dashboard's own route
/// (`/dashboard`, T12) is not wired yet — `Get.toNamed` on it is a
/// documented GetX no-op until then (task §3's own precedent for `/chat`).
class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NexoraColors.devicesHeaderBg,
        border: Border.fromBorderSide(BorderSide(color: _headerBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              active: false,
              onTap: () => Get.toNamed('/dashboard'),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.chat,
              label: 'Conversations',
              active: true,
              onTap: () {},
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
    final color = active ? Colors.white : NexoraColors.devicesMuted;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 2),
        Text(label, style: active ? _navActiveStyle : _navInactiveStyle),
      ],
    );
    // InkWell inside a transparent Material — real gesture-arena
    // participation (drag-away-to-cancel works) and real semantics (tap
    // action + isButton). See the task's Run log for why an earlier
    // `Listener` draft was reverted.
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

/// "10:42 AM" (today) / "Yesterday" / "Oct 12" (older) — the three example
/// formats the contract's own rows and its Groups section draw, without a
/// new `intl` dependency (rule 3 — none is added here).
String _relativeTime(DateTime dt) {
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
