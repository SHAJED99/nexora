# design/ — the design is law, and the law is checkable

This directory answers one question mechanically: **does the build match the
design?** Not "does a reviewer think it looks right" — that question has a known
failure rate. Run `make design-selftest` to watch a build with a missing
checkbox, two rewritten strings, a wrong accent and a wrong radius come out
**0.04% different by pixel comparison**. Any human would have approved it.

```
design source ──extract──▶ golden/  (probe.json + page.png)     ← the law, committed
                              │
                              ├──contract──▶ screens/<id>.md    ← what agents read
                              │
      built app ────verify────┴──▶ reports/  missing · copy · style · tokens · pixels
                                             hard findings = merge blocked
```

## Layout

| Path | What | Committed? |
|---|---|---|
| `sources.yaml` | where designs come from; screen → route bindings | ✅ |
| `thresholds.yaml` | what "matches" means, numerically | ✅ |
| `golden/<screen>/<state>@<vp>/` | `probe.json` (machine truth) + `page.png` | ✅ **the law** |
| `screens/<id>.md` | the contract agents build against | ✅ |
| `gaps.md` | journeys the design omits, derived from the spec | ✅ |
| `reports/` | last verify run | ❌ regenerated |
| `tools/` | extract · contract · verify · figma-import · selftest | ✅ |

The golden is committed on purpose: a diff on it **is** the design changelog.
When a designer changes a shade, you see exactly which screens are affected and
re-verify them.

## Quickstart

```bash
npm install                                    # playwright, pixelmatch, pngjs, yaml
make design-selftest                           # prove the gate works (~10s)

# 1. point it at your design
$EDITOR design/sources.yaml
make design-extract                            # → golden/
make design-contract                           # → screens/<id>.md   🧍 human reviews

# 2. build the screen against screens/<id>.md, then
make design-verify SCREEN=login IMPL=http://localhost:3000
```

No browser download needed — Playwright uses system Chrome if the bundled
Chromium isn't installed.

## What's hard, what's soft, and why

**Hard (blocks the merge):** missing elements · copy character-for-character ·
styles vs the design's own tokens · off-palette values.
**Soft (a warning the reviewer judges):** layout boxes · pixels.

The split is the whole design of this thing. An implementation controls
structure, copy and tokens completely — those are what "follow the design"
means, and there's no excuse for drift. Pixels are different: real apps render
real data in real fonts, so a *perfect* build still moves pixels. Gate on pixels
and agents learn to game screenshots. Gate on structure and they learn to build
the design.

Elements match by **role + words + geometry**, never by CSS selector. The build
may use whatever tags and class names it likes; it may not lose the thing. The
self-test proves it: a faithful port with entirely different markup scores 100%.

## The rules that keep this honest

1. **Never loosen `thresholds.yaml` to make a build pass.** That silently
   disables the whole subsystem. It's a 🧍 human decision (`harness.yaml:
   human_gates`) and it applies to every screen forever.
2. **Never hand-edit the generated tables in a contract.** Regenerate.
   Hand-written sections live below the marker and survive regeneration.
3. **A design element that can't be wired yet still gets built** — wire it to
   local state and log the gap. Don't delete the promise.
4. **Anything the design doesn't cover** → `gaps.md`, traced to a spec id,
   derived from existing primitives, 🧍 approved, then built and extracted as
   its own golden.

Depth: `agent/skills/design-fidelity/SKILL.md` (+ `references/ingest.md`,
`verify.md`, `gaps.md`).
