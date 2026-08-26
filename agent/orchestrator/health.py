#!/usr/bin/env python3
"""Harness health — detect the decay that kills this system quietly.

  make health              # all checks
  make health STRICT=1     # warnings count as failures too (use in CI)
  python3 agent/orchestrator/health.py --json

docs/ARCHITECTURE.md §7 lists seven ways the harness dies. Each looks locally
reasonable and is fatal in aggregate: a threshold loosened "just for now", a
mask widened until green means nothing, retros skipped so nothing ever gets
automated. §2 of the same doc says "remember to watch for X" is the weakest
control that exists — so a §7 that only *asks* you to watch is the one place the
harness didn't take its own advice.

This is that section promoted from a lesson to a hook. Six of the seven are
mechanically detectable from the repo; this finds them and names the fix.

Exit: 0 = healthy · 1 = at least one FAIL (or WARN under --strict).
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

try:
    import yaml
except ImportError:
    sys.exit("harness: pip install pyyaml (see requirements.txt)")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DONE = {"done", "verified"}

# The shipped-strict baseline. Anything weaker than this is a deliberate act and
# must be declared in thresholds.yaml `relaxations:` with a reason + approver.
# "Lower is stricter" for the max_* keys; "higher is stricter" for tolerances is
# false — tolerances are also maxima. Every key here: bigger = looser.
BASELINE = {
    "hard.missing_elements_max": 0,
    "hard.copy_mismatch_max": 0,
    "hard.style_deltas_max": 0,
    "hard.off_palette_tokens_max": 0,
    "soft.pixel_mismatch_max_pct": 8.0,
    "soft.layout_deltas_max": 0,
    "tolerance.font_size_px": 0.5,
    "tolerance.font_weight": 0,
    "tolerance.radius_px": 1.0,
    "tolerance.spacing_px": 2.0,
    "tolerance.layout_box_px": 8.0,
}

C = {"pass": "\033[32m", "warn": "\033[33m", "fail": "\033[31m", "dim": "\033[2m", "b": "\033[1m", "0": "\033[0m"}


class Result:
    def __init__(self, id, title):
        self.id, self.title = id, title
        self.status, self.findings, self.fix = "pass", [], ""

    def flag(self, status, finding):
        self.findings.append(finding)
        if status == "fail" or self.status == "fail":
            self.status = "fail"
        else:
            self.status = status


def dig(d, dotted):
    cur = d
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def load_yaml(path):
    p = os.path.join(ROOT, path)
    if not os.path.exists(p):
        return None
    try:
        with open(p, encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except yaml.YAMLError:
        return None


def frontmatter(path):
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return {}, ""
    m = re.match(r"\s*---\s*\n(.*?)\n---\s*\n", text, re.S)
    if not m:
        return {}, text
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        data = {}
    return (data if isinstance(data, dict) else {}), text[m.end():]


def tasks():
    for tp in sorted(glob.glob(os.path.join(ROOT, "epics", "E*", "tasks", "*.md"))):
        fm, body = frontmatter(tp)
        if fm:
            fm["_path"] = os.path.relpath(tp, ROOT)
            yield fm, body


# ── H1 · thresholds loosened without an approved reason ───────────────────────
def check_thresholds():
    r = Result("H1", "design thresholds not silently loosened")
    r.fix = ("Restore the value, or declare it in design/thresholds.yaml:\n"
             "    relaxations:\n"
             "      soft.pixel_mismatch_max_pct:\n"
             "        reason: \"charts render real data\"\n"
             "        approved_by: \"<human>\"\n"
             "        date: 2026-07-15\n"
             "  Loosening a threshold applies to EVERY screen, forever. It is the single\n"
             "  most effective way to disable this subsystem without anyone noticing.")
    th = load_yaml("design/thresholds.yaml")
    if th is None:
        r.flag("fail", "design/thresholds.yaml missing or unparseable")
        return r
    relax = th.get("relaxations") or {}
    for key, base in BASELINE.items():
        cur = dig(th, key)
        if cur is None:
            r.flag("warn", f"{key} is not set (baseline {base}) — the gate falls back to a default")
            continue
        if isinstance(cur, str) or isinstance(base, str):
            continue
        if float(cur) > float(base):
            entry = relax.get(key) or {}
            if entry.get("reason") and entry.get("approved_by"):
                r.flag("warn", f"{key}: {cur} (baseline {base}) — approved by "
                               f"{entry['approved_by']}: {entry['reason']}")
            else:
                r.flag("fail", f"{key}: {cur} is LOOSER than the baseline {base}, with no "
                               f"approved relaxation")
    tol_color = dig(th, "tolerance.color")
    if tol_color not in ("exact", None):
        entry = (relax.get("tolerance.color") or {})
        lvl = "warn" if entry.get("reason") else "fail"
        r.flag(lvl, f"tolerance.color: {tol_color} (baseline: exact)"
                    + (f" — approved by {entry.get('approved_by')}: {entry['reason']}" if entry.get("reason") else ""))
    return r


# ── H2 · masks and ignores kept narrow ────────────────────────────────────────
def check_masks():
    r = Result("H2", "masks + ignore_text stay narrow")
    r.fix = ("Every masked selector and ignored string is screen area the gate does NOT\n"
             "  check — and a green report never shows it. Narrow them, or seed the build\n"
             "  with the same data the design shows. If a region is genuinely unverifiable\n"
             "  (a chart, a map), say so in the screen's contract Notes.")
    src = load_yaml("design/sources.yaml")
    if src is None:
        r.flag("warn", "design/sources.yaml missing or unparseable")
        return r
    BROAD = [r"^\.\*$", r"^\.\+$", r"^\(\.\*\)$", r"^\.\*\??$"]
    for s in src.get("screens") or []:
        sid = s.get("id", "?")
        masks = s.get("mask") or []
        ignores = s.get("ignore_text") or []
        if len(masks) > 4:
            r.flag("warn", f"{sid}: {len(masks)} mask selectors — that's a lot of unchecked screen")
        for m in masks:
            if str(m).strip() in ("body", "main", "#root", "#__next", "*", "html"):
                r.flag("fail", f"{sid}: mask '{m}' hides the whole page — the gate is a no-op here")
        for pat in ignores:
            if any(re.match(b, str(pat)) for b in BROAD):
                r.flag("fail", f"{sid}: ignore_text '{pat}' matches everything — copy is unchecked")
        if len(ignores) > 6:
            r.flag("warn", f"{sid}: {len(ignores)} ignore_text patterns — copy parity is thinning out")
    return r


# ── H3 · retros actually happen ───────────────────────────────────────────────
def check_retros():
    r = Result("H3", "completed epics have retros")
    r.fix = ("Run skills/retro on the epic. Without it, recurrence never climbs, nothing is\n"
             "  ever promoted to a rule or a hook, and the whole learning apparatus is dead\n"
             "  weight you paid for. This is the check most worth obeying.")
    for ep in sorted(glob.glob(os.path.join(ROOT, "epics", "E*", "epic.md"))):
        fm, _ = frontmatter(ep)
        d = os.path.dirname(ep)
        if str(fm.get("status")) in DONE and not os.path.exists(os.path.join(d, "retro.md")):
            r.flag("fail", f"{fm.get('id', os.path.basename(d))} is {fm.get('status')} with no retro.md")
    return r


# ── H4 · scope fences are filled in ───────────────────────────────────────────
def check_fences():
    r = Result("H4", "tasks have a real scope fence")
    r.fix = ("Fill §4 'What this task does NOT do' with the tempting-but-wrong moves THIS\n"
             "  task invites. An agent with an empty fence fills the space with its own\n"
             "  judgement, and its judgement is not the plan.")
    HEAD = re.compile(r"^##\s*4\.\s*What this task does NOT do.*$", re.M | re.I)
    for fm, body in tasks():
        if str(fm.get("status")) in ("done", "verified"):
            continue
        m = HEAD.search(body)
        if not m:
            r.flag("warn", f"{fm.get('id')}: no §4 scope-fence section ({fm['_path']})")
            continue
        seg = body[m.end():]
        nxt = re.search(r"^##\s", seg, re.M)
        seg = seg[:nxt.start()] if nxt else seg
        bullets = [l for l in seg.splitlines()
                   if l.strip().startswith("-") and not l.strip().startswith("- (")]
        real = [b for b in bullets if not re.search(r"<[^>]+>|Explicit non-goal|tempting-but-wrong", b)]
        if not real:
            r.flag("fail", f"{fm.get('id')}: §4 scope fence is empty or still template text ({fm['_path']})")
    return r


# ── H5 · review independence (rule 5) ─────────────────────────────────────────
def check_review_independence():
    r = Result("H5", "reviews routed to a different model (rule 5)")
    r.fix = ("Route review to a model listed in harness.yaml review_routing.models,\n"
             "  excluding whatever executed the task. Same-model review is ceremony, not\n"
             "  independence — it shares the executor's blind spots exactly.")
    for fm, _ in tasks():
        if str(fm.get("status")) not in DONE:
            continue
        ex, rv = str(fm.get("executed_by") or ""), str(fm.get("reviewed_by") or "")
        if not rv:
            r.flag("fail", f"{fm.get('id')}: {fm.get('status')} with no reviewed_by ({fm['_path']})")
        elif ex and rv.strip().lower() == ex.strip().lower():
            r.flag("fail", f"{fm.get('id')}: reviewed_by == executed_by ({ex}) — rule 5 ({fm['_path']})")
    return r


# ── H6 · lessons get promoted, not hoarded ────────────────────────────────────
def check_lesson_promotion():
    r = Result("H6", "recurring lessons get promoted")
    r.fix = ("Run `make lessons`, then skills/retro §3: promote to a rule in the owning\n"
             "  SKILL.md, or to a hook if it's mechanically checkable. A lesson that has bitten\n"
             "  twice and stayed a lesson is a directory entry, not a control.")
    for p in sorted(glob.glob(os.path.join(ROOT, "agent", "memory", "lessons", "*.md"))):
        if os.path.basename(p) in ("README.md", "_template.md", "index.yaml"):
            continue
        try:
            text = open(p, encoding="utf-8").read()
        except OSError:
            continue
        for block in re.split(r"\n(?=## L-)", text):
            if not block.strip().startswith("## L-"):
                continue
            title = block.splitlines()[0][3:].strip()
            rec = re.search(r"recurrence:\s*(\d+)", block)
            st = re.search(r"status:\s*(.+)", block)
            rec = int(rec.group(1)) if rec else 1
            st = (st.group(1).split("#")[0].strip() if st else "lesson")
            if rec >= 2 and not st.startswith("promoted"):
                rung = "a HOOK" if rec >= 3 else "a RULE"
                r.flag("fail", f"{title[:64]} — hit {rec}×, still 'lesson' → promote to {rung}")
    return r


# ── H7 · gates not skipped ────────────────────────────────────────────────────
def check_gates():
    r = Result("H7", "merge gates not skipped")
    r.fix = ("A task reaching done without a recorded APPROVE, or a frontend task without a\n"
             "  design contract, means a gate was skipped. Re-run it. 'Once, under deadline'\n"
             "  is how the gates stop being gates.")
    for fm, _ in tasks():
        tid, status = fm.get("id"), str(fm.get("status"))
        if status in DONE:
            outcome = str(fm.get("review_outcome") or "").upper()
            if not outcome:
                r.flag("fail", f"{tid}: {status} with no review_outcome ({fm['_path']})")
            elif "APPROVE" not in outcome:
                r.flag("fail", f"{tid}: {status} but review_outcome is '{outcome}' ({fm['_path']})")
        if str(fm.get("layer")) == "frontend" and fm.get("type") != "genesis":
            dc = fm.get("design_contract")
            if not dc or str(dc) == "n/a":
                r.flag("fail", f"{tid}: frontend task with no design_contract — rule 2 ({fm['_path']})")
            elif not os.path.exists(os.path.join(ROOT, str(dc))):
                r.flag("fail", f"{tid}: design_contract '{dc}' does not exist ({fm['_path']})")
    return r


CHECKS = [check_thresholds, check_masks, check_retros, check_fences,
          check_review_independence, check_lesson_promotion, check_gates]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--strict", action="store_true", help="warnings fail too (CI)")
    a = ap.parse_args()

    results = [c() for c in CHECKS]

    if a.json:
        print(json.dumps([{"id": r.id, "title": r.title, "status": r.status,
                           "findings": r.findings} for r in results], indent=2))
        bad = [r for r in results if r.status == "fail" or (a.strict and r.status == "warn")]
        sys.exit(1 if bad else 0)

    print(f"\n{C['b']}harness health{C['0']} — the decay checks from docs/ARCHITECTURE.md §7\n")
    for r in results:
        icon = {"pass": "✅", "warn": "⚠️ ", "fail": "❌"}[r.status]
        col = C[r.status]
        print(f"{icon} {col}{r.id}{C['0']} {r.title}")
        for f in r.findings:
            print(f"      {col}·{C['0']} {f}")
        if r.findings and r.status != "pass":
            print(f"{C['dim']}      fix: {r.fix}{C['0']}\n")

    fails = [r for r in results if r.status == "fail"]
    warns = [r for r in results if r.status == "warn"]
    print("─" * 72)
    if not fails and not warns:
        print(f"{C['pass']}healthy{C['0']} — {len(results)}/{len(results)} checks pass.")
    else:
        print(f"{len(results) - len(fails) - len(warns)} pass · "
              f"{C['warn']}{len(warns)} warn{C['0']} · {C['fail']}{len(fails)} fail{C['0']}")
        print("\nNone of these are bugs. Each is a small, locally reasonable decision that\n"
              "quietly removes a control — which is exactly why a script has to notice them\n"
              "and a person can't. Each one you accept is a `process` lesson, not a shrug.")
    sys.exit(1 if fails or (a.strict and warns) else 0)


if __name__ == "__main__":
    main()
