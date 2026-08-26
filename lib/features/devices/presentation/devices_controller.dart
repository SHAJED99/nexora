// features/devices/presentation — DevicesController (E02-T02).
//
// Built against design/screens/devices.md. No live device discovery exists
// yet (E04), so the list is exactly what `RelationshipRepository` already
// holds locally — empty until this side has evaluated at least one device.
import 'package:get/get.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

class DevicesController extends GetxController {
  DevicesController(this._repository, this._blockUseCase);

  final RelationshipRepository _repository;
  final BlockUseCase _blockUseCase;

  final RxList<Relationship> relationships = <Relationship>[].obs;
  final RxBool loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Re-reads every stored relationship from `RelationshipRepository`.
  Future<void> load() async {
    loading.value = true;
    relationships.value = await _repository.listAll();
    loading.value = false;
  }

  /// Kebab menu's "Block" action (FR-BLOCK-001) — the design contract's
  /// generic `more_vert` button, element 12/20/28/36.
  Future<void> block(String deviceId) async {
    await _blockUseCase(deviceId);
    await load();
  }

  /// "Verify" button (element 31, Unknown rows only) — promotes an Unknown
  /// relationship to Allowed. The richer trust-config flow FR-TRUST-006
  /// would otherwise gate is not built yet; this is the minimal safe
  /// transition the design contract shows (task §3).
  Future<void> verify(String deviceId) async {
    await _repository.upsert(deviceId, RelationshipState.allowed);
    await load();
  }

  /// "Discover" button (element 6) — intentionally a no-op. Real device
  /// discovery is E04's job; see OQ-E02-T02-1 / design/gaps.md GAP-004.
  void discover() {
    Get.snackbar(
      'Discover',
      "Device discovery isn't available yet.",
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
