// Tests for CallSession (E07-T09, EARS-CALL-3, the exhaustive state-machine
// contract in the task file's own §5/§8).
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/calls/call_session.dart';

void main() {
  DateTime fakeNow = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime clock() => fakeNow;

  setUp(() {
    fakeNow = DateTime.fromMillisecondsSinceEpoch(0);
  });

  CallSession outgoing({Duration ringTimeout = defaultRingTimeout}) =>
      CallSession(
        callId: 'call-1',
        peerDeviceId: 'peer-1',
        isOutgoing: true,
        clock: clock,
        ringTimeout: ringTimeout,
      );

  CallSession incoming({Duration ringTimeout = defaultRingTimeout}) =>
      CallSession(
        callId: 'call-1',
        peerDeviceId: 'peer-1',
        isOutgoing: false,
        clock: clock,
        ringTimeout: ringTimeout,
      );

  group('valid transitions', () {
    test('test_EARS_CALL_2_outgoing_invite_to_active_via_ringing', () {
      final session = outgoing();
      expect(session.state, CallState.idle);
      session.onEvent(CallSignalKind.invite);
      expect(session.state, CallState.outgoingPending);
      session.onEvent(CallSignalKind.ringing);
      expect(session.state, CallState.outgoingRinging);
      session.onEvent(CallSignalKind.accept);
      expect(session.state, CallState.active);
      expect(session.endReason, isNull);
    });

    test('outgoing invite reaches active directly (no ringing ack)', () {
      final session = outgoing();
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.accept);
      expect(session.state, CallState.active);
    });

    test('incoming invite reaches active on accept', () {
      final session = incoming();
      session.onEvent(CallSignalKind.invite);
      expect(session.state, CallState.incomingRinging);
      session.onEvent(CallSignalKind.accept);
      expect(session.state, CallState.active);
    });

    test('incoming invite declined ends with declined', () {
      final session = incoming();
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.decline);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.declined);
    });

    test('outgoing invite gets busy', () {
      final session = outgoing();
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.busy);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.busy);
    });

    test('outgoing invite cancelled before answer', () {
      final session = outgoing();
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.cancel);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.cancelled);
    });

    test('incoming invite cancelled by caller before answer', () {
      final session = incoming();
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.cancel);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.cancelled);
    });

    test(
        'test_EARS_CALL_3_hangup_from_either_side_ends_both_and_cancels_timers',
        () async {
      final session = outgoing();
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.accept);
      expect(session.state, CallState.active);

      final states = <CallState>[];
      session.states.listen(states.add);
      session.onEvent(CallSignalKind.hangup);
      // Broadcast-stream delivery is scheduled as a microtask per event
      // even for events added synchronously back-to-back -- pump the event
      // queue so BOTH `ending` and `ended` are delivered before asserting.
      await pumpEventQueue();

      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.hangup);
      // Both the intermediate `ending` and final `ended` states are
      // observed by any listener (task file §2: the machine passes through
      // `ending` on its way to `ended`, never jumps straight there).
      expect(states, [CallState.ending, CallState.ended]);
    });
  });

  group('test_every_invalid_transition_throws', () {
    test('exhaustive over CallState x CallSignalKind (outgoing side)', () {
      // The only pairs that do NOT throw, starting from `idle` for an
      // outgoing session (task file's own state table).
      final validFromIdle = {CallSignalKind.invite};

      for (final kind in CallSignalKind.values) {
        final session = outgoing();
        if (validFromIdle.contains(kind)) {
          expect(() => session.onEvent(kind), returnsNormally,
              reason: 'idle + $kind should be valid for an outgoing session');
        } else {
          expect(() => session.onEvent(kind), throwsStateError,
              reason: 'idle + $kind must throw for an outgoing session');
        }
      }
    });

    test('exhaustive over CallState x CallSignalKind (incoming side)', () {
      final validFromIdle = {CallSignalKind.invite};
      for (final kind in CallSignalKind.values) {
        final session = incoming();
        if (validFromIdle.contains(kind)) {
          expect(() => session.onEvent(kind), returnsNormally);
        } else {
          expect(() => session.onEvent(kind), throwsStateError);
        }
      }
    });

    test('every (state, kind) pair not in the documented table throws', () {
      // Build every reachable state via a fresh session, then attempt
      // every kind against it, comparing to the exact validity table this
      // task file documents (also documented on CallSession.onEvent's own
      // doc comment).
      // `(idle, invite)` is intentionally NOT in this shared table -- its
      // target depends on `isOutgoing` (outgoingPending vs incomingRinging),
      // handled as a special case in the loop below.
      const validPairs = <(CallState, CallSignalKind), CallState>{
        (CallState.outgoingPending, CallSignalKind.ringing):
            CallState.outgoingRinging,
        (CallState.outgoingPending, CallSignalKind.accept): CallState.active,
        (CallState.outgoingRinging, CallSignalKind.accept): CallState.active,
        (CallState.incomingRinging, CallSignalKind.accept): CallState.active,
        (CallState.outgoingPending, CallSignalKind.decline):
            CallState.ended,
        (CallState.outgoingRinging, CallSignalKind.decline):
            CallState.ended,
        (CallState.incomingRinging, CallSignalKind.decline):
            CallState.ended,
        (CallState.outgoingPending, CallSignalKind.busy): CallState.ended,
        (CallState.outgoingRinging, CallSignalKind.busy): CallState.ended,
        (CallState.outgoingPending, CallSignalKind.cancel): CallState.ended,
        (CallState.outgoingRinging, CallSignalKind.cancel): CallState.ended,
        (CallState.incomingRinging, CallSignalKind.cancel): CallState.ended,
        (CallState.active, CallSignalKind.hangup): CallState.ended,
      };

      // Helper: drive a fresh session (outgoing, since it can reach every
      // non-incomingRinging state; a second fresh incoming session covers
      // incomingRinging) to exactly [target] via the shortest known valid
      // path, or null if unreachable that way.
      CallSession? driveTo(CallState target, {required bool isOutgoing}) {
        final session = isOutgoing ? outgoing() : incoming();
        switch (target) {
          case CallState.idle:
            return session;
          case CallState.outgoingPending:
            if (!isOutgoing) return null;
            session.onEvent(CallSignalKind.invite);
            return session;
          case CallState.outgoingRinging:
            if (!isOutgoing) return null;
            session.onEvent(CallSignalKind.invite);
            session.onEvent(CallSignalKind.ringing);
            return session;
          case CallState.incomingRinging:
            if (isOutgoing) return null;
            session.onEvent(CallSignalKind.invite);
            return session;
          case CallState.active:
            session.onEvent(CallSignalKind.invite);
            if (isOutgoing) {
              session.onEvent(CallSignalKind.accept);
            } else {
              session.onEvent(CallSignalKind.accept);
            }
            return session;
          case CallState.ending:
          case CallState.ended:
            // Not independently constructible as a starting point --
            // `onEvent` is never called again once `ended` (a session
            // there is used only to prove every kind throws).
            session.onEvent(CallSignalKind.invite);
            session.onEvent(CallSignalKind.cancel);
            return session;
        }
      }

      for (final isOutgoing in [true, false]) {
        for (final state in CallState.values) {
          final session = driveTo(state, isOutgoing: isOutgoing);
          if (session == null) continue;
          for (final kind in CallSignalKind.values) {
            final key = (state, kind);
            final expectedTarget = state == CallState.idle &&
                    kind == CallSignalKind.invite
                ? (isOutgoing
                    ? CallState.outgoingPending
                    : CallState.incomingRinging)
                : validPairs[key];
            if (state == CallState.ending || state == CallState.ended) {
              // Terminal: every kind throws, regardless of the table above
              // (the table only documents pairs reachable from a LIVE
              // state).
              expect(
                () => driveTo(state, isOutgoing: isOutgoing)!.onEvent(kind),
                throwsStateError,
                reason: '$state + $kind (terminal) must throw',
              );
              continue;
            }
            final probe = driveTo(state, isOutgoing: isOutgoing)!;
            if (expectedTarget == null) {
              expect(
                () => probe.onEvent(kind),
                throwsStateError,
                reason: '$state + $kind must throw (isOutgoing=$isOutgoing)',
              );
            } else {
              probe.onEvent(kind);
              expect(
                probe.state == CallState.ending
                    ? CallState.ended
                    : probe.state,
                expectedTarget,
                reason: '$state + $kind should reach $expectedTarget',
              );
            }
          }
        }
      }
    });
  });

  group('timers', () {
    // Real `Timer`s with a short INJECTED `ringTimeout` (task file §2: "both
    // values are injected constants, never literals at a call site") --
    // mirrors `messaging_coordinator_test.dart`'s own real-`Timer`-plus-
    // short-injected-`Duration` discipline rather than a fake-clock
    // library, since `defaultRingTimeout` (45s) is never the value actually
    // waited on in a test.
    const shortRing = Duration(milliseconds: 30);

    test('test_ring_timeout_ends_both_ends_at_the_same_boundary', () async {
      final caller = outgoing(ringTimeout: shortRing);
      final callee = incoming(ringTimeout: shortRing);
      caller.onEvent(CallSignalKind.invite);
      callee.onEvent(CallSignalKind.invite);

      expect(caller.state, isNot(CallState.ended));
      expect(callee.state, isNot(CallState.ended));

      await Future<void>.delayed(shortRing * 3);

      expect(caller.state, CallState.ended);
      expect(caller.endReason, CallEndReason.timeout);
      expect(callee.state, CallState.ended);
      expect(callee.endReason, CallEndReason.timeout);
    });

    test('ring timer does not restart on the ringing ack', () async {
      final session = outgoing(ringTimeout: shortRing);
      session.onEvent(CallSignalKind.invite);
      await Future<void>.delayed(shortRing * 2 ~/ 3);
      session.onEvent(CallSignalKind.ringing);
      // Total elapsed from invite is what matters, not from the ringing
      // ack -- waiting only a little past the ORIGINAL 30ms deadline (not
      // restarting a fresh 30ms from the ack) proves the timer was not
      // restarted.
      await Future<void>.delayed(shortRing * 2 ~/ 3);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.timeout);
    });

    test('test_EARS_CALL_3_no_timer_fires_after_ended', () async {
      final session = outgoing(ringTimeout: shortRing);
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.accept);
      session.onEvent(CallSignalKind.hangup);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.hangup);

      // If the ring timer were not cancelled on the active/hangup path,
      // this wait would let it fire and stomp `endReason` back to
      // `timeout`.
      await Future<void>.delayed(shortRing * 3);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.hangup);
    });

    test('accepting before the ring timeout cancels the timer', () async {
      final session = outgoing(ringTimeout: shortRing);
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.accept);
      await Future<void>.delayed(shortRing * 3);
      expect(session.state, CallState.active);
    });

    test('declining before the ring timeout cancels the timer', () async {
      final session = incoming(ringTimeout: shortRing);
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.decline);
      await Future<void>.delayed(shortRing * 3);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.declined);
    });
  });

  group('test_EARS_CALL_3_no_pending_ring_timer_after_end', () {
    // Round-1 review finding F2: the 613-test suite that existed before
    // this group stayed green even after deleting `_cancelRingTimer();`
    // from `CallSession._end` -- none of the existing tests actually
    // observed the TIMER ITSELF; they only observed effects the removal
    // happened not to disturb (either because `_enter(active)` had already
    // cancelled it on that particular path, or because the firing timer's
    // own in-timer state guard silently no-ops once already `ended`,
    // masking a leaked-but-harmless-looking `Timer` object). These tests
    // read `hasPendingRingTimer` directly -- the visible seam added to
    // `CallSession` for exactly this purpose -- on the three `_end` paths
    // task file §6 names as the actual risk: a REMOTE decline/busy/cancel
    // arriving while a ring timer is still live.
    //
    // Falsified directly (task instructions): with
    // `_cancelRingTimer();` temporarily deleted from `CallSession._end`,
    // all three tests below fail -- `hasPendingRingTimer` reads `true`
    // instead of `false` -- because `_ringTimer` is still non-null the
    // instant `_end` finishes. Restored, they pass again. See the run log
    // / PR description for the exact revert-run-restore transcript.
    test('remote decline while incoming-ringing leaves no pending timer', () {
      final session = incoming();
      session.onEvent(CallSignalKind.invite);
      expect(session.hasPendingRingTimer, isTrue,
          reason: 'ring timer must be armed while ringing');
      session.onEvent(CallSignalKind.decline);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.declined);
      expect(session.hasPendingRingTimer, isFalse,
          reason: 'a terminal transition must leave NO pending timer');
    });

    test('remote busy while outgoing-pending leaves no pending timer', () {
      final session = outgoing();
      session.onEvent(CallSignalKind.invite);
      expect(session.hasPendingRingTimer, isTrue);
      session.onEvent(CallSignalKind.busy);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.busy);
      expect(session.hasPendingRingTimer, isFalse);
    });

    test('remote cancel while incoming-ringing leaves no pending timer', () {
      final session = incoming();
      session.onEvent(CallSignalKind.invite);
      expect(session.hasPendingRingTimer, isTrue);
      session.onEvent(CallSignalKind.cancel);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.cancelled);
      expect(session.hasPendingRingTimer, isFalse);
    });
  });

  group('endLocally', () {
    test('drives idle-unreachable-style ending without a wire kind', () {
      final session = outgoing();
      session.onEvent(CallSignalKind.invite);
      session.endLocally(CallEndReason.unreachable);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.unreachable);
    });

    test(
        'test_EARS_CALL_5_null_media_transport_ends_the_call_explicitly_via_endLocally',
        () {
      final session = outgoing();
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.accept);
      expect(session.state, CallState.active);
      session.endLocally(CallEndReason.failed);
      expect(session.state, CallState.ended);
      expect(session.endReason, CallEndReason.failed);
    });

    test('is idempotent once already ended', () {
      final session = outgoing();
      session.onEvent(CallSignalKind.invite);
      session.onEvent(CallSignalKind.cancel);
      expect(session.endReason, CallEndReason.cancelled);
      session.endLocally(CallEndReason.failed);
      // Unchanged -- endLocally is a no-op once ended.
      expect(session.endReason, CallEndReason.cancelled);
    });
  });
}
