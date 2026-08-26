---
name: retro
description: The post-epic retrospective and the lesson → rule → hook promotion ladder that makes agents measurably better over time. Use after every epic, after any rollback or incident, and whenever the same mistake appears twice.
---
# Retro — how the system gets better

This is the skill that makes the harness compound instead of just repeat. Every
other skill spends knowledge; this one creates it.

**The v1 failure this fixes:** lessons were written to `memory/lessons/`, and
then a human hand-pasted the important ones into agent role files, where they
rotted. Learning that depends on someone remembering to copy it isn't learning.
Now: lessons are data, the hook injects them automatically, and promotion is a
mechanical ladder with a human gate.

## When
After every epic (mandatory), after any rollback or incident, on demand.

## Procedure

### 1. Evidence, not memory
Gather: tracker history · every **changes-requested** reason (this is the
richest signal in the system — it's a list of what agents get wrong) · the bug
list · `metrics.csv` (estimate vs actual) · design-verify reports (which
findings recurred) · handoff packets · human feedback · `spec/questions.md`
answer history (which questions blocked, which assumptions were wrong) ·
`spec/knowledge-map.yaml` drift (what the map said vs what got built).

Then run **`make health`**. It reports the seven ways the harness decays
(`docs/ARCHITECTURE.md` §7) — a skipped retro, an empty scope fence, a
same-model review, a threshold loosened without a reason. Every finding is a
`process` lesson with its evidence already attached. This is the cheapest retro
input there is: it found the problems before you went looking.

### 2. Write the lessons
For each miss or rework item → `agent/memory/lessons/<area>.md`, from
`_template.md`. **If the lesson already exists, increment `recurrence:`** —
don't write a second one. The recurrence count is what drives the ladder, so a
duplicate lesson is worse than no lesson: it hides the pattern.

Areas: `backend` · `frontend` · `design` · `qa` · `infra` · `process`.

### 3. The promotion ladder — the core mechanism

| Recurrence | Becomes | Where it lives | Enforced by |
|---|---|---|---|
| 1st time | **lesson** | `memory/lessons/<area>.md` | the agent reads it (hook injects) |
| 2nd time | **rule** | a line in the relevant `SKILL.md` | the reviewer checks it |
| mechanically checkable, or 3rd time | **hook** | `agent/hooks/` or a test | the machine, every time |

```bash
make lessons        # lessons by area + promotion candidates (recurrence >= 2)
```

Climb the ladder as fast as the evidence allows. **A hook beats a rule beats a
lesson**, because a hook can't be forgotten, skimmed, or lost to a context
window. When a lesson *can* become a hook, it should — "remember to X" is the
weakest possible control, and it's the one everyone reaches for first.

Examples of the ladder working:
- "commit messages should reference the task" → lesson → rule → **commit-msg
  hook**. Now unforgettable.
- "the UI drifts from the design" → lesson → rule ("compare screenshots") →
  **`make design-verify`**. The rule was being followed and drift shipped
  anyway; only the hook actually worked.
- "don't fire-and-forget a consequential side-effect" → hit twice → a rule in
  `skills/implement`, checked in review. Not mechanically checkable as written —
  a lint rule for the specific pattern would be the next rung, and that's the
  direction to push every rule that keeps recurring.

### 4. 🧍 HUMAN GATE — every promotion
`retro_promotions`. **Skills are code.** Diff them like code; the human approves
the PR. A bad "lesson" promoted to a rule makes every future agent worse, and
it's invisible — nobody re-reads a skill file to check whether it's still true.
This gate is not bureaucracy; it's the only thing standing between one bad
inference and permanent institutional damage.

Prune, too: a rule that no longer fires is noise in every context window forever.

### 5. Calibrate the estimates
Actual >1.5× the estimate for a tier, twice → adjust the tier guidance in
`skills/task-sharding`. Estimates that never learn are decoration.

### 6. Write it up
`epics/E<NN>/retro.md`: what shipped, what recurred, what got promoted, what the
numbers said. Short. It's evidence for the next retro, not a report for
management.

## Rules
1. **Lessons are about THE SYSTEM.** Not "the agent forgot X" — *why was
   forgetting possible?* Blame fixes nothing; a missing gate is fixable. If a
   lesson's root cause is "the agent should have been more careful", it isn't
   finished: careful is not a mechanism.
2. **Never auto-merge a skill edit.** Human gate, always.
3. **A lesson with no root cause is an anecdote.** The root cause is the spec
   gap, the skill gap, or the gate gap that let it through.
4. **Recurrence is sacred.** It's the only number that tells you what to
   automate next.

## Where to look next
- What must be complete first -> `skills/bug-sweep` (P1/P2 clear) and the
  epic's merge into `development`. **Not** `skills/release`: the epic retro runs
  *before* a release, and `skills/release` lists a completed retro among its
  preconditions — reading it the other way makes the two circular.
- Evidence to read, not memory -> per-epic `metrics.csv`, `runs/`, review verdicts, `docs/impact/`
- Where lessons live and how they reach an agent -> `agent/memory/lessons/` + the lesson-inject hook
- A lesson that became a rule -> the relevant `SKILL.md`; a rule that became a hook -> `agent/hooks/`
- Re-estimating the next epic -> `skills/epic-breakdown`
