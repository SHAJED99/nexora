// E05-T01 — exhaustive transition-matrix test for DeliveryStateMachine.
//
// Per this task's §6 risk note: getting the state graph wrong (e.g.
// allowing `Stored -> Sent`) silently breaks every later task's
// assumptions. This test enumerates EVERY (from, to) pair in
// DeliveryState, not just the happy path, so illegal transitions are
// provably rejected rather than merely untested.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';

void main() {
  // The documented happy path (FR-MSG-002 / F-032):
  // Queued -> Sent -> Accepted -> Delivered -> Stored -> Read
  const happyPath = [
    DeliveryState.queued,
    DeliveryState.sent,
    DeliveryState.accepted,
    DeliveryState.delivered,
    DeliveryState.stored,
    DeliveryState.read,
  ];

  // `-> Failed` is legal from every pre-terminal state (everything except
  // `read` and `failed` itself).
  const preTerminal = [
    DeliveryState.queued,
    DeliveryState.sent,
    DeliveryState.accepted,
    DeliveryState.delivered,
    DeliveryState.stored,
  ];

  /// The full set of legal (from, to) pairs, derived independently of the
  /// implementation (hand-enumerated from the spec), used to compute which
  /// pairs are illegal for the exhaustive negative test below.
  final legalPairs = <(DeliveryState, DeliveryState)>{
    for (var i = 0; i < happyPath.length - 1; i++)
      (happyPath[i], happyPath[i + 1]),
    for (final from in preTerminal) (from, DeliveryState.failed),
  };

  group('test_EARS_MSG_2b_legal_transitions_succeed', () {
    for (var i = 0; i < happyPath.length - 1; i++) {
      final from = happyPath[i];
      final to = happyPath[i + 1];
      test('${from.name} -> ${to.name} is legal and succeeds', () {
        expect(DeliveryStateMachine.canTransition(from, to), isTrue);
        expect(DeliveryStateMachine.transition(from, to), to);
      });
    }

    for (final from in preTerminal) {
      test('${from.name} -> failed is legal and succeeds', () {
        expect(
          DeliveryStateMachine.canTransition(from, DeliveryState.failed),
          isTrue,
        );
        expect(
          DeliveryStateMachine.transition(from, DeliveryState.failed),
          DeliveryState.failed,
        );
      });
    }
  });

  group('test_EARS_MSG_2a_illegal_transitions_rejected', () {
    // Exhaustive: every (from, to) pair over the full DeliveryState enum,
    // minus the legal set above, must be rejected by both canTransition
    // (false) and transition (throws).
    for (final from in DeliveryState.values) {
      for (final to in DeliveryState.values) {
        final isLegal = legalPairs.contains((from, to));
        if (isLegal) continue;

        test('${from.name} -> ${to.name} is illegal and rejected', () {
          expect(
            DeliveryStateMachine.canTransition(from, to),
            isFalse,
            reason: '${from.name} -> ${to.name} should not be legal',
          );
          expect(
            () => DeliveryStateMachine.transition(from, to),
            throwsA(isA<StateError>()),
          );
        });
      }
    }

    // Explicitly named illegal cases from the task's own examples, so the
    // intent is legible even without reading the loop above.
    test('Read -> Queued is rejected (named example)', () {
      expect(
        DeliveryStateMachine.canTransition(
          DeliveryState.read,
          DeliveryState.queued,
        ),
        isFalse,
      );
      expect(
        () => DeliveryStateMachine.transition(
          DeliveryState.read,
          DeliveryState.queued,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Stored -> Sent is rejected (named example)', () {
      expect(
        DeliveryStateMachine.canTransition(
          DeliveryState.stored,
          DeliveryState.sent,
        ),
        isFalse,
      );
      expect(
        () => DeliveryStateMachine.transition(
          DeliveryState.stored,
          DeliveryState.sent,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a state never transitions to itself', () {
      for (final s in DeliveryState.values) {
        expect(DeliveryStateMachine.canTransition(s, s), isFalse);
      }
    });

    test('Failed is terminal -- no transition out of it is legal', () {
      for (final to in DeliveryState.values) {
        expect(
          DeliveryStateMachine.canTransition(DeliveryState.failed, to),
          isFalse,
        );
      }
    });

    test('the thrown StateError names both states', () {
      try {
        DeliveryStateMachine.transition(
          DeliveryState.read,
          DeliveryState.queued,
        );
        fail('expected StateError');
      } on StateError catch (e) {
        expect(e.toString(), contains('read'));
        expect(e.toString(), contains('queued'));
      }
    });
  });
}
