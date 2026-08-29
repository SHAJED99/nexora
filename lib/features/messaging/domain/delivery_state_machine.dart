// features/messaging/domain — delivery-state machine (E05-T01).
//
// FR-MSG-002 / F-032 (docs/conventions.md "Enums"): delivery state is a
// closed set — `Queued -> Sent -> Accepted -> Delivered -> Stored -> Read`,
// or `-> Failed` from any pre-terminal state (i.e. any state except `Read`
// and `Failed` themselves, which are terminal). This is the single place
// transition legality is decided (this task's §3) — T02/T03/T04/T05 must
// call [DeliveryStateMachine.transition] rather than writing
// `delivery_state = X` directly.
//
// Stored in Drift as the enum's `.name` string, never an integer index
// (docs/conventions.md "Enums").
enum DeliveryState {
  queued,
  sent,
  accepted,
  delivered,
  stored,
  read,
  failed,
}

/// Pure validator/applier for [DeliveryState] transitions. Stateless — every
/// method is a pure function of its arguments, no instance state.
class DeliveryStateMachine {
  const DeliveryStateMachine._();

  /// The documented happy-path graph, in order. Adjacent pairs are the only
  /// legal non-`Failed` transitions.
  static const List<DeliveryState> _happyPath = [
    DeliveryState.queued,
    DeliveryState.sent,
    DeliveryState.accepted,
    DeliveryState.delivered,
    DeliveryState.stored,
    DeliveryState.read,
  ];

  /// States from which `-> Failed` is legal: every pre-terminal state, i.e.
  /// every state except the two terminal ones (`read`, `failed` itself).
  static const List<DeliveryState> _preTerminal = [
    DeliveryState.queued,
    DeliveryState.sent,
    DeliveryState.accepted,
    DeliveryState.delivered,
    DeliveryState.stored,
  ];

  /// Pure predicate — is `from -> to` legal per the closed-set state graph.
  static bool canTransition(DeliveryState from, DeliveryState to) {
    if (from == to) return false;

    if (to == DeliveryState.failed) {
      return _preTerminal.contains(from);
    }

    final fromIndex = _happyPath.indexOf(from);
    final toIndex = _happyPath.indexOf(to);
    // `from == failed` never appears in `_happyPath` (indexOf returns -1),
    // so a transition out of the terminal `failed` state is always
    // rejected here, correctly.
    if (fromIndex == -1 || toIndex == -1) return false;
    return toIndex == fromIndex + 1;
  }

  /// The one call site that mutates delivery state. Returns [to] if legal;
  /// throws [StateError] naming both states if not.
  static DeliveryState transition(DeliveryState current, DeliveryState to) {
    if (!canTransition(current, to)) {
      throw StateError(
        'Illegal delivery-state transition: '
        '${current.name} -> ${to.name}',
      );
    }
    return to;
  }
}
