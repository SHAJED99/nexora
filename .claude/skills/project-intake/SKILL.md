---
name: project-intake
description: Classify and inventory whatever the project starts from — PRD, SRS, design, existing code, raw idea, or any mix — extract the known facts, route the unknowns, and recommend the path into the lifecycle. Use at first contact with any new project input — an idea, a PRD, an SRS, a design, an existing codebase, or any mix — before genesis and before any implementation.
---
# Project Intake

The first skill that runs on any project. Its job is to answer one question
honestly: **what do we actually know, and what are we pretending to know?**

One binding rule: **intake never writes `spec/` — that is genesis's job.**
Intake produces `docs/intake-report.md` + questions, nothing else. An intake
that starts writing FR ids has skipped two gates and a whole skill.

## Procedure

### 1. Inventory the input
List every artifact that exists: files in `docs/business/`, files in
`docs/UI/`, the repo itself (source, manifests, migrations), and anything the
human pasted into the prompt. Every item gets a row in the report's inventory
table — format, size, apparent intent. Nothing is "obvious enough to skip".

### 2. Detect the mode(s)
Mixes are normal — D+C (code plus a redesign), A+D (PRD plus a legacy repo),
C+E (mockups plus a verbal idea). Detect ALL that apply:

| Mode | Signals |
|---|---|
| **A — PRD** | prose goals/personas/features, "should/will" language, no atomic requirement ids, roadmap-shaped |
| **B — SRS** | numbered FR/NFR-style requirements, "shall" language, acceptance-criteria structure |
| **C — Design** | HTML exports, Figma links, screenshots, component libraries, screen flows in `docs/UI/` |
| **D — Existing code** | source tree, package manifests, migrations, CI config, a git history |
| **E — Raw idea** | a paragraph or a conversation; no documents at all |

### 3. Extract known facts
Walk the knowledge categories and pull only what the input **states** —
vision · users · requirements · features · journeys · business rules · UI/UX ·
data · APIs · integrations · architecture · constraints · NFRs. Each fact
carries its source. Inference is allowed only when marked as inference; a fact
you inferred is a candidate assumption, not a fact.

### 4. Detect the unknowns
Unknowns, ambiguities, contradictions (PRD says X, design shows Y), and unsafe
assumptions. **Route every one to `skills/question-resolution` — never ask
inline.** Inline questions get answered in chat and lost; routed questions get
ids, statuses, and a paper trail.

### 5. Write the report
`docs/intake-report.md` from `templates/intake-report.template.md`: detected
mode(s) with the signals seen, input inventory, facts per category, per-mode
readiness assessment, question counts by priority, and the recommended next
skill.

### 6. 🧍 HUMAN GATE (`intake_mode_confirmation`)
The human confirms the detected mode(s) and the recommended path. A
misclassified project runs the wrong lifecycle from step one — thirty seconds
here versus days later.

### 7. Route
- Mode **D** present → `skills/codebase-analysis` FIRST, before anything else.
- Modes **A/B/C/E** only → `skills/question-resolution` → `skills/knowledge-map`
  baseline → `skills/genesis`.

## Per-mode parsing

### A — PRD
Extract the product intent: goals, personas, features, success metrics.
Then detect what a PRD structurally lacks — SRS-level precision: edge cases,
error behavior, data rules, permissions. Each lack is a question, not a guess.
**Ready** = intent is coherent, features enumerable, and blocking gaps are in
the question log.

### B — SRS
Extract FR/NFR candidates (genesis will mint the ids). Hunt ambiguity
("fast", "user-friendly", "appropriate"), conflicts between requirements, and
missing business context — an SRS often says *what* without *why*, and the
*why* is what settles later disputes. **Ready** = requirements are atomic-izable
and every ambiguity is logged.

### C — Design
Inventory screens, components, navigation flows; infer the journeys the
screens imply. Then list what designs never show: error states, loading
states, empty states, responsive behavior, permissions. **Visual design does
not define business logic** — a button labeled "Approve" tells you nothing
about who may press it or what approval means. Every inferred rule is a
question. **Ready** = the screen inventory is complete and the missing-state
list is in the question log.

### D — Existing code
Do NOT analyze it here. Note its existence, size, and apparent stack in the
inventory, then defer entirely to `skills/codebase-analysis` — a shallow read
of a codebase produces confident wrong facts, which are worse than none.

### E — Raw idea
Guided discovery: problem · users · goals · core features · constraints.
**Ask, don't invent** — the temptation is to speculate a full product from a
paragraph. Questions over speculative specification, every time: a wrong guess
written down reads like a decision to the next agent. **Ready** = the human has
answered enough blocking questions that a one-page product sketch is factual,
not fictional.

## Where to look next
- Unknowns found here → `skills/question-resolution`
- Mode D → `skills/codebase-analysis`
- After questions + map baseline → `skills/genesis`
- The index everything feeds → `skills/knowledge-map`
