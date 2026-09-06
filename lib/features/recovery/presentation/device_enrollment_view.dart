// features/recovery/presentation — built against
// design/screens/device-enrollment.md (GAP-028, source: derived).
//
// Per that contract's own header: the frame/icon-size/heading-body-sizing/
// button-shape are `welcome.md`'s (elements 1, 3, 4, 5); the non-branded
// primary button fill + `warning` status colour are `devices.md`'s
// (elements 6, 29). Every token below is already named in
// `core/design/tokens.dart` — this screen introduces none of its own
// (measured values matched exactly: welcomeTextAccent ==
// rgb(218,215,255), welcomeSubheading == rgb(203,219,245), welcomeBody's
// colour == rgb(211,228,254), loginBrand == rgb(53,37,205),
// devicesUnknownAmber == rgb(245,158,11), devicesDiscoverLabel == the
// 12px/w500/white button-label style).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:on_process_button_widget/on_process_button_widget.dart';
import 'device_enrollment_controller.dart';

class DeviceEnrollmentView extends GetView<DeviceEnrollmentController> {
  const DeviceEnrollmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.welcomeBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Obx(() {
            final content = _contentFor(controller.state.value, controller);
            return Column(
              children: [
                const Spacer(flex: 3),
                Icon(content.icon, size: 60, color: content.iconColor),
                const SizedBox(height: 24),
                Text(
                  content.heading,
                  textAlign: TextAlign.center,
                  style: NexoraTextStyles.welcomeSubheading,
                ),
                const SizedBox(height: 12),
                Text(
                  content.body,
                  textAlign: TextAlign.center,
                  style: NexoraTextStyles.welcomeBody,
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: OnProcessButtonWidget(
                    backgroundColor: NexoraColors.loginBrand,
                    borderRadius: BorderRadius.circular(29),
                    onTap: () async {
                      content.onPressed();
                      return null;
                    },
                    child: Text(
                      content.buttonLabel,
                      style: NexoraTextStyles.devicesDiscoverLabel,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _StateContent {
  const _StateContent({
    required this.icon,
    required this.iconColor,
    required this.heading,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String heading;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;
}

/// Elements DE1-DE4 (design contract's "Elements — the build checklist"),
/// one variant per state. Copy is verbatim from that contract's own §Copy.
_StateContent _contentFor(
  EnrollmentState state,
  DeviceEnrollmentController controller,
) {
  switch (state) {
    case EnrollmentState.waiting:
      return _StateContent(
        icon: Icons.hub,
        iconColor: NexoraColors.welcomeTextAccent,
        heading: 'Looking for a trusted device…',
        body: 'Ask a trusted device nearby to approve this one. '
            'Code: [pairing code]',
        buttonLabel: 'Continue without history',
        onPressed: controller.continueWithoutHistory,
      );
    case EnrollmentState.denied:
      return _StateContent(
        icon: Icons.hub,
        iconColor: NexoraColors.welcomeTextAccent,
        heading: 'No trusted device responded',
        body: 'You can try again later from Settings, or continue without '
            'your history.',
        buttonLabel: 'Continue without history',
        onPressed: controller.continueWithoutHistory,
      );
    case EnrollmentState.noRecoveryNotice:
      return _StateContent(
        icon: Icons.warning,
        iconColor: NexoraColors.devicesUnknownAmber,
        heading: "You're starting fresh",
        body: 'Without an existing device to vouch for this one, messages '
            "and files from before today can't be recovered here. This is "
            'expected — not an error.',
        buttonLabel: 'Continue',
        onPressed: controller.continueToDashboard,
      );
  }
}
