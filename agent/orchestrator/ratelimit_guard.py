#!/usr/bin/env python3
"""Rate-limit guard — the statusline, and the freeze trigger. One file, one job.

Wire directly as the Claude Code statusLine (.claude/settings.json):
  "statusLine": {"type": "command",
                 "command": "python3 agent/orchestrator/ratelimit_guard.py"}

Claude Code passes session JSON on stdin; >=2.1.x includes a `rate_limits`
object with five_hour / seven_day buckets. Field names vary by version, so the
probing here is deliberately defensive — a guard that crashes on an unexpected
shape is worse than no guard.

Prints the statusline text, and at the threshold drops agent/handoffs/.FREEZE
so the orchestrator knows to run skills/handoff §4 (freeze -> packet -> resume
on the next platform in harness.yaml). Exits:
  0 = OK to continue        2 = FREEZE

Threshold: harness.yaml platforms[claude-code].freeze_threshold_pct (default
80). Why 80 and not 99: a freeze needs room to *be* a freeze — WIP-commit, write
the packet, save the diff. Discovering the wall mid-edit is how you lose an hour
of uncommitted work.

Manual check:  echo '{}' | python3 agent/orchestrator/ratelimit_guard.py
"""
import datetime, json, os, sys
import sys

# This module prints ✓ · → and friends. On Windows the default console
# encoding is cp1252, which raises UnicodeEncodeError mid-print and takes
# the whole gate down. Force UTF-8 on the streams we own.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):  # pragma: no cover - py<3.7 / non-tty
        pass

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def signal_freeze():
    """Drop the marker the orchestrator watches. Never fail the statusline."""
    try:
        d = os.path.join(ROOT, "agent", "handoffs")
        os.makedirs(d, exist_ok=True)
        ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with open(os.path.join(d, ".FREEZE"), "a", encoding="utf-8") as f:
            f.write(f"{ts} freeze signal\n")
    except OSError:
        pass


def threshold():
    try:
        import yaml
        cfg = yaml.safe_load(open(os.path.join(ROOT, "harness.yaml"), encoding="utf-8")) or {}
        for p in cfg.get("platforms") or []:
            if p.get("name") == "claude-code":
                return float(p.get("freeze_threshold_pct", 80))
    except Exception:
        pass
    return 80.0


def pct_of(bucket):
    """Extract a utilization percentage from whatever shape this version sends."""
    if not isinstance(bucket, dict):
        return None
    for k in ("utilization", "used_pct", "percent_used", "pct"):
        if isinstance(bucket.get(k), (int, float)):
            v = float(bucket[k])
            return v * 100 if v <= 1 else v
    used, limit = bucket.get("used"), bucket.get("limit")
    if isinstance(used, (int, float)) and isinstance(limit, (int, float)) and limit:
        return 100.0 * used / limit
    remaining = bucket.get("remaining")
    if isinstance(remaining, (int, float)) and isinstance(limit, (int, float)) and limit:
        return 100.0 * (limit - remaining) / limit
    return None


def main():
    raw = sys.stdin.read() if not sys.stdin.isatty() else ""
    try:
        data = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        data = {}
    rl = data.get("rate_limits") or data.get("rateLimits") or {}
    five = pct_of(rl.get("five_hour") or rl.get("fiveHour") or {})
    week = pct_of(rl.get("seven_day") or rl.get("sevenDay") or rl.get("weekly") or {})
    th = threshold()

    parts, freeze = [], False
    if five is not None:
        parts.append(f"5h {five:.0f}%")
        freeze |= five >= th
    if week is not None:
        parts.append(f"wk {week:.0f}%")
        freeze |= week >= max(th, 90)  # weekly is the harder wall — be stricter
    if not parts:
        print("harness | window: n/a (no rate_limits in payload — check /usage manually)")
        sys.exit(0)
    if freeze:
        signal_freeze()
    flag = " ⏸ FREEZE → skills/handoff §4" if freeze else ""
    print(f"harness | {' · '.join(parts)} (freeze@{th:.0f}%){flag}")
    sys.exit(2 if freeze else 0)


if __name__ == "__main__":
    main()
