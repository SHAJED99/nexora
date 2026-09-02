// core/storage — the composed facade the app registers (E08-T06).
//
// `StorageManager` is what `AppBinding` registers and what
// `MessagingCoordinator`'s tick calls -- the piece this project has now
// shipped an unwired controller without twice (`OQ-E06-T06-4`, `E07-B03`;
// this epic's own task file names both explicitly as the pattern this task
// exists to close for good). It reads the active policy
// (`StorageSettingsRepository`, E08-T05), picks Smart Mode or a manual
// policy, computes a plan, logs it, optionally executes it (throttled), and
// exposes the latest plan for the UI to observe (`E08-T08`/`E08-T09`, not
// built here).
//
// **The mode-dependent allow-list lives here, not in `RetentionExecutor`**
// (`OQ-E08-T06-1`'s amendment -- see `retention_executor.dart`'s header for
// the full reasoning). This file is the one place that decides, per pass,
// which `StorageItemKind`s the executor may delete: empty for a Smart Mode
// plan (`OQ-E08-3(a)`: "Smart Mode's allow-list excludes conversation
// content entirely"), `{message}` for a Manual Mode plan (`olderThanDays`/
// `overSizeMb` -- "message deletion happens only under a manual policy the
// user explicitly turns on").
//
// **Plan and apply stay conceptually separate (task §2)**: `runPass(apply:
// false)` computes and logs a plan (`outcome: planned`) without ever
// touching `RetentionExecutor` -- the shape a dashboard's informational
// warning (`EARS-STORE-2`) would read. `runPass(apply: true)` (the default,
// and the one `MessagingCoordinator`'s tick calls) hands the plan straight
// to the executor, which does its own `applied`/`skipped` logging -- this
// file does not double-log a `planned` row in that path, since `RetentionExecutor.apply`
// already produces the pass's authoritative decision rows.
//
// **Throttled, and the throttle survives a process restart** (task §2/§6
// risk note): `runPass` reads `StorageDecisionLog.latestPass()`'s own
// `decided_at` rather than an in-memory timestamp, so a cold start does not
// re-run a full inventory scan just because no in-memory state survived.
library;

import 'package:drift/drift.dart';
import 'package:get/get.dart';

import 'manual_policy.dart';
import 'retention_executor.dart';
import 'retention_plan.dart';
import 'smart_mode_policy.dart';
import 'storage_decision_log.dart';
import 'storage_inventory.dart';
import 'storage_item.dart' show StorageItem, StorageItemKind;
import 'storage_settings_repository.dart';

/// The composed facade `AppBinding` registers (task §3). Every dependency is
/// injected -- this file constructs none of `AppDatabase`,
/// `StorageInventory`, `RetentionExecutor` etc. itself (task §5's own
/// constructor contract), so tests build it from plain fakes/an in-memory
/// `AppDatabase` exactly as every other `core/storage` file already does.
class StorageManager {
  StorageManager({
    required this.settings,
    required this.inventory,
    required this.smart,
    required this.executor,
    required this.log,
    this.storagePassInterval = const Duration(hours: 6),
  });

  final StorageSettingsRepository settings;
  final StorageInventory inventory;
  final SmartModePolicy smart;
  final RetentionExecutor executor;
  final StorageDecisionLog log;

  /// A full pass is skipped (recording nothing, task §2) if the most recent
  /// pass's `decided_at` is closer than this to `nowEpochMs`.
  final Duration storagePassInterval;

  /// Stateless -- `ManualPolicy.plan` takes every input as a parameter
  /// (`manual_policy.dart`'s own header), so one `const` instance is all any
  /// caller ever needs.
  static const ManualPolicy _manual = ManualPolicy();

  /// The most recent plan, for the UI to observe (task §5) -- null before
  /// the first pass this process has run. Updated by every [runPass] call
  /// that was not itself skipped by the throttle.
  final Rx<RetentionPlan?> latestPlan = Rx<RetentionPlan?>(null);

  /// The one entry point `MessagingCoordinator`'s tick calls (task §5).
  ///
  /// Returns the computed plan, or `null` when [storagePassInterval] has not
  /// elapsed since the last recorded pass (throttled, task §2) -- checked
  /// against `StorageDecisionLog.latestPass()`'s own `decided_at`, which
  /// survives a process restart (task §6 risk note), never an in-memory
  /// field alone.
  ///
  /// [apply] `false` computes and logs a plan (`outcome: planned`) without
  /// executing it -- e.g. for a caller that only wants the forecast. The
  /// default, `true`, hands the plan straight to [executor], which performs
  /// its own `applied`/`skipped` logging (this file's header).
  Future<RetentionPlan?> runPass({
    required int nowEpochMs,
    bool apply = true,
  }) async {
    final lastPass = await log.latestPass();
    if (lastPass.isNotEmpty) {
      var lastDecidedAt = lastPass.first.decidedAt;
      for (final row in lastPass) {
        if (row.decidedAt > lastDecidedAt) lastDecidedAt = row.decidedAt;
      }
      if (nowEpochMs - lastDecidedAt < storagePassInterval.inMilliseconds) {
        return null;
      }
    }

    final policySettings = await settings.read();
    final mode = StorageMode.values.byName(policySettings.mode);
    final snapshot = await inventory.snapshot();

    final RetentionPlan plan;
    final Set<StorageItemKind> allowedKinds;

    if (mode == StorageMode.smart) {
      // Smart Mode's allow-list is always empty (`OQ-E08-3(a)`,
      // `OQ-E08-T06-1`) -- conversation content (`message`) is never a
      // Smart Mode deletion candidate, regardless of what factors would
      // otherwise select it.
      allowedKinds = const <StorageItemKind>{};
      // E08-B02 fix: `SmartModePolicy.plan`'s own contract
      // (`smart_mode_policy.dart:79-84`) requires "a representative set
      // (e.g. every `message` item, not an age-filtered subset)" for its
      // age/access/conversation-activity factors to mean what their names
      // say. `itemsOfKind`'s bounded, newest-first default silently handed
      // it only the newest 500 -- exactly backwards for an `olderThan`
      // factor. Page fully through each kind instead (still bounded per
      // call, `_allItemsOfKind`'s own page size).
      final items = <StorageItem>[
        for (final kind in const [
          StorageItemKind.message,
          StorageItemKind.relayPayload,
        ])
          ...await _allItemsOfKind(kind),
      ];
      plan = smart.plan(
        snapshot: snapshot,
        items: items,
        stats: await _accessStats(items),
        nowEpochMs: nowEpochMs,
        budgetBytes: policySettings.budgetBytes,
      );
    } else {
      // The user explicitly turned on a manual rule (`olderThanDays`/
      // `overSizeMb`) -- that explicit choice is what `OQ-E08-3(a)`
      // authorises to include `message` (`OQ-E08-T06-1`).
      allowedKinds = const <StorageItemKind>{StorageItemKind.message};
      plan = await _manual.plan(
        mode: mode,
        snapshot: snapshot,
        items: inventory.itemsOfKind,
        settings: policySettings,
        nowEpochMs: nowEpochMs,
      );
    }

    latestPlan.value = plan;

    if (!apply) {
      await log.recordPass(
        plan,
        outcome: DecisionOutcome.planned,
        nowEpochMs: nowEpochMs,
      );
      return plan;
    }

    await executor.apply(
      plan,
      allowedKinds: allowedKinds,
      nowEpochMs: nowEpochMs,
    );
    return plan;
  }

  /// Pages fully through one kind, oldest-first, `_itemsPageSize` at a
  /// time (E08-B02) -- `StorageInventory.itemsOfKind`'s own single-call
  /// bound (`limit`) still holds for every individual call this makes; what
  /// changes is that this method keeps calling until the kind is genuinely
  /// exhausted instead of stopping after the first (newest) page. Smart
  /// Mode's own contract requires a representative set for its per-item
  /// factors to be meaningful (`smart_mode_policy.dart:79-84`), so no bound
  /// is left standing here -- see this file's header for why that is an
  /// honest choice rather than a silent truncation.
  static const int _itemsPageSize = 500;

  Future<List<StorageItem>> _allItemsOfKind(StorageItemKind kind) async {
    final all = <StorageItem>[];
    var offset = 0;
    while (true) {
      final page = await inventory.itemsOfKind(
        kind,
        oldestFirst: true,
        limit: _itemsPageSize,
        offset: offset,
      );
      if (page.isEmpty) break;
      all.addAll(page);
      offset += page.length;
      if (page.length < _itemsPageSize) break;
    }
    return all;
  }

  /// `storage_item_stats` (E08-T03), mapped into `SmartModePolicy.plan`'s
  /// own `Map<String, ItemAccessStat>` shape, keyed identically to this
  /// method's own construction below (`'<kind.name>:<itemId>'`) -- this file
  /// reads through [inventory]'s own `db` field rather than taking a second
  /// `AppDatabase` parameter (task §5's constructor names no such
  /// dependency), matching `StorageInventory`/`StorageSettingsRepository`'s
  /// own "one AppDatabase, injected once" precedent.
  ///
  /// **E08-B03 fix**: previously ran an unbounded `SELECT *` over the whole
  /// `storage_item_stats` table -- a table that only ever grows (one row per
  /// message ever displayed, per `E08-T03`'s recorder, plus one per
  /// conversation opened), materialized into a Dart `Map` every pass, every 6
  /// hours, directly contradicting `storage_inventory.dart`'s own stated
  /// discipline ("a history large enough to be worth managing is a history
  /// too large to materialize"). Bounded here instead: [items] is the exact,
  /// already-paged set `runPass` just built via [_allItemsOfKind] (the
  /// `E08-B01`/`E08-B02` fix) for `SmartModePolicy.plan` to score -- reading
  /// only the stats rows for those same item ids (grouped by kind, since
  /// `storage_item_stats`'s own PK is `(item_kind, item_id)`) means this
  /// query is bounded by exactly the same page-through set the paging fix
  /// already established as "representative", never a full-table scan
  /// sitting downstream of it.
  ///
  /// **Round-1 review fix (F1)**: [_allItemsOfKind] deliberately pages
  /// through a WHOLE kind with no upper bound (the `E08-B01`/`E08-B02` fix
  /// this file's header already documents) -- so on a device with enough
  /// stored history, [items] can legitimately exceed SQLite's own
  /// `SQLITE_MAX_VARIABLE_NUMBER` (32766 in this build). `t.itemId.isIn(ids)`
  /// binds one variable per id, so a single query over that whole set throws
  /// `SqliteException(1): too many SQL variables` -- and since that throw
  /// happens BEFORE `log.recordPass` ever runs, `storage_decisions` never
  /// advances, the throttle never moves, and (`MessagingCoordinator` only
  /// counting the failure rather than crashing) every subsequent pass
  /// repeats the same failure silently, forever, for exactly the "heavy
  /// user" this bug exists to help. Chunked here into
  /// [_itemsPageSize]-sized batches (the same constant [_allItemsOfKind]
  /// already uses, so the query never binds more variables than one page's
  /// worth) -- each chunk's rows are merged into the same [result] map.
  Future<Map<String, ItemAccessStat>> _accessStats(
    List<StorageItem> items,
  ) async {
    if (items.isEmpty) return const <String, ItemAccessStat>{};

    final idsByKind = <String, List<String>>{};
    for (final item in items) {
      idsByKind.putIfAbsent(item.kind.name, () => <String>[]).add(item.id);
    }

    final result = <String, ItemAccessStat>{};
    for (final entry in idsByKind.entries) {
      final ids = entry.value;
      for (var offset = 0; offset < ids.length; offset += _itemsPageSize) {
        final chunk = ids.sublist(
          offset,
          offset + _itemsPageSize > ids.length
              ? ids.length
              : offset + _itemsPageSize,
        );
        if (chunk.isEmpty) continue;
        final rows = await (inventory.db.select(inventory.db.storageItemStats)
              ..where(
                (t) => t.itemKind.equals(entry.key) & t.itemId.isIn(chunk),
              ))
            .get();
        for (final row in rows) {
          result['${row.itemKind}:${row.itemId}'] = ItemAccessStat(
            accessCount: row.accessCount,
            lastAccessedAtEpochMs: row.lastAccessedAt,
          );
        }
      }
    }
    return result;
  }
}
