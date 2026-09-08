// features/settings/notifications/presentation -- NT1-NT22
// (design/screens/settings-notifications.md, GAP-032). Composes E15-T03's
// `SettingsSubScreenScaffold`; no local frame, no route, no row wiring
// (task §4 -- all three are E15-T11's alone).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/persistence/notification_tables.dart'
    show NotificationPrivacyLevel;
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';

import 'notification_settings_controller.dart';

/// NT1-NT22. Every string below is `settings-notifications.md`'s §Copy,
/// copied character for character -- including NT19's em dash and the
/// straight double quotes inside it (task §6 risk).
class NotificationSettingsView extends GetView<NotificationSettingsController> {
  const NotificationSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsSubScreenScaffold(
        title: 'Notifications',
        subtitle:
            'Choose which alerts this device shows, and how much they reveal.',
        children: [
          SettingsSectionCard(
            children: [
              const _SectionHeader(
                icon: Icons.notifications,
                iconColor: NexoraColors.settingsIconLightBlue,
                title: 'Alerts',
              ),
              const SizedBox(height: 12),
              if (controller.categoriesError.value)
                const SettingsEmptyOrErrorLine('Settings could not be read.')
              else
                for (final category in NotificationSettingsController.categories)
                  _CategoryRow(
                    title: _categoryTitle[category]!,
                    secondary: _categorySecondary[category]!,
                    enabled: controller.isEnabled(category),
                    onTap: () => controller.toggle(category),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            children: [
              const _SectionHeader(
                icon: Icons.lock,
                iconColor: NexoraColors.settingsIconGreen,
                title: 'Privacy',
              ),
              const SizedBox(height: 4),
              const SettingsBodyLine(
                'What a notification shows on a locked screen.',
              ),
              const SizedBox(height: 12),
              if (controller.privacyError.value)
                const SettingsEmptyOrErrorLine('Settings could not be read.')
              else ...[
                _PrivacyRow(
                  title: 'Hidden',
                  secondary: 'Neither who nor what — "New message".',
                  selected:
                      controller.privacy.value ==
                      NotificationPrivacyLevel.hidden,
                  onTap: () => controller
                      .selectPrivacy(NotificationPrivacyLevel.hidden),
                ),
                _PrivacyRow(
                  title: 'Sender only',
                  secondary: 'Who it is from, never what it says.',
                  selected:
                      controller.privacy.value ==
                      NotificationPrivacyLevel.senderOnly,
                  onTap: () => controller
                      .selectPrivacy(NotificationPrivacyLevel.senderOnly),
                ),
                // NT21 -- offered as a value, not a working feature
                // (EARS-NOTIFY-17). No tap target: this row never writes.
                _PrivacyRow(
                  title: 'Full',
                  secondary:
                      'Not available — messages are decrypted only while '
                      'the app is open.',
                  selected:
                      controller.privacy.value ==
                      NotificationPrivacyLevel.full,
                  onTap: null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// NT6-NT14's copy, keyed by category, in `settings-notifications.md`'s
/// stated order (mirrors `NotificationSettingsController.categories`).
const Map<NotificationCategory, String> _categoryTitle = {
  NotificationCategory.message: 'Messages',
  NotificationCategory.voiceMessage: 'Voice messages',
  NotificationCategory.ptt: 'Push to talk',
  NotificationCategory.incomingCall: 'Calls',
  NotificationCategory.connectionRequest: 'Connection requests',
  NotificationCategory.trustRequest: 'Trust requests',
  NotificationCategory.groupEvent: 'Group activity',
  NotificationCategory.securityEvent: 'Security events',
  NotificationCategory.storageWarning: 'Storage warnings',
};

const Map<NotificationCategory, String> _categorySecondary = {
  NotificationCategory.message: 'New text messages.',
  NotificationCategory.voiceMessage: 'New recorded voice messages.',
  NotificationCategory.ptt: 'Live push-to-talk audio.',
  NotificationCategory.incomingCall: 'Incoming voice calls.',
  NotificationCategory.connectionRequest: 'A device wants to connect.',
  NotificationCategory.trustRequest: 'A device wants to be trusted.',
  NotificationCategory.groupEvent:
      'Members added, removed, or roles changed.',
  NotificationCategory.securityEvent: 'Revoked devices and blocked peers.',
  NotificationCategory.storageWarning:
      'When local storage needs attention.',
};

/// NT4/NT5 and NT16/NT17 -- a card's own icon (SH8) beside its `heading:3`
/// (SH6). Colour is the card's own, drawn only from the two values
/// `settings-notifications.md` names for these two cards
/// (`NexoraColors.settingsIconLightBlue`/`settingsIconGreen`, both already
/// measured in `lib/core/design/tokens.dart`).
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
        SettingsSectionHeading(title),
        const SizedBox(width: 8),
        SettingsRowGlyph(icon, color: iconColor),
      ],
    );
  }
}

/// NT6-NT14 -- one category row. Title is "SH6-weight body"
/// (`settings-notifications.md`'s own words): body size (`14px`, SH7) at
/// SH6's weight and colour -- the same title-shape `settings-storage.md`
/// SS8 already uses for a devices-borrowed row in this palette
/// (`rgb(248, 249, 255)` == `NexoraColors.welcomeButtonBg`, already measured;
/// no new colour). Selection state is SH12, blank while [enabled] is `null`
/// (the `loading` state -- task §5, never a spinner).
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.secondary,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String secondary;
  final bool? enabled;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _rowTitleStyle),
                    const SizedBox(height: 2),
                    SettingsBodyLine(secondary),
                  ],
                ),
              ),
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

/// NT19-NT21 -- a privacy-level row. Same shape as [_CategoryRow]; NT21 is
/// rendered with no tap target at all (`onTap == null`) so it can never
/// write (EARS-NOTIFY-17) while still reading as a row, per the contract's
/// "rendered unselectable" instruction.
class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.title,
    required this.secondary,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String secondary;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _rowTitleStyle),
                const SizedBox(height: 2),
                SettingsBodyLine(secondary),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SettingsSelectionGlyph(selected: selected),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// "SH6-weight body" (`settings-notifications.md`'s own words for NT6-NT14
/// / NT19-NT21's title): `14px` at SH6's weight (`w500`) and colour
/// (`rgb(248, 249, 255)`) -- the same combination `settings-storage.md` SS8
/// already uses for a devices-borrowed row title in this palette. Both
/// values are `NexoraColors.welcomeButtonBg`'s own font-weight/colour pair;
/// no new colour is introduced.
const _rowTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: NexoraColors.welcomeButtonBg,
);
