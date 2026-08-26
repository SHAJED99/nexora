// features/settings/presentation — built against design/screens/settings.md.
// Elements referenced by number below are that contract's "Elements — the
// build checklist" table; the "probe #" comments cite
// design/golden/settings/default@390x844/probe.json's raw element indices
// where the printed contract table dropped a fill (row container / icon
// backdrop) the same way design/screens/devices.md's did for its row icon
// backdrops (see design/gaps.md and the E02-T02 review that caught it).
//
// Deviation: the design's "battery_full_alt" glyph has no equivalent in
// Flutter's bundled Material icon font — `Icons.battery_full` is the
// closest available icon and is used in its place (logged here, not in
// design/gaps.md, since it's a glyph-substitution detail rather than a
// missing screen/journey).
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
                    for (final row in _rows) ...[
                      _MenuRow(spec: row, controller: controller),
                      const SizedBox(height: 12),
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
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.iconBackdrop,
  });

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
    icon: Icons.account_circle,
    title: 'Account',
    description: 'Profile, identity keys, linked devices',
    iconColor: NexoraColors.devicesAllowedBlue,
    iconBackdrop: NexoraColors.settingsIconBackdropBlue,
  ),
  _RowSpec(
    icon: Icons.security,
    title: 'Privacy & Security',
    description: 'Encryption protocols, app lock, permissions',
    iconColor: NexoraColors.settingsIconGreen,
    iconBackdrop: NexoraColors.settingsIconBackdropGreen,
  ),
  _RowSpec(
    icon: Icons.policy,
    title: 'Security Center',
    description: 'Threat logs, network audits, certificates',
    iconColor: NexoraColors.settingsIconGreen,
    iconBackdrop: NexoraColors.settingsIconBackdropGreen,
  ),
  _RowSpec(
    icon: Icons.wifi_tethering,
    title: 'Network',
    description: 'Data usage, mesh routing, proxy',
    iconColor: NexoraColors.welcomeHeading,
    iconBackdrop: NexoraColors.settingsIconBackdropViolet,
  ),
  _RowSpec(
    icon: Icons.sd_storage,
    title: 'Storage',
    description: 'Local cache, message retention, export',
    iconColor: NexoraColors.welcomeHeading,
    iconBackdrop: NexoraColors.settingsIconBackdropViolet,
  ),
  _RowSpec(
    icon: Icons.battery_full, // design glyph: battery_full_alt — see file header deviation note
    title: 'Battery',
    description: 'Background execution, power saving modes',
    iconColor: NexoraColors.settingsIconLightBlue,
    iconBackdrop: NexoraColors.devicesHeaderBg, // rgb(33,49,69) — identical value
  ),
  _RowSpec(
    icon: Icons.notifications,
    title: 'Notifications',
    description: 'Alerts, silent modes, LED behaviors',
    iconColor: NexoraColors.settingsIconLightBlue,
    iconBackdrop: NexoraColors.devicesHeaderBg, // rgb(33,49,69) — identical value
  ),
  _RowSpec(
    icon: Icons.info,
    title: 'About / Updates',
    description: 'Version 2.4.1, release notes, diagnostic logs',
    iconColor: NexoraColors.settingsIconLightBlue,
    iconBackdrop: NexoraColors.devicesHeaderBg, // rgb(33,49,69) — identical value
  ),
];

/// One menu row — container fill/border/radius per probe.json elements
/// 10/17/30/43 (applied uniformly to all 8 rows — the golden capture shows
/// them visually identical; the printed contract table only captured 4 of
/// the 8 as distinct elements, same drop pattern devices.md had for its
/// icon backdrops). Tapping shows a "Coming soon" acknowledgement (task
/// §3/§4 — no sub-screen exists yet for any row).
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.spec, required this.controller});

  final _RowSpec spec;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NexoraColors.settingsRowFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.openRow(spec.title),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NexoraColors.devicesRowBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
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
/// Settings is the active tab (probe #72's filled pill); the other three
/// route to screens not yet built by their owning feature epics, so they
/// are present and tappable but intentionally do nothing yet (same
/// pattern as devices_view.dart's `_BottomNav`).
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
          _NavItem(icon: Icons.dashboard, label: 'Dashboard', active: false, onTap: () {}),
          _NavItem(icon: Icons.chat, label: 'Conversations', active: false, onTap: () {}),
          _NavItem(icon: Icons.router, label: 'Devices', active: false, onTap: () {}),
          _NavItem(icon: Icons.settings, label: 'Settings', active: true, onTap: () {}),
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
