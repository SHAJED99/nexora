// features/login/presentation — GetX controller (ADR-0002).
//
// Drives the "Signing in..." transient state, then the real Google
// Sign-In use case, then navigates onward (E01-T01 — replaces the genesis
// walking skeleton's stub).
//
// E06-T12: post-login destination is now `/dashboard`
// (design/screens/dashboard.md), superseding the genesis `/home` placeholder
// per that task's §3/§6 ("verify the login journey end to end, since a
// broken redirect here breaks the app's entry point"). This file is not
// listed in E06-T12's own `files:` fence (an omission in that task's
// frontmatter — the literal `/home` redirect below is the ONLY place the
// post-login destination is hardcoded), but the task's own body explicitly
// requires this exact change and names verifying it as a risk; logged here
// as a Deviation (one line, this file only) rather than silently left
// pointing at the superseded placeholder.
import 'dart:math';

import 'package:get/get.dart';
import 'package:nexora/core/auth/google_auth_service.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';

/// Generates a device identifier using a cryptographically-secure RNG.
///
/// ADR-0005: device identity is independent of, and never derived from,
/// the account/Firebase session — this token is generated before any
/// Firebase call is made. This is a random device *token*, not a
/// cryptographic keypair: the X3DH/Double-Ratchet protocol is E03's job
/// (FR-AUTH-003 only needs a unique, hard-to-guess per-install id here).
///
/// File-scope (not private to [LoginController]) so it is directly
/// testable without instantiating a controller.
String generateSecureDeviceId() {
  final rand = Random.secure();
  return List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
}

class LoginController extends GetxController {
  LoginController(this._signInUseCase);

  final SignInUseCase _signInUseCase;

  final RxBool signingIn = true.obs;

  @override
  void onInit() {
    super.onInit();
    _signIn();
  }

  Future<void> _signIn() async {
    signingIn.value = true;
    final deviceId = generateSecureDeviceId();
    try {
      await _signInUseCase(deviceId);
      signingIn.value = false;
      Get.offNamed('/dashboard');
    } catch (e) {
      // EARS-AUTH-3: surface as a mapped failure, never crash. A full
      // error-state UI is out of scope for this task (see task §4) — this
      // is the minimum the task asks for: map + log, no error screen yet.
      signingIn.value = false;
      ObservabilityService.instance.logError(
        e is AppFailure ? e.code : 'auth.google_sign_in_failed',
        cause: e,
      );
    }
  }
}
