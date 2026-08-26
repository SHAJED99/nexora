# Reading the gate

```bash
make design-verify                                   # every screen
make design-verify SCREEN=login                      # one
make design-verify SCREEN=login IMPL=http://localhost:3000
```

Exit 0 = pass · 1 = drift · 2 = the gate itself broke (no golden, app not up).
Report: `design/reports/<screen>/<state>@<vp>/{report.md,report.json,built.png,diff.png}`.

`report.json` is machine-readable — paste `report.md` into the PR, attach
`diff.png`. A verdict with the report attached ends the argument.

## The findings, and what each one means

### ❌ Missing — in the design, not in the build
The design shows it, the build doesn't. Almost always a real defect: the field
dropped because the API wasn't ready, the link forgotten, the empty state never
built.

Fix it. If it truly cannot exist yet, it is still not allowed to vanish: keep
the element, wire it to local state, log it in the task's §Deviations **and** as
an Open Question. A user seeing a field is a promise the design made.

### ❌ Copy mismatches
- `changed` — the matched element's words differ ("Sign in" → "Login")
- `case/spacing` — same words, different case or whitespace
- `absent` — the string exists nowhere in the build

Copy is not decoration. It's the product's voice, it's what QA scripts assert,
and it's what users read. Character for character, always. If the design's copy
is *wrong*, the spec wins (rule 2) — fix the design, log the gap; don't
freelance in the implementation.

### ❌ Style deltas
A matched element's colour / font-size / weight / radius / border drifted past
`tolerance`. This is the eyeballing detector: `#059669` → `#10b981` is
invisible to a human and obvious here.

Fix: use the token, don't retype the value.

### ❌ Off-palette tokens
The build used a value that appears **nowhere** in the design. Classic causes:
a component library's defaults leaking through, a hand-typed hex, a Tailwind
class one shade off. The report names the nearest design value — usually that's
the one you meant.

### ⚠️ Layout deltas
Boxes moved more than `tolerance.layout_box_px`. Judgement: real drift (wrong
padding, wrong grid), or real data (a longer ticket title)? Persistent
same-direction deltas across many elements = a wrong spacing token upstream.

### ⚠️ Pixels
The backstop, never the gate — see the 0.04% story in the SKILL. Use `diff.png`
to *see* what moved once the structural findings are clean. High pixel % with
zero hard findings usually means fonts or data, not drift.

### ℹ️ Extra — in the build, not in the design
Often legitimate: a spec-required field the design forgot. Legitimate means
**logged in `design/gaps.md` and human-approved**. Unlogged extras are how a
design slowly becomes something else.

## Iterating (builder-ui)

Run the gate early and often — it's ~5s per screen. Order that converges
fastest:

1. **Structure first.** Get every element to exist. Match% climbs.
2. **Copy second.** Paste from the contract's verbatim list. Never retype.
3. **Tokens third.** Fix off-palette values at the source (your token file),
   not per-component — one fix, many screens.
4. **Style deltas fourth.** They mostly vanish once tokens are right.
5. **Layout last.** Padding and gaps, against `diff.png`.

A first screen takes a few rounds. The fifth screen on the same primitives is
usually green first try — which is the entire return on this subsystem.

## When the gate is wrong

It happens, and pretending otherwise gets it disabled. Legitimate causes:
- **Dynamic data** → `ignore_text` regex, narrowly.
- **A genuinely unstable element** (chart, avatar, map) → `mask` selector,
  narrowly. Masking is invisible to the reader of a green report; keep it small
  enough that you'd defend it out loud.
- **The design changed** → re-extract the golden and commit it. The golden diff
  is the changelog. Never patch the build to match a stale golden.
- **The design was wrong** (spec conflict) → spec wins, fix the design source,
  re-extract, log the gap.

What is never a legitimate fix: raising a threshold in `thresholds.yaml` to get
green. That's a 🧍 human decision, it applies to every screen forever, and it is
how this subsystem quietly stops existing.
