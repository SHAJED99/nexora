---
id: E04
title: Mesh Discovery, Relay & Dynamic Routing
status: build-complete
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

"Ephemeral" (E04-B02) means, precisely: the `payload` BLOB — the other
party's ciphertext this device is temporarily holding as a relay hop — is
reclaimed (nulled, schema v10, `payload` nullable) the instant a row in a
terminal state (`forwarding` / `delivered` / `expired`) is past its own
`expires_at`, via `RelayEngine.reclaimPayloads()`. No additional grace
period beyond the packet's original TTL: the TTL passed to `enqueue()` is
already the caller's "how long is this worth keeping" signal. A `queued`
row's payload is never touched by this pass, only its state (see
`sweepExpired()`). The row itself — id, destination, size, timestamps,
state — is kept indefinitely, independent of the payload, for a later
epic's diagnostics needs (E13, T04 §3); only the ciphertext bytes are
time-bound.

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
  - **Status:** ✅ resolved (folded into task-sharding, per the prior human
    decision recorded here at genesis: use the recommended default)
  - **Answer:** v1 weighted-sum heuristic: `cost = w1*latency_ms +
    w2*(1-reliability) + w3*battery_drain_rate + w4*hop_count`, with two
    named weight profiles (`interactive` for 1:1 chat — latency-weighted;
    `bulk` for large transfers — reliability/battery-weighted). Exact
    starting weights are a task-sharding implementation detail (placeholder,
    explicitly flagged tunable in code, not a second foundational decision).
  - **Answered by:** human (genesis-era decision, applied here 2026-08-27)
  - **Date:** 2026-08-27
- **OQ-E04-2 — Migration threshold (Q-FUNC-005).** Recommended default: fixed percentage improvement + minimum stability window, both placeholders.
  - **Status:** ✅ resolved (folded into task-sharding, per the prior human
    decision recorded here at genesis: use the recommended default)
  - **Answer:** Migrate only when a candidate route's cost is ≥20% better
    AND has held that advantage for ≥10 consecutive samples (stability
    window) — both named constants, explicitly flagged tunable.
  - **Answered by:** human (genesis-era decision, applied here 2026-08-27)
  - **Date:** 2026-08-27

## Analyze report
*(`skills/task-sharding` §6, run 2026-08-27 against E04-T01/T02/T03a/T03b/T03c/T04/T05)*

| Check | Result | Notes |
|---|---|---|
| EARS trace | ✅ pass | EARS-ROUTE-1/2/3/4 (epic-level) each covered: T02→ROUTE-1/2/4, T04→ROUTE-3/4b. New sub-ids introduced for genuinely new scope not named at epic level (EARS-SIM-1/2/3 for the simulator, EARS-TRANSPORT-1/2/3 for the Pigeon boundary, EARS-DISC-1/2 for Bluetooth, EARS-DEV-3/4 for the screen) — all trace to an FR id, none orphaned. |
| Contract sanity | ✅ pass, qualified 2026-08-27 (E04-B03) | One Pigeon schema (T03a) defines the transport boundary once; T03b/T03c extend its *implementation*, never redefine the contract. No two tasks define the same table/function differently — `routes` (T02) and `relay_packets` (T04) are disjoint tables. **Qualification:** this held for the tasks in scope when the report ran, but the end-of-epic bug sweep (E04-B03) found the contract itself was incomplete — no task had added a link-quality signal (RSSI/latency/loss) to the schema, so `RoutingEngine` had no production populator. The human approved extending the schema (2026-08-27) to close the gap; see §Carry-forward below. The claim "T03b/T03c never redefine the contract" is accurate for those two tasks specifically — it was E04-B03, not a T03b/T03c task, that extended the schema, and it did so with human sign-off as an explicit ADR-0004 boundary change, not a silent redefinition. |
| Collision matrix | ✅ pass | T01/T03a share no files (checked). T02/T03b share no files (T02 is pure Dart routing_engine + persistence; T03b is native Kotlin only). T03c only touches files T03a created/T03b will have already modified, strictly sequential via `depends_on`. T05 touches only `devices_controller.dart` + its test, untouched by any other E04 task. |
| Scope fences | ✅ pass | Every task's §4 is non-empty; T03a/T03b/T03c in particular are careful to state exactly what stays loopback/unimplemented at each stage — the most collision-prone three-way split in this epic. |
| MoSCoW inflation | ⚠️ exception, justified | 7/7 tasks `must` — same reasoning as E03: this is infrastructure with a strict dependency chain (simulator→routing engine→relay; Pigeon plumbing→discovery→data transfer→relay) and no task is independently shippable value on its own. Flagged, not silently re-graded. |
| Size | ✅ pass | T01 `S`, T02 `M`, T03a `M`, T03b `M`, T03c `S`, T04 `M`, T05 `S` — none `L`. T03 was originally sized `L` as a single "Bluetooth transport" task and explicitly split into three per this epic's own risk-mitigation note before this report ran — the split itself is evidence the sizing discipline worked, not a violation. |
| Design | ✅ pass | Only T05 is `layer: frontend`; `design_contract: design/screens/devices.md` — the contract already exists (E02-T02) and is approved. T01-T04 are `n/a`, consistent with backend/cross-cutting scope. |

**Net:** 6/7 clean pass, 1 flagged exception (MoSCoW), same shape and same
reasoning as E03's — infrastructure epics with a strict linear/near-linear
dependency chain legitimately have no optional slice to re-grade against.

**Notable, disclosed upfront:** T03b and T03c cannot be meaningfully proven
by `flutter test` — both task files say so explicitly and make honest
on-device manual verification (with a disclosed coverage gap if only one
Bluetooth-capable device is available) part of their Definition of Done,
rather than fabricating a hardware mock that would pass regardless of
correctness.

🧍 **HUMAN GATE** (`analyze_report`): 6/7 clean, 1 disclosed MoSCoW
exception (reasoning above), 0 unclassified findings, 0 collisions.
Proceeding to dispatch under the human's standing instruction to continue
through E14 without per-gate pauses — full findings stand as written above
for later audit, nothing re-graded silently to force a clean pass.

## Carry-forward

- **E04-B03 — link-quality measurement is contract-only, not wired.**
  `pigeons/transport.dart` now declares `TransportDevice.rssi` (nullable
  `int`) and `TransportEventsApi.onLinkQuality(deviceId, latencyMs,
  lossRate)` (human-approved ADR-0004 boundary extension, 2026-08-27), so
  `RoutingEngine.recordLinkMeasurement`
  (`lib/core/routing_engine/routing_engine.dart:141-155`) has a stable
  production event to consume once something calls it. **Nothing does yet.**
  No native Kotlin implementation populates `rssi` or emits
  `onLinkQuality`, and no Dart caller invokes
  `recordLinkMeasurement`. This blocks the routing engine from computing
  real routes on-device — `computeRoute()` returns `null` for every
  destination until this is wired (`RelayEngine` then queues every packet
  until it expires). **Blocked FRs:** FR-ROUTE-001, FR-ROUTE-002.
  **Owning epic: E05** — measuring real Android Bluetooth RSSI / round-trip
  latency, emitting them across the now-extended contract, and calling
  `RoutingEngine.recordLinkMeasurement` from the Dart side. Do not
  synthesize placeholder measurement values to make the engine appear live
  before that wiring lands — an honest `null` route beats a confident route
  computed from invented data.

## Retro
→ `retro.md` (written after E04 completion)
