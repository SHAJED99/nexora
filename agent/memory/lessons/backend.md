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

## L-backend-003 — when a counter becomes the authority for a property of a table, every existing reader of that table must be re-audited, not just the writer that introduced the counter
- date: 2026-08-27 | source: E03-T02 review → E03-B01 (found) → E03-B01's own
  review (recurred within the fix) → E03-B02 (recurred again) → E03-B02's
  review (recurred a fourth time inside the fix's own diff)
- situation: the same invariant — "never hand out an id/prekey already
  issued" — broke four times across one epic, each time because a *new*
  piece of code derived the answer from live table rows instead of
  consulting the counter that was supposed to be authoritative for it:
  1. E03-T02: `IdentityService`'s prekey-id allocator used
     `max(existingIds) + 1` — correct until the pool drained to empty, then
     restarted at 1, reissuing ids already handed to peers (E03-B01).
  2. E03-B01's own fix, reviewed same-day: the new counter's wrap-around
     modulus used the library's advertised `Medium.MAX_VALUE` instead of
     its real `(MAX_VALUE - 1)` arithmetic — a second, narrower instance of
     "trusted the wrong source of truth for what's actually valid," caught
     only because the reviewer independently checked the library source
     rather than the task's own sketch.
  3. E03-B02 (found in the epic's end-of-epic bug sweep, after B01 already
     shipped): `getLocalPreKeyBundle()` selected `oneTimeRows.first` — an
     unordered, unfiltered read of the same table B01 had just given a
     counter to. B01 fixed *allocation* (which ids exist); nothing fixed
     *issuance* (which id gets handed out next) — a different reader of
     the same table, never re-audited against the new counter.
  4. E03-B02's own fix, reviewed same-day: `replenishOneTimePreKeys()`
     still gated on raw live-row count, not *issuable* row count — after
     the issuance cursor existed, a device with 20 issued-but-unconsumed
     bundles had 20 live rows, reported a healthy pool, and would never
     replenish again. A third reader of the same table, still not
     re-audited, found inside the very fix meant to close this class.
- root cause: introducing a counter/cursor to make an invariant durable
  changes the *meaning* of "available" for every other piece of code that
  reads the same table, but nothing prompts an implementer (or a task's own
  `files:` fence) to enumerate those other readers. Each fix correctly
  solved the one call site named in its bug report and left the sibling
  call sites exactly as wrong as before — a grep for other readers of the
  same table at fix time would have caught #3 and #4 immediately.
- fix applied: each instance was caught in independent review (rule 5) and
  fixed same-day; no shipped defect. No mechanical hook exists yet for this
  — the pattern is semantic ("this table now has an authoritative counter;
  audit every SELECT against it"), not syntactically greppable in general.
- recurrence: 4
- status: promoted-to-rule — see `agent/skills/implement/SKILL.md`
  ("Introducing a durable counter" rule), promoted 2026-08-27 via
  `skills/retro`, 🧍 `retro_promotions` gate approved by human on
  2026-08-27 (as drafted).

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
