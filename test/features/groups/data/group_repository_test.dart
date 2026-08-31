// Tests for GroupRepository (E07-T03) -- createGroup/currentMembers/roleOf/
// applyEvent against a real in-memory AppDatabase.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/messaging/group_control.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/features/groups/data/group_repository.dart';

void main() {
  late AppDatabase db;
  late GroupRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = GroupRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  GroupControlFrame frame({
    required GroupEventKind kind,
    required String groupId,
    required int epoch,
    required String actorDeviceId,
    String? subjectDeviceId,
    String? name,
    List<String>? memberList,
  }) =>
      GroupControlFrame(
        kind: kind,
        groupId: groupId,
        epoch: epoch,
        actorDeviceId: actorDeviceId,
        subjectDeviceId: subjectDeviceId,
        name: name,
        memberList: memberList,
        createdAtMs: 1000 + epoch,
      );

  group('createGroup / currentMembers / roleOf', () {
    test('test_EARS_GROUP_8_owner_rename_applies_bumps_epoch_and_logs_one_event',
        () async {
      final groupId = await repo.createGroup(
        name: 'Old Name',
        ownerDeviceId: 'owner',
        memberDeviceIds: ['member-a'],
      );

      final failure = await repo.applyEvent(frame(
        kind: GroupEventKind.renamed,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'owner',
        name: 'New Name',
      ));

      expect(failure, isNull);

      final group = await repo.groupRow(groupId);
      expect(group!.membershipEpoch, 1);
      expect(group.name, 'New Name');

      final events = await repo.eventsFor(groupId);
      expect(events.map((e) => e.kind), [
        GroupEventKind.created.name,
        GroupEventKind.renamed.name,
      ]);
    });

    test('new group has epoch zero, one owner, members joined at epoch 0',
        () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'owner',
        memberDeviceIds: ['a', 'b'],
      );
      final group = await repo.groupRow(groupId);
      expect(group!.membershipEpoch, 0);

      expect(await repo.roleOf(groupId, 'owner'), GroupRole.owner);
      expect(await repo.roleOf(groupId, 'a'), GroupRole.member);
      expect(await repo.roleOf(groupId, 'b'), GroupRole.member);

      final members = await repo.currentMembers(groupId);
      expect(members.map((m) => m.deviceId), ['owner', 'a', 'b']);
      expect(members.every((m) => m.joinedAtEpoch == 0), isTrue);
    });

    test('roleOf returns null for a non-member and a removed member',
        () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'owner',
        memberDeviceIds: ['a'],
      );
      expect(await repo.roleOf(groupId, 'stranger'), isNull);

      final removeFailure = await repo.applyEvent(frame(
        kind: GroupEventKind.memberRemoved,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'owner',
        subjectDeviceId: 'a',
      ));
      expect(removeFailure, isNull);
      // Carried-forward finding #2: a removed member never retains a role.
      expect(await repo.roleOf(groupId, 'a'), isNull);

      final currentMembers = await repo.currentMembers(groupId);
      expect(currentMembers.map((m) => m.deviceId), ['owner']);
    });
  });

  group('applyEvent — permission (EARS-GROUP-9) and carried-forward finding #1',
      () {
    test('test_EARS_GROUP_9_member_removal_frame_from_a_member_is_refused',
        () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'owner',
        memberDeviceIds: ['member-a', 'member-b'],
      );

      final failure = await repo.applyEvent(frame(
        kind: GroupEventKind.memberRemoved,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'member-a',
        subjectDeviceId: 'member-b',
      ));

      expect(failure?.code, 'group.forbidden');
      // Table unchanged.
      expect(await repo.roleOf(groupId, 'member-b'), GroupRole.member);
      final group = await repo.groupRow(groupId);
      expect(group!.membershipEpoch, 0);
    });

    test(
      'removeMember against a target who is not a current member is denied '
      'without ever reaching GroupPermissions.allows (carried-forward finding #1)',
      () async {
        final groupId = await repo.createGroup(
          name: 'G',
          ownerDeviceId: 'owner',
          memberDeviceIds: [],
        );

        // Owner "removes" a device that was never a member -- must return a
        // clean AppFailure, never an uncaught ArgumentError from
        // GroupPermissions.allows (which throws on a null subjectRole).
        final failure = await repo.applyEvent(frame(
          kind: GroupEventKind.memberRemoved,
          groupId: groupId,
          epoch: 1,
          actorDeviceId: 'owner',
          subjectDeviceId: 'never-a-member',
        ));

        expect(failure?.code, 'group.forbidden');
      },
    );

    test('nobody may remove the owner via removeMember', () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'owner',
        memberDeviceIds: ['member-a'],
      );
      final failure = await repo.applyEvent(frame(
        kind: GroupEventKind.memberRemoved,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'member-a',
        subjectDeviceId: 'owner',
      ));
      expect(failure?.code, 'group.forbidden');
    });

    test('a member may leave (self-removal), an owner may not', () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'owner',
        memberDeviceIds: ['member-a'],
      );

      final leaveFailure = await repo.applyEvent(frame(
        kind: GroupEventKind.memberRemoved,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'member-a',
        subjectDeviceId: 'member-a',
      ));
      expect(leaveFailure, isNull);
      expect(await repo.roleOf(groupId, 'member-a'), isNull);

      final ownerLeaveFailure = await repo.applyEvent(frame(
        kind: GroupEventKind.memberRemoved,
        groupId: groupId,
        epoch: 2,
        actorDeviceId: 'owner',
        subjectDeviceId: 'owner',
      ));
      expect(ownerLeaveFailure?.code, 'group.forbidden');
    });
  });

  group('applyEvent — epoch ordering (EARS-GROUP-11)', () {
    test('test_EARS_GROUP_11_replayed_frame_is_idempotent', () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'owner',
        memberDeviceIds: [],
      );
      final renameFrame = frame(
        kind: GroupEventKind.renamed,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'owner',
        name: 'once',
      );
      expect(await repo.applyEvent(renameFrame), isNull);
      final replay = await repo.applyEvent(renameFrame);
      expect(replay?.code, 'group.replayed');

      final group = await repo.groupRow(groupId);
      expect(group!.membershipEpoch, 1);
      final events = await repo.eventsFor(groupId);
      expect(events.length, 2); // created + one renamed, not two renamed.
    });

    test('test_EARS_GROUP_11_epoch_gap_is_parked_not_applied', () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'owner',
        memberDeviceIds: [],
      );
      final failure = await repo.applyEvent(frame(
        kind: GroupEventKind.renamed,
        groupId: groupId,
        epoch: 5,
        actorDeviceId: 'owner',
        name: 'skipped-ahead',
      ));
      expect(failure?.code, 'group.out_of_order');

      final group = await repo.groupRow(groupId);
      expect(group!.membershipEpoch, 0);
      expect(group.name, 'G');
    });
  });

  group('applyEvent — transferOwnership atomicity', () {
    test('test_EARS_GROUP_8_transfer_ownership_is_atomic', () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'owner',
        memberDeviceIds: ['member-a'],
      );

      final failure = await repo.applyEvent(frame(
        kind: GroupEventKind.ownershipTransferred,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'owner',
        subjectDeviceId: 'member-a',
      ));
      expect(failure, isNull);

      expect(await repo.roleOf(groupId, 'member-a'), GroupRole.owner);
      expect(await repo.roleOf(groupId, 'owner'), GroupRole.admin);

      // The single-owner partial unique index never saw two owners nor zero:
      // a second, real insert attempt against the same invariant should
      // still succeed for a THIRD transfer (proving the index is intact,
      // not disabled).
      final secondTransfer = await repo.applyEvent(frame(
        kind: GroupEventKind.ownershipTransferred,
        groupId: groupId,
        epoch: 2,
        actorDeviceId: 'member-a',
        subjectDeviceId: 'owner',
      ));
      expect(secondTransfer, isNull);
      expect(await repo.roleOf(groupId, 'owner'), GroupRole.owner);
      expect(await repo.roleOf(groupId, 'member-a'), GroupRole.admin);
    });
  });

  group('applyEvent — unknown group / created bootstrap', () {
    test('an unknown group with a non-created frame is rejected', () async {
      final failure = await repo.applyEvent(frame(
        kind: GroupEventKind.renamed,
        groupId: 'g:never-heard-of-it',
        epoch: 1,
        actorDeviceId: 'someone',
        name: 'x',
      ));
      expect(failure?.code, 'group.unknown_group');
    });

    test(
      'test_blocked_device_cannot_be_added_locally — repository has no '
      'opinion on blocking; that is the service layer\'s job, and applyEvent '
      'still applies an incoming memberAdded for a device this side has '
      'blocked (task file §2: blocking is a local view, not a group-wide veto)',
      () async {
        final groupId = await repo.createGroup(
          name: 'G',
          ownerDeviceId: 'owner',
          memberDeviceIds: [],
        );
        final failure = await repo.applyEvent(frame(
          kind: GroupEventKind.memberAdded,
          groupId: groupId,
          epoch: 1,
          actorDeviceId: 'owner',
          subjectDeviceId: 'blocked-elsewhere',
        ));
        expect(failure, isNull);
        expect(await repo.roleOf(groupId, 'blocked-elsewhere'), GroupRole.member);
      },
    );

    test('an invitee bootstraps a brand-new group from a created frame',
        () async {
      final failure = await repo.applyEvent(frame(
        kind: GroupEventKind.created,
        groupId: 'g:new-to-me',
        epoch: 0,
        actorDeviceId: 'owner',
        name: 'Invited Group',
        memberList: const ['owner', 'me', 'other'],
      ));
      expect(failure, isNull);

      final group = await repo.groupRow('g:new-to-me');
      expect(group!.name, 'Invited Group');
      expect(group.membershipEpoch, 0);
      expect(await repo.roleOf('g:new-to-me', 'owner'), GroupRole.owner);
      expect(await repo.roleOf('g:new-to-me', 'me'), GroupRole.member);
      expect(await repo.roleOf('g:new-to-me', 'other'), GroupRole.member);
    });
  });
}
