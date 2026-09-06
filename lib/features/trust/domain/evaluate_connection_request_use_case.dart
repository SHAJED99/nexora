// features/trust/domain — evaluate an incoming connection request
// (E02-T01). FR-TRUST-003/004/005: this side's independent evaluation,
// never derived from the other side's own stored evaluation.
//
// E13-T02 (FR-ABUSE-001): gains an optional `RateLimiter` admission check
// (EARS-ABUSE-4), gating how OFTEN this evaluation may run for a given
// remote `deviceId` — never what it returns when it does run (task §4).
// `_rateLimiter` is deliberately nullable and OPTIONAL, matching the two
// existing production call sites (`MessagingStack.create`,
// `DevicesController`'s default fallback) which are both outside this
// task's `files:` fence and so cannot be edited to pass one through; when
// omitted, the gate is skipped and behavior is byte-for-byte unchanged from
// before this task (see task's Run log Deviations for the follow-up this
// leaves open).
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

class EvaluateConnectionRequestUseCase {
  final RelationshipRepository _repository;
  final RateLimiter? _rateLimiter;

  /// Bucket key scheme + limit chosen by this task (§3): keyed by the
  /// REMOTE device id being evaluated, since the abuse shape being bounded
  /// is "how often may any single peer be evaluated" — a caller re-request
  /// after a mesh dropout should still get through comfortably, so the
  /// window is short and the ceiling generous relative to that legitimate
  /// case (Run log documents the full reasoning).
  static const int _maxConnectionRequestsPerWindow = 10;
  static const Duration _connectionRequestWindow = Duration(minutes: 1);

  EvaluateConnectionRequestUseCase(this._repository, {this._rateLimiter});

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
    if (_rateLimiter != null) {
      final admitted = await _rateLimiter.allow(
        'connection_request:$deviceId',
        maxCount: _maxConnectionRequestsPerWindow,
        window: _connectionRequestWindow,
      );
      if (!admitted) {
        // EARS-ABUSE-4: deny WITHOUT consulting `RelationshipRepository` —
        // reuses the existing `blocked` state (task §3: "mirroring the
        // existing blocked/unknown result shape, not a thrown exception").
        // `blocked` is deliberately chosen over `unknown`: every existing
        // caller already treats `blocked` as "refuse" (e.g.
        // `MessagingStack` only refuses on `RelationshipState.blocked`),
        // so a rate-limited caller is actually denied end-to-end without
        // any caller needing a new case added to its handling — `unknown`
        // would silently let those callers proceed. This never touches
        // the stored `relationships` row, so it does not persist a false
        // "blocked" verdict.
        return RelationshipState.blocked;
      }
    }
    final existing = await _repository.get(deviceId);
    // A previously-recorded state (trusted, allowed, or blocked) is always
    // returned as-is — a blocked device must never evaluate as merely
    // "unknown" (review fix, E02-T01: that would be indistinguishable from
    // a never-seen device to any future caller, defeating FR-BLOCK-001).
    // Only a device with no relationship row at all is genuinely Unknown.
    if (existing != null) {
      return existing.state;
    }
    // No FR-TRUST-006 config wired yet — defaults to Unknown regardless of
    // the flags' values until E02-T03 gives them real meaning.
    return RelationshipState.unknown;
  }
}
