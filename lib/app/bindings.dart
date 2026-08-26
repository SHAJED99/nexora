// app/bindings.dart — DI via Get.put()/Get.lazyPut() (ADR-0002).
//
// A single global binding for the walking skeleton: one AppDatabase
// instance shared by every repository, plus per-feature controllers. Later
// epics likely split this into per-route bindings as feature count grows;
// genesis keeps one binding since there are only two real screens.
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/home/presentation/home_controller.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';
import 'package:nexora/features/welcome/presentation/welcome_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppDatabase(), permanent: true);
    Get.put(
      DeviceIdentityRepository(Get.find<AppDatabase>()),
      permanent: true,
    );
    Get.put(SignInUseCase(Get.find<DeviceIdentityRepository>()), permanent: true);

    Get.lazyPut(WelcomeController.new);
    Get.lazyPut(() => LoginController(Get.find<SignInUseCase>()));
    Get.lazyPut(
      () => HomeController(Get.find<DeviceIdentityRepository>()),
    );
  }
}
