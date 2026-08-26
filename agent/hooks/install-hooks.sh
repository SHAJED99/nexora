#!/usr/bin/env bash
# Point git at the harness hooks (run once per clone).
set -e
cd "$(dirname "$0")/../.."
chmod +x agent/hooks/githooks/* agent/hooks/*.sh agent/adapters/*.sh 2>/dev/null || true
git config core.hooksPath agent/hooks/githooks
echo "harness: hooks installed (core.hooksPath → agent/hooks/githooks)"
echo "harness: remember Claude Code settings: \"includeCoAuthoredBy\": false"
