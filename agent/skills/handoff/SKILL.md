---
name: handoff
description: How work moves between agents, models, platforms and the human — the review chain, blocked/partial handoffs, and the rate-limit freeze/resume packet. Use when a task is blocked, when handing off mid-task, when usage warnings appear, or when resuming frozen work on another platform.
---
# Handoff

Merges v1's `_handoff_protocol.md` + `rate-limit-handoff` + `handoff-freeze` +
`handoff-resume`.

## 1. The core principle
**No agent is special.** A task file + the spec + the ADRs + the design contract
contain everything needed to execute. Any agent that reads markdown and writes
code can pick up any `todo` task whose deps are met.

Handoffs happen through **the task file + git** (+ a packet for freezes) —
**never through agent memory or chat history.** The moment a handoff depends on
"what we discussed earlier", the system is one crashed session away from losing
work, and one model swap away from losing quality.

## 2. The chain
```
builder implements
  → self-review → status: review-requested
    → REVIEW by a different model (rule 5)
      → done  OR  changes-requested
        → [epic build-complete] → epic sweep (skills/bug-sweep)
          → 🧍 HUMAN: epic → development
            → status: verified
```
The human reviews *reviewed* work. Their time goes to judgement, not typos.

## 3. When to hand off

### A. Blocked — can't finish
`status: blocked` + §Handoff: what was tried · why blocked · what would unblock ·
suggested next (agent or human). Commit, push. The queue moves on. This is the
system working.

### B. Partial — the task needs a skill you're weak at
Keep `status: in-progress`. Append to §Handoff: done so far **with commit
hashes** · what remains · why you're handing off · suggested next agent. Push.
The next agent continues the **same branch, same task** — never a fork.

### C. Review — always cross-model
The reviewer reads the diff + §Self-review, runs the suite themselves, runs
`make design-verify` if there's a contract, and returns APPROVE or
changes-requested with concrete file:line evidence.

### D. Freeze — rate limit or P1 preempt
The expensive one, and the reason packets exist.

## 4. Rate-limit freeze

**Detect before exhaustion.** Trigger on *plan* limits (5-hour rolling +
weekly), not API budget. The statusline hook (`agent/orchestrator/ratelimit_guard.py`)
reads Claude Code's `rate_limits` payload and drops `agent/handoffs/.FREEZE` at
the `freeze_threshold_pct` in `harness.yaml` (default 80%). Also: `/usage`, or
`npx ccusage@latest`.

Why 80% and not 99%: a freeze needs room to *be* a freeze. Discovering the wall
mid-edit is how you lose an hour of uncommitted work.

**Freeze (orchestrator):**
1. Signal the builder: finish the current edit, start no new sub-goals.
2. WIP-commit the branch: `wip(E03-T07): freeze for handoff`.
3. Write the packet `agent/handoffs/<task-id>.yaml` from `_template.handoff.yaml`.
   **`next_step` and `last_test_status` are MANDATORY** — a packet without them
   is a note, not a handoff. Save `git diff origin/epic_<NN>` beside it.
4. Record the native session id; stamp partial metrics.
5. `status: frozen` in the tracker; notify the human (reason, window reset ETA,
   resume platform).

**Resume (orchestrator, on the next platform in `harness.yaml: platforms`):**
1. Read the packet; verify the branch exists and `last_commit` matches origin.
2. Spawn the same-role agent there. Inputs = **packet + task file + AGENTS.md
   ONLY**. Not the old chat history — that's the whole point.
3. Worktree-add the same branch. **Re-run the failing tests from
   `last_test_status` FIRST** to re-anchor in reality, then execute `next_step`
   literally.
4. Normal loop resumes. Delete the packet only after the task's PR merges;
   `frozen` → `in-progress`.

If a resumed agent can't continue from the packet alone, the packet was
incomplete — that's a `process` lesson, not a shrug.

## 5. Hygiene
1. **Leave the repo green, or clearly red.** Tests pass, or §Handoff says
   exactly what's failing and why.
2. **Commit before handing off.** Uncommitted work is invisible work.
3. **Same task = same branch.** Continue; don't fork.
4. **Write for a stranger.** Zero memory assumed: paths, hashes, decisions.
   The stranger might be you, next week, or a different model tonight.
5. **Update the tracker.**
6. **Never silently change scope.** Note it; real growth = a new task.
7. **Non-obvious choices get a Decision record** (one line minimum) so the next
   agent doesn't re-litigate what you already settled.

## 6. Conflicts
- **Small ambiguity** → simplest interpretation + §Deviations note. Don't stall.
- **Real gap/contradiction** → `spec/` wins on *what*, ADRs on *how*, `design/`
  on *how it looks* (spec beats design). Still unclear → Open Question +
  `blocked`. The human decides.
- **Two agents touched the same files** → the DAG should have prevented it
  (`skills/task-sharding` §Anti-collision). If it happened: the later agent
  **rebases** on the merged work. Never force-push over another agent's commits.
  Recurring collisions = resharding problem, not a git problem.

## 7. Statuses
| From | To | Trigger |
|---|---|---|
| todo | in-progress | dispatched, deps met |
| in-progress | review-requested | self-review passed |
| in-progress | blocked | can't proceed (§Handoff filled) |
| in-progress | frozen | rate-limit / P1 preempt (packet written) |
| blocked/frozen | in-progress | unblocked / resumed |
| review-requested | changes-requested | reviewer found issues |
| review-requested | done | approved + merged |
| changes-requested | in-progress | builder resumes |
| done | verified | 🧍 human sign-off |

## 8. What the human is for
A `blocked` decision · final `verified` · epic completion + bug priorities ·
constitution/ADR choices · the gates in `harness.yaml: human_gates`.
Everything else runs agent-to-agent.

## Where to look next
- Statuses and who may move them -> section 7 above - `agents/orchestrator.md`
- Blocked by a spec gap rather than a technical wall -> `skills/question-resolution`
- Blocked by a requirement change -> `skills/change-impact` (a running task is never edited)
- Resuming: read the packet, then the task file, then the lessons for its area -> `skills/implement`
- Freeze budgets and the rate-limit guard -> `scaffold/harness.yaml` - `agent/orchestrator/ratelimit_guard.py`
