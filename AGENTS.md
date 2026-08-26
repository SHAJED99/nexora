# AGENTS.md — Harness Constitution (always-on rules)

> The single cross-tool entry point (AGENTS.md open standard). Claude Code,
> Codex CLI, OpenCode and Cursor read this natively or via a thin adapter
> (see CLAUDE.md). Keep it SHORT — it loads on every turn. Depth lives in
> `agent/skills/` and is loaded on demand.

## What this repository is

A **spec-driven, design-faithful, multi-agent, human-in-the-loop harness** for
building software. `spec/` is law for *what*; `design/` is law for *how it
looks*; the accepted ADRs in `agent/memory/decisions/` are law for *how it is
built*. Work flows:

```
input (idea|PRD|SRS|design|code) ─▶ intake + questions ─▶ knowledge map ─▶ spec/ + design/ ─▶ Epic 00 (genesis) ─▶ Epics ─▶ Tasks ─▶ gated PRs ─▶ development ─▶ main
```

## The ten rules

1. **Spec is law.** Never implement behavior that does not trace to an SRS id,
   an EARS criterion, or an approved task file. Spec silent → write the
   question into the task's `## Open Questions` and STOP.
2. **Design is law.** Any screen with a design source is built against its
   contract in `design/screens/<id>.md` and must pass `make design-verify`
   before review. The design wins over agent taste; the spec wins over the
   design. A journey the design omits is *derived* from the spec — marked
   `source: derived` in `design/gaps.md`, consistent with existing design
   primitives, and human-approved. Never silently drop a design element, and
   never silently invent one.
3. **The human decides foundations and business fit.** Stack, architecture,
   datastore, auth strategy, schema migrations, new dependencies, secrets,
   deletions >50 lines, auth/payment code, and every merge into `development`
   or `main` are human calls. On a foundational choice the agent PRESENTS
   options with honest trade-offs and an advisory recommendation, then STOPS
   (ADR stays `⏳ AWAITING HUMAN`). Choices *within* an accepted ADR are the
   agent's.
4. **One task = one branch = one worktree.** `development` (integration) →
   `epic_<NN>` → `epic_<NN>_task_<MM>`. Never commit directly to `main`,
   `development`, or an epic branch. Promotion is by PR only.
5. **Every merge passes the gate.** `reviewed_by` ≠ `executed_by` — a
   different model reviews than implemented. Task PR → review gate → epic
   branch. Epic complete → bug sweep → human gate → `development`.
6. **The task file is the contract.** `files:`, `api_contracts:`, `functions:`
   and `## What this task does NOT do` are binding. Never invent APIs, fields
   or paths; never refactor outside scope; never upgrade deps. Deviation =
   stop, log to `## Open Questions`, request review.
7. **Done means proven.** Checklist ticked with commit hashes, DoD checked,
   tests green, and — for design-bearing UI — `make design-verify` green.
   "Looks right" is not evidence.
8. **Memory before work, lessons after.** Before starting: read the task file
   fully and the lessons for its area (`agent/memory/lessons/`, auto-injected
   by the lesson hook) plus ADRs touching its files. After a miss: write the
   lesson. Recurrence promotes it to a rule, then to a hook.
9. **Log everything.** Every headless run lands in `runs/<task_id>/`; every
   completed task appends a row to its epic's `metrics.csv`.
10. **Commit style.** Conventional commits referencing the task id —
    `feat(E03-T07): add refresh-token endpoint`. No AI co-author trailers
    (enforced by the commit-msg hook).

## Where to look next (load on demand, not by default)

| Need | Read |
|---|---|
| Your role & boundaries | `agent/agents/<role>.md` |
| How to do the thing | `agent/skills/<skill>/SKILL.md` — each carries procedure + gates |
| Design fidelity (the UI gate) | `agent/skills/design-fidelity/SKILL.md` · `design/README.md` |
| Project decisions / lessons | `agent/memory/decisions/` · `agent/memory/lessons/` |
| Topology, budgets, gates | `harness.yaml` |
| External platforms | `agent/mcp/README.md` |
| Current work queue | `make next` |
| Watch the whole run in a browser | `make dashboard` (or `make dashboard PORT=9999`) |
| Your gates as the human | `docs/HUMAN-GUIDE.md` |
| How to drive the workflow (commands, in order) | the plugin's `GETTING-STARTED.md` |
| Classify the input, write the intake report | `agent/skills/project-intake/SKILL.md` |
| Surface and resolve blocking questions | `agent/skills/question-resolution/SKILL.md` |
| Build/maintain the knowledge map | `agent/skills/knowledge-map/SKILL.md` |
| Baseline an existing codebase (brownfield) | `agent/skills/codebase-analysis/SKILL.md` |
| Assess a scope change before re-planning | `agent/skills/change-impact/SKILL.md` |
| Requirement → task → test coverage matrix | `agent/skills/traceability/SKILL.md` |
| Which agent runs a task, and the context it gets | `agent/skills/agent-briefing/SKILL.md` |

## Skills (17 — the whole process surface)

`project-intake` · `question-resolution` · `knowledge-map` ·
`codebase-analysis` · `change-impact` · `traceability` ·
`genesis` · `epic-breakdown` · `task-sharding` · `implement` ·
`design-fidelity` · `review` · `bug-sweep` · `retro` · `handoff` · `release` ·
`agent-briefing`

The six intake-side skills: `project-intake` (classify the input, write
`docs/intake-report.md`) · `question-resolution` (track questions to answers,
none blocking before genesis) · `knowledge-map` (maintain
`spec/knowledge-map.yaml`, the known/unknown ledger) · `codebase-analysis`
(brownfield baseline → `docs/codebase-baseline.md`) · `change-impact` (score a
scope change → `docs/impact/IMP-nnn` before re-planning) · `traceability`
(the requirement → task → test matrix in `docs/traceability.md`).

Each SKILL.md carries **both** the depth and the step order, with 🧍 human
gates marked inline. There is no separate workflows layer.

## Ids and artifacts (intake extension)

Questions `Q-<AREA>-nnn` (`spec/questions.md`) · assumptions `A-nnn` · impact
reports `IMP-nnn` (`docs/impact/`). New artifacts: `docs/intake-report.md`,
`spec/questions.md`, `spec/knowledge-map.yaml`, `docs/codebase-baseline.md`,
`docs/impact/`, `docs/traceability.md`.

## Project conventions (filled by Epic 00 — keep updated)

> **Rule 3** — the HUMAN picks these during genesis. Until then they stay
> placeholders. When Epic 00 completes, the planner replaces each line with a
> one-line summary and a link to the accepted ADR.

- Local persistence: Drift (SQLite, type-safe Dart ORM) — `agent/memory/decisions/ADR-0001-local-persistence.md`
- Architecture: GetX + MVC + Clean Architecture, per [SHAJED99/getx_mvc](https://github.com/SHAJED99/getx_mvc) — `agent/memory/decisions/ADR-0002-app-architecture.md`
- Cryptographic protocol: Signal Protocol (X3DH + Double Ratchet) for 1:1, Sender-Keys-style group scheme layered for membership-change rotation — `agent/memory/decisions/ADR-0003-crypto-protocol.md`
- Native transport integration: Pigeon (type-safe codegen over Platform Channels) — `agent/memory/decisions/ADR-0004-native-transport-strategy.md`
- Auth/session strategy: independent sessions — Firebase Auth is a thin account pointer, device identity/session is fully local — `agent/memory/decisions/ADR-0005-auth-session-strategy.md`
- Observability: a dedicated crash/error tool (e.g. Sentry), no usage analytics for v1 — `agent/memory/decisions/ADR-0006-observability-services.md`
- Naming & patterns: _(docs/conventions.md — pending genesis T02)_
- Design system: _(docs/design-system.md + design/screens/ — pending genesis T03)_
