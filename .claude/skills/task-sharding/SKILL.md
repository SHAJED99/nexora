---
name: task-sharding
description: Shard an approved epic into task files a fresh agent can execute without improvising — files, API contracts, function signatures, do/don't, EARS, DoD — then run the analyze gate. Use whenever an epic is approved, when creating tasks, or when a task proves too big or too vague mid-flight.
---
# Task Sharding + the Analyze gate

Goal: a task so specified that a **fresh agent with zero chat history** executes
it without improvising — and a human reads it in two minutes. Those two
constraints fight each other, and resolving that fight is the whole skill.

Merges v1's `task-sharding` + `ears-authoring` + `api-contract-design` +
`workflows/shard-epic.md` + `workflows/analyze.md`. Depth in
[references/ears.md](references/ears.md) and
[references/api-contracts.md](references/api-contracts.md).

## Precondition
The epic is human-approved, and Epic 00 is done (unless this IS Epic 00).
UI epic? Its design contracts exist and are approved first
(`skills/design-fidelity`) — a frontend task without a `design_contract:` is
not shardable.

## Procedure

### 1. Slice vertically
Walk the epic's EARS criteria. Group into slices where each task is **one
mergeable unit of value** — roughly ½–1 agent-session. Vertical (endpoint +
logic + tests) beats horizontal (all the models, then all the controllers):
vertical slices merge independently and prove themselves.

Size honestly: `XS ~2h · S ~1d · M ~2-3d · L ~1wk`. **An L task is a planning
failure — split it.** Long tasks are where context runs out, checklists rot, and
agents start inventing.

### 2. Fill the template completely
`epics/_templates/task.template.md`. Nine sections, and they're nine because
every one of them changes what gets built. The frontmatter contract:

- `traces_to:` ≥1 spec id — **rule 1**. No id, no task.
- `files:` — create / update / delete. **The diff may not exceed this list.**
  This is what makes review mechanical and parallel tasks safe.
- `api_contracts:` — full shape per endpoint (see references).
- `functions:` — signature, params, returns, purpose.
- `design_contract:` — required for `layer: frontend`.
- `depends_on:` — correct, or the scheduler lies to everyone.
- `required_context:` — the ids the executing agent will need: spec ids, ADR ids,
  the design contract, upstream task ids. `skills/agent-briefing` attaches
  **exactly** this and nothing "just in case", so an under-declared list is how a
  brief ends up missing something the task depends on.

### 3. Write the scope fence (§What this task does NOT do)
The most-skipped section and the highest-value one. Name the
tempting-but-wrong moves *this specific task* invites: "don't add a caching
layer", "don't touch login", "don't fix the naming next door". An agent with an
empty fence will fill the space with its own judgement, and its judgement is
not the plan.

### 4. Anti-collision pass
Build the file-collision matrix across tasks that could run in parallel. It
should be **empty**. Two parallel tasks touching one file is the #1 source of
merge pain — and it's free to prevent here and expensive to fix later. Collide?
Reshard, or serialize with `depends_on`.

### 5. Tracker + validate
Write/refresh `tracker.md` (state machine + mermaid DAG), then:
```bash
make validate     # cycles, unknown deps, missing traces_to, bad statuses
```

### 6. The Analyze gate — "unit tests for English"
Run this against the sharded epic **before any task dispatches**. It is a
consistency gate on the *specs*, and it is much cheaper than discovering the
same problems through five failed implementations.

| Check | Fails when |
|---|---|
| **EARS trace** | a task has no EARS id, or an epic EARS id has no task. Orphans either way = fail |
| **Contract sanity** | a list endpoint without pagination · a non-uniform error envelope · two tasks defining one endpoint differently · casing that contradicts the conventions |
| **Collision matrix** | any two parallelizable tasks share a file |
| **Scope fences** | any task's §NOT-do is empty |
| **MoSCoW inflation** | >60% of tasks are `must` — re-grade; if everything is critical, nothing is |
| **Size** | any `L` task not split or justified |
| **Design** | a frontend task without a `design_contract:`, or one pointing at a contract that doesn't exist |

Output an ANALYZE REPORT (pass/fail per check, with the offending ids) appended
to `epic.md`.

🧍 **HUMAN GATE** (`analyze_report`): the human skims it. Approval unlocks
dispatch.

## Estimation calibration
`token_estimate.tier`: `S 5–15k · M 50–150k · L 150–500k`. When `metrics.csv`
shows actuals >1.5× the estimate for a tier twice, `skills/retro` adjusts this
guidance. Estimates that never learn are decoration.

## Sizing smell tests
- Can't name the files? Not sharded — it's still an epic.
- The checklist has "and then handle the edge cases"? Name them or split.
- Two unrelated "and"s in the title? Two tasks.
- Can't write the test names before the code exists? The spec isn't ready —
  that's an Open Question, not a task.

## Where to look next
- Where epics and waves come from -> `skills/epic-breakdown`
- Who runs a task and what context it gets -> `skills/agent-briefing`
- Executing the contract you just wrote -> `skills/implement`
- Frontend tasks need a contract or they cannot be gated -> `skills/design-fidelity`
- A task that turns out to be wrong -> `skills/change-impact` (never edit a running task)
- Proving every requirement got sharded -> `skills/traceability`
