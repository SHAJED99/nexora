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

## Token-conservation: push execution work onto `agy` (human instruction, 2026-09-07)

The human wants THIS PROJECT's own Claude token spend minimized — they
need their Claude usage headroom for a different project — and is
willing to spend a separate CLI's tokens/quota here instead. A separate,
standalone CLI — `agy` (Antigravity), installed at
`C:\Users\SRPPC3\AppData\Local\agy\bin\agy.exe`, not on `PATH` — is
available on this machine, logged in as
`shajedurrahmanpanna.panna@gmail.com`. **`agy` is a full agentic CLI, not
a text-completion proxy** — it has its own file read/write, shell/tool
use, `--add-dir` (attach a workspace), `--mode accept-edits`/`--mode plan`,
and `--sandbox`. That means real work (implementation, investigation, bug
fixing, even review) can be handed to it to actually execute — not just
draft prose that still has to be applied by spending Claude tokens on it.

- **Default to dispatching actual task execution in this repo through
  `agy`, not through Claude directly and not through Claude's own Task/
  Agent subagents**, whenever `agy` is capable of the task — implementation
  work, investigation/research, drafting, bug fixes, even a review pass.
  Pick whichever model fits the task's weight: `gemini-3.1-pro-high` for
  genuinely hard/high-stakes work, a `flash` tier (`high`/`medium`/`low`
  by how much reasoning the task needs) for lighter or more mechanical
  work, `gpt-oss-120b-medium` where it's a better fit or for an
  independent second opinion, **or `agy`'s own `claude-sonnet-4-6`/
  `claude-opus-4-6-thinking` (human-confirmed 2026-09-07: these draw from
  `agy`/Antigravity's own separate quota, NOT this session's own Anthropic
  token budget — using them here costs nothing from the budget being
  preserved, unlike calling Claude directly or via a Claude Code
  subagent).** Run `agy models` to reconfirm the live list — it can
  change.
- Reserve Claude's own direct token spend (i.e. this session itself, or a
  Claude Code Task/Agent subagent — NOT `agy`'s own `claude-*` models,
  which are free of that cost per above) for what only Claude/Claude Code
  can actually do here: orchestrating and dispatching the work itself,
  reading back and acting on `agy`'s results, decisions that need this
  session's own accumulated context, and anything `agy` cannot do (or
  fails at) in this environment.
- **Check `agy`'s remaining usage/limit before dispatching a task to it,
  every time, not just once.** As of CLI v1.1.27 there is no dedicated
  `agy usage`/`agy quota` subcommand — the check is: run a trivial probe
  call with `--output-format json` first and read the returned `usage`
  object (`input_tokens`/`output_tokens`/`total_tokens`/`cache_read_tokens`),
  and watch for an explicit rate-limit/quota error surfaced by the CLI
  itself. A prior clean check does not guarantee capacity later.

### A second execution CLI: `opencode` (human instruction, 2026-09-07)

Also available on this machine — `opencode-cli.exe`, installed at
`C:\Users\SRPPC3\AppData\Local\OpenCode\opencode-cli.exe`, not on `PATH`,
v1.14.31. Same purpose as `agy` above (push real execution work off this
session's own Claude token budget), different provider mix: `opencode
models` lists ~370 models across OpenRouter, LM Studio (local), and
opencode's own hosted free tier. Non-interactive dispatch:
`opencode run --model <provider>/<id> "<prompt>"`. `opencode stats` gives
a real usage/cost dashboard (unlike `agy`, which has none) — check it
before a large dispatch.

- **The user said: use good FREE models, matched to the task.** Confirmed
  working, in order of preference for real execution work:
  1. `openrouter/nvidia/nemotron-3-ultra-550b-a55b:free` — largest
     confirmed-working free model (550B/a55b MoE); default choice for
     genuinely hard/high-stakes work.
  2. `openrouter/minimax/minimax-m3:free` — strong alternative, good fit
     for coding-heavy tasks or as an independent second opinion against
     the nemotron pick above.
  3. `opencode/nemotron-3.5-lightning-free` or
     `openrouter/nvidia/nemotron-3.5-lightning:free` — lighter/quicker
     tasks that don't need the biggest model.
  Re-run `opencode models | grep -i free` to reconfirm the live list —
  it can change, and a model missing here may have been added/removed.
- **Paid (non-`:free`) OpenRouter models are NOT reliably usable** — this
  account's OpenRouter credit balance is very low; a real attempt at
  `openrouter/~google/gemini-flash-latest` failed outright with "requires
  more credits... requested up to 32000 tokens, but can only afford
  2173." Stick to `:free`-suffixed OpenRouter models or `opencode/*-free`
  models unless a paid one is confirmed to work in the moment.
- **LM Studio models (`lmstudio/...`) are NOT currently reliable** — a
  real dispatch to `lmstudio/qwen/qwen3-coder-30b` did not respond within
  60s and had to be backgrounded, most likely because the local LM Studio
  server/model wasn't loaded and running at the time. Don't depend on
  these unless first confirmed responsive with a quick probe.
- Exact model-ID syntax matters and the CLI's own error message tells you
  the fix — e.g. `openrouter/google/gemini-flash-latest` fails with
  "Did you mean: ~google/gemini-flash-latest?" (some OpenRouter listings
  need a literal `~` prefix on the model segment). Read the error rather
  than guessing a second time.
- Same rules as `agy` apply: default to real task execution through
  `opencode` rather than Claude directly, reserve direct Claude spend for
  orchestration/what only Claude can do, and check usage/cost (`opencode
  stats`, plus watching for a credits/quota error) before each dispatch.
