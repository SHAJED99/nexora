#!/usr/bin/env python3
"""Compute the requirement -> epic -> ADR -> task -> code -> test -> doc chain
and render docs/traceability.md.

The report is COMPUTED, never maintained (skills/traceability). Every number
here is derived from files that already exist: `spec/srs.md` ids, `traces_to:`
frontmatter, `files:` lists, EARS-named tests. If this script and the repo
disagree, the repo wins -- regenerate, never patch.

Report, do not repair: an orphan leaves as a row in a table, never as an edit.

Usage:
    python agent/orchestrator/traceability.py             # render docs/traceability.md
    python agent/orchestrator/traceability.py --check     # non-zero exit if blocking orphans
    python agent/orchestrator/traceability.py --id FR-AUTH-001   # scoped walk, stdout
    python agent/orchestrator/traceability.py --json      # machine-readable, stdout
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import subprocess
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_PATH = os.path.join("docs", "traceability.md")

# `scheduler.py` globs `epics/E*/epic.md` and `epics/E*/tasks/*.md` -- match it
# exactly. A lowercase `epic-01-core/` matches on Windows and silently matches
# nothing on Linux, so the shape is deliberate, not incidental.
EPIC_GLOB = "epics"

# The separator after the id is `:` for a live requirement but an em-dash for a
# descoped one (`- **FR-TRUST-007** — DESCOPED ...`). Accept both, or a descoped
# requirement reads as a task citing something nobody specified.
REQ_RE = re.compile(r"^\s*[-*]\s+\*\*((?:FR|NFR)-[A-Z]+-\d+)\*\*\s*[:—-]\s*(.*)$")
DESCOPED_RE = re.compile(r"DESCOPED|⛔")
REQ_ID_RE = re.compile(r"\b((?:FR|NFR)-[A-Z]+-\d+)\b")
EARS_BULLET_RE = re.compile(r"^\s*[-*]\s+\*\*(EARS-[A-Z0-9]+-[A-Za-z0-9]+)\*\*\s*:\s*(.*)$")
EARS_ID_RE = re.compile(r"\b(EARS-[A-Z0-9]+-[A-Za-z0-9]+)\b")
# test_EARS_<AREA>_<NUM>[letter]_<name>  ->  EARS-<AREA>-<NUM>[letter]
TEST_RE = re.compile(r"test_EARS_([A-Z0-9]+)_([0-9]+[a-z]?|x[0-9]+)(?:_|\b)")
ADR_RE = re.compile(r"\b(ADR-\d{4})\b")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
BULLET_START_RE = re.compile(r"^\s*[-*]\s+")


def read(path):
    try:
        with io.open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except (IOError, OSError):
        return ""


def git(*args):
    try:
        out = subprocess.run(
            ["git"] + list(args), cwd=ROOT, capture_output=True, text=True,
            encoding="utf-8", errors="replace",
        )
        return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def parse_frontmatter(text):
    """Minimal YAML-ish frontmatter reader, indentation-driven.

    Deliberately not a YAML parser: the harness only needs scalars, inline
    `[a, b]` lists, `- item` block lists and one level of nesting (`files:`
    with `create:`/`update:`/`delete:` beneath). Taking a YAML dependency to
    read frontmatter would be a rule-3 call.
    """
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}

    def scalar(val):
        val = re.split(r"\s+#", val, 1)[0].strip()
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            return [v.strip().strip("'\"") for v in inner.split(",") if v.strip()]
        return val.strip("'\"")

    data = {}
    top = None        # current top-level key awaiting a block
    sub = None        # current nested key under `top`
    for raw in text[3:end].splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip())
        line = raw.strip()

        if indent == 0:
            m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", line)
            if not m:
                continue
            top, sub = m.group(1), None
            val = m.group(2)
            data[top] = scalar(val) if val.strip() else []
            continue

        if top is None:
            continue

        if line.startswith("- "):
            item = line[2:].strip().strip("'\"")
            target = data[top][sub] if sub else data[top]
            if isinstance(target, list):
                target.append(item)
            continue

        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", line)
        if m:
            if not isinstance(data.get(top), dict):
                data[top] = {}
            sub = m.group(1)
            val = m.group(2)
            data[top][sub] = scalar(val) if val.strip() else []
    return data


def bullet_block(lines, idx):
    """Return the full text of the bullet starting at `idx`.

    THE JOIN THAT BITES: an EARS criterion wraps onto a second line, so the
    requirement ids it cites may live below the first line. Match to the end of
    the BULLET -- next bullet, blank line or heading -- never to end-of-line.
    Anchoring this wrong reports 0% proven, which reads as catastrophic project
    failure rather than a broken regex.
    """
    out = [lines[idx]]
    for nxt in lines[idx + 1:]:
        if not nxt.strip() or BULLET_START_RE.match(nxt) or HEADING_RE.match(nxt):
            break
        out.append(nxt)
    return "\n".join(out)


def harvest_requirements():
    """spec/srs.md -> {id: {title, section}}. A requirement heading owns the
    bullets beneath it, so an uncited bullet still resolves to its parent."""
    reqs, section = {}, ""
    text = read(os.path.join(ROOT, "spec", "srs.md"))
    lines = text.splitlines()
    for i, line in enumerate(lines):
        h = HEADING_RE.match(line)
        if h and len(h.group(1)) <= 2:
            section = h.group(2).strip()
        m = REQ_RE.match(line)
        if m:
            block = bullet_block(lines, i)
            title = re.sub(r"\*\(traces_to:.*?\)\*", "", m.group(2)).strip()
            reqs[m.group(1)] = {
                "title": title,
                "section": section,
                # A descoped requirement is not unproven work, so it is harvested
                # (to keep it out of `task citing an unknown requirement`) but
                # held out of the orphan classes.
                "descoped": bool(DESCOPED_RE.search(block)),
            }
    return reqs


def harvest_epics():
    epics = {}
    base = os.path.join(ROOT, EPIC_GLOB)
    if not os.path.isdir(base):
        return epics
    for name in sorted(os.listdir(base)):
        epic_md = os.path.join(base, name, "epic.md")
        if not os.path.isfile(epic_md):
            continue
        m = re.match(r"^(E\d{2})", name)
        if not m:
            continue
        text = read(epic_md)
        fm = parse_frontmatter(text)
        epics[m.group(1)] = {
            "dir": name,
            "title": (fm.get("title") or name),
            "traces_to": fm.get("traces_to") or [],
            "path": os.path.join(EPIC_GLOB, name, "epic.md").replace("\\", "/"),
            "text": text,
        }
    return epics


def harvest_tasks():
    tasks = {}
    base = os.path.join(ROOT, EPIC_GLOB)
    if not os.path.isdir(base):
        return tasks
    for name in sorted(os.listdir(base)):
        tdir = os.path.join(base, name, "tasks")
        if not os.path.isdir(tdir):
            continue
        for fn in sorted(os.listdir(tdir)):
            if not fn.endswith(".md"):
                continue
            path = os.path.join(tdir, fn)
            text = read(path)
            fm = parse_frontmatter(text)
            tid = fm.get("id") or os.path.splitext(fn)[0]
            files = fm.get("files") or {}
            claimed = []
            if isinstance(files, dict):
                for bucket in ("create", "update"):
                    claimed.extend(files.get(bucket) or [])
            tasks[tid] = {
                "epic": fm.get("epic") or (re.match(r"^(E\d{2})", name).group(1) if re.match(r"^(E\d{2})", name) else ""),
                "status": fm.get("status") or "unknown",
                "traces_to": fm.get("traces_to") or [],
                "depends_on": fm.get("depends_on") or [],
                "design_contract": fm.get("design_contract") or "",
                "layer": fm.get("layer") or "",
                "files": [f for f in claimed if f],
                "path": os.path.join(EPIC_GLOB, name, "tasks", fn).replace("\\", "/"),
                "text": text,
                "open_questions": len(re.findall(r"Status:\*{0,2}\s*🟡", text)),
            }
    return tasks


def harvest_ears(epics, tasks):
    """EARS id -> {requirements, sources}. Criteria are declared in epic.md and
    refined in task files, so both are harvested."""
    ears = defaultdict(lambda: {"requirements": set(), "sources": set(), "text": ""})
    sources = [(e["path"], e["text"]) for e in epics.values()]
    sources += [(t["path"], t["text"]) for t in tasks.values()]
    for path, text in sources:
        lines = text.splitlines()
        heading_reqs = set()
        for i, line in enumerate(lines):
            h = HEADING_RE.match(line)
            if h:
                heading_reqs = set(REQ_ID_RE.findall(h.group(2)))
            m = EARS_BULLET_RE.match(line)
            if not m:
                continue
            eid = m.group(1)
            block = bullet_block(lines, i)
            cited = set(REQ_ID_RE.findall(block))
            if not cited:
                cited = set(heading_reqs)
            ears[eid]["requirements"] |= cited
            ears[eid]["sources"].add(path)
            if not ears[eid]["text"]:
                ears[eid]["text"] = m.group(2).strip()
    return ears


def harvest_tests():
    """EARS id -> sorted list of test files declaring it."""
    tests = defaultdict(set)
    for base in ("test", "integration_test"):
        root = os.path.join(ROOT, base)
        if not os.path.isdir(root):
            continue
        for dirpath, _dirs, files in os.walk(root):
            for fn in files:
                if not fn.endswith(".dart"):
                    continue
                path = os.path.join(dirpath, fn)
                rel = os.path.relpath(path, ROOT).replace("\\", "/")
                for area, num in TEST_RE.findall(read(path)):
                    tests["EARS-%s-%s" % (area, num)].add(rel)
    return tests


def harvest_adrs():
    adrs = {}
    base = os.path.join(ROOT, "agent", "memory", "decisions")
    if not os.path.isdir(base):
        return adrs
    for fn in sorted(os.listdir(base)):
        m = re.match(r"^(ADR-\d{4})", fn)
        if not m or "template" in fn:
            continue
        text = read(os.path.join(base, fn))
        fm = parse_frontmatter(text)
        status = fm.get("status") or ""
        if not status:
            s = re.search(r"^\s*(?:\*\*)?[Ss]tatus(?:\*\*)?\s*[:|]\s*(.+)$", text, re.M)
            status = s.group(1).strip() if s else "unknown"
        adrs[m.group(1)] = {
            "status": re.sub(r"[*`]", "", status)[:60],
            "path": "agent/memory/decisions/%s" % fn,
        }
    return adrs


def harvest_design():
    contracts = {}
    base = os.path.join(ROOT, "design", "screens")
    if not os.path.isdir(base):
        return contracts
    for fn in sorted(os.listdir(base)):
        if fn.endswith(".md") and not fn.startswith("_"):
            contracts["design/screens/%s" % fn] = {"path": "design/screens/%s" % fn}
    return contracts


def build(model_only=False):
    reqs = harvest_requirements()
    epics = harvest_epics()
    tasks = harvest_tasks()
    ears = harvest_ears(epics, tasks)
    tests = harvest_tests()
    adrs = harvest_adrs()
    contracts = harvest_design()

    req_tasks = defaultdict(set)
    req_epics = defaultdict(set)
    unknown_refs = defaultdict(set)
    for tid, t in tasks.items():
        for rid in t["traces_to"]:
            if rid in reqs:
                req_tasks[rid].add(tid)
                if t["epic"]:
                    req_epics[rid].add(t["epic"])
            elif REQ_ID_RE.match(rid):
                # `traces_to:` legitimately carries ADR-, EARS-, GAP-, Q- ids and
                # design-contract paths too. Only an FR/NFR id that `spec/srs.md`
                # does not define is a finding: that is a task building something
                # nobody specified.
                unknown_refs[rid].add(tid)
    for eid, e in epics.items():
        for rid in e["traces_to"]:
            if rid in reqs:
                req_epics[rid].add(eid)

    req_ears = defaultdict(set)
    for eid, info in ears.items():
        for rid in info["requirements"]:
            if rid in reqs:
                req_ears[rid].add(eid)

    req_tests = defaultdict(set)
    for rid, eids in req_ears.items():
        for eid in eids:
            req_tests[rid] |= tests.get(eid, set())

    # ADR citations across epics + tasks
    adr_cited = defaultdict(set)
    for tid, t in tasks.items():
        for aid in set(ADR_RE.findall(t["text"])):
            adr_cited[aid].add(tid)
    for eid, e in epics.items():
        for aid in set(ADR_RE.findall(e["text"])):
            adr_cited[aid].add(eid)

    # design contracts claimed by tasks
    contract_tasks = defaultdict(set)
    for tid, t in tasks.items():
        dc = (t["design_contract"] or "").strip()
        if dc and dc not in ("n/a", "none", "-"):
            contract_tasks[dc].add(tid)

    claimed_files = set()
    for t in tasks.values():
        for f in t["files"]:
            claimed_files.add(f.replace("\\", "/"))

    # Which EARS criteria each task declares in its OWN file. A task that
    # declares none inherits its epic's criteria, so it is judged on whether the
    # requirements it traces to reach a test instead -- not on a criterion it
    # never claimed.
    task_ears = defaultdict(set)
    for eid, info in ears.items():
        for src in info["sources"]:
            for tid, t in tasks.items():
                if t["path"] == src:
                    task_ears[tid].add(eid)

    def task_reaches_test(tid, t):
        own = task_ears.get(tid)
        if own:
            return any(tests.get(e) for e in own)
        rids = [r for r in t["traces_to"] if r in reqs]
        return any(req_tests.get(r) for r in rids) if rids else True

    done = {"done", "verified"}
    live = [r for r in reqs if not reqs[r].get("descoped")]
    orphans = {
        "req_no_epic": sorted(r for r in live if not req_epics.get(r)),
        "req_no_task": sorted(r for r in live if not req_tasks.get(r)),
        "req_no_ears": sorted(r for r in live if not req_ears.get(r)),
        "req_no_test": sorted(r for r in live if not req_tests.get(r)),
        "task_no_traces": sorted(t for t, v in tasks.items() if not v["traces_to"]),
        "task_unknown_req": sorted("%s (in %s)" % (r, ", ".join(sorted(v))) for r, v in unknown_refs.items()),
        "done_no_test": sorted(
            t for t, v in tasks.items()
            if v["status"] in done and not task_reaches_test(t, v)
        ),
        "ears_no_test": sorted(e for e in ears if not tests.get(e)),
        "ears_no_req": sorted(e for e, v in ears.items() if not v["requirements"]),
        "test_no_ears": sorted(e for e in tests if e not in ears),
        "adr_uncited": sorted(a for a in adrs if not adr_cited.get(a)),
        "adr_superseded_cited": sorted(
            a for a, v in adrs.items()
            if "supersed" in v["status"].lower() and adr_cited.get(a)
        ),
        "contract_unbuilt": sorted(c for c in contracts if not contract_tasks.get(c)),
        "dep_order": sorted(
            "%s -> %s (%s)" % (t, d, tasks.get(d, {}).get("status", "missing"))
            for t, v in tasks.items() if v["status"] in done
            for d in v["depends_on"]
            if d in tasks and tasks[d]["status"] not in done
        ),
        "task_open_question": sorted(t for t, v in tasks.items() if v["open_questions"] and v["status"] in done),
    }

    model = {
        "requirements": reqs, "epics": epics, "tasks": tasks,
        "ears": {k: {"requirements": sorted(v["requirements"]),
                     "sources": sorted(v["sources"]), "text": v["text"]}
                 for k, v in ears.items()},
        "tests": {k: sorted(v) for k, v in tests.items()},
        "adrs": adrs, "contracts": contracts,
        "req_tasks": {k: sorted(v) for k, v in req_tasks.items()},
        "req_epics": {k: sorted(v) for k, v in req_epics.items()},
        "req_ears": {k: sorted(v) for k, v in req_ears.items()},
        "req_tests": {k: sorted(v) for k, v in req_tests.items()},
        "adr_cited": {k: sorted(v) for k, v in adr_cited.items()},
        "contract_tasks": {k: sorted(v) for k, v in contract_tasks.items()},
        "claimed_files": sorted(claimed_files),
        "orphans": orphans,
    }
    return model


BLOCKING = [
    ("req_no_test", "requirement with no EARS-named test"),
    ("done_no_test", "`done` task with no passing EARS test"),
    ("dep_order", "`done` task whose dependency is not done"),
    ("adr_superseded_cited", "superseded ADR still cited"),
]

ROUTES = {
    "req_no_epic": ("requirement with no epic", "scope never planned", "skills/epic-breakdown"),
    "req_no_task": ("requirement with no task", "epic never sharded, or sharded incompletely", "skills/epic-breakdown"),
    "req_no_ears": ("requirement owning no EARS criterion", "invisible to the join; prose cross-references do not count", "skills/task-sharding"),
    "req_no_test": ("requirement with no test", "rule 7 breach — unproven, not done", "new test task"),
    "task_no_traces": ("task with empty `traces_to:`", "rule 1 breach — it isn't a task", "skills/question-resolution"),
    "task_unknown_req": ("task citing a requirement not in `spec/srs.md`", "building something nobody specified", "skills/change-impact"),
    "done_no_test": ("`done` task with no EARS test", '"done" that isn\'t', "revalidation task"),
    "ears_no_test": ("EARS criterion with no test", "criterion asserted, never proven", "new test task"),
    "ears_no_req": ("EARS criterion citing no requirement", "proves nothing traceable", "skills/task-sharding"),
    "test_no_ears": ("test matching no declared EARS id", "proves nothing traceable", "rename or delete task"),
    "adr_uncited": ("ADR nothing cites", "dead decision, or decisions being made in diffs", "audit or supersede"),
    "adr_superseded_cited": ("superseded ADR still cited", "task honouring a reversed decision", "skills/change-impact"),
    "contract_unbuilt": ("design contract no task builds", "rule 2 breach — screen unbuilt or built off-contract", "skills/design-fidelity"),
    "dep_order": ("`done` task whose `depends_on` is not done", "state-ordering violation; `make validate` does NOT catch this", "skills/review"),
    "task_open_question": ("`done` task carrying a 🟡 open question", "blocked in fact but not in status", "skills/question-resolution"),
}


def render(model):
    reqs = model["requirements"]
    total = len(reqs)
    with_epic = sum(1 for r in reqs if model["req_epics"].get(r))
    with_task = sum(1 for r in reqs if model["req_tasks"].get(r))
    with_ears = sum(1 for r in reqs if model["req_ears"].get(r))
    with_test = sum(1 for r in reqs if model["req_tests"].get(r))

    def pct(n):
        return "0.0%" if not total else "%.1f%%" % (100.0 * n / total)

    head = git("rev-parse", "--short", "HEAD") or "unknown"
    when = git("show", "-s", "--format=%cs", "HEAD") or "unknown"

    L = []
    a = L.append
    a("# Traceability matrix")
    a("")
    a("> **Generated — do not edit by hand.** Regenerate with `make trace`.")
    a("> Every number below is derived from `spec/srs.md`, `traces_to:` frontmatter,")
    a("> `files:` lists and EARS-named tests. If this report and the repo disagree,")
    a("> the repo wins: regenerate, never patch.")
    a("")
    a("Generated from commit `%s` (%s) by `agent/orchestrator/traceability.py`." % (head, when))
    a("")
    a("## Coverage")
    a("")
    a("| Metric | Count | Share |")
    a("|---|---:|---:|")
    descoped = sum(1 for r in reqs.values() if r.get("descoped"))
    a("| Requirements in `spec/srs.md` | %d | — |" % total)
    a("| …of which descoped (held out of orphan classes) | %d | %s |" % (descoped, pct(descoped)))
    a("| …mapped to an epic | %d | %s |" % (with_epic, pct(with_epic)))
    a("| …mapped to a task | %d | %s |" % (with_task, pct(with_task)))
    a("| …owning an EARS criterion | %d | %s |" % (with_ears, pct(with_ears)))
    a("| …reaching an EARS-named test | %d | %s |" % (with_test, pct(with_test)))
    a("")
    a("| Artifact | Count |")
    a("|---|---:|")
    a("| Epics | %d |" % len(model["epics"]))
    a("| Tasks | %d |" % len(model["tasks"]))
    a("| EARS criteria declared | %d |" % len(model["ears"]))
    a("| EARS ids with >=1 test | %d |" % sum(1 for e in model["ears"] if model["tests"].get(e)))
    a("| Distinct EARS ids found in tests | %d |" % len(model["tests"]))
    a("| ADRs | %d |" % len(model["adrs"]))
    a("| Design contracts | %d |" % len(model["contracts"]))
    a("")
    a("**A requirement is *proven* only when the chain reaches a passing test.**")
    a("This report proves the chain reaches a test that *exists*; whether the suite")
    a("is green is the CI gate's answer, not this file's.")
    a("")
    a("## Chain matrix")
    a("")
    a("| Requirement | Epics | Tasks | EARS | Tests |")
    a("|---|---|---|---|---:|")
    for rid in sorted(reqs):
        ep = ", ".join(model["req_epics"].get(rid, [])) or "—"
        tk = ", ".join(model["req_tasks"].get(rid, [])) or "—"
        ea = ", ".join(model["req_ears"].get(rid, [])) or "—"
        nt = len(model["req_tests"].get(rid, []))
        a("| `%s` | %s | %s | %s | %s |" % (rid, ep, tk, ea, nt or "—"))
    a("")
    a("## Orphans")
    a("")
    a("Both directions. Forward gaps hide missing work; backward gaps hide")
    a("**unspecified** work, which is worse, because unspecified work still ships.")
    a("")
    a("| Class | Count | Means | Route to | Release blocker |")
    a("|---|---:|---|---|---|")
    blocking_keys = {k for k, _ in BLOCKING}
    for key, (label, means, route) in ROUTES.items():
        n = len(model["orphans"].get(key, []))
        a("| %s | %d | %s | `%s` | %s |" % (
            label, n, means, route, "**yes**" if key in blocking_keys else "no"))
    a("")
    for key, (label, _means, route) in ROUTES.items():
        items = model["orphans"].get(key, [])
        if not items:
            continue
        a("### %s — %d" % (label, len(items)))
        a("")
        a("Route to `%s`." % route)
        a("")
        for item in items:
            a("- `%s`" % item)
        a("")
    a("## Release gate")
    a("")
    a("`skills/release` treats these classes as **blockers, not release notes**.")
    a("")
    a("| Blocking class | Count | Clear? |")
    a("|---|---:|---|")
    blocked = 0
    for key, label in BLOCKING:
        n = len(model["orphans"].get(key, []))
        blocked += n
        a("| %s | %d | %s |" % (label, n, "✅" if n == 0 else "❌"))
    a("")
    a("**Blocking orphans: %d.** %s" % (
        blocked,
        "Release gate clear on traceability." if blocked == 0
        else "These are release blockers. Orphans knowingly shipped belong in the changelog's Known gaps."))
    a("")
    return "\n".join(L) + "\n"


def walk(model, ident):
    out = []
    a = out.append
    if ident in model["requirements"]:
        a("%s — %s" % (ident, model["requirements"][ident]["title"][:100]))
        a("  epics : %s" % (", ".join(model["req_epics"].get(ident, [])) or "— (orphan)"))
        a("  tasks : %s" % (", ".join(model["req_tasks"].get(ident, [])) or "— (orphan)"))
        a("  EARS  : %s" % (", ".join(model["req_ears"].get(ident, [])) or "— (orphan)"))
        for t in model["req_tests"].get(ident, []):
            a("  test  : %s" % t)
        if not model["req_tests"].get(ident):
            a("  test  : — (UNPROVEN)")
    elif ident in model["tasks"]:
        t = model["tasks"][ident]
        a("%s [%s] epic %s" % (ident, t["status"], t["epic"]))
        a("  traces_to : %s" % (", ".join(t["traces_to"]) or "— (rule 1 breach)"))
        a("  files     : %s" % (", ".join(t["files"]) or "—"))
        a("  depends_on: %s" % (", ".join(t["depends_on"]) or "—"))
        for e, info in sorted(model["ears"].items()):
            if t["path"] in info["sources"]:
                a("  EARS      : %s -> %d test(s)" % (e, len(model["tests"].get(e, []))))
        commits = git("log", "--oneline", "--grep", ident, "-n", "10")
        for line in (commits.splitlines() if commits else []):
            a("  commit    : %s" % line)
    elif ident in model["ears"]:
        info = model["ears"][ident]
        a("%s" % ident)
        a("  requirements: %s" % (", ".join(info["requirements"]) or "— (orphan)"))
        a("  declared in : %s" % ", ".join(info["sources"]))
        for t in model["tests"].get(ident, []):
            a("  test        : %s" % t)
    else:
        hits = [t for t, v in model["tasks"].items() if ident.replace("\\", "/") in v["files"]]
        if hits:
            a("%s" % ident)
            for t in hits:
                a("  claimed by task %s -> traces_to %s" % (t, ", ".join(model["tasks"][t]["traces_to"])))
        else:
            a("%s — no requirement, task or EARS id matches, and no task's `files:` claims it." % ident)
            a("  A file that walks back to nothing IS the finding (skills/change-impact).")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description="requirement -> task -> test traceability audit")
    ap.add_argument("--id", help="scoped walk for one FR/NFR, task id, EARS id or file path")
    ap.add_argument("--json", action="store_true", help="machine-readable model to stdout")
    ap.add_argument("--check", action="store_true", help="exit 1 if any blocking orphan class is non-empty")
    ap.add_argument("--out", default=OUT_PATH, help="output path (default docs/traceability.md)")
    ap.add_argument("--stdout", action="store_true", help="render to stdout instead of writing")
    args = ap.parse_args()

    model = build()

    if args.id:
        sys.stdout.write(walk(model, args.id))
        return 0
    if args.json:
        sys.stdout.write(json.dumps(model, indent=2, sort_keys=True, default=list) + "\n")
        return 0

    text = render(model)
    if args.stdout:
        sys.stdout.write(text)
    else:
        path = os.path.join(ROOT, args.out)
        dirname = os.path.dirname(path)
        if dirname and not os.path.isdir(dirname):
            os.makedirs(dirname)
        with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        blocking = sum(len(model["orphans"].get(k, [])) for k, _ in BLOCKING)
        reqs = len(model["requirements"])
        proven = sum(1 for r in model["requirements"] if model["req_tests"].get(r))
        sys.stdout.write(
            "trace: %d requirements, %d reaching a test (%.1f%%), %d blocking orphans -> %s\n"
            % (reqs, proven, (100.0 * proven / reqs) if reqs else 0.0, blocking, args.out))

    if args.check:
        blocking = sum(len(model["orphans"].get(k, [])) for k, _ in BLOCKING)
        if blocking:
            sys.stderr.write("trace: %d blocking orphan(s) — release gate NOT clear\n" % blocking)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
