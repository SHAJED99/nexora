// features/login/presentation — built against design/screens/login.md.
// Structure/copy/primary state match the contract; pixel-perfect matching
// is a later design-fidelity pass (E00-T05 brief), not genesis.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.loginBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hub, size: 20, color: NexoraColors.loginBrand),
                  const SizedBox(width: 8),
                  const Text('NEXORA', style: NexoraTextStyles.loginBrandLabel),
                ],
              ),
              const Spacer(flex: 2),
              // `E01-B02`: the heading is no longer a `const` that claims
              // sign-in is in progress regardless of what happened. On
              // failure it states the failure instead, using the project's
              // established `Couldn't <thing>. Try again.` wording
              // (`dashboard.md` DX8, `group-create.md` GC16,
              // `group-manage.md` GM19, `settings-storage.md` SS28) and no
              // invented error colour (GAP-009's precedent).
              Obx(
                () => Text(
                  controller.signInFailed.value
                      ? "Couldn't sign in. Try again."
                      : 'Signing in with Google...',
                  textAlign: TextAlign.center,
                  style: NexoraTextStyles.loginHeading,
                ),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.lock, size: 24, color: NexoraColors.loginBrand),
              const SizedBox(height: 16),
              const Text(
                'Authentication only. Your messages stay end-to-end '
                'encrypted and never pass through Google.',
                textAlign: TextAlign.center,
                style: NexoraTextStyles.loginBody,
              ),
              const Spacer(flex: 3),
              Obx(() {
                if (controller.signingIn.value) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: CircularProgressIndicator(
                      color: NexoraColors.loginBrand,
                    ),
                  );
                }
                if (controller.signInFailed.value) {
                  // `LG7`. A plain `TextButton`, deliberately NOT
                  // `OnProcessButtonWidget`: this is the only way out of a
                  // dead end, so it must not depend on a widget whose taps
                  // are gated on internal state (`E01-B03`).
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: TextButton(
                      onPressed: controller.retry,
                      child: const Text(
                        'Try again',
                        style: NexoraTextStyles.loginBrandLabel,
                      ),
                    ),
                  );
                }
                return const SizedBox(height: 32);
              }),
            ],
          ),
        ),
      ),
    );
  }
}
