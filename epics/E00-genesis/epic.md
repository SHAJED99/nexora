---
id: E00
title: Genesis — project foundation
status: in-progress
type: genesis
priority: { moscow: must, wsjf: 10 }
depends_on: []
traces_to: [spec/srs.md, spec/feature-list.md, spec/constitution.md]
external_services: [Google Auth, Firebase, Google Play in-app update]
ui_surface: [mobile]
design_screens: [welcome, login, dashboard, conversations, chat, devices, settings]
---
# E00 · Genesis — project foundation

## Business goal
Establish the human-decided architectural foundation (stack, crypto protocol,
transport strategy, auth/session model, persistence, observability), the
project conventions, the design contracts, and a deployable walking skeleton —
so every later epic executes against locked decisions instead of relitigating
them.

## User-visible outcome
None yet by design — Epic 00 produces no user-facing feature. Its output is a
running, empty-but-real app (the walking skeleton) that later epics build
inside of.

## Scope
**In scope**
- Domain analysis, `spec/` conversion, `docs/domain/`
- Foundational ADRs (persistence, architecture, crypto, transport, auth, observability)
- Conventions (`docs/conventions.md`)
- Design contract extraction (`design/screens/*.md`, `design/gaps.md`)
- Repo/route/data-flow skeleton
- Walking skeleton: one real screen → one real local-DB write → visible result, running in CI
- CI, branch protection, hooks, design self-test

**Out of scope**
- Any real feature (chat, routing, groups, calls, etc.) — deferred to their own epics

## Tasks
| Task | Title | Layer | Size | Status |
|------|-------|-------|------|--------|
| E00-T00 | Domain analysis + spec/ conversion | docs | L | ✅ done |
| E00-T01 | Foundational ADRs (0001–0006) | docs | M | ✅ done — all `accepted`, 2026-08-26 |
| E00-T02 | Conventions (`docs/conventions.md`) | docs | S | ✅ done |
| E00-T03 | Design contracts (extract + gap pass) | design | M | ✅ done — 7 screens contracted + human-approved (Q-DESIGN-001); `design/gaps.md` intentionally empty until FR ids exist in an epic |
| E00-T04 | Repo skeleton + route/data-flow maps | infra | M | 🟡 todo |
| E00-T05 | Walking skeleton (real request, end to end, running) | cross-cutting | L | 🟡 todo |
| E00-T06 | CI, branch protection, hooks, design self-test | infra | M | 🟡 todo |

## Test strategy
T05's walking skeleton is proven by: app builds, launches, the one wired
screen performs one real local Drift read/write, and this runs green in CI
(`make design-selftest` plus a build/boot smoke check). No feature logic to
test yet.

## Risks
| Risk | Mitigation |
|------|-----------|
| Building the skeleton before conventions are used in anger may miss a convention gap | Conventions revisited at first feature epic's retro if so |
| No numeric NFR targets exist (R-003, knowledge-map) | Does not block the skeleton; will need human-supplied numbers before any task claiming an NFR is done |

## Open Questions
- **OQ-E00-1 — Q-ARCH-004/Q-FUNC-005/Q-FUNC-006 defaults.** Per human decision (2026-08-26): these fold into their respective feature epics (routing/relay, groups/encryption) at task-sharding time, using the recommended-default v1 heuristic, flagged tunable — not blocking here.
  - **Status:** ⚪ deferred (by design)
  - **Answer:** fold into feature-epic task-sharding, not genesis
  - **Answered by:** human (via Q&A, 2026-08-26)
  - **Date:** 2026-08-26

## Analyze report
<pending — appended once T04–T06 land>

## Retro
→ `retro.md` (written after E00 completion)
