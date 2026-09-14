# E14 · Version & Update Management — Retro

**Date:** 2026-09-07 | **Sharded:** 2026-09-05 | **Build-complete:** 2026-09-07 | **Merged into `development`:** 2026-09-07

## What shipped
6 tasks and 8 bugs, all merged to `development` with P1/P2/P3=0.
- E14-T01: Version-policy schema + cache
- E14-T02: Version state machine
- E14-T03: Signature verification (FR-VER-011)
- E14-T04: Mandatory-update UI + Play integration (PR #109)
- E14-T05: Relay frame version negotiation
- E14-T06: Migration-safety regression suite
- E14-B01: Wired `VersionPolicyService.refresh()` to production callers (S2/P1)
- E14-B02: Enforced application communication blocking on update (S2/P1)
- E14-B03: Fixed `_readInstalledBuildNumber` catch-all fail-open (S3/P2)
- E14-B04: Added v9 to migration regression sample (S4/P3)
- E14-B05: Added missing `/version-update-required` to `routes.md` (S4/P3)
- E14-B06: Added reconnect-triggered re-evaluation (S3/P2)
- E14-B07: Resolved `sentry_flutter` compileSdk conflict (bump to 9.29.0)
- E14-B08: Configured Sentry privacy options correctly

## What recurred
1. **Unwired capability sharding gap (L-process-007).** `E14-B01` revealed `VersionPolicyService.refresh()` had zero production callers. `E14-B02` revealed `AppBinding.blockCommunication` was not wired to block the coordinator/pipeline. Every task injected the cached policy in tests, hiding the integration hole.
2. **Missing `source: derived` registration.** The design fidelity gate for `version-update-required` could not run (gate blind spot from E12).

## Numbers
- **Tasks:** 6
- **Bugs:** 8 (0× S1, 2× S2, 3× S3, 3× S4)
- **Review rounds:** T03 took 2 rounds; bugs had multiple rounds (e.g. B06 round 2).
- **Estimate vs Actual:** No `metrics.csv` data.

## Lessons
- **process**: Unwired capabilities across task seams. Recurrence of **L-process-007**. Evidence: `E14-B01` and `E14-B02`.
- **process**: Missing route documentation. Proposed new lesson title: **L-process-XXX — UI tasks must update docs/routes.md**. Evidence: `E14-B05`.

## Promotion candidates
- **PENDING HUMAN GATE (retro_promotions)**: `L-process-007` unwired-capability pattern recurrence is overwhelming and demands a mechanical hook or review rule (verify integration at call site).

## Open follow-ups
- `OQ-E14-1` (where `FR-VER-004`'s simulation framework lives) remains open and unsharded.
- `E14-B06` (F4 finding): Reconnect-triggered update navigates to the update screen but does NOT retroactively set `AppBinding.blockCommunication`. A mid-session emergency policy update leaves background services running. Needs a future task to make `blockCommunication` mutable.

> Drafted 2026-09-15 by agy (gemini-3.1-pro-high) from the epic, tracker and task files, fact-checked by the orchestrator (claude-opus-5): task and bug counts verified against tasks/; E15 counts corrected. Promotion candidates are proposals only, pending the human `retro_promotions` gate; no SKILL.md, hook or lesson file was changed.
