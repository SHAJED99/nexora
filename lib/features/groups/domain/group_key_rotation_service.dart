// features/groups/domain — the ONE place a membership-epoch change becomes a
// key rotation (E07-T05). Makes FR-GROUP-004/005/006 actually true: whenever
// `groups.membership_epoch` advances (via `GroupRepository.applyEvent`,
// E07-T03's only writer of that column), this file mints a new sender-key
// chain at the new epoch, hands it only to the current member set, and then
// discards every chain below the new epoch.
//
// **Rotation is triggered by the epoch, not by the action (task file §2).**
// There is exactly one entry point either wiring path calls
// ([onEpochApplied] for this device's own action, [onRemoteEpochApplied] for
// a frame this device applied from someone else) and neither takes a
// `GroupAction` — only a `GroupEventKind`, already-applied, already-bumped.
// A `renamed` event rotates exactly like a `memberRemoved` one. There is
// deliberately no switch statement anywhere in this file that skips
// rotation for some kind — that is precisely how a real system quietly
// stops rotating on, say, `adminGranted` while still rotating on
// `memberAdded`, and the epic's whole guarantee erodes one "harmless"
// exception at a time.
//
// **The order is mint -> distribute -> discard, and it is load-bearing
// (task file §2/§6).** Discarding first would leave a window with no chain
// at all for this device to send under. Distributing to the OLD member set
// (i.e., before re-reading `GroupRepository.currentMembers`) would hand the
// new chain to a member who was just removed by this very epoch change --
// the exact defect FR-GROUP-005 exists to prevent. `GroupRepository
// .currentMembers` already filters `removed_at_epoch IS NULL` (E07-T03), so
// a removed member is never even offered as a distribution recipient here;
// `GroupCryptoService.distributeTo` (E07-T04) refuses again independently by
// `joined_at_epoch`/`removed_at_epoch` -- this file relies on both layers
// without trying to duplicate either's arithmetic.
//
// **FR-GROUP-006 (no historical access for a new member) has no exception
// path here, by explicit human decision (`OQ-E07-1`, 2026-08-26: v1 has no
// mechanism for granting a re-added or newly-added member historical
// access).** This file's public surface is exactly the three functions in
// the task's §5 contract -- no "since epoch", no "include history" flag, no
// extension point for one. Adding one is a spec violation, not a feature.
//
// **`deleted` and "this device is no longer a member" both discard EVERY
// epoch, not just below the new one (task file §2/§3 step 4).** The latter
// is operationalized as "this device's own role lookup returns null
// immediately after the event was applied" rather than by inspecting the
// frame's actor/subject, because this file's contract ([onEpochApplied]/
// [onRemoteEpochApplied]) carries only `(groupId, newEpoch, kind)` -- no
// actor or subject id. That check is deliberately symmetric between a
// voluntary `leave` and being removed by someone else: both produce a
// `memberRemoved` event and both leave this device with no legitimate
// reason to retain any old chain for a group it is no longer in. Reading
// the task's "self-leave" wording as "self leaving OR self having just been
// removed" is strictly safer than the narrower reading, never less correct
// than what the task asks for, and is the only reading this signature can
// even express.
//
// **Rotation is best-effort per recipient and never blocks the local
// change (task file §2).** [onEpochApplied]/[onRemoteEpochApplied] never
// throw: a failed recipient is a reported entry in the returned map, not an
// aborted rotation. `GroupCryptoService.distributeTo` already gives this
// file that contract (E07-T04); this file does not add its own try/catch
// around it because doing so would only hide a genuine bug in the mint or
// discard steps, which SHOULD propagate.
//
// Does NOT implement any cryptography, store or distribution mechanism --
// `ensureOwnChain`/`distributeTo`/`discardChains` are all
// `GroupCryptoService`'s (E07-T04), already tested. This file is pure
// sequencing and policy. Does NOT re-key on send, reconnect or a timer.
// Does NOT implement gap-fill for a missed epoch (`OQ-E07-7`, owner E11).
// Does NOT touch `messages`, the relay queue or the inbound pipeline
// directly -- it calls `GroupCryptoService`, which does. Does NOT add a
// table, column or migration.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `group_membership_service.dart`/`group_crypto_service.dart`: the fields
// are private (`_groups`, `_crypto`, `_selfDeviceId`) while the
// constructor's public named parameters match this task's documented §5
// call shape exactly (`groups`, `crypto`, `selfDeviceId`).
// ignore_for_file: prefer_initializing_formals
import '../../../core/auth/google_auth_service.dart' show AppFailure;
import '../../../core/crypto/group_crypto_service.dart';
import '../../../core/persistence/group_tables.dart';
import '../data/group_repository.dart';

/// The single rotation trigger in this codebase (task file §5). One
/// instance per `MessagingStack`-equivalent scope; `GroupMembershipService`
/// (E07-T03) owns the one real instance, built lazily from its own
/// `GroupRepository` and `MessagingStack.groupCryptoService` (see that
/// file's header for why lazily).
class GroupKeyRotationService {
  GroupKeyRotationService({
    required GroupRepository groups,
    required GroupCryptoService crypto,
    required String selfDeviceId,
  })  : _groups = groups,
        _crypto = crypto,
        _selfDeviceId = selfDeviceId;

  final GroupRepository _groups;
  final GroupCryptoService _crypto;
  final String _selfDeviceId;

  /// The local-action path: this device just performed a membership action
  /// and `GroupRepository.applyEvent` already committed it. Called
  /// immediately after that commit succeeds, inside neither the write
  /// transaction nor the membership-frame fan-out loop (task file §3).
  Future<Map<String, AppFailure?>> onEpochApplied({
    required String groupId,
    required int newEpoch,
    required GroupEventKind kind,
  }) =>
      _rotate(groupId: groupId, newEpoch: newEpoch, kind: kind);

  /// The receive path: this device just applied someone else's membership
  /// control frame. Every device rotates its own outbound chain on an
  /// epoch change -- rotation is not the acting device's job alone (task
  /// file §3).
  Future<Map<String, AppFailure?>> onRemoteEpochApplied({
    required String groupId,
    required int newEpoch,
    required GroupEventKind kind,
  }) =>
      _rotate(groupId: groupId, newEpoch: newEpoch, kind: kind);

  /// Group deleted, or this device left it: no decryptable material for
  /// [groupId] remains on this device (task file §5). Reads the group's
  /// current epoch and discards every row at or below it -- the same
  /// "discard everything" primitive [_rotate]'s own step 4 calls, exposed
  /// directly so a caller with only a group id (no in-flight epoch) can
  /// still reach it, and so `EARS-GROUP-16`'s test can exercise it in
  /// isolation.
  Future<int> discardAllFor(String groupId) async {
    final group = await _groups.groupRow(groupId);
    final belowEpoch = (group?.membershipEpoch ?? -1) + 1;
    return _crypto.discardChains(groupId: groupId, belowEpoch: belowEpoch);
  }

  /// Mint -> distribute -> discard, in that order (task file §2/§6) --
  /// identical for the local-action and remote-apply callers, which is
  /// exactly the point: every device runs the same rotation regardless of
  /// which one triggered the epoch change.
  Future<Map<String, AppFailure?>> _rotate({
    required String groupId,
    required int newEpoch,
    required GroupEventKind kind,
  }) async {
    // 1. Mint this device's own chain for the new epoch. Idempotent
    // (`GroupCryptoService.ensureOwnChain`, E07-T04) -- a second rotation
    // that somehow re-targets an epoch this device already minted a chain
    // for returns the same chain rather than a fresh one.
    await _crypto.ensureOwnChain(groupId: groupId, epoch: newEpoch);

    // 2. Distribute to the NEW current member set, re-read from the
    // repository AFTER the epoch bump -- never the set this device had in
    // memory before the change. `currentMembers` already excludes anyone
    // with `removed_at_epoch` set (E07-T03), and `distributeTo` refuses
    // again by `joined_at_epoch`/`removed_at_epoch` independently
    // (E07-T04) -- a removed member is excluded twice over, never once.
    final members = await _groups.currentMembers(groupId);
    final recipients = members
        .map((m) => m.deviceId)
        .where((deviceId) => deviceId != _selfDeviceId)
        .toList(growable: false);
    // `distributeTo` with an empty recipient list is documented as a
    // no-op success (E07-T04) -- the last-member-leaves / deleteGroup case
    // this file must never treat as an error.
    final results = await _crypto.distributeTo(
      groupId: groupId,
      epoch: newEpoch,
      recipientDeviceIds: recipients,
    );

    // 3. Discard every chain below the new epoch. Only now -- after
    // minting and distributing -- so there is never a window with no
    // chain at all for this device to send under.
    await _crypto.discardChains(groupId: groupId, belowEpoch: newEpoch);

    // 4. `deleted`, or this device no longer being a member (§ above):
    // discard EVERYTHING, including the chain just minted in step 1. Not
    // an optimization to skip step 1-3 for this case -- the task's own
    // sequence runs them unconditionally first, then layers this on top.
    final stillAMember =
        await _groups.roleOf(groupId, _selfDeviceId) != null;
    if (kind == GroupEventKind.deleted ||
        (kind == GroupEventKind.memberRemoved && !stillAMember)) {
      await discardAllFor(groupId);
    }

    return results;
  }
}
