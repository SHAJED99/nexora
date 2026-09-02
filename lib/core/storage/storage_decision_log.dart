// core/storage — the only writer of `storage_decisions` (E08-T06,
// `storage_tables.dart`'s own doc: "FR-STORE-007's ... explanation log").
//
// `StorageDecisionLog.recordPass` is the single call site the rest of this
// epic uses to explain a policy pass -- `StorageManager` for a plan-only
// pass (`outcome: planned`) and `RetentionExecutor` for what it actually did
// (`outcome: applied`/`outcome: skipped`). No other file writes this table
// (task §3).
//
// **Every pass writes at least one row, even with zero candidates.**
// `storage_decisions.decided_at` is also this epic's process-restart-safe
// throttle clock (task §6 risk note: "persist the last pass time ... rather
// than an in-memory field alone") -- a pass that found nothing to report
// must still advance `decided_at`, or a healthy device with nothing to
// remove would re-run a full inventory scan on every single tick forever.
// A zero-candidate pass writes one sentinel row (`categoryKey: 'none'`,
// `itemCount: 0`, `bytes: 0`) rather than silently writing nothing --
// [latestPass]'s own doc comment names how to recognise it.
library;

import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';

import 'retention_plan.dart';

/// The only reader/writer of `storage_decisions` (task §3).
class StorageDecisionLog {
  StorageDecisionLog({required this.db});

  /// The app's `AppDatabase` (injected, never constructed here -- matches
  /// every other `core/storage` file's own precedent).
  final AppDatabase db;

  /// Timestamp + an in-process counter for row ids, same technique
  /// `RelayEngine._generateId` already uses in this codebase (no `uuid`
  /// package is declared in `pubspec.yaml`, and adding one is a 🧍
  /// `new_dependency` gate this task does not need to clear).
  int _idCounter = 0;

  /// Appends one row per candidate group in [plan] (or one sentinel row if
  /// [plan] has no groups -- see this file's header) to `storage_decisions`,
  /// all sharing [nowEpochMs] as `decided_at` and [outcome] as their
  /// `outcome` -- so `FR-STORE-007`'s explanation surface can show every
  /// candidate group's own reason (`RetentionCandidateGroup.reason`/
  /// `reasonDetail`), never collapsed into one summary line.
  ///
  /// Returns the pass id -- `storage_decisions` has no dedicated
  /// "pass id" column (`storage_tables.dart`'s schema), so every row this
  /// call writes shares [nowEpochMs] as `decided_at`, and that shared value
  /// (stringified) is what identifies "this pass" to a caller or to
  /// [latestPass].
  Future<String> recordPass(
    RetentionPlan plan, {
    required DecisionOutcome outcome,
    required int nowEpochMs,
  }) async {
    final rows = plan.groups.isEmpty
        ? [_sentinelCompanion(plan: plan, outcome: outcome, nowEpochMs: nowEpochMs)]
        : [
            for (final group in plan.groups)
              _companionFor(
                group: group,
                plan: plan,
                outcome: outcome,
                nowEpochMs: nowEpochMs,
              ),
          ];

    await db.batch((batch) {
      batch.insertAll(db.storageDecisions, rows);
    });

    return nowEpochMs.toString();
  }

  /// The most recent pass's rows -- every row sharing the maximum
  /// `decided_at` value in the table, most recent first (by insertion
  /// order within that pass; drift preserves row id/rowid order). Empty
  /// when no pass has ever run.
  ///
  /// A row with `categoryKey == 'none'` is this file's own zero-candidate
  /// sentinel (see header) -- a caller building a user-facing summary
  /// should treat it as "nothing found this pass", not as a real category.
  Future<List<StorageDecisionRow>> latestPass() async {
    final maxRow = await db
        .customSelect(
          'SELECT MAX(decided_at) AS max_decided_at FROM storage_decisions',
          readsFrom: {db.storageDecisions},
        )
        .getSingleOrNull();
    final maxDecidedAt = maxRow?.read<int?>('max_decided_at');
    if (maxDecidedAt == null) return const [];

    return (db.select(db.storageDecisions)
          ..where((t) => t.decidedAt.equals(maxDecidedAt))
          ..orderBy([(t) => OrderingTerm.asc(t.categoryKey)]))
        .get();
  }

  StorageDecisionsCompanion _companionFor({
    required RetentionCandidateGroup group,
    required RetentionPlan plan,
    required DecisionOutcome outcome,
    required int nowEpochMs,
  }) {
    return StorageDecisionsCompanion.insert(
      id: _nextId(nowEpochMs),
      decidedAt: nowEpochMs,
      mode: plan.mode,
      categoryKey: group.categoryKey,
      itemCount: group.itemCount,
      bytes: group.bytes,
      reasonCode: group.reason.name,
      reasonDetail: Value(group.reasonDetail),
      outcome: outcome.name,
    );
  }

  StorageDecisionsCompanion _sentinelCompanion({
    required RetentionPlan plan,
    required DecisionOutcome outcome,
    required int nowEpochMs,
  }) {
    return StorageDecisionsCompanion.insert(
      id: _nextId(nowEpochMs),
      decidedAt: nowEpochMs,
      mode: plan.mode,
      categoryKey: 'none',
      itemCount: 0,
      bytes: 0,
      reasonCode: 'none',
      reasonDetail: const Value(null),
      outcome: outcome.name,
    );
  }

  String _nextId(int nowEpochMs) => '$nowEpochMs-${_idCounter++}';
}
