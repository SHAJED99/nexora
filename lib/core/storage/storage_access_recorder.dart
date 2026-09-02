// core/storage — access-frequency signals (E08-T03).
//
// `FR-STORE-005` names *access frequency* as one of the eight factors Smart
// Mode weighs, and until this task the schema recorded it nowhere
// (`storage_item_stats`, created empty by E08-T01). This file is the single
// writer of that table (task §5 Data: "No other table is written").
//
// **An access is a real display, not a query** (task §2). The two call
// sites this task wires are both in `ChatController`
// (`onInit` — conversation opened, `onMessageDisplayed` — a bubble actually
// rendered) — never the conversations list projection, the dashboard
// preview, or a sync pass. Every extra call site silently redefines what
// "accessed" means (task §4), so this file adds none of its own.
//
// **NULL means never observed** (task §2). This recorder never reads
// `storage_item_stats`, never backfills it, and never invents a default for
// an item it has not itself observed — an absent row stays absent until a
// real access happens.
//
// **`StorageItemKind`** is owned by `E08-T02`'s `storage_item.dart`
// (`storage_tables.dart`'s own doc: "a `StorageItemKind.name` string (E08-T02
// owns the enum)"). At the time this task was first built, T02 had not yet
// merged (dispatched in parallel off the same base commit) and this file
// declared its own verbatim-matching copy of the enum as a disclosed,
// temporary seam (`OQ-E08-T03-1`) — now resolved: T02 merged
// (`epic_08`@`1efec77`) and this file imports the canonical enum below, one
// value at a time identical to what the seam already produced, so this is a
// pure import-source change with no behavior change.
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';

import 'storage_item.dart' show StorageItemKind;

/// One coalesced write's identity — a `(item_kind, item_id)` pair, matching
/// `storage_item_stats`'s own primary key (task §5 Data).
class _PendingKey {
  const _PendingKey(this.itemKind, this.itemId);

  final String itemKind;
  final String itemId;

  @override
  bool operator ==(Object other) =>
      other is _PendingKey &&
      other.itemKind == itemKind &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(itemKind, itemId);
}

/// The single writer of `storage_item_stats` (task §5). Coalesces repeated
/// accesses to the same `(kind, id)` within [flushInterval] into one
/// upsert — scrolling a long conversation is not one write per bubble per
/// frame (task §6 Risks) — while still reflecting every call in the
/// eventual `access_count` (task §8: "ten calls, one write, count reflects
/// ten").
///
/// Recording is best-effort and never blocks or throws to the caller (task
/// §2/§5) — a failed stat write is not a user-visible error, the same
/// posture `E06-T08`'s delivery acks already established for a lost ack.
class StorageAccessRecorder {
  StorageAccessRecorder({
    required AppDatabase db,
    this.flushInterval = const Duration(seconds: 5),
    DateTime Function() clock = DateTime.now,
  })  : _db = db, // ignore: prefer_initializing_formals
        _clock = clock; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Duration flushInterval;
  final DateTime Function() _clock;

  /// Accesses observed since the last flush, keyed by `(kind, id)` — the
  /// value is how many times [recordAccess] was called for that key in the
  /// current window, so the eventual write bumps `access_count` by the
  /// whole coalesced total, not just by one (task §8).
  Map<_PendingKey, int> _pending = <_PendingKey, int>{};

  Timer? _timer;

  /// Notes that [itemId] (of class [kind]) was really used — fire and
  /// forget, never throws (task §5 contract). The write itself is deferred
  /// to the next [flush] (scheduled automatically, at most [flushInterval]
  /// away).
  void recordAccess(StorageItemKind kind, String itemId) {
    try {
      final key = _PendingKey(kind.name, itemId);
      _pending[key] = (_pending[key] ?? 0) + 1;
      _timer ??= Timer(flushInterval, () {
        _timer = null;
        unawaited(flush());
      });
    } catch (_) {
      // Best-effort (task §2/§5) — recording must never surface as a
      // caller-visible failure.
    }
  }

  /// Conversation-level access signal (task §5 contract): recorded as kind
  /// `message` with [conversationId] as the item id, so a conversation
  /// opened but not scrolled still counts as used.
  void recordConversationOpened(String conversationId) {
    recordAccess(StorageItemKind.message, conversationId);
  }

  /// Flushes every pending coalesced write durably (task §5 contract) — a
  /// single upsert statement per `(kind, id)` pair, atomic in SQL
  /// (`INSERT ... ON CONFLICT DO UPDATE SET access_count = access_count +
  /// :n`, never a read-then-write — `skills/implement` §6's atomic-counter
  /// requirement). Never called per-bubble; only by the debounce timer,
  /// [dispose], and tests that need a deterministic point to assert
  /// against.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return;
    final batch = _pending;
    _pending = <_PendingKey, int>{};

    final nowMs = _clock().millisecondsSinceEpoch;
    try {
      for (final entry in batch.entries) {
        final key = entry.key;
        final count = entry.value;
        await _db.into(_db.storageItemStats).insert(
              StorageItemStatsCompanion.insert(
                itemKind: key.itemKind,
                itemId: key.itemId,
                lastAccessedAt: Value(nowMs),
                accessCount: Value(count),
              ),
              onConflict: DoUpdate(
                // `.custom(...)` accepts a raw `Expression<T>` per column
                // (unlike the plain constructor's `Value<T>`, which only
                // ever carries a literal) — the single-statement, SQL-side
                // `access_count = access_count + :n` this contract requires
                // (task §5 Data; `skills/implement` §6's atomic-counter
                // requirement: never read-then-write).
                (old) => StorageItemStatsCompanion.custom(
                  accessCount: old.accessCount + Constant(count),
                  lastAccessedAt: Constant(nowMs),
                ),
              ),
            );
      }
    } catch (_) {
      // Best-effort (task §2/§5) — a failed stat write is not a
      // user-visible error and never propagates out of the display path.
      // The coalesced counts for this window are lost (not re-queued):
      // re-queuing risks an unbounded retry loop against a persistently
      // failing store, which is a worse failure mode than an undercounted
      // access signal.
    }
  }

  /// Flushes pending writes then cancels the timer — no timer outlives the
  /// controller that owns it (task §5 contract, task §6 Risks).
  Future<void> dispose() async {
    await flush();
  }
}
