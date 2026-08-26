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
SCREEN ?=
IMPL ?=
STRICT ?=

.PHONY: next status review validate health metrics metrics-json hooks lessons \
        design-extract design-contract design-verify design-selftest workshop help

# ── Work queue ────────────────────────────────────────────────────────────────
next:            ## next executable task(s); make next LAYER=frontend
	$(SCHED) --next $(if $(LAYER),--layer $(LAYER),)
status:          ## per-epic progress board
	$(SCHED) --status
review:          ## tasks waiting for review
	$(SCHED) --review-queue
validate:        ## DAG + frontmatter + design-contract sanity
	$(SCHED) --validate
health:          ## decay checks — the 7 ways the harness dies quietly; STRICT=1 fails on warnings too
	$(PY) agent/orchestrator/health.py $(if $(STRICT),--strict,)

# ── Design fidelity (rule 2) ──────────────────────────────────────────────────
design-extract:  ## design source → golden screenshots + DOM/token dumps
	$(NODE) design/tools/extract.mjs $(if $(SCREEN),--screen $(SCREEN),)
design-contract: ## golden dumps → design/screens/<id>.md contracts
	$(NODE) design/tools/contract.mjs $(if $(SCREEN),--screen $(SCREEN),)
design-verify:   ## THE GATE: built UI vs contract → pass/fail + delta report
	$(NODE) design/tools/verify.mjs $(if $(SCREEN),--screen $(SCREEN),) $(if $(IMPL),--impl $(IMPL),)
design-selftest: ## prove the gate works (faithful impl passes, drifted impl fails)
	$(NODE) design/tools/selftest.mjs

# ── Memory & metrics ──────────────────────────────────────────────────────────
lessons:         ## lessons by area + promotion candidates (recurrence >= 2)
	$(PY) agent/orchestrator/lessons.py
metrics:         ## task/epic token + cost usage from metrics.csv
	$(PY) agent/orchestrator/metrics_report.py
metrics-json:    ## same, as JSON
	$(PY) agent/orchestrator/metrics_report.py --json
hooks:           ## install git hooks (co-author strip, main/development protection)
	bash agent/hooks/install-hooks.sh

workshop:        ## render docs/WORKSHOP.md → deck.html (add PDF=1 for a PDF)
	npx --yes @marp-team/marp-cli@latest docs/WORKSHOP.md --no-stdin \
	  -o deck.$(if $(PDF),pdf,html)
	@echo "harness: deck → deck.$(if $(PDF),pdf,html)"

help:
	@grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/ —/'
