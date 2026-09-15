---
id: E05
title: Messaging Reliability & Multi-Device Sync
status: done
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
- Offline outgoing queue (compose while offline → queued → sent once
  durably accepted into this device's local relay queue — per E05-B03,
  "sent" does not mean a route existed or the message left the device;
  that stronger meaning was corrected out of T02 §2)
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
*(`skills/task-sharding` §6, run 2026-08-27 against E05-T01/T02/T03/T04/T05)*

| Check | Result | Notes |
|---|---|---|
| EARS trace | ✅ pass | EARS-MSG-1/2/3/4 (epic-level) each covered: T02→MSG-1, T03→MSG-2/3, T05→MSG-4. Sub-ids for genuinely new scope (EARS-MSG-2a/2b for the state machine, EARS-MSG-5/6 for sync cursors) all trace to an FR id. |
| Contract sanity | ✅ pass | One shared `messages`/`delivery_states` schema (T01) consumed identically by T02/T03/T04, no two tasks redefine it. Per L-process-005 (this session's own retro lesson from E04-B03): explicitly checked whether the union of T01-T05 is *sufficient* for the epic's stated scope, not just non-contradictory — found two real gaps (prekey-bundle exchange, gap-fill protocol) and recorded them as Open Questions in T02/T04 rather than silently leaving them undiscoverable, per that lesson's own recommended fix. |
| Collision matrix | ✅ pass | T02 (`send_message_use_case.dart`), T03 (`receive_message_use_case.dart`), T04 (`sync_cursor_service.dart` + `sync_tables.dart`), T05 (`conflict_resolver.dart`) — four disjoint file sets, all depending on T01 only (or nothing, for T05). |
| Scope fences | ✅ pass | Every task's §4 is non-empty; T02/T03/T04 in particular are careful to name exactly what they don't build (ack protocol, gap-fill protocol, group/session models) rather than silently inventing partial versions. |
| MoSCoW inflation | ⚠️ exception, justified | 5/5 tasks `must` — same reasoning as E03/E04: T01 is a strict prerequisite for T02/T03/T04, and all four/five deliver only partial epic value alone (a message model with no send/receive path, or a resolver nothing calls yet). T05 is arguably independently shippable (pure functions, no dependents in this epic) but is `must` because FR-MSG-007 is itself a `must` requirement, not because of scheduling — genuine `must`, not inflation. |
| Size | ✅ pass | T01 `M`, T02 `M`, T03 `M`, T04 `M`, T05 `S` — none `L`. |
| Design | ✅ pass (n/a) | No `layer: frontend` tasks; `design_contract: n/a` on all five, consistent with epic.md's "Screens: None." |

**Net:** 6/7 clean pass, 1 flagged exception (MoSCoW) with the same
justification pattern as E03/E04. Two honest scope gaps surfaced as
task-level Open Questions rather than left silently undiscoverable —
direct application of this session's own E04-B03 retro lesson
(L-process-005).

🧍 **HUMAN GATE** (`analyze_report`): 6/7 clean, 1 disclosed MoSCoW
exception, 2 honest scope gaps recorded as task-level Open Questions.
Proceeding to dispatch under the human's standing instruction to continue
through E14 without per-gate pauses — findings stand as written above for
audit, nothing re-graded silently to force a clean pass.

## Bug sweep
Run 2026-08-29 (`skills/bug-sweep`, Opus, against `epic_05` @ `af86907`
with all 5 tasks done). Baseline verified by the reviewer, not taken from
the PR bodies: `flutter analyze` → 0 issues; `flutter test` → **245/245
pass**.

**3 real findings, all open — P1/P2 not yet zero, so the epic→development
PR does not open yet** (`skills/release` gate). Priorities are `TBD-human`
(🧍 `bug_priorities`, rule 3); severities below are the reviewer's.

| Bug | Sev | What |
|---|---|---|
| E05-B01 | S2 | The wire envelope has a consumer but no producer — T02 encrypts raw plaintext, T03 deserializes a `MessageEnvelope` from it. No message this epic sends is receivable by this epic's receiver (reviewer probe: `FormatException`). EARS-MSG-2/3 are proven only against test-fabricated envelopes. |
| E05-B02 | S2 | Nothing calls `RelayEngine.processQueue()`/`sweepExpired()`/`reclaimPayloads()`. EARS-MSG-1's "and send once a route is available" half has no mechanism; E04-B02's retention guarantee, explicitly handed to E05 at E04's merge gate, is still unscheduled. |
| E05-B03 | S3 | `Sent` is applied on a bare INSERT that cannot fail, contradicting T02 §2's own definition; a message reads `Sent` with no radio or route, and the `Failed` branch is unreachable in production. |

E05-B01 and E05-B02 share one root cause — the epic delivered five correct
components and no composition layer, and no task's `files:` fence contained
the wiring. Fix E05-B01 before E05-B02.

**Confirmed non-issues** (checked, with reasoning, so they are not
re-litigated): the `delivery_states` orphan table (no E05 EARS requires
transition-history rows; T01 §3 scoped it conditionally — correctly
deferred); OQ-E05-T04-1, the missing gap-fill protocol (nothing in T01–T05
depends on it; genuinely epic-external, carry forward as a documented Open
Question, not a gate); the v10→v11→v12 migration sequence (additive and
disjoint, and drift's `createTable` emits `CREATE TABLE IF NOT EXISTS`
(`drift-2.34.3/lib/src/runtime/query_builder/migration.dart:319`) so the
unwrapped multi-statement v11 step is retry-safe — E04-B02's brick scenario
does not apply); the T02 crash-between-`enqueue`-and-`Sent` window (the
relay packet is already durably enqueued, so nothing is lost and nothing
double-sends — a stale label, not a dangling state); and
`ConflictResolver.resolveTrust`'s "unknown pulls down trusted" ratchet
(nothing calls `ConflictResolver` in this epic, so it is unreachable today —
a real seam for whoever wires it, recorded in `tracker.md`, not a defect
now).

## Retro
→ `retro.md` (written 2026-08-29). Four promotions proposed, 🧍
`retro_promotions` ✅ approved by the human, 2026-09-03 (recorded at the E08 retro and in each lesson's status line; this line updated 2026-09-16): L-backend-003 rule extended
(`skills/implement` §6, writer-side atomicity), L-process-006 +
L-process-007 promoted to rules (`skills/task-sharding` §0 and two new
Analyze-gate rows), L-qa-001 promoted to a rule (`skills/review` §2).
One red carry-forward: E04-B03's link-quality wiring was never picked up by
E05 and is still unwired.
