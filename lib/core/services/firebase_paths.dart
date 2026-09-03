// core/services — E11-T01: the single path registry for every Realtime
// Database path the app uses.
//
// Reconciliation, not invention (task §2/§6 Risks): `FirebaseMetadataService`
// (E01-T02) and `SyncCursorService` (E05-T04) already built and shipped their
// own path strings. The functions below reproduce those exact strings —
// verbatim, argument order preserved — so today's paths in the field never
// change. See `docs/firebase-schema.md` for the full tree these paths cover,
// and `EARS-FB-3`: every Realtime Database path SHALL come from this
// registry, and SHALL be identical to the paths in use before this task.
//
// Pure functions only: no `FirebaseDatabase` import, no I/O — trivially
// testable, and safe to call from anywhere without touching a live database
// instance.
class FirebasePaths {
  const FirebasePaths._();

  /// `users/<uid>/devices/<deviceId>` — the device-registry node
  /// (`FirebaseMetadataService`, E01-T02). Unchanged since that task shipped.
  static String device(String uid, String deviceId) =>
      'users/$uid/devices/$deviceId';

  /// `users/<uid>/sync_cursors/<writerDeviceId>/<conversationId>/<aboutDeviceId>`
  /// — replaces `SyncCursorService._cursorPath`. Argument order preserved
  /// exactly: [writerDeviceId] is whichever device produced the cursor entry,
  /// [aboutDeviceId] is the device that entry's sequence number tracks
  /// progress against (task §6 Risks — this order is easy to transpose and
  /// the resulting bug is silent, a read simply returns null forever).
  static String syncCursor(
    String uid,
    String writerDeviceId,
    String conversationId,
    String aboutDeviceId,
  ) =>
      'users/$uid/sync_cursors/$writerDeviceId/$conversationId/$aboutDeviceId';
}
