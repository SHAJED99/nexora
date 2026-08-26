// features/trust/domain — FR-BLOCK-001 enforcement entry point (E02-T01).
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

class BlockUseCase {
  final RelationshipRepository _repository;

  BlockUseCase(this._repository);

  /// Marks [deviceId]'s relationship as blocked. Blocking prevents ALL
  /// direct communication in both directions (FR-BLOCK-001) — later
  /// communication epics (E04+) enforce this via
  /// `RelationshipRepository.isBlocked`.
  Future<void> call(String deviceId) {
    return _repository.upsert(deviceId, RelationshipState.blocked);
  }
}
