// features/trust/data — wraps the `relationships` Drift table (ADR-0001).
// The one place `RelationshipState` <-> the `relationships.state` text
// column conversion happens (E02-T01).
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
    return domain.Relationship(
      deviceId: row.deviceId,
      state: domain.RelationshipState.values.byName(row.state),
      updatedAt: row.updatedAt,
    );
  }

  /// FR-BLOCK-001 — the one enforcement query point every later
  /// communication epic (E04+) must call before allowing any direct
  /// interaction with [deviceId].
  Future<bool> isBlocked(String deviceId) async {
    final relationship = await get(deviceId);
    return relationship?.state == domain.RelationshipState.blocked;
  }
}
