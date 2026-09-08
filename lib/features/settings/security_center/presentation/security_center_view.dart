// features/settings/security_center/presentation -- SC1-SC21
// (design/screens/settings-security-center.md, GAP-034). Composes
// E15-T03's `SettingsSubScreenScaffold`; no local frame, no route, no row
// wiring (task §4 -- all three are E15-T11's alone). This screen renders no
// action of any kind (`EARS-DIAG-5`) -- every row below is inert except
// SC16's navigation to `/devices`, which changes no security state.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/app/routes.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';
import 'package:nexora/features/settings/security_center/data/security_records_repository.dart';

import 'security_center_controller.dart';

/// SC1-SC21. Every fixed string below is `settings-security-center.md`'s
/// §Copy, copied character for character.
class SecurityCenterView extends GetView<SecurityCenterController> {
  const SecurityCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsSubScreenScaffold(
        title: 'Security Center',
        subtitle:
            'What this device has recorded about its own security. Nothing '
            'here can be changed from this screen.',
        children: [
          SettingsSectionCard(
            children: [
              const Row(
                children: [
                  Expanded(child: SettingsSectionHeading('Revoked devices')),
                  SizedBox(width: 8),
                  // SC4 -- the only glyph this screen renders anywhere,
                  // borrowed once from `settings.md` element 19's own hub
                  // row icon (SH8, `settings-security-center.md`'s own
                  // source column).
                  SettingsRowGlyph(
                    Icons.policy,
                    color: NexoraColors.settingsIconGreen,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionBody(
                records: controller.revocations.value,
                error: controller.revocationsError.value,
                emptyLine: 'No device has been revoked.',
                rowBuilder: _DeviceRecordRow.new,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            children: [
              const SettingsSectionHeading('Trusted identities'),
              const SizedBox(height: 12),
              _SectionBody(
                records: controller.trustedIdentities.value,
                error: controller.trustedIdentitiesError.value,
                emptyLine: 'No identities recorded yet.',
                rowBuilder: _DeviceRecordRow.new,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            children: [
              const SettingsSectionHeading('Blocked'),
              const SizedBox(height: 12),
              _SectionBody(
                records: controller.blockedPeers.value,
                error: controller.blockedPeersError.value,
                emptyLine: 'You have not blocked anyone.',
                rowBuilder: _DeviceRecordRow.new,
              ),
              const SizedBox(height: 8),
              const _ManageInDevicesLink(),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            children: [
              const SettingsSectionHeading('Rate limits'),
              const SizedBox(height: 12),
              _SectionBody(
                records: controller.rateLimitDenials.value,
                error: controller.rateLimitDenialsError.value,
                emptyLine: 'Nothing has been rate limited.',
                rowBuilder: _RateLimitRow.new,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One section's own list/empty/error handling -- `null` (loading, task §5:
/// "frame and card headings render, lists unpopulated") renders nothing at
/// all below the heading; `error` renders SC21 in place of the list only,
/// leaving the heading (and, for Blocked, SC16) untouched
/// (`EARS-UI-11`); an empty list renders its own SC7/SC11/SC15/SC20 line,
/// the expected state on a healthy install (task §5), never a spinner.
class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.records,
    required this.error,
    required this.emptyLine,
    required this.rowBuilder,
  });

  final List<SecurityRecord>? records;
  final bool error;
  final String emptyLine;
  final Widget Function({Key? key, required SecurityRecord record})
  rowBuilder;

  @override
  Widget build(BuildContext context) {
    if (error) {
      // SC21 -- shared error copy across every section.
      return const SettingsEmptyOrErrorLine('Records could not be read.');
    }
    final loaded = records;
    if (loaded == null) return const SizedBox.shrink();
    if (loaded.isEmpty) return SettingsEmptyOrErrorLine(emptyLine);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final record in loaded) rowBuilder(record: record)],
    );
  }
}

/// SC6/SC10/SC14 -- one row for a revoked, trusted or blocked device. Device
/// id at SH11 (machine value), an optional relative "when" at SH7 (body
/// line, revocations only -- `record.timestamp` is `null` for every other
/// record type this row renders, task §6), and the record's own state
/// label at SH10. No tap target, no dismissible, no long-press menu
/// anywhere on this widget (`EARS-DIAG-5`).
class _DeviceRecordRow extends StatelessWidget {
  const _DeviceRecordRow({super.key, required this.record});

  final SecurityRecord record;

  @override
  Widget build(BuildContext context) {
    final when = record.timestamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsMachineValue(record.displayIdentifier),
                if (when != null) ...[
                  const SizedBox(height: 2),
                  SettingsBodyLine(_formatWhen(when)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SettingsStateLabel(_stateLabel(record.recordType)),
        ],
      ),
    );
  }
}

/// SC19 -- one rate-limit row: limit name at SH7 (body line, never SH11 --
/// this is a name, not a device id), and the current-window count at SH10.
/// No tap target anywhere on this widget (`EARS-DIAG-5`).
class _RateLimitRow extends StatelessWidget {
  const _RateLimitRow({super.key, required this.record});

  final SecurityRecord record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SettingsBodyLine(record.displayIdentifier)),
          const SizedBox(width: 12),
          SettingsStateLabel('${record.count}'),
        ],
      ),
    );
  }
}

/// SC16 -- `Manage in Devices` + `chevron_right`. Navigates to the existing
/// `/devices` screen (`Routes.devices`, `E02-T02`), where blocking and
/// unblocking already live; this link changes no security state itself
/// (task §2, `EARS-DIAG-5`) -- it is the one navigational affordance this
/// screen renders, not an action.
class _ManageInDevicesLink extends StatelessWidget {
  const _ManageInDevicesLink();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => Get.toNamed(Routes.devices),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: SettingsBodyLine('Manage in Devices')),
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

/// SH10's own copy per record type -- `settings-security-center.md`'s
/// §Copy, verbatim.
String _stateLabel(SecurityRecordType type) => switch (type) {
  SecurityRecordType.revoked => 'Revoked',
  SecurityRecordType.trusted => 'Trusted',
  SecurityRecordType.blocked => 'Blocked',
  SecurityRecordType.rateLimited => '',
};

/// Relative "when" text, the same shape `devices_view.dart`'s own
/// `_formatLastSeen` already uses for this palette -- no new time-display
/// convention introduced.
String _formatWhen(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
