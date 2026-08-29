// features/messaging/domain — conflict resolution (E05-T05).
//
// FR-MSG-007 / EARS-MSG-4: when two devices (this device and a peer, or two
// of the user's own devices via sync) disagree about a piece of
// security-relevant state, always resolve to the more security-restrictive
// value, never the more permissive one.
//
// Four small, independently named, independently tested pure functions —
// deliberately NOT a generic "conflict resolution framework". The epic's own
// risk note (epic.md) is explicit that a single generic "restrictive wins"
// rule does not obviously generalize to all four pairs without being tested
// against each pair by name; see the trust-state ordering note below for a
// concrete case where a naive two-value assumption would have been wrong.
//
// This task only provides the resolution function once a conflict is
// already known to exist. It does NOT detect conflicts (T04's sync
// mechanism's job) and does NOT wire into E02's RelationshipRepository,
// E07's future group membership model, or E12's future session/revocation
// model — those integrations happen when those systems exist.
import 'package:nexora/features/trust/domain/relationship.dart';

class ConflictResolver {
  const ConflictResolver._();

  /// Trust-state precedence order, most restrictive first.
  ///
  /// E02's `relationship.dart` (`RelationshipState`, `isConnectionPermitted`)
  /// defines two facts but no full ordering across all four values:
  ///   - `blocked` always denies, regardless of the other side.
  ///   - `trusted` and `allowed` are treated as equally "permitting" for
  ///     connection purposes; `unknown` does not permit.
  /// Neither of those facts alone orders all four values, so this task
  /// defines the ordering explicitly here (per the task's own §6 risk note
  /// and §5 contract instruction), rather than inventing a second,
  /// possibly-inconsistent copy inside E02's file (out of this task's
  /// `files:` scope regardless):
  ///
  ///   blocked > unknown > allowed > trusted
  ///
  /// Rationale: `blocked` is an explicit, deliberate denial — the strongest
  /// restriction. `unknown` is the default "no information yet" state, which
  /// also does not permit a connection, but is a weaker restriction than an
  /// explicit block (it can resolve to permission with no state change,
  /// where escaping `blocked` requires an explicit unblock). `allowed` and
  /// `trusted` both permit connections, but `trusted` is strictly more
  /// permissive than `allowed`: per E02-T01, a `trusted` device additionally
  /// auto-accepts requests, skipping normal authentication (FR-TRUST-004) —
  /// a capability `allowed` does not grant. So `allowed` is the more
  /// restrictive of the two permitting states.
  static const List<RelationshipState> _trustRestrictiveness = [
    RelationshipState.blocked,
    RelationshipState.unknown,
    RelationshipState.allowed,
    RelationshipState.trusted,
  ];

  /// Resolves a trust-state conflict: the more security-restrictive of [a]
  /// and [b] wins, per [_trustRestrictiveness]. `blocked` beats everything;
  /// among non-blocked states, the documented ordering above applies.
  static RelationshipState resolveTrust(RelationshipState a, RelationshipState b) {
    final aRank = _trustRestrictiveness.indexOf(a);
    final bRank = _trustRestrictiveness.indexOf(b);
    return aRank <= bRank ? a : b;
  }

  /// Resolves a location-sharing conflict: sharing stops (`false`) if either
  /// side disagrees. Returns `false` (off) if either input is `false`.
  static bool resolveLocationSharing(bool a, bool b) => a && b;

  /// Resolves a revocation conflict: a revoked credential/session stays
  /// revoked. `true` means revoked. Returns `true` if either input is `true`.
  static bool resolveRevocation(bool a, bool b) => a || b;

  /// Resolves a group-membership conflict: removal wins over membership.
  /// `true` means removed. Returns `true` if either input is `true`.
  static bool resolveMembership(bool a, bool b) => a || b;
}
