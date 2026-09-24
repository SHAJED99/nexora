// features/settings/account/presentation -- SO1-SO7
// (design/screens/sign-out-confirm.md, GAP-039). `welcome.md`-shaped
// centred single-focus layout, NOT E15-T03's settings scaffold (task §4 --
// "does NOT compose the settings scaffold on sign-out-confirm"). No
// `AlertDialog`, no bottom sheet, no snackbar-with-action anywhere in this
// file (task §4, `sign-out-confirm.md` §Prohibition 1) -- a full route,
// pushed like any other screen, same structural choice
// `version_update_view.dart` already made for a similarly blocking moment.
//
// **Dismissible, unlike `version_update_view.dart`.** SO1's back
// affordance and the system back gesture both pop -- this screen is a
// legitimate "no" to a destructive action, not a mandatory block, so
// neither is suppressed (`sign-out-confirm.md` §Elements, SO1's own note:
// "unlike version-update-required.md, this screen IS dismissible").
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/l10n/app_strings.dart';
import 'package:nexora/core/design/tokens.dart';

import 'sign_out_confirm_controller.dart';

class SignOutConfirmView extends GetView<SignOutConfirmController> {
  const SignOutConfirmView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.welcomeBg,
      body: SafeArea(
        child: Column(
          children: [
            const _BackRow(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // SO2 -- `warning` glyph, welcome's icon size,
                    // devices' `warning` colour (same VUR1 choice
                    // `version_update_view.dart` already made for this
                    // exact glyph/colour pairing).
                    const Icon(
                      Icons.warning,
                      size: 60,
                      color: NexoraColors.devicesUnknownAmber,
                    ),
                    const SizedBox(height: 24),
                    // SO3 -- `welcome.md`'s centred heading treatment. The
                    // same "a sentence-length derived heading uses
                    // welcome's SUBheading treatment, not the 57px
                    // NEXORA-scale heading" choice
                    // `version_update_view.dart`'s own VUR2 already made
                    // (this screen's only heading-scale text, so the probe
                    // dumper's own order-of-first-appearance heuristic
                    // reports it as `heading:1` regardless of which of
                    // welcome's two heading styles is used here).
                    Text(
                      context.l10n.signOutTitle,
                      textAlign: TextAlign.center,
                      style: NexoraTextStyles.welcomeSubheading,
                    ),
                    const SizedBox(height: 16),
                    // SO4 -- the loss list, `welcome.md` body treatment.
                    Text(
                      context.l10n.signOutIntro,
                      textAlign: TextAlign.center,
                      style: NexoraTextStyles.welcomeBody,
                    ),
                    const SizedBox(height: 12),
                    const _LossList(),
                    const SizedBox(height: 16),
                    // SO5 -- same body treatment.
                    Text(
                      context.l10n.signOutIrreversible,
                      textAlign: TextAlign.center,
                      style: NexoraTextStyles.welcomeBody,
                    ),
                    const SizedBox(height: 16),
                    // The line every future edit of this screen must never
                    // drop -- task §6 Risks: without it, a user reasonably
                    // assumes signing back in restores what they had,
                    // which is exactly what `FR-AUTH-008` says will not
                    // happen.
                    Text(
                      context.l10n.signOutNewIdentity,
                      textAlign: TextAlign.center,
                      style: NexoraTextStyles.welcomeBody,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
              child: Obx(
                () => Column(
                  children: [
                    // SO6 -- `welcome.md`'s stacked primary button shape;
                    // fill/label pending `GAP-035`/`GAP-039`'s unresolved
                    // destructive-colour fork, so this reuses the SAME
                    // neutral, non-branded primary treatment
                    // `version_update_view.dart`'s own VUR4 already
                    // established for an equally serious full-screen
                    // action (task §4/§8 -- no destructive colour
                    // asserted). F3 (epic tracker carried-forward,
                    // `SignOutConfirmController`'s own header) --
                    // structurally disabled (`onPressed: null`) while
                    // [SignOutConfirmController.inProgress] is `true`, so
                    // a double tap cannot reach `confirm()` a second time.
                    SizedBox(
                      width: 326,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: controller.inProgress.value
                            ? null
                            : controller.confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NexoraColors.loginBrand,
                          disabledBackgroundColor: NexoraColors.loginBrand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(29),
                          ),
                        ),
                        child: Text(
                          context.l10n.signOutConfirm,
                          style: NexoraTextStyles.devicesDiscoverLabel,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // SO7 -- the same button shape, neutral treatment,
                    // stacked below SO6. Built from tokens already used
                    // elsewhere in this palette (`settingsRowFill` fill,
                    // `devicesRowBorder` hairline -- the same neutral card
                    // surface `SettingsSectionCard` already uses) rather
                    // than a new colour.
                    SizedBox(
                      width: 326,
                      height: 58,
                      child: OutlinedButton(
                        onPressed: controller.inProgress.value
                            ? null
                            : controller.cancel,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: NexoraColors.settingsRowFill,
                          side: const BorderSide(
                            color: NexoraColors.devicesRowBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(29),
                          ),
                        ),
                        child: Text(
                          context.l10n.cancel,
                          style: NexoraTextStyles.devicesDiscoverLabel,
                        ),
                      ),
                    ),
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

/// SO4's own five loss-category lines, verbatim from `sign-out-confirm.md`
/// §Copy -- no bullet glyph prepended (that would alter the verbatim
/// string; this app's own welcome-shaped screens draw no bullet marker
/// anywhere) and no line dropped or reordered (task §6 Risks: "the loss
/// list is long and exact").
class _LossList extends StatelessWidget {
  const _LossList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final line in context.l10n.signOutLossList)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: NexoraTextStyles.welcomeBody,
            ),
          ),
      ],
    );
  }
}

/// SO1 -- 40×40 `r9999px` back affordance, `arrow_back`, `welcome.md`'s own
/// `welcomeHeading` colour (the same value `settings_sub_screen_scaffold
/// .dart`'s own `_BackRow` uses for the identical control). Present because
/// -- unlike `version_update_view.dart` -- this screen IS dismissible;
/// cancelling is a legitimate outcome (`sign-out-confirm.md` §Elements).
class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 20, 0),
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
