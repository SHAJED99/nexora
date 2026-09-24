# Harness targets. Stack ops (up/down/migrate/test/lint) are appended by genesis
# once the human has picked a stack (rule 3).
# Probe by RUNNING it, not by looking for it: on Windows a `python3` file
# exists on PATH (the Microsoft Store stub) but is not an interpreter, so
# `command -v python3` finds it and every target then dies with e=2.
# Override with: make <target> PY=/path/to/python
PY ?= $(shell python3 -c "" >/dev/null 2>&1 && echo python3 || echo python)
SCHED := $(PY) agent/orchestrator/scheduler.py
NODE := node
LAYER ?=
ID ?=
CHECK ?=
SCREEN ?=
IMPL ?=
STRICT ?=
PORT ?= 8787
OUT ?= harness-status.html

.PHONY: next status review validate health metrics metrics-json hooks lessons trace \
        health-selftest \
        design-extract design-contract design-verify design-selftest design-probe \
        design-deps \
        dashboard dashboard-snapshot help

# ── Work queue ────────────────────────────────────────────────────────────────
next:            ## next executable task(s); make next LAYER=frontend
	$(SCHED) --next $(if $(LAYER),--layer $(LAYER),)
status:          ## per-epic progress board
	$(SCHED) --status
review:          ## tasks waiting for review
	$(SCHED) --review-queue
validate:        ## DAG + frontmatter + design-contract sanity
	$(SCHED) --validate
dashboard:       ## live web board (gates, queue, review, questions) at 127.0.0.1:$(PORT)
	$(PY) agent/orchestrator/dashboard.py --port $(PORT) --open
dashboard-snapshot: ## one static, self-contained HTML snapshot -> $(OUT)
	$(PY) agent/orchestrator/dashboard.py --html $(OUT)
health:          ## decay checks — the 7 ways the harness dies quietly; STRICT=1 fails on warnings too
	$(PY) agent/orchestrator/health.py $(if $(STRICT),--strict,)
health-selftest: ## prove H8 still rejects every shape it has wrongly exempted
	$(PY) agent/orchestrator/health.py --selftest
trace:           ## requirement → task → test chain + orphans → docs/traceability.md; make trace ID=FR-AUTH-001 for a scoped walk
	$(PY) agent/orchestrator/traceability.py $(if $(ID),--id $(ID),) $(if $(CHECK),--check,)

# ── Design fidelity (rule 2) ──────────────────────────────────────────────────
# The design tools are Node programs with real dependencies declared in
# package.json. `node_modules/` is gitignored, so a fresh clone -- or any
# `git worktree` created from one -- has none, and every target below then
# dies with a raw ERR_MODULE_NOT_FOUND stack trace naming `yaml`, which reads
# like a broken tool rather than a missing `npm install`.
#
# This matters more than an error message usually does. `make design-verify`
# is NOT in CI, so an UNRUNNABLE gate and a gate nobody ran look exactly the
# same from outside: both are simply an absence. On 2026-09-24 the rule-2
# gate had been in that state, and four screens were reporting FAIL into a
# void (docs/product-completeness-audit.md). This preflight makes the
# difference visible at the moment someone tries to run it.
#
# Two checks rather than one, and rather than a list of every package (which
# would drift): `.package-lock.json` proves an install actually resolved a
# tree, and `playwright` proves the devDependencies came with it. The second
# is not belt-and-braces -- design/tools/lib/browser.mjs and pixel.mjs import
# playwright, pixelmatch and pngjs at MODULE level, so every design target
# needs them even on the `--impl flutter` path that never opens a browser.
# An earlier draft checked only `node_modules/yaml` and would have passed a
# prod-only install straight into the crash it exists to prevent.
design-deps:     ## rule-2 gate preflight: are the design tools' Node deps installed?
	@test -f node_modules/.package-lock.json || { \
	  echo "design: Node dependencies are NOT installed -- the rule-2 gate cannot run."; \
	  echo "design: that is NOT the same as the gate passing. It has not run at all."; \
	  echo "design: fix with ->  npm install"; \
	  exit 2; }
	@test -d node_modules/playwright || { \
	  echo "design: devDependencies are missing (no node_modules/playwright)."; \
	  echo "design: every design target imports playwright/pixelmatch/pngjs at"; \
	  echo "design: module level -- see design/tools/lib/browser.mjs and pixel.mjs --"; \
	  echo "design: so a prod-only install (npm ci --omit=dev) cannot run the gate."; \
	  echo "design: fix with ->  npm install"; \
	  exit 2; }
	@echo "design: Node dependencies present."
design-extract:  design-deps ## design source → golden screenshots + DOM/token dumps
	$(NODE) design/tools/extract.mjs $(if $(SCREEN),--screen $(SCREEN),)
design-contract: design-deps ## golden dumps → design/screens/<id>.md contracts
	$(NODE) design/tools/contract.mjs $(if $(SCREEN),--screen $(SCREEN),)
design-verify:   design-deps ## THE GATE: built UI vs contract → pass/fail + delta report
	$(NODE) design/tools/verify.mjs $(if $(SCREEN),--screen $(SCREEN),) $(if $(IMPL),--impl $(IMPL),)
design-selftest: design-deps ## prove the gate works (faithful impl passes, drifted impl fails)
	$(NODE) design/tools/selftest.mjs
design-probe:     ## build/design-probe/<screen>.json dumps from flutter_test (E06-T01)
	flutter test test/design/design_probe_test.dart

# ── Memory & metrics ──────────────────────────────────────────────────────────
lessons:         ## lessons by area + promotion candidates (recurrence >= 2)
	$(PY) agent/orchestrator/lessons.py
metrics:         ## task/epic token + cost usage from metrics.csv
	$(PY) agent/orchestrator/metrics_report.py
metrics-json:    ## same, as JSON
	$(PY) agent/orchestrator/metrics_report.py --json
hooks:           ## install git hooks (co-author strip, main/development protection)
	bash agent/hooks/install-hooks.sh

