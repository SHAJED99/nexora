// features/trust/domain — evaluate an incoming connection request
// (E02-T01). FR-TRUST-003/004/005: this side's independent evaluation,
// never derived from the other side's own stored evaluation.
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

class EvaluateConnectionRequestUseCase {
  final RelationshipRepository _repository;

  EvaluateConnectionRequestUseCase(this._repository);

  /// Returns this side's independent evaluation of a connection request
  /// from [deviceId].
  ///
  /// FR-TRUST-004: a device already stored as [RelationshipState.trusted]
  /// auto-accepts, skipping normal authentication.
  ///
  /// [autoAcceptSpecific] and [requireAuthForUnknown] are FR-TRUST-006
  /// parameters for a future settings UI (E02-T03) to pass real
  /// configuration through — no persisted config exists yet, so both
  /// default off and this task's callers rely on the defaults.
  Future<RelationshipState> call(
    String deviceId, {
    bool autoAcceptSpecific = false,
    bool requireAuthForUnknown = false,
  }) async {
    final existing = await _repository.get(deviceId);
    if (existing?.state == RelationshipState.trusted) {
      return RelationshipState.trusted;
    }
    // No FR-TRUST-006 config wired yet — defaults to Unknown regardless of
    // the flags' values until E02-T03 gives them real meaning.
    return RelationshipState.unknown;
  }
}
