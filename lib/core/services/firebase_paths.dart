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

  /// `users/<uid>/devices` — the parent node this account's device nodes
  /// live under. Used by `DeviceRevocationService.pullRevocations`
  /// (E11-T04) to enumerate every one of the account's devices and their
  /// `revocation` child in a single read, rather than one read per device.
  static String devices(String uid) => 'users/$uid/devices';

  /// `users/<uid>/devices/<deviceId>/revocation` — the revocation-info
  /// child node (E11-T04, `FR-FB-001` "revocation information"). A new leaf
  /// under the pre-existing [device] node, not a new top-level path.
  static String deviceRevocation(String uid, String deviceId) =>
      'users/$uid/devices/$deviceId/revocation';

  /// `users/<uid>/relationships` — the parent node this account's own
  /// trust/block relationship entries live under. Used by
  /// `RelationshipSyncService.pull` (E11-T05) to enumerate every peer
  /// device this account has a relationship node for in a single read,
  /// same shape as [devices]/`DeviceRevocationService.pullRevocations`.
  static String relationships(String uid) => 'users/$uid/relationships';

  /// `users/<uid>/relationships/<peerDeviceId>` — this account's own
  /// trust/block state for [peerDeviceId] (E11-T05, `FR-TRUST-007`
  /// "relevant relationship configuration shall synchronize", read
  /// narrowly per `ADR-0008` as a user's own devices agreeing with each
  /// other). `$peerDeviceId` is the remote device id this relationship is
  /// about, never a foreign account's uid.
  static String relationship(String uid, String peerDeviceId) =>
      'users/$uid/relationships/$peerDeviceId';

  /// `directory` — the parent node every [directoryEntry] lives under
  /// (`E11-T06`, `ADR-0008` option 2). Deliberately never passed to
  /// `.ref(...)` by any application code — `DeviceDirectoryService` only
  /// ever reads/writes an exact [directoryEntry]. This function exists so
  /// the rules test can attempt a read at exactly this path and prove it is
  /// denied, without hand-typing the string a second time in the test file.
  static String directoryRoot() => 'directory';

  /// `directory/<deviceId>` — the public device-directory entry for
  /// [deviceId] (`E11-T06`, `ADR-0008` option 2). A top-level node, NOT
  /// under `users/$uid` — this is the one path in the whole tree any
  /// authenticated account may read, by exact id only, and the parent
  /// [directoryRoot] must never grant that same read (task §2/§6 Risks —
  /// the entire privacy argument for this node rests on that asymmetry).
  static String directoryEntry(String deviceId) => 'directory/$deviceId';

  /// `directory_private/<deviceId>/ownerUid` — the write-ownership marker
  /// for [deviceId]'s [directoryEntry], deliberately NOT stored alongside
  /// the public entry (`E11-B06` fix). `directory/$deviceId` is readable by
  /// any authenticated account (task §2/§6 Risks above); co-locating
  /// `ownerUid` there let any authenticated account learn whether two
  /// device ids belong to the same Firebase account, a cross-account
  /// correlation `ADR-0008`'s cost analysis never priced in (`E11-B06`
  /// finding 2). This node's own `.read` restricts it to the caller whose
  /// `auth.uid` already equals the stored value; `directory/$deviceId`'s
  /// `.write` rule reads this node (not its own child) to decide whether a
  /// write is from the entry's true owner.
  static String directoryPrivateOwnerUid(String deviceId) =>
      'directory_private/$deviceId/ownerUid';
}
