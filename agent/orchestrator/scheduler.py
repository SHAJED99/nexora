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
# The status vocabulary. Declared in harness.yaml so the config is load-bearing
# rather than decorative: previously this list was hardcoded here AND declared in
# harness.yaml scheduler.statuses, so adding a status to the yaml made
# `make validate` reject it as unknown instead of accepting it.
_ORDER_FALLBACK = ["todo", "in-progress", "review-requested", "changes-requested",
                   "blocked", "frozen", "done", "verified"]


def _statuses():
    try:
        with open(os.path.join(ROOT, "harness.yaml"), encoding="utf-8") as fh:
            cfg = yaml.safe_load(fh) or {}
        declared = ((cfg.get("scheduler") or {}).get("statuses")) or []
    except (OSError, yaml.YAMLError):
        declared = []
    if not isinstance(declared, list) or not declared:
        return list(_ORDER_FALLBACK)
    # DONE / IN_FLIGHT above are semantic groupings, so a project may reorder or
    # extend statuses but the two terminal ones must still exist.
    missing = [s for s in ("todo", "done") if s not in declared]
    return list(_ORDER_FALLBACK) if missing else [str(s) for s in declared]


ORDER = _statuses()


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
    # Epic-level depends_on was neither validated nor honoured: an epic could
    # declare depends_on a nonexistent epic with no error, and its tasks
    # dispatched while the epic it depended on was still todo.
    # Epic directories MUST be E<NN>-<slug> with two digits. This is not
    # cosmetic: the gate registry matches `epics/E00*/epic.md` and
    # `epics/E0[1-9]*/tasks/*.md` while the DAG loader matches `epics/E*/`, so a
    # project naming epics E0/E1 loads and validates cleanly while BOTH the
    # genesis exit gate and the epic-breakdown gate silently never fire.
    # Verified before this check existed: DAG OK, zero gate errors, no warning.
    for ep in sorted(glob.glob(os.path.join(ROOT, "epics", "E*", "epic.md"))):
        name = os.path.basename(os.path.dirname(ep))
        if not re.match(r"^E\d{2}(-|$)", name):
            errs.append(
                f"epics/{name}/: epic directories must be named E<NN>-<slug> with "
                f"TWO digits (E00-genesis, E01-core). The human gates are matched "
                f"by that shape — '{name}' would load but silently lose its gates.")

    for eid, e in epics.items():
        for d in (e.get("depends_on") or []):
            if str(d) not in epics:
                errs.append(f"{eid}: depends_on unknown epic '{d}'")

    for tid, t in tasks.items():
        for d in deps(t):
            if d not in tasks and d not in epics:
                errs.append(f"{tid}: unknown dependency '{d}'")
        if str(t.get("status")) not in ORDER:
            errs.append(f"{tid}: unknown status '{t.get('status')}'")
        if t.get("status") == "todo" and not (t.get("traces_to") or t.get("type") == "genesis"):
            errs.append(f"{tid}: missing traces_to (rule 1 — spec is law)")
        # An unedited copy of epics/_templates/task.template.md used to validate
        # clean and dispatch: `id: E<NN>-T<MM>`, `traces_to: [FR-XXXX-000, ...]`.
        # Placeholders are not ids, and a task nobody filled in is not a task.
        placeholders = [str(v) for v in
                        [tid] + [str(x) for x in (t.get("traces_to") or [])]
                        if re.search(r"<[A-Za-z]+>|XXXX|0\.0\.0|E<NN>|T<MM>", str(v))]
        if placeholders:
            errs.append(f"{tid}: unfilled template placeholder(s) "
                        f"{placeholders} — this task file was copied from "
                        f"epics/_templates/ and never completed")
        # rule 2 — a frontend task without a design contract cannot be gated,
        # which means it cannot be trusted to match the design.
        if str(t.get("layer", "")) == "frontend" and t.get("type") != "genesis":
            dc = t.get("design_contract")
            if not dc:
                errs.append(f"{tid}: layer=frontend without design_contract "
                            f"(rule 2 — see skills/design-fidelity)")
            else:
                dc_path = os.path.join(ROOT, str(dc))
                if not os.path.exists(dc_path):
                    errs.append(f"{tid}: design_contract '{dc}' does not exist "
                                f"(run: make design-extract && make design-contract)")
                else:
                    # Rule 2 used to be satisfied by os.path.exists() alone, so a
                    # 0-byte file made "design is law" green. A contract has to
                    # contain the elements the gate compares against.
                    try:
                        body = open(dc_path, encoding="utf-8").read()
                    except OSError:
                        body = ""
                    if len(body.strip()) < 200 or "elements" not in body:
                        errs.append(
                            f"{tid}: design_contract '{dc}' is empty or not a "
                            f"generated contract ({len(body.strip())} bytes) — "
                            f"regenerate with make design-contract; an existing "
                            f"file is not a contract")
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


# Where the map's field list actually lives. Derived, never duplicated: an
# earlier version of this check hardcoded a copy of every section's field names,
# which is the "two copies, one source, no sync" pattern this repo warns about
# (docs/ARCHITECTURE.md). Read the schema instead — pyyaml is already a
# dependency, and jsonschema deliberately is not.
MAP_SCHEMA_CANDIDATES = (
    os.path.join("schemas", "knowledge-map.schema.yaml"),
    os.path.join("agent", "schemas", "knowledge-map.schema.yaml"),
)


def _map_allowed_keys():
    """{section: {allowed field names}} derived from the JSON Schema.

    Returns {} when no schema ships with the project, which disables the lint
    rather than inventing rules.
    """
    path = next((os.path.join(ROOT, c) for c in MAP_SCHEMA_CANDIDATES
                 if os.path.exists(os.path.join(ROOT, c))), None)
    if not path:
        return {}
    try:
        with open(path, encoding="utf-8") as fh:
            schema = yaml.safe_load(fh) or {}
    except (OSError, yaml.YAMLError):
        return {}

    defs = schema.get("$defs") or {}

    def props_of(node, seen=()):
        """Collect property names through $ref and allOf."""
        if not isinstance(node, dict):
            return set()
        out = set(node.get("properties") or {})
        ref = node.get("$ref")
        if ref:
            name = ref.rsplit("/", 1)[-1]
            if name not in seen:
                out |= props_of(defs.get(name, {}), seen + (name,))
        for sub in node.get("allOf") or []:
            out |= props_of(sub, seen)
        return out

    allowed = {}
    for section, node in (schema.get("properties") or {}).items():
        if not isinstance(node, dict):
            continue
        if node.get("type") == "array":
            keys = props_of(node.get("items") or {})
            if keys:
                allowed[section] = keys
        elif section == "requirements":
            for sub, subnode in (node.get("properties") or {}).items():
                keys = props_of((subnode or {}).get("items") or {})
                if keys:
                    allowed[f"requirements.{sub}"] = keys
    return allowed


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

    allowed_by_section = _map_allowed_keys()
    if not allowed_by_section:
        return []

    errs = []
    for section, allowed in sorted(allowed_by_section.items()):
        if "." in section:
            parent, child = section.split(".", 1)
            container = data.get(parent) or {}
            items = container.get(child) if isinstance(container, dict) else None
        else:
            items = data.get(section)
        if not isinstance(items, list):
            continue
        for i, node in enumerate(items):
            if not isinstance(node, dict):
                continue
            extra = set(node) - allowed
            if extra:
                errs.append(
                    f"spec/knowledge-map.yaml: {section}[{i}] has unexpected key(s) "
                    f"{sorted(extra)} — usually an unquoted comma in flow style; "
                    f"quote the value")
    return errs


def _gates():
    """The declared gate registry from harness.yaml.

    Returns (gates, errors). FAILS CLOSED, which it did not used to.

    The previous version returned [] on a missing file, unparseable YAML, or a
    renamed key, and said nothing. Renaming `human_gates:` to anything else made
    all twenty gates vanish while `--validate` still printed "DAG OK" and
    `--next` dispatched — verified. One indentation slip in a merge conflict, or
    a declined overwrite during `/harness-init`, disarmed the whole model
    silently. A harness with no gates is a defect, not a permissive default.
    """
    path = os.path.join(ROOT, "harness.yaml")
    if not os.path.exists(path):
        return [], ["harness.yaml is missing — no human gates can be enforced. "
                    "Restore it from the plugin's scaffold/."]
    try:
        with open(path, encoding="utf-8") as fh:
            cfg = yaml.safe_load(fh) or {}
    except (OSError, yaml.YAMLError) as e:
        return [], [f"harness.yaml is unreadable ({e}) — no human gates can be "
                    f"enforced until it parses."]
    if not isinstance(cfg, dict):
        return [], ["harness.yaml does not parse to a mapping — no human gates "
                    "can be enforced."]
    if "human_gates" not in cfg:
        return [], ["harness.yaml declares no `human_gates:` key — every gate is "
                    "unenforced. If the key was renamed, rename it back; the "
                    "scheduler reads that exact name."]
    raw = cfg.get("human_gates")
    if not isinstance(raw, list) or not raw:
        return [], ["harness.yaml `human_gates:` is empty or not a list — every "
                    "gate is unenforced."]
    gates = [g for g in raw if isinstance(g, dict) and g.get("key")]
    errs = []
    if not gates:
        errs.append("harness.yaml `human_gates:` has no keyed entries — this "
                    "scheduler needs the structured form "
                    "`- { key: ..., kind: ..., owner: ... }`.")
    skipped = len(raw) - len(gates)
    if skipped and gates:
        errs.append(f"harness.yaml: {skipped} `human_gates` entr(y|ies) have no "
                    f"`key:` and are being ignored — fix or remove them rather "
                    f"than leaving a gate that looks declared but is not.")
    return gates, errs


def _gate_cleared(text, key):
    """True only for a canonical, cleared gate declaration naming `key`.

    The shape, and nothing else counts:

        **Gate:** \U0001f9cd `<key>` \u2014 \u2705 cleared by <name> on <YYYY-MM-DD>
        # Gate: \U0001f9cd <key> - \u2705 cleared by <name> on <YYYY-MM-DD>

    Anchored at the start of the line after optional decoration (`-`, `*`, `>`,
    `#`, `<!--`, bold markers, YAML comment), because an adversarial pass showed
    that scanning for a loose pattern anywhere on any line let all of these clear
    a gate: a log line appended at the bottom while the visible header still read
    AWAITING; "Delegated <key>" (the substring "gate"); a comment demonstrating
    what not to write; a negation; and a table row.

    It still cannot prove a human approved anything — the agent writes the file.
    What it enforces is that clearing a gate means editing the one declaration
    line, so a false clearance is a deliberate, dated, attributable edit rather
    than a plausible-looking sentence added somewhere else in the document.
    """
    decoration = r"(?:[-*>#]|<!--|\*\*|\s)*"
    label = r"(?:\*\*)?Gate:?(?:\*\*)?:?"
    # A clearing VERB, not merely the word "by": "required by policy, see <date>"
    # otherwise reads as an approval.
    verb = r"(?:cleared|approved|confirmed|signed|accepted)\s+by"
    verdicts = []
    for raw in text.splitlines():
        line = raw.strip()
        m = re.match(rf"^{decoration}{label}\s*", line, re.IGNORECASE)
        if not m:
            continue
        rest = line[m.end():]
        # the key must come next, allowing a person marker and backticks
        m2 = re.match(r"^(?:\U0001f9cd\s*)?`?" + re.escape(key) + r"`?\s*", rest)
        if not m2:
            continue
        verdicts.append(rest[m2.end():].lstrip(" -\u2014:"))

    # Order-independent: if ANY declaration of this key is still awaiting, the
    # gate is open, whatever a later line claims. Otherwise a log line appended
    # above the header would win by being scanned first.
    if any("\u23f3" in v for v in verdicts):
        return False
    for verdict in verdicts:
        if not verdict.startswith("\u2705"):          # must OPEN with the tick
            continue
        if re.search(r"\bnot\b|\bnever\b", verdict, re.IGNORECASE):
            continue
        if re.search(verb + r"\s+\S+.*?\b\d{4}-\d{2}-\d{2}\b", verdict, re.IGNORECASE):
            return True
    return False


def _gate_rejected(text, key):
    """True when the gate line records an explicit, dated human REJECTION.

    Same canonical shape as a clearance, with ❌ instead of ✅. A rejection is a
    decided outcome: the change does not proceed, and the project keeps working.
    Treating it as "not yet approved" wedged every dispatch permanently, which
    punished the human for using an outcome the impact-report template itself
    offers.
    """
    cross = "\u274c"
    decoration = r"(?:[-*>#]|<!--|\*\*|\s)*"
    label = r"(?:\*\*)?Gate:?(?:\*\*)?:?"
    verb = r"(?:rejected|declined|refused)\s+by"
    for raw in text.splitlines():
        line = raw.strip()
        m = re.match(rf"^{decoration}{label}\s*", line, re.IGNORECASE)
        if not m:
            continue
        rest = line[m.end():]
        m2 = re.match(r"^(?:\U0001f9cd\s*)?`?" + re.escape(key) + r"`?\s*", rest)
        if not m2:
            continue
        verdict = rest[m2.end():].lstrip(" -\u2014:")
        if not verdict.startswith(cross):
            continue
        if re.search(verb + r"\s+\S+.*?\b\d{4}-\d{2}-\d{2}\b", verdict, re.IGNORECASE):
            return True
    return False


def _exists(pattern):
    """True if a literal path or a glob matches anything under ROOT."""
    full = os.path.join(ROOT, pattern)
    if any(c in pattern for c in "*?["):
        return bool(glob.glob(full))
    return os.path.exists(full)


def validate_gates():
    """Human gates, enforced instead of merely documented.

    `human_gates` used to be a flat list that no code read: pure documentation,
    so the model was entirely trust-based and the list could drift from the
    skills without anything noticing.

    Three rules per artifact gate, in this order:

      1. A gate line that is PRESENT and not cleared is an error. The owning
         skill writes that line when it produces the document, so its presence
         means the approval is genuinely outstanding.
      2. A gate line that is ABSENT is not an error by itself. Several documents
         ship as empty placeholders (`design/gaps.md`, `epics/README.md`), and an
         earlier version demanded a cleared gate on them — which made a FRESH
         INSTALL fail `validate` while `harness-init` says it must be green. The
         only way to comply was to forge approvals for gates nobody had opened,
         so the system's first lesson was how to forge one. Absent means "not
         reached yet".
      3. Unless `precondition_for:` says otherwise: if that downstream path
         exists the stage demonstrably ran, so the document must exist AND carry
         a cleared line. This is what stops "skip the gate by never writing the
         paperwork" — rule 2 without rule 3 would be an open door.
    """
    errs = []
    gates, registry_errs = _gates()
    errs.extend(registry_errs)
    for g in gates:
        key, kind = g["key"], g.get("kind", "artifact")
        if kind != "artifact":
            continue                      # work/process gates have no document

        only_if = g.get("only_if")
        if only_if and not _exists(only_if):
            continue                      # conditional gate, not applicable here

        paths = []
        if g.get("artifact"):
            paths = [os.path.join(ROOT, g["artifact"])]
        elif g.get("artifact_glob"):
            paths = sorted(glob.glob(os.path.join(ROOT, g["artifact_glob"])))

        downstream = g.get("precondition_for")
        stage_passed = bool(downstream) and _exists(downstream)
        existing = [p for p in paths if os.path.exists(p)]

        if stage_passed and not existing:
            errs.append(
                f"🧍 {key}: {downstream} exists, so this stage ran — but its gate "
                f"document {g.get('artifact') or g.get('artifact_glob')} is missing. "
                f"A gate is not cleared by deleting the paperwork.")
            continue

        for path in existing:
            try:
                with open(path, encoding="utf-8") as fh:
                    text = fh.read()
            except OSError:
                continue
            rel = os.path.relpath(path, ROOT)
            declared = key in text
            if not declared:
                if stage_passed:
                    errs.append(
                        f"{rel}: this stage ran ({downstream} exists) but the file "
                        f"carries no 🧍 {key} gate line. The owning skill must write "
                        f"it — see harness.yaml for who owns this gate.")
                continue                  # otherwise: stage not reached, fine
            if _gate_rejected(text, key):
                # A recorded "no" is a DECISION, not an absence. It used to read
                # as "not cleared" and block every dispatch in the project
                # forever, telling the human to replace an ⏳ that was not there
                # — so the only escapes were forging a ✅ or deleting their own
                # decision. The change simply does not proceed; work continues.
                continue
            if not _gate_cleared(text, key):
                errs.append(f"🧍 {key} NOT cleared in {rel} — a human must approve "
                            f"it: set the gate line to "
                            f"'✅ cleared by <name> on <YYYY-MM-DD>' "
                            f"(or '❌ rejected by <name> on <YYYY-MM-DD>' to "
                            f"decline it)")
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
    gate_errs = validate_gates()
    errs += gate_errs

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
        if gate_errs:
            print("harness: ✋ a human gate is open — dispatch blocked:", file=sys.stderr)
            for e in gate_errs:
                print(f"  {e}", file=sys.stderr)
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
