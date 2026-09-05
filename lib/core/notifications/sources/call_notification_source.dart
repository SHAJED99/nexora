// core/notifications/sources — the `incomingCall` category producer
// (E10-T04, EARS-NOTIFY-8/9).
//
// Adapts `CallSignaling.notices` (this task's own addition to
// `call_signaling.dart`, an E07-owned file -- see that file's header for why
// this is observation-only, never control) into `NotificationFacts` for the
// `invite` kind, and issues a direct `NotificationSink.cancel` for every
// terminal kind (task file §3: "maps kind == invite to NotificationFacts
// ...; maps every terminal kind to a cancel of that call's notification
// id").
//
// **A cancel never goes through `NotificationDispatcher`/`NotificationPolicy`.**
// Withdrawal is cleanup, not a privacy/enablement decision -- a user who
// disabled the `incomingCall` category mid-ring must not be left with a
// stale ring notification either, and the dispatcher's own registry (task
// file's required context, `notification_dispatcher.dart`) has no post-
// bypassing "cancel" concept for a source to route through. This source is
// therefore constructed with the same `NotificationSink` the dispatcher
// itself posts through (`bindings.dart` passes `notificationDispatcher
// .service`, never a second `NotificationService` instance) and calls
// `cancel` on it directly for every non-`invite` kind. Cancelling an id
// nothing was ever posted for -- every terminal kind reached on an
// OUTGOING call's own session, which never had an `invite` notice emitted
// for it in the first place, see `call_signaling.dart`'s own
// `CallNoticeKind` doc comment -- is a harmless no-op, matching
// `NotificationSink.cancel`'s documented "withdraws a posted notification"
// contract and `NotificationStub.cancel`'s own unconditional recording.
//
// Never reads call/session content beyond `callId`/`peerDeviceId`, both
// already-authenticated routing identifiers `CallSignaling` itself computed
// (task file §5's `CallNotice` contract) -- no decrypt path, no plaintext.
import 'dart:async';

import '../../calls/call_signaling.dart' show CallNotice, CallNoticeKind;
import '../generated/notification_api.g.dart' show NotificationCategory;
import '../notification_dispatcher.dart' show NotificationSource;
import '../notification_policy.dart';
import '../notification_service.dart' show NotificationSink;

/// Posts one `incomingCall` [NotificationFacts] per inbound invite, and
/// withdraws it the moment the call reaches any terminal [CallNoticeKind]
/// (task file §3/§5). [sink] is used ONLY for the direct cancel -- every
/// post still goes through `NotificationDispatcher`/`NotificationPolicy` via
/// [facts], so enablement and privacy are applied to a posted `incomingCall`
/// notification exactly like every other category (task file §3: "one
/// dispatcher, one seam").
class CallNotificationSource implements NotificationSource {
  CallNotificationSource(this.notices, {required this.sink});

  final Stream<CallNotice> notices;
  final NotificationSink sink;

  /// Lazily subscribes to [notices] only once something listens to [facts]
  /// (the dispatcher, once registered and started) -- the exact
  /// `.where().map()` idiom `MessageNotificationSource.facts` already uses,
  /// deliberately kept rather than an `async*` generator: an early attempt
  /// used `await for`/`yield`, which subscribes to [notices] on a LATER
  /// microtask instead of synchronously inside `listen()` (an observable
  /// timing difference from every other source in this codebase) and, worse,
  /// left `StreamSubscription.cancel()` on the resulting stream hanging
  /// forever while the generator sat suspended inside its `await for` --
  /// confirmed by a minimal repro before this shape was chosen instead.
  /// [where]'s predicate carries the [NotificationSink.cancel] side effect
  /// for every non-[CallNoticeKind.invite] event and returns `false`, so
  /// only an `invite` ever reaches [map]/[_toFacts] and is published on
  /// [facts].
  @override
  Stream<NotificationFacts> get facts => notices
      .where((CallNotice notice) {
        if (notice.kind == CallNoticeKind.invite) return true;
        unawaited(sink.cancel(stableNotificationId(notice.callId)));
        return false;
      })
      .map(_toFacts);

  NotificationFacts _toFacts(CallNotice notice) {
    return NotificationFacts(
      category: NotificationCategory.incomingCall,
      // `NotificationFacts.conversationId` is reused for the call's own
      // identity here -- there is no conversation for a call, and
      // `stableNotificationId` (below) is derived from this same field for
      // both the post and the matching cancel, exactly like
      // `MessageNotificationSource`'s own use of `conversationId`.
      conversationId: notice.callId,
      peerDeviceId: notice.peerDeviceId,
      // Same stand-in `MessageNotificationSource` already uses -- no
      // display-name column exists anywhere in this codebase yet
      // (`design/gaps.md` GAP-003). Never derived from call content.
      peerDisplayName: notice.peerDeviceId,
      stableId: stableNotificationId(notice.callId),
    );
  }
}
