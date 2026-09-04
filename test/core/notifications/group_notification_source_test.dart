// Tests for GroupNotificationSource (E10-T06, EARS-NOTIFY-12/13).
//
// Unit-level: feeds a hand-built `Stream<GroupEventNotice>` rather than a
// real `GroupMembershipService` -- `group_membership_service_test.dart`'s
// own E10-T06 group already proves the emission side (kind mapping,
// inbound-only, no double-notify on rotation) against the real
// control-frame path; this file proves the mapping/collapse/defense-in-
// depth-filter side in isolation, mirroring
// `connection_request_notification_source_test.dart`'s own split.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_policy.dart';
import 'package:nexora/core/notifications/sources/group_notification_source.dart';
import 'package:nexora/features/groups/domain/group_membership_service.dart';

void main() {
  // Broadcast stream, no subscriber-buffering -- every test below awaits
  // one microtask after subscribing and before publishing on `controller`,
  // same discipline as `connection_request_notification_source_test.dart`.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'test_EARS_NOTIFY_12_inbound_notice_posts_one_groupEvent_notification',
    () async {
      final controller = StreamController<GroupEventNotice>.broadcast();
      final source = GroupNotificationSource(
        controller.stream,
        selfDeviceId: 'device-self',
      );

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      controller.add(
        const GroupEventNotice(
          kind: GroupNotificationEventKind.memberJoined,
          groupId: 'group-1',
          groupName: 'Weekend Trip',
          actorDeviceId: 'device-peer',
        ),
      );
      await settle();

      expect(facts, hasLength(1));
      expect(facts.single.category, NotificationCategory.groupEvent);
      expect(facts.single.conversationId, 'group-1');
      expect(facts.single.peerDeviceId, 'device-peer');
      expect(facts.single.peerDisplayName, 'Weekend Trip');
      expect(facts.single.stableId, stableNotificationId('group-1'));

      await subscription.cancel();
      await controller.close();
    },
  );

  test(
    'test_EARS_NOTIFY_12_burst_collapses_to_one_id',
    () async {
      final controller = StreamController<GroupEventNotice>.broadcast();
      final source = GroupNotificationSource(
        controller.stream,
        selfDeviceId: 'device-self',
      );

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      // Three different changes to the SAME group -- a rename, a member
      // join, an admin change -- must all carry the SAME stable id, so
      // Android's `notify(id, ...)` replaces rather than stacks (task file
      // §3/§5: "collapses a burst of changes to one group into one
      // notification").
      controller.add(
        const GroupEventNotice(
          kind: GroupNotificationEventKind.renamed,
          groupId: 'group-1',
          groupName: 'New Name',
          actorDeviceId: 'device-peer',
        ),
      );
      controller.add(
        const GroupEventNotice(
          kind: GroupNotificationEventKind.memberJoined,
          groupId: 'group-1',
          groupName: 'New Name',
          actorDeviceId: 'device-peer-2',
        ),
      );
      controller.add(
        const GroupEventNotice(
          kind: GroupNotificationEventKind.adminChanged,
          groupId: 'group-1',
          groupName: 'New Name',
          actorDeviceId: 'device-peer',
        ),
      );
      await settle();

      expect(facts, hasLength(3));
      final ids = facts.map((f) => f.stableId).toSet();
      expect(
        ids,
        hasLength(1),
        reason: 'every notice for the same groupId must share one stable '
            'notification id',
      );
      expect(ids.single, stableNotificationId('group-1'));

      await subscription.cancel();
      await controller.close();
    },
  );

  test(
    'test_EARS_NOTIFY_13_a_notice_naming_self_as_actor_posts_nothing '
    '(defense in depth)',
    () async {
      final controller = StreamController<GroupEventNotice>.broadcast();
      final source = GroupNotificationSource(
        controller.stream,
        selfDeviceId: 'device-self',
      );

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      controller.add(
        const GroupEventNotice(
          kind: GroupNotificationEventKind.renamed,
          groupId: 'group-1',
          groupName: 'New Name',
          actorDeviceId: 'device-self',
        ),
      );
      await settle();

      expect(facts, isEmpty);

      await subscription.cancel();
      await controller.close();
    },
  );

  test(
    'groupName null falls through to null peerDisplayName, never throws',
    () async {
      final controller = StreamController<GroupEventNotice>.broadcast();
      final source = GroupNotificationSource(
        controller.stream,
        selfDeviceId: 'device-self',
      );

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      controller.add(
        const GroupEventNotice(
          kind: GroupNotificationEventKind.groupDeleted,
          groupId: 'group-1',
          groupName: null,
          actorDeviceId: 'device-peer',
        ),
      );
      await settle();

      expect(facts, hasLength(1));
      expect(facts.single.peerDisplayName, isNull);

      await subscription.cancel();
      await controller.close();
    },
  );
}
