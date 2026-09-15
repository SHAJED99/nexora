# E15 · Session Lifecycle & Settings Sub-Screens — Retro

**Date:** 2026-09-11 | **Sharded:** 2026-09-08 | **Build-complete:** 2026-09-11 | **Merged into `development`:** 2026-09-11

## What shipped
13 tasks and 3 bugs, all merged to `development` (16/16 closed).
- E15-T01: Local data wipe service and sign-out use case (PR #189)
- E15-T02: Session-aware launch routing (PR #194)
- E15-T03: Settings sub-screen shell widget (PR #188)
- E15-T04: Notifications settings screen (PR #195)
- E15-T05: Privacy & Security settings screen (PR #197)
- E15-T06: Security Center screen (PR #196)
- E15-T07: Account screen and sign-out confirmation (PR #199)
- E15-T08: Network and Battery settings screens (PR #200)
- E15-T09: Storage settings screen (PR #203)
- E15-T10: About / Updates screen (PR #202)
- E15-T11: Settings hub wiring (PR #208)
- E15-T12: Wired SignOutUseCase teardown and remote-revoke closures (PR #210)
- E15-T13: Reconciled `settings.md` HTML-sourced golden against build (P3, PR #215)
- E15-B01: Fixed GetX lazyPut crash on second visit (PR #191)
- E15-B02: Fixed Chat composer write to disposed controller (PR #191)
- E15-B03: Fixed BackgroundService hijacking BackgroundLifecycleObserver (P1, PR #214)

## What recurred
1. **Design-fidelity test gaming (L-frontend-001).** Reviewers repeatedly found "no control is rendered" tests defeated by `Listener` or `InkWell` gesture wrappers (T08, T09). The exact `L-frontend-001` gaming pattern recurred.
2. **Missing/vacuous test verification (L-qa-001).** T05 had vacuous `isNotNull` tests; T06 had vacuous key-leak/back-affordance falsifications; T07 had non-deterministic design-gate fixtures. The reviewer's rigorous falsification caught them.
3. **Flawed sharding dependencies.** T12's original contract ordered teardown before remote revoke, which would have thrown unconditionally since the database was already closed. The orchestrator self-caught this before review.

## Numbers
- **Tasks:** 13
- **Bugs:** 3 (B01, B02, B03)
- **Review rounds:** High. T06 took 5 rounds; T05 took 3 rounds; multiple PRs took 2 rounds.
- **Estimate vs Actual:** No `metrics.csv` data.

## Lessons
- **frontend/qa**: Widget-TYPE denylist tests for interactive affordances are reliably defeated by arbitrary gesture wrappers. Recurrence of **L-frontend-001**.
- **qa**: Reviewer falsification is the only reliable way to catch vacuous tests. Recurrence of **L-qa-001** (reinforced).
- **process**: Sharding sequence must respect resource lifecycles (e.g. don't close DB before network call). Proposed new lesson title: **L-process-XXX — Task sequencing must validate resource lifecycle constraints before sharding**. Evidence: `E15-T12`.

## Promotion candidates
- **PENDING HUMAN GATE (retro_promotions)**: `L-frontend-001` recurrence warrants promotion to a mechanical test hook (e.g., a shared `expectNoInteractiveAffordance` test helper that walks the gesture surface natively).
- **PENDING HUMAN GATE (retro_promotions)**: `L-qa-001` reinforcing evidence proves its utility, but the sheer volume of vacuous tests suggests it needs to move from a reviewer rule to a mechanical mutation-testing hook.
  - ✅ Decided 2026-09-16 under the human's delegation ("on you"), for both items above: no promotion now. `L-frontend-001` is already a rule (`skills/design-fidelity`), and so is `L-qa-001` (`skills/review` §2, "Falsify the evidence"); both keep operating as rules. The proposed hooks are deferred rather than rejected. A shared `expectNoInteractiveAffordance` test helper is test code for a later task. A mutation-testing hook needs a new dev dependency, which is a separate rule-3 call and not made here.

## Open follow-ups
- `OQ-E15-T10-2`: No local diagnostic log store exists; the About screen's Diagnostics card renders empty in production. (Requires a future epic).
- `EARS-UI-9` (state the absence of release notes) is untested, gated behind `OQ-E15-T10-1`/GAP-038.
- `E15-T06`: `signal_trusted_identities` has no first-seen timestamp column yet, so the Security Center row shows `timestamp: null`.
- Tooling limitation: an unlabeled, icon-only interactive widget evades both the `EARS-UI-9` test and the `design-verify` gate.

> Drafted 2026-09-15 by agy (gemini-3.1-pro-high) from the epic, tracker and task files, fact-checked by the orchestrator (claude-opus-5): task and bug counts verified against tasks/; E15 counts corrected. Promotion candidates are proposals only, pending the human `retro_promotions` gate; no SKILL.md, hook or lesson file was changed.
