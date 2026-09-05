// core/notifications/sources — the `connectionRequest` category producer
// (E10-T05, EARS-NOTIFY-10/11).
//
// Adapts `PrekeyExchange.connectionRequests` (this task's own addition to
// `prekey_exchange.dart`, an E06-owned file -- see that file's own doc
// comment on `ConnectionRequestNotice` for why the stream deliberately
// emits every `RelationshipState`, not just `unknown`) into
// `NotificationFacts` for the `unknown` state only.
//
// **Only `unknown` is notifiable, and `blocked` must never notify (the
// security-relevant half of this task, task file §2).** `trusted`/`allowed`
// peers are already connections -- a notification adds nothing; `blocked`
// devices must never reach the user via any channel (E02-T01's whole
// point). The filter lives entirely here, on the already-emitted stream,
// rather than at the emission site -- so this rule is proven by a test on
// THIS class instead of being invisible because the event was never
// produced.
//
// **De-duplicated per `peerDeviceId`, in-process (task file §3/§6).** A
// peer retrying a handshake re-evaluates to `unknown` on every attempt --
// without this, the user would get a notification storm from a device they
// have not accepted, which is both annoying and an amplification vector.
// The de-dup set is unbounded and process-lifetime only (mirrors
// `MessageNotificationSource`/`CallNotificationSource`'s own lack of any
// persisted state) -- a fresh process (app restart) re-notifies once for a
// peer still pending, which is the correct behaviour: the user has not yet
// seen or acted on the earlier notification's outcome across a restart, and
// nothing in this task's contract asks for cross-run persistence.
//
// Never reads key material or any relationship detail beyond
// `peerDeviceId`/`state`, both already-computed, non-secret fields
// `ConnectionRequestNotice` carries (task file §6: "nothing here may read,
// log or store key material").
import 'dart:async';

import '../../../features/trust/domain/relationship.dart';
import '../../messaging/prekey_exchange.dart' show ConnectionRequestNotice;
import '../generated/notification_api.g.dart' show NotificationCategory;
import '../notification_dispatcher.dart' show NotificationSource;
import '../notification_policy.dart';

/// Posts one `connectionRequest` [NotificationFacts] per peer whose
/// connection request resolves to [RelationshipState.unknown] (task file
/// §3/§5) -- never for `blocked`, `trusted` or `allowed`, and never more
/// than once per peer within this process.
class ConnectionRequestNotificationSource implements NotificationSource {
  ConnectionRequestNotificationSource(this.requests);

  final Stream<ConnectionRequestNotice> requests;

  /// Peers this source has already turned into a posted `NotificationFacts`
  /// -- a second `unknown` evaluation for the same peer is dropped here
  /// (task file §3: "de-duplicates per peer within the process").
  final Set<String> _notifiedPeerDeviceIds = <String>{};

  /// The exact `.where().map()` idiom `CallNotificationSource.facts` and
  /// `MessageNotificationSource.facts` already use, deliberately kept
  /// rather than an `async*` generator -- `call_notification_source.dart`'s
  /// own header documents why an earlier `async*`/`await for` attempt was
  /// abandoned (it subscribed to the underlying stream on a later microtask
  /// than every other source, and left `StreamSubscription.cancel()`
  /// hanging while the generator sat suspended inside its `await for`).
  @override
  Stream<NotificationFacts> get facts => requests
      .where((notice) => notice.state == RelationshipState.unknown)
      .where((notice) => _notifiedPeerDeviceIds.add(notice.peerDeviceId))
      .map(_toFacts);

  NotificationFacts _toFacts(ConnectionRequestNotice notice) {
    return NotificationFacts(
      category: NotificationCategory.connectionRequest,
      // No conversation exists for a connection request -- the peer's own
      // device id stands in, exactly like `CallNotificationSource` reuses
      // `conversationId` for a call's identity (that source's own header).
      // Also the basis for `stableId` below, so a second (de-duplicated)
      // event for the same peer would have replaced rather than stacked,
      // had it ever reached this point.
      conversationId: notice.peerDeviceId,
      peerDeviceId: notice.peerDeviceId,
      // `RelationshipRepository` has no display-name column
      // (`design/gaps.md` GAP-003), and an `unknown` peer has none by
      // definition anyway (task file §5) -- the device id stands in, same
      // treatment as every other source in this codebase.
      peerDisplayName: notice.peerDeviceId,
      stableId: stableNotificationId(notice.peerDeviceId),
    );
  }
}
