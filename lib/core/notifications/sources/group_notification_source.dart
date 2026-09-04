// core/notifications/sources — the `groupEvent` category producer
// (E10-T06, EARS-NOTIFY-12/13).
//
// Adapts `GroupMembershipService.groupEvents` (this task's own addition to
// `group_membership_service.dart`, an E07-owned file -- see that file's
// own header for why the stream is emitted ONLY from
// `handleControlFrame`'s inbound success branch) into `NotificationFacts`
// for every notice it receives -- unlike `ConnectionRequestNotificationSource`
// (E10-T05), no state-based filter is needed here: the self-vs-other and
// local-vs-inbound distinctions are both already resolved upstream, before
// a `GroupEventNotice` is ever published (task file §2 -- "the distinction
// is structural -- the emission point is the inbound handler, not
// `_perform` -- so it cannot drift").
//
// **`selfDeviceId` is a second, defense-in-depth guard, not the primary
// filter (task file §5 signature).** `groupEvents` should structurally
// never carry a notice whose `actorDeviceId == selfDeviceId` -- inbound
// frames are, by construction, never self-authored. This source still
// drops such a notice if one ever arrived, matching this codebase's own
// established pattern of checking a security/privacy-relevant invariant
// twice (`group_membership_service.dart`'s own header: "permission is
// checked twice, both times locally"; `connection_request_notification
// _source.dart`: "blocked devices must never reach the user via any
// channel"). A defect upstream that somehow re-emitted a local change would
// otherwise notify the very user rule 2 (task file §2) says must never see
// it.
//
// **One stable notification id per `groupId` (task file §3/§5).** A burst
// of changes to one group -- e.g. two membership frames applied back to
// back -- all resolve to the SAME `stableNotificationId(groupId)`, so
// Android's `notify(id, ...)` semantics replace the prior post instead of
// stacking a new one. No additional de-dup state is needed here (unlike
// `ConnectionRequestNotificationSource`'s per-peer `Set`): the collapse is
// a property of the id being deterministic per group, not of tracking
// which groups have already notified.
//
// Never reads group membership, key material, or any control-frame content
// beyond `groupId`/`groupName`/`actorDeviceId`, all already-computed,
// non-secret fields `GroupEventNotice` carries (task file §6: "never
// decrypt group message content").
import 'dart:async';

import '../../../features/groups/domain/group_membership_service.dart'
    show GroupEventNotice;
import '../generated/notification_api.g.dart' show NotificationCategory;
import '../notification_dispatcher.dart' show NotificationSource;
import '../notification_policy.dart';

/// Posts one `groupEvent` [NotificationFacts] per inbound, already-applied
/// group change (task file §3/§5) -- one stable id per [GroupEventNotice
/// .groupId], so a burst of changes to one group collapses into one
/// notification rather than stacking a new one per change.
class GroupNotificationSource implements NotificationSource {
  GroupNotificationSource(this.events, {required this.selfDeviceId});

  final Stream<GroupEventNotice> events;
  final String selfDeviceId;

  /// The exact `.where().map()` idiom every other source in this codebase
  /// uses (`call_notification_source.dart`'s own header documents the
  /// abandoned `async*` alternative and why) -- subscribes to [events]
  /// synchronously inside `listen()`, with no suspended generator holding
  /// `StreamSubscription.cancel()` hostage.
  @override
  Stream<NotificationFacts> get facts => events
      .where((notice) => notice.actorDeviceId != selfDeviceId)
      .map(_toFacts);

  NotificationFacts _toFacts(GroupEventNotice notice) {
    return NotificationFacts(
      category: NotificationCategory.groupEvent,
      // No 1:1 conversation exists for a group event -- `groupId` stands
      // in, exactly like `CallNotificationSource` reuses a call's own
      // identity for `conversationId` (that source's own header). Also the
      // basis for `stableId` below, so every notice for the same group
      // replaces the prior post instead of stacking (task file §3).
      conversationId: notice.groupId,
      peerDeviceId: notice.actorDeviceId,
      // `NotificationPolicy._copyFor` has no `groupEvent` case yet (this
      // task's `files:` fence excludes `notification_policy.dart` --
      // `OQ-E10-T06-1`, rolled into `OQ-E10-1`), so `peerDisplayName` is
      // not read by today's copy table either way; carried through anyway
      // so a future policy pass has the group's display name on hand
      // without a further `GroupEventNotice` field.
      peerDisplayName: notice.groupName,
      stableId: stableNotificationId(notice.groupId),
    );
  }
}
