---
name: codebase-analysis
description: Reverse-engineer an existing codebase into a baseline document — architecture, conventions, tests, debt — before genesis touches it. Use when the input includes an existing codebase (mode D) — before genesis, before any change — and again whenever the repo structure surprises an agent.
---
# Codebase Analysis (brownfield)

Greenfield genesis decides foundations; brownfield genesis **inherits** them.
This skill produces the inheritance document: `docs/codebase-baseline.md`.
No change lands, no ADR is written, no epic shards until the baseline exists
and is human-approved — otherwise every agent re-discovers the codebase
privately, and each discovers a slightly different one.

The governing posture: **existing conventions are law until an ADR says
otherwise.** This is rule 1's spirit extended to code — the repo is a spec that
happens to compile. You don't get to disagree with it in a diff; you disagree
with it in an ADR the human accepts.

## Procedure

### 1. Survey
Languages, frameworks, package manifests, lockfiles. The **build, run and test
commands** — from CI config and manifests, then verified by running them, not
by guessing from README prose (READMEs lie; CI doesn't). Entry points: main
modules, servers, CLIs, jobs.

### 2. Map modules and conventions
Domain boundaries as the code actually draws them, not as you'd redraw them.
Then the conventions law-list: naming, the error envelope, state management,
layering, DI style, test style. Each convention recorded with an example path —
a convention without an example is an opinion.

### 3. Data flow, APIs, integrations
Request paths end to end. Every exposed API surface. Every external service,
with its failure mode if discoverable. Schemas and migrations — the migration
history is the most honest changelog the repo has.

### 4. Test baseline
What test suites exist, what actually runs, coverage posture (even a rough
one). **Establish the green baseline: record the exact command and its exact
result, with the date.** "Tests mostly pass" is not a baseline; `pytest -q →
412 passed, 3 skipped, 2026-08-23` is. Every future "did we break it?" is
answered against this line.

### 5. Docs inventory
READMEs, ADR-like documents, wikis, inline architecture notes. Grade each:
current / stale / actively misleading.

### 6. Technical debt + inconsistencies
Record as **facts and risks — do NOT fix anything.** The scope fence applies
before there are even tasks (rule 6): an analysis pass that "just cleans up a
few things" has made unreviewed changes to a system it doesn't understand yet.
Debt goes in the register; fixing it goes through epics like everything else.

### 7. Write the baseline
`docs/codebase-baseline.md` from `templates/codebase-baseline.template.md`:
architecture map · conventions law-list · module table · integration map ·
test baseline · debt register · risk register.

### 8. Feed the knowledge map
Facts (F-nnn: "auth is session-cookie based, src/auth/"), constraints
("Postgres 14 is load-bearing"), architecture nodes. Commit:
`docs(knowledge): baseline from codebase analysis`.

### 9. Generate questions
Everywhere intent is unclear — dead-looking code that might be load-bearing,
two competing patterns, a half-finished migration — route to
`skills/question-resolution`. **Never resolve unclear intent by reading harder;
the author's intent is not in the code, or it would be clear.**

### 10. 🧍 HUMAN GATE (`codebase_baseline_approval`)
The human — ideally someone who knows the repo — corrects the baseline. A wrong
convention in the law-list gets enforced by every agent forever.

### 10b. Note what a first test will need
A repo with no tests has no test *harness* either. Before sharding, record what
the first test task must create beyond the test file itself — a runner config, a
dev-requirements file, a `conftest.py` or equivalent loader, a `make test`
target. These are easy to leave out of a `files:` fence, and the shard is then
wrong the moment anyone writes a test. Scripts invoked by a task runner rather
than imported as a package are the usual reason a loader is needed at all.

### 11. Hand off to genesis in brownfield mode
- **T00** consumes the baseline instead of starting domain analysis from zero.
- **T01** ADRs record EXISTING foundations with `status: imposed` — the stack,
  architecture and auth are documented as decisions that were already made,
  not re-litigated. New decisions still follow rule 3 in full.
- The **walking skeleton** = the existing app's health path, proven running
  (build → run → one real request) rather than built.

## When the repo surprises an agent mid-flight
An agent hits structure the baseline doesn't explain → don't improvise. Check
the baseline first; if it's silent or wrong, that's a baseline amendment
(re-run the relevant step, update the doc, `docs(knowledge)` commit) plus a
question if intent is unclear. A surprising repo is a documentation bug.

## Where to look next
- Route in from → `skills/project-intake` (mode D)
- Unclear intent → `skills/question-resolution`
- Facts and constraints land in → `skills/knowledge-map`
- After approval → `skills/genesis` (brownfield mode, §11 above)
- Changing what the baseline recorded → `skills/change-impact`
