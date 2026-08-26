---
name: epic-breakdown
description: Turn an SRS + feature list into traceable, prioritized epics with EARS criteria and a wave plan; also handles work injected mid-stream (bugs, feedback, new scope). Use when planning a project or milestone, restructuring scope, or whenever the human drops in new work.
---
# Epic Breakdown + Injecting work

Merges v1's `epic-breakdown` + `priority-scheduling` + `workflows/epic-breakdown.md`
+ `workflows/inject-work.md` — one skill, because they're one question: *what
should be built next, and why that?*

## Precondition
**Epic 00's exit gate is GREEN** — domain model accepted, ADRs accepted, walking
skeleton running, design contracts extracted. Feature epics get built against
locked decisions, never against assumptions. If E00 isn't done, stop and say so.

## Procedure

### 1. Read the locked foundation
`docs/domain/*` (entities, flows, risks) + the accepted ADRs + the approved
design contracts. These bound every epic.

### 2. Draft epics from the spec
One epic ≈ one SRS module. Each gets `epics/E<NN>-<slug>/` with `epic.md` from
the template, an empty `tasks/`, and `tracker.md`.
Axis: **functional area**, not layer. "Backend" is not an epic; "Identity &
Access" is.

### 3. Score everything
**Epic — WSJF:** `(business_value + time_criticality + risk_reduction) / job_size`,
each 1–10, relative and fibonacci-ish. Re-score at injection or retro — not
daily, that's astrology.

**Task — MoSCoW:** `must | should | could | wont` + a correct `depends_on`.
If >60% is `must`, you haven't prioritized (Analyze gate catches this).

Mark the **wedge ★**: the single epic with the highest adoption value — the one
that makes the product worth existing. Everything else is scaffolding around it.

### 4. Coverage check
Every functional SRS id lands in **exactly one** epic. Orphans = fix. Duplicates
= fix. The dependency graph is acyclic. NFRs (security, perf, availability) are
cross-cutting: bind them as epic-level EARS on the epics they constrain — an
"NFR epic" is a way of never doing them.

### 5. Propose the first WAVE
Not a fixed number — **let the graph decide** (often 3–6). Which epics are
unblocked once E00 is done, plus the wedge, each with a one-line rationale, plus
an explicit "defer for now" list. Tighter waves = faster feedback = fewer
expensive wrong turns.

### 6. Write the map
`epics/README.md` — the table (id, title, SRS modules, WSJF, depends_on, status)
+ the dependency graph + the wave plan.

🧍 **HUMAN GATE** (`epic_breakdown_and_wave`): the human approves the map, the
scores AND the wave before anything is sharded. This is a business decision, and
it's the one where being wrong is most expensive.

### 7. Hand off
Approved epic → `skills/task-sharding` → the Analyze gate → dispatch.

---

## Injecting work (the human drops something in, anytime)

The queue is not a plan you defend; it's a plan you update. But updates enter
through the front door.

**1. Classify:**

| Input | Becomes |
|---|---|
| A defect | a bug task (`skills/bug-sweep` §Triage). Reviewer sets severity, **human sets priority** |
| New scope | route through `skills/change-impact` first (IMP report, gate `change_impact_approval` 🧍), then a new SRS amendment id, then task(s) or an epic. 🧍 approve. Spec stays the source of truth |
| Feedback on a deliverable | reopen that task; append to its `## Feedback log` |
| A recurring agent miss | a lesson now (`skills/retro`); a promotion proposal at the next retro |
| A project-wide rule | a constitution edit + an ADR. 🧍 approve |

**2. Score + DAG-insert.** Same WSJF/MoSCoW as everything else. New work does not
skip the queue because it's new — only P1 does, and P1 means *now*.

**3. Never edit an in-progress task.** Mid-flight edits produce work that matches
neither the old spec nor the new one. A P1 may **preempt** via `skills/handoff`;
everything else waits for the task to land.

**4. Confirm back to the human:** what was created, and where it landed in the
queue. An injection that vanishes silently is why people stop trusting the
queue and start asking for status.

## Where to look next
- What feeds the epic map -> `skills/genesis` (`spec/` + accepted ADRs)
- Turning an approved epic into tasks -> `skills/task-sharding`
- Injecting work mid-flight (the ONLY path for new tasks) -> `skills/change-impact` section 4
- Coverage: which requirements no epic claims -> `skills/traceability`
- Closing an epic -> `skills/bug-sweep` then `skills/release`
