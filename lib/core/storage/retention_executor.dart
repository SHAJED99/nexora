// core/storage — the only code path that deletes stored user data (E08-T06).
//
// `RetentionExecutor.apply()` turns a `RetentionPlan` (E08-T04/T05's forecast)
// into real deletes -- and only real deletes. It is the last of three E08-T06
// invariants that must hold *unconditionally*, independent of caller, mode or
// allow-list (task §2/§6):
//
// 1. **Relay payloads are never touched here.** `RelayEngine.reclaimPayloads()`
//    (E04-B02, driven by `MessagingCoordinator` since E06-T06) already owns
//    relay TTL. A `relayPayload` candidate group is always `outcome: skipped`
//    with the owning mechanism named, regardless of what `allowedKinds` a
//    caller passes.
// 2. **A message not in a terminal delivered state is never deleted.**
//    `Queued`/`Sent`/`Failed` mean the message is in flight; deleting it
//    destroys data the user believes they sent. This guard is independent of
//    `allowedKinds` entirely -- it applies even when `message` is
//    authorised for deletion by a Manual Mode pass.
// 3. **A candidate group outside `allowedKinds` is always `outcome: skipped`**
//    with its own `RetentionReason` preserved in the log, never silently
//    dropped (`FR-STORE-007`).
//
// **The mode-dependent allow-list (`OQ-E08-T06-1`'s amendment).** The task's
// original §5 gave this executor one constructor-level `allowedKinds` set --
// unable to express `OQ-E08-3(a)`'s answer ("Smart Mode's allow-list excludes
// conversation content entirely; message deletion happens only under a
// manual policy the user explicitly turns on"). The amended contract moves
// `allowedKinds` onto `apply()` itself, supplied per call by `StorageManager`
// based on which policy produced the plan it is applying (empty for Smart
// Mode, `{message}` for Manual Mode's `olderThanDays`/`overSizeMb`) -- this
// file has no opinion of its own about what a mode may delete; it only
// enforces whatever set it is handed, plus the two guards above that no
// allow-list can ever override.
//
// **Per-group atomicity, real, not just claimed (fixed after round-1
// review's F1 finding).** An earlier version of this file logged every
// `appliedGroups` group as `outcome: applied` in one upfront batch, then
// deleted each group's rows in a separate loop -- so a delete that failed
// partway through a multi-group pass left a decision row that FALSELY
// claimed `applied` for a group whose rows were never actually removed.
// `FR-STORE-007`'s explanation surface is the ONLY record of what this app
// did to a user's data; a log entry that lies about a delete having
// happened is worse than one that is merely late. The fix: for each group
// that survives every guard above, [deleteMessageItems] and the SINGLE
// `storage_decisions` row claiming `outcome: applied` for that group are
// wrapped in one `AppDatabase.transaction()` -- so either both the delete
// and its own decision row commit together, or neither does (a delete
// whose decision row fails to write never happens either, restoring the
// task's original "unexplainable deletion" invariant in the direction that
// actually matters). If the delete throws, the transaction rolls back
// (nothing durable for that group from this attempt), and a SEPARATE,
// truthful `outcome: skipped` row (`why`: the failure) is written outside
// that rolled-back transaction -- so `storage_decisions` never goes silent
// about a group either, it just never claims success it didn't earn. Every
// group this executor declines to touch at all (relay payload, wrong mode,
// outside the allow-list, undelivered) is logged `skipped` upfront, in one
// batch, before any delete runs at all -- safe to batch, since nothing is
// ever deleted for these. Falsified (see this task's Run log) with a
// two-group plan whose second delete throws: confirmed the first group's
// `applied` row survives, the second is `skipped` (never falsely
// `applied`), and both are visible in `storage_decisions`.
library;

import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';

import '../../features/messaging/domain/delivery_state_machine.dart';
import 'retention_plan.dart';
import 'storage_decision_log.dart';
import 'storage_item.dart' show StorageItemKind;
import 'storage_settings_repository.dart' show StorageMode;

/// One candidate group [RetentionExecutor.apply] declined to delete, with a
/// human-legible (but still not user-facing display copy -- task §4)
/// [why]. [group] is scoped to exactly the items this decision covers --
/// for a mixed `message` group (some items deliverable, some not), the
/// original candidate group is split so the decision log's own reason and
/// item count/bytes describe only the items this particular outcome
/// actually applies to (never the whole original group padded onto a
/// partial outcome).
final class SkippedRetentionGroup {
  const SkippedRetentionGroup({required this.group, required this.why});

  final RetentionCandidateGroup group;

  /// Why this group's items were not deleted -- e.g. "relay payload
  /// retention is owned by RelayEngine.reclaimPayloads (E04-B02)", "kind not
  /// authorised by this pass's allowedKinds", "message not in a terminal
  /// delivered state". Not display copy (task §4); an internal/log-facing
  /// explanation only.
  final String why;
}

/// What one [RetentionExecutor.apply] call actually did.
final class RetentionOutcome {
  const RetentionOutcome({
    required this.appliedGroups,
    required this.skippedGroups,
    required this.bytesReclaimed,
  });

  /// Groups (or the deletable slice of a split group) whose items were
  /// actually deleted.
  final List<RetentionCandidateGroup> appliedGroups;

  final List<SkippedRetentionGroup> skippedGroups;

  /// Real bytes reclaimed -- the sum of [appliedGroups]' own measured
  /// bytes, never re-estimated (`EARS-STORE-9`'s "real measured bytes"
  /// discipline, carried into execution).
  final int bytesReclaimed;
}

/// The only code path in this app that deletes stored user data (task §1).
/// Delivery-state guarded; each group's delete and its own `applied`
/// decision row commit atomically together, in one `AppDatabase
/// .transaction()`, so `storage_decisions` can never claim a delete
/// succeeded when it didn't (task §2/§6; F1 fix -- see this file's header).
/// See this file's header for the three unconditional invariants.
class RetentionExecutor {
  RetentionExecutor({required this.db, required this.log});

  /// The app's single `AppDatabase` (injected, never constructed here --
  /// matches `StorageInventory`/`StorageSettingsRepository`'s own
  /// precedent).
  final AppDatabase db;

  /// The only writer of `storage_decisions` (task §3) -- this executor never
  /// writes that table directly, always through [log].
  final StorageDecisionLog log;

  /// Delivery states a `message` item must NOT be in for this executor to
  /// ever delete it (task §2's "Never delete an item that is not yet
  /// delivered" -- `EARS-STORE-14`). Independent of `allowedKinds`: even a
  /// Manual Mode pass explicitly authorised to delete `message`-kind items
  /// may only delete ones that have actually left this set.
  static const Set<DeliveryState> _undeliveredStates = {
    DeliveryState.queued,
    DeliveryState.sent,
    DeliveryState.failed,
  };

  /// Execute [plan]: every group this method declines to touch (relay
  /// payload, wrong mode, outside the allow-list, undelivered) is logged
  /// `outcome: skipped` upfront, in one batch -- safe, since nothing is
  /// ever deleted for these. Every group that survives every guard is then
  /// processed ONE AT A TIME: its delete and its own `outcome: applied`
  /// decision row are wrapped in a single `AppDatabase.transaction()`, so
  /// the log can never claim a delete happened when it didn't (round-1
  /// review's F1 finding; see this file's header for the full story). A
  /// group whose delete fails gets a truthful `outcome: skipped` row
  /// instead, written outside the rolled-back transaction, and processing
  /// continues to the next group (one bad delete must not silently drop
  /// every group after it from the explanation).
  ///
  /// [allowedKinds] is supplied per call by `StorageManager`, mode-dependent
  /// (`OQ-E08-T06-1`) -- empty for a Smart Mode plan, `{message}` for a
  /// Manual Mode plan's `olderThanDays`/`overSizeMb` groups. A candidate
  /// group outside this set is always `outcome: skipped`, regardless of
  /// mode (this file's header, invariant 3).
  Future<RetentionOutcome> apply(
    RetentionPlan plan, {
    required Set<StorageItemKind> allowedKinds,
    required int nowEpochMs,
  }) async {
    // Candidate groups cleared by every guard, pending their own individual
    // delete attempt below -- NOT yet logged as `applied` (that would be
    // this file's F1 bug: claiming a delete happened before it's known to
    // have succeeded).
    final candidatesToApply = <RetentionCandidateGroup>[];
    final skippedGroups = <SkippedRetentionGroup>[];

    for (final group in plan.groups) {
      // Invariant 1 (this file's header): relay payload retention is never
      // ours, regardless of what allowedKinds a caller passes.
      if (group.kind == StorageItemKind.relayPayload) {
        skippedGroups.add(
          SkippedRetentionGroup(
            group: group,
            why: 'relay payload retention is owned by '
                'RelayEngine.reclaimPayloads (E04-B02), never this executor',
          ),
        );
        continue;
      }

      // Defense-in-depth, on top of invariant 3 below: a Smart Mode plan
      // (`plan.mode == 'smart'`) never deletes a `message`-kind group,
      // full stop -- even if a caller passed `allowedKinds` that happens to
      // include `message` (a bug in the caller, or a future change that
      // widens Smart Mode's allow-list for some OTHER kind and forgets to
      // keep this one excluded). `OQ-E08-3(a)`/`OQ-E08-T06-1`'s answer is
      // unconditional on the Smart Mode side, so this executor enforces it
      // unconditionally too, rather than trusting the caller's allow-list
      // alone for the one distinction this project has already had to
      // correct once (`test_EARS_STORE_13_smart_mode_never_deletes_
      // message_kind_items`).
      if (group.kind == StorageItemKind.message &&
          plan.mode == StorageMode.smart.name) {
        skippedGroups.add(
          SkippedRetentionGroup(
            group: group,
            why: 'Smart Mode never deletes message-kind items '
                '(OQ-E08-3(a)/OQ-E08-T06-1), regardless of allowedKinds',
          ),
        );
        continue;
      }

      // Invariant 3: outside the per-call allow-list -> always skipped,
      // reason preserved on the group itself.
      if (!allowedKinds.contains(group.kind)) {
        skippedGroups.add(
          SkippedRetentionGroup(
            group: group,
            why: 'kind ${group.kind.name} is not authorised by this pass\'s '
                'allowedKinds (mode-dependent, OQ-E08-T06-1)',
          ),
        );
        continue;
      }

      if (group.kind == StorageItemKind.message) {
        // Invariant 2: the delivery-state guard, unconditional -- checked
        // even though this group already passed the allow-list above.
        final split = await _splitByDeliveryState(group);
        if (split.deletable != null) candidatesToApply.add(split.deletable!);
        if (split.undelivered != null) {
          skippedGroups.add(
            SkippedRetentionGroup(
              group: split.undelivered!,
              why: 'message not in a terminal delivered state '
                  '(Queued/Sent/Failed are in flight, EARS-STORE-14) -- '
                  'this guard is independent of allowedKinds',
            ),
          );
        }
        continue;
      }

      // No other kind has a real deletion path in this build (task §3:
      // only `message`/`relayPayload` have real producers today) -- err on
      // the side of never deleting an item this executor has no tested
      // delete path for, rather than assuming a table-name convention holds
      // (task §6 risk: a deletion bug here is unrecoverable data loss).
      skippedGroups.add(
        SkippedRetentionGroup(
          group: group,
          why: 'no delete implementation for kind ${group.kind.name} in '
              'this build',
        ),
      );
    }

    var loggedAnything = false;

    // Every group this method already decided not to touch -- safe to log
    // upfront in one batch, since nothing is ever deleted for these
    // (invariant 1/2/3, this file's header).
    if (skippedGroups.isNotEmpty) {
      await log.recordPass(
        _planFor(plan, [for (final s in skippedGroups) s.group]),
        outcome: DecisionOutcome.skipped,
        nowEpochMs: nowEpochMs,
      );
      loggedAnything = true;
    }

    // Every remaining candidate is processed ONE AT A TIME: its delete and
    // its own `outcome: applied` row commit together, atomically, in one
    // `db.transaction()` -- so the log can never claim a delete happened
    // when it didn't (F1). A failed delete rolls back that attempt (nothing
    // durable from it) and gets a truthful `outcome: skipped` row instead,
    // written outside the rolled-back transaction; processing continues to
    // the next candidate rather than aborting the whole pass.
    final appliedGroups = <RetentionCandidateGroup>[];
    var bytesReclaimed = 0;
    for (final group in candidatesToApply) {
      try {
        await db.transaction(() async {
          await _deleteGroup(group);
          await log.recordPass(
            _planFor(plan, [group]),
            outcome: DecisionOutcome.applied,
            nowEpochMs: nowEpochMs,
          );
        });
        appliedGroups.add(group);
        bytesReclaimed += group.bytes;
        loggedAnything = true;
      } catch (e) {
        skippedGroups.add(
          SkippedRetentionGroup(group: group, why: 'delete failed: $e'),
        );
        await log.recordPass(
          _planFor(plan, [group]),
          outcome: DecisionOutcome.skipped,
          nowEpochMs: nowEpochMs,
        );
        loggedAnything = true;
      }
    }

    // A genuinely empty plan (no candidates at all, not even a skipped
    // one) must still advance `storage_decisions.decided_at` -- the
    // restart-safe throttle's own requirement (`storage_decision_log.dart`'s
    // header) -- via a `skipped`-outcome sentinel row, never `applied`
    // (round-1 review's F2 finding: an `applied` sentinel on a pass that
    // deleted nothing is itself a false claim, and every Smart Mode pass on
    // this build never has anything in `candidatesToApply` at all).
    if (!loggedAnything) {
      await log.recordPass(
        plan,
        outcome: DecisionOutcome.skipped,
        nowEpochMs: nowEpochMs,
      );
    }

    return RetentionOutcome(
      appliedGroups: appliedGroups,
      skippedGroups: skippedGroups,
      bytesReclaimed: bytesReclaimed,
    );
  }

  RetentionPlan _planFor(
    RetentionPlan source,
    List<RetentionCandidateGroup> groups,
  ) {
    final totalBytes = groups.fold<int>(0, (sum, g) => sum + g.bytes);
    return RetentionPlan(
      mode: source.mode,
      groups: groups,
      totalBytes: totalBytes,
      availableFactors: source.availableFactors,
      unavailableFactors: source.unavailableFactors,
      computedAt: source.computedAt,
    );
  }

  Future<void> _deleteGroup(RetentionCandidateGroup group) async {
    switch (group.kind) {
      case StorageItemKind.message:
        await deleteMessageItems(group.itemIds);
        // E08-B03 fix: `deleteMessageItems` only ever owned `messages`
        // (correctly, per its own doc below) -- but neither
        // `delivery_states` nor `storage_item_stats` has a FK/cascade, and
        // nothing else in `lib/` ever deletes from either, so every prior
        // pass left two orphan rows per deleted message forever. This call
        // runs inside the SAME `apply()` per-group `db.transaction()` as the
        // `messages` delete above and the group's own `applied` decision row
        // (this file's header) -- so a `messages` delete that succeeds but
        // whose bookkeeping cleanup then fails rolls back together with it,
        // never leaving the kind of half-applied state this epic's T06
        // review rounds already fought to eliminate for the delete+decision
        // -row pair.
        await _deleteBookkeeping(group.itemIds);
      case StorageItemKind.relayPayload:
      case StorageItemKind.databaseFile:
      case StorageItemKind.voiceMessage:
      case StorageItemKind.pttRecording:
      case StorageItemKind.callRecording:
      case StorageItemKind.attachment:
        // Never reached in practice -- every other kind is either always
        // skipped (relayPayload) or has no delete path yet (the `default`
        // skip branch in [apply] above never adds these to appliedGroups).
        // Asserted here defensively rather than silently no-op-ing, so a
        // future change that starts adding these to appliedGroups without
        // also adding a real delete path fails loudly instead of quietly
        // recording `applied` for a group nothing actually deleted.
        throw StateError(
          'RetentionExecutor has no delete path for ${group.kind.name} -- '
          'this should be unreachable (apply() only ever adds message-kind '
          'groups to appliedGroups in this build)',
        );
    }
  }

  /// Deletes [ids] from `messages`. Exposed as its own (non-private) method,
  /// overridable in tests, specifically so
  /// `test_EARS_STORE_13_decisions_are_logged_before_deletes` can force a
  /// delete to fail from inside [apply]'s per-group `db.transaction()` and
  /// assert that group's `applied` row never becomes durable (F1 fix) while
  /// a truthful `skipped` row for it still does -- the log can never claim
  /// a delete happened when it didn't, and this needs to be provably real,
  /// not merely asserted (`skills/implement`'s falsification discipline;
  /// task §6 risk note: "falsification ... is the expected review style for
  /// this task specifically").
  ///
  /// **Chunked (F1, round-1 review -- upgraded from "carried-forward
  /// observation, not fixed here" to fixed in this same round)**:
  /// `t.id.isIn(ids)` has the identical SQLite bind-variable ceiling
  /// `_deleteBookkeeping`'s own F1 fix documents (>32766 ids throws
  /// `SqliteException(1): too many SQL variables`). Originally flagged as
  /// lower-urgency and left for the epic sweep -- a group this large would
  /// throw inside `apply()`'s per-group `db.transaction()`, roll back, and
  /// get a truthful `skipped` row (never a false `applied`), so no
  /// *correctness* gap. But it turned out to be a completeness gap this
  /// same round: this method runs BEFORE [_deleteBookkeeping] in
  /// [_deleteGroup], so an unchunked `deleteMessageItems` would throw first
  /// for a real large Manual Mode group -- meaning `_deleteBookkeeping`'s
  /// own chunking fix could never actually be exercised end-to-end for the
  /// "heavy user" scenario this whole bug exists to help (a >32766-message
  /// group could never be deleted at all, bookkeeping or not). Fixed with
  /// the same [_chunked]/[_deleteChunkSize] this file's other two F1 fixes
  /// already use.
  Future<void> deleteMessageItems(List<String> ids) async {
    if (ids.isEmpty) return;
    for (final chunk in _chunked(ids, _deleteChunkSize)) {
      await (db.delete(db.messages)..where((t) => t.id.isIn(chunk))).go();
    }
  }

  /// Deletes the `delivery_states` and `storage_item_stats` rows that key
  /// off a now-deleted message's id (E08-B03) -- the two tables this app's
  /// only deletion path (`deleteMessageItems` above) never touched. Called
  /// from [_deleteGroup], inside [apply]'s per-group `db.transaction()`, so
  /// this cleanup and the `messages` delete it belongs to commit or roll
  /// back together, never half-applied.
  ///
  /// `delivery_states`'s PK is `(message_id, state)` (`message_tables.dart`)
  /// -- deleted by `message_id` alone, all states for the id at once.
  /// `storage_item_stats`'s PK is `(item_kind, item_id)`
  /// (`storage_tables.dart`) -- scoped to `item_kind ==
  /// StorageItemKind.message.name` so this never touches a stats row for any
  /// other kind (`relayPayload`, etc.) that happens to share an id string.
  ///
  /// Does **not** add a foreign key or cascade (that is a schema migration
  /// and requires the 🧍 `db_schema_migration` gate, not cleared for this
  /// fix -- task file §"Fix direction"/"What this fix does NOT do") -- this
  /// is an explicit, application-level delete instead.
  ///
  /// **Round-1 review fix (F1)**: `t.messageId.isIn(ids)`/`t.itemId.isIn(ids)`
  /// each bind one SQL variable per id. A single `RetentionCandidateGroup`
  /// can hold as many ids as a Manual Mode `olderThanDays`/`overSizeMb` plan
  /// selected (unbounded, same root cause `_accessStats`'s own F1 fix
  /// documents), so past SQLite's `SQLITE_MAX_VARIABLE_NUMBER` (32766 in
  /// this build) an unchunked delete throws `SqliteException(1): too many
  /// SQL variables` -- which, inside `apply()`'s per-group
  /// `db.transaction()`, would roll back the whole group (including the
  /// `messages` delete that already succeeded) and get logged `skipped`
  /// with a misleading "delete failed" reason instead of actually reclaiming
  /// the space. Chunked into [_deleteChunkSize]-sized batches so neither
  /// delete ever binds more variables than that.
  Future<void> _deleteBookkeeping(List<String> ids) async {
    if (ids.isEmpty) return;
    for (final chunk in _chunked(ids, _deleteChunkSize)) {
      await (db.delete(db.deliveryStates)
            ..where((t) => t.messageId.isIn(chunk)))
          .go();
      await (db.delete(db.storageItemStats)
            ..where(
              (t) =>
                  t.itemKind.equals(StorageItemKind.message.name) &
                  t.itemId.isIn(chunk),
            ))
          .go();
    }
  }

  /// Batch size for every chunked `isIn(...)` query in this file (F1, round-1
  /// review) -- comfortably under SQLite's `SQLITE_MAX_VARIABLE_NUMBER`
  /// (32766 in this build) and matching `StorageManager._itemsPageSize`, the
  /// same constant this executor's caller already pages items with.
  static const int _deleteChunkSize = 500;

  /// Splits [ids] into consecutive batches of at most [size] -- used
  /// wherever this file builds an `isIn(...)` query over a caller-supplied,
  /// potentially unbounded id list (F1, round-1 review).
  static Iterable<List<String>> _chunked(List<String> ids, int size) sync* {
    for (var offset = 0; offset < ids.length; offset += size) {
      yield ids.sublist(
        offset,
        offset + size > ids.length ? ids.length : offset + size,
      );
    }
  }

  /// Splits a `message` candidate group into the slice that is actually
  /// deletable (delivery state outside [_undeliveredStates]) and the slice
  /// that is not -- looked up from `messages` directly rather than trusted
  /// from the plan (a plan can be arbitrarily stale by the time it is
  /// applied; the delivery-state guard reads the row's *current* state).
  /// An id no longer present in `messages` (already removed by an earlier
  /// pass) is treated as non-deletable -- never delete on missing/uncertain
  /// information (task §6 risk: a deletion bug here is unrecoverable).
  Future<_DeliverySplit> _splitByDeliveryState(
    RetentionCandidateGroup group,
  ) async {
    if (group.itemIds.isEmpty) {
      return const _DeliverySplit(deletable: null, undelivered: null);
    }

    final deletableIds = <String>[];
    final deletableBytesById = <String, int>{};
    final undeliveredIds = <String>[];
    final undeliveredBytesById = <String, int>{};
    final found = <String>{};

    // Round-1 review F1 (carried into this pre-existing raw-SQL query,
    // found while proving `_deleteBookkeeping`'s own F1 fix end-to-end):
    // one `?` placeholder per id means one bound SQL variable per id, same
    // ceiling as every other `isIn(...)` in this file
    // (`SQLITE_MAX_VARIABLE_NUMBER`, 32766 in this build). This is called
    // for EVERY message-kind group `apply()` processes, before either
    // `deleteMessageItems` or `_deleteBookkeeping` ever run -- so an
    // unchunked query here would throw before this file's other two F1
    // fixes ever got a chance to matter, for a real Manual Mode
    // `olderThanDays`/`overSizeMb` group past the ceiling. Chunked into
    // [_deleteChunkSize] batches, merged into the same accumulators below.
    for (final chunk in _chunked(group.itemIds, _deleteChunkSize)) {
      // Raw SQL, matching `StorageInventory`'s own `LENGTH(ciphertext)`
      // pattern (E08-T02) -- a real measured byte length, never estimated.
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db
          .customSelect(
            'SELECT id, delivery_state, LENGTH(ciphertext) AS bytes '
            'FROM messages WHERE id IN ($placeholders)',
            variables: [for (final id in chunk) Variable.withString(id)],
            readsFrom: {db.messages},
          )
          .get();

      for (final row in rows) {
        final id = row.read<String>('id');
        found.add(id);
        final bytes = row.read<int>('bytes');
        final stateName = row.read<String>('delivery_state');
        final state = DeliveryState.values.byName(stateName);
        if (!_undeliveredStates.contains(state)) {
          deletableIds.add(id);
          deletableBytesById[id] = bytes;
        } else {
          undeliveredIds.add(id);
          undeliveredBytesById[id] = bytes;
        }
      }
    }
    // Any id no longer present in `messages` is not deletable (nothing to
    // delete, and never assumed safe) -- recorded on the undelivered side so
    // it is still visible in the explanation, never silently dropped.
    for (final id in group.itemIds) {
      if (!found.contains(id)) {
        undeliveredIds.add(id);
        undeliveredBytesById[id] = 0;
      }
    }

    return _DeliverySplit(
      deletable: deletableIds.isEmpty
          ? null
          : _rebuild(group, deletableIds, deletableBytesById),
      undelivered: undeliveredIds.isEmpty
          ? null
          : _rebuild(group, undeliveredIds, undeliveredBytesById),
    );
  }

  RetentionCandidateGroup _rebuild(
    RetentionCandidateGroup original,
    List<String> ids,
    Map<String, int> bytesById,
  ) {
    final sortedIds = [...ids]..sort();
    final bytes = sortedIds.fold<int>(0, (sum, id) => sum + (bytesById[id] ?? 0));
    return RetentionCandidateGroup(
      categoryKey: original.categoryKey,
      kind: original.kind,
      itemIds: sortedIds,
      itemCount: sortedIds.length,
      bytes: bytes,
      reason: original.reason,
      reasonDetail: original.reasonDetail,
    );
  }
}

class _DeliverySplit {
  const _DeliverySplit({required this.deletable, required this.undelivered});

  final RetentionCandidateGroup? deletable;
  final RetentionCandidateGroup? undelivered;
}
