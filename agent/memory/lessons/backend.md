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
  5. E05-T04 (`sync_cursor_service.dart:125-140`, found in round-1 review by
     reviewer-opus): `recordLocalProgress` read the cursor via `cursorFor`,
     `await`ed, then wrote via a separate `insertOnConflictUpdate` — a
     read-then-write with a suspension point in the middle, so two
     overlapping calls both read the stale value and the later write lost
     the higher one (`Future.wait([record(...,10), record(...,4)])` left the
     cursor at **4**). This is the same family — "the cursor is the
     authority for this property" — but a **different failure mode from the
     four above**: not a sibling reader that never learned about the
     counter, but the counter's *own writer* updating it non-atomically.
     The rule promoted after recurrence 4 (`implement/SKILL.md` §6) told the
     builder to audit other **readers**; it said nothing about the writer's
     own atomicity, so it did not fire here. Fixed (`1637be9`) by collapsing
     guard+write into one `insert(onConflict: DoUpdate(..., where: old.seq <
     new.seq))` statement — atomic in SQL, independent of drift's
     transaction semantics — plus
     `test_EARS_MSG_5_concurrent_calls_do_not_regress_cursor`, confirmed red
     on the prior code before the fix.
- root cause: introducing a counter/cursor to make an invariant durable
  changes the *meaning* of "available" for every other piece of code that
  reads the same table, but nothing prompts an implementer (or a task's own
  `files:` fence) to enumerate those other readers. Each fix correctly
  solved the one call site named in its bug report and left the sibling
  call sites exactly as wrong as before — a grep for other readers of the
  same table at fix time would have caught #3 and #4 immediately.
  For instance #5 the root cause is one layer earlier: nothing prompts the
  implementer to ask whether the *write* that maintains the counter is a
  single atomic statement. "Read, decide, write" reads as obviously correct
  code and is silently wrong the moment two callers overlap — and a
  single-threaded happy-path test passes either way, so the suite gives no
  signal.
- fix applied: each instance was caught in independent review (rule 5) and
  fixed same-day; no shipped defect. No mechanical hook exists yet for this
  — the pattern is semantic ("this table now has an authoritative counter;
  audit every SELECT against it"), not syntactically greppable in general.
  2026-08-29 (E05 retro): the §6 rule was **extended** rather than
  re-promoted — it now also covers the writer's own atomicity and requires a
  concurrency falsification test for any counter/cursor write, because
  instance #5 proves the reader-only wording did not reach the shape that
  actually recurred.
- recurrence: 5
- status: promoted-to-rule — see `agent/skills/implement/SKILL.md`
  ("Introducing a durable counter" rule), promoted 2026-08-27 via
  `skills/retro`, 🧍 `retro_promotions` gate approved by human on
  2026-08-27 (as drafted); **rule extended 2026-08-29** (E05 retro,
  writer-side atomicity + required concurrency falsification test),
  🧍 `retro_promotions` ✅ approved by the human, 2026-09-03 (E08 retro —
  retroactive cleanup: the extension had been live and operating
  successfully since 2026-08-29, gate formally cleared at the same time
  as three other long-pending promotions).
- promotion assessment (E05 retro, evidence-based — did the rule help?):
  the rule did **not** prevent authorship (the builder wrote the race), and
  it did not fire in self-review because its wording is about readers. What
  it did buy: the *class* was recognised instantly at review — the reviewer
  reached for a concurrency probe unprompted on both T03 and T04, source-
  traced drift's locking on T03 to prove that path safe, and demonstrated
  T04's lost update with a concrete two-call scenario before writing the
  finding. One round, one statement, one regression test. Verdict: the rule
  is earning its context cost at review altitude, not at authoring altitude
  — so the correction is to make it name the shape that keeps being written
  (extend the rule), not to escalate to a hook. A hook would have to detect
  "a read and a write of the same durable counter separated by a suspension
  point", which is a real dataflow analysis, not a grep; noted as a
  recommendation for the human, not built.

## L-backend-004 — a list built by unrestricted enumeration (paging until a kind is exhausted) and then fed whole into one `isIn(ids)`/raw-SQL `IN (...)` query is unbounded, and SQLite's ~32,766-bind-variable ceiling is not a theoretical limit — it recurred at four separate call sites in one epic
- date: 2026-09-03 | source: E08 bug sweep — `E08-B03` round 1 (found at
  `_accessStats`), the same fix's own round-1→round-2 work (found at
  `deleteMessageItems` and `_splitByDeliveryState`, both discovered only
  because proving the round-1 fix end-to-end required exercising the real
  call order), and `E08-B07` round 1 (found as a new caller — `_planOlderThan`
  — building the identical unbounded shape a second time, independently)
- situation: `E08-B01`/`E08-B02` deliberately fixed a 500-row *enumeration*
  cap by adding paging — correct, and the right fix for what those two bugs
  were about. But paging removes the bound on the *enumeration*, not on
  whatever the enumerated ids are used for next. `E08-B03`'s `_accessStats`
  and `_deleteBookkeeping` each took that now-unbounded id list and passed it
  straight into `itemId.isIn(ids)` — one bind variable per id — so a device
  with enough history throws `SqliteException(1): too many SQL variables`,
  not on a rare edge case but as soon as a single kind's aged/tracked set
  passes ~32,766 rows. Tracing the actual call order to prove the fix safe
  end-to-end surfaced **two more** unchunked sites in the same delete path
  (`deleteMessageItems`, `_splitByDeliveryState`) that would have blocked the
  fix from ever being reachable at the scale it exists to help. Weeks later
  in the same sweep, `E08-B07`'s fix removed `_planOlderThan`'s cap the same
  way `E08-B01` had removed `_planOverSize`'s — and produced the identical
  failure mode a fourth time, this time escalated to **worse than the bug it
  fixed** (a permanent, silent, forever-repeating failure of an entire
  retention mode, versus the original bug's self-correcting under-deletion).
- root cause: "add paging so the enumeration isn't capped at 500" and "chunk
  the query that consumes the enumerated ids" are two different fixes, and
  nothing connects them — a planner fixing the *producer* side of an
  unbounded-list defect has no prompt to check whether anything downstream
  assumed the old cap as an implicit safety bound. `_planOverSize`'s own fix
  (`E08-B01`) and `_allItemsOfKind`'s fix (`E08-B02`) both still hold this
  same unbounded-accumulation shape in memory (harmless today only because
  nothing yet queries their output with a raw `IN (...)`), so the class is
  reachable from **three** planners, not the two actually hit.
- fix applied: all four call sites in `RetentionExecutor` (`_accessStats`,
  `_deleteBookkeeping`, `deleteMessageItems`, `_splitByDeliveryState`) chunk
  id lists into ≤500-id batches (`_chunked`/`_deleteChunkSize`), merging
  results/applying deletes chunk-by-chunk. Every fix independently falsified
  (reverted, confirmed the exact `too many SQL variables` signature at
  ≥32,766-40,600-id scale, restored). No third-caller fix was needed for
  `E08-B07` once `E08-B03`'s chunking existed *downstream* of it — the
  correct architectural fix was chunking at the query boundary the executor
  owns, not at each planner that can produce an unbounded list.
- recurrence: 4 (three sites found by tracing one fix's real call order, one
  independent rediscovery by a different task weeks later)
- status: promoted-to-rule+hook — human chose rule + hook at E08's retro,
  2026-09-03. Rule: `agent/skills/implement/SKILL.md` §6 self-review
  checklist (new "feeding an enumerated id list" item) and
  `agent/skills/review/SKILL.md` §7 (new "Unbounded id lists" checklist
  item). Hook: `agent/orchestrator/health.py` H8 — greps `lib/**/*.dart` for
  `.isIn(`/raw SQL `IN (...)` call sites with no chunking marker in the
  surrounding 6 lines, flags as WARN (heuristic, not proof — a human still
  judges each finding; one true-negative flagged in the real codebase at
  first run, `relay_engine.dart:416`, a small fixed enum set not an id
  list). 🧍 `retro_promotions` ✅ approved by the human, 2026-09-03.

## L-backend-005 — a new table keyed to another table's row, with no foreign key/cascade and no task's contract naming who deletes it when the parent is deleted, orphans forever and nobody notices until a bug sweep greps for it
- date: 2026-09-03 | source: E08 bug sweep (`E08-B03`)
- situation: `delivery_states` (E05) and `storage_item_stats` (E08-T03) both
  key off a message id. `E08-T06` built the app's only deletion path
  (`RetentionExecutor.deleteMessageItems`) against `messages` alone — correct
  and in-fence for T06's own contract, which owns `messages` and nothing
  else. Neither table declares a foreign key or cascade, and a repo-wide grep
  found zero deletes against either table anywhere in `lib/` before this bug
  was filed. The rows survive their message forever; the epic's own
  `_accessStats()` then materializes the growing orphan-laden table every
  pass. No task's `files:` fence or §4 named this join as anyone's
  responsibility — it fell through the seam between the task that writes
  each side-table (E05, E08-T03) and the task that eventually deletes the
  row they key off of (E08-T06), because none of the three needed to read
  each other's contract to satisfy their own.
- root cause: `skills/task-sharding`'s obligation-ownership check (§0/its
  analyze-report step) greps for *cross-task prose references* between
  sharded tasks, but a table that a later task's deletion path never
  mentions at all isn't a reference gap it can catch — it's a *missing*
  reference. Nothing in the sharding brief asks "does any existing table key
  off this task's rows with no cascade, and if so, who deletes it when a row
  here is removed?" at the point a task's own deletion contract is written.
- fix applied: `RetentionExecutor.apply`'s existing per-group transaction
  extended to delete matching `delivery_states`/`storage_item_stats` rows
  alongside the `messages` delete it belongs to (`E08-B03`). A real FK
  cascade was presented as an alternative and correctly deferred to the
  🧍 `db_schema_migration` gate (rule 3) rather than taken unilaterally.
- recurrence: 1
- status: lesson

## L-backend-006 — a live Drift `.watch()` stream subscribed inside a composition root's construction (e.g. `MessagingStack.create()`) hangs `flutter_test`'s `pumpAndSettle()` in ANY widget test that constructs that composition root — confirmed even with a no-op callback, and confirmed that cancelling the subscription in the composition root's own `dispose()` does not help
- date: 2026-09-04 | source: E09-B08 (reactive location-privacy-sweep
  trigger, attempted then reverted)
- situation: `E09-B08`'s fix direction was implemented exactly as
  specified — a table-wide `RelationshipRepository.watchAnyChange()`
  (`.select(table).watch()`), subscribed inside `MessagingStack.create()`
  to re-run a privacy sweep reactively. Both of the fix's own regression
  tests passed. Running the FULL suite afterward revealed the fix hung
  four unrelated widget tests (`chat_view_test.dart`,
  `conversations_view_test.dart`, `conversations_groups_test.dart`,
  `dashboard_view_test.dart` — each to the runner's 10-minute cap on
  `tester.pumpAndSettle()`), because each of those tests constructs a
  real `MessagingStack` via GetX bindings. Reduced the subscription's
  callback to a no-op `(_) {}` and reproduced the identical hang,
  ruling out the fix's own callback logic as the cause. Also tried
  cancelling the subscription explicitly in `MessagingStack.dispose()`
  (rather than relying on the database closing alone) — did not help,
  because the hang occurs INSIDE the test body's own `pumpAndSettle()`
  call, before `dispose()`/`tearDown` is ever reached.
- root cause: not a project-code gap in the traditional sense — a
  genuine, project-specific interaction between Drift's reactive query
  machinery and `flutter_test`'s pump-until-idle detection that this
  project had not previously exercised (every existing `.watch()` stream
  before this fix was consumed by a *narrower*-scoped subscriber, never
  held open unconditionally for a whole composition root's lifetime from
  inside `create()` itself). Nothing in `skills/implement` or
  `skills/review` currently prompts "does this new stream subscription
  get exercised by any widget test that builds this composition root,
  and does `pumpAndSettle()` actually settle with it live?" before a
  reactive-trigger fix is considered done.
- fix applied: the fix was reverted rather than shipped (a P3, bounded,
  workaround-able bug does not justify risking an unbounded number of
  present and future widget test hangs). No project-code fix exists yet
  — this needs either a different reactive-trigger mechanism that
  doesn't hold a live Drift `.watch()` open across a composition root's
  lifetime, or deeper Drift/`flutter_test` internals knowledge this
  session did not have. Recorded so the next attempt starts from "this
  exact shape is known to hang `pumpAndSettle()`," not from zero.
- addendum (2026-09-24, on landing this lesson): **the root cause above is
  narrower than the one finally established.** This lesson was written
  2026-09-04, after the first implementation attempt. A second attempt, in a
  separate session, bisected it further and `E09-B08`'s own §Resolution
  (2026-09-07) records the broader finding: **any unawaited real query against
  this codebase's `NativeDatabase.memory()`-backed `AppDatabase`, fired
  synchronously before `pumpWidget`/`pumpAndSettle` in a widget test, hangs
  `pumpAndSettle` — regardless of what triggers it or what it queries.** It is
  not specific to Drift's `.watch()` machinery and not specific to holding a
  subscription open, so the title's framing above should be read as the
  symptom first seen, not the boundary of the hazard. `E09-B08` was closed
  **won't-fix** on 2026-09-07 with both attempts fully reverted; `grep -rn
  "watchAnyChange" lib/` returns nothing today, so "no project-code fix
  exists yet" still holds. Read `OQ-E09-B08-1` for the three-variant
  bisection before a third attempt — it rules out two plausible guesses
  (subscription lifetime, unawaited-Future-in-general) that would otherwise
  cost another cycle to re-discover.
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
