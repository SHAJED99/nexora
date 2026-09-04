# Firebase data-boundary schema

> Written by `E11-T01`. This is the **complete** Realtime Database tree the
> project is allowed to use. Nothing outside this document may be written to
> or read from Firebase (`FR-FB-001`, `NFR-PRIV-001`). If code and this doc
> ever disagree, the code is the current truth and the doc records it
> as-is — the fix is a proposed change routed through the normal task
> process, never a silent edit to either side (task §4).

Project: `nexora-b3a97` · Realtime Database instance:
`nexora-b3a97-default-rtdb`. Every path lives under `users/$uid/…` except
`directory/`, reserved for `E11-T06` (`ADR-0008`, accepted option 2).

## Tree

| Path | Status | Fields | `FR-FB-001` clause | Owner | Rules enforcement |
|---|---|---|---|---|---|
| `users/$uid/devices/$deviceId` | live | `deviceId:String`, `createdAt:int(ServerValue)`, `lastSeenAt:int(ServerValue)`, `platform:String` | device registry metadata | `E01-T02` | structural (`.validate` + `$other` deny) — `E11-T02` |
| `users/$uid/sync_cursors/$writerDeviceId/$conversationId/$aboutDeviceId` | live | `localDeviceId:String`, `remoteDeviceId:String`, `conversationId:String`, `lastConfirmedSequenceNumber:int`, `updatedAt:int` | synchronization metadata (`NFR-PRIV-001`) | `E05-T04` | structural (`.validate` + `$other` deny) — `E11-T02` |
| `users/$uid/devices/$deviceId/revocation` | live | `revokedAt:int(ServerValue)`, `revokedByDeviceId:String` | revocation information | `E11-T04` | structural (`.validate` + `$other` deny) — `E11-T04` |
| `users/$uid/relationships/$peerDeviceId` | live | `state:String` (one of `trusted`/`allowed`/`unknown`/`blocked`), `updatedAt:int(ServerValue)` | trust metadata, block metadata | `E11-T05` | structural (`.validate` + `$other` deny) — `E11-T05` |
| `users/$uid/push/$deviceId` | reserved (no owner) | — | push notification information | ⏳ `OQ-E11-2` | client guard only (no rule yet — reserved node, `E11-T02` §4) |
| `config/version_policy` | reserved (no owner) | — | application version policy | ⏳ `OQ-E11-2` | client guard only (no rule yet — reserved node, `E11-T02` §4) |
| `directory/$deviceId` | reserved | — declared by `E11-T06` | device public identity information | `E11-T06` (`ADR-0008` accepted, option 2) | client guard only (no rule yet — reserved node, `E11-T02` §4) |

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
change that. The remaining `reserved` rows are declared here as
placeholders their owning task flips to `live` — this is the anti-collision
mechanism for this shared doc, not a promise of behaviour (see
`epics/E11-firebase-sync/epic.md` §Analyze gate, "Contract sanity").

## Path registry and field-allowlist code

- Paths: `lib/core/services/firebase_paths.dart` — `FirebasePaths.device`,
  `FirebasePaths.syncCursor`, `FirebasePaths.devices` (the parent
  `users/$uid/devices` node, used to enumerate every device's revocation
  flag in one read), `FirebasePaths.deviceRevocation` (E11-T04),
  `FirebasePaths.relationships` (the parent `users/$uid/relationships`
  node, used to enumerate every peer relationship in one read) and
  `FirebasePaths.relationship` (E11-T05). Pure functions, no I/O.
- Allowed fields: `lib/core/services/firebase_boundary.dart` —
  `FirebaseBoundary.allowedFields(FirebaseNodeKind)` and
  `FirebaseBoundary.assertAllowedFields(FirebaseNodeKind, Map<String, Object?>)`,
  which throws `FirebaseBoundaryViolation` (naming the offending key(s),
  never their values) before any write reaches `.set()`.
- The four existing wrappers — `FirebaseMetadataService.registerDevice`
  (`lib/core/services/firebase_metadata_service.dart`),
  `SyncCursorService.writeCursorToFirebase`
  (`lib/features/messaging/domain/sync_cursor_service.dart`),
  `DeviceRevocationService.revoke`
  (`lib/core/services/device_revocation_service.dart`, E11-T04) and
  `RelationshipSyncService.push`
  (`lib/core/services/relationship_sync_service.dart`, E11-T05) — build
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
  (`OQ-E11-T02-1`, deferred to land with `E11-T05`/`E11-T06`) proves the
  server actually does it.
- **Deployment** — `database.rules.json` is not published by any task;
  `firebase deploy --only database` is a human step at the merge gate
  (`E11-T02` §4).
- **The reserved rows' actual fields, rules, or code** — each is built (or
  left permanently unowned, in the push/version-policy case) by its own
  named task. This document only reserves the slot.
