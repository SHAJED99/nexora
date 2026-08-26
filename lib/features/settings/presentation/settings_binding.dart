// features/settings/presentation — per-route GetX binding (E02-T03).
//
// SettingsController has no dependencies of its own (it's a pure
// navigation menu — see task §2/§3), so this binding only registers it.
import 'package:get/get.dart';
import 'package:nexora/features/settings/presentation/settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(SettingsController.new);
  }
}
