# E13 · Abuse Prevention & Diagnostics — Retro

**Date:** 2026-09-07 | **Sharded:** 2026-09-05 | **Build-complete:** 2026-09-07 | **Merged into `development`:** 2026-09-07

## What shipped
7 tasks and 3 bugs, all merged to `development` with P1/P2/P3=0.
- E13-T01: Generic rate-limiter primitive
- E13-T02: Rate-limit connection-request & device-registration
- E13-T03: Rate-limit message flooding & relay abuse
- E13-T04: Rate-limit group-invitation spam
- E13-T05: Byte-volume admission control
- E13-T06: Real observability client (Sentry)
- E13-T07: Wire the rate limiter into production (P1, PR #116)
- E13-B01: Fixed `RateLimiter.allow` eviction (bounded rolling 2 days)
- E13-B02: Prevented device ID leak in observability sink
- E13-B03: Fixed `SentryObservabilityClient.init()` hang on empty DSN (PR #158)

## What recurred
1. **Unwired capability sharding gap (L-process-007).** `E13-T02`'s built mechanism had zero live production call sites. Caught in review and required filing a new P1 task (`E13-T07`) to wire it in.
2. **Fail-open validation gates.** `E13-T05`'s rollover branch never compared the packet size against the budget, letting an oversized packet sail through on the first hit.

## Numbers
- **Tasks:** 7
- **Bugs:** 3 (0× S1, 0× S2, 1× S3, 2× S4)
- **Review rounds:** T07 took 3 review rounds; others mostly 1-2.
- **Estimate vs Actual:** No `metrics.csv` data (expected per L-process-015).

## Lessons
- **process**: Sharding misses real production call sites, leaving capabilities unwired. Recurrence of **L-process-007**. Evidence: `E13-T02` requiring `E13-T07`.
- **qa**: Tests failing to catch fail-open branches (T05 oversized packet). Recurrence of **L-qa-001** (reviewer falsification caught it).

## Promotion candidates
- **PENDING HUMAN GATE (retro_promotions)**: `L-process-007` recurrence (now spanning E06, E09, E11, E12, E13, E14) strongly warrants promotion to a mechanical hook (e.g., dead-code analysis for new public methods).

## Open follow-ups
- `RelayEngine` rate limiting accepts rotating claimed source IDs (evasion limitation accepted due to TOFU trust posture).
- If multiple accounts sign in on the same device (currently unreachable), sign-in will silently reuse the device identity row and bypass registration rate limits.

> Drafted 2026-09-15 by agy (gemini-3.1-pro-high) from the epic, tracker and task files, fact-checked by the orchestrator (claude-opus-5): task and bug counts verified against tasks/; E15 counts corrected. Promotion candidates are proposals only, pending the human `retro_promotions` gate; no SKILL.md, hook or lesson file was changed.
