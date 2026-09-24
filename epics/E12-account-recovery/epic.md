---
id: E12
title: Account Recovery & Device Enrollment
status: done  # 2026-09-07; 3/3 tasks + 14/14 bugs closed, P1/P2/P3=0 — merged into development
type: feature
priority: { moscow: should, wsjf: 3.5 }
depends_on: [E01, E03]
traces_to: [FR-RECOVER-001, FR-RECOVER-002]
external_services: []
ui_surface: [mobile]
design_screens: []
---
# E12 · Account Recovery & Device Enrollment

## Business goal
Let a user add a new device authorized by an existing trusted device, and
be honest that losing all cryptographic keys means historical content is
gone by design — not a bug to be worked around.

## Scope
**In scope:** new-device enrollment flow vouched for by an existing trusted
device; explicit, clear "no recovery" messaging when all keys are lost.
**Out of scope:** any recovery mechanism that would contradict FR-RECOVER-002
— this must never be silently "solved" by weakening the security property.

## Acceptance criteria (epic-level, EARS)
- **EARS-RECOVER-1**: WHERE possible, an existing trusted device SHALL authorize a new device's enrollment. (FR-RECOVER-001)
- **EARS-RECOVER-2**: IF all cryptographic keys are permanently lost, THEN encrypted historical content SHALL NOT be recoverable. (FR-RECOVER-002 — intentional, not a defect)

## Tasks
3 tasks, sharded 2026-09-05 — see `tracker.md`.

| Task | Title |
|---|---|
| E12-T01 | Read back this account's own device list from Firebase |
| E12-T02 | Detect and surface a pending new-device enrollment request on the Devices screen |
| E12-T03 | New-device enrollment waiting screen, login-flow gate, and the "no recovery" notice |

## Open Questions
None new. Design gap resolved: `GAP-028` (approved 2026-09-05, contracts
written — `design/screens/device-enrollment.md`,
`design/screens/device-enrollment-approval.md`).

## Bug sweep result (2026-09-06)

All 3 tasks `done` and merged to `epic_12`; end-of-epic sweep run per
`skills/bug-sweep`. **8 bugs filed, 3 of them S1 — the epic is NOT ready for
its `development` merge.** `EARS-RECOVER-1` ("an existing trusted device
SHALL authorize a new device's enrollment") is non-functional in the running
app for three independent reasons (`E12-B01`, `E12-B02`, `E12-B03`), while
both task suites and `flutter analyze` are green.

`EARS-RECOVER-2` (lost keys ⇒ unrecoverable) is unaffected — it is a
structural property of `ADR-0003`, and this epic's contribution to it is UI
copy, which shipped correctly.

See `tracker.md` §Bug sweep for the table, the probe evidence, the `E13-T07`
cross-epic sequencing dependency, and the C2/C3 out-of-scope dispositions.

**Update (2026-09-07):** all 8 of the above, plus 6 more filed during fix
review (`E12-B09`–`E12-B14`), are now fixed and merged — 14/14 bugs closed,
P1/P2/P3 all zero. See `tracker.md`'s own header and event log for the full
closure sequence. This epic's merge into `development` is complete.

## Analyze report / Retro

### ANALYZE REPORT (2026-09-05)

| Check | Result |
|---|---|
| **EARS trace** | PASS. `EARS-RECOVER-1`/`FR-RECOVER-001` → `T01`/`T02`/`T03` (their own `EARS-RECOVER-3..11`). `EARS-RECOVER-2`/`FR-RECOVER-002` → `T03`'s `no-recovery-notice` state and its `EARS-RECOVER-11`. Note: the underlying negative security property ("lost keys ⇒ unrecoverable") is structural, already guaranteed by `ADR-0003`'s crypto design (no key escrow, Firebase never holds plaintext or private keys per `FR-FB-002`) — this epic's own contribution is surfacing that property honestly in UI copy, not building a new mechanism that makes it true. No orphans either direction. |
| **Contract sanity** | PASS (vacuous) — no API/list endpoints; internal backend + one new screen. |
| **Collision matrix** | PASS, empty. `T02` and `T03` touch disjoint files; both depend only on `T01`. |
| **Scope fences** | PASS. Every task's §4 is non-empty (e.g. `T01`: no caller yet; `T02`: no new trust mechanism, no notification; `T03`: no change to the first-device path). |
| **MoSCoW inflation** | FAIL-adjacent, flagged not blocked: 3/3 `must`. Re-graded: all three are load-bearing links in one short chain (`T01` is a shared dependency, `T02`/`T03` are the two literal halves of `FR-RECOVER-001`'s own "existing device authorizes new device" sentence) — an epic this small legitimately has no discretionary task to grade `should`. Not treated as inflation given `EARS-RECOVER-1` is itself no-optional at the epic's own MoSCoW (`priority.moscow: should` at the epic level, but the EARS criteria are needs-based `SHALL`, not qualified). |
| **Size** | PASS. One `S` (`T01`), two `M` (`T02`, `T03`). No `L`. |
| **Design** | PASS. Both frontend tasks (`T02`, `T03`) carry `design_contract:` pointing at `GAP-028`'s two approved, written contracts. |
| **Obligation ownership** | PASS. `T03`'s contract names `T02`'s `push` call in prose ("whatever a trusted device's `push(...)` already wrote") but does not describe `T02` performing work `T02`'s own contract doesn't independently state — `T02`'s own §3 states the `verify`/`push` wiring itself. |
| **Inherited obligations** | PASS, nothing to carry. `depends_on: [E01, E03]` — searched both epics' `retro.md` §Open follow-ups and every task/bug file for any mention of E12/recovery/enrollment: none found (checked earlier this session during design-gap research). |

**Note on scope discovery**: task-sharding's own backend investigation
found `FR-RECOVER-001` needs almost no new protocol — `T01` is the only
new backend surface (a single read method); `T02`/`T03` wire two already-
accepted mechanisms (`RelationshipRepository`/`RelationshipSyncService`
from `E02`/`E11-T05`, `DevicesController`'s existing `verify`/`block`)
together with new UI. No new ADR was needed; every choice here is within
`ADR-0001`/`ADR-0002`/`ADR-0003`/`ADR-0005`/`ADR-0008`'s existing
acceptance.

🧍 **HUMAN GATE** (`analyze_report`): pending. Approval unlocks dispatch.
