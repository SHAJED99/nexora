// features/welcome/presentation — built against design/screens/welcome.md.
// Structure/copy/primary action match the contract; pixel-perfect matching
// is a later design-fidelity pass (E00-T05 brief), not genesis.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'welcome_controller.dart';

class WelcomeView extends GetView<WelcomeController> {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.welcomeBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const Icon(Icons.hub, size: 60, color: NexoraColors.welcomeTextAccent),
              const SizedBox(height: 12),
              const Text(
                'NEXORA',
                style: NexoraTextStyles.welcomeHeading,
              ),
              const SizedBox(height: 24),
              const Text(
                'Connect beyond the network.',
                textAlign: TextAlign.center,
                style: NexoraTextStyles.welcomeSubheading,
              ),
              const SizedBox(height: 12),
              const Text(
                'Secure communication that keeps working when the '
                'network doesn\'t.',
                textAlign: TextAlign.center,
                style: NexoraTextStyles.welcomeBody,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: controller.continueWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NexoraColors.welcomeButtonBg,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.g_mobiledata,
                          color: NexoraColors.welcomeButtonText),
                      const SizedBox(width: 8),
                      const Text(
                        'Continue with Google',
                        style: NexoraTextStyles.buttonLabel,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: NexoraColors.welcomeTextPrimary),
                  SizedBox(width: 6),
                  Text(
                    'End-to-end encrypted mesh',
                    style: NexoraTextStyles.welcomeCaption,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
