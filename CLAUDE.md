# Claude Code adapter

@AGENTS.md

Claude Code specifics for this repo:

- Agent roles live in `agent/agents/` (5 roles). Mirror them as native
  subagents: `ln -s ../agent/agents .claude/agents`
- Skills live in `agent/skills/` (17). Make them natively discoverable:
  `ln -s ../agent/skills .claude/skills`
  (`/harness-init` creates both directories by copying them out of the plugin.
  Skill cross-references are written `skills/<name>` — the same directory, seen
  from inside `agent/`.)
- Run headless tasks via `agent/adapters/run-claude.sh <task-id> "<prompt>"`
  so cost + session JSON are captured into `runs/` and `metrics.csv`. This
  logging is specific to that dispatch path — an orchestrator dispatching
  through an interactive session's own Agent tool (as this project has done
  for every task and bug so far) has no `run-claude.sh` invocation to log
  through, and rule 9 does not apply to it (`L-process-015`).
- Settings this repo expects (`.claude/settings.json`, see `agent/hooks/`):
  - `"includeCoAuthoredBy": false` (or `"attribution": {"commit": "", "pr": ""}`)
  - `statusLine` → `agent/orchestrator/ratelimit_guard.py` (5-hour + weekly
    window freeze detection)
  - `hooks.UserPromptSubmit` → `agent/hooks/lesson-inject.py` (auto-injects the
    lessons for the task's area — rule 8 without anyone remembering it)
  Copy the ready-made file: `cp .claude/settings.example.json .claude/settings.json`
- MCP servers are declared in `.mcp.json` (project scope).
