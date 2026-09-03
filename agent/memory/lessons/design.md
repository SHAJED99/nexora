# Lessons — design

Real findings from **this** project's reviews. Format + ladder: `README.md`.
`skills/retro` writes here; `agent/hooks/lesson-inject.py` injects these
automatically for matching tasks (see `index.yaml`).

## L-design-001 — probe.json's untexted wrapper `generic`s carry real layout (fills/borders/backdrops), not just the numbered elements
- date: 2026-08-27 | source: E02-T02 (Devices screen review), E02-T03 (Settings screen review)
- situation: Both UI tasks read `design/screens/<id>.md`'s printed "Elements —
  the build checklist" table as the complete element list and built from it.
  E02-T02 dropped a 40×40 tinted circular icon backdrop behind each device
  row (present in `probe.json` as untexted `generic` DIVs, not surfaced in
  the printed table). E02-T03 went further: it correctly found 4 untexted
  wrapper `generic`s (elements 9/16/29/42) and their fill/radius/border, but
  misread them as "a uniform style applied to all 8 rows" instead of
  recognizing they were GROUP containers holding 1/2/2/3 rows each — so it
  built 8 individually-bordered cards where the design has 4 grouped panels.
- root cause: the design-fidelity contract's printed table is generated from
  probe.json but only surfaces elements with visible text/icon roles —
  untexted structural wrappers (fills, borders, radii, group containers)
  don't get their own numbered row, so an agent building from the table
  alone has no prompt to go check `probe.json` directly for wrapper
  geometry, and no habit of treating a wrapper's *size relative to the rows
  inside it* as a grouping signal.
- fix applied: both tasks were caught in independent review (a different
  model than the executor, rule 5) and fixed post-review — E02-T02 added
  the missing backdrop; E02-T03 restructured into 4 `_MenuGroup` containers
  with hairline dividers between rows, sized `48×48` (not `40×40`,
  carried over from the wrong contract) backdrops. No shipped defect.
- recurrence: 2
- status: promoted-to-rule(design-fidelity) — see `agent/skills/design-
  fidelity/SKILL.md` Rules §5, promoted 2026-08-27 via `skills/retro`,
  🧍 `retro_promotions` gate approved by human.

## L-design-002 — the shared design-probe fixture never seeds a group conversation, so the design-fidelity gate has been structurally blind to every group-bearing screen since it was built, and the gap was flagged three times without anyone owning the fix
- date: 2026-09-02 | source: E07 retro — flagged first by `E07-T08`'s own
  reviewer (2026-09-02), again unprompted by `E07-B01`'s reviewer on a
  separate task days later, and named explicitly in `E07-T08`'s own §4 as
  a carried-forward item ("whichever task next owns `design/tools`/`test/
  design/design_probe_test.dart` should seed a group fixture")
- situation: `E07-T08` built the Conversations screen's real "Groups"
  section (closing `GAP-006`) and `E07-B01` fixed a live bug in how a
  group row's tap behaves — both are group-bearing changes to a
  design-contracted screen, and both hit the same 21.1% (12/57) gate
  score, independently confirmed byte-identical before and after each
  diff. Neither task's reviewer treated this as a defect in the shipped
  UI (correctly — see `L-frontend-001`'s 2026-09-02 addendum) — but
  neither could the gate actually see the feature either task built,
  because `test/design/design_probe_test.dart`'s shared fixture seeds
  zero groups. The design-fidelity gate has been rule-2's enforcement
  mechanism for this screen since `GAP-006` first opened, and it has been
  unable to measure this screen's group behavior at all, in three
  separate task reviews, without ever becoming a task of its own.
- root cause: this is the same shape `L-process-008` already named for
  mid-epic carried-forward observations — a correct, dated, attributed
  finding sitting in the right place (a task's §4, an epic tracker) with
  no dispatcher reading it before the *next* task starts. Here the
  carrier is a design gap specifically: `skills/design-fidelity` has no
  step that asks "does the shared probe fixture actually exercise what
  this task is about to build," so a fixture gap discovered by one task's
  reviewer has no mechanism forcing the very next task touching the same
  screen to close it, even when that next task (`E07-B01`) is a two-line
  fix away from being able to.
- fix applied: none yet — both tasks correctly disclosed the limitation
  rather than routing around it, but the fixture itself is still unfixed
  as of this retro. Systemic fix proposed: `skills/design-fidelity` should
  require, at the point a design-contracted screen gains a new displayed
  data shape (a new conversation kind, a new row type), that the shared
  probe fixture is updated in the same task or an explicitly-scoped
  follow-up is opened — not left as prose in a §4 for an indefinite future
  reader.
- recurrence: 3 (the original `GAP-006`/`E07-T08` finding, `E07-B01`'s
  independent re-discovery, and the still-open carried-forward note itself
  counted separately since three different reviewers/readers hit the same
  wall without any of them being positioned to fix it)
- status: promoted-to-rule — `agent/skills/design-fidelity/SKILL.md` (new
  rule: a task widening a design-contracted screen's displayed data shape
  must update the shared probe fixture or open a named follow-up task),
  2026-09-02 via `skills/retro`, 🧍 `retro_promotions` ✅ approved by the
  human, 2026-09-02.

- **2026-09-03 (E08 retro) - the promoted rule fired correctly and closed the fixture gap.** `E08-T08` (dashboard Local Storage card) inherited the fixture-seed obligation at sharding time (re-homed from prospective `E08-T09` since T08 owns `test/design/design_probe_test.dart`), and its round-2 review independently confirmed the seed is genuinely real: the probe dump now contains `Groups`/`Family` content it previously had zero of. The three-reviewer-no-owner gap this lesson named is closed - a fourth reader was positioned to fix it, and did. Not incremented - no new occurrence of the miss.
