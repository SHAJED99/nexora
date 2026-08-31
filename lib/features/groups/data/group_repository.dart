// features/groups/data — the durable read/write surface over E07-T01's four
// group tables (E07-T03).
//
// [applyEvent] is the ONLY writer of `groups.membership_epoch` (task file
// §5's own contract) — every membership mutation, whether this device is the
// one performing the action (`GroupMembershipService`'s local-apply path) or
// merely receiving someone else's (`GroupMembershipService.handleWireFrame`
// -> `handleControlFrame`), goes through this exact method. That single
// choke point is what makes "every receiver checks again before applying,
// against its own copy" (task file §2) true by construction rather than by
// convention: the permission re-check inside [applyEvent] runs against
// *this device's own* `GroupMembers` rows every single time, never against
// anything the frame itself claims.
//
// **Carried-forward finding #2 from E07-T02's review, applied here.**
// `GroupPermissions` is pure and only ever sees a `GroupRole` — it cannot see
// `removed_at_epoch`. Every query in this file that loads a role to feed
// `GroupPermissions.allows`/`.check` filters `removedAtEpoch IS NULL` first
// ([roleOf] does this unconditionally) — a removed member is `null`, never a
// stale role, so a removed member can never retain their last role's
// permissions through this file.
//
// **Carried-forward finding #1, applied here.** `GroupPermissions.allows`
// throws `ArgumentError` on a `null` subject for `removeMember`/
// `removeAdmin`, even though its own §5 doc says "never throws". This file
// (`_checkPermission`) never reaches that call with a `null` subjectRole: a
// `memberRemoved` frame naming a subject who is not a current member is
// answered with `AppFailure('group.forbidden')` BEFORE `GroupPermissions` is
// ever consulted (see `_checkPermission` below) — the precondition failure
// is handled here, not left to surface as an uncaught `ArgumentError` at a
// network-frame boundary.
//
// Does NOT implement `SenderKeyStore`/key distribution (E07-T04), key
// rotation (E07-T05), or message fan-out (E07-T06) — task file §4. Does NOT
// modify `database.dart` or any table definition (`group_tables.dart` is
// E07-T01's, untouched here).
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `relay_engine.dart`/`inbound_pipeline.dart`/`prekey_exchange.dart`: the
// field is private (`_db`) while the constructor's public positional/named
// parameters match this task's documented call shape.
// ignore_for_file: prefer_initializing_formals
import 'package:drift/drift.dart';

import '../../../core/auth/google_auth_service.dart' show AppFailure;
import '../../../core/messaging/group_control.dart';
import '../../../core/persistence/database.dart';
import '../../../core/persistence/group_tables.dart';
import '../domain/group_permissions.dart';

/// The four-table read/write surface `GroupMembershipService` builds on
/// (task file §3). One instance per [AppDatabase] — cheap to construct,
/// holds no state of its own beyond an in-process id counter for
/// `group_events.id`.
class GroupRepository {
  GroupRepository(this._db, {DateTime Function() clock = DateTime.now})
      : _clock = clock;

  final AppDatabase _db;
  final DateTime Function() _clock;

  int _eventIdCounter = 0;

  String _nextEventId() =>
      'ge:${_clock().microsecondsSinceEpoch}-${_eventIdCounter++}';

  /// The founding write (task file §5): a group row at epoch 0, one Owner,
  /// every member of [memberDeviceIds] joined at epoch 0, and one `created`
  /// `group_events` row — all in one transaction. [ownerDeviceId] is
  /// deduplicated out of [memberDeviceIds] if present there too.
  Future<String> createGroup({
    required String name,
    required String ownerDeviceId,
    required List<String> memberDeviceIds,
  }) async {
    final id = newGroupId();
    final now = _clock().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _db.into(_db.groups).insert(
            GroupsCompanion.insert(
              id: id,
              name: name,
              createdAt: now,
              createdByDeviceId: ownerDeviceId,
            ),
          );
      await _db.into(_db.groupMembers).insert(
            GroupMembersCompanion.insert(
              groupId: id,
              deviceId: ownerDeviceId,
              role: GroupRole.owner.name,
              joinedAtEpoch: 0,
            ),
          );
      for (final memberId in memberDeviceIds) {
        if (memberId == ownerDeviceId) continue;
        await _db.into(_db.groupMembers).insert(
              GroupMembersCompanion.insert(
                groupId: id,
                deviceId: memberId,
                role: GroupRole.member.name,
                joinedAtEpoch: 0,
              ),
            );
      }
      await _db.into(_db.groupEvents).insert(
            GroupEventsCompanion.insert(
              id: _nextEventId(),
              groupId: id,
              epoch: 0,
              kind: GroupEventKind.created.name,
              actorDeviceId: ownerDeviceId,
              createdAt: now,
            ),
          );
    });
    return id;
  }

  /// The raw `groups` row, or null if [groupId] is unknown to this device.
  Future<GroupRow?> groupRow(String groupId) =>
      (_db.select(_db.groups)..where((t) => t.id.equals(groupId)))
          .getSingleOrNull();

  /// Members with `removedAtEpoch IS NULL`, Owner first then Admins then
  /// Members, id-stable within a role (task file §5).
  Future<List<GroupMemberRow>> currentMembers(String groupId) async {
    final rows = await (_db.select(_db.groupMembers)
          ..where(
            (t) => t.groupId.equals(groupId) & t.removedAtEpoch.isNull(),
          ))
        .get();
    int rank(String role) {
      if (role == GroupRole.owner.name) return 0;
      if (role == GroupRole.admin.name) return 1;
      return 2;
    }

    rows.sort((a, b) {
      final byRole = rank(a.role).compareTo(rank(b.role));
      if (byRole != 0) return byRole;
      return a.deviceId.compareTo(b.deviceId);
    });
    return rows;
  }

  /// Null for a non-member OR a removed member — never a default role
  /// (task file §5; carried-forward finding #2's own guarantee point).
  Future<GroupRole?> roleOf(String groupId, String deviceId) async {
    final row = await (_db.select(_db.groupMembers)
          ..where(
            (t) =>
                t.groupId.equals(groupId) &
                t.deviceId.equals(deviceId) &
                t.removedAtEpoch.isNull(),
          ))
        .getSingleOrNull();
    if (row == null) return null;
    return GroupRole.values.byName(row.role);
  }

  /// Every group_events row for [groupId], oldest epoch first.
  Future<List<GroupEventRow>> eventsFor(String groupId) =>
      (_db.select(_db.groupEvents)
            ..where((t) => t.groupId.equals(groupId))
            ..orderBy([(t) => OrderingTerm.asc(t.epoch)]))
          .get();

  /// Every non-deleted group this device is (or was) a party to.
  Stream<List<GroupRow>> watchGroups() =>
      (_db.select(_db.groups)..where((t) => t.isDeleted.equals(false)))
          .watch();

  /// The single writer of `groups.membership_epoch` (task file §5). Applies
  /// [frame] transactionally — member mutation + epoch bump + one
  /// `group_events` row — after independently re-validating BOTH the
  /// permission (against this device's own current `GroupMembers` state,
  /// never the frame's claim) and the epoch ordering (task file §2:
  /// idempotent, ordered by epoch). Returns `null` on success; a typed
  /// [AppFailure] on `forbidden`/`replayed`/`out_of_order`/`unknown_group`/
  /// `malformed_control` otherwise — never throws for an ordinary
  /// rule violation.
  Future<AppFailure?> applyEvent(GroupControlFrame frame) {
    return _db.transaction<AppFailure?>(() async {
      final group = await groupRow(frame.groupId);

      if (group == null) {
        if (frame.kind != GroupEventKind.created) {
          return const AppFailure('group.unknown_group');
        }
        return _applyCreatedBootstrap(frame);
      }

      if (frame.epoch <= group.membershipEpoch) {
        // Already applied (or older than what this device already has) —
        // idempotent drop, never a re-apply (task file §2).
        return const AppFailure('group.replayed');
      }
      if (frame.epoch > group.membershipEpoch + 1) {
        // This device missed an epoch — parked, not applied speculatively
        // (task file §2, OQ-E07-7).
        return const AppFailure('group.out_of_order');
      }

      final permissionFailure = await _checkPermission(frame);
      if (permissionFailure != null) return permissionFailure;

      final mutationFailure = await _mutateMembers(frame);
      if (mutationFailure != null) return mutationFailure;

      await (_db.update(_db.groups)..where((t) => t.id.equals(frame.groupId)))
          .write(
        GroupsCompanion(
          membershipEpoch: Value(frame.epoch),
          isDeleted: frame.kind == GroupEventKind.deleted
              ? const Value(true)
              : const Value.absent(),
        ),
      );

      await _db.into(_db.groupEvents).insert(
            GroupEventsCompanion.insert(
              id: _nextEventId(),
              groupId: frame.groupId,
              epoch: frame.epoch,
              kind: frame.kind.name,
              actorDeviceId: frame.actorDeviceId,
              subjectDeviceId: Value(frame.subjectDeviceId),
              createdAt: frame.createdAtMs,
            ),
          );

      return null;
    });
  }

  /// An invitee's very first hearing of a group it has never seen locally —
  /// the receive-side half of `createGroup`'s founding write (task file §3:
  /// "`memberList` for `created`, so an invitee learns the roster"). No
  /// local permission check makes sense here (there is no local membership
  /// row to check a role against yet); the cryptographic authentication that
  /// `GroupMembershipService.handleWireFrame` already performed before
  /// calling `handleControlFrame` -> [applyEvent] is this bootstrap's only,
  /// and sufficient, gate.
  Future<AppFailure?> _applyCreatedBootstrap(GroupControlFrame frame) async {
    final members = frame.memberList;
    if (members == null || members.isEmpty) {
      return const AppFailure('group.malformed_control');
    }
    await _db.into(_db.groups).insert(
          GroupsCompanion.insert(
            id: frame.groupId,
            name: frame.name ?? '',
            createdAt: frame.createdAtMs,
            createdByDeviceId: frame.actorDeviceId,
            membershipEpoch: Value(frame.epoch),
          ),
        );
    for (final deviceId in members) {
      final role =
          deviceId == frame.actorDeviceId ? GroupRole.owner : GroupRole.member;
      await _db.into(_db.groupMembers).insert(
            GroupMembersCompanion.insert(
              groupId: frame.groupId,
              deviceId: deviceId,
              role: role.name,
              joinedAtEpoch: frame.epoch,
            ),
          );
    }
    await _db.into(_db.groupEvents).insert(
          GroupEventsCompanion.insert(
            id: _nextEventId(),
            groupId: frame.groupId,
            epoch: frame.epoch,
            kind: GroupEventKind.created.name,
            actorDeviceId: frame.actorDeviceId,
            createdAt: frame.createdAtMs,
          ),
        );
    return null;
  }

  /// Re-validates [frame]'s claimed action against THIS device's own current
  /// `GroupMembers` state — never against anything the frame itself asserts
  /// about roles. See this file's header for the two carried-forward
  /// findings this method exists to close.
  Future<AppFailure?> _checkPermission(GroupControlFrame frame) async {
    final actorRole = await roleOf(frame.groupId, frame.actorDeviceId);
    if (actorRole == null) {
      // Not a current member of this group at all -- no role, no
      // permission, full stop (task file §2).
      return const AppFailure('group.forbidden');
    }

    switch (frame.kind) {
      case GroupEventKind.created:
        // Bootstrap only reaches _checkPermission via the non-null-group
        // branch, which a `created` kind never takes for an already-known
        // group (a second `created` for the same id fails the epoch check
        // first, since a real group's epoch is always >= 0 == frame.epoch).
        return null;

      case GroupEventKind.renamed:
        if (frame.name == null) return const AppFailure('group.malformed_control');
        return GroupPermissions.check(
          actorRole: actorRole,
          action: GroupAction.rename,
        );

      case GroupEventKind.memberAdded:
        if (frame.subjectDeviceId == null) {
          return const AppFailure('group.malformed_control');
        }
        return GroupPermissions.check(
          actorRole: actorRole,
          action: GroupAction.addMember,
        );

      case GroupEventKind.memberRemoved:
        final subject = frame.subjectDeviceId;
        if (subject == null) return const AppFailure('group.malformed_control');
        if (subject == frame.actorDeviceId) {
          // A self-removal is `leave`, not `removeMember` -- distinct
          // permission row (Owner may not leave without transferring
          // first), and `GroupAction.leave` never conditions on subjectRole
          // at all, so there is no null-subject hazard here.
          return GroupPermissions.check(
            actorRole: actorRole,
            action: GroupAction.leave,
          );
        }
        final subjectRole = await roleOf(frame.groupId, subject);
        if (subjectRole == null) {
          // Carried-forward finding #1: the target is not a current member
          // (never was, or already removed) -- a precondition failure,
          // answered here as a denial BEFORE GroupPermissions.allows is
          // ever called with a null subjectRole (which would throw
          // ArgumentError for removeMember/removeAdmin).
          return const AppFailure('group.forbidden');
        }
        return GroupPermissions.check(
          actorRole: actorRole,
          action: GroupAction.removeMember,
          subjectRole: subjectRole,
        );

      case GroupEventKind.adminGranted:
        if (frame.subjectDeviceId == null) {
          return const AppFailure('group.malformed_control');
        }
        return GroupPermissions.check(
          actorRole: actorRole,
          action: GroupAction.grantAdmin,
        );

      case GroupEventKind.adminRevoked:
        if (frame.subjectDeviceId == null) {
          return const AppFailure('group.malformed_control');
        }
        return GroupPermissions.check(
          actorRole: actorRole,
          action: GroupAction.revokeAdmin,
        );

      case GroupEventKind.ownershipTransferred:
        if (frame.subjectDeviceId == null) {
          return const AppFailure('group.malformed_control');
        }
        return GroupPermissions.check(
          actorRole: actorRole,
          action: GroupAction.transferOwnership,
        );

      case GroupEventKind.deleted:
        return GroupPermissions.check(
          actorRole: actorRole,
          action: GroupAction.deleteGroup,
        );
    }
  }

  /// The actual `GroupMembers`/`Groups.name` mutation for [frame]'s kind —
  /// called only after [_checkPermission] has already returned `null`.
  /// Returns a non-null [AppFailure] only for a structurally malformed frame
  /// (a required field missing) that slipped past [_checkPermission]'s own
  /// guards for a kind that doesn't need them.
  Future<AppFailure?> _mutateMembers(GroupControlFrame frame) async {
    switch (frame.kind) {
      case GroupEventKind.renamed:
        final name = frame.name;
        if (name == null) return const AppFailure('group.malformed_control');
        await (_db.update(_db.groups)..where((t) => t.id.equals(frame.groupId)))
            .write(GroupsCompanion(name: Value(name)));
        return null;

      case GroupEventKind.memberAdded:
        final subject = frame.subjectDeviceId;
        if (subject == null) return const AppFailure('group.malformed_control');
        await _db.into(_db.groupMembers).insert(
              GroupMembersCompanion.insert(
                groupId: frame.groupId,
                deviceId: subject,
                role: GroupRole.member.name,
                joinedAtEpoch: frame.epoch,
              ),
              mode: InsertMode.insertOrReplace,
            );
        return null;

      case GroupEventKind.memberRemoved:
        final subject = frame.subjectDeviceId;
        if (subject == null) return const AppFailure('group.malformed_control');
        await (_db.update(_db.groupMembers)
              ..where(
                (t) => t.groupId.equals(frame.groupId) & t.deviceId.equals(subject),
              ))
            .write(GroupMembersCompanion(removedAtEpoch: Value(frame.epoch)));
        return null;

      case GroupEventKind.adminGranted:
        final subject = frame.subjectDeviceId;
        if (subject == null) return const AppFailure('group.malformed_control');
        await (_db.update(_db.groupMembers)
              ..where(
                (t) => t.groupId.equals(frame.groupId) & t.deviceId.equals(subject),
              ))
            .write(GroupMembersCompanion(role: Value(GroupRole.admin.name)));
        return null;

      case GroupEventKind.adminRevoked:
        final subject = frame.subjectDeviceId;
        if (subject == null) return const AppFailure('group.malformed_control');
        await (_db.update(_db.groupMembers)
              ..where(
                (t) => t.groupId.equals(frame.groupId) & t.deviceId.equals(subject),
              ))
            .write(GroupMembersCompanion(role: Value(GroupRole.member.name)));
        return null;

      case GroupEventKind.ownershipTransferred:
        final newOwner = frame.subjectDeviceId;
        if (newOwner == null) return const AppFailure('group.malformed_control');
        // Demote the OLD owner (the actor) first, promote the new owner
        // second -- both inside this one already-open transaction, so
        // E07-T01's partial unique index (`idx_group_single_owner`) never
        // observes two current owners, and demoting first means it never
        // observes zero for longer than this one statement either (task
        // file §6 risk: "must be inside one transaction, or the index will
        // reject the intermediate state").
        await (_db.update(_db.groupMembers)
              ..where(
                (t) =>
                    t.groupId.equals(frame.groupId) &
                    t.deviceId.equals(frame.actorDeviceId),
              ))
            .write(GroupMembersCompanion(role: Value(GroupRole.admin.name)));
        await (_db.update(_db.groupMembers)
              ..where(
                (t) => t.groupId.equals(frame.groupId) & t.deviceId.equals(newOwner),
              ))
            .write(GroupMembersCompanion(role: Value(GroupRole.owner.name)));
        return null;

      case GroupEventKind.deleted:
        // `isDeleted` is set by the caller (applyEvent) alongside the epoch
        // bump -- nothing else to mutate here.
        return null;

      case GroupEventKind.created:
        // Bootstrap is handled entirely by _applyCreatedBootstrap; this
        // branch is unreachable from applyEvent's non-null-group path (see
        // _checkPermission's own comment for why).
        return null;
    }
  }
}
