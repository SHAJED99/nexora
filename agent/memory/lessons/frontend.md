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
  🧍 `retro_promotions` ✅ approved by the human, 2026-08-30. Promoted at a single real
  occurrence because the near-miss count shows the lesson was already
  known and already had to be re-taught twice by hand in one epic — the
  exact signal the ladder exists to catch before a third, unwarned task
  repeats it for real.
- **2026-09-02 (E07 retro) — the promoted rule held, twice more, without
  restatement.** `E07-T08` and `E07-B01` both hit the same red gate on the
  Conversations screen (21.1%/12/57, later confirmed byte-identical
  across both diffs) and both correctly disclosed the score as a known
  probe-fixture/`InkWell`-swallowing limitation rather than reshaping any
  widget to improve it — with no per-dispatch prose reminder needed this
  time, because the rule now lives in `skills/design-fidelity` itself.
  Not incremented (no new occurrence of the miss) — recorded because a
  rule holding under real pressure, twice, unprompted, is exactly the
  evidence `skills/retro` §Rules 1 asks retros to capture, not just misses.

- **2026-09-03 (E08 retro) - held a third and fourth time, on a screen the
  rule had never been exercised against before.** `E08-T08`'s dashboard
  Local Storage card hit the identical `InkWell`-swallowing probe blindness
  (filed as `OQ-E08-T08-2` rather than routed around), and the epic-level
  bug sweep independently confirmed it now affects **both** dashboard cards
  (Network Status and Local Storage), reproduced, disclosed, left as an
  owned cross-epic follow-up, never worked around by reshaping either
  widget. Not incremented - this is the rule doing its job on unfamiliar
  ground, which is the harder test than repeating it on the same screen.

- **2026-09-12 (E06-B07) — root-caused down to the exact code path for the
  first time, with a raw dump as evidence, instead of inferred from a
  score delta.** Earlier occurrences (E06-T10, E07-T08/B01, E08-T08)
  disclosed this gap correctly but from symptom evidence (a score number,
  a copy mismatch). `E06-B07` dumped `build/design-probe/chat.json`'s raw
  element list directly and confirmed: `test/design/flutter_probe_dumper.dart`'s
  `_walk` emits exactly one `button`-role element per `_isInteractive`
  widget, and its `Icon` branch only adds a probe element when
  `!insideInteractive` — so `arrow_back`/`more_vert`/`add`/`mic` (bare
  `Icon`s inside `InkWell`/`Material` tap targets in `chat_view.dart`) are
  walked but never emitted, while the golden (DOM-based `probe.mjs`)
  always captures an icon-font glyph as its own nested `<span>` element
  inside the `<button>`. Also found, while investigating: a second,
  narrower and previously-unnamed instance of the general "icon glyph
  goes unseen" pattern — `_iconNames`'s lookup map omits `Icons.check`/
  `Icons.done_all`, so `chat_view.dart`'s own delivery ticks (which are
  NOT swallowed — they're bare `Icon`s outside any interactive wrapper)
  still dump with empty text. Not incremented as a new lesson (same
  underlying "the probe drops something inside/adjacent to a widget it
  treats as opaque" family as the promoted rule) — recorded because this
  is the first occurrence with an exact fix locus, which is what let this
  task file a concretely-scoped follow-up (`E06-B08`) to actually fix the
  dumper, rather than another disclosed-but-unfixed instance. `E06-B08`
  fixes both: emit a nested `Icon` even when `insideInteractive`, and add
  `check`/`done_all` to `_iconNames`.
