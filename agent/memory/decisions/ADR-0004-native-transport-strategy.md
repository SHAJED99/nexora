---
status: accepted
date: 2026-08-26
proposed_by: claude-code (genesis T01)
decided_by: human, 2026-08-26
traces_to: [FR-DISC-001, FR-DISC-003, FR-PLAT-001, FR-PLAT-003, FR-ROUTE-001]
---

# ADR-0004 — Native transport integration strategy

## Context
FR-PLAT-003 already fixes the *shape* — Android-native components handle
Bluetooth/Wi-Fi/nearby-device system access, Flutter talks to them through
defined interfaces. What's open is *how* Flutter and the native layer
communicate for what is, functionally, the most performance- and
reliability-sensitive boundary in the app: continuous, low-latency,
multi-transport connection and data-transfer management running partly in
the background (FR-PLAT-001/002), directly feeding the route engine.

## Options considered
1. **Platform Channels (MethodChannel + EventChannel), hand-written Kotlin
   native layer** — pros: full control over Bluetooth/Wi-Fi Direct/BLE
   background behavior including Doze/Battery-Saver handling, no
   third-party plugin's abstractions or bugs in the critical path, direct
   access to Android's Nearby Connections API or raw Bluetooth/WiFi-Direct
   APIs as needed. cons: significant native Android engineering investment,
   Flutter/Kotlin boundary is hand-maintained code that must stay in sync
   as both layers evolve.
2. **Pigeon (type-safe codegen over Platform Channels)** — pros: same
   control as raw Platform Channels, but with generated, type-safe Dart↔
   Kotlin bindings instead of hand-written channel message parsing — removes
   a whole class of boundary bugs. cons: still requires the same amount of
   native Android engineering; codegen adds a build step.
3. **Existing community plugins (e.g. flutter_bluetooth_serial,
   nearby_connections wrappers, wifi_iot)** — pros: fastest to a working
   prototype, less code to write and maintain directly. cons: BRD's
   requirement that any transport can carry any communication type,
   evaluated continuously for routing cost, is a level of control most
   general-purpose plugins aren't built for; background-execution
   reliability (Doze/Battery-Saver interaction) is exactly where thin
   community plugins tend to be weakest; multiple different plugins would
   likely be needed for Bluetooth vs Wi-Fi Direct vs Nearby, each with its
   own quirks to reconcile inside one route engine.

## Comparison matrix
| Criterion | Platform Channels | Pigeon | Community plugins |
|---|---|---|---|
| Control over background/Doze behavior (FR-PLAT-002) | Full | Full | Limited, plugin-dependent |
| Boundary type-safety | Manual | Generated | Plugin-dependent |
| Fit to "any transport, any type, cost-evaluated continuously" | Strong | Strong | Weak (multiple disjoint plugins) |
| Speed to walking skeleton | Slower | Slower | Faster |
| Long-term maintenance burden | High (self-owned) | Moderate | Low, but capped by plugin limits |

## Agent recommendation (advisory — NOT the decision)
**Pigeon over hand-written native Kotlin.** The reliability and background-
execution control this domain needs (continuous multi-transport routing
decisions, Doze-aware background operation) argues strongly against thin
community plugins as the primary transport layer — this is core product
value, not a peripheral integration. Pigeon gets the same control as raw
Platform Channels while removing a real class of hand-written-boundary bugs.
Community plugins may still be worth using for narrow, well-solved pieces
(e.g. a permissions-request helper) without being the transport backbone.
Final call is yours.

## Decision
✅ Accepted — chosen option: **Pigeon (type-safe codegen over Platform
Channels)**, hand-written native Kotlin behind it.

## Consequences
- Dart↔Kotlin boundary for Bluetooth/Wi-Fi Direct/Nearby/background
  transport is defined via Pigeon schemas, generated on both sides.
- Full control over Doze/Battery-Saver-aware background behavior
  (FR-PLAT-002) stays in the native Android layer.
- Community plugins may still be used for narrow, well-solved pieces (e.g.
  permission-request helpers) but never as the transport backbone.
- `docs/conventions.md` (T02) will record where Pigeon schema files live
  and the regeneration workflow.
