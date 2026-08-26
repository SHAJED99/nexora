---
id: E05
title: Messaging Reliability & Multi-Device Sync
status: todo
type: feature
priority: { moscow: must, wsjf: 3.2 }
depends_on: [E03, E04]
traces_to: [FR-MSG-001, FR-MSG-002, FR-MSG-003, FR-MSG-004, FR-MSG-005, FR-MSG-006, FR-MSG-007, FR-MSG-008]
external_services: [Firebase]
ui_surface: []
design_screens: []
---
# E05 · Messaging Reliability & Multi-Device Sync

## Business goal
Turn "an encrypted byte pipe with routing" (E03+E04) into "messages that
reliably arrive exactly once, in order, even offline and across a user's
multiple devices" — the semantics layer the wedge's chat UI (E06) is built on.

## User-visible outcome
None directly (no new screen) — proven through E06's chat UI actually
behaving correctly (no dupes, no reordering, works offline, catches up
across devices).

## Scope
**In scope**
- Offline outgoing queue (compose while offline → queued → sent when a
  route exists)
- Delivery-state machine: Queued/Sent/Accepted/Delivered/Stored/Read/Failed
- Idempotency (unique ids, dedup) and logical ordering under out-of-order
  packet arrival
- Multi-device sync (missing-data-only, not full re-sync) and Firebase-less
  operation with reconnect-time sync
- Conflict resolution favoring the more security-restrictive state
  (BLOCK>TRUST, LOCATION-OFF>LOCATION-ON, REVOKED>ACTIVE, REMOVED>MEMBER)

**Out of scope**
- The chat UI itself (E06)
- Group-specific sync nuances beyond what this epic's general mechanism
  already covers (E07 consumes this, doesn't extend it)

## Data model
`messages` (keyset-paginated per `docs/conventions.md`), `delivery_states`,
`sync_cursors` (per device-pair, "what's missing" bookkeeping).

## API surface
Internal — consumed by E06/E07's presentation layer; Firebase used only for
sync *metadata*, never content (`FR-FB-002`).

## Screens
None.

## Acceptance criteria (epic-level, EARS)
- **EARS-MSG-1**: WHEN a message is created offline, the system SHALL queue it locally and send once a route is available. (FR-MSG-001)
- **EARS-MSG-2**: The system SHALL NOT create duplicate messages from duplicate packets. (FR-MSG-003)
- **EARS-MSG-3**: The system SHALL maintain logical message ordering despite out-of-order packet arrival. (FR-MSG-004)
- **EARS-MSG-4**: WHEN resolving conflicts, the system SHALL favor the more security-restrictive state per the defined precedence table. (FR-MSG-007)

Cross-cutting: **NFR-REL-001**, **NFR-SCALE-001** *(needs number, A-002
placeholder applies)* bind here.

## Tasks
<sharded by `skills/task-sharding` once this epic is approved>

## Test strategy
Deterministic packet-reordering and duplicate-injection tests (this is
exactly what a route/network simulator, if built in E04, should make easy);
multi-device catch-up test with a simulated Firebase-outage window.

## Risks
| Risk | Mitigation |
|------|-----------|
| Conflict-resolution precedence is easy to get half-right (only some state pairs implemented) | Task-sharding should enumerate all four stated precedence pairs as explicit test cases, not assume the pattern generalizes untested |

## Open Questions
_(none new — inherits E04's routing-formula dependency but doesn't itself need those numbers)_

## Analyze report
<pending — appended once tasks are sharded>

## Retro
→ `retro.md` (written after E05 completion)
