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
| `users/$uid/device_enrollment_grants/$newDeviceId` | live | `approvedByDeviceId:String`, `approvedAt:int(ServerValue)` | device-enrollment authorization grant (`FR-RECOVER-001`) | `E12-B02`/`E12-B03` | structural (`.validate` + `$other` deny), own-uid read/write inherited from `users/$uid` — `E12-B02`/`E12-B03` |
| `users/$uid/push/$deviceId` | reserved (no owner) | — | push notification information | ⏳ `OQ-E11-2` | client guard only (no rule yet — reserved node, `E11-T02` §4) |
| `config/version_policy` | reserved (no owner) | — | application version policy | ⏳ `OQ-E11-2` | client guard only (no rule yet — reserved node, `E11-T02` §4) |
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

The seventh `live` row (`device_enrollment_grants/$newDeviceId`) is
`E12-B02`/`E12-B03`'s own fix for a two-part S1 defect the E12 bug sweep
found: an approving device's `verify()` recorded trust locally only
(`E12-B02`, no Firebase write at all) and, even once written, a new
device's `RelationshipSyncService.pull` could never surface it
(`E12-B03`) — `pull` merges every remote relationship state through
`ConflictResolver.resolveTrust` (`FR-MSG-007`, "more restrictive state
wins"), and an enrolling device has no local relationship row, so
`resolveTrust(unknown, allowed)` resolves to `unknown` and the approval
is silently discarded. The human-decided fix (2026-09-06) is a dedicated
node, deliberately NOT under `relationships/`, read directly by the
enrolling device rather than merged through `ConflictResolver` — an
enrollment approval is an authorization GRANT from a trusted device to a
specific new device, not a peer-trust OPINION to reconcile, so
`FR-MSG-007`'s restrictive-wins rule (correct for the general
peer-relationship case) is a category error here. This row does **not**
change `ConflictResolver.resolveTrust`, `FR-MSG-007`, or `pull`'s own
Firebase read seam at all — those stay exactly as they were for ordinary
peer trust. `approvedByDeviceId` is the approving (already-trusted)
device's own id; `approvedAt` is a `ServerValue.timestamp`. Own-uid
read/write is inherited from `users/$uid`'s own rule, same shape as
`relationships/$peerDeviceId` — no narrower `.read`/`.write` is declared
at this node.

`E12-B09` (`FR-RECOVER-001`/`FR-TRUST-007`) closes a gap the reviewer found
once `E12-B02`/`E12-B03` shipped: a grant node written above is otherwise
permanent — nothing ever revoked it. Two independent, best-effort checks now
guard against a stale grant, neither adding a new path or a new writer:
`DevicesController.block()` (the same handler `Deny` uses) now also calls
`FirebaseMetadataService.deleteEnrollmentGrant` for the blocked/denied device
id — a `.remove()` at the exact same `device_enrollment_grants/$newDeviceId`
node, unconditional on whether the id is still tracked as "pending" (by the
time a previously-approved device is blocked, `verify()` has already cleared
that tracking) and a harmless no-op when no grant exists. Separately,
`DeviceEnrollmentController.checkApproval()` also checks
`FirebaseMetadataService.isDeviceRevoked` — a read of the ALREADY-EXISTING
`users/$uid/devices/$deviceId/revocation` child (`E11-T04`, above), reused
as-is — so a device revoked via that unrelated mechanism is never trusted by
a stale grant either, with no new Firebase path or writer needed for that
check. Neither change touches `relationships/*`/`RelationshipSyncService`
or reintroduces `ConflictResolver` on this read path.

The remaining `reserved` rows are declared here as placeholders their
owning task flips to `live` — this is the anti-collision mechanism for
this shared doc, not a promise of behaviour (see
`epics/E11-firebase-sync/epic.md` §Analyze gate, "Contract sanity").

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
  `FirebasePaths.deviceEnrollmentGrant` (`E12-B02`/`E12-B03`). Pure
  functions, no I/O.
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
  (`lib/core/services/relationship_sync_service.dart`, E11-T05),
  `DeviceDirectoryService.publish`
  (`lib/core/services/device_directory_service.dart`, E11-T06) and
  `FirebaseMetadataService.writeEnrollmentGrant`
  (`lib/core/services/firebase_metadata_service.dart`, `E12-B02`) — build
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
