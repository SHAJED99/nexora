---
name: agent-briefing
description: Decide which agent runs a task, whether a new role is justified at all, and assemble the minimal context package that agent receives. Use before dispatching any task, whenever a task looks like it needs expertise no current role has, and whenever an agent asks a question its brief should have answered.
---
# Agent Briefing

Two questions get answered before any dispatch: **who runs this**, and **what
do they get to see**. Both are usually answered by reflex, and both failure
modes look identical from the outside — an agent producing confident, wrong,
well-formatted work.

Two governing rules:

**The brief is the agent's entire world.** Context is not a courtesy, it's a
boundary. Everything you hand over is something the agent may act on, and
anything you hand over "just in case" is scope you have silently authorised.

**A new role is a change to the process, not a convenience.** Roles are cheap to
add and expensive to own: every one is another place for "who is responsible for
this?" to have no answer.

---

## Part 1 — Routing: who runs this

### 1. Start from what the shard already decided
The task file's `layer:` and `owner_agent:` were set by `skills/task-sharding`
with the whole epic in view. **Do not re-litigate them per task** — a router
that second-guesses every shard produces a different answer on Tuesday than it
did on Monday, and the trackers stop meaning anything.

Override only with a stated reason, recorded in the task's Run log.

### 2. The five roles, by boundary
| Role | Boundary — not "technology" |
|---|---|
| **planner** | Turns intent into contracts. Writes spec/, ADRs, epics, tasks. Writes no product code. |
| **orchestrator** | Owns the queue, gates, budgets, routing, metrics. Writes no product code. |
| **builder** | Implements backend · CLI · infra. One task, one branch, inside the contract. |
| **builder-ui** | Implements frontend. Additionally bound by a design contract and its gate. |
| **reviewer** | Judges. Read-only on product code, and must be a different model than the implementer. |

The dividing line is **what the role may touch and who checks it** — not which
framework the task happens to use. A React task and a Vue task are the same
role; a task that writes code and a task that judges code are not.

### 3. The reuse test — run it before considering a new role
Four questions, in order. The first "yes" ends the search:

1. Can an existing role do this **with a different skill loaded**? → reuse it.
   Skills are the extension point; that is what they are for.
2. Is the gap **knowledge**, not capability? → that's a context or MCP problem.
   Fix the brief (Part 2), not the roster.
3. Is the gap **a tool**? → an MCP server on an existing role.
4. Is this **one task**, or a recurring class of work? One task is never a role.

> Most "we need a specialist agent" moments are step 1 wearing a costume. An
> agent isn't a person: "backend engineer" and "database engineer" are the same
> executor holding a different skill.

### 4. The bar for a new role — ALL four must hold
1. **Recurring** — at least three foreseeable tasks, not this one.
2. **A genuinely different boundary** — different files, permissions, or
   review posture. Different *technology* is not a different boundary.
3. **No existing role + skill combination covers it**, demonstrably: name the
   combination you tried and why it failed.
4. **It changes who reviews the work**, or the review rule (rule 5) is unaffected
   and the role is decoration.

Fail any one → write a skill, extend a role's `mcp:`, or fix the brief.

> A role per technology is how a system ends up with fifteen agents and no
> owner. Five roles that are always clear beats fifteen that are usually right.

### 5. 🧍 HUMAN GATE (`agent_role_creation`)
A new role file is law: every future agent reads it and every future task can be
routed to it. That makes it the same class of change as promoting a lesson to a
rule (`retro_promotions`) — process editing, which rule 3 reserves for the
human. Present: the proposed boundary, the reuse test results with the
combination you tried, the three-plus tasks that justify it, and its
prohibitions.

### 6. A new role file must mirror the existing five
Frontmatter `name` · `description` · `model` · `mcp` · `skills`, then: what it
owns, its **prohibitions** (the load-bearing half — a role without prohibitions
is an agent with your whole repo), and its review relationship. Add it to
`harness.yaml` topology and to the roster in `scaffold/AGENTS.md`.

### 7. Sequential, parallel, or conditional
**Do not invent a second scheduler.** The answer is already in the data:

- `depends_on:` / `blocks:` in task frontmatter form the DAG.
- `agent/orchestrator/scheduler.py` picks order: `unblocked → p1_bug → moscow
  → wsjf → critical_path`.
- Waves come from `skills/epic-breakdown`; a wave dispatches only after its 🧍 gate.
- WIP is capped at 3 parallel agents.

Your job here is only to notice **conflicts the DAG doesn't model**: two
unblocked tasks whose `files:` lists overlap cannot run in parallel regardless
of what the DAG says. Serialise them, or reshard so the overlap disappears.

---

## Part 2 — The context package: what they get to see

### The inclusion rule
**Everything in a brief must be traceable to one of the task's own ids.** If you
cannot name the `traces_to:` requirement, the `files:` entry, the ADR, or the
`depends_on:` task that pulled a document in, it does not go in.

This is the rule that makes briefs shrink instead of grow. "It might be
relevant" is not a provenance.

### What the brief contains
Assembled into `templates/agent-brief.template.md`:

| Section | Source — how it's retrieved |
|---|---|
| **Task definition** | the task file itself, in full. Not summarised — it's the contract. |
| **Relevant requirements** | only the FR/NFR/UC ids in `traces_to:`, quoted from `spec/srs.md` |
| **Relevant architecture** | only ADRs whose scope touches `files:` — walk `constrained_by` edges |
| **Relevant decisions** | accepted ADRs cited by those requirements. **Never a superseded one** |
| **Relevant design** | the one contract named in `design_contract:` — not the design system entire |
| **Relevant files** | `files:` plus their direct imports/callers. One hop, not the tree |
| **Dependencies** | the *outputs* of completed `depends_on:` tasks — what they built, not their transcripts |
| **Constraints** | the constitution rules that actually bite here, named |
| **Acceptance criteria** | the task's EARS criteria, verbatim |
| **Expected output** | branch, the diff's permitted shape, and what "returned" looks like |

Lessons are injected by `agent/hooks/lesson-inject.py` for the task's area —
**never hand-copied**, or the brief and the hook disagree and the agent believes
the wrong one.

### What is forbidden, and why
| Never include | Because |
|---|---|
| the whole repository | the `files:` fence stops meaning anything the moment the agent has read everything |
| the full SRS | 58 requirements is 57 invitations to build the wrong one |
| the whole ADR directory | including superseded ADRs, which is how a reversed decision gets honoured |
| unrelated epics | scope is contagious; a mentioned feature is a feature someone starts |
| the full question log | open questions on other work read as this task's uncertainty |
| another task's transcript | you wanted its output, not its reasoning; its reasoning includes its mistakes |
| the chat history | it is not reproducible, and the next agent won't have it |

### Retrieval is a walk, not a search
Pull context by walking `spec/knowledge-map.yaml` edges outward from the task's
ids — that is what the map is for. Grepping the repo for anything that looks
related is how a 4k brief becomes a 90k brief that nobody reads to the end,
including the model.

### The `required_context:` field
`skills/task-sharding` declares what a task will need in its
`required_context:` frontmatter list; briefing **assembles exactly that** and
records what it actually attached. A mismatch between the two is a finding:
either the shard under-specified, or the brief smuggled something in.

### Budget: the brief is bounded by the task, not the reverse
The task's `token_estimate.tier` bounds the brief. **If the brief won't fit the
tier, the task is too big — reshard it.** Growing the brief to fit the task is
backwards: it converts a sharding problem into a comprehension problem, and
comprehension problems fail silently.

---

## Part 3 — Validation on return
Declared **before** dispatch, so the verdict isn't negotiated afterwards:

| Check | Fails when |
|---|---|
| diff ⊆ `files:` | the agent went outside the fence (rule 6) |
| every EARS criterion has a test named for it | "done" without proof (rule 7) |
| §4 "does NOT do" respected | the scope fence was treated as advice |
| deviations listed with a spec/ADR reason | "looked better" appears anywhere |
| no question left silently answered | check `## Open Questions` — a filled-in gap means an agent decided policy |
| reviewer ≠ executor | rule 5 |

An agent that returns work failing these gets `changes-requested` with the
failing row named — not a rewrite by the reviewer, which would make the reviewer
the executor.

## Smell tests
- A brief containing the full SRS → the task's `traces_to:` is empty, or nobody read it.
- A new role proposed to serve one task → it's a skill.
- Two roles whose prohibitions are identical → they're one role.
- A brief larger than the task's token tier → reshard the task; don't shrink the fonts.
- An agent asking something the brief should have answered → that's a **brief
  bug**. Fix the brief and the `required_context:` that missed it, not the agent.
- A brief assembled by grep → it will contain a superseded ADR eventually.

## What a cleared gate does and does not prove
`scheduler.py --validate` enforces the artifact gates: a gate whose document
exists must carry `✅ cleared by <name> on <date>`, and a gate whose
`precondition_for:` path exists must have that document at all — so skipping a
stage by never writing its paperwork fails too. `--next` refuses to dispatch
while any of that is open.

**It cannot prove a human did it.** You write the files; nothing distinguishes
your tick from theirs. `validation/attack_gates.py` measures exactly that: eight
ways of slipping past a gate are blocked, and one — forging a dated, attributed
approval — is not, because it is irreducible here.

So the value is not proof, it is **shape**: clearing a gate becomes an explicit,
dated, attributable claim instead of an omission nobody notices, and forging one
is a visible lie in the diff with a name on it. Never write an approval line on a
human's behalf — including when you are confident they would agree.

## Where to look next
- Who decided `owner_agent:` → `skills/task-sharding` · waves → `skills/epic-breakdown`
- Where the context is retrieved from → `skills/knowledge-map`
- Dispatch, WIP and budgets → `agents/orchestrator.md` · `scaffold/harness.yaml`
- When an agent can't finish → `skills/handoff`
- Judging what comes back → `skills/review`
- The roster and its prohibitions → `agents/*.md`
