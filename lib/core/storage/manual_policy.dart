// core/storage — the two non-default manual modes of `FR-STORE-004`
// (E08-T05).
//
// `ManualPolicy.plan()` turns one of the two manual modes
// (`olderThanDays`/`overSizeMb`) into the same `RetentionPlan` type
// `SmartModePolicy` produces (`retention_plan.dart`, E08-T04) — one plan
// shape means one explanation surface (`FR-STORE-007`) rather than three
// that drift apart (task §2).
//
// A manual policy is literal, not clever (task §2): "older than X days"
// means exactly items whose `createdAt` is older than X days. It does not
// additionally weigh access frequency, importance or pressure the way Smart
// Mode does — a manual mode that quietly scored those factors would be
// Smart Mode with a different label (task §4). This file deletes nothing
// and writes nothing (task §4): a plan only, same fence as `E08-T04`.
library;

import 'package:nexora/core/persistence/database.dart'
    show StoragePolicySettingRow;

import 'retention_plan.dart';
import 'storage_inventory.dart' show StorageInventorySnapshot;
import 'storage_item.dart' show StorageItem, StorageItemKind;
import 'storage_settings_repository.dart' show StorageMode;

export 'storage_settings_repository.dart' show StorageMode;

/// The shape of `StorageInventory.itemsOfKind` this file calls through
/// (E08-B01/E08-B02's shared fix): the callback signature had to widen past
/// the original `(kind, {olderThanEpochMs})` pair to also carry [limit],
/// [oldestFirst] and [offset] paging, since `_planOverSize` (below) now
/// pages a genuinely oldest-first enumeration instead of trusting the
/// injected fetch's own bounded, newest-first default. `OQ-E08-T05-1` named
/// this contract gap explicitly: "amending either way".
typedef StorageItemsFetcher = Future<List<StorageItem>> Function(
  StorageItemKind kind, {
  int limit,
  int? olderThanEpochMs,
  bool oldestFirst,
  int offset,
});

/// The two non-default modes of `FR-STORE-004` (task §1). Stateless —
/// `plan()` takes every input as a parameter.
final class ManualPolicy {
  const ManualPolicy();

  /// Compute what one manual mode would remove, and why — without removing
  /// anything (task §4).
  ///
  /// [mode] must be [StorageMode.olderThanDays] or [StorageMode.overSizeMb]
  /// — passing [StorageMode.smart] is a [StateError] (task §5: "Smart Mode
  /// has its own policy").
  ///
  /// [snapshot] supplies the per-kind item counts this plan iterates over —
  /// a kind with zero items today (task §2/E08-T02) contributes no group.
  ///
  /// [items] is the per-item detail this file cannot fetch itself (unlike
  /// `SmartModePolicy`, this file's own contract makes it the caller of the
  /// injected fetch, since each mode needs a different query shape — see
  /// the age-cutoff pushdown below). In practice this is
  /// `StorageInventory.itemsOfKind` (E08-T02), passed straight through.
  ///
  /// [settings] supplies the mode's own parameter
  /// (`olderThanDays`/`maxBytes`) — read via `StorageSettingsRepository`
  /// (task §5), already validated at write time (task §6: this file is not
  /// the validation backstop, `StorageSettingsRepository.setMode` is).
  ///
  /// [nowEpochMs] is the injected clock — this method never reads
  /// `DateTime.now()` (task §5/§6, same discipline as `SmartModePolicy`).
  Future<RetentionPlan> plan({
    required StorageMode mode,
    required StorageInventorySnapshot snapshot,
    required StorageItemsFetcher items,
    required StoragePolicySettingRow settings,
    required int nowEpochMs,
  }) async {
    switch (mode) {
      case StorageMode.smart:
        throw StateError(
          'ManualPolicy.plan does not handle StorageMode.smart — '
          'Smart Mode has its own policy (SmartModePolicy.plan)',
        );
      case StorageMode.olderThanDays:
        return _planOlderThan(
          snapshot: snapshot,
          items: items,
          settings: settings,
          nowEpochMs: nowEpochMs,
        );
      case StorageMode.overSizeMb:
        return _planOverSize(
          snapshot: snapshot,
          items: items,
          settings: settings,
          nowEpochMs: nowEpochMs,
        );
    }
  }

  Future<RetentionPlan> _planOlderThan({
    required StorageInventorySnapshot snapshot,
    required StorageItemsFetcher items,
    required StoragePolicySettingRow settings,
    required int nowEpochMs,
  }) async {
    final days = settings.olderThanDays;
    if (days == null) {
      throw StateError(
        'StorageMode.olderThanDays requires settings.olderThanDays to be '
        'set — StorageSettingsRepository.setMode should have rejected a '
        'write that left it null',
      );
    }
    final cutoffEpochMs =
        nowEpochMs - (days * const Duration(days: 1).inMilliseconds);

    final groups = <RetentionCandidateGroup>[];
    for (final classTotal in snapshot.classTotals) {
      if (classTotal.itemCount == 0) continue;
      final kindItems = await items(
        classTotal.kind,
        olderThanEpochMs: cutoffEpochMs,
      );
      // Age only — never access frequency, importance or pressure (task
      // §2). Re-check the cutoff defensively rather than trusting the
      // injected fetch to have applied it: the literal contract of [items]
      // permits a caller-supplied implementation that ignores
      // `olderThanEpochMs` and returns everything of that kind.
      final selected = kindItems
          .where((item) => item.createdAt < cutoffEpochMs)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      if (selected.isEmpty) continue;

      groups.add(
        _group(
          kind: classTotal.kind,
          items: selected,
          reason: RetentionReason.olderThan,
          reasonDetail: days.toString(),
        ),
      );
    }

    return _plan(mode: StorageMode.olderThanDays, groups: groups, nowEpochMs: nowEpochMs);
  }

  /// The batch size used when paging each kind oldest-first
  /// (E08-B01) — matches `StorageInventory.itemsOfKind`'s own default
  /// `limit`, so a kind under the old cliff is fetched in a single page,
  /// same as before this fix.
  static const int _pageSize = 500;

  Future<RetentionPlan> _planOverSize({
    required StorageInventorySnapshot snapshot,
    required StorageItemsFetcher items,
    required StoragePolicySettingRow settings,
    required int nowEpochMs,
  }) async {
    final maxBytes = settings.maxBytes;
    if (maxBytes == null) {
      throw StateError(
        'StorageMode.overSizeMb requires settings.maxBytes to be set — '
        'StorageSettingsRepository.setMode should have rejected a write '
        'that left it null',
      );
    }

    // The cap applies to the TOTAL across every kind, not to each kind
    // independently (task §6 risk note: "which items go when the total
    // exceeds the cap"; design/screens/settings-storage.md's own wording:
    // "Delete old data when storage exceeds X MB"). Three kinds each at
    // 200 bytes with a 300-byte cap is 600 total, 2x over — even though no
    // single kind exceeds the cap alone.
    final totalBytes = snapshot.classTotals.fold<int>(
      0,
      (sum, classTotal) => sum + classTotal.bytes,
    );
    if (totalBytes <= maxBytes) {
      return _plan(
        mode: StorageMode.overSizeMb,
        groups: <RetentionCandidateGroup>[],
        nowEpochMs: nowEpochMs,
      );
    }

    // E08-B01 fix: select the genuinely-oldest items across the WHOLE pool,
    // not just the newest-500-per-kind window `itemsOfKind`'s own default
    // returns. Each kind is paged oldest-first (`oldestFirst: true`,
    // `_pageSize` per page — `StorageInventory`'s own "bounded by
    // construction" property, task §5, still holds: no single call ever
    // returns more than `_pageSize` items), and the pages are merged
    // oldest-first across kinds via a small streaming k-way merge so at
    // most one page per kind is ever held in memory at once.
    final kindsWithItems = [
      for (final classTotal in snapshot.classTotals)
        if (classTotal.itemCount > 0) classTotal.kind,
    ];

    final buffers = <StorageItemKind, List<StorageItem>>{
      for (final kind in kindsWithItems) kind: <StorageItem>[],
    };
    final nextOffset = <StorageItemKind, int>{
      for (final kind in kindsWithItems) kind: 0,
    };
    final exhausted = <StorageItemKind, bool>{
      for (final kind in kindsWithItems) kind: false,
    };

    Future<void> refill(StorageItemKind kind) async {
      if (exhausted[kind]!) return;
      final page = await items(
        kind,
        oldestFirst: true,
        limit: _pageSize,
        offset: nextOffset[kind]!,
      );
      nextOffset[kind] = nextOffset[kind]! + page.length;
      buffers[kind]!.addAll(page);
      if (page.length < _pageSize) exhausted[kind] = true;
    }

    for (final kind in kindsWithItems) {
      await refill(kind);
    }

    var runningBytes = totalBytes;
    final selectedByKind = <StorageItemKind, List<StorageItem>>{};

    while (runningBytes > maxBytes) {
      StorageItemKind? bestKind;
      StorageItem? bestItem;
      for (final kind in kindsWithItems) {
        final buffer = buffers[kind]!;
        if (buffer.isEmpty) continue;
        final head = buffer.first;
        if (bestItem == null ||
            head.createdAt < bestItem.createdAt ||
            (head.createdAt == bestItem.createdAt &&
                head.id.compareTo(bestItem.id) < 0)) {
          bestItem = head;
          bestKind = kind;
        }
      }
      // Every kind's buffer is empty and exhausted -- the whole inventory
      // has been consumed while still over the cap (under-planning, the
      // second half of `OQ-E08-T05-1`: this can genuinely happen if the
      // snapshot's totals and the live per-item rows have drifted, e.g. a
      // concurrent write between `snapshot()` and this call). Stop rather
      // than loop forever; the plan disclosed here is everything the
      // inventory actually has to offer.
      if (bestItem == null || bestKind == null) break;

      buffers[bestKind]!.removeAt(0);
      selectedByKind.putIfAbsent(bestKind, () => []).add(bestItem);
      // Decrement by the real selected item's bytes -- runningBytes is
      // seeded from the SQL-summed TOTAL and must be brought down by every
      // item this loop actually selects, so the loop's own stopping
      // condition (`runningBytes <= maxBytes`) reflects reality rather than
      // exhausting a truncated pool while still over cap (E08-B01's
      // documented under-planning half).
      runningBytes -= bestItem.bytes;

      if (buffers[bestKind]!.isEmpty && !exhausted[bestKind]!) {
        await refill(bestKind);
      }
    }

    final groups = <RetentionCandidateGroup>[
      for (final entry in selectedByKind.entries)
        _group(
          kind: entry.key,
          items: entry.value,
          reason: RetentionReason.overSizeLimit,
          reasonDetail: maxBytes.toString(),
        ),
    ];

    return _plan(
      mode: StorageMode.overSizeMb,
      groups: groups,
      nowEpochMs: nowEpochMs,
    );
  }

  RetentionCandidateGroup _group({
    required StorageItemKind kind,
    required List<StorageItem> items,
    required RetentionReason reason,
    required String? reasonDetail,
  }) {
    final sortedIds = items.map((i) => i.id).toList()..sort();
    final bytes = items.fold<int>(0, (sum, i) => sum + i.bytes);
    return RetentionCandidateGroup(
      categoryKey: _categoryKeyFor(kind),
      kind: kind,
      itemIds: sortedIds,
      itemCount: items.length,
      bytes: bytes,
      reason: reason,
      reasonDetail: reasonDetail,
    );
  }

  RetentionPlan _plan({
    required StorageMode mode,
    required List<RetentionCandidateGroup> groups,
    required int nowEpochMs,
  }) {
    groups.sort((a, b) {
      final byCategory = a.categoryKey.compareTo(b.categoryKey);
      if (byCategory != 0) return byCategory;
      return a.reason.name.compareTo(b.reason.name);
    });
    final totalBytes = groups.fold<int>(0, (sum, g) => sum + g.bytes);
    return RetentionPlan(
      mode: mode.name,
      groups: groups,
      totalBytes: totalBytes,
      // A manual policy scores no factor at all — it is a single literal
      // rule, not Smart Mode's eight-factor scorer (task §2/§4). Both maps
      // stay empty rather than being padded with fabricated `Unavailable`
      // entries for factors this mode never considers.
      availableFactors: const {},
      unavailableFactors: const {},
      computedAt: DateTime.fromMillisecondsSinceEpoch(nowEpochMs),
    );
  }

  /// Mirrors `SmartModePolicy`'s own `_categoryKeyFor` mapping exactly
  /// (task §2: "one plan shape" — the two policies must agree on what a
  /// category is called, or the explanation surface shows two different
  /// names for the same class of data depending on which mode is active).
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
