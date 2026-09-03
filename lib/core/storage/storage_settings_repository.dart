// core/storage — the single reader/writer of `storage_policy_settings`
// (E08-T05, ADR-0001).
//
// `FR-STORE-004` names exactly three storage management modes: Smart Mode
// (default), delete-older-than-X-days, delete-when-over-X-MB. This file owns
// that vocabulary ([StorageMode]) and is the *only* file that reads or
// writes `storage_policy_settings` (`storage_tables.dart`, E08-T01's
// single-row table, `id` always `1`). No other file in this build touches
// that table directly.
//
// Changing the mode never deletes anything by itself (task §2) — it only
// changes what the next `ManualPolicy.plan()` / `SmartModePolicy.plan()`
// call says. Execution stays `E08-T06`'s single responsibility.
library;

import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';

/// `FR-STORE-004`'s three modes, and only these three — no "off", no "ask me
/// first", no per-conversation override (task §4). Stored as `.name` in
/// `storage_policy_settings.mode` (docs/conventions.md "Enums": never an
/// integer index).
enum StorageMode { smart, olderThanDays, overSizeMb }

/// The only reader/writer of `storage_policy_settings` (task §3). A fresh
/// install always has a row here — `E08-T01`'s migration inserts the
/// default (`mode: smart`) on both `onCreate` and `onUpgrade` — so this
/// repository never has to handle a missing row (task §2).
class StorageSettingsRepository {
  StorageSettingsRepository({required this.db});

  /// The app's `AppDatabase` instance (injected, never constructed here —
  /// matches `StorageInventory`'s own precedent, E08-T02).
  final AppDatabase db;

  /// The single-row table's only row id (`storage_tables.dart`,
  /// `StoragePolicySettings.id`, "always `1`").
  static const int _rowId = 1;

  /// `FR-STORE-004` says "MB" in user-facing language, but
  /// `storage_policy_settings.max_bytes` is a byte column and this task's
  /// own §5 contract validates it as `>= 1 MiB` literally. This is the one
  /// and only conversion point (task §6 risk note: "pick one conversion,
  /// state it, never convert twice") — 1 MiB = 1,048,576 bytes, the binary
  /// unit, not the decimal "1 MB = 1,000,000 bytes" the user-facing copy
  /// says. Any further MB-facing display conversion is a UI concern
  /// (`E08-T09`), not this repository's.
  static const int minMaxBytes = 1024 * 1024;

  /// Current policy — never null, `E08-T01`'s migration guarantees the row
  /// exists (task §5).
  Future<StoragePolicySettingRow> read() {
    return (db.select(db.storagePolicySettings)
          ..where((t) => t.id.equals(_rowId)))
        .getSingle();
  }

  /// The UI binds to this rather than polling (task §5) — a broadcast
  /// stream (drift's own query streams support multiple independent
  /// listeners) that emits the current value immediately on listen. A
  /// stream that did not emit its current value on listen would make the
  /// settings screen render empty on first frame (task §6 risk note) — this
  /// is proven by
  /// `test_EARS_STORE_11_watch_emits_current_value_on_listen`, not merely
  /// asserted.
  Stream<StoragePolicySettingRow> watch() {
    return (db.select(db.storagePolicySettings)
          ..where((t) => t.id.equals(_rowId)))
        .watchSingle();
  }

  /// Persists `FR-STORE-004`'s user choice (task §5). Validation is
  /// concrete and rejects loudly rather than coercing (task §2):
  /// - `olderThanDays` must be non-null and `>= 1` iff `mode ==
  ///   olderThanDays`, and null otherwise.
  /// - `maxBytes` must be non-null and `>= 1 MiB` ([minMaxBytes]) iff
  ///   `mode == overSizeMb`, and null otherwise.
  /// - `smart` accepts neither parameter.
  ///
  /// Throws [ArgumentError] on any violation — never substitutes a default
  /// (`EARS-STORE-12`). This is the backstop, not the only guard: the UI
  /// (`E08-T09`) validates before ever calling this (task §6 risk note).
  Future<void> setMode(
    StorageMode mode, {
    int? olderThanDays,
    int? maxBytes,
  }) async {
    switch (mode) {
      case StorageMode.smart:
        if (olderThanDays != null) {
          throw ArgumentError.value(
            olderThanDays,
            'olderThanDays',
            'must be null when mode is smart',
          );
        }
        if (maxBytes != null) {
          throw ArgumentError.value(
            maxBytes,
            'maxBytes',
            'must be null when mode is smart',
          );
        }
        break;

      case StorageMode.olderThanDays:
        if (olderThanDays == null) {
          throw ArgumentError.notNull('olderThanDays');
        }
        if (olderThanDays < 1) {
          throw ArgumentError.value(
            olderThanDays,
            'olderThanDays',
            'must be >= 1',
          );
        }
        if (maxBytes != null) {
          throw ArgumentError.value(
            maxBytes,
            'maxBytes',
            'must be null when mode is olderThanDays',
          );
        }
        break;

      case StorageMode.overSizeMb:
        if (maxBytes == null) {
          throw ArgumentError.notNull('maxBytes');
        }
        if (maxBytes < minMaxBytes) {
          throw ArgumentError.value(
            maxBytes,
            'maxBytes',
            'must be >= $minMaxBytes bytes (1 MiB)',
          );
        }
        if (olderThanDays != null) {
          throw ArgumentError.value(
            olderThanDays,
            'olderThanDays',
            'must be null when mode is overSizeMb',
          );
        }
        break;
    }

    await (db.update(db.storagePolicySettings)
          ..where((t) => t.id.equals(_rowId)))
        .write(
      StoragePolicySettingsCompanion(
        mode: Value(mode.name),
        // Explicit `Value(...)`, not `Value.absent()` (L-backend-001): the
        // non-active mode's parameter must be actively cleared to NULL when
        // switching modes, not left at whatever the previous mode wrote.
        olderThanDays: Value(olderThanDays),
        maxBytes: Value(maxBytes),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// A home for `OQ-E08-1`'s eventual answer (task §3) — this task leaves
  /// [bytes] NULL and never sets a default (task §4). `null` clears the
  /// denominator back to "unmeasured".
  Future<void> setBudgetBytes(int? bytes) async {
    await (db.update(db.storagePolicySettings)
          ..where((t) => t.id.equals(_rowId)))
        .write(
      StoragePolicySettingsCompanion(
        budgetBytes: Value(bytes),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
