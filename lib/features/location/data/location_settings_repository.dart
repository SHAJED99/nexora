// features/location/data — the sole reader/writer of `location_settings`
// and `location_peer_settings` (E09-T02, ADR-0001).
//
// Shape mirrors `StorageSettingsRepository` (E08-T05): an injected
// `AppDatabase`, a `read()` that is never null, a `watch()` that emits the
// current value immediately on listen, and writes that throw rather than
// coerce. `E09-T01`'s migration guarantees `location_settings`'s single row
// (`id == 1`) exists on both `onCreate` and `onUpgrade`, so the global
// read/watch never has to handle a missing row.
//
// `readPeerEnabled`/`watchPeerEnabled` treat an absent
// `location_peer_settings` row as `false` — never `true`, never "unknown"
// (task §6 risk note: "the whole bug" is a careless `?? true` here).
// `readAllPeerEnabled` is the one place that distinguishes "never
// configured" (absent from the map) from "explicitly off" (`false` in the
// map); every other reader collapses both to `false` on purpose.
library;

import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';

class LocationSettingsRepository {
  LocationSettingsRepository({required this.db});

  /// The app's `AppDatabase` instance (injected, never constructed here —
  /// matches `StorageSettingsRepository`'s own precedent, E08-T05).
  final AppDatabase db;

  /// `location_settings`'s single-row id (`location_tables.dart`,
  /// `LocationSettings.id`, "always `1`").
  static const int _globalRowId = 1;

  /// `FR-LOC-001`'s global switch, read side. Never null — `E09-T01`'s
  /// migration guarantees the single row exists.
  Future<bool> readGlobalEnabled() async {
    final row = await (db.select(db.locationSettings)
          ..where((t) => t.id.equals(_globalRowId)))
        .getSingle();
    return row.globalEnabled;
  }

  /// `FR-LOC-001`'s global switch, reactive read. Emits the current value
  /// immediately on listen, then on every change (`StorageSettingsRepository
  /// .watch()`'s established reason: a settings surface must not render
  /// empty on its first frame).
  Stream<bool> watchGlobalEnabled() {
    return (db.select(db.locationSettings)
          ..where((t) => t.id.equals(_globalRowId)))
        .watchSingle()
        .map((row) => row.globalEnabled);
  }

  /// `FR-LOC-001`'s global switch, write side. Updates the single row and
  /// stamps `updatedAt` from the current time.
  Future<void> writeGlobalEnabled(bool enabled) async {
    await (db.update(db.locationSettings)
          ..where((t) => t.id.equals(_globalRowId)))
        .write(
      LocationSettingsCompanion(
        globalEnabled: Value(enabled),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// `FR-LOC-002`'s per-user switch, read side. `FALSE` when no row exists
  /// for [peerDeviceId] — absent is never "unknown" and never "enabled"
  /// (task §6 risk note, `EARS-LOC-7`).
  Future<bool> readPeerEnabled(String peerDeviceId) async {
    final row = await (db.select(db.locationPeerSettings)
          ..where((t) => t.peerDeviceId.equals(peerDeviceId)))
        .getSingleOrNull();
    return row?.enabled ?? false;
  }

  /// Per-peer reactive read, for the same first-frame reason as
  /// [watchGlobalEnabled]. Emits `false` immediately when no row exists,
  /// then the row's value once one is written.
  ///
  /// Built on `watchSingleOrNull()` (not `watchSingle()`, which throws when
  /// the row is missing — `E09-T01`'s migration only guarantees the global
  /// row, never a per-peer row).
  Stream<bool> watchPeerEnabled(String peerDeviceId) {
    return (db.select(db.locationPeerSettings)
          ..where((t) => t.peerDeviceId.equals(peerDeviceId)))
        .watchSingleOrNull()
        .map((row) => row?.enabled ?? false);
  }

  /// `FR-LOC-002`'s per-user switch, write side. Upserts on the
  /// `peer_device_id` primary key and stamps `updatedAt`.
  Future<void> writePeerEnabled(String peerDeviceId, bool enabled) async {
    await db.into(db.locationPeerSettings).insertOnConflictUpdate(
          LocationPeerSettingsCompanion.insert(
            peerDeviceId: peerDeviceId,
            enabled: Value(enabled),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// The one bulk read: every peer that HAS a row, keyed by
  /// `peerDeviceId`. Peers with no row are absent from the map, not
  /// present-with-`false` — this is the only place that distinguishes
  /// "never configured" from "explicitly off"; [readPeerEnabled] collapses
  /// both to `false` on purpose.
  ///
  /// No pagination: the row count is bounded by the device's own
  /// relationship count, which `RelationshipRepository.listAll` already
  /// returns unpaginated (task §5).
  Future<Map<String, bool>> readAllPeerEnabled() async {
    final rows = await db.select(db.locationPeerSettings).get();
    return {for (final row in rows) row.peerDeviceId: row.enabled};
  }
}
