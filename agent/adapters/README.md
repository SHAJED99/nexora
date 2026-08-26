# Platform adapters — one interface, many CLIs

Each adapter: `run-<platform>.sh <TASK_ID> "<prompt>"` →
1. runs the CLI headless, 2. saves the raw result to `runs/<TASK_ID>/`,
3. stamps tokens+cost into the epic's `metrics.csv` via metrics_collect.py.

⚠️ CLI flags evolve fast. Each script marks the flags to VERIFY against the
tool's current `--help` before first use. Cost capture quality differs:
- claude-code: authoritative `total_cost_usd` in result JSON ✅
- codex: `codex exec --json` emits token_count JSONL events; the collector
  records task tokens, but `cost_usd` is blank unless Codex starts emitting an
  authoritative cost.
- opencode: token fields vary — adapter logs the run; fill tokens from the
  tool's usage view if absent (rows still attribute time/platform).
