# E00 · Genesis — Retro

**Date:** 2026-08-27 · **Epic status:** done (merged to `main`)

## What shipped
Domain analysis (`spec/` conversion from `docs/business/BRD.md`), 6
foundational ADRs (all accepted), `docs/conventions.md`, 7 design contracts
(human-approved), a real Flutter repo skeleton, and a walking skeleton
(welcome → login → Drift write → home) confirmed running on a physical
Android device.

## What recurred
Nothing recurred within this epic — it's the first one. Two process misses
worth noting for the record (both fixed in this same retro pass, evidence
in `agent/memory/lessons/process.md`):
- No `metrics.csv` was ever written despite rule 9 requiring one row per
  completed task. Not caught until this retro.
- `.claude/worktrees/` leftover directories (Windows path-length limits
  blocked clean removal) nearly got committed as embedded git repos via a
  broad `git add -A` — caught before commit, now gitignored
  (L-process-004).

## What got promoted
None yet from E00 specifically — its own misses (the null-clobber bug, the
untested migration, the hang risk, the design element drops) surfaced in
E01/E02's reviews, not E00's, since E00 had no comparable UI/backend
surface at this granularity. See E01/E02 retros.

## What the numbers said
No `metrics.csv` exists, so no estimate-vs-actual data to calibrate
against. **Action:** every task from here forward should append its row —
this is now a known gap, not an oversight repeating.

## Open follow-ups carried forward
- OQ-E00-2 — GitHub branch protection on `main`/`development` (needs your
  GitHub console action).
- OQ-E00-3 — no Flutter-capable design-fidelity gate exists yet; `make
  design-verify` can't inspect a compiled Android build. Every UI review
  since has been a manual `probe.json`/screenshot comparison. Worth
  building once a UI epic has bandwidth — E02's two design-fidelity misses
  (see its retro) make the case for this more urgent, not less.
