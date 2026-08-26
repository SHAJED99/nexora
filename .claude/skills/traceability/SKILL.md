---
name: traceability
description: Compute the requirement → epic → ADR → task → code → test → doc chain from the actual files and render docs/traceability.md, flagging orphans in both directions. Use at the release gate, at epic close, before any scope negotiation, and whenever asked whether a requirement is really implemented.
---
# Traceability

Answers two questions nobody can answer from memory: **"is this requirement
actually built?"** and **"why does this code exist?"** — the second one being
the question every maintainer asks at 2am about a line nobody claims.

**The report is computed, never maintained.** Every number in
`docs/traceability.md` is derived from files that already exist — `spec/srs.md`
ids, `traces_to:` frontmatter, `files:` lists, EARS-named tests. A
hand-maintained traceability matrix is a lie with a timestamp: it agrees with
the repo exactly once, on the day someone wrote it. If this skill and the repo
disagree, the repo wins and the report is stale — regenerate, never patch.

Distinct from `skills/knowledge-map`: the map is the **index** (nodes and
edges, maintained continuously as work happens). This skill is the **audit**
(walk the chain end to end, prove each hop against a file, report what's
broken). The map says a link should exist; traceability checks whether it does.

## The chain
```
FR-AUTH-007  (spec/srs.md)
   ├─▶ E02                     epics/E02-<slug>/ — feature that implements it
   ├─▶ ADR-0005                agent/memory/decisions/ — decision that constrains it
   ├─▶ E02-T04                 task with FR-AUTH-007 in traces_to:
   │      ├─▶ src/auth/reset.py        task frontmatter files:
   │      ├─▶ test_EARS_AUTH_1_*       EARS criterion → test name
   │      └─▶ 8f3c1ab                  commit referencing E02-T04
   └─▶ docs/conventions.md · design/screens/reset.md
```
Seven hops. A requirement is **proven** only when the chain reaches a passing
test; everything short of that is a requirement someone believes in.

## Procedure

### 1. Harvest the ids
Read, don't infer:
- requirements → `FR-`/`NFR-` ids in `spec/srs.md` (+ `UC-` use cases)
- features → `epics/E<NN>-<slug>/epic.md` and their `traces_to:`
  (**exactly this shape** — `scheduler.py` globs `epics/E*/epic.md` and
  `epics/E*/tasks/*.md`; a lowercase `epic-01-core/` matches on Windows and
  silently matches nothing on Linux)
- decisions → ADR ids and `status:` in `agent/memory/decisions/`
- tasks → every task file's `id`, `traces_to:`, `files:`, `status`
- tests → `grep -r "test_EARS_"` across the test tree, then **check they pass**
  — a test that exists is coverage, a test that passes is proof
- design → `design/screens/*.md` contracts, `design/gaps.md` GAP ids
- commits → `git log --grep="<task-id>"` for the hash column

### 2. Join, and record every failed join
The joins are where the truth is. A requirement id in `traces_to:` that doesn't
exist in `spec/srs.md` is not a formatting problem — it's a task building
something nobody specified.

**The EARS→requirement join is the one that bites.** An EARS criterion cites its
requirement ids inside its own bullet, and a criterion *wraps onto a second
line* — so match to the end of the **bullet** (next bullet, blank line or
heading), never to end-of-line. A requirement heading also owns the bullets
beneath it, so an uncited bullet still resolves to its parent. Anchor this wrong
and the report says **0% proven**, which reads as a catastrophic project failure
rather than a broken regex. Sanity-check the join before believing the number:
if the suite is green and coverage is 0%, the harvest is broken, not the project.

**Prose cross-references do not count.** A requirement whose only link to a test
is English — "proven by EARS-CORE-1" in the SRS body — is invisible to the join
and will report as untested. Every requirement must **own at least one EARS id**;
if a criterion genuinely covers two requirements, cite both ids in the bullet.

### 3. Detect orphans — both directions
Forward gaps hide missing work; backward gaps hide unspecified work, which is
worse, because unspecified work still ships.

| Orphan | Means | Route to |
|---|---|---|
| requirement with no epic | scope never planned | `skills/epic-breakdown` |
| requirement with no task | epic never sharded, or sharded incompletely | `skills/epic-breakdown` |
| requirement with no test | rule 7 breach — unproven, not done | new test task |
| `done` task with no passing test | "done" that isn't | revalidation task |
| task with empty `traces_to:` | rule 1 breach — it isn't a task | `skills/question-resolution` |
| test matching no EARS id | proves nothing traceable | rename or delete task |
| code file no task's `files:` claims | arrived outside the harness | `skills/change-impact` |
| ADR nothing cites | dead decision, or decisions being made in diffs | audit or supersede |
| design contract no task builds | rule 2 breach — screen unbuilt or built off-contract | `skills/design-fidelity` |
| `superseded` ADR still cited | task honouring a reversed decision | `skills/change-impact` |
| `done` task whose `depends_on` is not done | state-ordering violation — it was built on unmerged work. **`make validate` does NOT catch this**: the DAG is checked for cycles and unknown ids, not for status order | `skills/review` (re-gate both) |
| task carrying a 🟡 open question | blocked in fact but maybe not in status | `skills/question-resolution` |
| requirement with a test that exists but fails or skips | coverage without proof | fix or revalidate |

### 4. Render `docs/traceability.md`
Coverage summary (requirements: total / with task / with test / proven),
the full chain matrix, the orphan tables by class with counts, and the
generation stamp (date + commit). Commit as
`docs(trace): regenerate traceability matrix`.

### 5. Report, do not repair
**Fixing an orphan is out of scope here** — the scope fence (rule 6) applies to
audits too. An audit that also edits is an audit you can no longer trust to
tell you what it found. Every orphan leaves as a routed task, question or
impact report, never as a quiet commit.

### 6. Feed the gates
- **epic close** — no `done` task in the epic may lack a passing EARS test, and
  every FR the epic claims is covered.
- **release** (`skills/release`) — blocking orphan classes are release blockers,
  not release notes.
- **scope negotiation** — "is FR-X done?" is answered from this report, never
  from a status field. `status: done` is a claim; the chain is evidence.

## Scoped runs
Given one id, walk only its neighbourhood: an `FR-` walks forward to tests, a
task id walks backward to its requirement and forward to its tests, a file path
walks backward to the task and requirement that justify it. The file-path walk
is the "why does this code exist?" query — and a file that walks back to
nothing is the finding.

## Smell tests
- 100% coverage on the first ever run → the joins are matching too loosely
  (substring instead of whole-id is the usual culprit).
- **0% coverage while the suite is green → the joins are broken**, not the
  project. Check the EARS→requirement anchor first (§2).
- A package file (`__init__.py`, `mod.rs`, `index.ts`) in *code no task claims* →
  it was created outside a `files:` fence. Common and real: shards forget that a
  new module needs its package file listed.
- Zero orphans and a repo with untracked files → the harvest missed a tree.
- A requirement `proven` whose only test is skipped → a skip is not a pass.
- The report edited by hand in a diff → revert; it's generated.

## Where to look next
- The index this audits → `skills/knowledge-map`
- Missing coverage becomes work → `skills/epic-breakdown` · `skills/task-sharding`
- Unclaimed code or reversed decisions → `skills/change-impact`
- Consumes this report → `skills/release` (release gate) · `skills/review`
- Command → `/agentic-dev-workflow:trace [id]`
