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

| Path | Status | Fields | `FR-FB-001` clause | Owner |
|---|---|---|---|---|
| `users/$uid/devices/$deviceId` | live | `deviceId:String`, `createdAt:int(ServerValue)`, `lastSeenAt:int(ServerValue)`, `platform:String` | device registry metadata | `E01-T02` |
| `users/$uid/sync_cursors/$writerDeviceId/$conversationId/$aboutDeviceId` | live | `localDeviceId:String`, `remoteDeviceId:String`, `conversationId:String`, `lastConfirmedSequenceNumber:int`, `updatedAt:int` | synchronization metadata (`NFR-PRIV-001`) | `E05-T04` |
| `users/$uid/devices/$deviceId/revocation` | reserved | — declared by `E11-T04` | revocation information | `E11-T04` |
| `users/$uid/relationships/$peerDeviceId` | reserved | — declared by `E11-T05` | trust metadata, block metadata | `E11-T05` |
| `users/$uid/push/$deviceId` | reserved (no owner) | — | push notification information | ⏳ `OQ-E11-2` |
| `config/version_policy` | reserved (no owner) | — | application version policy | ⏳ `OQ-E11-2` |
| `directory/$deviceId` | reserved | — declared by `E11-T06` | device public identity information | `E11-T06` (`ADR-0008` accepted, option 2) |

Both `live` rows above are pre-existing (`E01-T02`, `E05-T04`); this task
centralised their path strings and allowed-field sets without changing a
single field, path, or the paths' argument order (task §6 Risks). The
`reserved` rows are declared here as placeholders their owning task flips to
`live` — this is the anti-collision mechanism for this shared doc, not a
promise of behaviour (see `epics/E11-firebase-sync/epic.md` §Analyze gate,
"Contract sanity").

## Path registry and field-allowlist code

- Paths: `lib/core/services/firebase_paths.dart` — `FirebasePaths.device`,
  `FirebasePaths.syncCursor`. Pure functions, no I/O.
- Allowed fields: `lib/core/services/firebase_boundary.dart` —
  `FirebaseBoundary.allowedFields(FirebaseNodeKind)` and
  `FirebaseBoundary.assertAllowedFields(FirebaseNodeKind, Map<String, Object?>)`,
  which throws `FirebaseBoundaryViolation` (naming the offending key(s),
  never their values) before any write reaches `.set()`.
- Both existing wrappers — `FirebaseMetadataService.registerDevice`
  (`lib/core/services/firebase_metadata_service.dart`) and
  `SyncCursorService.writeCursorToFirebase`
  (`lib/features/messaging/domain/sync_cursor_service.dart`) — build their
  payload, call `assertAllowedFields` **before** entering their existing
  best-effort `try`/`catch`, then call the path-registry function for the
  actual `.ref(...)` call. This ordering matters: a boundary violation must
  propagate as a programming error, not get swallowed and logged as "just
  another Firebase error" (task §6 Risks).

## Forbidden anywhere in the tree

Restated verbatim from `FR-FB-002`: message plaintext · voice recordings ·
call recordings · private keys · session keys · permanent private location
history. No `status: live` or `status: reserved` row above authorizes any of
these, in any node, ever.

## What this schema does not cover

- **Security rules** (`.validate`/`.read`/`.write` enforcement of this
  table) — `E11-T02`, deliberately separate so the schema is agreed before
  rules are written against it.
- **The reserved rows' actual fields, rules, or code** — each is built (or
  left permanently unowned, in the push/version-policy case) by its own
  named task. This document only reserves the slot.
