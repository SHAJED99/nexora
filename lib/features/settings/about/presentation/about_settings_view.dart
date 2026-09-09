// features/settings/about/presentation -- AB1-AB18
// (design/screens/settings-about.md, GAP-038). Composes E15-T03's
// `SettingsSubScreenScaffold`; no local frame, no route, no row wiring
// (task §4 -- all three are E15-T11's alone). No button of any kind
// anywhere on this screen (task §4/§6): `Update available` at AB8 is a
// status word, not a control.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/core/services/version_policy_service.dart'
    show VersionPolicy;
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';
import 'package:nexora/features/version/domain/version_state.dart';

import 'about_settings_controller.dart';

/// AB1-AB18. Every fixed string below is `settings-about.md`'s §Copy,
/// copied character for character.
class AboutSettingsView extends GetView<AboutSettingsController> {
  const AboutSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        // Every `.value`/list read this screen depends on is done HERE,
        // synchronously inside the `Obx` builder -- the same shape
        // `SecurityCenterView` (`E15-T06`) already established. `Obx` can
        // only discover which observables to rebuild on by tracking reads
        // that happen during ITS OWN builder call; a read deferred into a
        // child `StatelessWidget`'s own `build` (called later, by the
        // framework's own build pipeline, not by this closure) is
        // invisible to it.
        final buildInfoError = controller.buildInfoError.value;
        final version = controller.version.value;
        final buildNumber = controller.buildNumber.value;
        final versionState = controller.versionState.value;
        final policyError = controller.policyError.value;
        final policyLoaded = controller.policyLoaded.value;
        final cachedPolicy = controller.cachedPolicy.value;
        final logEntriesError = controller.logEntriesError.value;
        final logEntriesLoaded = controller.logEntriesLoaded.value;
        final logEntries = controller.logEntries.toList();

        return SettingsSubScreenScaffold(
          title: 'About',
          subtitle:
              'This build, the version policy it is checked against, and '
              'what has gone wrong recently.',
          children: [
            SettingsSectionCard(
              children: [
                const Row(
                  children: [
                    Expanded(child: SettingsSectionHeading('This build')),
                    SizedBox(width: 8),
                    // AB4 -- the same "info" glyph `settings.md` element
                    // 44 uses for the hub row this screen is reached
                    // from.
                    SettingsRowGlyph(
                      Icons.info,
                      color: NexoraColors.settingsIconLightBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _BuildInfoBody(
                  error: buildInfoError,
                  version: version,
                  buildNumber: buildNumber,
                  versionState: versionState,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsSectionCard(
              children: [
                const SettingsSectionHeading('Version policy'),
                const SizedBox(height: 12),
                _PolicyBody(
                  error: policyError,
                  loaded: policyLoaded,
                  policy: cachedPolicy,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsSectionCard(
              children: [
                const SettingsSectionHeading('Diagnostics'),
                const SizedBox(height: 12),
                _DiagnosticsBody(
                  error: logEntriesError,
                  loaded: logEntriesLoaded,
                  entries: logEntries,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// AB6-AB8 — `loading` (task §5: "content lines unpopulated", never a
/// spinner) renders nothing below the heading; `error` (AB18) replaces the
/// whole card's values, never a lone unreadable row beside otherwise
/// -populated ones (task §6 Risks).
class _BuildInfoBody extends StatelessWidget {
  const _BuildInfoBody({
    required this.error,
    required this.version,
    required this.buildNumber,
    required this.versionState,
  });

  final bool error;
  final String? version;
  final int? buildNumber;
  final VersionState? versionState;

  @override
  Widget build(BuildContext context) {
    if (error) {
      return const SettingsEmptyOrErrorLine(
        'Version information could not be read.',
      );
    }
    final resolvedVersion = version;
    final resolvedBuildNumber = buildNumber;
    if (resolvedVersion == null || resolvedBuildNumber == null) {
      // Still loading -- distinct from `error` above.
      return const SizedBox.shrink();
    }
    // `versionState` depends on the SAME cached policy the Version Policy
    // card reads (`EvaluateVersionStateUseCase`) -- a failure reading it is
    // that card's own failure (`policyError`, `EARS-UI-11`), not this
    // card's. Version/Build render regardless; Status renders only once
    // `versionState` actually resolves, rather than forcing this whole
    // card into AB18 for a failure that belongs to a different section.
    final resolvedVersionState = versionState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValueRow(
          label: 'Version',
          value: SettingsMachineValue(resolvedVersion),
        ),
        const SizedBox(height: 8),
        _KeyValueRow(
          label: 'Build',
          value: SettingsMachineValue('$resolvedBuildNumber'),
        ),
        if (resolvedVersionState != null) ...[
          const SizedBox(height: 8),
          _KeyValueRow(
            label: 'Status',
            value: SettingsStateLabel(_statusLabel(resolvedVersionState)),
          ),
        ],
      ],
    );
  }
}

/// AB11-AB13 — `loading` renders nothing below the heading; `null` (AB13,
/// the fail-open statement — `EARS-VER-9`) is a real, ordinary outcome and
/// never confused with an `error` (AB18) (task §6 Risks: "`cached()` is a
/// Future over a Drift read that can legitimately return null. null is
/// AB13, not AB18.").
class _PolicyBody extends StatelessWidget {
  const _PolicyBody({
    required this.error,
    required this.loaded,
    required this.policy,
  });

  final bool error;
  final bool loaded;
  final VersionPolicy? policy;

  @override
  Widget build(BuildContext context) {
    if (error) {
      return const SettingsEmptyOrErrorLine(
        'Version information could not be read.',
      );
    }
    if (!loaded) {
      return const SizedBox.shrink();
    }
    final resolvedPolicy = policy;
    if (resolvedPolicy == null) {
      // AB13.
      return const SettingsEmptyOrErrorLine(
        'No policy has been fetched yet. This build is treated as '
        'supported until one is.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValueRow(
          label: 'Minimum supported build',
          value: SettingsMachineValue(
            '${resolvedPolicy.minimumSupportedBuild}',
          ),
        ),
        const SizedBox(height: 8),
        _KeyValueRow(
          label: 'Last checked',
          // `updatedAt` is epoch millis (`VersionPolicyService`) -- render
          // it as an absolute ISO-8601 instant, the same format the
          // Diagnostics card's own `_LogEntryRow` already uses for its
          // timestamp, rather than the raw unreadable integer.
          value: SettingsMachineValue(
            DateTime.fromMillisecondsSinceEpoch(
              resolvedPolicy.updatedAt,
              isUtc: true,
            ).toIso8601String(),
          ),
        ),
      ],
    );
  }
}

/// AB16/AB17 — `loading` renders nothing below the heading; an empty list
/// (AB17) is one of `settings-about.md`'s own two explicitly-"ordinary"
/// empty states (never rendered as an error). Never expands an entry into
/// its `cause` — `DiagnosticEntry` has no such field to expand (task §2/§6,
/// `FR-DIAG-002`).
class _DiagnosticsBody extends StatelessWidget {
  const _DiagnosticsBody({
    required this.error,
    required this.loaded,
    required this.entries,
  });

  final bool error;
  final bool loaded;
  final List<DiagnosticEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (error) {
      return const SettingsEmptyOrErrorLine(
        'Version information could not be read.',
      );
    }
    if (!loaded) {
      return const SizedBox.shrink();
    }
    if (entries.isEmpty) {
      // AB17.
      return const SettingsEmptyOrErrorLine('Nothing has been logged.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final entry in entries) _LogEntryRow(entry: entry)],
    );
  }
}

/// AB6-AB8/AB11-AB12's shared row shape — a body-line label (SH7) and its
/// own value widget (SH11 machine value, or SH10 state label for Status).
class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: SettingsBodyLine(label)),
        const SizedBox(width: 12),
        // `Flexible` rather than a bare unconstrained `value` (F6, review
        // round 1): "Last checked" now renders a full ISO-8601 instant
        // (24 characters) rather than a raw epoch-millis integer, which
        // overflows this row's remaining width at this screen's 390px
        // viewport with no wrap constraint at all -- the exact overflow
        // shape `_LogEntryRow` already documents for the same reason at
        // this same viewport. Every other `_KeyValueRow` value is short
        // enough that this is a no-op for it.
        Flexible(child: value),
      ],
    );
  }
}

/// AB16 — one diagnostic row: the log code at SH11 (machine value) and its
/// own timestamp at SH7 (body line). Rendered as an absolute, machine
/// -readable string, never a relative "Xd ago" — `E15-T06`'s own probe
/// golden broke on exactly that shape rolling over with wall-clock time
/// (F3, that task's review round), and this row has no reason to take on
/// the same risk when the underlying value is already a fixed instant.
class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({required this.entry});

  final DiagnosticEntry entry;

  @override
  Widget build(BuildContext context) {
    // Code above, timestamp below -- the same "primary value, secondary
    // line beneath it" shape `_DeviceRecordRow`
    // (`security_center_view.dart`, E15-T06) already uses, rather than a
    // side-by-side `Row` -- a log code plus a full ISO-8601 timestamp is
    // routinely wider than one row at this screen's 390px viewport
    // (confirmed: a `Row` shape overflowed by 38px at that width).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsMachineValue(entry.code),
          const SizedBox(height: 2),
          SettingsBodyLine(entry.timestamp.toIso8601String()),
        ],
      ),
    );
  }
}

/// AB8's own copy — `VersionState`'s three values, in this app's own words
/// (`settings-about.md`'s §Copy, verbatim).
String _statusLabel(VersionState state) => switch (state) {
  VersionState.upToDate => 'Up to date',
  VersionState.updateAvailable => 'Update available',
  VersionState.updateRequired => 'Update required',
};
