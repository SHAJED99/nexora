# E01 · Identity & Access — Retro

**Date:** 2026-08-27 · **Epic status:** done (merged to `main`)

## What shipped
Real Google Sign-In (Firebase Auth), secure device identity
(`Random.secure()`), and a best-effort Firebase Realtime Database
device-metadata write — pivoted from Firestore mid-task after Firestore
turned out to need the Blaze billing plan, which the human declined.

## What recurred
Nothing recurred *within* E01 — each review found a distinct issue. Two of
them set up patterns that mattered again later:

- **E01-T01 review (Opus):** `markSignedIn`'s `Value(accountUid)` wrote an
  explicit `NULL` when no uid was passed, instead of leaving the column
  alone — would have clobbered an existing account link on a future
  re-sign-in call. Also: the v1→v2 schema migration had no test exercising
  `onUpgrade` (every test used `AppDatabase.forTesting`, which always takes
  `onCreate`). Both fixed; see `agent/memory/lessons/backend.md`
  L-backend-001 and the migration-test pattern (folded into general
  practice, not a standalone lesson since E02-T01 built its migration test
  correctly the first time once explicitly told to).
- **E01-T02 review (Opus):** `registerDevice` correctly caught write
  *failures* but not a write that queues offline and never resolves —
  `SignInUseCase` awaited it directly, so a degraded connection could hang
  sign-in indefinitely. Fixed with a bounded timeout. See
  `agent/memory/lessons/backend.md` L-backend-002.

## What got promoted
Nothing reached recurrence 2 within E01 alone — both backend lessons above
are freshly written (recurrence 1) as part of this retro pass, not
previously promoted.

## What the numbers said
No `metrics.csv` — same gap as E00, not yet fixed mechanically.

## Open follow-ups carried forward
- `.firebaserc`/Firebase project (`nexora-b3a97`) is under a third Google
  account (`shajedurrahmanpanna.storage3@gmail.com`), distinct from the
  session's primary account — worth confirming long-term ownership.
- Release-signing SHA-1/SHA-256 fingerprints (separate from the debug
  keystore used for all testing so far) still need adding before any
  signed/release build.
- `E01-T02`'s two non-blocking review notes (createdAt/lastSeenAt always
  equal since both use `ServerValue.timestamp` on every write; no
  `.validate` rule structurally enforcing the FR-FB-002 field boundary)
  carried to E11 (Firebase Metadata Sync) as refinement candidates.
