// features/home/presentation — genesis placeholder screen only.
//
// Not one of the 7 design-contracted screens (design/sources.yaml) — this
// is the walking skeleton's proof that the Drift write from /login is
// readable back, nothing more. The real post-auth destination
// (dashboard, per design/screens/) is a feature epic's job.
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';

class HomeController extends GetxController {
  HomeController(this._repository);

  final DeviceIdentityRepository _repository;

  final Rx<DeviceIdentity?> deviceIdentity = Rx<DeviceIdentity?>(null);

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    deviceIdentity.value = await _repository.latestDeviceIdentity();
  }
}
