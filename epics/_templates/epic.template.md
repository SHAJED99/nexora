---
id: E<NN>
title: <epic title>
status: todo                # todo → in-progress → done → verified
type: feature               # feature | genesis
priority: { moscow: must, wsjf: 0 }   # wsjf = (value + time_criticality + risk) / size, each 1–10
depends_on: []              # other epic ids
traces_to: []               # SRS modules / FR prefixes this epic covers
external_services: []
ui_surface: []              # the surfaces this epic touches (staff | admin | widget | cli)
design_screens: []          # design/screens/<id>.md — required if ui_surface is non-empty
---
# E<NN> · <epic title>

## Business goal
One paragraph: the user/business outcome this delivers.

## User-visible outcome
What a user can do after this epic that they couldn't before. If you can't write
this sentence, it isn't an epic — it's a chore.

## Scope
**In scope**
- ...

**Out of scope**
- ... (deferred to E<YY>)

## Data model
Tables/columns this epic introduces — high level. Tasks carry the migrations.

## API surface
Endpoints this epic owns — high level. Tasks carry the full contracts.

## Screens
Every screen this epic builds, bound to its design contract. Each row becomes a
frontend task's `design_contract:` — and `make validate` fails any frontend task
without one (rule 2).

| Screen | Route | Design contract | Task |
|---|---|---|---|
| <name> | /<route> | `design/screens/<id>.md` | E<NN>-T<MM> |

**Gaps:** journeys this epic needs that the design doesn't show → `design/gaps.md`,
traced to a spec id, derived from existing primitives, 🧍 human-approved before
the task is built.

## Acceptance criteria (epic-level, EARS)
- **EARS-<AREA>-1**: WHEN <trigger>, the system SHALL <behavior>  (FR-..., UC-...)
- **EARS-<AREA>-2**: IF <error>, THEN the system SHALL <response>  (FR-...)

Cross-cutting NFRs (security, perf, availability) bind here as epic-level EARS —
not as a separate "NFR epic", which is how NFRs never get done.

## Tasks
| Task | Title | Layer | Size | Depends on |
|------|-------|-------|------|-----------|
| E<NN>-T01 | <title> | backend | S | — |

## Test strategy
How this epic proves itself: the unit/integration/E2E mix, and where the sweep
should look hardest — the seams between tasks, since every task passed its own
review.

## Risks
| Risk | Mitigation |
|------|-----------|
| <risk> | <mitigation> |

## Open Questions
> Epic-level gaps to resolve BEFORE kickoff. Stable keys for tooling.
> Status: 🟡 open · 🟢 answered · ⚪ deferred

- **OQ-E<NN>-1 — <short title>.** <the question>
  - **Status:** 🟡 open
  - **Answer:** _<empty>_
  - **Answered by:** _<human | agent id> (manual|auto)_
  - **Date:** _<YYYY-MM-DD>_

## Analyze report
<appended by the Analyze gate — skills/task-sharding. Do not fill manually.>

## Retro
→ `retro.md` (written by skills/retro after completion)
