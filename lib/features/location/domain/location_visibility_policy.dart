// features/location/domain — the pure four-condition AND (E09-T02).
//
// `FR-LOC-003` (this epic's headline requirement): a peer's location is
// visible only when ALL of the following hold —
//   1. connected      — `isConnectionPermitted(local, remote)` (FR-TRUST-005)
//   2. authorized     — the peer is not blocked and its state is `trusted`
//                        or `allowed`; `unknown` is not authorized
//   3. global-on      — `FR-LOC-001`
//   4. per-user-on    — `FR-LOC-002`, additive to (3), never a substitute
//
// This function performs no I/O — the repository fetches, this decides
// (task §2). The global/per-user combination is delegated to
// `ConflictResolver.resolveLocationSharing` (E05-T05, `FR-MSG-007`'s
// LOCATION-OFF > LOCATION-ON precedence) rather than re-derived here (task
// §4): a second, private copy of a security precedence rule is how the two
// copies diverge.
library;

import 'package:nexora/features/location/domain/location_visibility.dart';
import 'package:nexora/features/messaging/domain/conflict_resolver.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

class LocationVisibilityPolicy {
  const LocationVisibilityPolicy._();

  /// Evaluates `FR-LOC-003`'s four-condition AND for one peer.
  ///
  /// [localState] — this device's stored `RelationshipState` for the peer
  /// (`RelationshipRepository.get`).
  /// [remoteState] — the peer's reported state for this device
  /// (`FR-TRUST-005` is two-sided). Callers pass
  /// `RelationshipState.unknown` when the remote side has not been learned
  /// — `unknown` is not authorized, the security-restrictive reading
  /// (`OQ-E09-T02-1`: single-sided evaluation accepted for v1).
  /// [globalEnabled] — `LocationSettingsRepository.readGlobalEnabled()`.
  /// [peerEnabled] — `LocationSettingsRepository.readPeerEnabled(peer)`.
  ///
  /// No short-circuit shortcut changes the reported reason: every condition
  /// is evaluated, and when more than one fails, the most
  /// security-restrictive/specific one is reported, in this fixed order:
  /// `blocked > notAuthorized > notConnected > globalOff > peerOff`.
  ///
  /// `notAuthorized` is checked ahead of `notConnected` deliberately:
  /// `authorized` depends only on `localState` (what this device itself has
  /// recorded for the peer — the thing this device can unilaterally see and
  /// fix), while `connected` is the full two-sided
  /// `isConnectionPermitted(local, remote)` check, which by construction
  /// can only fail *in addition to* a failing `authorized` whenever
  /// `localState` itself does not permit — `authorized` is a strict
  /// prerequisite of `connected`, never the other way around. Reporting the
  /// more specific, locally-actionable `notAuthorized` in that overlap
  /// (rather than the vaguer `notConnected`) is what makes `notConnected`
  /// reachable at all: it is reported only when this device's own state
  /// already permits and the peer's reported state is the sole remaining
  /// obstacle.
  static LocationVisibility evaluate({
    required RelationshipState localState,
    required RelationshipState remoteState,
    required bool globalEnabled,
    required bool peerEnabled,
  }) {
    final blocked = localState == RelationshipState.blocked ||
        remoteState == RelationshipState.blocked;

    // "authorized": the peer is not blocked and its (local-side) state is
    // `trusted` or `allowed` — `unknown` is not authorized. Checked
    // explicitly on `localState` rather than merely inferred from
    // `connected`, so `notAuthorized` is distinguishable from
    // `notConnected` (task §2).
    final authorized = !blocked &&
        (localState == RelationshipState.trusted ||
            localState == RelationshipState.allowed);

    final connected = !blocked && isConnectionPermitted(localState, remoteState);

    // FR-LOC-002 is additive, never a substitute for FR-LOC-001 — delegated
    // to ConflictResolver.resolveLocationSharing rather than re-derived
    // (`a && b`, but this task's first production caller of that function).
    final sharingAllowed =
        ConflictResolver.resolveLocationSharing(globalEnabled, peerEnabled);

    if (blocked) {
      return const LocationVisibility.hidden(LocationUnavailableReason.blocked);
    }
    if (!authorized) {
      return const LocationVisibility.hidden(
        LocationUnavailableReason.notAuthorized,
      );
    }
    if (!connected) {
      return const LocationVisibility.hidden(
        LocationUnavailableReason.notConnected,
      );
    }
    if (!sharingAllowed) {
      // globalOff outranks peerOff (task §5 precedence) — when both are
      // off, report globalOff. `sharingAllowed` is exactly
      // ConflictResolver.resolveLocationSharing(globalEnabled, peerEnabled)
      // ( == globalEnabled && peerEnabled), so `!globalEnabled` correctly
      // distinguishes "global is the failing side" from "only peer is".
      return LocationVisibility.hidden(
        !globalEnabled
            ? LocationUnavailableReason.globalOff
            : LocationUnavailableReason.peerOff,
      );
    }

    return const LocationVisibility.visible();
  }
}
