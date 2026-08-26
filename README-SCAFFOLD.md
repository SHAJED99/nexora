# README-SCAFFOLD — what this directory is

This directory is the **harness project scaffold**. It is not run in place —
the plugin's `/harness-init` command copies it into a target project's root.
Everything here lands at the target project's top level with the same relative
paths (`AGENTS.md`, `harness.yaml`, `agent/`, `design/`, `docs/`, `epics/`,
`runs/`, …).

## What is deliberately NOT here

`agent/agents/` and `agent/skills/` are **not** in the scaffold. The plugin
ships those at plugin level; `/harness-init` symlinks or copies them into the
target project's `.claude/` so there is one source of truth and upgrades don't
require re-scaffolding.

## Extensions over upstream harness v2

This scaffold tracks the upstream harness v2 layout with two extensions:

1. **Seven new human gates** in `harness.yaml` (20 total, was 13), now a
   structured registry that `scheduler.py --validate` reads and enforces:
   `intake_mode_confirmation` · `blocking_questions_resolved` ·
   `knowledge_map_baseline` · `codebase_baseline_approval` ·
   `change_impact_approval`.
2. **Intake artifacts** referenced from `AGENTS.md`: `docs/intake-report.md`,
   `spec/questions.md` (Q-<AREA>-nnn), `spec/knowledge-map.yaml`,
   `docs/codebase-baseline.md`, `docs/impact/` (IMP-nnn),
   `docs/traceability.md` — produced by the six intake-side skills
   (`project-intake`, `question-resolution`, `knowledge-map`,
   `codebase-analysis`, `change-impact`, `traceability`) that ship with the
   plugin.

Everything else is byte-identical to upstream where possible; keep it that way
when syncing upstream changes.
