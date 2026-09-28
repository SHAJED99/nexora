// features/trust/data — the sole reader/writer of `trust_settings`
// (E02-T04, ADR-0001).
//
// Shape mirrors `LocationSettingsRepository` (E09-T02): an injected
// `AppDatabase`, a `read()` that is never null, a `watch()` that emits the
// current value immediately on listen, and a `write()` that stamps
// `updatedAt`. `E02-T04`'s migration guarantees `trust_settings`'s single
// row (`id == 1`) exists on both `onCreate` and `onUpgrade`, so the read/
// watch here never has to handle a missing row.
library;

import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';

class TrustSettingsRepository {
  TrustSettingsRepository({required this.db});

  /// The app's `AppDatabase` instance (injected, never constructed here --
  /// matches `LocationSettingsRepository`'s own precedent, E09-T02).
  final AppDatabase db;

  /// `trust_settings`'s single-row id (`trust_tables.dart`,
  /// `TrustSettings.id`, "always `1`").
  static const int _rowId = 1;

  /// `FR-TRUST-006`'s "allow/disable communication" rule (`Q-FUNC-011`),
  /// read side. Never null -- this task's migration guarantees the single
  /// row exists.
  Future<bool> readAllowNewConnectionRequests() async {
    final row = await (db.select(db.trustSettings)
          ..where((t) => t.id.equals(_rowId)))
        .getSingle();
    return row.allowNewConnectionRequests;
  }

  /// Reactive read, emitting the current value immediately on listen, then
  /// on every change (`LocationSettingsRepository.watchGlobalEnabled()`'s
  /// established reason: a settings surface must not render empty on its
  /// first frame).
  Stream<bool> watchAllowNewConnectionRequests() {
    return (db.select(db.trustSettings)..where((t) => t.id.equals(_rowId)))
        .watchSingle()
        .map((row) => row.allowNewConnectionRequests);
  }

  /// Write side. Updates the single row and stamps `updatedAt` from the
  /// current time.
  Future<void> writeAllowNewConnectionRequests(bool allowed) async {
    await (db.update(db.trustSettings)..where((t) => t.id.equals(_rowId)))
        .write(
      TrustSettingsCompanion(
        allowNewConnectionRequests: Value(allowed),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
