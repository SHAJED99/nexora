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
  /// trust/block relationship entries live under.
  ///
  /// UNUSED since `E12-B11`/`IMP-002`: `FR-TRUST-007` is descoped and its
  /// only reader (`RelationshipSyncService.pull`, E11-T05) is deleted. Kept
  /// only because the node and its security rule (`EARS-FB-16`) still
  /// exist; retiring those is a separate operational decision.
  static String relationships(String uid) => 'users/$uid/relationships';

  /// `users/<uid>/relationships/<peerDeviceId>` — this account's own
  /// trust/block state for [peerDeviceId] (E11-T05). `$peerDeviceId` is the
  /// remote device id this relationship is about, never a foreign account's
  /// uid.
  ///
  /// UNUSED since `E12-B11`/`IMP-002`: `FR-TRUST-007` is descoped and
  /// `RelationshipSyncService` is deleted, so nothing reads or writes this
  /// path. Kept only because the node and its security rule (`EARS-FB-16`)
  /// still exist; retiring those is a separate operational decision.
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

  /// `config/version_policy` — `E14-T01`, claiming `OQ-E11-2`'s reserved
  /// node (`docs/firebase-schema.md`). A top-level node, NOT under
  /// `users/$uid` — this is server/ops-published policy shared by every
  /// account, not per-account data, the same reasoning as [directoryRoot]/
  /// [directoryEntry] being siblings of `users` rather than nested under a
  /// uid. `.write: false` for every client (task §2) — no client code, this
  /// build included, ever writes this node; see `E14-T01`'s own §4 for who
  /// actually publishes it.
  static String versionPolicy() => 'config/version_policy';

  /// `.info/connected` — Firebase Realtime Database's own built-in special
  /// path (not part of this app's schema tree; there is no corresponding
  /// entry in `database.rules.json`, and it needs none — the SDK serves it
  /// directly, the same way it does for every RTDB client). Its value is
  /// `true`/`false` and toggles automatically as the client's own socket to
  /// the Realtime Database server connects/disconnects — reusing this
  /// (`E14-B06`) rather than adding a new connectivity dependency
  /// (`connectivity_plus` or similar) is deliberate: `FR-VER-008`'s
  /// "reconnect" is reconnection to the exact source `VersionPolicyService`
  /// reads from, and this path is Firebase's own native signal for exactly
  /// that, already available via the `firebase_database` package this app
  /// already depends on.
  static String infoConnected() => '.info/connected';

  /// `users/<uid>/device_enrollment_grants/<newDeviceId>` — `E12-B02`/
  /// `E12-B03`'s dedicated enrollment-approval channel, deliberately
  /// separate from [relationship]/[relationships]. The since-deleted
  /// `RelationshipSyncService.pull` merged every remote relationship state
  /// through
  /// `ConflictResolver.resolveTrust` (`FR-MSG-007`, "more restrictive
  /// state wins"), which is correct for reconciling two devices'
  /// independent OPINIONS about a peer but a category error for an
  /// enrollment approval -- an authorization GRANT from a trusted device
  /// to a specific new device, not an opinion to reconcile (`E12-B03`'s
  /// human decision, 2026-09-06: a dedicated node, read directly, never
  /// merged through `ConflictResolver`). `$newDeviceId` is the enrolling
  /// device's own id -- the node this account's OTHER (already-trusted)
  /// device writes to once it approves that enrollment.
  static String deviceEnrollmentGrant(String uid, String newDeviceId) =>
      'users/$uid/device_enrollment_grants/$newDeviceId';
}
