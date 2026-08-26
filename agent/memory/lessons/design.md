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
- status: lesson (recurrence 2 — candidate for promotion to a rule in
  `agent/skills/design-fidelity/SKILL.md`: "for any grouped/repeated UI
  element, cross-check probe.json's untexted wrapper `generic`s directly —
  don't infer structure from the printed contract table alone. Where a
  wrapper's height/width doesn't match a single row's, check whether it
  spans multiple rows (a group) before assuming a uniform per-row style."
  Awaiting 🧍 `retro_promotions` gate — not applied here, since that edit
  is itself a human-approved gate this session hasn't run `skills/retro` for.)
