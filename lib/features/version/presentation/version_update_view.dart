// features/version/presentation — built against
// design/screens/version-update-required.md (E14-T04). Elements referenced
// by number below are that contract's "Elements — the build checklist"
// table (VUR1-VUR4). Every token cited below is reused verbatim from an
// already-measured `NexoraColors`/`NexoraTextStyles` value per that
// contract's own §Tokens (each cross-checked against the contract's RGB
// value before reuse — no new token invented here).
//
// **Non-dismissible, structurally (task file §3/§6 — this task's single
// biggest risk).** `PopScope(canPop: false)` refuses BOTH the system back
// gesture and the Android hardware/software back button — no
// `onPopInvokedWithResult` callback is supplied, so there is no code path
// that can pop this route. There is also no close icon, no secondary
// button, and no gesture detector anywhere else in this tree: the contract's
// own "nothing else on this screen to tap" (§States, `default`) is honoured
// by literally not building anything else, not by disabling something that
// looks tappable.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'version_update_controller.dart';

class VersionUpdateView extends GetView<VersionUpdateController> {
  const VersionUpdateView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: NexoraColors.welcomeBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // VUR1 — `warning` icon, welcome's 60x60 sizing, devices'
                // `warning` colour (element 29, rgb(245,158,11)).
                const Icon(
                  Icons.warning,
                  size: 60,
                  color: NexoraColors.devicesUnknownAmber,
                ),
                const SizedBox(height: 24),
                // VUR2 — 22px/w500/rgb(203,219,245), welcome's own subheading
                // treatment (element 3) — an exact style-object match.
                const Text(
                  'Update required',
                  textAlign: TextAlign.center,
                  style: NexoraTextStyles.welcomeSubheading,
                ),
                const SizedBox(height: 12),
                // VUR3 — 14px/rgb(211,228,254), welcome's own body treatment
                // (element 4) — an exact style-object match. States plainly
                // that local data is preserved (FR-VER-009).
                const Text(
                  'A new version of Nexora is required to continue. Your '
                  'messages, files and settings are safe and will still be '
                  'here after you update.',
                  textAlign: TextAlign.center,
                  style: NexoraTextStyles.welcomeBody,
                ),
                const Spacer(flex: 3),
                // VUR4 — 326x58 fully-rounded (r9999px) button, welcome's own
                // shape (element 5); devices' non-branded primary fill
                // (element 6, rgb(53,37,205)) with a 12px/w500/white label —
                // an exact style-object match to `devicesDiscoverLabel`.
                // The one and only affordance on this screen.
                SizedBox(
                  width: 326,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: controller.startImmediateUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NexoraColors.loginBrand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(29),
                      ),
                    ),
                    child: const Text(
                      'Update now',
                      style: NexoraTextStyles.devicesDiscoverLabel,
                    ),
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
