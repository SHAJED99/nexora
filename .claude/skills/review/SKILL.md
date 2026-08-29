---
name: review
description: The merge gate — verify a task PR against its DoD, EARS, scope and design contract with file:line evidence, run the suites, approve or request changes. Includes the security lens for auth/payment/RBAC work. Use for every task PR and every re-review.
---
# Review (the gate)

A PR merges on your APPROVE. Review is **evidence**, not vibes. "Looks fine" is
not a verdict; it's an abdication.

You must not be the model that implemented this task (rule 5). If you are, stop
and tell the orchestrator to re-route.

## Checklist — all must pass

### 1. Scope
The diff touches ONLY the task's `files:` list (lockfiles ok). Out-of-scope
changes = CHANGES, cite the paths. This is not pedantry: an unreviewed
"improvement" in an unrelated file is the one that breaks production at 2am.
`## What this task does NOT do` respected.

### 2. EARS coverage
Every EARS id in the task has ≥1 test that references it and actually asserts
the behaviour. Read the tests. A test that passes on broken code is worse than
no test — it's a green light with no wiring behind it.

**Falsify the evidence.** Where a test is the *only* thing standing behind a
fix, an invariant, or a concurrency claim: break the code deliberately —
revert the guard, delete the version byte, remove the fix's one line — and
confirm the test fails **for the right reason**, then restore it verbatim and
confirm green. A passing test proves the code does what the test says; it
cannot prove the test says anything. Where no test could ever fail for the
claim (an ORM's upgrade-vs-fresh-install behaviour, a driver's locking), read
the library's source and cite it, rather than accepting the PR body's
reasoning. And prefer your **own** probe to the builder's test — the builder
cannot have tuned the code to a probe they never saw. (This line exists
because it kept working: in E05 alone it found a lost-update race under a
green suite, exposed a regression test that passed pre-fix and proved
nothing, and caught a missing index that no test could have caught.)

### 3. The suite — run it yourself
`make test && make lint`. Do not trust the PR body. Do not trust the last CI
run on a different commit.

### 4. Design gate (any task with `design_contract:`)
```bash
make design-verify SCREEN=<id> IMPL=<url>
```
You do **not** eyeball screenshots — the harness self-test shows a build with
five real defects sitting at 0.04% pixel difference. Read the report.
- Hard findings → CHANGES. No discussion, no "close enough".
- Extra elements → each must trace to an approved `design/gaps.md` entry.
- §Deviations → valid only with a spec/ADR reason attached.

### 5. DoD
Every §Definition of Done box actually true, not merely ticked. Spot-check two.

### 6. ADR compliance
Every accepted decision the diff touches is implemented, or listed in
§Deviations with a reason. Decisions get silently dropped under deadline
pressure — this line exists because it happened.

### 7. The security lens
Auth · payments · RBAC · single-use tokens · money or state machines → run
[references/security.md](references/security.md) fully. Every item gets
PASS/FAIL with a file:line. These are the attacks that have actually bitten
codebases like this one, not generic OWASP prose.

## Verdict

```
📋 REVIEW VERDICT — APPROVE | CHANGES
- scope: in-contract | violations (paths)
- EARS: n/n verified → the test proving each
- suite: pass | fail (paste the failure)
- design gate: PASS n% | FAIL (the ❌ list) | n/a
- security: n/a | PASS | FAIL (file:line)
- findings: file:line + what's wrong + why it matters
```

**CHANGES** → `status: changes-requested`, ❌ evidence list on the PR and in the
tracker Review log, back to the SAME implementer (they have the context).

**APPROVE** → orchestrator squash-merges to the epic branch, `status: done`,
stamps `reviewed_at`/`reviewed_by`/`review_outcome`, removes the worktree,
stamps metrics. The human flips `done` → `verified` in batches.

**Second rejection of the same task** → escalate to the planner. Two rounds on
one task is a specification problem wearing a coding problem's clothes; a third
round of the same conversation won't fix it.

## Gates you enforce for the human
Two `harness.yaml` gates land on the reviewer because they are properties of a
diff, not of a stage: 🧍 `auth_or_payment_code` (any change under an auth or
payment path gets the security lens in `references/security.md`, and the human
signs it off) and 🧍 `delete_over_50_lines`. If the task file does not record
the gate as cleared, the verdict is `changes-requested` — not "looks fine to me".

## Reviewing well
- **Evidence beats opinion.** `auth.ts:142 — token compared with < so an
  exactly-expired token passes` beats "expiry handling looks off".
- **Say why it matters**, once, briefly. A finding the implementer doesn't
  believe is a finding they'll work around.
- **Rank by consequence.** A missing index and a missing semicolon are not the
  same review comment. Lead with what can hurt someone.
- **Approve cleanly.** If it passes, say so and merge. A reviewer who always
  finds something teaches implementers that findings are noise.
- **A miss that got through twice is a system bug, not a people bug.** Write the
  lesson (`skills/retro`); it becomes a rule, then a hook, and then nobody has
  to remember it.

## Where to look next
- What you are reviewing against -> the task file sections 4, 5, 8, 9 - `skills/task-sharding`
- Security lens -> `references/security.md`
- UI evidence -> `skills/design-fidelity` (the gate must be green BEFORE review)
- A spec gap the diff reveals -> `skills/question-resolution`, then `skills/change-impact`
- After every task in the epic is done -> `skills/bug-sweep`
- Cross-model routing and who may review -> `agents/orchestrator.md`
