# E02 · Relationships, Trust & Blocking — Retro

**Date:** 2026-08-27 · **Epic status:** done (merged to `main`)

## What shipped
The relationship/trust domain (Trusted/Allowed/Unknown/Blocked, bidirectional-
independent evaluation, blocking enforcement), the real Devices screen, and
the real Settings screen (8-row navigation menu) — the first two UI screens
built after genesis's welcome/login.

## What recurred — the epic's central finding
**The same design-fidelity miss hit twice in a row:**
- **E02-T02 (Devices) review:** a 40×40 tinted circular backdrop behind
  each device row's leading icon was dropped. The design contract's
  printed element table doesn't surface it (no text/icon role of its own);
  it only exists as an untexted wrapper `generic` in `probe.json`.
- **E02-T03 (Settings) review:** the *same class* of miss, one level up —
  the builder had learned to check `probe.json` for untexted wrappers
  (correctly found 4 of them) but misread them as "a uniform per-row
  style" instead of recognizing they were GROUP containers holding 1/2/2/3
  rows each. Built 8 individually-bordered cards where the design has 4
  grouped panels.

This is now `agent/memory/lessons/design.md` L-design-001, recurrence 2,
**promoted to a rule** in `agent/skills/design-fidelity/SKILL.md` (Rules
§5) this retro — 🧍 `retro_promotions` gate, human-approved.

A smaller, distinct miss: **E02-T01 review** found
`EvaluateConnectionRequestUseCase` collapsed a stored `blocked` or
`allowed` relationship state to `unknown` on evaluation — a future caller
reading that return value to decide "unknown device, prompt the user?"
would have prompted for a device the user explicitly blocked, defeating
FR-BLOCK-001's enforcement intent. Fixed; not a recurrence of anything
else in this epic.

## What got promoted
- **L-design-001 → rule** (design-fidelity SKILL.md §5, this retro).

## What the numbers said
No `metrics.csv` — same gap as E00/E01. Given this epic needed 2 review
rounds on 2 of its 3 tasks (T02 and T03 both hit `changes_requested`), the
size estimates themselves (T02 = M, T03 = S) look roughly right — the
rework was a fidelity miss, not an underestimate of scope.

## Open follow-ups carried forward
- `design/gaps.md` GAP-002/003/004 (E02-T02: empty state, device
  name/transport placeholders, Discover no-op) and GAP-005 (E02-T03:
  Privacy & Security sub-screen has no design source) all still need your
  actual sign-off — none are agent-approved (that itself was L-process-002,
  corrected during E02-T02's review).
- OQ-E00-3 (no Flutter-capable design-fidelity gate) is now a sharper
  problem than when E00 closed: **two consecutive real UI misses were
  caught only because a human-equivalent reviewer manually diffed
  `probe.json` against the build.** If a future review pass is less
  thorough, this class of miss ships. Recommend prioritizing a Flutter
  design-verify gate (even a manual-trigger script comparing a debug
  build's widget tree/RenderObject geometry against `probe.json`) before
  E06 (the wedge) reaches review — that epic has 3 real screens with much
  higher complexity than a static menu.
- `verify()` in `DevicesController` calls `RelationshipRepository.upsert`
  directly, bypassing the domain layer (`BlockUseCase`'s pattern) —
  flagged as a follow-up, not urgent.
- No font-family theming anywhere in the app (`design/screens/*.md`
  measure JetBrains Mono/Inter/Geist; the build uses the platform default)
  — bug-sweep item, severity S3, needs a font-asset dependency decision
  (rule 3) before it can be fixed.
