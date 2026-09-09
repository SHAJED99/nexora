// features/settings/storage/presentation -- SS1-SS28
// (design/screens/settings-storage.md, GAP-024, already human-approved
// 2026-09-02, byte-unchanged). Composes E15-T03's
// `SettingsSubScreenScaffold`; no local frame, no route, no row wiring
// (task §4 -- all three are E15-T11's alone).
//
// **There is no `Clean Now` button anywhere in this file.** No apply-now,
// no confirmation dialog, no "free up space" action, no delete affordance --
// not even a disabled one (`EARS-STORE-22`, the contract's own "prohibition
// this screen exists to keep"). Every tap target below either selects a
// mode (writes a setting) or edits a parameter draft (writes the same
// setting's own parameter) -- neither runs, applies or schedules anything.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/core/persistence/database.dart' show StorageDecisionRow;
import 'package:nexora/core/storage/retention_plan.dart' show RetentionReason;
import 'package:nexora/core/storage/storage_item.dart' show StorageItemKind;
import 'package:nexora/core/storage/storage_settings_repository.dart'
    show StorageMode;
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';

import 'storage_settings_controller.dart';

class StorageSettingsView extends GetView<StorageSettingsController> {
  const StorageSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSubScreenScaffold(
      title: 'Storage',
      subtitle: 'Choose how NEXORA manages local storage.',
      children: [
        _UsageSummaryCard(controller: controller),
        const SizedBox(height: 16),
        _ModeRow(mode: StorageMode.smart, controller: controller),
        const SizedBox(height: 12),
        _ModeRow(mode: StorageMode.olderThanDays, controller: controller),
        const SizedBox(height: 12),
        _ModeRow(mode: StorageMode.overSizeMb, controller: controller),
        const SizedBox(height: 16),
        _ExplanationCard(controller: controller),
      ],
    );
  }
}

/// SS5-SS9. Reads only [StorageSettingsController.usage*] -- never triggers
/// an inventory pass itself (the screen observes, task §6 note).
class _UsageSummaryCard extends StatelessWidget {
  const _UsageSummaryCard({required this.controller});

  final StorageSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      children: [
        Row(
          children: [
            const SettingsRowGlyph(
              Icons.sd_storage,
              color: NexoraColors.welcomeHeading,
            ),
            const SizedBox(width: 8),
            // `Expanded` guards against a `RenderFlex` overflow -- found on
            // real-device verification, same fix `security_center_view.dart`
            // already applies to this identical glyph+heading Row shape.
            const Expanded(child: SettingsSectionHeading('Local Storage')),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() {
          if (controller.usageError.value) {
            return const SettingsEmptyOrErrorLine(
              "Couldn't read local storage. Try again.",
            );
          }
          // `loading` (design contract §5): unpopulated, no spinner.
          if (!controller.usageLoaded.value) {
            return const SizedBox.shrink();
          }
          final total = controller.usageTotalBytes.value ?? 0;
          // `pttRecording` has no approved label in this contract's own
          // §Copy (only `Voice messages`/`Call recordings`/`Old
          // attachments` are named for the four media kinds) -- omitted
          // here rather than rendered under an invented label. It always
          // measures zero in this build (no producer, `StorageInventory`'s
          // own header), so nothing is silently dropped from what the
          // design actually shows.
          final classRows = controller.usageClassTotals.where(
            (total) => total.kind != StorageItemKind.pttRecording,
          );
          final databaseFileBytes = controller.usageDatabaseFileBytes.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsMachineValue('${_formatMb(total)} MB used'),
              const SizedBox(height: 12),
              for (final classTotal in classRows)
                _UsageRow(
                  label: _classLabel(classTotal.kind),
                  bytes: classTotal.bytes,
                ),
              if (databaseFileBytes != null)
                _UsageRow(label: 'Database file', bytes: databaseFileBytes),
            ],
          );
        }),
      ],
    );
  }
}

/// SS8/SS9 -- one usage-summary class row.
class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.bytes});

  final String label;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: _classLabelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('${_formatMb(bytes)} MB', style: _classByteStyle),
        ],
      ),
    );
  }
}

/// SS10-SS19 -- one mode option, its own card (SS10's own "the settings row
/// card"), with SS16-SS19's parameter field rendered only while this mode is
/// the active one (task §6 risk: "rendering both, or rendering one for Smart
/// Mode, is a contract violation").
class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.mode, required this.controller});

  final StorageMode mode;
  final StorageSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.policy.value;
      final selected =
          current != null && StorageMode.values.byName(current.mode) == mode;
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => controller.selectMode(mode),
          child: SettingsSectionCard(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_modeTitle(mode), style: NexoraTextStyles.settingsRowTitle),
                        const SizedBox(height: 4),
                        SettingsBodyLine(
                          mode == StorageMode.smart
                              ? "Smart Mode doesn't remove conversation content."
                              : 'This mode can remove conversation content.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SettingsSelectionGlyph(selected: selected),
                ],
              ),
              if (selected && mode == StorageMode.olderThanDays)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Obx(
                    () => _ParameterField(
                      key: const ValueKey('storage-param-olderThanDays'),
                      label: 'Days',
                      initialValue: controller.olderThanDaysDraft.value,
                      invalidMessage: 'Enter a whole number of days, 1 or more.',
                      onChangedValid: controller.updateOlderThanDays,
                    ),
                  ),
                ),
              if (selected && mode == StorageMode.overSizeMb)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Obx(
                    () => _ParameterField(
                      key: const ValueKey('storage-param-overSizeMb'),
                      label: 'Limit (MB)',
                      initialValue: controller.maxBytesMbDraft.value,
                      invalidMessage: 'Enter a size of at least 1 MB.',
                      onChangedValid: controller.updateMaxBytesMb,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// SS16-SS19. **Not a text-input primitive borrowed from elsewhere** --
/// SS17 is the parent's own card surface (`settings-storage.md`
/// §Derivation boundary 4), carrying a `JetBrains Mono` numeral. Still a
/// real, editable `TextField` (the design's own `textbox:text` role) --
/// only its visual chrome is the card surface, never a generic "input box"
/// style. `error_outline` at [NexoraColors.settingsBodyText] is GAP-009's
/// approved treatment; no red is introduced (§Derivation boundary 5).
class _ParameterField extends StatefulWidget {
  const _ParameterField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.invalidMessage,
    required this.onChangedValid,
  });

  final String label;
  final int initialValue;
  final String invalidMessage;
  final Future<bool> Function(int) onChangedValid;

  @override
  State<_ParameterField> createState() => _ParameterFieldState();
}

class _ParameterFieldState extends State<_ParameterField> {
  late final TextEditingController _text = TextEditingController(
    text: '${widget.initialValue}',
  );
  bool _invalid = false;

  Future<void> _onChanged(String value) async {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) {
      setState(() => _invalid = true);
      return;
    }
    final ok = await widget.onChangedValid(parsed);
    if (!mounted) return;
    setState(() => _invalid = !ok);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsStateLabel(widget.label),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: NexoraColors.devicesHeaderBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _text,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'JetBrains Mono',
              color: NexoraColors.welcomeButtonBg,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              isCollapsed: true,
            ),
            onChanged: _onChanged,
          ),
        ),
        if (_invalid) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                size: 18,
                color: NexoraColors.settingsBodyText,
              ),
              const SizedBox(width: 6),
              Expanded(child: SettingsBodyLine(widget.invalidMessage)),
            ],
          ),
        ],
      ],
    );
  }
}

/// SS20-SS26 plus the `empty`/`error` states (SS27/SS28). Reads
/// [StorageSettingsController.decisions] only -- never runs, applies or
/// schedules a pass by rendering (task §6 note).
class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.controller});

  final StorageSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      children: [
        Obx(() {
          if (controller.decisionsError.value) {
            return const SettingsEmptyOrErrorLine(
              "Couldn't read local storage. Try again.",
            );
          }
          // `loading` (design contract §5): unpopulated, no spinner.
          if (!controller.decisionsLoaded.value) {
            return const SizedBox.shrink();
          }
          final decisions = controller.decisions;
          // `empty` (design contract §5): a required state, not an edge
          // case -- the expected reading on a default install.
          if (decisions.isEmpty) {
            return const SettingsEmptyOrErrorLine(
              'Nothing to remove right now.',
            );
          }
          final totalBytes = decisions.fold<int>(0, (sum, d) => sum + d.bytes);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SettingsStateLabel('Will remove:'),
                  const SizedBox(width: 6),
                  // SS26 -- renders exactly when this list is non-empty,
                  // the same condition `dashboard_view.dart`'s own
                  // `warningActive` uses for the identical glyph.
                  const Icon(
                    Icons.warning,
                    size: 18,
                    color: NexoraColors.settingsBodyText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final decision in decisions) _DecisionRow(decision: decision),
              const SizedBox(height: 12),
              const SettingsStateLabel('Why:'),
              const SizedBox(height: 4),
              SettingsBodyLine(
                'Removing these would free up ${_formatMb(totalBytes)} MB.',
              ),
            ],
          );
        }),
      ],
    );
  }
}

/// SS21-SS23 -- one decision row.
class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision});

  final StorageDecisionRow decision;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _categoryLabel(decision.categoryKey),
                  style: _classLabelStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('${_formatMb(decision.bytes)} MB', style: _classByteStyle),
            ],
          ),
          const SizedBox(height: 2),
          SettingsBodyLine(
            _reasonLabel(
              RetentionReason.values.byName(decision.reasonCode),
              decision.reasonDetail,
            ),
          ),
        ],
      ),
    );
  }
}

/// BRD §19's own mode names, verbatim -- the literal "X" placeholder, never
/// substituted with the user's real parameter (that lives in SS16/SS17's
/// own field, separately). `settings-storage.md` SS11's own copy.
String _modeTitle(StorageMode mode) => switch (mode) {
      StorageMode.smart => 'Smart Mode',
      StorageMode.olderThanDays => 'Delete data older than X days',
      StorageMode.overSizeMb => 'Delete old data when storage exceeds X MB',
    };

/// SS8/SS21's category label, keyed by [StorageItemKind] for the usage
/// summary. `settings-storage.md`'s own §Copy set -- `pttRecording` is
/// filtered out before this is ever called (see `_UsageSummaryCard`).
String _classLabel(StorageItemKind kind) => switch (kind) {
      StorageItemKind.message => 'Messages',
      StorageItemKind.relayPayload => 'Temporary cache',
      StorageItemKind.voiceMessage => 'Voice messages',
      StorageItemKind.callRecording => 'Call recordings',
      StorageItemKind.attachment => 'Old attachments',
      StorageItemKind.databaseFile => 'Database file',
      // `pttRecording` has no approved copy in `settings-storage.md`'s own
      // §Copy set (only `Voice messages`/`Call recordings`/`Old
      // attachments` are named for the four media kinds) -- this branch is
      // provably unreachable (`_UsageSummaryCard` filters `pttRecording`
      // out before calling this function) and exists only because Dart
      // requires this `switch` to be exhaustive over all seven kinds. Never
      // rendered; not an approved string.
      StorageItemKind.pttRecording => 'PTT recordings',
    };

/// SS21's category label, keyed by the decision log's own machine
/// `categoryKey` string (`manual_policy.dart`/`smart_mode_policy.dart`'s
/// shared `_categoryKeyFor`). Mirrors [_classLabel] exactly, plus `relayCache`
/// (excluded from [StorageSettingsController.decisions] already, but mapped
/// here for completeness rather than left to the honest fallback) --
/// unrecognised keys fall back to the raw key itself, never a blank label
/// (mirrors `dashboard_view.dart`'s own `_categoryLabelFor` precedent: a
/// category with no producer in this build should never silently disappear
/// from an explanation surface, `FR-STORE-007`).
String _categoryLabel(String categoryKey) => switch (categoryKey) {
      'messages' => 'Messages',
      'relayCache' => 'Temporary cache',
      'voiceMessages' => 'Voice messages',
      'callRecordings' => 'Call recordings',
      'attachments' => 'Old attachments',
      'databaseFile' => 'Database file',
      // `pttRecordings` has no approved copy in this contract either (see
      // `_classLabel`'s own note) -- falls through to the honest raw-key
      // fallback below rather than inventing a string for it.
      _ => categoryKey,
    };

/// SS23's reason copy -- `settings-storage.md`'s own §Copy set. `olderThan`
/// and `overSizeLimit` are the only two reasons `ManualPolicy` ever assigns
/// (the only policy whose decisions survive [StorageSettingsController]'s
/// own filter, since a Smart Mode `messages` row is always excluded --
/// `_filterActionable`'s own doc). `rarelyAccessed`/`noLongerRequired` are
/// BRD-verbatim reason strings, kept for completeness. `storagePressure` has
/// no approved copy in this contract (`settings-storage.md` §Open 1: "no
/// copy is proposed" -- a product judgement call, not this task's to make)
/// and is not reachable by any decision this filter keeps today; its own
/// enum name is reported honestly rather than inventing prose for it.
String _reasonLabel(RetentionReason reason, String? detail) => switch (reason) {
      RetentionReason.olderThan => 'Older than ${detail ?? '0'} days',
      RetentionReason.rarelyAccessed => 'Rarely accessed',
      RetentionReason.noLongerRequired => 'No longer required',
      RetentionReason.overSizeLimit => 'Over the size limit',
      RetentionReason.storagePressure => reason.name,
    };

/// Binary MiB, matching `StorageSettingsRepository.minMaxBytes`'s own "1
/// MiB = 1,048,576 bytes" conversion -- the one further MB-facing display
/// conversion this file needs, applied consistently with
/// `dashboard_view.dart`'s own identical `_formatMb` rather than re-deriving
/// a second convention (task §6 risk note: "convert once ... never convert
/// twice"). Never a negative or fabricated value; a non-zero byte count
/// that rounds to 0 MB shows `<1`, never `0`.
String _formatMb(int bytes) {
  if (bytes <= 0) return '0';
  final mb = bytes / (1024 * 1024);
  final rounded = mb.round();
  return rounded < 1 ? '<1' : '$rounded';
}

/// SS8/SS21 -- "the devices row title shape in the settings palette"
/// (`settings-storage.md`'s own words): `14px` `w500`
/// `rgb(248, 249, 255)`, the same composite `settings-notifications.md`'s
/// own `_rowTitleStyle` already uses for the identical treatment. No new
/// colour -- both are `NexoraColors.welcomeButtonBg`.
const _classLabelStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: NexoraColors.welcomeButtonBg,
);

/// SS9/SS22 -- "the devices state-label treatment" plus `JetBrains Mono`
/// (`settings-storage.md`'s own words): `12px` `w500`
/// `rgb(199, 196, 216)` `JetBrains Mono`, the same composite
/// `dashboard_view.dart`'s own `_storageByteStyle` already uses for the
/// identical treatment on the same data shape. No new colour -- all three
/// values (size, weight, colour) are already measured in `settings.md`'s
/// own token table; only the combination is declared locally, exactly as
/// `dashboard_view.dart` already does for this same "byte figure" role.
const _classByteStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.settingsBodyText,
  fontFamily: 'JetBrains Mono',
);
