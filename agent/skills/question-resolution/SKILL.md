---
name: question-resolution
description: Collect, deduplicate, classify, batch and record every question the project raises — blocking questions stop work, optional ones become tracked assumptions. Use whenever unknowns, ambiguities, conflicts or unsafe assumptions exist — after intake, during genesis, at epic breakdown, or mid-flight when a task hits a spec gap.
---
# Question Resolution

One log, one lifecycle, one gate. Questions scattered across chat, task files
and heads are questions that get answered twice or never. Everything lands in
`spec/questions.md` (template: `templates/question-log.template.md`).

## The filter that makes this skill worth having
**Every question costs human attention; ask only what changes an outcome.**
A question whose answer doesn't change a decision, an estimate, or a design is
not a question — it becomes a documented assumption (A-nnn) or gets dropped.
An agent that asks forty questions has outsourced its thinking; an agent that
asks none has done the thinking the human should have seen.

## Priorities (shared definition — binding)
| Priority | Meaning |
|---|---|
| **blocking** | implementation STOPS until a human answers. No workaround, no "reasonable default". |
| **important** | may affect architecture; must be answered before the affected epic shards. |
| **optional** | a documented assumption A-nnn is allowed; question goes ⚪ with the assumption noted. |

## Question lifecycle
```
proposed ─▶ asked ─▶ 🟢 answered
                 ├─▶ ⚪ assumed (A-nnn recorded, risk_if_wrong noted)
                 └─▶ ⚪ deferred (explicitly parked, revisit trigger named)

assumption invalidated later ─▶ question reopened 🟡 + skills/change-impact
```

## Procedure

### 1. Collect candidates
From intake's unknowns, from `OQ-` entries in epic/task files, from
`design/gaps.md` (GAP-nnn), from codebase-analysis's unclear-intent list.
Sweep them all — a question stuck in a task file blocks one agent silently.

### 2. Deduplicate and filter
Merge questions that share an answer. Apply the filter above ruthlessly.
For each survivor, be able to say what changes if the answer is X versus Y —
if you can't, it fails the filter.

### 3. Classify
- **Area** → id `Q-<AREA>-nnn`, AREA ∈ {PROD, BIZ, UX, FUNC, TECH, ARCH, SEC,
  DATA, INT, DEPLOY, NFR}.
- **Priority** → blocking / important / optional per the table. When unsure
  between blocking and important, ask: can genesis or the current task proceed
  correctly without the answer? No → blocking.

### 4. Batch and ask
Group by area, **≤10 questions per round** (matches the orchestrator's
interrupt budget — a 30-question dump gets skimmed, not answered). Present
each in the ADR options style: the question, the options considered, honest
trade-offs, **a recommended default where one exists**. A question with a
recommendation takes the human ten seconds; a bare question takes ten minutes.

### 5. Record everything
Every question in `spec/questions.md`: id, status 🟡/🟢/⚪, **the answer
verbatim** (not your paraphrase — paraphrase is where meaning leaks),
`answered_by` (human | agent-derived), date, and `fed_into` — the artifact the
answer became (ADR id, SRS id, GAP id, A-nnn). An answer that fed nothing is
an answer that changed nothing; see the filter.

### 6. Optional → assumptions
Each ⚪-assumed question produces an A-nnn entry: statement, made_because,
**risk_if_wrong** (the invalidation consequence, concretely — "we rebuild the
billing module" beats "some rework"), status. Add it to
`spec/knowledge-map.yaml` `assumptions[]`.

### 7. 🧍 HUMAN GATE (`blocking_questions_resolved`)
Genesis and implementation **may not proceed past a 🟡 blocking question**.
This is rule 1 wearing a different hat: spec silent → STOP. An agent that
proceeds "provisionally" past a blocking question has answered it itself.

### 8. Answers flow onward
- Every 🟢/⚪ resolution updates `spec/knowledge-map.yaml` (flip the
  `open_questions[]` pointer, add facts/assumptions).
- An answer that changes an **accepted** artifact (SRS id, accepted ADR,
  approved design contract) does not get applied directly — it routes through
  `skills/change-impact`. The system never silently overwrites a prior
  decision.

## Smell tests
- The same question appears in round 3 that was ⚪-deferred in round 1 with no
  new trigger? The deferral was a dodge — escalate it.
- An `agent-derived` answer to a blocking question? Contradiction in terms —
  blocking means human.
- `fed_into` empty on a 🟢 answer? Either wire it in or admit the question
  failed the filter.

## Where to look next
- Questions come from → `skills/project-intake` · `skills/codebase-analysis` ·
  task `## Open Questions`
- Answers land in → `skills/knowledge-map`
- Answers that change accepted artifacts → `skills/change-impact`
- Blocking questions during a task → `skills/handoff` (§blocked)
