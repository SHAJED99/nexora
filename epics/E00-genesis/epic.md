---
id: E00
title: Genesis — project foundation
status: done
type: genesis
priority: { moscow: must, wsjf: 10 }
depends_on: []
traces_to: [spec/srs.md, spec/feature-list.md, spec/constitution.md]
external_services: [Google Auth, Firebase, Google Play in-app update]
ui_surface: [mobile]
design_screens: [welcome, login, dashboard, conversations, chat, devices, settings]
---
# E00 · Genesis — project foundation

**Gate:** 🧍 `epic00_exit_review` — ✅ cleared by human on 2026-08-26
(all 6 foundational ADRs accepted; walking skeleton confirmed running on a
physical Android device; human approved the epic_00 → development → main
merges. Two follow-ups remain open and don't block this gate: OQ-E00-2
branch protection, OQ-E00-3 Flutter-capable design gate.)

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
| E00-T04 | Repo skeleton + route/data-flow maps | infra | M | ✅ done — reviewed (Opus, approve with notes) — Flutter Android skeleton scaffolded (`lib/` per docs/conventions.md), `docs/routes.md` + `docs/data-flow.md` written |
| E00-T05 | Walking skeleton (real request, end to end, running) | cross-cutting | L | ✅ done — reviewed (Opus, approve with notes) — welcome/login built against contracts; UI → GetX controller → use case → repository → Drift wired with one real write + read; `flutter analyze`/`flutter test` green, `flutter build apk --debug` succeeded; no emulator available to confirm on-device boot |
| E00-T06 | CI, branch protection, hooks, design self-test | infra | M | ✅ done — reviewed (Opus, approve with notes) — `.github/workflows/ci.yml` added; git hooks confirmed already installed; `design-selftest` green; **branch protection on `main`/`development` NOT done** (requires GitHub UI/API repo-admin access — open human follow-up, OQ-E00-2) and design-verify wiring for welcome/login explicitly deferred (OQ-E00-3) |
| E00-B01 | Release builds signed with the debug key | infra | S | ✅ done — reviewed (Opus subagent, APPROVE, 4 non-blocking findings applied) — release signing now reads `android/key.properties`, falling back to the debug key when absent so CI and fresh clones are unaffected; **the keystore itself is not created here** (`secrets_or_env_change` human gate, OQ-E00-B01-1) and `docs/release-signing.md` is its runbook |

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
- **OQ-E00-2 — GitHub branch protection on `main`/`development`.** Not doable from an agent worktree (needs GitHub UI or `gh api` with repo-admin credentials). Remains an explicit human follow-up before the exit gate closes.
  - **Status:** 🟡 open
  - **Answer:** _<empty>_
  - **Answered by:** _<empty>_
  - **Date:** _<empty>_
- **OQ-E00-3 — No design-fidelity gate exists for the built Flutter app yet.** `make design-verify`'s DOM probe can't inspect a compiled Android build; welcome/login were only hand-diffed against their contracts during review (2026-08-26). A Flutter-capable design gate (e.g. golden-image widget tests, or a debug HTTP/semantics dump the existing tooling can probe) is a follow-up task for whichever epic next touches a screen.
  - **Status:** 🟢 closed
  - **Answer:** Built as E06-T01, first task of E06, per E02's retro recommendation
    and E06's own `epic.md` §Risks. `test/design/flutter_probe_dumper.dart`
    walks a pumped screen's `Element` tree and emits a JSON dump in the same
    shape `design/tools/lib/probe.mjs` produces for a DOM page;
    `design/tools/lib/flutter_probe.mjs` normalizes it; `design/tools/verify.mjs`
    accepts it via `IMPL=flutter` / `--impl-probe <path>`, reusing
    `compare.mjs`, `design/screens/*.md` and `design/thresholds.yaml`
    unchanged. All four hard checks (missing elements, copy, style deltas,
    off-token findings) run in full; pixel comparison is explicitly skipped
    and reported as such (no screenshot exists on this path). Proven against
    `devices` (E02-T02) with a real, non-trivial report, and falsified via a
    four-way drift-injection fixture (delete an element / one-character copy
    change / one colour channel / +4px radius — each independently produces
    a hard finding). See `docs/design-gate-flutter.md` for the run
    instructions, the role-mapping table and the gate's honest limits.
  - **Answered by:** builder (E06-T01)
  - **Date:** 2026-08-29
- **OQ-E00-1 — Q-ARCH-004/Q-FUNC-005/Q-FUNC-006 defaults.** Per human decision (2026-08-26): these fold into their respective feature epics (routing/relay, groups/encryption) at task-sharding time, using the recommended-default v1 heuristic, flagged tunable — not blocking here.
  - **Status:** ⚪ deferred (by design)
  - **Answer:** fold into feature-epic task-sharding, not genesis
  - **Answered by:** human (via Q&A, 2026-08-26)
  - **Date:** 2026-08-26

## Analyze report
<pending — appended once T04–T06 land>

## Retro
→ `retro.md` (written after E00 completion)
