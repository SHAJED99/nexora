# Firebase data-boundary schema

> Written by `E11-T01`. This is the **complete** Realtime Database tree the
> project is allowed to use. Nothing outside this document may be written to
> or read from Firebase (`FR-FB-001`, `NFR-PRIV-001`). If code and this doc
> ever disagree, the code is the current truth and the doc records it
> as-is — the fix is a proposed change routed through the normal task
> process, never a silent edit to either side (task §4).

Project: `nexora-b3a97` · Realtime Database instance:
`nexora-b3a97-default-rtdb`. Every path lives under `users/$uid/…` except
`directory/`, the public device directory `E11-T06` builds (`ADR-0008`,
accepted option 2).

## Tree

| Path | Status | Fields | `FR-FB-001` clause | Owner | Rules enforcement |
|---|---|---|---|---|---|
| `users/$uid/devices/$deviceId` | live | `deviceId:String`, `createdAt:int(ServerValue)`, `lastSeenAt:int(ServerValue)`, `platform:String` | device registry metadata | `E01-T02` | structural (`.validate` + `$other` deny) — `E11-T02` |
| `users/$uid/sync_cursors/$writerDeviceId/$conversationId/$aboutDeviceId` | live | `localDeviceId:String`, `remoteDeviceId:String`, `conversationId:String`, `lastConfirmedSequenceNumber:int`, `updatedAt:int` | synchronization metadata (`NFR-PRIV-001`) | `E05-T04` | structural (`.validate` + `$other` deny) — `E11-T02` |
| `users/$uid/devices/$deviceId/revocation` | live | `revokedAt:int(ServerValue)`, `revokedByDeviceId:String` | revocation information | `E11-T04` | structural (`.validate` + `$other` deny) — `E11-T04` |
| `users/$uid/relationships/$peerDeviceId` | live | `state:String` (one of `trusted`/`allowed`/`unknown`/`blocked`), `updatedAt:int(ServerValue)` | trust metadata, block metadata | `E11-T05` | structural (`.validate` + `$other` deny) — `E11-T05` |
| `users/$uid/push/$deviceId` | reserved (no owner) | — | push notification information | ⏳ `OQ-E11-2` | client guard only (no rule yet — reserved node, `E11-T02` §4) |
| `config/version_policy` | live | `minimumSupportedBuild:int`, `currentBuild:int`, `updateAvailableBuild:int`, `signature:String`, `updatedAt:int` | application version policy | `E14-T01` | structural (`.validate` + `$other` deny), any-authenticated-account read, `.write: false` for every client — `E14-T01` |
| `directory/$deviceId` | live | `identityPublicKey:String` (base64), `prekeyBundle:String` (base64 `PreKeyBundleCodec` v1), `revokedAt:int?` | device public identity information | `E11-T06` (`ADR-0008` accepted, option 2) | structural (`.validate` + `$other` deny), cross-account exact-id read; write requires the caller's `auth.uid` to match `directory_private/$deviceId/ownerUid` — `E11-T06`, fixed by `E11-B06` |
| `directory_private/$deviceId` | live | `ownerUid:String` | write-ownership marker for the corresponding `directory/$deviceId` entry | `E11-T06` (fix: `E11-B06`) | structural (`.validate` + `$other` deny), owner-only read (`auth.uid === ` the stored value), immutable write (first-writer-wins) |

`users/$uid`'s own `$other` child (any subtree not named `devices` or
`sync_cursors`) is also denied structurally (`.validate: false`) —
`E11-T02`, `EARS-FB-5`. The owner-only `.read`/`.write` at `users/$uid`
itself (`auth.uid === $uid`) is `E11-T02`, `EARS-FB-6`, unchanged in shape
from before this task.

The first two `live` rows above are pre-existing (`E01-T02`, `E05-T04`);
`E11-T01` centralised their path strings and allowed-field sets without
changing a single field, path, or the paths' argument order (task §6 Risks).
The third `live` row (`.../revocation`) is new — `E11-T04`'s own deliverable,
a child node under the pre-existing `devices/$deviceId` node rather than a
new top-level path. The fourth `live` row (`relationships/$peerDeviceId`) is
`E11-T05`'s own deliverable — a new top-level-under-`$uid` node, own-account
only (`ADR-0008`'s declined-option-3 boundary): `$peerDeviceId` is always a
remote device id, never a foreign account's uid, and this row does not
change that. The fifth `live` row (`directory/$deviceId`) is `E11-T06`'s
own deliverable and the one deliberate exception to "every path lives
under `users/$uid/…`, owner-only": it is a top-level node, readable by
**any authenticated account, by exact device id only** — never a listing,
never a query — per `ADR-0008` option 2. `identityPublicKey` and
`prekeyBundle` are public-by-construction material (a public key and a
public prekey bundle); `revokedAt` mirrors this device's own local
revocation state (`E11-T04`'s `device_revocations` table, read locally —
not re-derived from the `users/$uid/devices/$deviceId/revocation` row,
which only that device's owning account can read).

The sixth `live` row (`directory_private/$deviceId`) is `E11-B06`'s fix
for a defect `ADR-0008` itself did not anticipate: `ownerUid` was
originally co-located inside `directory/$deviceId`, which is readable by
any authenticated account — so any account holding two device ids could
read both entries' `ownerUid` and learn whether they belong to the same
Firebase account, a cross-account correlation `ADR-0008`'s cost analysis
never priced in. `ownerUid` now lives in its own top-level node, `.read`
restricted to the caller whose `auth.uid` already equals the stored
value (never any other authenticated account), and is immutable after
first write, same first-writer-wins shape as before
(`database.rules.json`'s `.write` expression on this node requires the
caller's `auth.uid` to already match the stored value whenever the node
exists, and to match the value it is writing in every case).
`directory/$deviceId`'s own `.write` rule reads THIS node
(`newData.parent().parent().child('directory_private').child($deviceId)
.child('ownerUid')` — the Realtime Database idiom for reading a sibling
path written in the SAME multi-location update; `root.child(...)` reads
only the pre-write snapshot even inside a multi-location update and was
caught by review, emulator-verified as permanently denying every new
device's first publish, before merge) to decide whether a write to the
public entry is from that entry's true owner — the two nodes are always
written together, as one atomic multi-location update
(`DeviceDirectoryService.writeDirectoryData`), never as two separate
writes. **`E11-B06`'s finding 1** (no cryptographic binding between
`$deviceId` and the identity published under it, so a first writer can
squat any id it learns) is **not** fixed by this row — RTDB security
rules have no hash or signature-verification primitive available to
enforce the human-approved direction (binding `$deviceId` to a derivation
of `identityPublicKey`), which needs either a Cloud Function (a new
dependency, its own rule-3 call) or a change to how `$deviceId` itself is
minted (`ADR-0005`: device ids are generated before any identity key
exists, at `lib/features/login/presentation/login_controller.dart`'s
`generateSecureDeviceId()`, so deriving one from the other means
reordering that bootstrap sequence across `E01`/`E03` — a protocol-level
change, not a rules-file fix, and
squarely `E11-B06`'s own scope fence: "does not fix anything itself...
possibly a protocol-level decision"). **Finding 3** (no unpublish path,
only a `revokedAt` update) is confirmed here as the deliberate, final
design: revoke, don't delete — enforced by the `.write` rule's own
`newData.exists() &&` clause (added at round 3 review after that
property was found to have been silently dropped by finding 2's
refactor; `ADR-0008`'s addendum has the full detail).

The remaining `reserved` rows are declared here as placeholders their
owning task flips to `live` — this is the anti-collision mechanism for
this shared doc, not a promise of behaviour (see
`epics/E11-firebase-sync/epic.md` §Analyze gate, "Contract sanity").

The seventh `live` row (`config/version_policy`) is `E14-T01`'s own
deliverable, claiming `OQ-E11-2`'s reserved node. Like `directory/
$deviceId`, it is a top-level node, NOT under `users/$uid` — but unlike
`directory/$deviceId` (per-device, cross-account-readable by exact id
only), this is one single shared node every authenticated account reads
the same value from: server/ops-published minimum-build policy
(`FR-VER-005`, `FR-VER-008`, `FR-VER-010`), never per-account data.
`.write: false` for every client, no exception — this node is published
by a server/ops process outside this app's own client code (an
Admin-SDK/Cloud Function or console write, out of this task's own build
per its §4), never by anything running on a device. `signature` is
stored as raw, unverified data in this build — signature verification
(`FR-VER-011`) is `E14-T05`'s own task.

## Path registry and field-allowlist code

- Paths: `lib/core/services/firebase_paths.dart` — `FirebasePaths.device`,
  `FirebasePaths.syncCursor`, `FirebasePaths.devices` (the parent
  `users/$uid/devices` node, used to enumerate every device's revocation
  flag in one read), `FirebasePaths.deviceRevocation` (E11-T04),
  `FirebasePaths.relationships` (the parent `users/$uid/relationships`
  node, used to enumerate every peer relationship in one read),
  `FirebasePaths.relationship` (E11-T05), `FirebasePaths.directoryRoot`
  (the parent `directory` node — never passed to a live `.ref(...)` call,
  only used by the rules test to prove a read there is denied),
  `FirebasePaths.directoryEntry` (E11-T06),
  `FirebasePaths.directoryPrivateOwnerUid` (`E11-B06` fix) and
  `FirebasePaths.versionPolicy` (`E14-T01`). Pure functions, no I/O.
- Allowed fields: `lib/core/services/firebase_boundary.dart` —
  `FirebaseBoundary.allowedFields(FirebaseNodeKind)` and
  `FirebaseBoundary.assertAllowedFields(FirebaseNodeKind, Map<String, Object?>)`,
  which throws `FirebaseBoundaryViolation` (naming the offending key(s),
  never their values) before any write reaches `.set()`.
- The five existing wrappers — `FirebaseMetadataService.registerDevice`
  (`lib/core/services/firebase_metadata_service.dart`),
  `SyncCursorService.writeCursorToFirebase`
  (`lib/features/messaging/domain/sync_cursor_service.dart`),
  `DeviceRevocationService.revoke`
  (`lib/core/services/device_revocation_service.dart`, E11-T04),
  `RelationshipSyncService.push`
  (`lib/core/services/relationship_sync_service.dart`, E11-T05) and
  `DeviceDirectoryService.publish`
  (`lib/core/services/device_directory_service.dart`, E11-T06) — build
  their payload, call `assertAllowedFields` **before** entering their
  existing best-effort `try`/`catch`, then call the path-registry function
  for the actual `.ref(...)` call. This ordering matters: a boundary
  violation must propagate as a programming error, not get swallowed and
  logged as "just another Firebase error" (task §6 Risks).

## Forbidden anywhere in the tree

Restated verbatim from `FR-FB-002`: message plaintext · voice recordings ·
call recordings · private keys · session keys · permanent private location
history. No `status: live` or `status: reserved` row above authorizes any of
these, in any node, ever.

## What this schema does not cover

- **Behavioural proof that the Realtime Database server enforces these
  rules** — `E11-T02`'s structural Dart test
  (`test/core/services/firebase_rules_test.dart`) proves the rules FILE says
  the right thing; only the Firebase emulator + `@firebase/rules-unit-testing`
  (`OQ-E11-T02-1`) proves the server actually does it. Still not brought in
  as of `E11-T06` — the last of the two tasks `OQ-E11-T02-1`'s answer named
  as the point to add it — because it is a new dev dependency (🧍 rule 3,
  `new_dependency`) outside this task's own `files:` fence. `E11-T06`
  instead adds a small in-file rules-cascade simulator (walks `.read` from
  root down to a target path exactly as the RTDB server would, rather than
  checking the JSON for an absent key) for the one property that matters
  most here — that `directory` (no child) denies a read while
  `directory/$deviceId` grants one — but this is still not a server-backed
  proof. `OQ-E11-T02-1` carries forward, unresolved, to whichever task next
  touches a rules-bearing node.
- **Deployment** — `database.rules.json` is not published by any task;
  `firebase deploy --only database` is a human step at the merge gate
  (`E11-T02` §4).
- **The reserved rows' actual fields, rules, or code** — each is built (or
  left permanently unowned, in the push/version-policy case) by its own
  named task. This document only reserves the slot.
