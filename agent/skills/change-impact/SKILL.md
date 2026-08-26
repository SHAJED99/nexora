---
name: change-impact
description: Walk the blast radius of any change to a baselined requirement, decision, assumption or design, produce an IMP-nnn report, and execute the approved re-plan. Use whenever a requirement, decision, assumption or design changes after baseline — before any re-planning — and whenever an assumption is invalidated.
---
# Change Impact

**The system never silently overwrites a prior decision.** After baseline,
every change to spec, ADRs, design contracts or assumptions passes through
here first — because the cost of a change is never the edit, it's everything
downstream of the edit, and downstream is exactly what nobody checks when
they're in a hurry.

Output: `docs/impact/IMP-nnn-<slug>.md` from
`templates/impact-report.template.md`. No IMP report, no re-plan.

## Procedure

### 1. Classify the change
| Class | Example |
|---|---|
| **new scope** | a feature nobody specified appears |
| **changed requirement** | FR-AUTH-003's behavior is redefined |
| **invalidated assumption** | A-007 ("single currency") turns out false |
| **reversed decision** | an accepted ADR no longer holds |
| **design change** | an approved screen contract changes |
| **dropped scope** | a must-have becomes a won't-have |
| **resolved silence** | the spec never covered a case, an agent's code picked one by omission, and a human has now decided it |

The class determines who must approve and how far the walk goes — an
invalidated assumption walks from its `risk_if_wrong`; a reversed ADR walks
from everything that cited it.

**resolved silence** is the class that looks like the others and behaves
differently. It usually arrives as a 🟢 answer to a question the review gate
raised. Nothing is *changed*, so: **no id is retired, no ADR is superseded, and
the existing requirement text stays exactly as written** — you add a new id for
the case that was never covered. Walk it from the code that guessed, not from
the requirement, because the requirement was never wrong; the silence was.

### 2. Walk the blast radius
Two passes, both mandatory — the map for structure, grep for truth:

1. **Knowledge map walk:** follow `edges[]` from the changed node outward
   until the edges stop.
2. **Grep for the ids** — the map indexes; the repo decides:
   - requirements: the FR/NFR ids in `spec/srs.md`, epics, tasks
   - decisions: ADRs citing the changed id. **A reversed accepted ADR requires
     a superseding ADR — never an edit.** History is how the next agent learns
     why; edited history teaches nothing.
   - design: `design/screens/*.md` contracts, `design/gaps.md` entries
   - epics/tasks: `traces_to:` frontmatter hits — **both** levels. An epic and
     its tasks each carry `traces_to:`, and the task is the one you remember. A
     new requirement claimed by a task but not by its epic shows up immediately
     as a `requirement with no epic` orphan.
   - code modules: the `files:` lists of affected tasks
   - tests: EARS naming — grep `test_EARS_<AREA>` for the affected criteria
   - docs: baseline, traceability, conventions

### 3. Write the report
`docs/impact/IMP-nnn-<slug>.md`: the change · the cause · the blast radius
table (artifact | id | impact | action) · effort/risk assessment · proposed
re-plan. Re-plan rules:
- Task changes go through **epic-breakdown's injecting-work path** — impact
  never edits task files directly.
- **Never edit an in-progress task.** Its agent is executing a contract; a
  contract that changes underfoot produces work that satisfies neither
  version. New/changed scope = a new task; the in-progress one finishes or is
  cleanly blocked via `skills/handoff`.
  - **The boundary:** this protects a *running* agent. A `changes-requested` or
    `blocked` task has nobody executing it, so amending it and returning it to
    `in-progress` is correct — that transition is what those states are for.
    Forcing a new task there splits one contract in two and strands the parked
    task on a question that is now answered. Read the rule by its reason, not
    its wording.

### 4. 🧍 HUMAN GATE (`change_impact_approval`)
The human approves the re-plan, trims it, or rejects the change. This gate is
what makes step 1 of question-resolution safe: agents can *propose* any change
because no change *executes* without a human seeing its full cost.

### 5. Execute the approved re-plan
In order, each its own commit:
1. Supersede ADRs (new ADR, `supersedes:` link; old one → `superseded`).
2. Amend `spec/srs.md` — changed behavior gets **new ids**; retired ids are
   marked, never deleted (tasks trace to them).
3. Update knowledge map nodes + edges (`docs(knowledge): IMP-nnn executed`).
4. Reopen or create tasks via epic-breakdown; update trackers.
5. Mark stale tests — tests asserting the old behavior are flagged, not
   silently rewritten to pass.

### 5b. Verify the execution, don't assume it
Regenerate traceability (`skills/traceability`) **as the last step of executing
the re-plan**, and read it. It is the only thing that checks whether the re-plan
you approved is the re-plan you performed — a step skipped, a `traces_to:` half
updated, a new id nothing claims. This is a verification step, not bookkeeping.

### 6. Revalidation
**Done is only done against the current spec.** Affected `done` tasks need
revalidating. **"needs-revalidation" is a disposition, NOT a status** — it is not
in `harness.yaml scheduler.statuses` and `scheduler.py --validate` rejects any
status it does not know. Revalidation is expressed as new bug/chore tasks tracing to the new
ids, because the harness has one execution state system (task frontmatter +
tracker.md) and impact does not get a second one. A task that was done against
FR-X-old and never revalidated against FR-X-new is not done; it's stale and
lucky.

## Smell tests
- An "edit" to an accepted ADR in a diff → stop; that's a superseding ADR.
- A blast radius table with one row → the walk was shallow; requirements have
  tests, tests have tasks, tasks have files.
- Re-plan executed before the gate → revert; the gate is the skill.

## Where to look next
- What triggers this → `skills/question-resolution` (answers changing accepted
  artifacts, invalidated assumptions) · design changes via `skills/design-fidelity`
- The walk's index → `skills/knowledge-map`
- Task injection → `skills/epic-breakdown`
- Proving revalidation → `skills/traceability`
