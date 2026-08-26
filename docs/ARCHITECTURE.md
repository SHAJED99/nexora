# Architecture — why the harness is built this way

The reasoning behind v2: what problem it solves, what we optimized for, what it
buys you, and — at equal length — what it costs you and where it breaks.

This is **harness documentation**, not project memory. Project memory lives in
`agent/memory/lessons/` and is written by your own retros.

Read this before "simplifying" a gate. Most gates here exist because something
got through, and every one looks like overhead right up until it earns its keep.

---

## 1. The problem this is built for

A capable coding agent, given a real spec and a real design, produces work that
is *approximately* right. Individually every miss is defensible. Collectively
they are a product that isn't what you asked for:

- a field dropped because the API wasn't ready yet
- a label rewritten because the new wording read better
- an accent colour one shade off
- an accepted architecture decision silently not implemented
- scope creep that fixed the ugly code next door
- the same mistake again next epic, by the next agent

Note what these share. **None are intelligence failures.** They are failures of
*ground truth* (nothing precisely said what "right" was), of *scope* (nothing
said where to stop), and of *memory* (nothing carried forward what was already
learned).

So the harness doesn't try to make agents smarter. It makes "right"
unambiguous, "done" checkable, and "learned" permanent.

## 2. What we optimized for

Seven principles. Every structural decision below follows from one of them.

**1. Mechanism beats instruction.**
A hook beats a rule beats a lesson. "Remember to X" is the weakest control that
exists, and it's everyone's first idea. A hook can't be forgotten, skimmed, or
lost to a context window. Clearest case: the design gate. The *rule* ("compare
the build to the design") was being followed, and drift shipped anyway. Only the
mechanism worked.

**2. Measure what you claim.**
If a gate says "matches the design", something must compute a number. Otherwise
"matches" quietly degrades into "nobody objected" — not the same thing, and it
fails silently. Corollary: a gate making a strong claim should have a test that
proves it (`make design-selftest`).

**3. Ground truth must be small enough to actually read.**
A 425KB design bundle and a 90-page docx are technically the source of truth and
practically ignored — not by choice; the size chooses for you. Hence `spec/`
(atomic greppable ids) and `design/screens/<id>.md` (~150-line contracts).
Converting raw input into addressable truth **is** the work, not clerical
overhead.

**4. Context is the scarce resource.**
Everything loaded competes with everything else. Optional template sections,
duplicate docs, an unused MCP server, a rule that never fires — each is a small
permanent tax on every task, and together they push what matters past where
attention runs out. Deletion is a feature.

**5. Nothing depends on chat history.**
A task file + git + (for freezes) a packet contain everything. The moment a
handoff needs "what we discussed earlier", you are one crashed session from lost
work and one model swap from lost quality. This is what makes multi-platform,
resumption and parallel agents possible at all.

**6. Independence comes from routing, not roles.**
Two role files aren't two perspectives if both run on the same model. Real
independence is a different model — ideally a different vendor — reading the
diff.

**7. Humans decide; machines verify.**
Human attention is the scarcest thing here. Spend it on judgement — is this the
right product, the right stack, the right priority — and never on typo-catching
or pixel-comparing, which machines do better and tirelessly.

## 3. The architecture, and why each piece exists

### The constitution — `AGENTS.md`, 10 rules, always loaded
Always-on rules must be short or they get skimmed (principle 4). Ten rules, each
mechanically consequential. Depth lives in skills, loaded on demand.

### 10 skills, no workflows layer
v1 had 17 skills + 12 workflows + a protocol doc. The split was "skills carry
depth, workflows carry order" — sensible on a whiteboard, with **no mechanical
meaning**. Nothing enforced which file owned what, so both carried both and they
drifted apart. 29 files → 10, each with procedure + depth + 🧍 gates inline.

### 5 roles
`orchestrator` (the loop) · `planner` (spec→epics→tasks, ADRs) · `builder` ·
`builder-ui` · `reviewer`.

v1 had 7, including a `peer reviewer` and a `qa` doing near-identical work —
modelling independence as *more roles* instead of *different models* (principle
6). v2 has one reviewer, routed twice: per-task (model ≠ executor) and per-epic
(the sweep). `pm` + `team-lead` → `planner`; `devops` → `builder`.

### The task file is the contract
`files:`, `api_contracts:`, `functions:` and the scope fence are binding. This is
what makes review mechanical (diff ⊆ `files:`), parallelism safe (the scheduler
skips file collisions), and improvisation visible.

Nine sections, all load-bearing. v1's 18-section template had most tasks filling
half with "None." — and every boilerplate "None." teaches that this document can
be skimmed. Then the sections that *matter* get skimmed too.

### The design gate — the reason v2 exists
```
design source ──extract──▶ golden (probe.json + page.png)   ← committed: the law
                              ├──contract──▶ screens/<id>.md ← what agents read
   built app ──────verify────┴──▶ missing · copy · style · tokens · pixels
                                  hard findings block the merge
```

**The finding that drove it:** v1 told the reviewer to screenshot the route and
compare it to the design by eye. Drift shipped anyway. Measured on
`design/tools/selftest-data/`: a build missing a checkbox, with two rewritten
strings, a wrong accent (`#059669` → `#10b981`) and a wrong radius (7px → 12px)
renders **0.04% different by pixel comparison**. No amount of care fixes that —
it isn't an attention problem, so "review more carefully" was never going to
work.

**Hard vs soft is the crux.** Structure, copy and tokens are hard: an
implementation controls them completely, so drift has no excuse. Pixels and
layout are soft: real apps render real data in real fonts, so a *perfect* build
still moves pixels. Gate on pixels and agents learn to game screenshots; gate on
structure and they learn to build the design.

**Matching is by role + words + geometry, never CSS selector.** The build may use
any tags or class names; it may not lose the thing. The self-test proves it: a
faithful port with entirely different markup scores 100%.

### Memory: files, and a hook that delivers them
v1 wrote lessons to `memory/lessons/`, then hand-pasted the important ones into
`agent/agents/developer-backend.md`. Two copies, one source, no sync — the role
file grew, the lessons directory stagnated. Every rung of the ladder needed a
human to remember, and remembering doesn't scale past the first busy week.
**Learning that needs a human to copy it isn't learning.**

v2: `lesson-inject.py` (UserPromptSubmit hook) finds the task id, reads its
`layer:`/`files:`, and injects that area's lessons — recurrence-ranked, once per
session, failing open. Role files carry boundaries; `memory/lessons/` carries
knowledge.

**The ladder:** lesson (1st) → rule in the owning SKILL.md (2nd) → hook/lint/test
(checkable, or 3rd). `make lessons` surfaces candidates. Recurrence is the only
number that knows what to automate next.

Graphiti (a temporal knowledge graph) was dropped: a server dependency for
relationships that files and git already record.

### The scheduler
Reads task frontmatter; picks the highest-priority unblocked task that doesn't
collide on files with anything in flight. `--validate` enforces what's
checkable: every task traces to a spec id (rule 1), every frontend task has an
existing design contract (rule 2), the DAG is acyclic (rule 4).

### Handoff + multi-platform
Kept deliberately. Cross-platform review is the strongest form of rule 5, and
freeze packets are how work survives the 5-hour wall. Packets exist because
principle 5 says a resuming agent gets the packet + task file + AGENTS.md —
never the old chat.

### The human gates
`harness.yaml: human_gates`. Foundational choices (stack, architecture, auth),
business fit, bug priority, and every promotion of a lesson into a rule. On a
foundational choice the agent presents options + a recommendation and **stops**.
An agent that quietly picks the stack has made the project's most expensive
decision without review.

## 4. What this buys you

- **Design fidelity that's real, not claimed.** Drift caught by a number, in
  seconds, with a file-level report you can paste into a PR. It ends the "looks
  fine to me" conversation permanently.
- **Fidelity compounds.** Screens 5–20 land near-green first try, because the
  primitives are already right and the gate proved it.
- **Improvisation becomes visible.** Extra elements, missing elements, dropped
  ADR decisions, out-of-scope diffs — each has a mechanism that surfaces it.
- **Work survives everything.** Crashed session, rate limit, model swap, a
  different CLI, you disappearing for a week. Nothing lives in chat.
- **Safe parallelism.** The DAG + file-collision check let several agents run
  without merge pain.
- **Learning compounds.** Each retro either adds evidence or promotes something
  into a mechanism that can't be forgotten.
- **Cheap wrongness.** The Analyze gate and the design-contract gate catch spec
  and design misreads before five screens are built on them.
- **Attention spent on judgement.** You review reviewed work.
- **Portable.** No product knowledge anywhere in the harness. Point it at a
  different spec and design; it works.

## 5. What it costs you, and where it breaks

The honest half. Skipping this section is how people adopt a system and then
resent it.

### Cost and fit
- **Genesis is slow.** Domain analysis, ADRs, conventions, design contracts, a
  walking skeleton — days before the first feature. On a two-week throwaway this
  never pays back. **The harness is wrong for prototypes, spikes and anything
  you intend to delete.**
- **It amortizes over tasks.** The design gate pays for itself around screen
  3–5. Below that you did extra work for nothing.
- **Real token cost.** An opus planner, cross-model review, lesson injection on
  every task. `make metrics` exists because this is worth watching.
- **You are the bottleneck.** Many gates route to you. Batch them (target ≤10
  interrupts/session) or throughput collapses to your response time.

### The design gate's actual limits
It's the most load-bearing component, so be precise about what it does *not* do:

- **It doesn't judge whether the design is good.** It enforces conformance. A
  bad design gets faithfully built.
- **Structural parity ≠ visual identity.** Layout is soft by necessity, so a
  build can pass every hard check and still feel subtly off in spacing rhythm.
  `diff.png` is the backstop, and it needs a human.
- **Dynamic content fights it.** Timestamps, counts, avatars, live data. You
  manage that with `ignore_text` and `mask` — **and both are abusable**. A wide
  mask produces a green report that means nothing, and it is invisible to whoever
  reads the green.
- **Canvas, charts, maps and video are near-opaque** to a DOM probe. They get
  masked, and masked means unverified.
- **Animation and transient states aren't checked.** The probe freezes the page.
- **Interaction, semantics and accessibility aren't checked.** Focus order, ARIA
  correctness, keyboard traps, contrast — none of it. The gate proves the build
  *matches the design*; it says nothing about whether either is usable.
- **Role changes read as drift.** An agent improving `<span>` → `<label>` gets
  flagged missing+extra. Arguably correct (semantics changed), but it's friction
  and needs a §Deviation.
- **Geometry matching can mispair** unlabelled surfaces on dense screens,
  producing confusing style deltas on the wrong element.
- **Extra elements only warn.** A build that *adds* things drifts more quietly
  than one that drops them.
- **Responsive multiplies cost.** Every viewport × state is another golden to
  capture, review and keep current.
- **Figma import is the weak path.** Roles inferred from layer names; styles from
  node fills rather than rendered CSS. `Frame 247` tells it nothing. Tolerances
  start looser, so the gate starts weaker. An HTML export is meaningfully
  better — that's why we recommend it.
- **Golden churn.** Every design change re-extracts and re-verifies affected
  screens. That's the point, but it's ongoing work, and a fast-moving design
  makes it constant.
- **`thresholds.yaml` is a kill switch.** One person loosening it under deadline
  silently disables the subsystem — forever, for every screen. It's a human gate
  for exactly that reason, and it is still the most likely way this dies.

### Process limits
- **Spec-is-law is brittle in one direction.** If the SRS is wrong, the harness
  builds the wrong thing faithfully, quickly, with full traceability. Rigour is
  not correctness.
- **Rule 6 causes friction.** A slightly-wrong `files:` list blocks work on a
  trivial change. That's the trade for mechanical review; sometimes it's a bad
  trade for the task in front of you.
- **One review gate is less redundant than three.** It relies on the routing
  actually differing. Route a Sonnet review of Sonnet work and you have
  ceremony, not independence.
- **Merging PM + Team Lead lost a reader.** The planner now analyzes specs it
  wrote. Fresh-context self-review is weaker than a second person; on a big epic,
  route Analyze to a different model deliberately.
- **The lesson hook is heuristic.** It needs a task id in the prompt. No id →
  silent no-op. It's a memory aid, not a guarantee, and it fails open by design.
- **Lessons start empty and stay empty until you run retros.** The compounding is
  real but back-loaded. Skip retros and the learning apparatus is dead weight.
- **A bad lesson promoted to a rule is invisible damage.** It makes every future
  agent worse, and nobody re-reads skills to check whether they're still true.
  Hence the human gate; hence pruning.
- **Collision detection trusts `files:`.** A sloppy list and two agents collide
  anyway.
- **Estimates only calibrate if someone does it** (retro step 5).

### Operational limits
- **Playwright + a Chrome/Chromium** must exist wherever the gate runs, CI
  included. It falls back to system Chrome, but it is a real dependency.
- **The probe captures light theme, reduced motion, one device scale.** Dark mode
  is a separate state you must declare.
- **Codex/OpenCode adapter flags drift.** Their CLIs change; the adapters carry
  "VERIFY flags" comments for a reason.
- **`cost-config.yaml` goes stale.** Vendor prices move monthly.
- **Contract regeneration overwrites everything above the hand-written marker.**
  Edit above it and you lose it.

## 6. When not to use this

- prototypes, spikes, demos, anything disposable
- exploratory or research work where the spec *is* the output
- projects where you're inventing the UI as you go — there's no design to be
  faithful to, and the gate has nothing to measure
- a solo dev moving fast on something small and well-understood
- teams that won't run retros or won't answer gates (the harness stalls at your
  slowest gate)

It fits: a real spec, a real design, many screens, work spread over months and
across sessions and models, where consistency and traceability actually matter.

## 7. How this dies quietly — and the check that catches it

```bash
make health            # the seven decay checks
make health STRICT=1   # warnings fail too (wire this into CI)
```

This harness will not fail loudly. Nothing will crash, no test will go red. It
will be dismantled one locally-reasonable decision at a time, by people acting
in good faith under deadline, and the first symptom will be a product that
quietly stopped matching its design about four months ago.

Each decay below shares a signature: **it removes a control while leaving the
appearance of one.** The gate still runs. The report still says green. The
directory still has lessons in it. That's what makes them dangerous, and it's
why the earlier drafts of this section — a list that asked you to *watch for
these* — were the weakest thing in the document. §2 rule 1: a lesson is the
weakest control that exists. A section warning about decay had no business being
one. So it's a hook.

| # | Decay | Why it happens | What it costs | Detector |
|---|---|---|---|---|
| 1 | `thresholds.yaml` loosened "just for now" | one screen is red at 5pm | applies to **every screen, forever**; the fastest way to disable the whole subsystem | **H1** — fails on any value weaker than the shipped baseline |
| 2 | `mask:` / `ignore_text:` widened until green | the chart keeps failing | green now means "we didn't look"; **invisible to whoever reads the green** | **H2** — fails on page-wide masks and catch-all regexes |
| 3 | Retros skipped | there's always a next epic | recurrence never climbs, so nothing is ever promoted; the learning apparatus becomes pure cost | **H3** — fails on a `done` epic with no `retro.md` |
| 4 | Scope fences left empty | the planner was in a hurry | the agent fills the space with its own judgement, which is not the plan | **H4** — fails on a §4 that's empty or still template text |
| 5 | Review routed to the executor's model | it was already loaded | ceremony, not independence — same model, same blind spots | **H5** — fails on `reviewed_by == executed_by`, or missing |
| 6 | Lessons written, never promoted | writing feels like progress | the directory becomes a graveyard; each entry taxes context and changes nothing | **H6** — fails on `recurrence >= 2` still marked `lesson` |
| 7 | Gates skipped "once" | the deadline | a gate skipped once is a gate; skipped twice is a suggestion | **H7** — fails on `done` without a recorded APPROVE, or a frontend task with no contract |

**The escape hatch is deliberate, and it is the point.** Sometimes you genuinely
must loosen a threshold — live charts really do render pixel noise. So H1 doesn't
forbid it; it forbids doing it *silently*. Declare it in `thresholds.yaml`:

```yaml
relaxations:
  soft.pixel_mismatch_max_pct:
    reason: "the dashboard renders live charts; pixel noise is data, not drift"
    approved_by: "<human>"
    date: 2026-07-15
```

Now it's a warning that carries its reason and its author to everyone who reads
the report, forever, instead of a number nobody noticed changing. **The goal was
never to prevent the decision — it was to prevent the decision from being
invisible.** That distinction is the whole design: an undeclared relaxation
fails; a declared one is fine and stays visible.

The seventh way, the one no script catches: **treating a `make health` failure as
noise to be silenced.** Each finding you accept without fixing is a `process`
lesson (`skills/retro`), not a shrug. If you find yourself adding relaxations
faster than you remove them, the harness isn't the thing that's broken.

## 8. What was dropped, and why

| Dropped | Why |
|---|---|
| `token-optimization` (6 files) | six files of instructions to save tokens. Native now. |
| `graphiti` + its MCP server | a server for relationships files and git already record |
| `mcp-connections` skill | `agent/mcp/README.md` says it once |
| `dashboard_build.py` (326 lines) | a cost console; `make metrics` answers it in text |
| `workflows/` (12 files) | duplicated the skills |
| `statusline-ratelimit.sh` | a 12-line wrapper; folded into `ratelimit_guard.py` |
| 9 template sections | they said "None." |
| 2 of 3 review gates | they re-caught what the first caught |

## 9. Where it should go next

Honest backlog, roughly by value:

1. **Interaction and a11y checks** in the gate — focus order, contrast, keyboard
   paths. The biggest hole in the strongest component.
2. **Between-screen consistency** as a mechanism. Today it's a design-source
   problem resolved by humans; it could be a check across goldens.
3. **A lint rule for recurring runtime traps**, pushing rules down to hooks.
4. **Mask/ignore auditing** — report how much of the screen was excluded, so a
   green report can't hide a wide mask.
5. **Design-token extraction into the build's token file**, closing the loop so
   off-palette values become impossible rather than merely detected.
6. **Semantic diffing of the golden** on re-extract — "the accent changed on 12
   screens" instead of a raw file diff.
