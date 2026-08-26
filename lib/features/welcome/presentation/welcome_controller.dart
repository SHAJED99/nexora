// features/welcome/presentation — GetX controller (ADR-0002).
import 'package:get/get.dart';

class WelcomeController extends GetxController {
  /// "Continue with Google" — hands off to /login, which performs the
  /// actual (stubbed) sign-in and Drift write.
  void continueWithGoogle() {
    Get.toNamed('/login');
  }
}
