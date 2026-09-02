// core/persistence -- storage lifecycle tables (ADR-0001, E08-T01).
//
// Three tables give every later E08 task one durable place to keep what the
// storage manager *knows* (per-item access signals, `StorageItemStats`),
// what the user *chose* (the active policy, `StoragePolicySettings`), and
// what the policy *decided and why* (the explanation log,
// `StorageDecisions`) -- so no later task invents a table under time
// pressure (task §1). This file only defines storage shape: no row of user
// conversation data is read, written or deleted here (task §4).
import 'package:drift/drift.dart';

/// One row per `(itemKind, itemId)` -- the access signals `FR-STORE-005`
/// needs and the schema currently has nowhere to put. `itemKind` is a
/// `StorageItemKind.name` string (E08-T02 owns the enum; docs/conventions.md
/// "Enums" -- never an integer index). An absent row means "never observed"
/// -- this task deliberately does not backfill from existing `messages`
/// rows (task §4), so a NULL `lastAccessedAt` is the honest default, never
/// synthesized as 0.
@DataClassName('StorageItemStatRow')
@TableIndex(
  name: 'idx_storage_item_stats_last_accessed',
  columns: {#lastAccessedAt},
)
class StorageItemStats extends Table {
  TextColumn get itemKind => text()();
  TextColumn get itemId => text()();

  /// Epoch-ms; NULL = never observed, never 0 (task §5).
  IntColumn get lastAccessedAt => integer().nullable()();

  IntColumn get accessCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {itemKind, itemId};
}

/// Single-row table (`id` always `1`) holding `FR-STORE-004`'s active
/// policy -- the simplest correct shape for app-wide settings, making
/// "exactly one active policy" an invariant of the schema rather than of
/// every reader (task §2). The migration inserts the one default row
/// (`mode == 'smart'`) on both `onCreate` and `onUpgrade` -- the app must
/// never have to cope with an absent settings row (task §5).
///
/// `budgetBytes` stays NULL until a human answers `OQ-E08-1` (task §2) --
/// this task does not choose a default. NULL means "no denominator known",
/// which every reader must render as *unmeasured*, never as 0 or 100%.
@DataClassName('StoragePolicySettingRow')
class StoragePolicySettings extends Table {
  IntColumn get id => integer()();

  /// A `StorageMode.name`: `smart` | `olderThanDays` | `overSizeMb`
  /// (docs/conventions.md "Enums" -- never an integer index).
  TextColumn get mode => text()();

  /// NULL unless `mode == olderThanDays`.
  IntColumn get olderThanDays => integer().nullable()();

  /// NULL unless `mode == overSizeMb`.
  IntColumn get maxBytes => integer().nullable()();

  /// The denominator; stays NULL until `OQ-E08-1` is answered (task §2).
  IntColumn get budgetBytes => integer().nullable()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// `FR-STORE-007`'s "what did the policy decide, and why" -- an append-only
/// explanation log. `categoryKey` and `reasonCode` are stable machine keys,
/// never display copy (task §5) -- the user-facing strings are design copy
/// owned by `E08-T07`'s design contract, not stored here.
@DataClassName('StorageDecisionRow')
@TableIndex(
  name: 'idx_storage_decisions_decided_at',
  columns: {#decidedAt},
)
class StorageDecisions extends Table {
  TextColumn get id => text()();
  IntColumn get decidedAt => integer()();

  /// The `StorageMode.name` in force when the decision was made.
  TextColumn get mode => text()();

  /// A stable machine key (e.g. `relayCache`, `messages`) -- not display
  /// copy.
  TextColumn get categoryKey => text()();

  IntColumn get itemCount => integer()();

  /// Real measured bytes, never estimated.
  IntColumn get bytes => integer()();

  /// A `RetentionReason.name` (E08-T04 owns the enum).
  TextColumn get reasonCode => text()();

  /// The reason's parameter as text (e.g. `45` for "older than 45 days").
  TextColumn get reasonDetail => text().nullable()();

  /// A `DecisionOutcome.name`: `planned` | `applied` | `skipped`.
  TextColumn get outcome => text()();

  @override
  Set<Column> get primaryKey => {id};
}
