// Tests for E05-T05 — conflict resolution, security-restrictive precedence.
// FR-MSG-007 / EARS-MSG-4: four independently named precedence pairs, each
// its own test group. No single generic "restrictive wins" test stands in
// for these — the epic's own risk note is explicit that assuming one
// generalizes to all four untested is exactly the mistake to avoid.

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/messaging/domain/conflict_resolver.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  group('test_EARS_MSG_4_block_beats_trust', () {
    // Every pairwise combination involving `blocked` on either side.
    for (final other in RelationshipState.values) {
      test('blocked vs $other -> blocked (blocked first)', () {
        expect(
          ConflictResolver.resolveTrust(RelationshipState.blocked, other),
          RelationshipState.blocked,
        );
      });
      test('$other vs blocked -> blocked (blocked second)', () {
        expect(
          ConflictResolver.resolveTrust(other, RelationshipState.blocked),
          RelationshipState.blocked,
        );
      });
    }
  });

  group('test_EARS_MSG_4_trust_state_full_ordering', () {
    // Documented restrictiveness ordering, most to least restrictive:
    // blocked > unknown > allowed > trusted.
    // (See conflict_resolver.dart doc comment for the rationale — E02's
    // RelationshipState/isConnectionPermitted define blocked-vs-not and
    // trusted/allowed-both-permit, but no total order across all four; this
    // task defines one explicitly since none already existed to reuse.)
    const orderedMostRestrictiveFirst = [
      RelationshipState.blocked,
      RelationshipState.unknown,
      RelationshipState.allowed,
      RelationshipState.trusted,
    ];

    // Exhaustive pairwise combination of all four values (16 pairs,
    // including a==b), asserting the resolved value is always the one
    // earlier (more restrictive) in the documented ordering.
    for (final a in RelationshipState.values) {
      for (final b in RelationshipState.values) {
        test('resolveTrust($a, $b) picks the more restrictive of the two', () {
          final expected =
              orderedMostRestrictiveFirst.indexOf(a) <=
                      orderedMostRestrictiveFirst.indexOf(b)
                  ? a
                  : b;
          expect(ConflictResolver.resolveTrust(a, b), expected);
        });
      }
    }

    test('symmetry: resolveTrust(a, b) == resolveTrust(b, a) for every pair', () {
      for (final a in RelationshipState.values) {
        for (final b in RelationshipState.values) {
          expect(
            ConflictResolver.resolveTrust(a, b),
            ConflictResolver.resolveTrust(b, a),
            reason: 'resolveTrust($a, $b) should equal resolveTrust($b, $a)',
          );
        }
      }
    });

    test('unknown beats allowed and trusted (not just blocked-vs-other)', () {
      expect(
        ConflictResolver.resolveTrust(
          RelationshipState.unknown,
          RelationshipState.allowed,
        ),
        RelationshipState.unknown,
      );
      expect(
        ConflictResolver.resolveTrust(
          RelationshipState.unknown,
          RelationshipState.trusted,
        ),
        RelationshipState.unknown,
      );
    });

    test('allowed beats trusted', () {
      expect(
        ConflictResolver.resolveTrust(
          RelationshipState.allowed,
          RelationshipState.trusted,
        ),
        RelationshipState.allowed,
      );
    });
  });

  group('test_EARS_MSG_4_location_off_beats_on', () {
    test('false, true -> false', () {
      expect(ConflictResolver.resolveLocationSharing(false, true), false);
    });
    test('true, false -> false', () {
      expect(ConflictResolver.resolveLocationSharing(true, false), false);
    });
    test('false, false -> false', () {
      expect(ConflictResolver.resolveLocationSharing(false, false), false);
    });
    test('true, true -> true', () {
      expect(ConflictResolver.resolveLocationSharing(true, true), true);
    });
  });

  group('test_EARS_MSG_4_revoked_beats_active', () {
    test('revoked, active -> revoked (true, false -> true)', () {
      expect(ConflictResolver.resolveRevocation(true, false), true);
    });
    test('active, revoked -> revoked (false, true -> true)', () {
      expect(ConflictResolver.resolveRevocation(false, true), true);
    });
    test('active, active -> active (false, false -> false)', () {
      expect(ConflictResolver.resolveRevocation(false, false), false);
    });
    test('revoked, revoked -> revoked (true, true -> true)', () {
      expect(ConflictResolver.resolveRevocation(true, true), true);
    });
  });

  group('test_EARS_MSG_4_removed_beats_member', () {
    test('removed, member -> removed (true, false -> true)', () {
      expect(ConflictResolver.resolveMembership(true, false), true);
    });
    test('member, removed -> removed (false, true -> true)', () {
      expect(ConflictResolver.resolveMembership(false, true), true);
    });
    test('member, member -> member (false, false -> false)', () {
      expect(ConflictResolver.resolveMembership(false, false), false);
    });
    test('removed, removed -> removed (true, true -> true)', () {
      expect(ConflictResolver.resolveMembership(true, true), true);
    });
  });
}
