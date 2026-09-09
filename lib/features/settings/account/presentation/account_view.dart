// features/settings/account/presentation -- AC1-AC17
// (design/screens/settings-account.md, GAP-035). Composes E15-T03's
// `SettingsSubScreenScaffold`; no local frame, no route, no row wiring
// (task §4 -- all three are E15-T11's alone).
//
// Two `SettingsSectionCard`s (AC3-AC7 "Signed in as", AC8-AC13 "This
// device" + its own "Linked devices" sub-list -- the same "sub-heading
// nested inside the last opened card" shape `PrivacySettingsView`'s own
// "Per person" list already uses under its "Location sharing" card), then
// the sign-out row (AC14/AC15) standing OUTSIDE any card -- the same
// "outside any card" placement `PrivacySettingsView`'s own PV22 line
// already uses for a screen-level statement, here used instead for the
// screen's one and only action so no card visually diminishes it.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';

import 'account_controller.dart';

/// AC1-AC17. Every string below is `settings-account.md`'s §Copy, copied
/// character for character.
class AccountView extends GetView<AccountController> {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsSubScreenScaffold(
        title: 'Account',
        subtitle:
            'The account this app signs in with, and the device identity '
            'that is yours alone.',
        children: [
          // AC3-AC7 -- Signed in as.
          SettingsSectionCard(
            children: [
              const Row(
                children: [
                  Expanded(child: SettingsSectionHeading('Signed in as')),
                  SizedBox(width: 8),
                  // AC4 -- settings.md element 9's own glyph/colour.
                  SettingsRowGlyph(
                    Icons.account_circle,
                    color: NexoraColors.devicesAllowedBlue,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (controller.accountError.value)
                const SettingsEmptyOrErrorLine(
                  'Account details could not be read.',
                )
              else if (controller.accountUid.value != null) ...[
                SettingsMachineValue(controller.accountUid.value!),
                const SizedBox(height: 8),
                const SettingsBodyLine(
                  'Google account. Signing in does not create your device '
                  'identity — that is generated here, on this device.',
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // AC8-AC13 -- This device, then its own Linked devices sub-list.
          SettingsSectionCard(
            children: [
              const SettingsSectionHeading('This device'),
              const SizedBox(height: 12),
              if (controller.deviceError.value)
                const SettingsEmptyOrErrorLine(
                  'Account details could not be read.',
                )
              else if (controller.deviceFingerprint.value != null) ...[
                SettingsMachineValue(controller.deviceFingerprint.value!),
                const SizedBox(height: 8),
                const SettingsBodyLine(
                  'Generated on this device. It has never left it, and it '
                  'is not derived from your account.',
                ),
              ],
              const SizedBox(height: 16),
              const SettingsSectionHeading('Linked devices'),
              const SizedBox(height: 8),
              _LinkedDevicesBody(
                loaded: controller.linkedDevicesLoaded.value,
                deviceIds: controller.linkedDevices,
                thisDeviceId: controller.thisDeviceId.value,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // AC14/AC15 -- the sign-out row. Never gated by AC17/AC16 above
          // (settings-account.md §States, `error`: "the sign-out row is
          // never hidden by a failed read"), and rendered unconditionally
          // regardless of the two cards' own load state.
          _SignOutRow(
            onTap: () => Get.toNamed('/settings/sign-out-confirm'),
          ),
          const SizedBox(height: 4),
          const SettingsBodyLine('Erases everything on this device.'),
        ],
      ),
    );
  }
}

/// AC13 -- one row per linked device (device id + "This device"/"Linked"),
/// or AC16's own empty line once loaded with nothing to show. `loaded ==
/// false` renders nothing (the `loading` state, task §5: "values
/// unpopulated", never a spinner) -- the same `null`-means-unloaded shape
/// `_SectionBody` (security_center_view.dart) already uses for this exact
/// distinction.
class _LinkedDevicesBody extends StatelessWidget {
  const _LinkedDevicesBody({
    required this.loaded,
    required this.deviceIds,
    required this.thisDeviceId,
  });

  final bool loaded;
  final List<String> deviceIds;
  final String? thisDeviceId;

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const SizedBox.shrink();
    if (deviceIds.isEmpty) {
      return const SettingsEmptyOrErrorLine(
        'No other devices are linked to this account.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final deviceId in deviceIds)
          _LinkedDeviceRow(
            deviceId: deviceId,
            isThisDevice: deviceId == thisDeviceId,
          ),
      ],
    );
  }
}

/// AC13's own row shape (`devices.md` row shape, per contract): device id
/// (SH11, machine value) + its own state label (SH10).
class _LinkedDeviceRow extends StatelessWidget {
  const _LinkedDeviceRow({
    required this.deviceId,
    required this.isThisDevice,
  });

  final String deviceId;
  final bool isThisDevice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: SettingsMachineValue(deviceId)),
          const SizedBox(width: 12),
          SettingsStateLabel(isThisDevice ? 'This device' : 'Linked'),
        ],
      ),
    );
  }
}

/// AC14 -- `Sign out` + `chevron_right`, neutral treatment (SH6 title +
/// SH9 -- pending `GAP-035`'s own unresolved destructive-colour fork). No
/// destructive colour is asserted here (task §4/§8 -- picking one would
/// settle a parked design decision by taste).
class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: SettingsSectionHeading('Sign out')),
              SizedBox(width: 12),
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
