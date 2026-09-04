// features/location/data — the sole reader/writer of `location_fixes`
// (E09-T03, ADR-0001).
//
// `location_fixes.peer_device_id` is the primary key (`location_tables.dart`,
// E09-T01) — this is `FR-LOC-004`'s no-permanent-history invariant made
// structural: the table can physically hold at most one row per peer, ever.
// [upsertFix] is therefore a full replace, never a partial update — there is
// no append path in this class or anywhere else in this codebase (task file
// §2/§3).
library;

import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';

class LocationFixRepository {
  LocationFixRepository({required this.db});

  /// Injected `AppDatabase` — never constructed here, matching every other
  /// repository in this codebase (`LocationSettingsRepository`,
  /// `StorageSettingsRepository`).
  final AppDatabase db;

  /// The only write path into `location_fixes` (task file §5). Replaces
  /// [peerDeviceId]'s single row wholesale — `accuracyM` is written
  /// explicitly even when `null`, so a fix that no longer reports accuracy
  /// never inherits a stale non-null value left by a previous fix
  /// (`docs/../L-backend-001`'s `Value(null)` vs `Value.absent()`
  /// distinction: this is a full replace, not a partial update, so writing
  /// `Value(accuracyM)` unconditionally is the correct call here).
  Future<void> upsertFix({
    required String peerDeviceId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    required int capturedAtMs,
    required int receivedAtMs,
  }) async {
    await db.into(db.locationFixes).insertOnConflictUpdate(
          LocationFixesCompanion(
            peerDeviceId: Value(peerDeviceId),
            latitude: Value(latitude),
            longitude: Value(longitude),
            accuracyM: Value(accuracyM),
            capturedAt: Value(capturedAtMs),
            receivedAt: Value(receivedAtMs),
          ),
        );
  }

  /// The peer's single stored fix, or `null` if none (`E09-T04`'s read
  /// side).
  Future<LocationFixRow?> readFix(String peerDeviceId) async {
    return (db.select(db.locationFixes)
          ..where((t) => t.peerDeviceId.equals(peerDeviceId)))
        .getSingleOrNull();
  }

  /// Idempotent — deleting a non-existent row is not an error (task file
  /// §5). Called when sharing is revoked or a peer is blocked/no longer
  /// visible (`FR-LOC-004`).
  Future<void> deleteFix(String peerDeviceId) async {
    await (db.delete(db.locationFixes)
          ..where((t) => t.peerDeviceId.equals(peerDeviceId)))
        .go();
  }
}
