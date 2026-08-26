# Agent harness v2

A spec-driven, **design-faithful**, multi-agent, human-in-the-loop harness for
building software with coding agents.

This repo is **the harness only** — no product code. Drop your requirements into
`docs/business/` and your design into `docs/UI/`, run genesis, and it produces
epics → tasks → gated PRs.

## What's different from v1

| | v1 | v2 |
|---|---|---|
| Process surface | 17 skills + 12 workflows + a protocol doc | **10 skills**, procedure + depth + gates in each |
| Roles | 7 | **5** — peer-vs-QA is model *routing*, not two files |
| Task template | 18 sections (half said "None.") | **9**, all load-bearing |
| Review gates per task | 3 (peer → QA → human) | **1** cross-model gate + an epic sweep + the human |
| Design fidelity | "reviewer compares screenshots" | **`make design-verify`** — measured, blocks the merge |
| Learning | lessons written, hand-pasted into role files, rotted | **injected automatically** by a hook; promotion by recurrence |
| Memory | files + a Graphiti graph server | **files** |

## Quickstart

```bash
# 1. your inputs (any format — read-only, agents never edit them)
cp <your BRD/SRS/feature-list>  docs/business/
cp -r <your design>             docs/UI/

# 2. the harness
npm install                     # design-gate tooling
python -m venv .venv            # keep .venv activated for every make target below
source .venv/bin/activate
pip install -r requirements.txt
make hooks                      # commit-msg + branch protection
make design-selftest            # see the gate catch drift before you trust it
make help
```

Then run genesis: `agent/skills/genesis/SKILL.md`. It turns `docs/business/`
into a greppable `spec/` (rule 1 needs an **id** to be law) and `docs/UI/` into
measured design contracts (rule 2 needs a **golden** to be checkable). It will
stop and ask you to pick the stack — that's rule 3, not a limitation.

## The design gate, in one paragraph

The reason v1 implementations didn't match their designs isn't that agents were
careless. It's that "compare the build to the design" is beyond human
perception: a build with a missing checkbox, two rewritten strings, a wrong
accent (`#059669` → `#10b981`) and a wrong radius renders **0.04% different by
pixel comparison**. Run `make design-selftest` and watch it. So v2 doesn't ask
anyone to look — it extracts a golden from the design, generates a ~150-line
contract per screen, and mechanically checks the build for missing elements,
copy drift character-for-character, and off-token styles. Hard findings block
the merge. Elements match by role + words + geometry, never by CSS selector, so
a faithful port with completely different markup scores 100%.

## Where to look

| | |
|---|---|
| The rules | `AGENTS.md` (10 of them) |
| Your gates | `docs/HUMAN-GUIDE.md` |
| Why it's built this way (+ its limits) | `docs/ARCHITECTURE.md` |
| Teaching it to a room | `docs/WORKSHOP.md` — `make workshop` |
| The map | `STRUCTURE.md` |
| The design gate | `design/README.md` · `agent/skills/design-fidelity/` |
| How to do anything | `agent/skills/<skill>/SKILL.md` |
| Topology & policy | `harness.yaml` |

MIT licensed. See `LICENSE`.
