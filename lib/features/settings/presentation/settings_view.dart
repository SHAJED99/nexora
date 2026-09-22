// features/settings/presentation — built against design/screens/settings.md.
// Elements referenced by number below are that contract's "Elements — the
// build checklist" table; the "probe #" comments cite
// design/golden/settings/default@390x844/probe.json's raw element indices,
// since the printed contract table numbers each row as its own element and
// does not surface the untexted wrapper `generic`s that actually carry the
// group fill/border/radius and the icon backdrops. Review finding
// (E02-T03, round 2): the first pass read those wrapper indices as "applies
// to all 8 rows uniformly" instead of recognizing 4 of them as GROUP
// containers (1/2/2/3 rows each) — see `_groups` below. Second consecutive
// UI task to lose an element this way (E02-T02's icon backdrop was the
// first) — worth a design-fidelity lesson entry.
//
// Deviation: the design's "battery_full_alt" glyph has no equivalent in
// Flutter's bundled Material icon font — `Icons.battery_full` is the
// closest available icon and is used in its place (logged here and in the
// task file's §9 Deviations, since it's a glyph-substitution detail rather
// than a missing screen/journey).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.settingsPageBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleBlock(),
                    const SizedBox(height: 16),
                    for (final group in _groups) ...[
                      _MenuGroup(rows: group, controller: controller),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
            _BottomNav(),
          ],
        ),
      ),
    );
  }
}

/// Elements 4-7 (probe #3-7): hub icon, "NEXORA", lock icon — no separate
/// header bar fill in this design (unlike devices.md); everything sits on
/// `settingsPageBg`.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.hub, size: 24, color: NexoraColors.welcomeHeading),
          const SizedBox(width: 8),
          const Text('NEXORA', style: NexoraTextStyles.settingsBrandTitle),
          const Spacer(),
          const Icon(Icons.lock, size: 24, color: NexoraColors.welcomeHeading),
        ],
      ),
    );
  }
}

/// Elements 6-7 (probe #8-9): "Settings" heading + subtitle.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Settings', style: NexoraTextStyles.settingsHeading),
        SizedBox(height: 4),
        Text(
          'Manage your secure connection preferences and device configurations.',
          style: NexoraTextStyles.settingsSubtitle,
        ),
      ],
    );
  }
}

class _RowSpec {
  const _RowSpec({
    required this.row,
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.iconBackdrop,
  });

  /// The closed row identity `openRow` routes on (E15-T11) — never the
  /// title string below, which is copy and may not be routed on (see
  /// `settings_controller.dart`'s own header).
  final SettingsRow row;
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color iconBackdrop;
}

/// The eight menu rows, in the design contract's order (elements 8-11,
/// 12-15, ... 43-46). Icon/backdrop colors read from probe.json elements
/// 12/19/25/32/38/45/51/57 — not reproduced in the printed contract table.
final _rows = <_RowSpec>[
  _RowSpec(
    row: SettingsRow.account,
    icon: Icons.account_circle,
    title: 'Account',
    description: 'Profile, identity keys, linked devices',
    iconColor: NexoraColors.devicesAllowedBlue,
    iconBackdrop: NexoraColors.settingsIconBackdropBlue,
  ),
  _RowSpec(
    row: SettingsRow.privacy,
    icon: Icons.security,
    title: 'Privacy & Security',
    description: 'Encryption protocols, app lock, permissions',
    iconColor: NexoraColors.settingsIconGreen,
    iconBackdrop: NexoraColors.settingsIconBackdropGreen,
  ),
  _RowSpec(
    row: SettingsRow.securityCenter,
    icon: Icons.policy,
    title: 'Security Center',
    description: 'Threat logs, network audits, certificates',
    iconColor: NexoraColors.settingsIconGreen,
    iconBackdrop: NexoraColors.settingsIconBackdropGreen,
  ),
  _RowSpec(
    row: SettingsRow.network,
    icon: Icons.wifi_tethering,
    title: 'Network',
    description: 'Data usage, mesh routing, proxy',
    iconColor: NexoraColors.welcomeHeading,
    iconBackdrop: NexoraColors.settingsIconBackdropViolet,
  ),
  _RowSpec(
    row: SettingsRow.storage,
    icon: Icons.sd_storage,
    title: 'Storage',
    description: 'Local cache, message retention, export',
    iconColor: NexoraColors.welcomeHeading,
    iconBackdrop: NexoraColors.settingsIconBackdropViolet,
  ),
  _RowSpec(
    row: SettingsRow.battery,
    icon: Icons.battery_full, // design glyph: battery_full_alt — see file header deviation note
    title: 'Battery',
    description: 'Background execution, power saving modes',
    iconColor: NexoraColors.settingsIconLightBlue,
    iconBackdrop: NexoraColors.devicesHeaderBg, // rgb(33,49,69) — identical value
  ),
  _RowSpec(
    row: SettingsRow.notifications,
    icon: Icons.notifications,
    title: 'Notifications',
    description: 'Alerts, silent modes, LED behaviors',
    iconColor: NexoraColors.settingsIconLightBlue,
    iconBackdrop: NexoraColors.devicesHeaderBg, // rgb(33,49,69) — identical value
  ),
  _RowSpec(
    row: SettingsRow.about,
    icon: Icons.info,
    title: 'About / Updates',
    description: 'Version 2.4.1, release notes, diagnostic logs',
    iconColor: NexoraColors.settingsIconLightBlue,
    iconBackdrop: NexoraColors.devicesHeaderBg, // rgb(33,49,69) — identical value
  ),
];

/// The design groups the 8 rows into 4 panels of 1/2/2/3 — the fill,
/// 12px radius, and 1px border belong to the GROUP
/// (probe.json elements 9/16/29/42, heights 106/211/191/316 — exactly 1/2/2/3
/// rows tall), not to each row individually. This was dropped in the first
/// pass (review finding, E02-T03): the printed contract table lists each
/// row as its own numbered element, which reads as "8 separate cards" until
/// probe.json's untexted wrapper `generic`s are checked directly.
final _groups = <List<_RowSpec>>[
  [_rows[0]],
  [_rows[1], _rows[2]],
  [_rows[3], _rows[4]],
  [_rows[5], _rows[6], _rows[7]],
];

/// One grouped panel — fill/border/radius on the group (probe elements
/// 9/16/29/42), a hairline divider between rows within the group, rows
/// themselves transparent/unbordered.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.rows, required this.controller});

  final List<_RowSpec> rows;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NexoraColors.settingsRowFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NexoraColors.devicesRowBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: NexoraColors.devicesRowBorder,
              ),
            _MenuRow(spec: rows[i], controller: controller),
          ],
        ],
      ),
    );
  }
}

/// One menu row inside a `_MenuGroup` — no fill/border/radius of its own
/// (those belong to the group). Tapping navigates to the row's own
/// sub-screen: `FR-UI-006` (`IMP-003`) requires every Settings row to
/// navigate and forbids a non-navigating acknowledgement, and `E15` built
/// all eight sub-screens. This comment previously described the original
/// "Coming soon" acknowledgement, which `settings_controller.dart` no
/// longer has.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.spec, required this.controller});

  final _RowSpec spec;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.openRow(spec.row),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: spec.iconBackdrop,
                  shape: BoxShape.circle,
                ),
                child: Icon(spec.icon, size: 24, color: spec.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.title, style: NexoraTextStyles.settingsRowTitle),
                    const SizedBox(height: 2),
                    Text(
                      spec.description,
                      style: NexoraTextStyles.settingsRowDescription,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 24,
                color: NexoraColors.devicesMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elements 48-59 (probe #62-74): Dashboard/Conversations/Devices/Settings.
/// Settings is the active tab (probe #72's filled pill, `onTap: () {}` —
/// re-tapping the already-active tab is a no-op by convention).
///
/// E06-B05: the other three used to ALSO be `onTap: () {}` (copied from
/// `devices_view.dart`'s own identical bug, per this comment's own prior
/// text — "same pattern as devices_view.dart's `_BottomNav`"). That was a
/// real dead end: landing on Settings via the bottom nav left a user
/// unable to reach any other tab without the system back gesture. Found
/// via live two-device on-hardware testing; fixed alongside
/// `devices_view.dart`'s identical bug.
///
/// E15-T11: each `_NavItem` below is now wrapped in `Expanded` — a real,
/// pre-existing `RenderFlex` overflow (183px at the real 390px mobile
/// viewport, "Conversations" being the widest label) was invisible until
/// this task wired `settings` into `test/design/design_probe_test.dart`
/// for the first time (it was never registered there before — genesis's
/// own golden for this screen was captured from the HTML design source,
/// never from a pumped Flutter build). `devices_view.dart`'s own
/// `_BottomNav` already wraps each of its four `_NavItem`s in `Expanded`;
/// this brings `settings_view.dart` in line with that same, already-
/// established pattern. No element, icon, label, order or behaviour
/// changes — only the missing width constraint that was letting the row
/// overflow instead of sharing space evenly, exactly as the design's own
/// four equal-width tabs require. This is the minimal fix needed to make
/// this task's own required `design-verify SCREEN=settings` gate (§7/§9)
/// runnable at all; logged in §9 Deviations as an out-of-band fix to a
/// bug this task's own probe wiring exposed, not one it introduced.
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: NexoraColors.settingsPageBg,
        border: Border(
          top: BorderSide(color: NexoraColors.devicesRowBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(icon: Icons.dashboard, label: 'Dashboard', active: false, onTap: () => Get.toNamed('/dashboard')),
          ),
          Expanded(
            child: _NavItem(icon: Icons.chat, label: 'Conversations', active: false, onTap: () => Get.toNamed('/conversations')),
          ),
          Expanded(
            child: _NavItem(icon: Icons.router, label: 'Devices', active: false, onTap: () => Get.toNamed('/devices')),
          ),
          Expanded(
            child: _NavItem(icon: Icons.settings, label: 'Settings', active: true, onTap: () {}),
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
    final color = active
        ? NexoraColors.welcomeTextAccent
        : NexoraColors.settingsBodyText;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: active
              ? NexoraTextStyles.settingsNavLabelActive
              : NexoraTextStyles.settingsNavLabel,
        ),
      ],
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(active ? 9999 : 8),
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
    );
  }
}
