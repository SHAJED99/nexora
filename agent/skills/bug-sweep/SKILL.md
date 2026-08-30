---
name: bug-sweep
description: The end-to-end epic sweep plus bug triage on the severity x priority matrix. Use when an epic's tasks are all done, when a human reports a bug mid-stream, and whenever something gets called "critical" without a definition.
---
# Bug Sweep + Triage

Merges v1's `bug-triage` + `workflows/bug-sweep.md`.

## Why a sweep exists at all
Every task passed its own review. The bugs live in the **seams between tasks** —
the places no task owned, which is precisely why no task's tests covered them.
Task-level tests prove tasks. Only the sweep proves the epic.

## Mid-epic: read the tracker's own carried-forward observations before every new dispatch
**Rule, added 2026-08-30 (L-process-008):** a task's reviewer sometimes flags
a real, out-of-fence risk and records it in the epic tracker's §Carried-forward
observations — correctly, per this skill. That entry has no reader until the
end-of-epic sweep unless something forces one sooner. In E06 this let an S1
defect (a fallback that silently hijacked the app's only transport-event
handler) sit unaddressed across eight subsequent tasks before the sweep
finally caught it. Before dispatching each next task in a still-running epic,
check the tracker's own §Carried-forward observations: if the next task's
`files:` fence touches the same file or area as an open entry, fold in the
fix or note explicitly why it stays out of scope. An unread carry-forward
should require a reason to stay unread, not just silence until the sweep.

## The sweep (reviewer, when all epic tasks are `done`)

1. **End-to-end against the epic's EARS set:**
   - API flows — real calls, real data, in order, like a user
   - UI flows — Playwright against the running app; `make design-verify` across
     every screen the epic touched (a screen can pass at task time and drift
     when the next task lands)
   - **cross-task seams** — the handoffs between tasks: does the thing task A
     writes match what task B reads? This is where the money is.
   - the unwanted paths: the IF/THEN criteria, permissions, boundaries
2. **Each defect → a bug task** (`E<NN>-B<nn>`) via the template: exact repro
   steps, expected (cite the FR/UC/EARS id), actual, severity.
3. 🧍 **HUMAN GATE** (`bug_priorities`): the human confirms or overrides
   priority. Severity stays the reviewer's.
4. **P1/P2 feed back into the scheduler** before the epic→dev PR.
   P3/P4 → backlog. **The epic→dev PR opens only when P1/P2 = 0.**

## Triage — two independent axes

Confusing these is why "critical" stops meaning anything.

**Severity — the reviewer sets it. Technical impact:**

| | Meaning |
|---|---|
| **S1** | crash · data loss · security hole · total blocker |
| **S2** | major function broken, no workaround |
| **S3** | broken, but there's a workaround |
| **S4** | cosmetic / minor |

**Priority — the HUMAN sets it. Business urgency:**

| | Meaning |
|---|---|
| **P1** | now — preempts running work (`skills/handoff`) |
| **P2** | this epic |
| **P3** | next epic |
| **P4** | backlog |

They're independent on purpose. A typo in the logo (S4) can be P1 the day
before a launch. A rare data-race (S1) can be P3 if the feature is behind a
flag nobody has. **An agent that sets priority has made a business decision it
has no information for** — that's the human's call, and it's rule 3.

## Writing a bug task that gets fixed once
- **Repro:** numbered steps a stranger can follow, from a known starting state.
  "Sometimes fails" is a report, not a repro — go find the trigger.
- **Expected:** cite the id. Not your opinion — the spec's.
- **Actual:** what happened, with the evidence (error, screenshot, gate report).
- **Regression test first.** The fix isn't done until a test that failed before
  it passes after. Bugs without regression tests come back; that's what "bugs
  come back" means mechanically.
- **Severity, not adjectives.**
- **A scope fence, same as a feature task.** (Rule, added 2026-08-30,
  L-process-009: every bug task file checked so far — `E05-B02`, `E06-B02`,
  `E06-B03`, `E06-B04` — shipped with no "What this fix does NOT do"
  section at all, not even an empty one; `make health`'s H4 check flags an
  absent fence as worse than an empty one.) Write one. A bug fix's diff
  looks small, which makes scope creep both easier to justify in the
  moment and easier to miss in review — state plainly what the fix does
  NOT touch, alongside Repro/Expected/Actual/Severity.

## Re-verification
Every fix is re-verified by the reviewer before close — against the original
repro, not against the fixer's claim. The person who fixed it is the person
least able to see that it isn't fixed.

## Where to look next
- When to run -> after every task in the epic is `done`, before `skills/release`
- Aim it at the boundaries -> the `files:` fences of the epic's tasks, because a seam belongs to no task
- Writing the bug tasks -> `skills/task-sharding` (bug frontmatter) - `skills/epic-breakdown` (injecting work)
- P1 preempts running work -> `skills/handoff`
- A bug that is really a spec gap -> `skills/question-resolution`
- The gate this feeds -> `skills/release` (P1/P2 must be zero)
