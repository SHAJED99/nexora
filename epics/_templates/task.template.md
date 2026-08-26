---
# ── identity & routing ──────────────────────────────────────────────
id: E<NN>-T<MM>                  # immutable. Bugs: E<NN>-B<MM>
epic: E<NN>
type: feature                    # feature | bug | genesis | chore
title: <short imperative title>
layer: backend                   # backend | frontend | cli | infra | docs | cross-cutting
size: S                          # XS ~2h | S ~1d | M ~2-3d | L ~1wk (split L!)
status: todo                     # todo|in-progress|review-requested|changes-requested|done|verified · side: blocked|frozen
owner_agent: builder             # builder | builder-ui | planner
model: sonnet                    # opus | sonnet | haiku
preferred_agent: any             # claude-code | codex | opencode | any (hint, not a lock)
token_estimate: { tier: M, range: "50k-150k" }   # S 5–15k · M 50–150k · L 150–500k
priority: { moscow: must, p: P2 }                # P1 preempts (bugs mainly)
depends_on: []                   # task ids; cross-epic ok: E02-T04
blocks: []
traces_to: [FR-XXXX-000, UC-0.0.0]   # rule 1 — at least one id, or it isn't a task
required_context: []             # what the agent's brief must carry: srs ids, ADR ids,
                                 # design contract, dep task ids. `skills/agent-briefing`
                                 # attaches exactly this — nothing "just in case"
design_contract: n/a             # REQUIRED for layer: frontend — design/screens/<id>.md
                                 # `make validate` enforces this (rule 2)
files:                           # rule 6 — the diff may not exceed this list
  create: []
  update: []
  delete: []
# ── audit trail (agents stamp these) ────────────────────────────────
started_at:
completed_at:
executed_by:
reviewed_at:
reviewed_by:                     # MUST differ from executed_by (rule 5)
review_outcome:
# ── bug-only (delete for features) ──────────────────────────────────
# severity: S2                   # S1 crash/security · S2 major · S3 workaround · S4 cosmetic
# found_in: E<NN> sweep | human-report
# repro: ["step 1", "step 2"]
# expected: <per FR/UC id>
# actual: <observed>
---
# <id> · <Title>

> Nine sections, all of them load-bearing. v1 had eighteen and half of every
> task said "None." — which taught agents to skim the template, and then to skim
> the sections that mattered (L-process-003). If a section doesn't apply, the
> shard is wrong or the section shouldn't exist.

## 1. Goal
One sentence: what this achieves for the product or the user when it's done.

## 2. Business logic
The rules. What must be true, what's forbidden, the edge cases. Cite the SRS FR
and UC ids explicitly ("implements FR-AUTH-003, UC-1.1.3"). Name the constitution
constraints that bite here (RBAC at the API layer, audit on lifecycle writes).

## 3. What this task does
- Concrete deliverable
- Concrete deliverable

## 4. What this task does NOT do  ← the scope fence
- The explicit non-goal (deferred to E<NN>-T<YY>)
- The tempting-but-wrong move *this task invites*: "don't add a cache",
  "don't touch login", "don't fix the naming next door"

> Never leave this empty. An agent with no fence fills the space with its own
> judgement, and its judgement is not the plan.

## 5. Contract
Everything the implementer may not invent (rule 6). Delete the sub-sections that
genuinely don't apply to this task — but if you're deleting most of them, ask
whether this is really one task.

### API
| Method | Path | Auth | Request | Response | Status |
|--------|------|------|---------|----------|--------|
| POST | /api/v1/... | bearer(staff) | {...} | {...} | 201 |

Per endpoint: **pagination** (every list declares cursor|offset|page+size and its
envelope) · required fields · **validation per field, concrete** · every reachable
error status with its code · idempotency.
Depth: `agent/skills/task-sharding/references/api-contracts.md`.

### Data
Migration `NNNN_description` — tables, columns, indexes. Reversible? Backfill?
🧍 Schema changes are a human gate.

### Functions
```yaml
- signature: "do_thing(input: TypeA) -> TypeB"
  params: { input: "what it is, where it comes from" }
  returns: "TypeB — shape/meaning; raises on <condition>"
  purpose: "one line — why this exists"
```

### UI
- **Design contract:** `design/screens/<id>.md` ← build from this, not from the mockup
- Route · navigation from → to
- States required: loading · error · empty · data
- Gate: `make design-verify SCREEN=<id>` **green before the PR** (rule 2)

### External services & flags
Service · env vars · failure behavior. Flag key · default · scope.
🧍 New dependency or secret is a human gate.

## 6. Risks
Known pitfalls, races, gotchas for THIS task. What will bite the implementer at
hour three.

## 7. Implementation checklist  ← live execution log
> Tick each item **the moment it's done**, with the 7-char commit hash. Not at
> the end — a resuming agent (maybe another model, tomorrow) starts at the first
> unchecked box. `(uncommitted)` is temporary and must be gone before any handoff.

- [ ] tests written FIRST and failing, named by EARS id
- [ ] <granular step>
- [ ] <granular step>

## 8. Acceptance criteria (EARS) + test plan
Depth: `agent/skills/task-sharding/references/ears.md`.

- **EARS-<AREA>-1**: WHEN <trigger>, the system SHALL <behavior>  (FR-..., UC-...)
- **EARS-<AREA>-2**: IF <error condition>, THEN the system SHALL <response>  (FR-...)

### Tests
- `test_EARS_<AREA>_1_<behavior>` → asserts what
### Manual
1. Step → expected result

## 9. Self-review + Definition of Done
Fill §Self-review before flipping to `review-requested`. The reviewer checks
these anyway; ticking them untruthfully only buys a wasted cycle with your name
on it.

### Self-review
- [ ] Every §7 item done, with commit hashes
- [ ] `make test && make lint` green
- [ ] Diff confined to `files:`; §4 respected
- [ ] UI: `make design-verify SCREEN=<id>` green
- [ ] Loading/error/empty states present (if UI)
- [ ] No secrets or PII logged; audit entry on lifecycle writes
- [ ] Every ADR touching these files is honoured — or listed below with a reason

**Deviations from spec/design** (none, or list — each with its spec/ADR reason.
"Looked better" is not a reason):

**Files actually touched:**

### Definition of Done
- [ ] Every §8 criterion passes via a test named by its EARS id
- [ ] UI: design gate green; extra elements trace to an approved `design/gaps.md` entry
- [ ] Review APPROVE from a **different model** than `executed_by` (rule 5)
- [ ] Squash-merged to the epic branch; tracker + metrics stamped
- [ ] 🧍 Human `verified` (epic-level batches are fine)

## Handoff (only when blocked or frozen — `skills/handoff`)
What was tried · why blocked · what would unblock · suggested next.
Rate-limit freeze: the packet at `agent/handoffs/<id>.yaml` is mandatory.

## Open Questions
> A real spec gap → append here and STOP. (Small ambiguity → simplest reading +
> a §Deviations note; don't stall.) Keys are stable so tooling can fill them.
> Status: 🟡 open · 🟢 answered · ⚪ deferred

- **OQ-<id> — <short title>.** <the question / the gap>
  - **Status:** 🟡 open
  - **Answer:** _<empty — fill here>_
  - **Answered by:** _<human name | agent id> (manual|auto)_
  - **Date:** _<YYYY-MM-DD>_

## Feedback log
- (human feedback on this deliverable lands here)

## Run log
- (key evidence: decisions applied, session refs, gate reports)
