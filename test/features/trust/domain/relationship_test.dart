// isConnectionPermitted — FR-TRUST-005 bidirectional-independent gate
// (E02-T01). Pure-function tests, no persistence.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  test('both sides trusted permits the connection', () {
    expect(
      isConnectionPermitted(
        RelationshipState.trusted,
        RelationshipState.trusted,
      ),
      isTrue,
    );
  });

  test('both sides allowed permits the connection', () {
    expect(
      isConnectionPermitted(
        RelationshipState.allowed,
        RelationshipState.allowed,
      ),
      isTrue,
    );
  });

  test('a mix of trusted and allowed on each side permits the connection',
      () {
    expect(
      isConnectionPermitted(
        RelationshipState.trusted,
        RelationshipState.allowed,
      ),
      isTrue,
    );
  });

  test('unknown on either side never permits the connection', () {
    expect(
      isConnectionPermitted(
        RelationshipState.unknown,
        RelationshipState.trusted,
      ),
      isFalse,
    );
    expect(
      isConnectionPermitted(
        RelationshipState.trusted,
        RelationshipState.unknown,
      ),
      isFalse,
    );
  });
}
