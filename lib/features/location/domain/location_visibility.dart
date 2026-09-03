// features/location/domain — the decision types `LocationVisibilityPolicy`
// returns (E09-T02).
//
// `FR-LOC-003` is a hard four-condition AND. When it fails, the *reason* is
// not decoration: `design/screens/chat-location.md` renders a disabled
// picker row (state 1) for a policy that says no up front, and a
// `Location unavailable` card (state 5) for a share that stopped being
// permitted. A boolean cannot tell those apart, and the UI task
// (`E06-T18`) is forbidden from deciding it itself.
library;

/// Why a peer's location is not being shown. Declared in the exact order
/// the task's `## 5. Contract` data section specifies — see
/// `LocationVisibilityPolicy.evaluate`'s doc comment for the actual
/// most-security-restrictive-first reporting precedence
/// (`blocked > notAuthorized > notConnected > globalOff > peerOff`), which
/// is not the same as this enum's declaration order: `notAuthorized`
/// (this device's own recorded state for the peer) is a strict
/// prerequisite of `notConnected` (the full two-sided check), so it is
/// reported first whenever both would independently be true.
enum LocationUnavailableReason {
  /// The peer (or this device, from the peer's side) is blocked.
  /// `FR-LOC-004`.
  blocked,

  /// `isConnectionPermitted(local, remote)` is false for a reason other
  /// than an explicit block or this device's own `localState` — i.e. the
  /// peer's reported state (`remoteState`) is the sole remaining obstacle.
  /// See [notAuthorized] for the local-state failure, which is reported in
  /// preference to this one when both are true.
  notConnected,

  /// This device's own recorded state for the peer (`localState`) is not
  /// blocked but is not `trusted`/`allowed` either (i.e. `unknown`).
  /// `unknown` is not authorized.
  notAuthorized,

  /// `FR-LOC-001` — the app-wide sharing switch is off.
  globalOff,

  /// `FR-LOC-002` — this peer's own sharing switch is off (or was never
  /// configured, which reads as off).
  peerOff,
}

/// `LocationVisibilityPolicy.evaluate`'s result: either visible with no
/// reason, or hidden with exactly one [LocationUnavailableReason].
class LocationVisibility {
  final bool isVisible;
  final LocationUnavailableReason? reason;

  const LocationVisibility._({required this.isVisible, this.reason})
      : assert(
          (isVisible && reason == null) || (!isVisible && reason != null),
          'reason must be null iff isVisible',
        );

  /// All four of `FR-LOC-003`'s conditions hold.
  const LocationVisibility.visible() : this._(isVisible: true);

  /// At least one of `FR-LOC-003`'s conditions failed; [reason] names the
  /// most security-restrictive one that did.
  const LocationVisibility.hidden(LocationUnavailableReason reason)
      : this._(isVisible: false, reason: reason);

  @override
  bool operator ==(Object other) =>
      other is LocationVisibility &&
      other.isVisible == isVisible &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(isVisible, reason);

  @override
  String toString() =>
      'LocationVisibility(isVisible: $isVisible, reason: $reason)';
}
