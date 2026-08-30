# Lessons — frontend

Real findings from **this** project's reviews. Format + ladder: `README.md`.
`skills/retro` writes here; `agent/hooks/lesson-inject.py` injects these
automatically for matching tasks (see `index.yaml`).

## L-frontend-001 — reshaping a production widget's interaction primitive to score better against the design-fidelity gate's own measurement limits breaks real UX/accessibility, and only survives when someone remembers to warn against it every time
- date: 2026-08-30 | source: E06-T10 (real occurrence, CHANGES) — avoided
  proactively at E06-T11 and E06-T12 only because the dispatch prompt for
  each explicitly restated the lesson
- situation: `test/design/flutter_probe_dumper.dart`'s `_isInteractive`
  classification (E06-T01) treats any `GestureDetector`/`InkWell`/button
  widget as one opaque element, swallowing everything nested inside it
  (icons, labels) — a real, documented capability gap in the probe, not a
  bug in the screens it measures. E06-T10's builder discovered this while
  chasing design-gate score and worked around it by switching tap targets
  from `InkWell` to `Listener` — a raw-pointer widget the probe's
  classifier doesn't recognize as interactive, so its children stay
  individually visible to the gate. Gate score improved (17.5% → 49.1%).
  The independent reviewer found two real defects this introduced:
  `Listener` never enters the gesture arena (a scroll/drag starting on a
  row still fired as a tap) and emits zero accessibility semantics (a
  screen-reader user could not open a conversation or use the bottom nav
  at all). Fixed by reverting to `InkWell`; the honest gate score dropped
  back to 21.1% — the correct outcome, since the defect was real and the
  gate limitation was already a tracked, known gap.
- root cause: nothing in `skills/design-fidelity` or `skills/review` states
  the general rule this specific fix embodies — a measurement tool's own
  capability gap is the tool's problem to fix or disclose, never the
  shipped UI's problem to route around. The lesson was correctly generalized
  in the moment (this session explicitly warned E06-T11 and E06-T12's
  builders not to repeat it, and neither did), but that generalization
  lived only in a dispatch prompt's prose, re-typed by hand each time —
  exactly the "remember to X" control this project's own retro skill
  calls the weakest kind. A future task, or a future session with no memory
  of E06-T10's incident, has nothing written down to read.
- fix applied: E06-T10's own fix (Listener → InkWell, two regression
  tests). Systemic fix proposed in this retro: a stated rule in
  `skills/design-fidelity` — a screen's interaction widgets are never
  chosen or changed to influence what the probe/gate can see; a gate
  limitation is recorded as a known-cause finding (as T01/T10/T11/T12 all
  correctly did afterward) or fixed in the probe itself, never worked
  around in the shipped widget tree.
- recurrence: 1 real occurrence + 2 proactively-avoided near-misses in the
  same epic (the near-misses only held because of manual, per-dispatch
  repetition — the control that's supposed to make repetition unnecessary)
- status: promoted-to-rule — `agent/skills/design-fidelity/SKILL.md` (new
  stated rule, "never reshape the widget tree to score better against the
  gate's own measurement limits"), 2026-08-30 via `skills/retro`,
  🧍 `retro_promotions` ⏳ awaiting human. Promoted at a single real
  occurrence because the near-miss count shows the lesson was already
  known and already had to be re-taught twice by hand in one epic — the
  exact signal the ladder exists to catch before a third, unwarned task
  repeats it for real.
