#!/usr/bin/env bash
# Usage: run-opencode.sh E03-T07 "Implement E03-T07 per agent/skills/implement/SKILL.md"
set -euo pipefail
TASK="${1:?task id}"; PROMPT="${2:?prompt}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
TS=$(date -u +%Y%m%dT%H%M%SZ); OUT="runs/$TASK/$TS-opencode.log"; mkdir -p "runs/$TASK"
# VERIFY: `opencode run --help` (output/format flags evolve).
opencode run "$PROMPT" ${HARNESS_OPENCODE_FLAGS:-} 2>&1 | tee "$OUT" >/dev/null
python3 agent/orchestrator/metrics_collect.py --task "$TASK" --platform opencode --result "$OUT" --no-cost
echo "harness: run saved → $OUT"
