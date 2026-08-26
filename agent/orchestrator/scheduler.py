#!/usr/bin/env python3
"""Harness scheduler — validate the task DAG, report status, pick what's next.

Usage:
  python3 agent/orchestrator/scheduler.py --validate
  python3 agent/orchestrator/scheduler.py --next [--limit N] [--layer L] [--tight]
  python3 agent/orchestrator/scheduler.py --status
  python3 agent/orchestrator/scheduler.py --review-queue

Reads epics/*/epic.md + epics/*/tasks/*.md (YAML frontmatter).
Statuses: todo → in-progress → review-requested → (changes-requested →)
done → verified · side: blocked, frozen.
Pick order: P1 bugs → MoSCoW → parent-epic WSJF → critical path → (--tight)
smallest token tier. Skips tasks colliding on files with in-flight tasks
(frontmatter `files:`) and respects the WIP limit.

--validate also enforces the harness rules that are checkable:
  rule 1  every task traces to a spec id
  rule 2  every frontend task has a design_contract that exists on disk
  rule 4  the dependency DAG is acyclic and every dep resolves
"""
import argparse, glob, json, os, re, sys
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
MOSCOW = {"must": 0, "should": 1, "could": 2, "wont": 3}
TIER = {"S": 0, "M": 1, "L": 2}
DONE = {"done", "verified"}
IN_FLIGHT = {"in-progress", "review-requested", "changes-requested"}
ORDER = ["todo", "in-progress", "review-requested", "changes-requested",
         "blocked", "frozen", "done", "verified"]


def frontmatter(path):
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return {}
    m = re.match(r"\s*---\s*\n(.*?)\n---\s*\n", text, re.S)
    if not m:
        return {}
    try:
        data = yaml.safe_load(m.group(1)) or {}
        return data if isinstance(data, dict) else {}
    except yaml.YAMLError as e:
        print(f"harness: ⚠ bad frontmatter in {os.path.relpath(path, ROOT)}: {e}", file=sys.stderr)
        return {}


def deps(t):
    return list(t.get("depends_on") or t.get("depends") or [])


def load():
    epics, tasks = {}, {}
    for ep in sorted(glob.glob(os.path.join(ROOT, "epics", "E*", "epic.md"))):
        fm = frontmatter(ep)
        eid = str(fm.get("id") or os.path.basename(os.path.dirname(ep)).split("-")[0])
        fm.setdefault("wsjf", (fm.get("priority") or {}).get("wsjf", 0))
        epics[eid] = fm
        for tp in sorted(glob.glob(os.path.join(os.path.dirname(ep), "tasks", "*.md"))):
            t = frontmatter(tp)
            tid = str(t.get("id") or os.path.splitext(os.path.basename(tp))[0])
            t["_path"], t["_epic"], t["id"] = os.path.relpath(tp, ROOT), eid, tid
            t.setdefault("status", "todo")
            tasks[tid] = t
    return epics, tasks


def validate(epics, tasks):
    errs = []
    for tid, t in tasks.items():
        for d in deps(t):
            if d not in tasks and d not in epics:
                errs.append(f"{tid}: unknown dependency '{d}'")
        if str(t.get("status")) not in ORDER:
            errs.append(f"{tid}: unknown status '{t.get('status')}'")
        if t.get("status") == "todo" and not (t.get("traces_to") or t.get("type") == "genesis"):
            errs.append(f"{tid}: missing traces_to (rule 1 — spec is law)")
        # rule 2 — a frontend task without a design contract cannot be gated,
        # which means it cannot be trusted to match the design.
        if str(t.get("layer", "")) == "frontend" and t.get("type") != "genesis":
            dc = t.get("design_contract")
            if not dc:
                errs.append(f"{tid}: layer=frontend without design_contract "
                            f"(rule 2 — see skills/design-fidelity)")
            elif not os.path.exists(os.path.join(ROOT, str(dc))):
                errs.append(f"{tid}: design_contract '{dc}' does not exist "
                            f"(run: make design-extract && make design-contract)")
    children = {k: [] for k in tasks}
    indeg = {k: 0 for k in tasks}
    for k, t in tasks.items():
        for d in deps(t):
            if d in tasks:
                children[d].append(k)
                indeg[k] += 1
    q, seen = [k for k, v in indeg.items() if v == 0], 0
    while q:
        n = q.pop(); seen += 1
        for c in children[n]:
            indeg[c] -= 1
            if indeg[c] == 0:
                q.append(c)
    if seen != len(tasks):
        errs.append(f"dependency CYCLE among {len(tasks) - seen} task(s)")
    return errs, children


def chain_len(tid, children, memo):
    if tid in memo:
        return memo[tid]
    memo[tid] = 1 + max((chain_len(c, children, memo) for c in children.get(tid, [])), default=0)
    return memo[tid]


def ready(epics, tasks, children, layer=None, tight=False):
    in_flight = [t for t in tasks.values() if t.get("status") in IN_FLIGHT]
    busy = set()
    for t in in_flight:
        f = t.get("files") or {}
        busy.update((f.get("create") or []) + (f.get("update") or []))
    memo, out = {}, []
    for tid, t in tasks.items():
        if t.get("status") != "todo":
            continue
        if layer and str(t.get("layer", "")) != layer:
            continue
        unmet = any((tasks.get(d, {}).get("status") not in DONE) if d in tasks
                    else (epics.get(d, {}).get("status") not in DONE) for d in deps(t))
        if unmet:
            continue
        f = t.get("files") or {}
        mine = set((f.get("create") or []) + (f.get("update") or []))
        if mine & busy:
            continue
        pr = t.get("priority") or {}
        p1bug = 0 if (t.get("type") == "bug" and str(pr.get("p", "")).upper() == "P1") else 1
        mos = MOSCOW.get(str(pr.get("moscow", "should")).lower(), 1)
        wsjf = -(float((epics.get(t["_epic"], {}) or {}).get("wsjf") or 0))
        crit = -chain_len(tid, children, memo)
        tier = TIER.get(str((t.get("token_estimate") or {}).get("tier", "M")).upper(), 1) if tight else 0
        out.append((p1bug, mos, wsjf, crit, tier, tid))
    out.sort()
    return [tid for *_, tid in out], len(in_flight)


def show_status(epics, tasks):
    tot = {s: 0 for s in ORDER}
    print(f"{'epic':<6} {'title':<42} {'prog':>7}  per-status")
    for eid, e in sorted(epics.items()):
        mine = [t for t in tasks.values() if t["_epic"] == eid]
        c = {s: 0 for s in ORDER}
        for t in mine:
            c[str(t.get("status"))] = c.get(str(t.get("status")), 0) + 1
            tot[str(t.get("status"))] = tot.get(str(t.get("status")), 0) + 1
        donez = c["done"] + c["verified"]
        line = " ".join(f"{s}:{c[s]}" for s in ORDER if c[s])
        print(f"{eid:<6} {str(e.get('title',''))[:42]:<42} {donez:>3}/{len(mine):<3}  {line or '—'}")
    print("totals: " + " ".join(f"{s}:{tot[s]}" for s in ORDER if tot[s]))


# Field names each knowledge-map node may carry. Mirrors
# schemas/knowledge-map.schema.yaml; kept as a plain set so this check needs
# nothing beyond pyyaml (ADR: the harness stays stdlib + pyyaml).
MAP_KEYS = {
    "facts": {"id", "statement", "source", "inferred"},
    "assumptions": {"id", "statement", "made_because", "risk_if_wrong", "status",
                    "from_question", "impact_report"},
    "decisions": {"id", "summary", "path", "status", "supersedes"},
    "features": {"id", "summary", "path", "status"},
    "journeys": {"id", "summary", "path", "status"},
    "business_rules": {"id", "summary", "path", "status"},
    "data_models": {"id", "summary", "path", "status"},
    "apis": {"id", "summary", "path", "status"},
    "integrations": {"id", "summary", "path", "status"},
    "constraints": {"id", "summary", "path", "status"},
    "risks": {"id", "summary", "path", "status", "severity", "mitigation"},
    "open_questions": {"id", "summary", "priority", "area", "path"},
    "edges": {"from", "to", "kind", "note"},
}


def validate_knowledge_map():
    """Lint spec/knowledge-map.yaml for keys that leaked out of flow style.

    Promoted from a lesson to a hook after recurring twice (retro 2026-08-24).
    In YAML flow style an unquoted comma silently starts a NEW KEY:

        - { id: F-008, statement: Default 30 days, overridable per link }

    parses as a node with a bogus `overridable per link` key, and the fact's
    statement is truncated. It reads fine in review, and the map is quietly
    wrong. Any unexpected key is almost always this.
    """
    path = os.path.join(ROOT, "spec", "knowledge-map.yaml")
    if not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8") as fh:
            data = yaml.safe_load(fh) or {}
    except yaml.YAMLError as e:
        return [f"spec/knowledge-map.yaml: unparseable ({e})"]
    if not isinstance(data, dict):
        return ["spec/knowledge-map.yaml: top level is not a mapping"]

    errs = []
    reqs = data.get("requirements") or {}
    sections = list(MAP_KEYS.items())
    if isinstance(reqs, dict):
        for k in ("functional", "non_functional"):
            sections.append((f"requirements.{k}", {"id", "summary", "path", "status"}))
    for name, allowed in sections:
        if "." in name:
            items = (reqs or {}).get(name.split(".", 1)[1]) or []
        else:
            items = data.get(name) or []
        if not isinstance(items, list):
            continue
        for i, node in enumerate(items):
            if not isinstance(node, dict):
                continue
            extra = set(node) - allowed
            if extra:
                errs.append(
                    f"spec/knowledge-map.yaml: {name}[{i}] has unexpected key(s) "
                    f"{sorted(extra)} — usually an unquoted comma in flow style; "
                    f"quote the value")
    return errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--validate", action="store_true")
    ap.add_argument("--next", action="store_true")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--review-queue", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--layer", default=None, help="backend|frontend|cli|infra|docs|cross-cutting")
    ap.add_argument("--tight", action="store_true", help="rate-limit window low: prefer small tasks")
    a = ap.parse_args()
    epics, tasks = load()
    errs, children = validate(epics, tasks)
    errs += validate_knowledge_map()

    if a.status:
        show_status(epics, tasks); sys.exit(0)
    if a.review_queue:
        q = [t for t in tasks.values() if t.get("status") in ("review-requested", "changes-requested")]
        for t in sorted(q, key=lambda x: x["id"]):
            print(f"{t['id']:<10} {t.get('status'):<18} executed_by={t.get('executed_by') or '?'}  {t['_path']}")
        print(f"harness: {len(q)} in review queue"); sys.exit(0)
    if a.validate or not a.next:
        for e in errs:
            print("✗", e)
        print(f"harness: {len(epics)} epics, {len(tasks)} tasks — " + ("DAG OK ✓" if not errs else f"{len(errs)} problem(s)"))
        sys.exit(1 if errs else 0)
    if errs:
        print("harness: fix --validate errors first", file=sys.stderr); sys.exit(1)

    picks, in_flight = ready(epics, tasks, children, layer=a.layer, tight=a.tight)
    wip = 3
    try:
        cfg = yaml.safe_load(open(os.path.join(ROOT, "harness.yaml"), encoding="utf-8")) or {}
        wip = int(((cfg.get("scheduler") or {}).get("wip_limit_parallel_agents")) or 3)
    except OSError:
        pass
    slots = max(0, wip - in_flight)
    n = min(len(picks), a.limit or slots or 1)
    result = [{"task": tid, "epic": tasks[tid]["_epic"], "layer": tasks[tid].get("layer", ""),
               "model": tasks[tid].get("model", "sonnet"),
               "owner": tasks[tid].get("owner_agent", "builder"),
               "preferred_agent": tasks[tid].get("preferred_agent", "any"),
               "path": tasks[tid]["_path"]} for tid in picks[:n]]
    print(json.dumps({"in_flight": in_flight, "wip_limit": wip, "next": result}, indent=2))


if __name__ == "__main__":
    main()
