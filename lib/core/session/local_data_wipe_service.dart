// core/session — LocalDataWipeService (E15-T01, `FR-AUTH-006`, `FR-AUTH-009`,
// `NFR-PRIV-001`).
//
// The one thing sign-out actually does to this device's local state: delete
// `AppDatabase`'s own file (and its `-wal`/`-shm` sidecars), never `DELETE
// FROM` its rows. Deleting rows leaves the SQLite file, its write-ahead log
// and its freelist pages carrying recoverable ciphertext and key material —
// `NFR-PRIV-001` is not satisfied by emptying tables (task §2).
//
// Sentinel (FR-AUTH-009): a zero-byte file written next to the database
// *before* the first delete and removed *after* the last. It cannot live in
// the database — the database is what is being destroyed — so
// `isWipePending()`/`completePendingWipe()` read it directly off disk. An
// interrupted erase (process killed mid-wipe) leaves the sentinel behind;
// `completePendingWipe()` (called by `E15-T02` at launch, before any routing
// decision) re-runs the same delete-and-clear-sentinel path.
//
// Idempotent by design (task §7): every delete tolerates "already absent" —
// `completePendingWipe()` may run on a device where the file, some sidecars,
// or all of them are already gone.
//
// Test isolation (task §6 Risks): `AppDatabase.forTesting(NativeDatabase
// .memory())` has no file at all, so the file-path tests need a real temp
// directory. Both the database path and the actual file-delete call are
// taken through injected seams — [databaseFile] (defaults to
// `AppDatabase.databaseFile`, the one source of truth for where the database
// lives) and [deleteFile] (defaults to `File.delete`) — rather than calling
// `getApplicationDocumentsDirectory()`/`File.delete()` inline, so a test can
// point this service at a temp directory and force a delete to fail without
// touching the real filesystem's permission model.
//
// Scope fence (task §4): this service does NOT tear down any in-memory
// singleton (`AppDatabase`, `MessagingStack`, GetX registrations) — that is
// `SignOutUseCase.call()`'s own, separate "teardown" step, run before this
// service's `wipe()`/`completePendingWipe()` are ever called, per the
// binding ordering in task §5 ("teardown → sentinel → delete → sentinel
// removed → auth clear"). This service only ever touches files.
import 'dart:io';

import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/persistence/database.dart';

class LocalDataWipeService {
  LocalDataWipeService({
    Future<File> Function()? databaseFile,
    Future<void> Function(File file)? deleteFile,
  })  : _databaseFile = databaseFile ?? AppDatabase.databaseFile,
        _deleteFile = deleteFile ?? _defaultDeleteFile;

  final Future<File> Function() _databaseFile;
  final Future<void> Function(File file) _deleteFile;

  static Future<void> _defaultDeleteFile(File file) => file.delete();

  /// The sentinel lives beside the database file itself (`&lt;db path&gt;
  /// .wipe_pending`) — a name that can never collide with the `-wal`/`-shm`
  /// sidecars this same directory already carries.
  Future<File> _sentinelFile() async {
    final dbFile = await _databaseFile();
    return File('${dbFile.path}.wipe_pending');
  }

  /// FR-AUTH-009's detection half. `true` when the sentinel file exists — an
  /// erase was started (at least the database file's own delete was
  /// attempted) and never finished.
  Future<bool> isWipePending() async {
    final sentinel = await _sentinelFile();
    return sentinel.exists();
  }

  /// FR-AUTH-006. Writes the sentinel (if not already present — see
  /// [completePendingWipe]), deletes the database file and its `-wal`/`-shm`
  /// sidecars, removes the sentinel. Idempotent: safe to call when nothing
  /// exists.
  ///
  /// A failed delete is a failure, never silently downgraded to a row-level
  /// clear — it propagates as an [AppFailure], leaving the sentinel in
  /// place so [completePendingWipe] can retry at next launch (task §6
  /// Risks: "the obvious wrong fix").
  Future<void> wipe() async {
    try {
      final sentinel = await _sentinelFile();
      if (!await sentinel.exists()) {
        await sentinel.create(recursive: true);
      }
      await _deleteDatabaseFilesAndSidecars();
      if (await sentinel.exists()) {
        await sentinel.delete();
      }
    } catch (e) {
      throw AppFailure('session.local_wipe_failed', cause: e);
    }
  }

  /// FR-AUTH-009. No-op when no sentinel exists; otherwise re-runs the exact
  /// same delete-and-clear-sentinel path [wipe] uses (the sentinel already
  /// exists, so [wipe]'s own "write it if absent" step is a no-op here) —
  /// called by `E15-T02` at launch, before any routing decision.
  Future<void> completePendingWipe() async {
    if (!await isWipePending()) return;
    await wipe();
  }

  Future<void> _deleteDatabaseFilesAndSidecars() async {
    final dbFile = await _databaseFile();
    for (final path in [dbFile.path, '${dbFile.path}-wal', '${dbFile.path}-shm']) {
      final file = File(path);
      if (await file.exists()) {
        await _deleteFile(file);
      }
    }
  }
}
