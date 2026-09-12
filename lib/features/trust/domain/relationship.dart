// features/trust/domain — relationship domain model (E02-T01).
//
// FR-TRUST-001..005: each device pair's trust is evaluated independently by
// each side. This file defines the closed set of states, the plain entity
// persisted in `relationships` (ADR-0001), and the pure bidirectional gate
// (FR-TRUST-005) — no I/O, no transport.

/// A device's trust classification, from this side's perspective only.
/// Stored in Drift as its `.name` string, per `docs/conventions.md`
/// "Enums" — never as an integer index.
enum RelationshipState { trusted, allowed, unknown, blocked }

/// This side's stored relationship with a single remote device.
class Relationship {
  final String deviceId;
  final RelationshipState state;
  final DateTime updatedAt;

  /// E04-B12 (Option A, part 1/2): the peer's own real `selfDeviceId`,
  /// learned via the identity-announce control protocol
  /// (`lib/core/messaging/identity_announce.dart`) and stored keyed by
  /// [deviceId] above, which stays the Bluetooth-address transport id this
  /// relationship row was created under (task file §2a: zero re-keying).
  /// `null` until a peer has announced at least once. Optional/nullable
  /// named field so every existing call site that constructs a
  /// [Relationship] without it keeps compiling unchanged.
  final String? remoteSelfDeviceId;

  const Relationship({
    required this.deviceId,
    required this.state,
    required this.updatedAt,
    this.remoteSelfDeviceId,
  });
}

/// FR-TRUST-005 — a connection is permitted only when NEITHER side is
/// [RelationshipState.blocked] AND BOTH sides are trusted or allowed.
/// [RelationshipState.unknown] on either side means not yet permitted.
///
/// This is a pure function over two already-evaluated states — it never
/// looks up "the" state for a device pair itself, so it cannot be
/// accidentally implemented as one-sided (see the task's §6 risk note).
/// There is no live remote-evaluation exchange yet (that's E04's transport
/// layer); this is the seam E04 calls once one exists.
bool isConnectionPermitted(RelationshipState local, RelationshipState remote) {
  if (local == RelationshipState.blocked ||
      remote == RelationshipState.blocked) {
    return false;
  }
  bool allows(RelationshipState s) =>
      s == RelationshipState.trusted || s == RelationshipState.allowed;
  return allows(local) && allows(remote);
}
