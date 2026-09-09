// features/settings/privacy/presentation -- PV1-PV22
// (design/screens/settings-privacy.md, GAP-033 + GAP-040). Composes
// E15-T03's `SettingsSubScreenScaffold`; no local frame, no route, no row
// wiring (task §4 -- all three are E15-T11's alone).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';

import 'privacy_settings_controller.dart';

/// PV1-PV22. Every string below is `settings-privacy.md`'s §Copy, copied
/// character for character.
class PrivacySettingsView extends GetView<PrivacySettingsController> {
  const PrivacySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsSubScreenScaffold(
        title: 'Privacy & Security',
        subtitle: 'What this device protects, and what it shares.',
        children: [
          // PV3-PV8 -- Encryption. Read-only, no error state possible: this
          // card reads nothing, it states ADR-0003's own accepted decision
          // (task §2).
          SettingsSectionCard(
            children: [
              const _SectionHeader(
                icon: Icons.security,
                iconColor: NexoraColors.settingsIconGreen,
                title: 'Encryption',
              ),
              const SizedBox(height: 4),
              const SettingsBodyLine(
                'Every private message is end-to-end encrypted. This cannot '
                'be turned off.',
              ),
              const SizedBox(height: 12),
              const _MachineValueRow(
                label: 'Direct messages',
                value: 'X3DH + Double Ratchet',
              ),
              const SizedBox(height: 8),
              const _MachineValueRow(
                label: 'Group messages',
                value: 'Sender Keys',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // PV9-PV12 -- Notification privacy. Reads, links, never writes
          // (task §4 -- if the diff contains `setPrivacyLevel`, it is
          // wrong). No icon on this card -- the contract's own element
          // table names none, unlike the Encryption and Location cards.
          SettingsSectionCard(
            children: [
              const SettingsSectionHeading('Notification privacy'),
              const SizedBox(height: 12),
              if (controller.notificationPrivacyError.value)
                const SettingsEmptyOrErrorLine('Settings could not be read.')
              else
                SettingsBodyLine(controller.notificationPrivacyLabel.value),
              const SizedBox(height: 8),
              _NotificationPrivacyLinkRow(
                onTap: () => Get.toNamed('/settings/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // PV13-PV21 -- Location sharing. The one writable card.
          SettingsSectionCard(
            children: [
              const _SectionHeader(
                icon: Icons.location_on,
                iconColor: NexoraColors.welcomeHeading,
                title: 'Location sharing',
              ),
              const SizedBox(height: 12),
              if (controller.globalLocationError.value)
                const SettingsEmptyOrErrorLine('Settings could not be read.')
              else ...[
                _GlobalLocationRow(
                  enabled: controller.globalLocationEnabled.value,
                  // Inert (`null`) while the switch's own value is still
                  // unknown, task's carried-forward F1 finding -- the tap
                  // target itself must not suggest an action is possible
                  // before the first stream emission arrives. The real
                  // write guard also lives in
                  // `PrivacySettingsController.setGlobalLocation`.
                  onTap: controller.globalLocationEnabled.value == null
                      ? null
                      : () => controller.setGlobalLocation(
                          !controller.globalLocationEnabled.value!,
                        ),
                ),
                const SizedBox(height: 8),
                const SettingsBodyLine(
                  'When this is off, no one can see your location, whatever '
                  'their own setting says.',
                ),
              ],
              const SizedBox(height: 12),
              const SettingsSectionHeading('Per person'),
              const SizedBox(height: 8),
              if (controller.peerLocationError.value)
                const SettingsEmptyOrErrorLine('Settings could not be read.')
              else if (controller.peerLocationEnabled.value == null)
                const SizedBox.shrink()
              else if (controller.peerLocationEnabled.value!.isEmpty)
                const SettingsEmptyOrErrorLine(
                  'No one has location sharing turned on yet.',
                )
              else
                for (final entry
                    in controller.peerLocationEnabled.value!.entries)
                  _PeerLocationRow(
                    peerDeviceId: entry.key,
                    enabled: entry.value,
                    onTap: () => controller.setPeerLocation(
                      entry.key,
                      !entry.value,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          // PV22 -- GAP-040 (human-approved 2026-09-09): EARS-UI-9's second
          // clause requires this screen to STATE the absence of an app
          // lock/permissions manager, not merely omit a control for one.
          // A constant SH7 line, outside any card (PV2's own placement),
          // present in every state (task §5 / settings-privacy.md
          // §States) -- it names a capability this build never
          // implements, so no read failure can ever touch it. No icon, no
          // control, no link: a statement, nothing else.
          const SettingsBodyLine(
            'App lock and a permissions manager are not available in this '
            'version.',
          ),
        ],
      ),
    );
  }
}

/// PV4/PV14 -- a card's own leading icon (SH8) beside its `heading:3`
/// (SH6). Same shape as `notification_settings_view.dart`'s
/// `_SectionHeader` -- heading first, glyph after (matches this screen's
/// own real dumper output, not assumed order).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  final IconData icon;
  final Color iconColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // `Expanded` bounds the heading's width so a longer title (e.g.
        // "Location sharing") wraps/ellipsizes instead of overflowing the
        // card -- `notification_settings_view.dart`'s own `_SectionHeader`
        // never needed this because both its titles ("Alerts", "Privacy")
        // are short; this screen's are not.
        Expanded(child: SettingsSectionHeading(title)),
        const SizedBox(width: 8),
        SettingsRowGlyph(icon, color: iconColor),
      ],
    );
  }
}

/// PV7/PV8 -- a label (SH7, body line) above its machine value (SH11,
/// `JetBrains Mono`). Read-only, no tap target: ADR-0003's protocol choice
/// is a statement of fact, not a preference (task §2). Stacked rather than
/// side-by-side: a `Row` with the label `Expanded` and the value's natural
/// (unbounded) width left it squeezed to a few pixels and wrapped vertically
/// for "Direct messages" + "X3DH + Double Ratchet" -- a real overflow-style
/// defect, not a probe artifact (confirmed against the real dumper output,
/// this task's own carried-forward F1 warning). Stacking removes the shared
/// horizontal budget entirely; both lines keep their own SH7/SH11 styling.
class _MachineValueRow extends StatelessWidget {
  const _MachineValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsBodyLine(label),
        const SizedBox(height: 2),
        SettingsMachineValue(value),
      ],
    );
  }
}

/// PV12 -- `Change in Notifications` + `chevron_right`. Navigates; never
/// writes (task §4). Rendered unconditionally, independent of whether
/// PV11's own read succeeded -- this row makes no read of its own.
class _NotificationPrivacyLinkRow extends StatelessWidget {
  const _NotificationPrivacyLinkRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Expanded(
                child: SettingsBodyLine('Change in Notifications'),
              ),
              const SizedBox(width: 12),
              Icon(
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

/// PV16 -- `Share my location` + state (SH7 + SH12). Blank selection slot
/// (no glyph, not tappable) while [enabled] is `null` -- the `loading`
/// state, never a spinner (task §5, carried-forward F1 finding).
class _GlobalLocationRow extends StatelessWidget {
  const _GlobalLocationRow({required this.enabled, required this.onTap});

  final bool? enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Expanded(child: SettingsBodyLine('Share my location')),
              const SizedBox(width: 12),
              SizedBox(
                width: 24,
                height: 24,
                child: enabled == null
                    ? null
                    : SettingsSelectionGlyph(selected: enabled!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PV19 -- one row per peer with a location setting: `devices.md` row
/// shape (leading glyph SH8, peer id SH7, state SH12). Shows a device id
/// only -- no other information about the peer (task §6 risk note).
class _PeerLocationRow extends StatelessWidget {
  const _PeerLocationRow({
    required this.peerDeviceId,
    required this.enabled,
    required this.onTap,
  });

  final String peerDeviceId;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const SettingsRowGlyph(Icons.devices),
              const SizedBox(width: 12),
              Expanded(child: SettingsBodyLine(peerDeviceId)),
              const SizedBox(width: 12),
              SettingsSelectionGlyph(selected: enabled),
            ],
          ),
        ),
      ),
    );
  }
}
