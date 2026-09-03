# E08 · Local Storage & Management — Retro

**Date:** 2026-09-03 | **Epic merged:** `development` @ `854d327` (PR #30,
merge commit, not squash — preserves the 44-commit history) | **Sharded:**
2026-09-02 | **Merged into `epic_08`:** progressively, 2026-09-02 → 2026-09-03

## What shipped

8 sharded tasks (T01–T08; T09 correctly deferred to prospective per rule 2 —
its design contract didn't exist yet) + 7 sweep bugs (B01–B07). Every task
and every bug reviewed by a different model than executed it (rule 5), zero
exceptions this epic (confirmed by `make health` H5 — no E08 entries in
any failing check). Two sharded tasks (`T06`, `T08`) needed a second review
round; every finding in both was real, none was a data-loss bug — the epic's
central safety property (Smart Mode can never delete a message) was
adversarially attacked at both the plan and execution layers and held.

The bug sweep found the epic's single highest-value defect
(`overSizeMb`/Smart Mode silently deleting the wrong 500 items past a
500-row window — S1, root-caused to one `ORDER BY ... LIMIT 500` line with
two unpaged callers) and, while fixing it, surfaced a second, more
dangerous class (SQLite's ~32,766-bind-variable ceiling) that recurred at
four separate call sites before the sweep closed. Final state:
**797/797 tests, `flutter analyze` clean, P1/P2 = 0**, verified locally at
the merge tip, not just claimed by CI.

## What recurred (the richest signal — see `agent/memory/lessons/`)

1. **A list built by unrestricted enumeration, fed whole into one
   `isIn(ids)`/raw-SQL `IN (...)` query, is unbounded — 4 hits in one
   epic.** `E08-B01`/`E08-B02` correctly fixed a 500-row *enumeration* cap
   with paging; three fixes later, `E08-B03` found the *consumer* side of
   that same paged output wasn't bounded, at two call sites; proving that
   fix end-to-end surfaced two more; `E08-B07` then rebuilt the identical
   shape independently, in a different planner, weeks later. New lesson:
   `L-backend-004`. `agent/orchestrator/lessons.py` flags this at
   **recurrence 4, "promote to a HOOK"** — the mechanical signal is real
   (any `.isIn(`/raw `IN (...)` call whose id list isn't provably bounded
   at the call site), and it's this epic's dominant recurring defect
   class. Human decision on promotion tier pending (see below).
2. **`make health`'s H3 hook, promoted after E07's retro, fired correctly
   this time.** E08 merged into `development` before this retro ran — H3
   caught it immediately, unprompted, exactly as designed. Different from
   E07's occurrence: this retro started in the same session, minutes after
   the merge, not an entire session boundary later. `L-process-013`
   updated: hook confirmed live and working, not just proposed.
3. **Rule 9's logging (`runs/`/`metrics.csv`) checked a second time,
   still 0% compliance, project-wide.** Same finding as E07's retro
   (`L-process-015`), unchanged — recurrence now 2, crossing the ladder's
   own "becomes a rule" threshold. Still a human decision (build a shim
   vs. amend the rule's wording), raised again rather than silently
   re-deferred a third time.
4. **Two already-promoted rules held under new pressure, unprompted.**
   `L-frontend-001` (never reshape a widget to score better against the
   design-fidelity probe's own blind spots) held a third and fourth time,
   on a screen (`E08-T08`'s dashboard card) it had never been tested
   against before — the sweep found the same `InkWell`-swallowing
   blindness on **both** dashboard cards, and neither was ever routed
   around. `L-design-002` (a task widening a design-contracted screen's
   data shape must update the shared probe fixture or name a follow-up)
   fired correctly at sharding — `E08-T08` inherited the group-fixture
   obligation and closed it, confirmed real by its own round-2 review
   (probe dump now shows `Groups`/`Family` content it had zero of before).
5. **`L-qa-001`'s falsification discipline (break the fix, watch the
   right test fail, restore) held through an entire epic-level bug sweep**
   at real production-scale stakes (a 40,000-id atomicity rollback probe,
   a 40,600-item shuffled-age adversarial fixture) — not toy fixtures.
   Recorded as reinforcing evidence, not a new occurrence.

## New lessons filed

- `L-backend-004` (recurrence 4, promotion pending) — the SQL
  bind-variable-ceiling class above.
- `L-backend-005` (recurrence 1) — a new table keyed to another table's
  row, with no FK/cascade and no task's contract naming who deletes it
  when the parent is deleted, orphans forever with no reader until a bug
  sweep greps for it (`E08-B03`'s `delivery_states`/`storage_item_stats`
  orphan finding).

## Housekeeping fixed by this retro

- `epics/E08-local-storage/epic.md`'s `status:` field corrected `todo` →
  `done` (the exact stale-field shape `L-process-013` names — `make
  health`'s H3 caught it correctly regardless of the field's value, which
  is the whole point of that hook).
- Noticed, not fixed this retro: `agent/orchestrator/lessons.py`'s
  promotion-candidate report lists `L-process-011` (already
  `promoted-to-rule`, human-approved 2026-09-02) as "not yet promoted" —
  a parser gap in the report script, not a real unpromoted lesson. Left
  for a future infra/process pass; doesn't block anything since the
  underlying rule is genuinely already live in `skills/bug-sweep`.

## Estimate calibration (§5)

No data — `metrics.csv` still doesn't exist for any epic (see `L-process-015`
above). Nothing to calibrate.

## Open Questions — all six answered, none carried forward as blocking

`OQ-E08-1` through `OQ-E08-6` all closed 🟢 by the human at sharding time
(2026-09-02); none reopened by the sweep or this retro. Two answered-but-
unbuilt decisions (`OQ-E08-1(a)`'s Pigeon free-space channel, `OQ-E08-4(a)`'s
E02 Trusted-relationship derivation) now have named prospective owners
(`E08-T10`, `E08-T11`) per `E08-B05`. `OQ-E08-5` (FR-STORE-002/003, no
owner) still correctly waits on the media-path task's creation.

## Carried forward, not left dangling

- `E08-T09` (storage settings screen) — prospective, blocked on
  `E08-T07`'s design contract (already merged, so unblocked whenever
  someone next shards).
- `E08-T10` (Pigeon free-space channel), `E08-T11` (E02 Trusted-relationship
  derivation) — named owners, not yet sharded.
- `OQ-E08-T08-2` (probe-dumper `InkWell` blindness on both dashboard
  cards) — cross-epic, not E08's to fix; `L-frontend-001`'s rule already
  prevents anyone from routing around it in the meantime.
- `manual_policy.dart:152`'s id-sort trap (`E08-B07`'s round-2 finding) —
  harmless today, would silently resurrect the B07 defect if a future
  change reintroduces an early-termination cap on `_planOlderThan`.

## Human decisions — resolved

1. **`L-backend-004` promotion tier → rule + hook.** Rule added to
   `agent/skills/implement/SKILL.md` §6 and `agent/skills/review/SKILL.md`
   §7. Hook built: `agent/orchestrator/health.py` H8 greps `lib/**/*.dart`
   for `.isIn(`/raw SQL `IN (...)` sites with no chunking marker nearby,
   flags WARN (heuristic — a human still judges each finding). First run
   against the real codebase: 1 finding, a true negative
   (`relay_engine.dart:416`, a fixed enum set, not an id list) — left as a
   permanent, correctly-dismissable advisory since H8 is not wired into
   CI or any blocking gate.
2. **`L-process-015` fix → (b), amend the rule.** `AGENTS.md` rule 9,
   `CLAUDE.md`, and `skills/retro` §5 all now state plainly that
   `runs/`/`metrics.csv` logging is `run-claude.sh`-specific and doesn't
   apply to Agent-tool dispatch. Future retros won't re-flag the absence.
3. **Retroactive gate cleanup → approved.** `L-process-006`,
   `L-process-007`, `L-qa-001`, and `L-backend-003`'s extension all marked
   🧍 `retro_promotions` ✅ approved, 2026-09-03.

`make health` re-run after all edits: H3 now passes (this file exists);
the new H8 shows its one expected true-negative warning; the 3 remaining
fails (H4/H5/H7) are all pre-existing E05/E06 legacy, outside E08's scope.
