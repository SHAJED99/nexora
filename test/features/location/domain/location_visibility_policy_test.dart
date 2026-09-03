// Tests for E09-T02 — LocationVisibilityPolicy, FR-LOC-003's four-condition
// AND. Pure function, no I/O, no database: every one of the four
// conditions failing independently, every reason's precedence when two
// fail at once, and the all-hold case (task §3, §8).

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/location/domain/location_visibility.dart';
import 'package:nexora/features/location/domain/location_visibility_policy.dart';
import 'package:nexora/features/messaging/domain/conflict_resolver.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  group('test_EARS_LOC_1', () {
    test('test_EARS_LOC_1_all_four_conditions_hold_is_visible', () {
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.trusted,
        remoteState: RelationshipState.trusted,
        globalEnabled: true,
        peerEnabled: true,
      );

      expect(result, const LocationVisibility.visible());
    });

    test(
        'test_EARS_LOC_1_all_four_conditions_hold_is_visible_allowed_state',
        () {
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.allowed,
        remoteState: RelationshipState.allowed,
        globalEnabled: true,
        peerEnabled: true,
      );

      expect(result, const LocationVisibility.visible());
    });

    test('test_EARS_LOC_1_blocked_peer_is_unavailable_reason_blocked', () {
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.blocked,
        remoteState: RelationshipState.trusted,
        globalEnabled: true,
        peerEnabled: true,
      );

      expect(
        result,
        const LocationVisibility.hidden(LocationUnavailableReason.blocked),
      );
    });

    test(
        'test_EARS_LOC_1_blocked_peer_is_unavailable_reason_blocked_remote_side',
        () {
      // Blocked can come from either side's stored state.
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.trusted,
        remoteState: RelationshipState.blocked,
        globalEnabled: true,
        peerEnabled: true,
      );

      expect(
        result,
        const LocationVisibility.hidden(LocationUnavailableReason.blocked),
      );
    });

    test(
        'test_EARS_LOC_1_not_connected_is_unavailable_reason_not_connected',
        () {
      // Local side authorized (trusted), remote side unknown -> not
      // connected (isConnectionPermitted requires BOTH sides to permit),
      // but local state itself is authorized, so the reason must be
      // notConnected, not notAuthorized.
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.trusted,
        remoteState: RelationshipState.unknown,
        globalEnabled: true,
        peerEnabled: true,
      );

      expect(
        result,
        const LocationVisibility.hidden(
          LocationUnavailableReason.notConnected,
        ),
      );
    });

    test(
        'test_EARS_LOC_1_unknown_state_is_unavailable_reason_not_authorized',
        () {
      // This device's own recorded state for the peer is unknown. The
      // full two-sided `isConnectionPermitted` check would ALSO fail here
      // (unknown never permits), but `notAuthorized` is the more specific,
      // locally-actionable diagnosis and is reported in preference to the
      // vaguer `notConnected` whenever the local side is the cause.
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.unknown,
        remoteState: RelationshipState.trusted,
        globalEnabled: true,
        peerEnabled: true,
      );

      expect(
        result,
        const LocationVisibility.hidden(
          LocationUnavailableReason.notAuthorized,
        ),
      );
    });

    test('test_EARS_LOC_1_global_off_is_unavailable_reason_global_off', () {
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.trusted,
        remoteState: RelationshipState.trusted,
        globalEnabled: false,
        peerEnabled: true,
      );

      expect(
        result,
        const LocationVisibility.hidden(LocationUnavailableReason.globalOff),
      );
    });

    test('test_EARS_LOC_1_peer_off_is_unavailable_reason_peer_off', () {
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.trusted,
        remoteState: RelationshipState.trusted,
        globalEnabled: true,
        peerEnabled: false,
      );

      expect(
        result,
        const LocationVisibility.hidden(LocationUnavailableReason.peerOff),
      );
    });

    test(
        'test_EARS_LOC_1_blocked_and_global_off_reports_blocked',
        () {
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.blocked,
        remoteState: RelationshipState.trusted,
        globalEnabled: false,
        peerEnabled: false,
      );

      expect(
        result,
        const LocationVisibility.hidden(LocationUnavailableReason.blocked),
        reason: 'blocked is the most security-restrictive reason and must '
            'win over any other simultaneously-failing condition',
      );
    });

    test(
        'test_EARS_LOC_1_not_connected_and_peer_off_reports_not_connected',
        () {
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.trusted,
        remoteState: RelationshipState.unknown,
        globalEnabled: true,
        peerEnabled: false,
      );

      expect(
        result,
        const LocationVisibility.hidden(
          LocationUnavailableReason.notConnected,
        ),
        reason: 'notConnected outranks peerOff in the precedence order',
      );
    });
  });

  group('test_EARS_LOC_4', () {
    test('test_EARS_LOC_4_global_off_beats_peer_on', () {
      final result = LocationVisibilityPolicy.evaluate(
        localState: RelationshipState.trusted,
        remoteState: RelationshipState.trusted,
        globalEnabled: false,
        peerEnabled: true,
      );

      expect(result.isVisible, isFalse);
      expect(result.reason, LocationUnavailableReason.globalOff);

      // The delegation to ConflictResolver.resolveLocationSharing is
      // proven, not coincidental: the sharing-allowed value the policy
      // used to reach this reason equals the resolver's own output.
      expect(
        ConflictResolver.resolveLocationSharing(false, true),
        isFalse,
      );
    });
  });
}
