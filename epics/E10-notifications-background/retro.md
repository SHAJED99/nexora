# E10 · Notifications & Background Operation — Retro

**Date:** 2026-09-04 | **Sharded:** 2026-09-04 | **Build-complete:**
2026-09-04 | **Merged into `epic_10`:** progressively, 2026-09-04 |
**epic_10 → `development`:** not yet — PR #75 open, awaiting the human
merge gate.

## What shipped

10 sharded tasks (T01–T10: native notification boundary, preferences,
policy/dispatcher, per-source notifications, Android foreground service
per `ADR-0007` option 1, power-state signals, adaptive background policy)
+ an original bug sweep (8 findings, all resolved) + a second, retroactive
rule-5 re-review pass on `T01`/`T02` (2 more findings, both fixed). Final
state: **938/938 tests**, `flutter build apk --debug` compiles clean,
verified locally at the merge tip. `flutter analyze` shows one
pre-existing, unrelated issue confirmed present before this session's
work (`test/core/calls/call_migration_controller_test.dart:177`,
`annotate_overrides`).

## What recurred (the richest signal — see `agent/memory/lessons/`)

1. **The second occurrence, in three epics this session, of the exact
   same rule-5 pattern.** `E10-T01`/`T02` were both reviewed by
   `claude-sonnet-5` under "independent session." Genuinely cross-model
   re-review of `T01` found two real S2 defects (`E10-B09`/`E10-B10`);
   `T02` re-reviewed clean. Reinforces `L-process-016` (now recurrence 3
   across E09/E10/E11 — this session found the same routing miss on the
   first two tasks of every epic it touched).
2. **A notification's Dart-side event contract can be fully, correctly
   built and never fed by anything native — with the gap invisible to
   the original review because nothing in the task's own tests exercised
   the missing half.** `E10-B09`: `NotificationService.notificationTapped`
   was a complete, correctly-wired `Stream<int>` from day one; nothing in
   `android/` ever called the native method that would feed it. The task
   file itself scoped tap *routing* out (deferred to `OQ-E10-1`) but
   explicitly kept tap *delivery* in scope — a same-model review reading
   both the Dart facade and the open-question deferral together could
   plausibly conclude "the open question covers this," missing that
   delivery and routing are two different halves of the same feature.
3. **A documented `Future<bool>` contract ("never throws, never hangs")
   is not free — it has to be built, and a same-model review can miss
   that it wasn't.** `E10-B10`: `ensureReady()`'s own doc comment
   promised exactly the contract it didn't have. Two independent failure
   modes (a host-channel error, a permission result that never arrives)
   each bypassed the promised behavior in a different way, and the
   second is reachable via a lifecycle interaction (`E10-B05`'s own
   "no Activity, revived engine" shape) that a task-scoped review of
   `T01` alone would have had no reason to think about — it only became
   visible once `E10-B05` (found and fixed earlier this session) put
   that lifecycle shape on record. Recurrence of `L-qa-002`'s underlying
   theme (a green test proves less than the property it's named for):
   here the "test-strength" gap wasn't in an existing test at all, but
   in a documented contract with *no* test ever written for its failure
   modes.
4. **A test-only constructor parameter (`readyTimeout`) is the practical
   way to make a "hangs forever" bug testable without actually waiting
   forever.** Same technique as `E09-B08`'s (unsuccessful, reverted)
   attempt and `E11-B04`'s (`@visibleForTesting` seam) — three different
   shapes of "the property under test needs an escape hatch the
   production contract doesn't naturally offer," three different correct
   solutions depending on what the escape hatch needs to expose.

## New lessons filed

None new this retro — both findings reinforce lessons already filed
during `E09`'s retro this session (`L-process-016`, `L-qa-002`).
Recurrence counts updated in those files' own text.

## Housekeeping fixed by this retro

- `epics/E10-notifications-background/epic.md`'s `status:` field
  corrected `todo` → `done`, with the same "priority-stamped P1/P2=0,
  pending human stamp on the new bugs" caveat `E11`'s retro this session
  also recorded.
- `E10-T01`/`E10-T02`'s `reviewed_by`/`reviewed_at`/`review_outcome`
  restamped to the genuine cross-model pass, with the superseded
  same-model review named explicitly.

## Estimate calibration (§5)

No data — `metrics.csv` still doesn't exist for any epic (`L-process-015`,
resolved at E08's retro as a rule amendment).

## Open Questions — carried forward, not left dangling

- **`OQ-E10-1`** (what each notification category's tap should actually
  open) remains entirely unresolved by `E10-B09` — that bug closed only
  the *delivery* half (the event now genuinely reaches Dart), not the
  routing decision, which stays a human/design call.
- **`E10-B06`/`E10-B07`** (six unwired `dispose()` methods assessed
  inert; five EARS criteria on unfalsifiable tests) remain tracking-only,
  unchanged by this retro.

## Human decisions — resolved this session

1. **`bug_priorities` stamps on `E10-B09`/`E10-B10`** — both P2, under
   the decision authority already delegated to the agent for this
   session (both bugs were already fixed and reviewed APPROVE; the
   stamp is a record-keeping close, not an open gate).
2. **`AGENTS.md` rule 3 amended (2026-09-05, direct human instruction):**
   epic→`development` merges are now delegated to the agent, once P1/P2
   = 0 and rule 5's cross-model review gate has genuinely passed.
   `development`→`main` remains entirely human-only.

## Human decisions — still open

1. **`retro_promotions` gate** for the `L-process-016` recurrence bump
   (now 3, past the ladder's own "2nd time → becomes a rule" threshold a
   second time).

The `epic_10` → `development` merge itself (PR #75) is no longer a human
decision — see above.

`make health` re-run after this retro's edits: H3 now passes for E10
(this file exists); H4/H5/H7's failures are unchanged E05/E06/E08
legacy, outside E10's scope, exactly as E08's/E09's/E11's own retros
already recorded.
