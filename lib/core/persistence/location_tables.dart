// core/persistence -- location sharing tables (ADR-0001, E09-T01).
//
// Three tables give every later E09 task one durable place to keep what the
// user *chose* (global on/off -- `FR-LOC-001`; per-peer on/off -- additional
// to the global one, `FR-LOC-002`) and the single most recent location fix
// known for each peer, with "no permanent location history" (`FR-LOC-004`)
// enforced by the schema's own shape rather than by every writer
// remembering: `LocationFixes` uses `peerDeviceId` as its primary key, so the
// table can physically hold at most one row per peer, ever.
//
// This file only defines location-sharing shape: no permission is evaluated,
// no byte is encrypted, decrypted, sent or received here (task §4). Neither
// a staleness threshold nor any user-facing copy is decided here either --
// both are reader-side judgements `E09-T04` owns.
import 'package:drift/drift.dart';

/// Single-row table (`id` always `1`) holding `FR-LOC-001`'s app-wide
/// sharing switch -- the same shape and for the same reason as
/// `StoragePolicySettings` (E08-T01): "exactly one global setting exists"
/// becomes a schema invariant rather than a thing every reader must cope
/// with. The migration inserts the one default row with `globalEnabled ==
/// false` on both `onCreate` and `onUpgrade` (task §2, §5) -- absent
/// evidence that a user opted in, the honest default for a privacy control
/// is off.
@DataClassName('LocationSettingRow')
class LocationSettings extends Table {
  IntColumn get id => integer()();

  BoolColumn get globalEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Epoch-ms.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per peer holding `FR-LOC-002`'s per-user sharing switch --
/// additional to (never instead of) `LocationSettings.globalEnabled`. An
/// absent row means **not enabled**, never "enabled" and never "unknown"
/// (task §2) -- there is deliberately no tri-state column, and this task
/// does not backfill from `relationships` (task §4).
@DataClassName('LocationPeerSettingRow')
class LocationPeerSettings extends Table {
  /// The same device-id string `relationships.deviceId` uses.
  TextColumn get peerDeviceId => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  /// Epoch-ms.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {peerDeviceId};
}

/// The single latest known location fix per peer. `peerDeviceId` is the
/// **primary key** -- this is `FR-LOC-004`'s no-permanent-history invariant
/// made structural rather than procedural: the table can physically hold at
/// most one row per peer, ever. There is no history table and no append
/// path; a second fix for a peer that already has one replaces the existing
/// row (task §3, §8 EARS-LOC-5 no-history half).
///
/// `capturedAt` and `receivedAt` are both present on purpose and are not
/// interchangeable (task §5): `capturedAt` is the sender's clock, what
/// `FR-LOC-005`'s staleness is measured against; `receivedAt` is this
/// device's clock, when the fix was accepted. A fix that arrives now but was
/// measured twenty minutes ago is stale, and a schema with only one
/// timestamp cannot say so.
@DataClassName('LocationFixRow')
@TableIndex(
  name: 'idx_location_fixes_captured_at',
  columns: {#capturedAt},
)
class LocationFixes extends Table {
  TextColumn get peerDeviceId => text()();

  /// Decimal degrees, WGS84.
  RealColumn get latitude => real()();

  /// Decimal degrees, WGS84.
  RealColumn get longitude => real()();

  /// Metres; NULL = the sender reported none, never 0 (task §5).
  RealColumn get accuracyM => real().nullable()();

  /// Epoch-ms, as reported by the sender.
  IntColumn get capturedAt => integer()();

  /// Epoch-ms, this device's clock, when the fix was accepted.
  IntColumn get receivedAt => integer()();

  @override
  Set<Column> get primaryKey => {peerDeviceId};
}
