// features/messaging/domain — SyncCursorService (E05-T04, FR-MSG-006/
// FR-FB-002).
//
// Multi-device sync is missing-data-only, not full re-sync (FR-MSG-006):
// this service tracks, per (local device, remote device, conversation), the
// highest `messages.sequence_number` this device has confirmed seeing from
// that remote device -- so a reconnect only needs to request the gap, not
// re-fetch everything. This file is bookkeeping only; it does NOT implement
// the actual gap-request/gap-fill protocol over the mesh (task §4 -- that
// needs a message-envelope type this epic hasn't defined, flagged as
// OQ-E05-T04-1) and does NOT implement conflict resolution (T05 -- sync
// cursors concern message *position*, not trust/security *state*).
//
// Firebase boundary (FR-FB-002, non-negotiable): the Firebase read/write
// methods below mirror `FirebaseMetadataService`'s exact pattern (E01-T02) --
// best-effort, bounded timeout via `.timeout()`, catch-and-log via
// `ObservabilityService`, never throws to the caller. Only sequence-number/
// device-id/conversation-id fields are ever written -- never message content
// or ciphertext.
import 'package:drift/drift.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';

/// Immutable value object mirroring a `sync_cursors` row in domain terms.
class SyncCursor {
  const SyncCursor({
    required this.localDeviceId,
    required this.remoteDeviceId,
    required this.conversationId,
    required this.lastConfirmedSequenceNumber,
    required this.updatedAt,
  });

  final String localDeviceId;
  final String remoteDeviceId;
  final String conversationId;
  final int lastConfirmedSequenceNumber;

  /// Epoch-ms wall-clock time of the last update to this cursor.
  final int updatedAt;

  factory SyncCursor.fromRow(SyncCursorRow row) => SyncCursor(
        localDeviceId: row.localDeviceId,
        remoteDeviceId: row.remoteDeviceId,
        conversationId: row.conversationId,
        lastConfirmedSequenceNumber: row.lastConfirmedSequenceNumber,
        updatedAt: row.updatedAt,
      );

  /// Reconstructs a cursor from the exact field set
  /// [SyncCursorService.writeCursorToFirebase] writes -- used by
  /// [SyncCursorService.readRemoteCursorFromFirebase].
  static SyncCursor? fromFirebaseData(Object? data) {
    if (data is! Map) return null;
    final localDeviceId = data['localDeviceId'];
    final remoteDeviceId = data['remoteDeviceId'];
    final conversationId = data['conversationId'];
    final lastConfirmedSequenceNumber = data['lastConfirmedSequenceNumber'];
    final updatedAt = data['updatedAt'];
    if (localDeviceId is! String ||
        remoteDeviceId is! String ||
        conversationId is! String ||
        lastConfirmedSequenceNumber is! int ||
        updatedAt is! int) {
      return null;
    }
    return SyncCursor(
      localDeviceId: localDeviceId,
      remoteDeviceId: remoteDeviceId,
      conversationId: conversationId,
      lastConfirmedSequenceNumber: lastConfirmedSequenceNumber,
      updatedAt: updatedAt,
    );
  }
}

class SyncCursorService {
  SyncCursorService({
    required this.localDeviceId,
    required AppDatabase database,
    FirebaseDatabase? firebaseDatabase,
    Duration? timeout,
    DateTime Function() clock = DateTime.now,
  })  : // Named params (`database`, `clock`) are public API; the private
        // fields below can't share those names, so `prefer_initializing_
        // formals` doesn't apply here despite the trivial assignment.
        _database = database, // ignore: prefer_initializing_formals
        _firebaseDatabaseOverride = firebaseDatabase,
        // Same reasoning as FirebaseMetadataService._timeout: a Realtime
        // Database write/read queued offline never completes at all, so
        // this bounds it -- a timeout is just another failure mode, caught
        // below like any other Realtime Database error.
        _timeout = timeout ?? const Duration(seconds: 10),
        _clock = clock; // ignore: prefer_initializing_formals

  /// This device's own device id -- the "local" side of every cursor this
  /// service instance manages.
  final String localDeviceId;

  final AppDatabase _database;
  final FirebaseDatabase? _firebaseDatabaseOverride;
  final Duration _timeout;
  final DateTime Function() _clock;

  // Resolved lazily, mirroring FirebaseMetadataService._database -- so
  // constructing a SyncCursorService with no override never touches a live
  // Realtime Database instance until a read/write is actually attempted.
  FirebaseDatabase get _firebaseDatabase =>
      _firebaseDatabaseOverride ?? FirebaseDatabase.instance;

  /// Advances this device's high-water mark for [conversationId] against
  /// whichever device produced the message ([senderDeviceId]) -- called
  /// whenever a message is durably stored, by `MessagingCoordinator`
  /// (E06-T06): `MessagingCoordinator.recordStored` for an outbound send's
  /// result, and automatically on every `InboundPipeline.delivered` event
  /// for a receive. Neither `SendMessageUseCase` (T02) nor
  /// `ReceiveMessageUseCase` (T03) imports this service or calls this method
  /// themselves -- this comment used to claim otherwise (E05-B02's finding:
  /// the same false-wiring-claim shape as E05-B01's root cause), which was
  /// never true from the day this method was written.
  ///
  /// Monotonic only (EARS-MSG-5/FR-MSG-006): never regresses the stored
  /// `last_confirmed_sequence_number`, even if called with an older
  /// [sequenceNumber] than what is already recorded (e.g. a delayed or
  /// out-of-order call).
  ///
  /// Round-1 review finding: an earlier version of this method did a
  /// read-then-write (`cursorFor` guard, then a separate
  /// `insertOnConflictUpdate`) with an `await` in between -- two overlapping
  /// calls could both read the stale row before either wrote, losing an
  /// update (e.g. concurrent calls with sequence numbers 10 and 4 could
  /// leave the cursor at 4). Fixed by collapsing to a single guarded upsert
  /// statement below: the monotonic check is expressed as the `DoUpdate`
  /// clause's `where`, evaluated by SQLite atomically as part of the same
  /// statement that performs the write, so there is no read-then-write
  /// window for two concurrent calls to race through. (Preferred over
  /// wrapping the old read-then-write in `_database.transaction()`, mirroring
  /// `DriftSignalStore`'s counter pattern (drift_signal_store.dart:221,261):
  /// that pattern is only race-free because it re-reads the counter row
  /// *inside* the transaction and both the read and the write are issued on
  /// the same connection inside one BEGIN/COMMIT, serialized by SQLite's
  /// write lock -- it still depends on drift's transaction serialization
  /// actually holding the lock across the internal `await`, which is a
  /// property of drift's queuing behaviour rather than of the SQL itself.
  /// The single-statement upsert has no such dependency: the guard and the
  /// write are one atomic SQL statement, race-free regardless of drift's
  /// transaction/isolation semantics.)
  Future<void> recordLocalProgress(
    String conversationId,
    String senderDeviceId,
    int sequenceNumber,
  ) async {
    final now = _clock().millisecondsSinceEpoch;
    await _database.into(_database.syncCursors).insert(
          SyncCursorsCompanion.insert(
            localDeviceId: localDeviceId,
            remoteDeviceId: senderDeviceId,
            conversationId: conversationId,
            lastConfirmedSequenceNumber: sequenceNumber,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (old) => SyncCursorsCompanion(
              lastConfirmedSequenceNumber: Value(sequenceNumber),
              updatedAt: Value(now),
            ),
            // Only apply the update if it would not regress the cursor --
            // otherwise keep the existing row untouched (a conflict with a
            // false `where` is a no-op in SQLite's upsert semantics, not an
            // error).
            where: (old) =>
                old.lastConfirmedSequenceNumber.isSmallerThanValue(
              sequenceNumber,
            ),
          ),
        );
  }

  /// Local read of the last known cursor for `(localDeviceId,
  /// remoteDeviceId, conversationId)`. Returns `null` if no progress has
  /// been recorded yet for that device-pair/conversation.
  Future<SyncCursor?> cursorFor(
    String conversationId,
    String remoteDeviceId,
  ) async {
    final row = await (_database.select(_database.syncCursors)
          ..where(
            (t) =>
                t.localDeviceId.equals(localDeviceId) &
                t.remoteDeviceId.equals(remoteDeviceId) &
                t.conversationId.equals(conversationId),
          ))
        .getSingleOrNull();
    return row == null ? null : SyncCursor.fromRow(row);
  }

  /// Best-effort Realtime Database publish of this device's cursor metadata
  /// (sequence number + conversation/device ids only -- no content,
  /// FR-FB-002). Never throws: any Realtime Database error (including being
  /// offline) is caught and logged via [ObservabilityService], same pattern
  /// as `FirebaseMetadataService.registerDevice`.
  Future<void> writeCursorToFirebase(String uid, SyncCursor cursor) async {
    try {
      await writeCursorData(uid, cursor, {
        'localDeviceId': cursor.localDeviceId,
        'remoteDeviceId': cursor.remoteDeviceId,
        'conversationId': cursor.conversationId,
        'lastConfirmedSequenceNumber': cursor.lastConfirmedSequenceNumber,
        'updatedAt': cursor.updatedAt,
      }).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.sync_cursor_write_failed',
        cause: e,
      );
    }
  }

  /// Performs the actual Realtime Database write. Split out from
  /// [writeCursorToFirebase] deliberately -- `FirebaseDatabase`/
  /// `DatabaseReference` need a live platform-channel test harness to
  /// construct in tests, so tests seam here instead (mirrors
  /// `FirebaseMetadataService.writeDeviceMetadata`).
  Future<void> writeCursorData(
    String uid,
    SyncCursor cursor,
    Map<String, dynamic> data,
  ) {
    return _firebaseDatabase
        .ref(_cursorPath(uid, cursor.localDeviceId, cursor.conversationId,
            cursor.remoteDeviceId))
        .set(data);
  }

  /// Best-effort read of another of the user's own devices' last-known
  /// cursor for `(remoteDeviceId, conversationId)`, to compute the
  /// local-vs-remote gap. Returns `null` on any failure -- offline, not
  /// found, malformed data, or timeout -- never throws.
  Future<SyncCursor?> readRemoteCursorFromFirebase(
    String uid,
    String remoteDeviceId,
    String conversationId,
  ) async {
    try {
      final data = await readCursorData(uid, remoteDeviceId, conversationId)
          .timeout(_timeout);
      return SyncCursor.fromFirebaseData(data);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.sync_cursor_read_failed',
        cause: e,
      );
      return null;
    }
  }

  /// Performs the actual Realtime Database read, at the path
  /// [remoteDeviceId] itself would have written its own cursor to (its
  /// "local", our "remote") -- i.e. the entry recorded against
  /// [localDeviceId] as *its* remote device. Split out from
  /// [readRemoteCursorFromFirebase] for the same test-seam reason as
  /// [writeCursorData].
  Future<Object?> readCursorData(
    String uid,
    String remoteDeviceId,
    String conversationId,
  ) async {
    final snapshot = await _firebaseDatabase
        .ref(_cursorPath(uid, remoteDeviceId, conversationId, localDeviceId))
        .get();
    return snapshot.value;
  }

  /// `users/$uid/sync_cursors/$writerDeviceId/$conversationId/$aboutDeviceId`
  /// -- consistent with the existing `users/$uid/devices/$deviceId`
  /// convention (`FirebaseMetadataService`). [writerDeviceId] is whichever
  /// device produced this cursor entry; [aboutDeviceId] is the device that
  /// entry's `last_confirmed_sequence_number` is tracking progress against.
  String _cursorPath(
    String uid,
    String writerDeviceId,
    String conversationId,
    String aboutDeviceId,
  ) =>
      'users/$uid/sync_cursors/$writerDeviceId/$conversationId/$aboutDeviceId';
}
