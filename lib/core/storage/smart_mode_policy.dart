// core/storage — Smart Mode's eight-factor scorer (E08-T04).
//
// `SmartModePolicy.plan()` turns a `StorageInventorySnapshot` (E08-T02), the
// items it summarizes, and access stats (E08-T03) into a `RetentionPlan` —
// what Smart Mode would remove, and why. It is a PURE function: no I/O, no
// `AppDatabase` access (task §5 Data: "Reads only, and only through the
// values passed in. No table access at all from this file"), no clock reads
// except the injected [nowEpochMs] (task §6 risk note). It deletes nothing
// and writes nothing (task §4) — execution is `E08-T06`'s.
//
// **A factor without an input is `Unavailable`, never a default** (task §2,
// `EARS-STORE-10`, E04-B03's standing prohibition). `storagePressure` is
// `Unavailable` whenever [SmartModePolicy.plan] is called with
// `budgetBytes: null` (`OQ-E08-1` unanswered for this call). `importance`
// is `Unavailable` on every call this build makes — `OQ-E08-4`'s "importance"
// factor has no input this task is scoped to build (see the file-level
// Deviations note in `E08-T04.md` for the full reasoning: the epic-level
// question has since been answered with an advisory derivation, but that
// derivation is new logic this task's own `files:` fence does not cover,
// and the task's own §2/§3/§4 text — the binding contract, rule 6 — commits
// to `unavailable` explicitly and unconditionally).
library;

import 'retention_plan.dart';
import 'storage_inventory.dart' show StorageInventorySnapshot;
import 'storage_item.dart' show StorageItem, StorageItemKind;

/// One `storage_item_stats` row's shape (E08-T03), as read by the scorer.
/// Mirrors `StorageItemStatRow`'s two data columns exactly — this file never
/// reads `AppDatabase` itself, so it cannot use the Drift-generated row type
/// directly; this is the plain-Dart mirror the caller maps into.
final class ItemAccessStat {
  const ItemAccessStat({required this.accessCount, this.lastAccessedAtEpochMs});

  /// Epoch-ms of the last recorded access, or null if the row itself is
  /// present but (defensively) has never actually recorded one — in
  /// practice `StorageAccessRecorder` never inserts a row without also
  /// setting this, but the type stays honest about what the schema allows.
  final int? lastAccessedAtEpochMs;

  final int accessCount;
}

/// Canonical `storage_item_stats` lookup key: `'<kind.name>:<itemId>'` —
/// matching `StorageAccessRecorder`'s own `_PendingKey` shape exactly
/// (`kind.name`, then `:`, then the raw item id). A single tested helper
/// avoids a `kind:id` vs `id:kind` vs bare-`id` mismatch silently making
/// every item look unaccessed (task §6 risk note).
String statsKeyFor(StorageItemKind kind, String itemId) =>
    '${kind.name}:$itemId';

/// The eight-factor scorer (task §1/§5). Stateless — every input arrives as
/// a parameter to [plan]; the constructor only carries the tunable
/// thresholds (`OQ-E08-2`'s placeholder set), so answering that question is
/// a value change against [SmartModeThresholds], never a rewrite of this
/// file.
final class SmartModePolicy {
  const SmartModePolicy({required this.thresholds});

  final SmartModeThresholds thresholds;

  static const String _modeSmart = 'smart';

  /// Compute what Smart Mode would remove, and why — without removing
  /// anything (task §1/§4).
  ///
  /// [snapshot] is `StorageInventory.snapshot()`'s per-class totals
  /// (`E08-T02`) — the source for the [SmartModeFactor.fileType] and
  /// [SmartModeFactor.storagePressure] factors, and for [RetentionPlan]'s
  /// per-kind bookkeeping.
  ///
  /// [items] is the per-item detail (`StorageItem`, `E08-T02`) the six
  /// scored factors need to select real candidates — age, size, access
  /// frequency, conversation activity and temporary status are all
  /// per-item properties that [StorageInventorySnapshot]'s class-level
  /// totals alone cannot supply. The caller obtains these via
  /// `StorageInventory.itemsOfKind()` *before* calling [plan] (this file
  /// never calls it itself — task §5 Data: no table access at all here).
  /// **Conversation activity is derived only from the `message`-kind items
  /// actually present in [items]** — a conversation whose most recent
  /// message is outside the supplied set reads as inactive for this run;
  /// the caller is responsible for supplying a representative set (e.g.
  /// every `message` item, not an age-filtered subset) for this factor to
  /// mean what its name says.
  ///
  /// [stats] is `storage_item_stats` (`E08-T03`), keyed by [statsKeyFor] —
  /// a missing key means the item has never been observed accessed, never
  /// a synthesized zero.
  ///
  /// [nowEpochMs] is the injected clock — this method never reads
  /// `DateTime.now()` (task §5/§6).
  ///
  /// [budgetBytes] is `OQ-E08-1`'s denominator, or null. Null makes
  /// [SmartModeFactor.storagePressure] `Unavailable` (`EARS-STORE-10`).
  RetentionPlan plan({
    required StorageInventorySnapshot snapshot,
    required List<StorageItem> items,
    required Map<String, ItemAccessStat> stats,
    required int nowEpochMs,
    int? budgetBytes,
  }) {
    final dayMs = const Duration(days: 1).inMilliseconds;

    // Conversation activity: the most recent `createdAt` this run has seen
    // for each conversation, derived only from the `message`-kind items in
    // [items] (task §2 factor 5's own "derived, real" definition).
    final conversationLastActivity = <String, int>{};
    for (final item in items) {
      if (item.kind != StorageItemKind.message) continue;
      final conversationId = item.conversationId;
      if (conversationId == null) continue;
      final current = conversationLastActivity[conversationId];
      if (current == null || item.createdAt > current) {
        conversationLastActivity[conversationId] = item.createdAt;
      }
    }
    final activeConversationCutoffMs =
        nowEpochMs - (thresholds.activeConversationWindowDays * dayMs);
    bool isConversationActive(String? conversationId) {
      if (conversationId == null) return false;
      final lastActivity = conversationLastActivity[conversationId];
      return lastActivity != null && lastActivity >= activeConversationCutoffMs;
    }

    // Storage pressure: Unavailable without a denominator (`OQ-E08-1`,
    // `EARS-STORE-10`) — never a default (task §2).
    final FactorScore pressureFactor;
    final double? pressureRatio;
    if (budgetBytes == null) {
      pressureFactor = const FactorScore.unavailable(
        'OQ-E08-1 — no storage budget (denominator) supplied to this plan run',
      );
      pressureRatio = null;
    } else {
      final ratio = budgetBytes == 0
          ? 1.0
          : snapshot.classTotalsSumBytes() / budgetBytes;
      pressureFactor = FactorScore.scored(ratio);
      pressureRatio = ratio;
    }
    final pressureIsHigh =
        pressureRatio != null && pressureRatio >= thresholds.storagePressureRatio;

    // Importance: Unavailable on every call this build makes — `OQ-E08-4`
    // is an undefined term this task's own contract (§2/§3/§4) commits to
    // never inventing a definition for (see file header note).
    const importanceFactor = FactorScore.unavailable(
      'OQ-E08-4 — "importance" is not a defined term in this build',
    );

    // Per-item candidate selection (message + relayPayload — the only two
    // kinds with real producers today, task §2).
    var agingCandidateCount = 0;
    var rarelyAccessedCandidateCount = 0;
    var overSizeCandidateCount = 0;
    var temporaryCandidateCount = 0;
    var conversationShieldedCount = 0;

    final byGroupKey = <String, _GroupBuilder>{};

    void addToGroup({
      required StorageItemKind kind,
      required String categoryKey,
      required RetentionReason reason,
      required String? reasonDetail,
      required StorageItem item,
    }) {
      final groupKey = '$categoryKey|${reason.name}';
      final builder = byGroupKey.putIfAbsent(
        groupKey,
        () => _GroupBuilder(
          categoryKey: categoryKey,
          kind: kind,
          reason: reason,
          reasonDetail: reasonDetail,
        ),
      );
      builder.add(item);
    }

    for (final item in items) {
      if (item.kind == StorageItemKind.relayPayload) {
        // Temporary by construction (`StorageItem.isTemporary`, E08-T02's
        // own derived definition) — always a candidate, unconditional on
        // age or access (BRD §20/§22: "Temporary cache ... No longer
        // required").
        temporaryCandidateCount++;
        addToGroup(
          kind: item.kind,
          categoryKey: _categoryKeyFor(item.kind),
          reason: RetentionReason.noLongerRequired,
          reasonDetail: null,
          item: item,
        );
        continue;
      }

      if (item.kind != StorageItemKind.message) {
        // No producer in this build for the remaining kinds (E08-T02 task
        // §3/§6, `databaseFile` is a container property, not an item) —
        // nothing to score per-item; the class still counts toward
        // `fileType`'s diversity measure via `snapshot.classTotals`.
        continue;
      }

      if (isConversationActive(item.conversationId)) {
        conversationShieldedCount++;
        continue;
      }
      final ageDays = (nowEpochMs - item.createdAt) / dayMs;
      final stat = stats[statsKeyFor(item.kind, item.id)];
      final lastAccessedAt = stat?.lastAccessedAtEpochMs;
      final rarelyAccessed = lastAccessedAt == null
          ? ageDays >= thresholds.rarelyAccessedMinAgeDays
          : (nowEpochMs - lastAccessedAt) / dayMs >=
              thresholds.rarelyAccessedDays;

      RetentionReason? baseReason;
      String? baseDetail;
      if (ageDays >= thresholds.ageThresholdDays) {
        baseReason = RetentionReason.olderThan;
        baseDetail = thresholds.ageThresholdDays.toString();
        agingCandidateCount++;
      } else if (rarelyAccessed) {
        baseReason = RetentionReason.rarelyAccessed;
        baseDetail = thresholds.rarelyAccessedDays.toString();
        rarelyAccessedCandidateCount++;
      } else if (item.bytes > thresholds.sizeThresholdBytes) {
        baseReason = RetentionReason.overSizeLimit;
        baseDetail = thresholds.sizeThresholdBytes.toString();
        overSizeCandidateCount++;
      }

      if (baseReason == null) continue;

      // Storage pressure, when high, dominates the explanation over a
      // plain age/access/size reason — BRD §22's own worked example folds
      // pressure and low usage into one "why" together.
      final RetentionReason reason;
      final String? reasonDetail;
      if (pressureIsHigh) {
        reason = RetentionReason.storagePressure;
        reasonDetail = (pressureRatio * 100).round().toString();
      } else {
        reason = baseReason;
        reasonDetail = baseDetail;
      }

      addToGroup(
        kind: item.kind,
        categoryKey: _categoryKeyFor(item.kind),
        reason: reason,
        reasonDetail: reasonDetail,
        item: item,
      );
    }

    final groups = byGroupKey.values.map((b) => b.build()).toList()
      ..sort((a, b) {
        final byCategory = a.categoryKey.compareTo(b.categoryKey);
        if (byCategory != 0) return byCategory;
        return a.reason.name.compareTo(b.reason.name);
      });

    final totalBytes = groups.fold<int>(0, (sum, g) => sum + g.bytes);

    final distinctKindsWithItems =
        snapshot.classTotals.where((c) => c.itemCount > 0).length;

    final availableFactors = <SmartModeFactor, FactorScore>{
      SmartModeFactor.age: FactorScore.scored(agingCandidateCount.toDouble()),
      SmartModeFactor.size: FactorScore.scored(overSizeCandidateCount.toDouble()),
      SmartModeFactor.fileType:
          FactorScore.scored(distinctKindsWithItems.toDouble()),
      SmartModeFactor.accessFrequency:
          FactorScore.scored(rarelyAccessedCandidateCount.toDouble()),
      SmartModeFactor.conversationActivity:
          FactorScore.scored(conversationShieldedCount.toDouble()),
      SmartModeFactor.storagePressure: pressureFactor,
      SmartModeFactor.temporaryStatus:
          FactorScore.scored(temporaryCandidateCount.toDouble()),
      SmartModeFactor.importance: importanceFactor,
    };
    final unavailableFactors = <SmartModeFactor, FactorScore>{
      for (final entry in availableFactors.entries)
        if (entry.value is Unavailable) entry.key: entry.value,
    };

    return RetentionPlan(
      mode: _modeSmart,
      groups: groups,
      totalBytes: totalBytes,
      availableFactors: availableFactors,
      unavailableFactors: unavailableFactors,
      computedAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
    );
  }

  static String _categoryKeyFor(StorageItemKind kind) {
    switch (kind) {
      case StorageItemKind.message:
        return 'messages';
      case StorageItemKind.relayPayload:
        return 'relayCache';
      case StorageItemKind.voiceMessage:
        return 'voiceMessages';
      case StorageItemKind.pttRecording:
        return 'pttRecordings';
      case StorageItemKind.callRecording:
        return 'callRecordings';
      case StorageItemKind.attachment:
        return 'attachments';
      case StorageItemKind.databaseFile:
        return 'databaseFile';
    }
  }
}

/// Accumulates one candidate group's items before [RetentionCandidateGroup]
/// is built — kept private so item ids can be sorted once at the end
/// (task §2 determinism requirement) rather than re-sorted on every add.
class _GroupBuilder {
  _GroupBuilder({
    required this.categoryKey,
    required this.kind,
    required this.reason,
    required this.reasonDetail,
  });

  final String categoryKey;
  final StorageItemKind kind;
  final RetentionReason reason;
  final String? reasonDetail;
  final List<StorageItem> _items = [];

  void add(StorageItem item) => _items.add(item);

  RetentionCandidateGroup build() {
    final sortedIds = _items.map((i) => i.id).toList()..sort();
    final bytes = _items.fold<int>(0, (sum, i) => sum + i.bytes);
    return RetentionCandidateGroup(
      categoryKey: categoryKey,
      kind: kind,
      itemIds: sortedIds,
      itemCount: _items.length,
      bytes: bytes,
      reason: reason,
      reasonDetail: reasonDetail,
    );
  }
}

/// Sum of every measured class total in [StorageInventorySnapshot] — the
/// same figure `StorageInventory.totalBytes()` computes (E08-T02), recomputed
/// here from the snapshot alone since this file never holds a
/// `StorageInventory` instance (task §5 Data: no table access at all).
extension on StorageInventorySnapshot {
  int classTotalsSumBytes() {
    var total = 0;
    for (final classTotal in classTotals) {
      total += classTotal.bytes;
    }
    return total;
  }
}
