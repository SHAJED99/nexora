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

## Token-conservation: use `agy` for non-Claude work (human instruction, 2026-09-07)

A separate, standalone CLI — `agy` (Antigravity), installed at
`C:\Users\SRPPC3\AppData\Local\agy\bin\agy.exe`, not on `PATH` — is
available on this machine, logged in as
`shajedurrahmanpanna.panna@gmail.com`. It gives non-interactive access
(`agy --model <id> --print="<prompt>"`, or `--output-format json` for
structured output including a per-call `usage` object) to Gemini 3.x
(`gemini-3.8/3.7/3.6-flash-{high,medium,low}`, `gemini-3.1-pro-{high,low}`)
and `gpt-oss-120b-medium`. Run `agy models` to reconfirm the live list —
it can change.

- **Use `agy`'s models wisely for suitable sub-tasks** (investigation,
  drafting, secondary opinions/second-pass checks, research, non-critical-
  path work) to conserve this session's own Claude token budget — that is
  the entire point of reaching for it.
- **Never invoke `agy`'s `claude-*` models** (`claude-sonnet-4-6`,
  `claude-opus-4-6-thinking`) — routing Claude work through this proxy
  defeats the purpose of using `agy` to save Claude tokens in the first
  place.
- **Check `agy`'s remaining usage/limit before dispatching a task to it.**
  As of CLI v1.1.27 there is no dedicated `agy usage`/`agy quota`
  subcommand — the check is: run a trivial probe call with
  `--output-format json` first and read the returned `usage` object
  (`input_tokens`/`output_tokens`/`total_tokens`/`cache_read_tokens`), and
  watch for an explicit rate-limit/quota error surfaced by the CLI itself.
  Re-check this each time `agy` is reached for again in a session, not just
  once — a prior clean check does not guarantee capacity later.
