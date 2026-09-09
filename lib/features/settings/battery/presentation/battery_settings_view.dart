// features/settings/battery/presentation -- BT1-BT13
// (design/screens/settings-battery.md, GAP-037). Composes E15-T03's
// `SettingsSubScreenScaffold`; no local frame, no route, no row wiring
// (task §4 -- all three are E15-T11's alone). Read-only throughout --
// `EARS-PLAT-16`: no button, switch or tappable row anywhere on either
// card. BT12 (the OS battery-settings deep link) is deliberately absent --
// `GAP-037`'s fork is unresolved (task §4/§Open Questions, OQ-E15-T08-2);
// this build ships BT1-BT11 plus BT13, exactly the contract's own "if
// unresolved" element list.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';

import 'battery_settings_controller.dart';

/// BT1-BT13. Every fixed string below is `settings-battery.md`'s §Copy,
/// copied character for character.
class BatterySettingsView extends GetView<BatterySettingsController> {
  const BatterySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsSubScreenScaffold(
        title: 'Battery',
        subtitle: 'What this device is allowed to do in the background, '
            'and what the system is restricting.',
        children: [
          SettingsSectionCard(
            children: [
              const Row(
                children: [
                  Expanded(child: SettingsSectionHeading('Background operation')),
                  SizedBox(width: 8),
                  // BT4 -- `settings.md` element 34's own hub-row glyph.
                  // Deviation, already established at
                  // `settings_view.dart`'s own header: the design's glyph
                  // name `battery_full_alt` has no equivalent in Flutter's
                  // bundled Material icon font -- `Icons.battery_full` is
                  // the nearest real glyph, same substitution the parent
                  // hub row already makes for this exact icon.
                  SettingsRowGlyph(
                    Icons.battery_full,
                    color: NexoraColors.settingsIconLightBlue,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BackgroundOperationBody(
                running: controller.backgroundRunning.value,
                error: controller.backgroundRunningError.value,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            children: [
              const SettingsSectionHeading('Restrictions in effect'),
              const SizedBox(height: 12),
              _RestrictionsAndPlanBody(
                restrictions: controller.restrictions,
                plan: controller.plan.value,
                error: controller.restrictionsError.value,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// BT6/BT7/BT13's own value/error handling. `null` (loading, task §5:
/// "values unpopulated") renders neither BT6 nor BT7 below the heading.
class _BackgroundOperationBody extends StatelessWidget {
  const _BackgroundOperationBody({required this.running, required this.error});

  final bool? running;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (error) {
      // BT13 -- shared error copy, this card's value only.
      return const SettingsEmptyOrErrorLine(
        'Background state could not be read.',
      );
    }
    if (running == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsStateLabel(running! ? 'Running' : 'Not running'),
        const SizedBox(height: 8),
        // BT7 -- fixed body copy, always shown once BT6 has a value.
        const SettingsBodyLine(
          'Discovery, message sync and calls continue while the app is '
          'closed — only while this is running.',
        ),
      ],
    );
  }
}

/// BT9-BT13's own value/error handling. BT10's three rows always render by
/// name (task §3 contract -- "exactly three entries", never fewer, never a
/// variable-length list); BT11's plan line renders once known.
class _RestrictionsAndPlanBody extends StatelessWidget {
  const _RestrictionsAndPlanBody({
    required this.restrictions,
    required this.plan,
    required this.error,
  });

  final List<RestrictionStatus> restrictions;
  final String? plan;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (error) {
      // BT13 -- shared error copy, this card's values only.
      return const SettingsEmptyOrErrorLine(
        'Background state could not be read.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final restriction in restrictions) _RestrictionRow(status: restriction),
        const SizedBox(height: 12),
        const SettingsSectionHeading('Current plan'),
        const SizedBox(height: 8),
        if (plan != null) SettingsBodyLine(plan!),
        // BT12 (the OS battery-settings deep link) is deliberately absent
        // here -- `GAP-037`'s fork is unresolved (file header).
      ],
    );
  }
}

/// BT10 -- one restriction's fixed name (SH7, body text) + its
/// On/Off/Unknown value (SH10). `Unknown` is a real, rendered value, not a
/// failure (task §3/§6).
class _RestrictionRow extends StatelessWidget {
  const _RestrictionRow({required this.status});

  final RestrictionStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SettingsBodyLine(status.name)),
          const SizedBox(width: 12),
          SettingsStateLabel(_valueLabel(status.value)),
        ],
      ),
    );
  }
}

/// BT10's own copy per value -- `settings-battery.md`'s §Copy, verbatim.
String _valueLabel(RestrictionValue value) => switch (value) {
  RestrictionValue.on => 'On',
  RestrictionValue.off => 'Off',
  RestrictionValue.unknown => 'Unknown',
};
