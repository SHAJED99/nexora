---
id: E04
title: Mesh Discovery, Relay & Dynamic Routing
status: todo
type: feature
priority: { moscow: must, wsjf: 2.8 }
depends_on: [E01, E03]
traces_to: [FR-DISC-001, FR-DISC-002, FR-DISC-003, FR-ROUTE-001, FR-ROUTE-002, FR-ROUTE-003, FR-ROUTE-004, FR-ROUTE-005, FR-ROUTE-006, FR-ROUTE-007, FR-ROUTE-008, FR-ROUTE-009]
external_services: []
ui_surface: [mobile]
design_screens: [devices]
---
# E04 · Mesh Discovery, Relay & Dynamic Routing

## Business goal
This is what makes NEXORA a mesh messenger rather than a generic chat app:
devices discover each other over Bluetooth/Wi-Fi/Wi-Fi Direct/Internet,
relay for each other when no direct path exists, and continuously migrate to
better routes without dropping communication.

## User-visible outcome
A message sent to a device with no direct connection still arrives, routed
through whatever intermediate devices are available — invisibly to the user
beyond an (optional, one-tap-away per FR-UI-004) route detail view.

## Scope
**In scope**
- Multi-transport discovery (Bluetooth, Wi-Fi, Wi-Fi Direct, local network,
  Internet/peer-assisted) via the Pigeon-based native layer (ADR-0004)
- Store-and-forward relay (temporary encrypted-packet storage + forwarding)
- Route cost calculation and make-before-break migration
- Route-failure recovery (search alternatives, else queue/retry)

**Out of scope**
- The encrypted payload's contents/format (E03 owns encryption; this epic
  moves encrypted bytes)
- Message-level semantics — delivery states, dedup, ordering (E05)

## Data model
`routes` (candidate paths + measured cost factors), `relay_packets`
(id, destination, priority, size, created, expiry, delivery-state per
FR-ROUTE-004) — local only, ephemeral.

## API surface
Pigeon-generated Dart↔Kotlin bindings (ADR-0004) for transport control;
internal routing-engine interface consumed by E05/E06.

## Screens
| Screen | Route | Design contract | Task |
|---|---|---|---|
| Devices | /devices | `design/screens/devices.md` | nearby-device discovery list, connection status (shared with E02's trust UI — coordinate task-sharding to avoid duplicate work on the same screen) |

## Acceptance criteria (epic-level, EARS)
- **EARS-ROUTE-1**: The system SHALL support communication between two devices with no direct connection via one or more relays. (FR-ROUTE-001)
- **EARS-ROUTE-2**: WHEN migrating routes, the system SHALL establish and validate the new connection before terminating the old one (make-before-break). (FR-ROUTE-006)
- **EARS-ROUTE-3**: A relay device SHALL never gain access to plaintext content. (FR-ROUTE-003, depends on E03)
- **EARS-ROUTE-4**: WHEN a route fails, the system SHALL search for and migrate to an alternative, or queue/retry if none exists. (FR-ROUTE-009)

Cross-cutting: **NFR-SEC-001**, **NFR-REL-001**, **NFR-BATT-001** *(needs
number)* bind here.

## Tasks
<sharded by `skills/task-sharding` once this epic is approved>

## Test strategy
`FR-VER-004`'s testing/simulation framework requirement is arguably *this*
epic's own deliverable — task-sharding should treat "build the route/battery/
latency/partition simulator" as an early task here, since every later route
-behavior test depends on it existing.

## Risks
| Risk | Mitigation |
|------|-----------|
| Routing cost formula and migration threshold have no numbers (Q-ARCH-004, Q-FUNC-005) | Per your prior decision: task-sharding writes an explicit v1 weighted-sum heuristic + a fixed-percentage-plus-stability-window migration threshold, both flagged tunable placeholders — not blocking, but must be written down, not implicit in code |
| This is the single largest, most novel epic (BRD itself defers 30 technical topics touching this area) | Consider sub-sharding by transport (Bluetooth-only first, then Wi-Fi Direct, then Internet-assisted) rather than building all transports before anything works end to end |

## Open Questions
- **OQ-E04-1 — Routing cost formula (Q-ARCH-004).** Recommended default: weighted-sum per traffic-type profile (BRD §31's factor list), explicit placeholder weights, revisited once real usage data exists.
  - **Status:** 🟡 open
  - **Answer:** _<empty>_ — folds into this epic's task-sharding per prior human decision
  - **Answered by:** _<empty>_
  - **Date:** _<empty>_
- **OQ-E04-2 — Migration threshold (Q-FUNC-005).** Recommended default: fixed percentage improvement + minimum stability window, both placeholders.
  - **Status:** 🟡 open
  - **Answer:** _<empty>_ — folds into this epic's task-sharding per prior human decision
  - **Answered by:** _<empty>_
  - **Date:** _<empty>_

## Analyze report
<pending — appended once tasks are sharded>

## Retro
→ `retro.md` (written after E04 completion)
