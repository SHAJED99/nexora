#!/usr/bin/env bash
# Usage: run-codex.sh E03-T07 "Implement E03-T07 per agent/skills/implement/SKILL.md"
set -euo pipefail
TASK="${1:?task id}"; PROMPT="${2:?prompt}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
TS=$(date -u +%Y%m%dT%H%M%SZ); OUT="runs/$TASK/$TS-codex.jsonl"; mkdir -p "runs/$TASK"
# VERIFY flags: `codex exec --help` (sandbox/model flags evolve).
codex exec --json ${HARNESS_CODEX_FLAGS:-} "$PROMPT" 2>&1 | tee "$OUT" >/dev/null
python3 agent/orchestrator/metrics_collect.py --task "$TASK" --platform codex --result "$OUT"
echo "harness: run saved → $OUT"
