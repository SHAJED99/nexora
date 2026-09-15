# E12 · Account Recovery & Device Enrollment — Retro

**Date:** 2026-09-07 | **Sharded:** 2026-09-05 | **Build-complete:** 2026-09-07 | **Merged into `development`:** 2026-09-07

## What shipped
3 tasks and 14 bugs, all merged to `development` with P1/P2/P3=0.
- E12-T01: Own-account device list reader
- E12-T02: Existing device's approval UI
- E12-T03: New device's waiting UI + login gate
- E12-B01: Fixed returning user routing / device-id reuse (S1)
- E12-B02: Wired `RelationshipSyncService.push` to a production caller (S1)
- E12-B03: Fixed `pull()` to raise trust (S1)
- E12-B04: Fixed own-device-id cache invalidation (S3)
- E12-B05: Fixed `devices` design gate blind on `renderError` (S3)
- E12-B06: Registered E12 derived screens in `design/sources.yaml` (S3)
- E12-B07: Added widget test for `DeviceEnrollmentView` (S4)
- E12-B08: Logged and handled new sign-in failure path (S4)
- E12-B09: Ensured grant is deleted on block/deny (S3)
- E12-B10: Added defense-in-depth self-grant check to Firebase rules (S4)
- E12-B11: Formally descoped `FR-TRUST-007` and deleted `RelationshipSyncService` dead code (S3)
- E12-B12: Fixed devices screen icon-by-state / bottom-nav color (S3)
- E12-B13: Fixed 5 dumper blind spots in `flutter_probe_dumper.dart` (P3)
- E12-B14: Fixed nondeterministic ordering in `RelationshipRepository` device-row query (S4)

## What recurred
1. **Unwired capability sharding gap (L-process-007).** `E12-B02` revealed that `RelationshipSyncService.push` had zero production callers. The task contract asserted a wiring that didn't exist, and testing with mocked boundaries hid the gap.
2. **Integration testing gap between disjoint tasks.** `E12-B01`, `B02`, and `B03` were all S1s living in the seams between tasks, where each task passed its own review because tests mocked the other side (e.g. `checkApproval()` never actually receiving the pushed state).
3. **Design-fidelity tooling gap for derived screens.** `E12-B06` showed that `design/sources.yaml` did not register derived screens from previous epics, causing the gate to fail silently on `device-enrollment.md`.

## Numbers
- **Tasks:** 3
- **Bugs:** 14 (3× S1, 0× S2, 6× S3, 5× S4)
- **Review rounds:** Multiple per task/bug (evidence shows round 2s for bugs like B04, B13)
- **Estimate vs Actual:** No `metrics.csv` exists for this epic (expected per L-process-015).

## Lessons
- **process**: Unwired capabilities across task seams. Recurrence of **L-process-007**. Evidence: `E12-B02` sharding defect.
- **frontend/qa**: Tests passing because they mock the other side of an integration boundary. Matches the gap that led to `L-qa-001` (falsify the evidence).
- **process**: Derived design screens not registered for gating. Proposed new lesson title: **L-process-XXX — Derived design screens must be registered in tooling, not just documented**. Evidence: `E12-B06` and `E12-B13`.

## Promotion candidates
- **PENDING HUMAN GATE (retro_promotions)**: `L-process-007` recurrence warrants promotion to a rule (require integration test or caller verification for new services).
  - ✅ Decided 2026-09-16 under the human's delegation ("on you"): the pattern was mis-cited. L-process-007 is a different, already-promoted lesson. The "new service never wired" pattern is now its own lesson, `L-process-017`, promoted to a review rule ("Every new capability has a production caller", `skills/review`). A mechanical hook is not built yet.

## Open follow-ups
- A literal `Code: [pairing code]` placeholder shipped in `device_enrollment_view.dart`, explicitly out of T03's scope, needing a real protocol in a future epic.
- `devices` screen gate fails (0/1 pass/fail) due to residual golden mismatch (65.6% match, below threshold). Covered by existing bug lineage.
- `database.rules.json` sticky `directory_private/$deviceId/ownerUid` prevents multiple accounts on the same device (unreachable until account-switching is built).
- `isDeviceRevoked` fails open on a read timeout (mitigated by grant read failing closed).

> Drafted 2026-09-15 by agy (gemini-3.1-pro-high) from the epic, tracker and task files, fact-checked by the orchestrator (claude-opus-5): task and bug counts verified against tasks/; E15 counts corrected. Promotion candidates are proposals only, pending the human `retro_promotions` gate; no SKILL.md, hook or lesson file was changed.
