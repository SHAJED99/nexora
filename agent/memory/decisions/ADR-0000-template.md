# ADR-NNNN — <decision title>
- status: proposed            # proposed → (human chooses) → accepted | imposed | superseded-by: ADR-NNNN
- date: <YYYY-MM-DD> | proposed_by: <agent role> | decided_by: ⏳ <human> (pending)
- traces_to: [SRS-x.y, E00-Txx, docs/domain/...]

> DECISION OWNERSHIP: the agent fills Context, Options, the comparison matrix
> and an advisory Recommendation, then STOPS. The **Decision** line stays
> `⏳ AWAITING HUMAN` until the human picks. The agent must not self-finalize
> a foundational choice or set status to `accepted`.

## Context
<the forces: requirements (FR ids), NFR numbers, constraints, team skills,
client infra, what the domain model in docs/domain/ implies>

## Options considered
For each: what it is, and honest pros / cons for THIS product (not generic).
1. **<Option A>** — pros: … · cons: …
2. **<Option B>** — pros: … · cons: …
3. **<Option C>** — pros: … · cons: …

## Comparison matrix
| Criterion (weight) | Option A | Option B | Option C |
|---|---|---|---|
| Fit to SRS NFRs (e.g. ≥1000 concurrent agents) | … | … | … |
| Team familiarity / hiring in Dhaka market | … | … | … |
| Ecosystem & libraries for the needed integrations | … | … | … |
| Operational cost & complexity | … | … | … |
| Speed to walking skeleton | … | … | … |
| Long-term maintainability | … | … | … |

## Agent recommendation (advisory — NOT the decision)
<the agent's suggested option + one-paragraph why, grounded in the matrix.
Explicitly: "Final call is yours.">

## Decision
⏳ AWAITING HUMAN — chosen option: __________  (the human fills this)

## Consequences
<filled AFTER the human chooses: what becomes easier, what becomes harder,
the follow-up tasks this choice creates>
