// core/calls — the 1:1 call session state machine (E07-T09).
//
// Deliberately reads this task's own header note first: this file is the
// half of voice calling that does NOT depend on the unsettled real-time
// media question (`OQ-E07-3`, `epics/E07-groups-calls/epic.md`). Nothing
// here captures, encodes, encrypts, transmits, decodes or plays audio, and
// nothing here talks to a transport, a database, or the network. This is a
// pure, clock-injected state machine — `call_signaling.dart` is the only
// thing that constructs one, drives it, and carries it over the wire.
//
// **The state machine is small and total** (task file §2): every [onEvent]
// call either applies one of the transitions documented on that method, or
// throws [StateError] — there is no "unknown" state and no transition that
// silently does nothing. A call UI built against a machine with a silent
// no-op is a call UI that can get stuck showing "Connecting…" forever;
// this file's whole reason to exist is to make that impossible to reach.
//
// **Timers are where call state machines rot** (task file §6). Every path
// that can end a session — a signal-driven transition via [onEvent], the
// internal 45s ring timer firing, or [endLocally] (the seam
// `NullCallMediaTransport`/a send failure/a timeout use to end a session
// WITHOUT a matching wire [CallSignalKind]) — funnels through the single
// `_end` method, which cancels the ring timer before doing anything else.
// There is exactly one place a timer is started ([_startRingTimer]) and
// exactly one place it is cancelled ([_cancelRingTimer]), both private, so
// "did every terminal transition cancel its timer" is answerable by reading
// this one file rather than auditing every call site that can end a call.
//
// **Does NOT know about the wire.** [CallSignalKind] is the same closed set
// `CallSignalingFrame.kind` carries on the wire (`call_signaling.dart`), but
// this class never encodes, decodes, sends or receives a frame — it is
// driven by [onEvent] regardless of whether the caller derived that kind
// from a local action (this device placed/accepted/declined/hung up a call)
// or from an already-decrypted, already-authenticated inbound frame. Which
// side does which is entirely `call_signaling.dart`'s concern.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `prekey_exchange.dart`/`relay_engine.dart`/`inbound_pipeline.dart`/
// `messaging_coordinator.dart` — the field names are prefixed (`_clock`,
// `_ringTimeout`) while the constructor parameters are not, so an
// initializing formal cannot express the rename.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

/// The call session lifecycle (task file §2/§5): two shapes sharing a
/// spine, `idle → outgoingPending → outgoingRinging → active → ending →
/// ended` for the caller and `idle → incomingRinging → active → ending →
/// ended` for the callee.
enum CallState {
  idle,
  outgoingPending,
  outgoingRinging,
  incomingRinging,
  active,
  ending,
  ended,
}

/// Why an [CallState.ended] [CallSession] stopped (task file §2). Always
/// non-null once [CallSession.state] reaches [CallState.ended], always null
/// before that.
enum CallEndReason {
  declined,
  busy,
  cancelled,
  hangup,
  timeout,
  failed,
  unreachable,
}

/// The signaling event kinds a [CallSession] transitions on — the exact
/// same closed set `CallSignalingFrame.kind` carries on the wire (task file
/// §3, `call_signaling.dart`). [CallSession] has no wire-format knowledge of
/// its own; see this file's header for why the same enum drives both a
/// local action and a decoded, already-authenticated inbound frame.
enum CallSignalKind { invite, ringing, accept, decline, busy, hangup, cancel }

/// How long a session stays in a ringing state — [CallState.outgoingPending]
/// / [CallState.outgoingRinging] for the caller, [CallState.incomingRinging]
/// for the callee — before it ends itself with [CallEndReason.timeout].
/// Task file §2: "both values are injected constants, never literals at a
/// call site", the same discipline `messaging_stack.dart`'s own
/// `coordinatorTickInterval` already established. Both the caller and the
/// callee run this SAME duration independently, so neither side needs a
/// round trip with the other to agree when a call has rung out.
const Duration defaultRingTimeout = Duration(seconds: 45);

/// One 1:1 call's total, explicit state machine (task file §3/§5). Pure and
/// clock-injected — no I/O, no transport, no crypto, no database. Exactly
/// one instance represents exactly one side's view of exactly one call;
/// `call_signaling.dart` constructs one per call attempt (caller side, on
/// [CallSignalKind.invite] sent) or per inbound invite (callee side, on
/// [CallSignalKind.invite] received) and holds at most one at a time (task
/// file §2: "one active call per device").
class CallSession {
  CallSession({
    required this.callId,
    required this.peerDeviceId,
    required this.isOutgoing,
    required DateTime Function() clock,
    Duration ringTimeout = defaultRingTimeout,
  })  : _clock = clock,
        _ringTimeout = ringTimeout;

  /// Minted by the caller (task file §6: "mint it on the caller side, echo
  /// it in every frame"); both sides' [CallSession] for the same call carry
  /// the identical value.
  final String callId;

  final String peerDeviceId;

  /// `true` for the device that placed the call, `false` for the device
  /// being called — fixed for this session's whole lifetime, set once at
  /// construction.
  final bool isOutgoing;

  final DateTime Function() _clock;
  final Duration _ringTimeout;

  final StreamController<CallState> _statesController =
      StreamController<CallState>.broadcast();

  CallState _state = CallState.idle;
  CallEndReason? _endReason;
  Timer? _ringTimer;
  DateTime? _lastTransitionAt;

  /// The current state. Never anything outside [CallState] — there is no
  /// "unknown" value (task file §2).
  CallState get state => _state;

  /// When [state] last changed, per the injected [clock] — not part of the
  /// task file's own contract list, but a natural, small use of the
  /// required `clock` parameter (a call UI showing "ringing for Ns" needs
  /// exactly this), rather than leaving it an unused constructor
  /// parameter.
  DateTime? get lastTransitionAt => _lastTransitionAt;

  /// Broadcast so more than one listener (a call UI, `call_signaling.dart`'s
  /// own bookkeeping) can observe every transition, including the ones
  /// reached internally — the ring timer firing, or [endLocally] — not just
  /// the ones [onEvent] drives directly.
  Stream<CallState> get states => _statesController.stream;

  /// Set only once [state] reaches [CallState.ended]; null at every other
  /// state (task file §2: "`ended` carries a reason").
  CallEndReason? get endReason => _endReason;

  /// Applies one transition from this task's own state table (task file
  /// §2/§5), driven by [kind]. Throws [StateError] on any `(state, kind)`
  /// pair not in that table — never a silent no-op (task file §5's own
  /// contract for this method):
  ///
  ///   idle             + invite  -> outgoingPending (isOutgoing) /
  ///                                 incomingRinging (!isOutgoing)
  ///   outgoingPending  + ringing -> outgoingRinging
  ///   outgoingPending  + accept  -> active
  ///   outgoingRinging  + accept  -> active
  ///   incomingRinging  + accept  -> active
  ///   outgoingPending  + decline -> ended(declined)
  ///   outgoingRinging  + decline -> ended(declined)
  ///   incomingRinging  + decline -> ended(declined)
  ///   outgoingPending  + busy    -> ended(busy)
  ///   outgoingRinging  + busy    -> ended(busy)
  ///   outgoingPending  + cancel  -> ended(cancelled)
  ///   outgoingRinging  + cancel  -> ended(cancelled)
  ///   incomingRinging  + cancel  -> ended(cancelled)
  ///   active           + hangup  -> ended(hangup)
  ///
  /// Every other pair (49 total minus the 14 above) throws.
  void onEvent(CallSignalKind kind) {
    final CallState from = _state;

    if (from == CallState.idle && kind == CallSignalKind.invite) {
      _enter(
        isOutgoing ? CallState.outgoingPending : CallState.incomingRinging,
      );
      return;
    }
    if (from == CallState.outgoingPending && kind == CallSignalKind.ringing) {
      _enter(CallState.outgoingRinging);
      return;
    }
    if (kind == CallSignalKind.accept &&
        (from == CallState.outgoingPending ||
            from == CallState.outgoingRinging ||
            from == CallState.incomingRinging)) {
      _enter(CallState.active);
      return;
    }
    if (kind == CallSignalKind.decline &&
        (from == CallState.outgoingPending ||
            from == CallState.outgoingRinging ||
            from == CallState.incomingRinging)) {
      _end(CallEndReason.declined);
      return;
    }
    if (kind == CallSignalKind.busy &&
        (from == CallState.outgoingPending ||
            from == CallState.outgoingRinging)) {
      _end(CallEndReason.busy);
      return;
    }
    if (kind == CallSignalKind.cancel &&
        (from == CallState.outgoingPending ||
            from == CallState.outgoingRinging ||
            from == CallState.incomingRinging)) {
      _end(CallEndReason.cancelled);
      return;
    }
    if (from == CallState.active && kind == CallSignalKind.hangup) {
      _end(CallEndReason.hangup);
      return;
    }

    throw StateError(
      'CallSession($callId): invalid transition -- kind $kind from state $from',
    );
  }

  /// Forces this session straight to [CallState.ended] with [reason]
  /// WITHOUT going through [onEvent] — the seam for the three end reasons
  /// no wire [CallSignalKind] ever carries: a ring timeout firing
  /// ([CallEndReason.timeout], driven by this class's own internal timer),
  /// a media-transport failure ([CallEndReason.failed], driven by
  /// `NullCallMediaTransport.attach`), and an unreachable peer at send time
  /// ([CallEndReason.unreachable], driven by `CallSignaling` when an
  /// outbound send itself fails). A no-op once already
  /// [CallState.ended] — idempotent, since more than one of these can race
  /// (e.g. the ring timer firing the same tick a decline frame arrives).
  void endLocally(CallEndReason reason) {
    if (_state == CallState.ended) return;
    _end(reason);
  }

  void _enter(CallState next) {
    _state = next;
    _lastTransitionAt = _clock();
    _statesController.add(_state);
    if (next == CallState.outgoingPending || next == CallState.incomingRinging) {
      // The ring timer starts on FIRST entry into a ringing family only —
      // the later outgoingPending -> outgoingRinging hop (task file §2:
      // "the callee also stops ringing at 45s so both ends agree without a
      // round trip") does not restart it, so the 45s bound covers the
      // whole ringing window, not just its tail.
      _startRingTimer();
    } else if (next == CallState.active) {
      _cancelRingTimer();
    }
  }

  void _end(CallEndReason reason) {
    _cancelRingTimer();
    _endReason = reason;
    _state = CallState.ending;
    _lastTransitionAt = _clock();
    _statesController.add(_state);
    _state = CallState.ended;
    _statesController.add(_state);
  }

  void _startRingTimer() {
    _ringTimer?.cancel();
    _ringTimer = Timer(_ringTimeout, () {
      // Defense in depth: only a session still in a ringing state times
      // out. A session that left the ringing family before this fires has
      // already had its timer cancelled by `_cancelRingTimer` (called from
      // every `_enter`/`_end` path), so this branch is unreachable in
      // practice — it exists so a firing timer can never resurrect an
      // already-terminal session even under an unforeseen ordering.
      if (_state == CallState.outgoingPending ||
          _state == CallState.outgoingRinging ||
          _state == CallState.incomingRinging) {
        endLocally(CallEndReason.timeout);
      }
    });
  }

  void _cancelRingTimer() {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  /// Releases this session's broadcast stream controller and cancels any
  /// pending timer. `CallSignaling` calls this once a session leaves its
  /// own bookkeeping (task file §6: every timer cancelled on every terminal
  /// transition) — safe to call more than once.
  void dispose() {
    _cancelRingTimer();
    unawaited(_statesController.close());
  }
}
