# Human Guide — your loop, in five minutes

The harness is human-in-the-loop by design. Agents produce; **you** decide
business fit. This is everything you actually do.

## Day one — what you supply

| Put | Here | Becomes |
|---|---|---|
| BRD · SRS · feature list (any format) | `docs/business/` | `spec/` — atomic, greppable ids (genesis T00) |
| The design (Figma · HTML · React) | `docs/UI/` | `design/golden/` + `design/screens/` (genesis T03) |

Both are read-only history once converted. The conversion is the point: rule 1
needs a **greppable id** to be law, rule 2 needs a **measurable golden** — a
`.docx` and a mockup are neither.

## Four commands, daily

```bash
make status     # the board — every epic, every status
make next       # what runs now (make next LAYER=frontend for one lane)
make review     # what's waiting on review
make health     # is the harness still doing its job? (run it weekly)
```

Your sign-off flips reviewed tasks from `done` → `verified`.

## Your gates — where the system stops for you

| Gate | When | What you're deciding |
|---|---|---|
| **Foundational ADRs** | Epic 00 | stack, architecture, auth. The agent presents options + a recommendation; **you pick** (rule 3) |
| **Epic 00 exit** | after E00 | domain model + ADRs accepted, skeleton seen responding. The big one |
| **Design contracts** | after extraction | do these contracts match the design you meant? + the gap list |
| **Epic map + first wave** | after breakdown | right epics, right order, right priorities |
| **Analyze report** | before tasks dispatch | are the specs complete and consistent |
| **Bug priorities** | after each sweep | severity is the reviewer's; **priority is yours** |
| **Retro promotions** | after each retro | approve skill/rule edits — they're code |
| **Epic → development** | epic done | delegated to the agent, 2026-09-05 (once P1/P2 = 0 and rule 5's review gate has passed) — no longer a human click, but merges here are reversible and visible in the epic's own tracker/retro |
| **Release (dev → main)** | on release | ship it? — still yours |
| **Anything in `harness.yaml: human_gates`** | anytime | migrations, deps, secrets, auth |

Everything else runs agent-to-agent. You review *reviewed* work — your time goes
to judgement, not typo-catching.

## Giving feedback — anytime, on anything

Just say it. The planner routes it (`skills/epic-breakdown` §Injecting work):

| You say | It becomes |
|---|---|
| "this button is wrong" | reopens that task → its `## Feedback log` |
| "X is broken" | a bug task — **you set P1–P4**; P1 preempts running work |
| "we also need Y" | an SRS amendment + task/epic, scored into the queue (you approve) |
| "agents keep doing Z" | a lesson now; a promotion proposal at the next retro |
| "from now on, always…" | a constitution edit + an ADR (you approve) |

In-progress tasks are never silently edited. New work enters as new work.

## The design gate — why your UI will actually match

```bash
make design-verify SCREEN=login IMPL=http://localhost:3000
```

Every screen with a design is measured, not eyeballed: missing elements, copy
character-for-character, styles against the design's own tokens. Hard findings
block the merge.

**Why this exists:** `make design-selftest` shows a build with a missing
checkbox, two rewritten strings, a wrong accent and a wrong radius rendering
**0.04% different by pixel comparison**. You would have approved it. So would
any reviewer. That's not carelessness — it's a task beyond human perception, and
v1 assumed otherwise.

What you should watch for: **anyone loosening `design/thresholds.yaml`**. That's
the one change that silently switches this off — so `make health` now fails on
any threshold weaker than the shipped baseline unless it's declared with a reason
and an approver. You don't have to police it by memory; run `make health`.

## Rate limits

The statusline shows window usage. At ~80% the orchestrator freezes work into
handoff packets and resumes on the next platform in `harness.yaml`. You get a
notice. Nothing is lost, and nothing depends on chat history.

## When something shipped wrong

**Redeploy the previous tag FIRST. Then revert. Then diagnose.**

| Situation | Action |
|---|---|
| bad task merged | revert that one squash commit on the epic branch |
| bad epic in dev | revert its merge commit |
| bad release | redeploy `vX.Y.Z-1`, *then* revert on main |

Details: `agent/skills/release/SKILL.md`.

## Reading the system's learning

```bash
make lessons     # what keeps biting, and what should be automated next
```

Lessons with `recurrence >= 2` are promotion candidates: they become rules in
skills, then hooks. You approve each promotion — a bad lesson promoted to a rule
makes every future agent worse, invisibly, forever. That gate is yours because
nobody re-reads a skill file to check whether it's still true.
