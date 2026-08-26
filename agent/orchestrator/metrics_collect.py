#!/usr/bin/env python3
"""the harness metrics collector — append one run's tokens+cost to its epic CSV.

Usage:
  python3 metrics_collect.py --task E03-T07 --platform claude-code --result runs/E03-T07/x.json
  python3 metrics_collect.py --task E03-T07 --platform codex --result runs/E03-T07/x.jsonl

For claude-code, reads the `claude -p --output-format json` result message:
`total_cost_usd` is the AUTHORITATIVE cost (do NOT sum raw per-turn
input_tokens from session JSONL — known to undercount). Field names are
probed defensively because shapes vary across CLI versions.
For codex, reads `codex exec --json` JSONL events and sums `last_token_usage`
from token_count events. Codex does not emit authoritative cost, so cost_usd is
left empty unless the result shape starts emitting it later.
CSV: epics/<EPIC>/metrics.csv
  ts,task_id,platform,model,input,output,cache_read,cache_creation,cost_usd,duration_s,session_id
"""
import argparse, csv, datetime, glob, json, os, sys
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
HEADER = ["ts", "task_id", "platform", "model", "input", "output",
          "cache_read", "cache_creation", "cost_usd", "duration_s", "session_id"]


def pick(d, *keys, default=0):
    for k in keys:
        cur, ok = d, True
        for part in k.split("."):
            if isinstance(cur, dict) and part in cur:
                cur = cur[part]
            else:
                ok = False
                break
        if ok and cur is not None:
            return cur
    return default


def add_num(row, key, value):
    row[key] = str(int(float(row.get(key) or 0) + float(value or 0)))


def load_result(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError:
        events = []
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        return events


def collect_codex_usage(events, row):
    token_events = 0
    final_total = {}
    for event in events if isinstance(events, list) else []:
        payload = event.get("payload") if isinstance(event, dict) else {}
        if not isinstance(payload, dict) or payload.get("type") != "token_count":
            continue
        token_events += 1
        info = payload.get("info") or {}
        usage = info.get("last_token_usage") or {}
        if usage:
            input_tokens = float(usage.get("input_tokens") or 0)
            cached_tokens = float(usage.get("cached_input_tokens") or 0)
            add_num(row, "input", max(0, input_tokens - cached_tokens))
            add_num(row, "cache_read", cached_tokens)
            add_num(row, "output", usage.get("output_tokens") or 0)
        final_total = info.get("total_token_usage") or final_total

    if token_events:
        return
    if final_total:
        input_tokens = float(final_total.get("input_tokens") or 0)
        cached_tokens = float(final_total.get("cached_input_tokens") or 0)
        row.update(
            input=str(int(max(0, input_tokens - cached_tokens))),
            cache_read=str(int(cached_tokens)),
            output=str(int(float(final_total.get("output_tokens") or 0))),
        )


def collect_json_usage(data, row, model_arg):
    if isinstance(data, list):
        collect_codex_usage(data, row)
        result = next((d for d in reversed(data) if isinstance(d, dict) and d.get("type") == "result"), {})
        if not model_arg:
            row["model"] = pick(result, "model", "payload.model", default="")
        row["cost_usd"] = pick(result, "total_cost_usd", "cost_usd", "usage.total_cost_usd", "payload.total_cost_usd", default="")
        row["duration_s"] = round(float(pick(result, "duration_ms", "payload.duration_ms", default=0)) / 1000, 1) or ""
        row["session_id"] = pick(result, "session_id", "sessionId", "payload.session_id", default="")
        return

    usage = pick(data, "usage", default={}) or {}
    mu = pick(data, "modelUsage", default={}) or {}
    if not model_arg:
        row["model"] = next(iter(mu), "") or pick(data, "model", default="")
    row.update(
        input=pick(usage, "input_tokens", default=pick(data, "usage.input_tokens", default="")),
        output=pick(usage, "output_tokens", default=""),
        cache_read=pick(usage, "cache_read_input_tokens", default=""),
        cache_creation=pick(usage, "cache_creation_input_tokens", default=""),
        cost_usd=pick(data, "total_cost_usd", "cost_usd", "usage.total_cost_usd", default=""),
        duration_s=round(float(pick(data, "duration_ms", default=0)) / 1000, 1) or "",
        session_id=pick(data, "session_id", "sessionId", default=""),
    )


def epic_dir(task_id):
    eid = task_id.split("-")[0]
    hits = glob.glob(os.path.join(ROOT, "epics", eid + "-*")) + glob.glob(os.path.join(ROOT, "epics", eid))
    if not hits:
        sys.exit(f"harness: no epics/{eid}-* folder for task {task_id}")
    return hits[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", required=True)
    ap.add_argument("--platform", required=True)
    ap.add_argument("--result", required=True)
    ap.add_argument("--no-cost", action="store_true", help="log run without token/cost fields")
    ap.add_argument("--model", default="")
    a = ap.parse_args()

    row = dict.fromkeys(HEADER, "")
    row.update(ts=datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
               task_id=a.task, platform=a.platform, model=a.model)

    if not a.no_cost:
        try:
            data = load_result(a.result)
        except (OSError, IndexError) as e:
            print(f"harness: ⚠ could not parse {a.result} ({e}); logging without cost", file=sys.stderr)
            data = {}
        collect_json_usage(data, row, a.model)

    path = os.path.join(epic_dir(a.task), "metrics.csv")
    new = not os.path.exists(path)
    with open(path, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=HEADER)
        if new:
            w.writeheader()
        w.writerow(row)
    print(f"harness: metrics → {os.path.relpath(path, ROOT)} "
          f"(cost={row['cost_usd'] or 'n/a'} model={row['model'] or 'n/a'})")


if __name__ == "__main__":
    main()
