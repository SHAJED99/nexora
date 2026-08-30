// features/groups/domain — the group role permission matrix (E07-T02).
//
// One pure, total function answers "may this role perform this action on
// this group?", so E07-T03 (the membership control protocol), E07-T06
// (message fan-out) and any future UI (design/gaps.md GAP-019) enforce the
// *same* answer instead of three similar ones. See this task's §1/§2 for the
// full reasoning and `epics/E07-groups-calls/tasks/E07-T02.md` §5 for the
// literal matrix this file must not deviate from.
//
// This file does NOT read or write the database (§4) — no I/O, no clock, no
// `dart:io`. The caller loads `actorRole`/`subjectRole` from
// `GroupMembers` (E07-T01) and passes them in.
import '../../../core/auth/google_auth_service.dart' show AppFailure;
import '../../../core/persistence/group_tables.dart' show GroupRole;

/// One value per FR-GROUP-002/003 action. `removeMember` and `removeAdmin`
/// are separate because the Admin matrix distinguishes them (§5) — removing
/// a plain member is a reversible act an Admin may also perform; removing an
/// admin is not.
enum GroupAction {
  rename,
  addMember,
  removeMember,
  removeAdmin,
  grantAdmin,
  revokeAdmin,
  transferOwnership,
  deleteGroup,
  leave,
  sendMessage,
}

/// The single source of truth for FR-GROUP-001/002/003 — who may do what to
/// a group, given only the acting device's *current* role in *that* group
/// (§2). Never widen this beyond the task's §5 table without a new task: the
/// Admin matrix is deliberately narrow per `OQ-E07-5`.
class GroupPermissions {
  const GroupPermissions._();

  /// Returns `true` iff [actorRole] may perform [action], optionally against
  /// a member currently holding [subjectRole]. Total — never returns `null`.
  ///
  /// [subjectRole] is required (non-null) for the two actions the §5 table
  /// conditions on it — `removeMember` and `removeAdmin` — because "remove
  /// *whom*" is not a well-formed question without a subject. Passing `null`
  /// there is a programming error, not a permission decision (§6 risk
  /// note), so it throws an [ArgumentError] rather than silently returning
  /// `false` — a silent `false` at the call site reads as "not permitted"
  /// and would hide the bug.
  ///
  /// For every other action, [subjectRole] is not part of the §5 table's
  /// distinction and is ignored (any value, including `null`, gives the
  /// same answer).
  static bool allows({
    required GroupRole actorRole,
    required GroupAction action,
    GroupRole? subjectRole,
  }) {
    switch (action) {
      case GroupAction.rename:
      case GroupAction.addMember:
        return actorRole == GroupRole.owner || actorRole == GroupRole.admin;

      case GroupAction.removeMember:
        if (subjectRole == null) {
          throw ArgumentError.value(
            subjectRole,
            'subjectRole',
            'GroupAction.removeMember requires a subjectRole — '
                '"remove whom" is not answerable without one',
          );
        }
        if (subjectRole != GroupRole.member) {
          // Nobody may remove the owner (§5); an admin subject must go
          // through GroupAction.removeAdmin instead, never removeMember.
          return false;
        }
        return actorRole == GroupRole.owner || actorRole == GroupRole.admin;

      case GroupAction.removeAdmin:
        if (subjectRole == null) {
          throw ArgumentError.value(
            subjectRole,
            'subjectRole',
            'GroupAction.removeAdmin requires a subjectRole — '
                '"remove whom" is not answerable without one',
          );
        }
        if (subjectRole != GroupRole.admin) {
          // removeAdmin only ever targets an admin (§5); a member or owner
          // subject is out of scope for this action.
          return false;
        }
        return actorRole == GroupRole.owner;

      case GroupAction.grantAdmin:
      case GroupAction.revokeAdmin:
      case GroupAction.transferOwnership:
      case GroupAction.deleteGroup:
        // Irreversible or self-elevating (§2) — Owner only, no shortcut.
        return actorRole == GroupRole.owner;

      case GroupAction.leave:
        // Every role may leave except the Owner, who must transfer
        // ownership first (§2) — otherwise E07-T01's single-owner
        // invariant becomes unsatisfiable. Deliberately NOT
        // `actorRole == owner ? false : true` collapsed into a blanket
        // owner-allows-everything shortcut anywhere else in this file (§6
        // risk note): this is the one row where Owner is denied.
        return actorRole != GroupRole.owner;

      case GroupAction.sendMessage:
        return true;
    }
  }

  /// The same decision as [allows], in the project's single error envelope
  /// (`docs/conventions.md`) for callers that need to surface a reason.
  /// Returns `null` when allowed, `AppFailure('group.forbidden')` otherwise.
  static AppFailure? check({
    required GroupRole actorRole,
    required GroupAction action,
    GroupRole? subjectRole,
  }) {
    final permitted = allows(
      actorRole: actorRole,
      action: action,
      subjectRole: subjectRole,
    );
    return permitted ? null : const AppFailure('group.forbidden');
  }
}
