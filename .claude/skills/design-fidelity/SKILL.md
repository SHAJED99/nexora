---
name: design-fidelity
description: Turn any design (Figma, HTML export, React app) into a machine-checkable contract, build against it, and prove the match with `make design-verify`. Use when ingesting a new design, sharding any UI task, building any screen, reviewing any UI PR, or whenever someone says the implementation "doesn't match the design".
---
# Design Fidelity

The harness exists partly because of one failure: an agent is handed a design,
ports it by eye, and ships something that is *approximately* right — a dropped
field here, a rewritten label there, a radius that drifted from 7px to 12px.
Every individual miss is defensible. The sum is a product that isn't the design.

**Why eyeballing cannot work.** In this repo's own self-test, a build with a
missing checkbox, two rewritten strings, a wrong accent colour and a wrong
radius came out **0.04% different by pixel comparison**. A human — or a
vision model — comparing two screenshots would have approved it. Run
`make design-selftest` and watch it happen.

So: don't review fidelity. **Measure it.**

```
design source ──extract──▶ golden (probe.json + page.png)   ← the law, committed
                              │
                              ├──contract──▶ design/screens/<id>.md   ← what agents read
                              │
   built app ──────verify─────┴──▶ report: missing · copy · style · tokens · pixels
                                    hard findings = merge blocked
```

## The four commands

| Command | When | Who |
|---|---|---|
| `make design-extract` | the design arrives or changes | planner |
| `make design-contract` | after extract | planner |
| `make design-verify SCREEN=<id> IMPL=<url>` | before every UI PR, and in review | builder-ui, reviewer |
| `make design-selftest` | when you doubt the gate | anyone |

## Procedure

### 1. Ingest (planner, once per design)
Declare each screen in `design/sources.yaml`: its source, its design path, the
route it binds to, its viewports, its states. Then `make design-extract`.
Per-source detail — Figma, HTML export, React/Storybook — is in
[references/ingest.md](references/ingest.md).

The golden lands in `design/golden/<screen>/<state>@<vp>/`. **Commit it.** From
then on, a diff on the golden IS the design changelog — you can see exactly what
changed and re-verify every affected screen.

### 2. Contract (planner)
`make design-contract` writes `design/screens/<id>.md`: the element checklist,
the verbatim copy, the measured tokens — ~150 lines instead of a 400KB bundle.
Nobody drifts from a document they can actually hold in their head.

🧍 **HUMAN GATE** (`design_contract_approval`): the human skims the contracts and
the gap list before anything is built. This is the cheapest gate in the system —
catching a misread design here costs minutes; catching it after five screens are
built costs an epic.

### 3. Fill the gaps (planner) — the part everyone skips
A design is never a complete product. It shows the happy path at one viewport
and leaves out the empty list, the 403, the validation error, the whole
password-reset journey.

For each gap: name it in `design/gaps.md`, trace it to the **BRD / SRS /
feature-list id** that requires it, and derive it *from the design's own
primitives* — same tokens, same spacing, same component shapes as the contract
measured. Consistency with the design is the standard, not taste.
🧍 Human approves the gap list. See [references/gaps.md](references/gaps.md).

> Derived screens get a contract too — hand-written, marked `source: derived`.
> Once built, extract the built screen as its own golden so it is regression-
> gated from then on like everything else.

### 4. Shard (planner)
Every frontend task carries `design_contract: design/screens/<id>.md` in its
frontmatter. One task ≈ one screen (or one coherent state set). A task without
a contract cannot be a UI task.

### 5. Build (builder-ui)
Read the contract. Use the tokens by name. Copy the strings character for
character. Then run the gate and fix every ❌ before opening a PR.
Iterating against the gate is *the job* — it usually takes 2–4 rounds on a
first screen and converges fast after the primitives exist.

### 6. Verify (reviewer)
Run `make design-verify SCREEN=<id>`. Read `design/reports/<id>/…/report.md`.
- Any **hard** finding → CHANGES. Not negotiable, no discussion.
- **Extra elements** → check each traces to an approved `design/gaps.md` entry.
- **Soft** findings (layout, pixels) → judgement: real drift, or real data?
- A **§Deviation** in the task is only valid with a spec/ADR reason attached.
  "Looked better" is not a reason.

Detail: [references/verify.md](references/verify.md).

## What the gate measures

| Check | Hard? | Catches |
|---|---|---|
| missing elements | ✅ | the dropped field, the forgotten link |
| copy, character for character | ✅ | "Sign in" → "Login", silent rewrites |
| style vs the design's tokens | ✅ | eyeballed colours, drifted radii, wrong weights |
| off-palette tokens | ✅ | invented values that aren't in the design at all |
| layout boxes | ⚠️ | real structural drift — and real data, so: judgement |
| pixels | ⚠️ | the eyeball backstop; never the gate |

Matching is by **role + words + geometry**, never by CSS selector — the
implementation may use whatever tags and class names it likes. It may not lose
the thing. The self-test proves this: a faithful port with entirely different
markup scores 100%.

## Rules
1. **Never hand-edit the generated tables** in a contract. Regenerate.
2. **Never loosen `thresholds.yaml` to make a build pass.** That is the one
   change that silently disables this whole subsystem. It's a 🧍 human call — the `design_threshold_relaxation` gate.
3. **Never delete a design element to satisfy the API.** Keep it, wire it to
   local state, log the gap.
4. **A red gate is never "close enough".** The number is right there.

## Recording the gate
When you write the derived-gap list, put the gate line at the top of
`design/gaps.md`, awaiting a human:

```
**Gate:** 🧍 `design_contract_approval` — ⏳ AWAITING HUMAN
```

The human replaces the whole right-hand side with
`✅ cleared by <name> on <YYYY-MM-DD>`. `make validate` reads that one
line and `make next` refuses to dispatch until it is cleared. Do not add
the line before there is something to approve — a gate on an empty document
is a gate that gets cleared out of habit.

## Where to look next
- Where screen contracts are first produced -> `skills/genesis` (T03)
- Who builds against them -> `agents/builder-ui.md` - `skills/implement`
- A design change after approval -> `skills/change-impact` (design change class)
- Screens the design never covered -> `design/gaps.md` and `references/gaps.md`
- Contracts nothing builds -> `skills/traceability` (an orphan class)
