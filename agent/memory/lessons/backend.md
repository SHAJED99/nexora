# Lessons — backend

Real findings from **this** project's reviews. Format + ladder: `README.md`.
`skills/retro` writes here; `agent/hooks/lesson-inject.py` injects these
automatically for matching tasks (see `index.yaml`).

## L-backend-001 — Drift `Companion` partial updates: `Value(null)` writes NULL, `Value.absent()` leaves the column alone
- date: 2026-08-27 | source: E01-T01 review (Opus)
- situation: `AppDatabase.markSignedIn(id, {String? accountUid})` wrote
  `accountUid: Value(accountUid)` unconditionally. When called without an
  `accountUid`, this wrote an explicit `NULL` instead of leaving an existing
  value alone — a future re-sign-in caller would have silently wiped the
  account link on that row.
- root cause: nothing in `docs/conventions.md`'s Drift/migration guidance
  calls out the `Value(x)` vs `Value.absent()` distinction for optional
  Companion fields — an agent reasonably reads "pass null when you don't
  have one" as "write null", which is correct for a full insert but wrong
  for a partial update.
- fix applied: `accountUid: accountUid == null ? const Value.absent() : Value(accountUid)`.
  Caught in independent review (rule 5), not by a test — no test exercised
  a second `markSignedIn` call without `accountUid` on an already-linked row.
- recurrence: 1
- status: lesson

## L-backend-002 — an unbounded `await` on a best-effort external write can hang the primary flow it's supposed to never block
- date: 2026-08-27 | source: E01-T02 review (Opus)
- situation: `FirebaseMetadataService.registerDevice` correctly caught and
  logged any *throw* from the Realtime Database write, satisfying the
  task's "fire-and-forget, must never block sign-in" contract for the
  failure case — but `DatabaseReference.set()`'s Future only resolves on
  server ack, so a write that's queued offline (not failed, just pending)
  never completes at all. `SignInUseCase` awaited it directly, so a
  degraded connection at exactly the wrong moment could hang the entire
  sign-in flow indefinitely, with no test covering that shape.
- root cause: "fire-and-forget" was implemented as "catch errors", not
  "bound the wait" — the task's own EARS criteria (`docs/conventions.md`
  and the task file) named the throw case explicitly but never named the
  hang case, so there was nothing prompting a test for a write seam that
  simply never completes.
- fix applied: added a `timeout` (default 10s) inside the service, caught
  by the same error handler as any other failure. Added a regression test
  using a write seam that returns a `Completer` that's never completed.
- recurrence: 1
- status: lesson

> Deliberately empty, like every area here. A lesson is evidence from *this*
> codebase, and its recurrence count is what decides which trap gets automated
> next — seeding it with another project's findings would put fiction in that
> count and spend context on traps this code may never have.
>
> Generic craft that belongs in every project already lives in the skills
> (`skills/implement`, `skills/task-sharding/references/api-contracts.md`).
> This file is for what only your own reviews can teach.
>
> Why the harness itself is built this way: `docs/ARCHITECTURE.md`.

> Deliberately empty, like every area here. A lesson is evidence from *this*
> codebase, and its recurrence count is what decides which trap gets automated
> next — seeding it with another project's findings would put fiction in that
> count and spend context on traps this code may never have.
>
> Generic craft that belongs in every project already lives in the skills
> (`skills/implement`, `skills/task-sharding/references/api-contracts.md`).
> This file is for what only your own reviews can teach.
>
> Why the harness itself is built this way: `docs/ARCHITECTURE.md`.
