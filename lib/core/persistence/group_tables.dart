// core/persistence — group data model tables (ADR-0001, E07-T01).
//
// Four tables give every later E07 task one durable place to keep what a
// group *is* (this task's §1): its identity (`Groups`), its membership
// roster (`GroupMembers`), the per-sender Sender-Keys state the group
// encryption layer will read/write (`GroupSenderKeys`, E07-T04), and the
// append-only membership-change log (`GroupEvents`, E07-T02/T06). No group
// message body and no key material is generated or interpreted here — this
// file only defines storage shape, per this task's §4.
import 'dart:math';

import 'package:drift/drift.dart';

/// FR-GROUP-001's three roles. Persisted by `.name`, never by index
/// (docs/conventions.md "Enums") — see [GroupMembers.role].
enum GroupRole { owner, admin, member }

/// FR-GROUP-002's membership-change action list — one enum value per
/// action, so the event log (`GroupEvents`) and the permission matrix
/// (E07-T02) cannot drift apart. Persisted by `.name`, never by index.
enum GroupEventKind {
  created,
  renamed,
  memberAdded,
  memberRemoved,
  adminGranted,
  adminRevoked,
  ownershipTransferred,
  deleted,
}

/// The one place a group id is minted. The `g:` prefix keeps the widened
/// `conversationId` space (E06-T09 §2) unambiguous against a 1:1
/// conversation's `conversationId == peerDeviceId` — no reader ever has to
/// guess which kind of conversation it is holding, and an attacker cannot
/// mint a group id that collides with a real peer's device id (§2).
///
/// [random] is injectable for deterministic tests; production callers omit
/// it and get `Random.secure()` so minted ids are not guessable.
String newGroupId({Random? random}) {
  final rng = random ?? Random.secure();
  const hexDigits = '0123456789abcdef';
  final buffer = StringBuffer('g:');
  for (var i = 0; i < 32; i++) {
    buffer.write(hexDigits[rng.nextInt(16)]);
  }
  return buffer.toString();
}

/// One row per group — its identity, name, and the membership epoch that
/// key rotation (E07-T05) keys off (§2). `id` is a locally-minted,
/// `g:`-prefixed, globally unique id (§2) — never a device id.
///
/// `membershipEpoch` is monotonically increasing and bumped by every
/// membership change (FR-GROUP-004); this task only guarantees it exists
/// and starts at 0 for a newly created group (EARS-GROUP-3). `isDeleted`
/// marks a group as gone without dropping its row, mirroring
/// `GroupMembers.removedAtEpoch`'s "mark, don't delete" pattern (§2) so a
/// group's history stays auditable.
@DataClassName('GroupRow')
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Epoch-ms wall-clock creation time.
  IntColumn get createdAt => integer()();

  TextColumn get createdByDeviceId => text()();

  IntColumn get membershipEpoch => integer().withDefault(const Constant(0))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per (group, device) membership. A removed member's row is
/// retained with `removedAtEpoch` set rather than deleted, so FR-GROUP-005
/// ("a removed member shall not decrypt future communication") stays
/// auditable after the fact (§2, `OQ-E07-4` advisory 2) — never delete a
/// row here.
///
/// `joinedAtEpoch` is what makes FR-GROUP-006 ("a newly added member gets
/// no historical access", `OQ-E07-1`) checkable: nothing in this project
/// ever hands a member a `GroupSenderKeys` record for an epoch below their
/// own `joinedAtEpoch` (enforced by E07-T05; this table only carries the
/// fact).
///
/// The partial unique index enforcing "exactly one current Owner per group"
/// (EARS-GROUP-3/4) is declared as raw SQL in the `12 -> 13` migration step
/// in `database.dart` (and via `TableIndex.sql` here for a fresh install),
/// because `docs/conventions.md`'s single-owner invariant must be enforced
/// by the database, not by application code that someone will forget to
/// call (§6 risk note).
@DataClassName('GroupMemberRow')
@TableIndex(
  name: 'idx_group_members_current',
  columns: {#groupId, #removedAtEpoch},
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_group_single_owner ON group_members(group_id) '
  "WHERE role = 'owner' AND removed_at_epoch IS NULL",
)
class GroupMembers extends Table {
  TextColumn get groupId => text()();
  TextColumn get deviceId => text()();

  /// A [GroupRole] value's `.name`, never an integer index.
  TextColumn get role => text()();

  /// The `groups.membership_epoch` value in effect when this member joined
  /// (§2) — the floor below which this member is never handed a sender-key
  /// record (FR-GROUP-006).
  IntColumn get joinedAtEpoch => integer()();

  /// NULL = current member. Set (never cleared) once a member is removed —
  /// the row itself is never deleted (§2).
  IntColumn get removedAtEpoch => integer().nullable()();

  @override
  Set<Column> get primaryKey => {groupId, deviceId};
}

/// One row per `(groupId, senderDeviceId, membershipEpoch)` — the single
/// most important shape decision in this table set (§2). libsignal's
/// `SenderKeyName` is `(groupId, sender)` only; keying this table by the
/// membership epoch as well means a rotation (E07-T05) can hold a removed
/// member's old chain and the new chain apart as distinct rows during the
/// window both exist in flight, and FR-GROUP-005 becomes a delete of one
/// row set rather than an overwrite race (`OQ-E07-4` advisory 1). See
/// `E07-T04` §2 for the mapping back onto libsignal's two-part
/// `SenderKeyName`.
///
/// `record` is an opaque libsignal `SenderKeyRecord` blob — never generated,
/// parsed or interpreted by anything in this file (§4; that's E07-T04).
@DataClassName('GroupSenderKeyRow')
class GroupSenderKeys extends Table {
  TextColumn get groupId => text()();
  TextColumn get senderDeviceId => text()();
  IntColumn get membershipEpoch => integer()();

  BlobColumn get record => blob()();

  /// Epoch-ms wall-clock time this row was last written.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {groupId, senderDeviceId, membershipEpoch};
}

/// The append-only membership-change log FR-GROUP-002's actions produce and
/// E07-T06's in-thread system messages render from (§3). Kept as its own
/// table rather than synthetic rows in `messages` (`OQ-E07-4` advisory 3) —
/// every row in `messages` is currently assumed to carry ciphertext, and a
/// non-message row would break that assumption.
@DataClassName('GroupEventRow')
@TableIndex(
  name: 'idx_group_events_group_epoch',
  columns: {#groupId, #epoch},
)
class GroupEvents extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();

  /// The `groups.membership_epoch` in effect when this event was recorded.
  IntColumn get epoch => integer()();

  /// A [GroupEventKind] value's `.name`, never an integer index.
  TextColumn get kind => text()();

  TextColumn get actorDeviceId => text()();

  /// The member the event is about (e.g. who was added/removed), when the
  /// event kind has one. NULL for group-level events like `renamed`.
  TextColumn get subjectDeviceId => text().nullable()();

  /// Epoch-ms wall-clock creation time.
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
