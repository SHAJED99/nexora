#!/usr/bin/env python3
"""Lessons report + promotion candidates.

  make lessons              # everything, by area
  make lessons --area backend
  make lessons --json

The ladder (skills/retro): recurrence 1 = lesson · 2 = promote to a rule in the
relevant SKILL.md · 3+ or mechanically checkable = promote to a hook.

This exists so "what should we automate next?" has an answer made of evidence
instead of vibes. Recurrence is the only number that knows.
"""
import argparse
import glob
import json
import os
import re
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
LESSONS = os.path.join(ROOT, "agent", "memory", "lessons")


def parse_area(path):
    area = os.path.splitext(os.path.basename(path))[0]
    with open(path, encoding="utf-8") as f:
        text = f.read()
    out = []
    for block in re.split(r"\n(?=## L-)", text):
        block = block.strip()
        if not block.startswith("## L-"):
            continue
        title = block.splitlines()[0][3:].strip()
        get = lambda k, d="": (re.search(rf"{k}:\s*(.+)", block) or [None, d])[1].strip()
        out.append({
            "area": area,
            "id": title.split(" — ")[0],
            "title": title,
            "recurrence": int(get("recurrence", "1").split()[0] or 1),
            "status": get("status", "lesson").split("#")[0].strip(),
            "root_cause": get("root cause"),
            "source": get("source") or get(r"date").split("| source:")[-1].strip(),
        })
    return out


def load():
    items = []
    for p in sorted(glob.glob(os.path.join(LESSONS, "*.md"))):
        if os.path.basename(p) in ("README.md", "_template.md"):
            continue
        try:
            items += parse_area(p)
        except OSError:
            pass
    return items


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--area", default=None)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    items = [i for i in load() if not a.area or i["area"] == a.area]
    if a.json:
        print(json.dumps(items, indent=2))
        return

    if not items:
        print("harness: no lessons yet — skills/retro writes them after each epic.")
        return

    by_area = {}
    for i in items:
        by_area.setdefault(i["area"], []).append(i)

    for area, ls in sorted(by_area.items()):
        print(f"\n\033[1m{area}\033[0m ({len(ls)})")
        for l in sorted(ls, key=lambda x: -x["recurrence"]):
            mark = "🔁" if l["recurrence"] > 1 else "  "
            done = "✅" if l["status"].startswith("promoted") else "  "
            print(f"  {mark}{done} x{l['recurrence']}  {l['title'][:78]}")
            if l["status"].startswith("promoted"):
                print(f"           └─ {l['status']}")

    candidates = [i for i in items if i["recurrence"] >= 2 and not i["status"].startswith("promoted")]
    print("\n" + "─" * 72)
    if candidates:
        print(f"\033[33mPromotion candidates ({len(candidates)}) — recurrence >= 2, not yet promoted\033[0m")
        for c in candidates:
            rung = "a HOOK (it keeps happening)" if c["recurrence"] >= 3 else "a RULE in the owning SKILL.md"
            print(f"  • [{c['area']}] {c['title']}")
            print(f"    hit {c['recurrence']}× → promote to {rung}")
            if c["root_cause"]:
                print(f"    root cause: {c['root_cause'][:88]}")
        print("\n  A hook beats a rule beats a lesson — a hook can't be forgotten.")
        print("  🧍 Human gate: skills are code. Diff the promotion, get it approved (retro_promotions).")
    else:
        print("\033[32mNo promotion candidates — nothing has bitten twice without being automated.\033[0m")

    promoted = sum(1 for i in items if i["status"].startswith("promoted"))
    print(f"\ntotals: {len(items)} lessons · {promoted} promoted · {len(candidates)} awaiting promotion")


if __name__ == "__main__":
    main()
