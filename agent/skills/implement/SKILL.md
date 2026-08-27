---
name: implement
description: The implementation loop — branch + worktree, tests first from EARS, build inside the task contract, tick the live checklist with commit hashes, self-review, PR. Use for every implementation task and every bug fix.
---
# Implement

One task. One branch. One worktree. Nothing outside the contract.

## Before you touch anything

**Read your brief first** — `runs/<task_id>/brief.md`, if the orchestrator wrote
one (`skills/agent-briefing`). It is the task file plus exactly the context you
were given, and its §10 lists what was deliberately withheld. If something you
genuinely need is missing, that is a **brief bug**: append to the task's
`## Open Questions` and stop. Do not go and find it yourself — a brief you
widened is a brief nobody reviewed.
1. **Read the task file completely.** It is the contract (rule 6): `files:`,
   `api_contracts:`, `functions:`, `## What this task does NOT do`.
2. **Read the lessons.** The lesson hook injects your area's list at prompt
   time; if it didn't fire, read `agent/memory/lessons/<layer>.md` yourself.
   These are real findings from real reviews — they are the traps you are
   statistically about to fall into.
3. **Read the ADRs your files touch.** An accepted decision is not optional and
   not re-litigable. Silently dropping one is a review failure — and it is an
   easy one to commit, because the decision lives in a document nobody re-reads
   while coding.
4. **UI task?** Read `design/screens/<id>.md`. See `skills/design-fidelity`.

## The loop

### 1. Branch + worktree
```bash
git worktree add ../wt-E03-T07 -b epic_03_task_07 origin/epic_03
cd ../wt-E03-T07
```
Four tiers: `main` → `development` → `epic_<NN>` → `epic_<NN>_task_<MM>`.
Never commit to the first three. Worktrees keep parallel agents from fighting
over one checkout.

### 2. Tests first (red)
From the task's EARS ids and `api_contracts:`, write the failing tests **before**
the code. Name them for the id they prove:
`test_EARS_AUTH_3_refresh_rejects_expired`. Run them — confirm they fail for the
RIGHT reason (an assertion, not an import error). A test that never failed
proves nothing.

Bug fix? The regression test comes first, and it must fail on the current code.

**Brownfield exception — characterization tests SHOULD pass immediately.** When
you are adding the first tests to existing untested code (mode D), the test
documents behaviour that already works, so green on the first run is the correct
outcome, not a symptom. Do not go hunting for a bug that isn't there, and above
all **do not change working code to manufacture a red**. Red-first applies to
behaviour you are about to add or fix; characterization applies to behaviour you
are about to depend on. Say which kind each test is in the task's Run log — the
reviewer cannot tell them apart from the diff.

**Test the documented invocation, not only the function.** A criterion like "the
system SHALL emit parseable JSON" is satisfiable by a unit test on `main()` and
still broken through the interface the docs tell people to use — a `make` recipe
that echoes its command onto stdout, a wrapper script that prints a banner, a
CLI that buffers. If a criterion describes what a *user or a script* sees, one
test must go through the path they actually use.

### 3. Green
Minimum code to pass, inside `files:` / `functions:` only. Not the elegant
refactor you noticed on the way. That's a different task, and you can propose it.

### 4. Tick as you go
The §Implementation checklist is a **live execution log**, not a form to fill in
at the end. Check each item the moment it's genuinely done, with the 7-char
commit hash:
```markdown
- [x] Refresh endpoint  `e4f5g6h`
```
Many items per commit = same hash on each. One item across commits = list both.
`(uncommitted)` is temporary and must be gone before any handoff. An agent
resuming your work — maybe on another platform tomorrow — starts at the first
unchecked box. That's the whole reason this is mechanical.

### 5. Commit
`type(E03-T07): summary` — conventional, task id, no AI co-author trailers (the
commit-msg hook strips them).

### 6. Self-review, honestly
Fill §Self-review before flipping status. Its checkboxes are the ones the
reviewer will check anyway; the only thing you gain by ticking them untruthfully
is a wasted review cycle with your name on it.
- `make test && make lint` green
- diff confined to §5 Files; §4 respected
- UI: `make design-verify SCREEN=<id>` **green** (rule 2 — non-negotiable)
- loading/error/empty states present
- no secrets or PII logged
- every ADR your files touch is honoured, or listed in §Deviations with a reason
- **introducing a durable counter/cursor?** grep for every other reader of
  the same table/row and decide, per reader, whether it must now consult
  the counter instead of deriving its answer from live data. A counter
  changes what "available"/"next" means for the whole table, not just the
  call site that motivated it — the counter's own reader can be correct
  while a sibling `SELECT` a few files away silently keeps the old, now-wrong
  assumption. (Real cost of skipping this: the same invariant broke four
  times in one epic — E03-T02, its own fix, the sweep-found sibling bug, and
  that fix's own fix — each time in a different reader of one table.)

### 7. Hand over
`status: review-requested` → push → PR to the **epic** branch → 📋 DEV STATUS
(what / why / how tested / risks). The orchestrator routes it to a reviewer on
a different model (rule 5).

## When you're stuck

**Small ambiguity** (the spec allows two readings, both fine): pick the simplest
that satisfies the acceptance criteria, note it in §Deviations, keep moving.
Don't stall on small things.

**Real gap or contradiction** (the spec is silent, or says two things): STOP.
Write it into `## Open Questions`, set `status: blocked`, fill §Handoff (what
you tried, why blocked, what would unblock, suggested next). Commit and push —
uncommitted work is invisible work. The queue moves on without you; that's the
system working, not you failing.

`spec/` wins on *what*. The ADRs win on *how*. The design wins on *how it looks*,
and the spec beats the design. Never improvise around a gap: an agent's guess
becomes a requirement nobody agreed to.

## Never
- Touch files outside `files:`. **Lockfiles are NOT a free pass**: a lockfile
  change means a dependency changed, which is 🧍 `new_dependency` (rule 3). Add
  the manifest and lockfile to `files:` in the same breath as getting that gate
  cleared — never as a silent side effect of `npm install`.

**Four gates fire on the *shape* of your diff, not on any stage — stop and get
each cleared the moment your work turns into one of them** (they are declared in
`harness.yaml`, and the reviewer checks for them):

| If your diff… | Gate |
|---|---|
| adds or edits a migration | 🧍 `db_schema_migration` |
| changes a manifest or lockfile | 🧍 `new_dependency` |
| touches `.env`, secrets or deployment config | 🧍 `secrets_or_env_change` |
| removes more than ~50 lines | 🧍 `delete_over_50_lines` |

None of these is detected for you. Naming your own gate is the job.
- Add a dependency, change a schema, touch auth/payment code, or delete >50
  lines without the 🧍 human gate.
- Refactor something unrelated because you were passing through.
- Review or merge your own work.

## Where to look next
- Your contract and its fence -> the task file - `skills/task-sharding`
- What you were given, and what you were deliberately not given -> `skills/agent-briefing`
- UI work: build from the contract, not the mockup -> `skills/design-fidelity`
- Cannot finish, or hit a rate limit -> `skills/handoff`
- A spec gap you must not close yourself -> `skills/question-resolution`
- What happens to your PR -> `skills/review`
