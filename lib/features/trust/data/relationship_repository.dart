// features/trust/data — wraps the `relationships` Drift table (ADR-0001).
// The one place `RelationshipState` <-> the `relationships.state` text
// column conversion happens (E02-T01).
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/trust/domain/relationship.dart'
    as domain;

class RelationshipRepository {
  final AppDatabase _db;

  RelationshipRepository(this._db);

  /// Inserts or updates the local relationship state for [deviceId].
  Future<void> upsert(String deviceId, domain.RelationshipState state) {
    return _db.into(_db.relationships).insertOnConflictUpdate(
          RelationshipsCompanion.insert(
            deviceId: deviceId,
            state: state.name,
            updatedAt: DateTime.now(),
          ),
        );
  }

  /// Reads back the stored relationship for [deviceId], or null if this
  /// side has never evaluated it.
  Future<domain.Relationship?> get(String deviceId) async {
    final row = await (_db.select(_db.relationships)
          ..where((t) => t.deviceId.equals(deviceId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Reads back every stored relationship, most recently updated first.
  ///
  /// Added in E02-T02: until then no caller needed the full set. This is
  /// the Devices screen's only data source — there is no live device
  /// discovery yet (E04), so it renders exactly what this side has already
  /// evaluated locally.
  Future<List<domain.Relationship>> listAll() async {
    final rows = await (_db.select(_db.relationships)
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
            (t) => OrderingTerm.asc(t.deviceId),
          ]))
        .get();
    return rows.map(_fromRow).toList();
  }

  domain.Relationship _fromRow(RelationshipRow row) => domain.Relationship(
        deviceId: row.deviceId,
        state: domain.RelationshipState.values.byName(row.state),
        updatedAt: row.updatedAt,
      );

  /// FR-BLOCK-001 — the one enforcement query point every later
  /// communication epic (E04+) must call before allowing any direct
  /// interaction with [deviceId].
  Future<bool> isBlocked(String deviceId) async {
    final relationship = await get(deviceId);
    return relationship?.state == domain.RelationshipState.blocked;
  }

  /// Reactive read of [deviceId]'s stored `RelationshipState`, added by
  /// `E09-B01`: a caller re-evaluating a state-dependent policy on every
  /// change (e.g. `LocationVisibilityPolicy`) previously had no way to
  /// observe this table at all.
  ///
  /// Emits `RelationshipState.unknown` immediately on listen when no row
  /// exists for [deviceId] — never `null`, and never a state this side has
  /// not actually recorded — matching [get]'s own `null` -> `unknown`
  /// fallback used by every caller of this repository (e.g.
  /// `LocationReadModel._evaluateVisibility`). Built on
  /// `watchSingleOrNull()`, the same emit-on-listen shape
  /// `LocationSettingsRepository.watchPeerEnabled` already uses, for the
  /// same reason: `upsert` never pre-creates a row for every device, so a
  /// caller must be able to watch a device it has not evaluated yet.
  Stream<domain.RelationshipState> watchState(String deviceId) {
    return (_db.select(_db.relationships)
          ..where((t) => t.deviceId.equals(deviceId)))
        .watchSingleOrNull()
        .map(
          (row) => row == null
              ? domain.RelationshipState.unknown
              : domain.RelationshipState.values.byName(row.state),
        );
  }
}
