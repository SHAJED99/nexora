#!/usr/bin/env python3
"""Live harness dashboard — the terminal state, in a browser, auto-refreshing.

    python agent/orchestrator/dashboard.py            # serve on 127.0.0.1:8787
    python agent/orchestrator/dashboard.py --port 9000 --open
    python agent/orchestrator/dashboard.py --json     # one snapshot to stdout
    python agent/orchestrator/dashboard.py --html out.html   # static snapshot

Why this exists: `make status`, `make next`, `make review` and `make validate`
each answer one question, and a human watching a multi-agent run wants all four
at once, updating, without typing. This adds NO new state — every number is
re-derived from the same files the scheduler reads, on every request. If the
dashboard and `make status` disagree, that is a bug in here, not two truths.

It is deliberately read-only and deliberately localhost-only. There is no
button that clears a gate: a gate is cleared by editing the gate line in the
owning document, with a name and a date, and putting a one-click "Approve" in a
web page would demolish exactly the property rule 3 exists to protect.

Stdlib only (plus pyyaml, already required by the scheduler) so it runs in a
fresh project before any stack is chosen.
"""
import argparse
import errno
import glob
import html
import json
import os
import re
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):  # pragma: no cover
        pass

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    import scheduler as S
except ImportError as e:  # pragma: no cover
    sys.exit(f"harness: dashboard needs agent/orchestrator/scheduler.py ({e})")

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("harness: pip install pyyaml (see requirements.txt)")

ROOT = S.ROOT


def _read(rel):
    try:
        with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return None


# ── the pieces ────────────────────────────────────────────────────────────────

def project_info():
    """Name + lifecycle stage, from the knowledge map when it exists."""
    out = {"name": os.path.basename(ROOT), "stage": None, "modes": []}
    text = _read(os.path.join("spec", "knowledge-map.yaml"))
    if not text:
        return out
    try:
        m = yaml.safe_load(text) or {}
    except yaml.YAMLError:
        return out
    p = (m.get("project") or {}) if isinstance(m, dict) else {}
    if isinstance(p, dict):
        if p.get("name") and not str(p["name"]).startswith("<"):
            out["name"] = str(p["name"])
        if p.get("lifecycle_stage"):
            out["stage"] = str(p["lifecycle_stage"])
        if isinstance(p.get("modes"), list):
            out["modes"] = [str(x) for x in p["modes"]]
    return out


def gate_rows():
    """Every declared gate with its real state — the scheduler's own predicates.

    States: cleared · rejected · awaiting (line present, not cleared) ·
    not-reached (no document, and nothing downstream proves the stage ran) ·
    missing-paperwork (downstream exists but the document does not) ·
    n/a (only_if not satisfied).
    """
    gates, registry_errs = S._gates()
    rows = []
    for g in gates:
        key = g["key"]
        row = {"key": key, "kind": g.get("kind", "artifact"),
               "owner": g.get("owner"), "state": "not-reached",
               "artifact": g.get("artifact") or g.get("artifact_glob"),
               "detail": ""}
        if row["kind"] != "artifact":
            # work/process gates have no document to read; they are enforced by
            # the skill that owns them, so the dashboard reports them as such
            # rather than inventing a status for them.
            row["state"] = "process"
            rows.append(row)
            continue

        only_if = g.get("only_if")
        if only_if and not S._exists(only_if):
            row["state"] = "n/a"
            row["detail"] = f"only_if {only_if} not present"
            rows.append(row)
            continue

        if g.get("artifact"):
            paths = [os.path.join(ROOT, g["artifact"])]
        else:
            paths = sorted(glob.glob(os.path.join(ROOT, g.get("artifact_glob") or "")))
        existing = [p for p in paths if os.path.exists(p)]
        downstream = g.get("precondition_for")
        stage_passed = bool(downstream) and S._exists(downstream)

        if stage_passed and not existing:
            row["state"] = "missing-paperwork"
            row["detail"] = f"{downstream} exists but the gate document does not"
            rows.append(row)
            continue

        states, files = [], []
        for p in existing:
            try:
                with open(p, encoding="utf-8") as fh:
                    text = fh.read()
            except OSError:
                continue
            rel = os.path.relpath(p, ROOT).replace("\\", "/")
            if key not in text:
                states.append("missing-line" if stage_passed else "not-reached")
            elif S._gate_rejected(text, key):
                states.append("rejected")
            elif S._gate_cleared(text, key):
                states.append("cleared")
            else:
                states.append("awaiting")
            files.append(rel)
        # Worst state wins: one uncleared instance of a globbed gate is an open
        # gate, however many siblings are green.
        for worst in ("missing-line", "awaiting", "not-reached", "rejected", "cleared"):
            if worst in states:
                row["state"] = worst
                break
        row["detail"] = ", ".join(files[:4]) + (" …" if len(files) > 4 else "")
        rows.append(row)
    return rows, registry_errs


def board(epics, tasks):
    rows = []
    totals = {}
    for eid, e in sorted(epics.items()):
        mine = [t for t in tasks.values() if t["_epic"] == eid]
        counts = {}
        for t in mine:
            s = str(t.get("status"))
            counts[s] = counts.get(s, 0) + 1
            totals[s] = totals.get(s, 0) + 1
        done = counts.get("done", 0) + counts.get("verified", 0)
        rows.append({"id": eid, "title": str(e.get("title") or ""),
                     "status": str(e.get("status") or ""),
                     "done": done, "total": len(mine), "counts": counts})
    return rows, totals


def questions():
    """Per-question state from spec/questions.md, parsed as BLOCKS.

    The register's canonical shape is a `### Q-<AREA>-nnn` heading followed by
    `- **Priority:**` / `- **Status:**` lines (sometimes on one line together),
    grouped under `## Open questions (🟡)` / `## Answered (🟢)` sections.

    An earlier version of this scanned single LINES for an id plus an emoji.
    On a real register that puts the id in a heading and the status two lines
    below, it matched nothing and reported **0 blocking** — the most dangerous
    possible wrong answer, since "no blockers" is the green light for genesis.
    So: read the block, fall back to the enclosing section heading, and when a
    question's state cannot be determined, COUNT IT AS UNKNOWN and say so. A
    number the parser could not derive is never quietly folded into a benign
    bucket.

    The hand-maintained summary table at the top of the register is ignored on
    purpose: it is the part most likely to be stale, and the rows are the truth.
    """
    text = _read(os.path.join("spec", "questions.md"))
    if text is None:
        return None
    OPEN, ANSWERED, CLOSED = "🟡", "🟢", "⚪"
    out = {"blocking": 0, "important": 0, "optional": 0,
           "answered": 0, "closed": 0, "unknown": 0, "total": 0,
           "open_ids": []}

    # Split into (section_heading, question_id, block_text) triples.
    lines = text.splitlines()
    section, blocks, cur = "", [], None
    for line in lines:
        if re.match(r"^##\s", line) and not re.match(r"^###", line):
            section = line
            if cur:
                blocks.append(cur); cur = None
            continue
        m = re.match(r"^#{3,}\s.*?(Q-[A-Z][A-Z0-9]*-\d+)", line)
        if m:
            if cur:
                blocks.append(cur)
            cur = {"section": section, "id": m.group(1), "text": line}
            continue
        if cur:
            cur["text"] += "\n" + line
    if cur:
        blocks.append(cur)

    # Fallback for registers written as table rows: one row, one question.
    if not blocks:
        for line in lines:
            m = re.match(r"^\s*\|", line)
            q = re.search(r"\bQ-[A-Z][A-Z0-9]*-\d+", line)
            if m and q:
                blocks.append({"section": "", "id": q.group(0), "text": line,
                               "row": True})

    for b in blocks:
        out["total"] += 1
        body, sec = b["text"], b["section"]
        # State: the block wins; the enclosing section heading is the fallback.
        if OPEN in body:
            state = "open"
        elif ANSWERED in body:
            state = "answered"
        elif CLOSED in body:
            state = "closed"
        elif OPEN in sec:
            state = "open"
        elif ANSWERED in sec:
            state = "answered"
        elif CLOSED in sec:
            state = "closed"
        else:
            state = None

        if state == "answered":
            out["answered"] += 1
        elif state == "closed":
            out["closed"] += 1
        elif state == "open":
            m = re.search(r"Priority:?\*{0,2}:?\s*\**\s*"
                          r"(blocking|important|optional)", body, re.IGNORECASE)
            if not m and b.get("row"):
                # A table row carries no "Priority:" label — the word IS the
                # cell. Only for rows: a bare-word search over a heading block
                # would read "this is important" out of the prose.
                m = re.search(r"\b(blocking|important|optional)\b", body,
                              re.IGNORECASE)
            if m:
                pri = m.group(1).lower()
                out[pri] += 1
                if pri in ("blocking", "important"):
                    out["open_ids"].append(f"{b['id']} ({pri})")
            else:
                # Do NOT default to optional. An open question of unreadable
                # priority silently filed as optional under-reports blockers,
                # which is the same failure as reporting zero: it reads as
                # permission to proceed. Unknown is surfaced loudly instead.
                out["unknown"] += 1
                out["open_ids"].append(f"{b['id']} (priority unreadable)")
        else:
            out["unknown"] += 1
    return out

def impacts():
    out = []
    for p in sorted(glob.glob(os.path.join(ROOT, "docs", "impact", "IMP-*.md"))):
        try:
            with open(p, encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        key = "change_impact_approval"
        state = ("cleared" if S._gate_cleared(text, key)
                 else "rejected" if S._gate_rejected(text, key)
                 else "awaiting" if key in text else "no-gate-line")
        out.append({"id": os.path.basename(p)[:-3], "state": state})
    return out


def state():
    """The whole snapshot. Every section is guarded: one unreadable file
    degrades its own panel instead of blanking the page."""
    snap = {"root": ROOT.replace("\\", "/"), "errors": [], "sections": {}}

    def sect(name, fn):
        try:
            snap["sections"][name] = fn()
        except Exception as e:                       # pragma: no cover
            snap["sections"][name] = None
            snap["errors"].append(f"{name}: {type(e).__name__}: {e}")

    sect("project", project_info)
    try:
        epics, tasks = S.load()
    except Exception as e:                           # pragma: no cover
        epics, tasks = {}, {}
        snap["errors"].append(f"load: {type(e).__name__}: {e}")

    def _board():
        rows, totals = board(epics, tasks)
        return {"epics": rows, "totals": totals, "order": S.ORDER}
    sect("board", _board)

    def _queue():
        try:
            errs, children = S.validate(epics, tasks)
        except Exception:
            children = {}
            errs = []
        ready, in_flight = S.ready(epics, tasks, children)
        return {
            "ready": [{"id": t, "title": str(tasks[t].get("title") or ""),
                       "layer": str(tasks[t].get("layer") or ""),
                       "epic": tasks[t]["_epic"],
                       "path": tasks[t]["_path"].replace("\\", "/")}
                      for t in ready[:25]],
            "ready_total": len(ready),
            "in_flight": [{"id": t["id"], "status": str(t.get("status")),
                           "executed_by": str(t.get("executed_by") or "?"),
                           "path": t["_path"].replace("\\", "/")}
                          for t in sorted(tasks.values(), key=lambda x: x["id"])
                          if t.get("status") in S.IN_FLIGHT],
            "review": [{"id": t["id"], "status": str(t.get("status")),
                        "executed_by": str(t.get("executed_by") or "?"),
                        "reviewed_by": str(t.get("reviewed_by") or ""),
                        "path": t["_path"].replace("\\", "/")}
                       for t in sorted(tasks.values(), key=lambda x: x["id"])
                       if t.get("status") in ("review-requested", "changes-requested")],
            "stuck": [{"id": t["id"], "status": str(t.get("status")),
                       "path": t["_path"].replace("\\", "/")}
                      for t in sorted(tasks.values(), key=lambda x: x["id"])
                      if t.get("status") in ("blocked", "frozen")],
        }
    sect("queue", _queue)

    def _gates():
        rows, reg = gate_rows()
        return {"gates": rows, "registry_errors": reg}
    sect("gates", _gates)

    sect("questions", questions)
    sect("impacts", impacts)

    def _validate():
        errs, _children = S.validate(epics, tasks)
        errs = list(errs)
        errs += S.validate_knowledge_map()
        errs += S.validate_gates()
        return {"errors": errs, "ok": not errs}
    sect("validate", _validate)
    return snap


# ── the page ──────────────────────────────────────────────────────────────────
# One file, no CDN, no build step. It fetches /api/state and re-renders; the
# server does the reading, the page does the layout.

PAGE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>__TITLE__</title>
<style>
:root{--bg:#fbfbfa;--fg:#1c1b19;--dim:#6b6862;--line:#e3e0da;--card:#fff;
--ok:#1a7f4b;--warn:#a2650a;--bad:#b3261e;--busy:#2456c4;--chip:#f0eee9}
@media (prefers-color-scheme:dark){:root{--bg:#16151a;--fg:#eceae4;--dim:#9a968d;
--line:#2e2c33;--card:#1e1d23;--ok:#5fd39b;--warn:#e0ac4c;--bad:#f0857c;
--busy:#7ea6ff;--chip:#2a2830}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
font:14px/1.5 ui-sans-serif,-apple-system,Segoe UI,Roboto,sans-serif}
header{position:sticky;top:0;background:var(--bg);border-bottom:1px solid var(--line);
padding:14px 20px;display:flex;gap:16px;align-items:baseline;flex-wrap:wrap;z-index:9}
h1{font-size:17px;margin:0;font-weight:650}
.meta{color:var(--dim);font-size:12px}
main{padding:20px;max-width:1180px;margin:0 auto;
display:grid;gap:16px;grid-template-columns:repeat(auto-fit,minmax(330px,1fr))}
section{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
section.wide{grid-column:1/-1}
h2{font-size:12px;text-transform:uppercase;letter-spacing:.07em;color:var(--dim);
margin:0 0 10px;font-weight:600}
table{width:100%;border-collapse:collapse;font-size:13px}
td,th{text-align:left;padding:4px 8px 4px 0;border-bottom:1px solid var(--line);
vertical-align:top}
th{color:var(--dim);font-weight:600;font-size:11px;text-transform:uppercase}
tr:last-child td{border-bottom:0}
code,.mono{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:12px}
.chip{display:inline-block;padding:1px 7px;border-radius:99px;background:var(--chip);
font-size:11px;margin:1px 3px 1px 0;white-space:nowrap}
.ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--bad)}.busy{color:var(--busy)}
.dim{color:var(--dim)}
.dot{display:inline-block;width:8px;height:8px;border-radius:99px;margin-right:6px;
background:currentColor;vertical-align:1px}
.bar{height:6px;background:var(--chip);border-radius:99px;overflow:hidden;min-width:60px}
.bar>i{display:block;height:100%;background:var(--ok)}
.big{font-size:26px;font-weight:600;line-height:1.1}
ul{margin:0;padding-left:18px}li{margin:3px 0}
.empty{color:var(--dim);font-style:italic}
details{margin-top:10px}
summary{cursor:pointer;font-size:12px;padding:2px 0}
summary::marker{color:var(--dim)}
#err{grid-column:1/-1;border-color:var(--bad)}
.scroll{overflow-x:auto}
</style></head><body>
<header>
  <h1 id="pname">harness</h1>
  <span class="meta" id="pstage"></span>
  <span class="meta" id="pval"></span>
  <span class="meta" style="margin-left:auto" id="stamp">loading…</span>
</header>
<main id="app"></main>
<script>
const E=(t,a={},k=[])=>{const n=document.createElement(t);
 for(const[x,v]of Object.entries(a)){if(x=='html')n.innerHTML=v;else if(x=='cls')n.className=v;else n.setAttribute(x,v)}
 for(const c of [].concat(k))if(c!=null)n.append(c);return n};
const card=(title,body,wide)=>E('section',{cls:wide?'wide':''},[E('h2',{},title),body]);
const empty=t=>E('div',{cls:'empty'},t);
const GS={cleared:'ok','process':'dim','n/a':'dim','not-reached':'dim',
 awaiting:'warn',rejected:'dim','missing-line':'bad','missing-paperwork':'bad'};

function tbl(head,rows){
 const t=E('table');
 if(head)t.append(E('tr',{},head.map(h=>E('th',{},h))));
 for(const r of rows)t.append(E('tr',{},r.map(c=>E('td',{},c))));
 return E('div',{cls:'scroll'},t);
}

function render(s){
 const p=s.sections.project||{};
 document.getElementById('pname').textContent=p.name||'harness';
 document.getElementById('pstage').textContent=
   (p.stage?'stage: '+p.stage:'stage: unknown')+(p.modes&&p.modes.length?'  ·  modes '+p.modes.join(''):'');
 const v=s.sections.validate;
 const pv=document.getElementById('pval');
 if(v){pv.className='meta '+(v.ok?'ok':'bad');
   pv.textContent=v.ok?'✓ validate clean':'✗ '+v.errors.length+' validate error(s)';}
 document.getElementById('stamp').textContent='updated '+new Date().toLocaleTimeString();

 const app=document.getElementById('app');app.textContent='';

 if(s.errors&&s.errors.length)app.append(E('section',{id:'err'},[
   E('h2',{},'dashboard could not read'),E('ul',{},s.errors.map(e=>E('li',{cls:'bad'},e)))]));

 // gates
 const g=s.sections.gates;
 if(g){
  // Order by what the human has to DO. The first version listed the registry
  // in declaration order, so twelve inert `process` rows pushed the one gate
  // that actually wanted a human to row 3 of 20 — a status board whose top
  // half is never actionable trains you to stop reading it.
  const NEED=['missing-paperwork','missing-line','awaiting'];
  const RANK={'missing-paperwork':0,'missing-line':1,awaiting:2,cleared:3,rejected:4};
  const need=g.gates.filter(x=>NEED.includes(x.state));
  const rest=g.gates.filter(x=>['cleared','rejected'].includes(x.state));
  const inert=g.gates.filter(x=>!NEED.includes(x.state)&&!['cleared','rejected'].includes(x.state));
  const srt=a=>a.sort((p,q)=>(RANK[p.state]-RANK[q.state])||p.key.localeCompare(q.key));
  const row=x=>[E('span',{cls:GS[x.state]||''},[E('i',{cls:'dot'}),x.state]),
                E('span',{cls:'mono'},x.key),
                E('span',{cls:'dim'},x.detail||x.owner||'')];
  app.append(card(need.length?'human gates — '+need.length+' waiting on you'
                             :'human gates — none waiting on you',
   E('div',{},[
    ...(g.registry_errors||[]).map(e=>E('div',{cls:'bad'},e)),
    need.length?tbl(null,srt(need).map(row)):empty('nothing blocked on a human'),
    rest.length?E('details',{},[E('summary',{cls:'dim'},
        rest.length+' cleared / decided'),tbl(null,srt(rest).map(row))]):null,
    // Process gates have no document to read — they are enforced by the skill
    // that owns them. Chips, not twelve table rows pretending to have state.
    inert.length?E('div',{style:'margin-top:10px'},[
      E('span',{cls:'dim'},'not applicable yet: '),
      ...inert.map(x=>E('span',{cls:'chip',title:x.state+' · '+(x.owner||'')},x.key))
    ]):null]),true));}

 // board
 const b=s.sections.board;
 if(b){app.append(card('epics',tbl(['epic','title','progress',''],
   b.epics.map(e=>{const pct=e.total?Math.round(100*e.done/e.total):0;
    return [E('span',{cls:'mono'},e.id),e.title||E('span',{cls:'dim'},'—'),
     E('div',{},[E('div',{cls:'bar'},E('i',{style:'width:'+pct+'%'})),
       E('span',{cls:'dim mono'},e.done+'/'+e.total)]),
     E('div',{},Object.entries(e.counts).map(([k,n])=>E('span',{cls:'chip'},k+' '+n)))]}))
   ,true));}

 // queue
 const q=s.sections.queue;
 if(q){
  app.append(card('in flight ('+q.in_flight.length+')',q.in_flight.length?
    tbl(null,q.in_flight.map(t=>[E('span',{cls:'mono busy'},t.id),t.status,
      E('span',{cls:'dim'},t.executed_by)])):empty('nothing running')));
  app.append(card('review queue ('+q.review.length+')',q.review.length?
    tbl(null,q.review.map(t=>[E('span',{cls:'mono warn'},t.id),t.status,
      E('span',{cls:'dim'},'by '+t.executed_by)])):empty('nothing waiting on review')));
  app.append(card('ready to dispatch ('+q.ready_total+')',q.ready.length?
    tbl(null,q.ready.map(t=>[E('span',{cls:'mono'},t.id),t.title||'',
      E('span',{cls:'chip'},t.layer||'—')])):empty('nothing dispatchable — check gates and deps')));
  if(q.stuck.length)app.append(card('blocked / frozen ('+q.stuck.length+')',
    tbl(null,q.stuck.map(t=>[E('span',{cls:'mono bad'},t.id),t.status]))));
 }

 // questions
 const qs=s.sections.questions;
 if(qs){app.append(card('open questions',E('div',{},[
   E('div',{cls:'big '+(qs.blocking?'bad':'ok')},String(qs.blocking)),
   E('div',{cls:'dim'},'blocking — these stop work'),
   E('div',{style:'margin-top:8px'},[
     E('span',{cls:'chip'},'important '+qs.important),
     E('span',{cls:'chip'},'optional '+qs.optional),
     E('span',{cls:'chip'},'answered '+qs.answered),
     E('span',{cls:'chip'},'closed '+qs.closed),
     E('span',{cls:'chip'},'total '+qs.total)]),
   // A question the parser could not classify is shown, never absorbed: a
   // silent 0 blocking is the one wrong answer that reads as permission.
   qs.unknown?E('div',{cls:'bad',style:'margin-top:8px'},
     qs.unknown+' question(s) with no readable status — check spec/questions.md '
     +'formatting; treat as open until confirmed'):null,
   qs.open_ids&&qs.open_ids.length?E('div',{cls:'dim mono',style:'margin-top:8px'},
     qs.open_ids.join(' · ')):null])));}
 else if(qs===null)app.append(card('open questions',
   empty('no spec/questions.md yet — intake has not run')));

 // impacts
 const im=s.sections.impacts;
 if(im&&im.length)app.append(card('impact reports',tbl(null,
   im.map(i=>[E('span',{cls:'mono'},i.id),
     E('span',{cls:GS[i.state]||''},i.state)]))));

 // validate errors
 if(v&&!v.ok)app.append(card('validate errors',
   E('ul',{},v.errors.map(e=>E('li',{cls:'mono bad'},e))),true));
}

let stop=false;
async function tick(){
 if(stop)return;
 try{const r=await fetch('api/state',{cache:'no-store'});render(await r.json());}
 catch(e){document.getElementById('stamp').textContent='server gone — '+e;stop=true;}
}
tick();setInterval(tick,__EVERY__);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)tick()});
</script></body></html>
"""


def page(title, every_ms):
    return (PAGE.replace("__TITLE__", html.escape(title))
                .replace("__EVERY__", str(int(every_ms))))


def static_html(title):
    """A self-contained snapshot: no server, the state baked in.

    This is what you publish or email. It does not update — that is the point
    of a snapshot, and it says so in the page.
    """
    snap = state()
    body = page(title, 10 ** 9)
    inject = (
        "<script>window.__SNAP__=" + json.dumps(snap) + ";</script>\n"
        "<script>document.addEventListener('DOMContentLoaded',()=>{"
        "render(window.__SNAP__);"
        "document.getElementById('stamp').textContent='static snapshot';});"
        "</script>\n")
    # The live fetch loop must not run in a snapshot: there is no server.
    body = body.replace("tick();setInterval(tick,1000000000);", "stop=true;")
    return body.replace("</body>", inject + "</body>")


class Handler(BaseHTTPRequestHandler):
    server_version = "harness-dashboard"
    title = "harness"
    every = 3000

    def _send(self, code, ctype, payload):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/") or "/"
        if path in ("/", "/index.html"):
            self._send(200, "text/html; charset=utf-8",
                       page(self.title, self.every).encode("utf-8"))
        elif path in ("/api/state", "/state.json"):
            try:
                payload = json.dumps(state(), default=str).encode("utf-8")
            except Exception as e:                   # pragma: no cover
                payload = json.dumps({"errors": [f"{type(e).__name__}: {e}"],
                                      "sections": {}}).encode("utf-8")
            self._send(200, "application/json; charset=utf-8", payload)
        else:
            self._send(404, "text/plain; charset=utf-8", b"not found\n")

    def log_message(self, fmt, *a):                  # quiet; this runs alongside work
        pass


class Server(ThreadingHTTPServer):
    """ThreadingHTTPServer, minus the Windows double-bind.

    http.server sets allow_reuse_address = 1, which means two different things.
    On Linux it lets a restart reclaim a port stuck in TIME_WAIT — useful. On
    Windows SO_REUSEADDR also lets a *second* socket bind a port that is still
    being listened on: running this twice on one port silently produced two
    servers, with the OS splitting requests between them. Two boards, one URL,
    disagreeing about the state of your project, and no error either time.
    """

    daemon_threads = True
    allow_reuse_address = os.name != "nt"


def port_arg(raw):
    """A port, or a message a human can act on — not a traceback at bind time."""
    try:
        n = int(raw)
    except ValueError:
        raise argparse.ArgumentTypeError(f"{raw!r} is not a number")
    if not (0 <= n <= 65535):
        raise argparse.ArgumentTypeError(
            f"{n} is not a port — must be 1-65535 (or 0 to pick a free one)")
    return n


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", type=port_arg, default=8787,
                    help="1-65535, or 0 to let the OS pick a free one")
    ap.add_argument("--host", default="127.0.0.1",
                    help="default 127.0.0.1 — this page exposes your whole "
                         "project state, so binding it wider is a decision, "
                         "not a default")
    ap.add_argument("--every", type=int, default=3000, help="refresh ms")
    ap.add_argument("--open", action="store_true", help="open a browser")
    ap.add_argument("--json", action="store_true", help="one snapshot to stdout")
    ap.add_argument("--html", metavar="PATH", help="write a static snapshot")
    a = ap.parse_args()

    if a.json:
        print(json.dumps(state(), indent=2, default=str))
        return 0

    info = project_info()
    if a.html:
        with open(a.html, "w", encoding="utf-8") as fh:
            fh.write(static_html(info["name"]))
        print(f"harness: wrote {a.html}")
        return 0

    Handler.title = info["name"]
    Handler.every = a.every
    try:
        srv = Server((a.host, a.port), Handler)
    except OSError as exc:
        if exc.errno in (errno.EADDRINUSE, getattr(errno, "WSAEADDRINUSE", None)):
            print(f"harness: port {a.port} is already in use on {a.host}.",
                  file=sys.stderr)
            print("harness: another dashboard may already be running there — "
                  "open it, or pick another port.", file=sys.stderr)
        elif exc.errno in (errno.EACCES, getattr(errno, "WSAEACCES", None)):
            print(f"harness: not allowed to bind port {a.port} "
                  f"(ports under 1024 usually need root).", file=sys.stderr)
        else:
            print(f"harness: cannot bind {a.host}:{a.port} — {exc}",
                  file=sys.stderr)
        return 2
    # Ask the socket, do not assume: with --port 0 the OS chose, and printing
    # the requested port would hand out a URL that goes nowhere.
    bound = srv.server_address[1]
    url = f"http://{a.host}:{bound}/"
    print(f"harness: dashboard on {url}  (root {ROOT})")
    print("harness: read-only — gates are cleared by editing the document, not here")
    print("harness: Ctrl-C to stop")
    if a.open:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nharness: dashboard stopped")
    finally:
        srv.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
