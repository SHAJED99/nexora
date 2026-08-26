---
name: genesis
description: Epic 00 — the mandatory project foundation: domain analysis, human-decided ADRs (stack/architecture/auth), conventions, design contracts, and a deployable walking skeleton. Use at every project start, and whenever a foundational decision is missing or contested.
---
# Epic 00 — Genesis

No feature epic starts until Epic 00 is human-approved AND its walking skeleton
runs end to end. Everything built later inherits these decisions; a wrong one
here isn't a bug, it's a rewrite.

`epics/E00-genesis/epic.md` IS the checklist — every box maps to a task and to
an ADR.

## Preconditions

In the extended workflow, genesis runs AFTER `skills/project-intake` and
`skills/question-resolution` have produced `docs/intake-report.md` and resolved
every blocking question (gate `blocking_questions_resolved` 🧍), and after the
knowledge map baseline exists (`spec/knowledge-map.yaml`, gate
`knowledge_map_baseline` 🧍). For brownfield projects (an existing codebase),
`skills/codebase-analysis` runs first and genesis consumes
`docs/codebase-baseline.md`, preserving the codebase's existing conventions
rather than inventing new ones.

## The rule that governs this whole epic

**Rule 3: foundational choices are the human's.** Stack, language, framework,
architecture style, datastore, queue, auth strategy. Your job is *not* to pick.
Your job is to make the human's pick well-informed:

> present the real options → honest pros/cons → a comparison matrix →
> **one advisory recommendation with your reasoning** → then STOP.

The ADR stays `status: proposed`, `Decision: ⏳ AWAITING HUMAN`. You wait.
Once chosen: record the decision + consequences, and only then proceed.
Implementation choices *within* an accepted ADR are yours.

An agent that quietly picks the stack has made the most expensive decision in
the project without anyone reviewing it. Don't.

## The sequence

### T00 — Investigate before deciding (opus)
The first genesis task is deep business/domain analysis — **not** architecture.

Read everything in **`docs/business/`** (BRD, SRS, feature list — whatever the
human dropped there) and skim **`docs/UI/`** for what the product actually looks
like. Then produce two things.

**First, `spec/` — the canonical, greppable source of truth:**
`spec/srs.md` (atomic FR/NFR ids) · `spec/feature-list.md` (Module → Feature →
UC) · `spec/glossary.md` · `spec/product-rules.md` (🧍 the human approves) — the
invariants that hold across every feature: authorisation model, audit
obligations, tenancy, money handling.

> Named `product-rules.md`, not `constitution.md`. **"The constitution" in this
> harness means `AGENTS.md`** — the ten always-on rules that govern the *agents*.
> Two files with one name is how a task ends up citing the wrong law.

This conversion is not clerical work. A `.docx` cannot be grepped, diffed,
traced or cited — **rule 1 needs an id to be law**. A task claiming it
"implements the BRD" is unreviewable; `traces_to: [FR-AUTH-003]` is checkable by
a script. Every requirement becomes an atomic, addressable, testable id, or it
isn't a requirement yet.

After this: `spec/` is law, `docs/business/` is history. When they disagree
later, that's an SRS amendment the human approves — never a silent preference
for the docx.

**Second, `docs/domain/`:**
- the entities and their real relationships (the nouns the business actually uses)
- the core flows end to end
- the risks: what's regulated, what's irreversible, what's money, what's PII
- the constraints: scale, latency, integrations, team, deadline

Everything after this is downstream of getting the domain right. Skipping it
produces architecture that's internally consistent and unrelated to the problem.

**Expect to come back with questions**, and expect them to be the uncomfortable
ones — what the BRD implies but never says. That's the job, not a failure to
understand. Every ambiguity surfaced here costs minutes; every one missed costs
an epic. Answers become SRS amendments with ids, so the next agent inherits the
answer instead of re-asking it.

### T01 — The foundational ADRs (rule 3)
One ADR per decision, each with the options matrix and the advisory pick:
`ADR-0001 stack` · `ADR-0002 architecture` · `ADR-0003 methodology` ·
`ADR-0004 third-party services` · `ADR-0005 auth/session` ·
`ADR-0006 authorization` · `ADR-000N …`

🧍 **HUMAN GATE**: each is accepted, amended or rejected by the human. Then
`AGENTS.md` §Project conventions gets a one-line summary + link per decision.

### T02 — Conventions
`docs/conventions.md`: file naming, module boundaries, the **one** error
envelope, pagination style, enum handling, logging. Small decisions that cost
nothing now and cost an epic later, when two modules disagree.

### T03 — Design contracts
Point `design/sources.yaml` at **`docs/UI/`** and run `skills/design-fidelity`
§Ingest: `make design-extract && make design-contract`. Extract the measured
token census into `docs/design-system.md` and the screen→route map into
`docs/routes.md`. Do the gap pass (`design/gaps.md`), tracing each gap to an id
from `spec/` (which T00 just produced from `docs/business/`). 🧍 human approves.

If the design is a Figma file, read `references/ingest.md` §Figma first — an
HTML export measured in a real browser beats an imported node tree, and the
export never ships, it's only measured.

Do this **before** any UI epic is sharded. A design contract that arrives after
three screens are built is an audit, not a gate.

### T04 — Skeleton + maps
The repo structure the ADRs imply. Routes and data-flow maps.

### T05 — Walking skeleton
**One real request, all the way through, deployed.** UI → API → datastore → back,
in CI, in an environment. Flag-gated and ugly is fine. It proves the
architecture exists rather than being described.

### T06 — The harness's own gates
CI green, branch protection on `main`/`development` (PR required, CI green,
linear history), `make hooks` installed, `make design-selftest` green.

## 🧍 The exit gate — the big one (`epic00_exit_review`)

Record it at the top of `epics/E00-genesis/epic.md` — the document that IS
the exit checklist:

```
**Gate:** 🧍 `epic00_exit_review` — ⏳ AWAITING HUMAN
```

Cleared as `✅ cleared by <name> on <YYYY-MM-DD>`. `make validate`
reads it, and once `epics/E01*/` exists the gate must be present and
cleared — finishing genesis by deleting its paperwork does not count.

Nothing shards until the human confirms:
- [ ] domain model accepted
- [ ] every foundational ADR `accepted` (not "proposed", not "assumed")
- [ ] conventions written
- [ ] design contracts extracted + approved; `design/gaps.md` reviewed
- [ ] walking skeleton **seen responding** in an environment
- [ ] CI green; branch protection on; hooks installed; design self-test green
- [ ] `AGENTS.md` §Project conventions filled in with ADR links

Then, and only then: `skills/epic-breakdown`.

## Why this is worth the days it takes
Every hour here is spent once. Every hour skipped here is spent again in every
epic, by every agent, forever — as a re-litigated decision, an inconsistent
pattern, or a rewrite. The harness's whole leverage comes from agents executing
against locked decisions. Nothing is locked yet. That's what this epic is for.

## Where to look next
- What must be settled before you start -> `skills/question-resolution` (no blocking question open) - `skills/knowledge-map` (baseline approved)
- Brownfield: inherit instead of deciding -> `skills/codebase-analysis` section 11 (`status: imposed` ADRs)
- Design contracts produced here -> `skills/design-fidelity`
- What consumes `spec/` next -> `skills/epic-breakdown`
- A foundation that later turns out wrong -> `skills/change-impact` (superseding ADR, never an edit)
