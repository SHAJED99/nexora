// features/devices/presentation — per-route GetX binding (E02-T02).
//
// `RelationshipRepository`/`BlockUseCase` are registered as permanent
// singletons in `app/bindings.dart` (shared across the trust feature);
// this binding only owns the screen's own controller, per
// `docs/conventions.md` "Project structure".
import 'package:get/get.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';

class DevicesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => DevicesController(
        Get.find<RelationshipRepository>(),
        Get.find<BlockUseCase>(),
      ),
    );
  }
}
