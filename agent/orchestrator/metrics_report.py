#!/usr/bin/env python3
"""Summarize task-level and epic-level token/cost usage from metrics.csv files.

Reads epics/*/metrics.csv rows written by agent/orchestrator/metrics_collect.py.
Task totals are grouped by task_id; epic totals are grouped by the metrics file's
epic folder. If cost_usd is missing but token counts and a known model are present,
an estimated cost is calculated from agent/rates/cost-config.yaml.
"""
import argparse
import csv
import glob
import json
import os
import sys
import re

# This module prints ✓ · → and friends. On Windows the default console
# encoding is cp1252, which raises UnicodeEncodeError mid-print and takes
# the whole gate down. Force UTF-8 on the streams we own.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):  # pragma: no cover - py<3.7 / non-tty
        pass

try:
    import yaml
except ImportError:
    yaml = None

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ACTIVE_STATUSES = {"in-progress", "review-requested", "changes-requested", "done", "verified"}


def fm(path):
    text = open(path, encoding="utf-8").read()
    match = re.match(r"\s*---\s*\n(.*?)\n---\s*\n", text, re.S)
    if not match or yaml is None:
        return {}
    try:
        return yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError:
        return {}


def fnum(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def kfmt(n):
    n = float(n)
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}k"
    return str(int(n))


def load_rates():
    if yaml is None:
        return {}, {}
    path = os.path.join(ROOT, "agent", "rates", "cost-config.yaml")
    try:
        data = yaml.safe_load(open(path, encoding="utf-8")) or {}
    except OSError:
        return {}, {}
    return data.get("models") or {}, data.get("aliases") or {}


def rate_for(model, models, aliases):
    if not model:
        return None
    raw = str(model).lower()
    if raw in models:
        return models[raw]
    for prefix, key in sorted(aliases.items(), key=lambda item: len(item[0]), reverse=True):
        if raw.startswith(str(prefix).lower()):
            return models.get(key)
    return None


def estimate_cost(row, models, aliases):
    rates = rate_for(row.get("model", ""), models, aliases)
    if not rates:
        return 0.0
    input_tokens = fnum(row.get("input"))
    output_tokens = fnum(row.get("output"))
    cache_read = fnum(row.get("cache_read"))
    cache_creation = fnum(row.get("cache_creation"))
    return (
        input_tokens * fnum(rates.get("input"))
        + output_tokens * fnum(rates.get("output"))
        + cache_read * fnum(rates.get("cache_read"))
        + cache_creation * fnum(rates.get("cache_write"))
    ) / 1_000_000


def empty_bucket(key):
    return {
        "key": key,
        "status": "",
        "estimate": "",
        "epic": "",
        "runs": 0,
        "input": 0.0,
        "output": 0.0,
        "cache_read": 0.0,
        "cache_creation": 0.0,
        "tokens": 0.0,
        "actual_cost_usd": 0.0,
        "estimated_cost_usd": 0.0,
        "missing_usage_runs": 0,
        "missing_usage": False,
        "run_details": [],
    }


def add_row(bucket, row, models, aliases):
    input_tokens = fnum(row.get("input"))
    output_tokens = fnum(row.get("output"))
    cache_read = fnum(row.get("cache_read"))
    cache_creation = fnum(row.get("cache_creation"))
    tokens = input_tokens + output_tokens + cache_read + cache_creation
    has_actual_cost = str(row.get("cost_usd") or "").strip() != ""
    estimated_cost = 0.0 if has_actual_cost else estimate_cost(row, models, aliases)

    bucket["runs"] += 1
    bucket["input"] += input_tokens
    bucket["output"] += output_tokens
    bucket["cache_read"] += cache_read
    bucket["cache_creation"] += cache_creation
    bucket["tokens"] += tokens
    if has_actual_cost:
        bucket["actual_cost_usd"] += fnum(row.get("cost_usd"))
    else:
        bucket["estimated_cost_usd"] += estimated_cost
    if tokens == 0:
        bucket["missing_usage_runs"] += 1
    bucket["run_details"].append({
        "ts": row.get("ts", ""),
        "platform": row.get("platform", ""),
        "model": row.get("model", ""),
        "input": input_tokens,
        "output": output_tokens,
        "cache_read": cache_read,
        "cache_creation": cache_creation,
        "tokens": tokens,
        "actual_cost_usd": fnum(row.get("cost_usd")) if has_actual_cost else 0.0,
        "estimated_cost_usd": estimated_cost,
        "cost_kind": "actual" if has_actual_cost else ("estimated" if estimated_cost else "none"),
        "duration_s": fnum(row.get("duration_s")),
        "session_id": row.get("session_id", ""),
    })


def task_estimate(task):
    est = task.get("token_estimate") or {}
    if not isinstance(est, dict):
        return ""
    tier = str(est.get("tier") or "").strip()
    rng = str(est.get("range") or "").strip()
    if tier and rng:
        return f"{tier} {rng}"
    return tier or rng


def load_task_index():
    tasks = {}
    epics = {}
    for epic_path in sorted(glob.glob(os.path.join(ROOT, "epics", "E*", "epic.md"))):
        epic_dir = os.path.basename(os.path.dirname(epic_path))
        epic_id = epic_dir.split("-")[0]
        epic = epics.setdefault(epic_id, empty_bucket(epic_id))
        epic["epic"] = epic_id
        for task_path in sorted(glob.glob(os.path.join(os.path.dirname(epic_path), "tasks", "*.md"))):
            task = fm(task_path)
            task_id = str(task.get("id") or os.path.splitext(os.path.basename(task_path))[0])
            bucket = tasks.setdefault(task_id, empty_bucket(task_id))
            bucket["status"] = str(task.get("status") or "")
            bucket["estimate"] = task_estimate(task)
            bucket["epic"] = epic_id
    return tasks, epics


def collect():
    models, aliases = load_rates()
    tasks, epics = load_task_index()
    row_count = 0

    for path in sorted(glob.glob(os.path.join(ROOT, "epics", "E*", "metrics.csv"))):
        epic_dir = os.path.basename(os.path.dirname(path))
        epic_id = epic_dir.split("-")[0]
        epic = epics.setdefault(epic_id, empty_bucket(epic_id))
        with open(path, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                task_id = (row.get("task_id") or "").strip()
                if not task_id:
                    continue
                row_count += 1
                task = tasks.setdefault(task_id, empty_bucket(task_id))
                task["epic"] = task.get("epic") or epic_id
                add_row(task, row, models, aliases)
                add_row(epic, row, models, aliases)

    for task in tasks.values():
        task["missing_usage"] = task["runs"] == 0 and task.get("status") in ACTIVE_STATUSES

    return row_count, tasks, epics


def row_for_json(bucket):
    return {
        key: (round(value, 6) if isinstance(value, float) else value)
        for key, value in bucket.items()
    }


def print_table(title, rows):
    print(title)
    print("id        status             estimate       runs  tokens   input   output  cache-r  actual$  est$    missing")
    print("--------  -----------------  -------------  ----  -------  ------  ------  -------  -------  ------  -------")
    for row in rows:
        missing = "yes" if row.get("missing_usage") else row["missing_usage_runs"]
        print(
            f"{row['key']:<8}  {row.get('status', '')[:17]:<17}  {row.get('estimate', '')[:13]:<13}  "
            f"{row['runs']:>4}  {kfmt(row['tokens']):>7}  "
            f"{kfmt(row['input']):>6}  {kfmt(row['output']):>6}  "
            f"{kfmt(row['cache_read']):>7}  "
            f"{row['actual_cost_usd']:>7.2f}  {row['estimated_cost_usd']:>6.2f}  "
            f"{str(missing):>7}"
        )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = ap.parse_args()

    row_count, tasks, epics = collect()
    task_rows = sorted(tasks.values(), key=lambda r: r["key"])
    epic_rows = sorted(epics.values(), key=lambda r: r["key"])

    if args.json:
        print(json.dumps({
            "rows": row_count,
            "tasks": [row_for_json(row) for row in task_rows],
            "epics": [row_for_json(row) for row in epic_rows],
        }, indent=2))
        return

    if row_count == 0:
        print("harness: no metrics rows yet")
        print("hint: run tasks through agent/adapters/run-*.sh or backfill epics/<E>/metrics.csv")
        task_rows = [row for row in task_rows if row.get("missing_usage")]
        if task_rows:
            print()
            print_table("tasks missing usage", task_rows)
        return

    print_table("task token usage", task_rows)
    print()
    print_table("epic token usage", epic_rows)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        sys.exit(0)
