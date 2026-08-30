// Tests for E07-T02's group role permission matrix — the single source of
// truth FR-GROUP-001/002/003 name, and the thing E07-T03/T06/UI all defer to
// instead of re-deriving their own answer.
//
// See `epics/E07-groups-calls/tasks/E07-T02.md` §5 for the literal matrix
// this file asserts against, cell by cell.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/persistence/group_tables.dart' show GroupRole;
import 'package:nexora/features/groups/domain/group_permissions.dart';

/// A single expected outcome for one `(actorRole, action, subjectRole)`
/// cell. [throwsArgError] marks a cell that is a programming error (§6) —
/// `subjectRole == null` for a member-directed action — rather than a real
/// permission decision, so the expectation is "throws", not "false".
class _Expected {
  const _Expected(this.allowed, {this.throwsArgError = false});
  final bool allowed;
  final bool throwsArgError;
}

void main() {
  const roles = GroupRole.values;
  // subjectRole ranges over every role plus null.
  const subjects = <GroupRole?>[GroupRole.owner, GroupRole.admin, GroupRole.member, null];

  /// The literal expectation table from the task's §5 matrix, expanded to
  /// every `(action, subjectRole)` pair this task's implementation
  /// distinguishes. Actions not conditioned on `subjectRole` by the §5
  /// table (rename, addMember, grantAdmin, revokeAdmin, transferOwnership,
  /// deleteGroup, leave, sendMessage) give the same answer for every
  /// subject, including null — the table simply doesn't vary on it.
  Map<GroupRole, _Expected> perActorFor(GroupAction action, GroupRole? subject) {
    switch (action) {
      case GroupAction.rename:
      case GroupAction.addMember:
        return const {
          GroupRole.owner: _Expected(true),
          GroupRole.admin: _Expected(true),
          GroupRole.member: _Expected(false),
        };
      case GroupAction.removeMember:
        if (subject == null) {
          return const {
            GroupRole.owner: _Expected(false, throwsArgError: true),
            GroupRole.admin: _Expected(false, throwsArgError: true),
            GroupRole.member: _Expected(false, throwsArgError: true),
          };
        }
        if (subject == GroupRole.member) {
          return const {
            GroupRole.owner: _Expected(true),
            GroupRole.admin: _Expected(true),
            GroupRole.member: _Expected(false),
          };
        }
        // subject == owner OR subject == admin: removeMember never applies
        // to either — the owner is never removable, and an admin subject
        // must go through removeAdmin instead.
        return const {
          GroupRole.owner: _Expected(false),
          GroupRole.admin: _Expected(false),
          GroupRole.member: _Expected(false),
        };
      case GroupAction.removeAdmin:
        if (subject == null) {
          return const {
            GroupRole.owner: _Expected(false, throwsArgError: true),
            GroupRole.admin: _Expected(false, throwsArgError: true),
            GroupRole.member: _Expected(false, throwsArgError: true),
          };
        }
        if (subject == GroupRole.admin) {
          return const {
            GroupRole.owner: _Expected(true),
            GroupRole.admin: _Expected(false),
            GroupRole.member: _Expected(false),
          };
        }
        // subject == owner OR subject == member: removeAdmin never applies.
        return const {
          GroupRole.owner: _Expected(false),
          GroupRole.admin: _Expected(false),
          GroupRole.member: _Expected(false),
        };
      case GroupAction.grantAdmin:
      case GroupAction.revokeAdmin:
      case GroupAction.transferOwnership:
      case GroupAction.deleteGroup:
        return const {
          GroupRole.owner: _Expected(true),
          GroupRole.admin: _Expected(false),
          GroupRole.member: _Expected(false),
        };
      case GroupAction.leave:
        return const {
          GroupRole.owner: _Expected(false),
          GroupRole.admin: _Expected(true),
          GroupRole.member: _Expected(true),
        };
      case GroupAction.sendMessage:
        return const {
          GroupRole.owner: _Expected(true),
          GroupRole.admin: _Expected(true),
          GroupRole.member: _Expected(true),
        };
    }
  }

  group('test_matrix_is_exhaustive_and_matches_the_contract_table', () {
    for (final action in GroupAction.values) {
      for (final subject in subjects) {
        final expectedByActor = perActorFor(action, subject);
        for (final actor in roles) {
          final expected = expectedByActor[actor]!;
          test('$action / actor=$actor / subject=$subject', () {
            if (expected.throwsArgError) {
              expect(
                () => GroupPermissions.allows(
                  actorRole: actor,
                  action: action,
                  subjectRole: subject,
                ),
                throwsArgumentError,
              );
            } else {
              expect(
                GroupPermissions.allows(
                  actorRole: actor,
                  action: action,
                  subjectRole: subject,
                ),
                expected.allowed,
                reason: '$action by $actor on subject=$subject',
              );
            }
          });
        }
      }
    }
  });

  test('test_EARS_GROUP_6_owner_may_perform_every_fr_group_002_action', () {
    // FR-GROUP-002's exact list: rename, add members, remove members,
    // assign administrators, transfer ownership, delete the group.
    expect(
      GroupPermissions.allows(actorRole: GroupRole.owner, action: GroupAction.rename),
      isTrue,
    );
    expect(
      GroupPermissions.allows(actorRole: GroupRole.owner, action: GroupAction.addMember),
      isTrue,
    );
    expect(
      GroupPermissions.allows(
        actorRole: GroupRole.owner,
        action: GroupAction.removeMember,
        subjectRole: GroupRole.member,
      ),
      isTrue,
    );
    expect(
      GroupPermissions.allows(
        actorRole: GroupRole.owner,
        action: GroupAction.grantAdmin,
        subjectRole: GroupRole.member,
      ),
      isTrue,
    );
    expect(
      GroupPermissions.allows(
        actorRole: GroupRole.owner,
        action: GroupAction.revokeAdmin,
        subjectRole: GroupRole.admin,
      ),
      isTrue,
    );
    expect(
      GroupPermissions.allows(
        actorRole: GroupRole.owner,
        action: GroupAction.transferOwnership,
        subjectRole: GroupRole.admin,
      ),
      isTrue,
    );
    expect(
      GroupPermissions.allows(actorRole: GroupRole.owner, action: GroupAction.deleteGroup),
      isTrue,
    );
  });

  test('test_EARS_GROUP_7_admin_cannot_grant_admin_or_transfer_or_delete', () {
    expect(
      GroupPermissions.allows(
        actorRole: GroupRole.admin,
        action: GroupAction.grantAdmin,
        subjectRole: GroupRole.member,
      ),
      isFalse,
    );
    expect(
      GroupPermissions.allows(
        actorRole: GroupRole.admin,
        action: GroupAction.revokeAdmin,
        subjectRole: GroupRole.admin,
      ),
      isFalse,
    );
    expect(
      GroupPermissions.allows(
        actorRole: GroupRole.admin,
        action: GroupAction.transferOwnership,
        subjectRole: GroupRole.member,
      ),
      isFalse,
    );
    expect(
      GroupPermissions.allows(actorRole: GroupRole.admin, action: GroupAction.deleteGroup),
      isFalse,
    );
  });

  test('test_EARS_GROUP_7_member_cannot_perform_any_management_action', () {
    for (final action in GroupAction.values) {
      if (action == GroupAction.sendMessage || action == GroupAction.leave) continue;
      final subject = switch (action) {
        GroupAction.removeMember => GroupRole.member,
        GroupAction.removeAdmin => GroupRole.admin,
        GroupAction.grantAdmin || GroupAction.revokeAdmin || GroupAction.transferOwnership =>
          GroupRole.member,
        _ => null,
      };
      expect(
        GroupPermissions.allows(actorRole: GroupRole.member, action: action, subjectRole: subject),
        isFalse,
        reason: 'Member must not be permitted to $action',
      );
    }
  });

  test('test_EARS_GROUP_7_denial_returns_group_forbidden_failure', () {
    final failure = GroupPermissions.check(
      actorRole: GroupRole.member,
      action: GroupAction.deleteGroup,
    );
    expect(failure, isA<AppFailure>());
    expect(failure!.code, 'group.forbidden');

    final allowed = GroupPermissions.check(
      actorRole: GroupRole.owner,
      action: GroupAction.deleteGroup,
    );
    expect(allowed, isNull);
  });

  test('test_owner_cannot_leave_without_transferring_first', () {
    expect(
      GroupPermissions.allows(actorRole: GroupRole.owner, action: GroupAction.leave),
      isFalse,
    );
    expect(
      GroupPermissions.allows(actorRole: GroupRole.admin, action: GroupAction.leave),
      isTrue,
    );
    expect(
      GroupPermissions.allows(actorRole: GroupRole.member, action: GroupAction.leave),
      isTrue,
    );
  });

  test('test_nobody_can_remove_the_owner', () {
    for (final actor in roles) {
      expect(
        GroupPermissions.allows(
          actorRole: actor,
          action: GroupAction.removeMember,
          subjectRole: GroupRole.owner,
        ),
        isFalse,
        reason: '$actor must never be able to remove the owner',
      );
    }
  });

  test('removeMember with null subjectRole is a programming error, not false', () {
    expect(
      () => GroupPermissions.allows(
        actorRole: GroupRole.owner,
        action: GroupAction.removeMember,
      ),
      throwsArgumentError,
    );
  });

  test('removeAdmin with null subjectRole is a programming error, not false', () {
    expect(
      () => GroupPermissions.allows(
        actorRole: GroupRole.owner,
        action: GroupAction.removeAdmin,
      ),
      throwsArgumentError,
    );
  });
}
