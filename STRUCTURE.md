# Structure

The harness only. **You supply** `docs/business/` (BRD, SRS, feature list) and
`docs/UI/` (the design). Everything else the product needs — `spec/`,
`docs/domain/`, `apps/`, `packages/`, the feature epics — is produced by **Epic
00 (genesis)** and the epics after it. They don't exist yet; that's the intended
starting state.

```
docs/business/*.docx ──[genesis T00]──▶ spec/          ← canonical, greppable, law
docs/UI/             ──[genesis T03]──▶ design/golden/ ← measured, committed, law
                                        design/screens/ ← what agents build against
```

Raw inputs are read-only history. `spec/` and `design/golden/` are the law
agents actually execute against, because rule 1 needs a **greppable id** and
rule 2 needs a **measurable golden** — a `.docx` and a mockup are neither.

```
<your-project>/
├── AGENTS.md              ← the constitution: 10 always-on rules, every CLI reads it
├── CLAUDE.md              ← thin Claude Code adapter (imports AGENTS.md)
├── README.md · STRUCTURE.md · LICENSE
├── Makefile               ← next · status · review · validate · design-* · lessons · metrics · hooks
├── harness.yaml           ← topology: platforms, model tiers, review routing, budgets, WIP, human gates
├── .mcp.json              ← MCP servers (project scope): github · figma · playwright · database(ro) · context7 · atlassian · slack
├── package.json           ← design-gate tooling deps (playwright, pixelmatch, pngjs, yaml)
├── requirements.txt       ← pyyaml (orchestrator scripts)
│
├── design/               ★ THE DESIGN GATE — rule 2
│   ├── README.md          ← how it works, and why eyeballing can't
│   ├── sources.yaml       ← where designs come from; screen → route bindings
│   ├── thresholds.yaml    ← what "matches" means, numerically (loosening = 🧍 gate)
│   ├── golden/            ← extracted truth: probe.json + page.png  ← COMMITTED, it's the law
│   ├── screens/<id>.md    ← the ~150-line contract agents build against
│   ├── gaps.md            ← journeys the design omits, derived from the spec, 🧍 approved
│   ├── reports/           ← last verify run (gitignored)
│   └── tools/            ★ the gate itself — generic machinery, no project knowledge
│                            extract · contract · verify · figma-import · selftest
│                            + lib/{probe,compare,browser,pixel,source,config}.mjs
│                            + selftest-data/ (synthetic test data — NOT design)
│
├── agent/                ★ THE HARNESS
│   ├── agents/            ← 5 roles: orchestrator · planner · builder · builder-ui · reviewer
│   ├── skills/            ← 10 skills. Each carries procedure + depth + 🧍 gates.
│   │                        genesis · epic-breakdown · task-sharding · implement ·
│   │                        design-fidelity · review · bug-sweep · retro · handoff · release
│   │                        (there is no workflows/ layer — that split was the v1 mistake)
│   ├── memory/
│   │   ├── lessons/       ← per-area lessons + index.yaml. The retro writes; the HOOK injects.
│   │   └── decisions/     ← ADRs. Foundational ones are the human's (rule 3)
│   ├── hooks/             ← lesson-inject.py (rule 8, mechanized)
│   │                        · githooks/ (strip co-author, block main/dev push) · install-hooks.sh
│   ├── orchestrator/      ← scheduler.py (DAG, next, validate) · metrics_collect/report.py
│   │                        · lessons.py (promotion candidates)
│   │                        · health.py (the 7 decay checks — ARCHITECTURE §7)
│   │                        · ratelimit_guard.py (statusLine + freeze trigger, one file)
│   ├── adapters/          ← run-claude · run-codex · run-opencode (headless → runs/ → metrics.csv)
│   ├── handoffs/          ← freeze packets (_template.handoff.yaml)
│   ├── mcp/               ← per-platform guides + Codex/OpenCode/Cursor examples
│   └── rates/             ← cost-config.yaml (per-model price card — verify before trusting)
│
├── epics/
│   ├── README.md          ← the master epic map (the planner fills it; you approve)
│   └── _templates/        ← epic · task (9 sections) · tracker
│
├── docs/
│   ├── HUMAN-GUIDE.md     ← your gates, feedback routing, rollback cheat-sheet
│   ├── ARCHITECTURE.md    ← why it's built this way, what it buys, what it costs,
│   │                        where it breaks. Read before "simplifying" a gate.
│   ├── WORKSHOP.md        ← 90-min hands-on deck (Marp/Slidev) — `make workshop`
│   ├── business/         ★ YOU PUT THE BRD / SRS / feature list HERE (any format, read-only)
│   │                        → genesis T00 turns it into spec/ + docs/domain/
│   └── UI/               ★ YOU PUT THE DESIGN HERE (Figma export · HTML · React app)
│                            → genesis T03 turns it into design/golden/ + design/screens/
│                            (docs/design-system.md + docs/routes.md land here too)
└── runs/                  ← per-task run logs (gitignored; metrics.csv is the durable record)
```

## How a task flows

1. `make next` — the scheduler reads task frontmatter, picks the highest-priority
   unblocked task that doesn't collide on files with anything in flight.
2. The owner agent reads the task + the lessons (injected by the hook) + the ADRs
   its files touch + — if it's UI — its design contract. It works on
   `epic_<NN>_task_<MM>` in its own worktree, ticking the checklist with commit
   hashes as it goes.
3. UI work: `make design-verify` until green. A red gate means no PR.
4. Self-review → `review-requested` → **review by a different model** (rule 5) →
   squash-merge to the epic branch → metrics stamped → you flip `verified`.
5. Epic done → sweep (`skills/bug-sweep`) → your bug priorities → retro (lessons →
   rules → hooks, you approve) → 🧍 epic→development PR → release (tagged).
6. Rate limit at ~80%? Freeze packet → resume on the next platform. Nothing is
   lost; nothing depends on chat history.

## First run

1. Drop your BRD / SRS / feature list into **`docs/business/`** and your design
   into **`docs/UI/`**. Any format; nothing to convert by hand.
2. `npm install`, then `python -m venv .venv && source .venv/bin/activate &&
   pip install -r requirements.txt`, then `make hooks`. Keep `.venv` activated
   — the `make` targets shell out to bare `python3`.
3. `make design-selftest` — see the gate catch drift before you trust it.
4. Run genesis: `agent/skills/genesis/SKILL.md`.

Genesis will stop and make you choose the stack, the architecture and the auth
strategy — those are yours (rule 3). An agent that picks them quietly has made
the project's most expensive decision without review. It will also come back
with uncomfortable questions about the BRD; that's the job working, not failing.
