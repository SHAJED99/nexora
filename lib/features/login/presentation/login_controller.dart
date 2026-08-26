// features/login/presentation — GetX controller (ADR-0002).
//
// Drives the "Signing in..." transient state, then the real (stubbed)
// sign-in use case, then navigates onward. This is the walking skeleton's
// UI -> controller -> use case -> repository -> Drift wiring (E00-T05).
import 'dart:math';

import 'package:get/get.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';

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
    final deviceId = _generateDeviceId();
    await _signInUseCase(deviceId);
    signingIn.value = false;
    Get.offNamed('/home');
  }

  String _generateDeviceId() {
    final rand = Random();
    return List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
  }
}
