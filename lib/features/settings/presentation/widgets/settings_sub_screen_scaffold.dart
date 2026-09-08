// features/settings/presentation/widgets — the shared frame every Settings
// sub-screen composes (design/screens/settings-shell.md, GAP-031, E15-T03).
//
// One shell, built once, so the eight sub-screen tasks (E15-T04..T10) cannot
// each derive their own frame from settings.md and arrive at eight slightly
// different ones — each internally consistent, each passing its own gate,
// and collectively not one design. That is design-fidelity's opening
// failure, moved up a level (settings-shell.md's own framing).
//
// Every value below is cited from settings-shell.md's own "source of every
// value" column, which in turn traces to design/screens/settings.md or
// design/screens/settings-storage.md (GAP-024, already human-approved).
// Nothing here is a new visual decision — if a sub-screen needs a colour,
// radius, size or glyph that appears in neither, that is a finding to raise,
// not a value to invent (this task's own §2).
//
// No bottom navigation bar (settings-shell.md §"What this shell deliberately
// does NOT contain" #6): settings.md draws one because /settings is a
// top-level tab; a sub-screen is pushed on top of that tab, not a peer of
// it, and this file draws no such bar anywhere.
//
// Back navigation is the platform's ordinary pop (FR-UI-008). SH1's tap and
// the system back gesture do the same thing; neither is suppressed — no
// PopScope/WillPopScope appears anywhere in this file.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';

/// SH1-SH4 — the frame every Settings sub-screen shares: a 40×40 back
/// affordance (SH1/SH2), the sub-screen's own heading (SH3) and subtitle
/// (SH4), then [children] filling the scrollable content area.
///
/// `children` is a `children` slot, not a fixed layout, precisely so no
/// screen has a reason to fork this widget (settings-shell.md's own §Risks
/// note) — a screen that genuinely cannot compose it is a contract
/// amendment to `settings-shell.md`, not a local copy.
class SettingsSubScreenScaffold extends StatelessWidget {
  const SettingsSubScreenScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  /// SH3 — the sub-screen's own heading string, from its own contract.
  final String title;

  /// SH4 — the sub-screen's own one-line subtitle.
  final String subtitle;

  /// The screen's own content sections — composed from the SH5-SH13
  /// vocabulary below (or a screen-specific widget consistent with it).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.settingsPageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BackRow(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _shellHeadingStyle),
                    const SizedBox(height: 4),
                    Text(subtitle, style: NexoraTextStyles.settingsSubtitle),
                    const SizedBox(height: 16),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SH3's own text style — `28px` `w600`, colour `rgb(248, 249, 255)`
/// (`NexoraColors.welcomeButtonBg`). Deliberately NOT `settings.md`'s
/// measured `rgb(234, 241, 255)` heading colour: that value does not appear
/// in `settings.md`'s own token table, so a derived screen using it would
/// carry a value the token check cannot find in any source table.
/// `rgb(248, 249, 255)` is in that table (8 uses) and is the colour of every
/// `heading:3` on the parent — the identical decision
/// `settings-storage.md` §Derivation boundary 3 already made and the human
/// already approved (settings-shell.md's own note, restated here).
const _shellHeadingStyle = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w600,
  color: NexoraColors.welcomeButtonBg,
);

/// SH1 (back affordance, `40×40`, `r9999px`) + SH2 (`arrow_back`, `24px`,
/// `rgb(195, 192, 255)` — `NexoraColors.welcomeHeading`, the same value
/// `settings.md` elements 2/5 measure). A real `InkWell`/`Material` tap
/// target, never a raw `Listener` (L-frontend-001) — gesture-arena and
/// accessibility semantics both depend on it.
class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: Row(
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => Get.back<void>(),
              borderRadius: BorderRadius.circular(9999),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(
                    Icons.arrow_back,
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

/// SH5 — section card: surface `rgb(26, 44, 66)`, `r12px`,
/// `rgba(199, 196, 216, 0.1)` hairline.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NexoraColors.settingsRowFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NexoraColors.devicesRowBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// SH6 — section heading: `22px` `w500` `rgb(248, 249, 255)`.
class SettingsSectionHeading extends StatelessWidget {
  const SettingsSectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: NexoraTextStyles.settingsRowTitle);
  }
}

/// SH7 — body / secondary line: `14px` `rgb(199, 196, 216)`.
class SettingsBodyLine extends StatelessWidget {
  const SettingsBodyLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: NexoraTextStyles.settingsRowDescription);
  }
}

/// SH8/SH9 — a row's leading glyph, `24px`. The colour is the row's own,
/// drawn only from `settings.md`'s measured set for an active row (SH8), or
/// the tertiary/inactive glyph colour `rgb(119, 117, 135)`
/// (`NexoraColors.devicesMuted` — the default here, SH9).
class SettingsRowGlyph extends StatelessWidget {
  const SettingsRowGlyph(
    this.icon, {
    super.key,
    this.color = NexoraColors.devicesMuted,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 24, color: color);
  }
}

/// SH10 — state label: `12px` `w500`; says what a row currently *is*
/// (`devices.md` elements 14/22/30/38, via `settings-storage.md`'s
/// already-approved borrow). Colour is the state's own —
/// [NexoraColors.settingsBodyText] is the neutral default, the same value
/// `settings-storage.md` SS9/SS16/SS20 use for this exact treatment in the
/// settings palette.
class SettingsStateLabel extends StatelessWidget {
  const SettingsStateLabel(
    this.text, {
    super.key,
    this.color = NexoraColors.settingsBodyText,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }
}

/// SH11 — machine value: `JetBrains Mono`, `14px` (`settings.md`'s measured
/// font family, 4 uses). Colour defaults to
/// [NexoraColors.settingsBodyText] — the settings body colour — and may be
/// overridden with another `settings.md`/`settings-storage.md`-measured
/// value where a screen's own contract calls for one (e.g. the primary text
/// colour for an emphasised numeral).
class SettingsMachineValue extends StatelessWidget {
  const SettingsMachineValue(
    this.text, {
    super.key,
    this.color = NexoraColors.settingsBodyText,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontFamily: 'JetBrains Mono',
        color: color,
      ),
    );
  }
}

/// SH12 — selection state glyph: `radio_button_checked` /
/// `radio_button_unchecked`, `24px` (`devices.md` element 21 / `dashboard.md`
/// element 33, via `settings-storage.md` SS14-16). Checked uses
/// `rgb(195, 192, 255)` (`NexoraColors.welcomeHeading` — settings' own
/// active-icon colour, elements 24/29); unchecked uses `rgb(119, 117, 135)`
/// (`NexoraColors.devicesMuted` — settings' own inactive glyph colour,
/// elements 12/17/22/27/32).
class SettingsSelectionGlyph extends StatelessWidget {
  const SettingsSelectionGlyph({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      size: 24,
      color: selected
          ? NexoraColors.welcomeHeading
          : NexoraColors.devicesMuted,
    );
  }
}

/// SH13 — empty / error line: one centred line at `14px`
/// `rgb(199, 196, 216)` (GAP-002's approved treatment, via
/// `settings-storage.md` SS27/SS28). A failed read of one section never
/// clears another, and never clears a setting the user themselves chose —
/// this widget only renders the line; which section shows it is the caller's
/// own state handling.
class SettingsEmptyOrErrorLine extends StatelessWidget {
  const SettingsEmptyOrErrorLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: NexoraTextStyles.settingsRowDescription,
      ),
    );
  }
}
