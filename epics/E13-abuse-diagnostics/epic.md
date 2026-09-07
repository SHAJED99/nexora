---
id: E13
title: Abuse Prevention & Diagnostics
status: done (2026-09-07; 7/7 tasks done, 3/3 bugs closed, P1/P2=0 — merged into development)
type: feature
priority: { moscow: should, wsjf: 4.0 }
depends_on: [E06]
traces_to: [FR-ABUSE-001, FR-DIAG-001, FR-DIAG-002]
external_services: []
ui_surface: []
design_screens: []
---
# E13 · Abuse Prevention & Diagnostics

## Business goal
Harden a working system against connection-request spam, message flooding,
relay abuse, storage exhaustion, group-invite spam, device-registration
abuse, and battery/network-exhaustion attacks — plus real, privacy-safe
diagnostics for the team once real usage exists.

## Scope
**In scope:** rate-limiting/abuse controls per FR-ABUSE-001's list; real
observability wiring (ADR-0006 — replacing genesis's console-log stub with
the actual Sentry-or-equivalent client), strictly bounded by FR-DIAG-002's
"never log X" list.
**Out of scope:** the crypto/protocol-level threat protections already
covered by E03 (FR-SEC-003) — this epic is policy/rate-limiting, not
protocol security.

## Acceptance criteria (epic-level, EARS)
- **EARS-DIAG-1**: The system SHALL never log message plaintext, private/session keys, voice content, or sensitive personal/location data. (FR-DIAG-002 — non-negotiable, testable by log-content review)

## Tasks
6 tasks, sharded 2026-09-05 — see `tracker.md`.

| Task | Title |
|---|---|
| E13-T01 | Generic rate-limiter primitive (fixed-window counter, Drift-backed) |
| E13-T02 | Rate-limit connection-request spam and device-registration abuse |
| E13-T03 | Rate-limit message flooding and relay abuse at RelayEngine admission |
| E13-T04 | Rate-limit group-invitation spam |
| E13-T05 | Byte-volume admission control against storage-exhausting inbound data |
| E13-T06 | Real observability client (Sentry-or-equivalent) replacing the console-log stub |
| E13-T07 | Wire the rate limiter into production — filed 2026-09-05 out of T02's own review finding (P1) |

## Bug sweep (2026-09-06)

Run per `skills/bug-sweep` by an independent cross-model reviewer against
`origin/epic_13` @ `b5c3f99` in an isolated worktree. Full suite
1187/1187 green; `flutter analyze` clean. Two findings, **zero S1, zero
S2 — P1/P2 = 0**:

| Bug | Severity | Summary |
|---|---|---|
| `E13-B01` | S3 | `RateLimiter.allow`'s eviction runs an unindexed full-table DELETE on every admission decision; per-call cost grows linearly with an attacker-growable table (measured 0.28ms → 1.31ms/call from 10k → 50k rows). T01/T07 seam. Also corrects `OQ-E13-T01-1` from "resolved" to "bounded to a rolling 2 days". |
| `E13-B02` | S4 | T06 changed the observability sink from a debug-console stub to real third-party egress without re-auditing the pre-existing `cause:` payloads; `device_directory_service.dart:274` interpolates a device id into a message Sentry captures verbatim (currently unreachable — that service is never constructed). Rate-limit denials themselves were checked and leak nothing. |

🧍 **HUMAN GATE** (`bug_priorities`): cleared — `E13-B01` (S3/P2) and
`E13-B02` (S4/P4) both fixed, reviewed, merged into `development`.
`E13-B03` (re-scoped down from `E13-B02`'s own review, S4/P3) is also
fixed and merged (PR #158) — see `tracker.md`'s header. **E13 has zero
open bugs.**

## Open Questions
None new at the epic level (each task's own Open Questions section, if
any, is scoped to that task — see `E13-T01`'s stale-counter-row cleanup
and `E13-T05`'s admission-call-site confirmation).

## Analyze report / Retro

### ANALYZE REPORT (2026-09-05)

| Check | Result |
|---|---|
| **EARS trace** | PASS. `FR-ABUSE-001` → `EARS-ABUSE-1`..`11` across T01-T05. `FR-DIAG-001`/`FR-DIAG-002` → `EARS-DIAG-1`..`3` on T06, including the epic-level `EARS-DIAG-1` (§Acceptance criteria above), which T06 explicitly claims as its own testable criterion. No orphans either direction. |
| **Contract sanity** | PASS (vacuous) — no API/list endpoints in this epic; every task is internal backend wiring. |
| **Collision matrix** | PASS, empty. Only `T03`/`T05` share a file (`lib/core/routing_engine/relay_engine.dart`); serialized via `T05`'s `depends_on: [E13-T01, E13-T03]`, never a parallel-edit collision. Every other task pair touches disjoint files. |
| **Scope fences** | PASS. Every task's §4 is non-empty and names concrete tempting-but-wrong moves (e.g. T02: don't invent a Firebase-side registration control; T03: don't fold group-frame handling in; T05: don't duplicate T03's count check). |
| **MoSCoW inflation** | PASS. 1/6 `must` (T01, the shared primitive everything else depends on) = 17%, well under 60%. |
| **Size** | PASS. Five `S` tasks, one `M` (T06, the observability vendor integration). No `L`. |
| **Design** | PASS (n/a). `ui_surface: []` — no frontend task, no `design_contract:` needed. |
| **Obligation ownership** | PASS. T05 names T03 in prose (its own dependency on T03's call site already existing) but T05's own contract independently states its own obligation (the byte-volume check) rather than describing something T03 is supposed to do on T05's behalf — no orphaned obligation. |
| **Inherited obligations** | PASS, nothing to carry. `depends_on: [E06]` — searched `epics/E06-personal-chat/retro.md` §Open follow-ups and every `E06` task/bug file for any mention of E13/abuse/diagnostics: none found. |

**Human note on scope**: `E12` and `E14` were NOT sharded in this same
pass despite being the other two `todo` (Wave 2+) epics, because both
declare `ui_surface: [mobile]` with `design_screens: []` — no design
contract exists for either, and rule 2 requires a human-approved
`design/gaps.md` entry before any derived UI element is built; the
task-sharding skill's own precondition explicitly blocks sharding a
frontend task without one. `E13` has `ui_surface: []` (no UI at all), so
it carries no such blocker and was sharded first. `E12`/`E14`'s
backend-only slices (if any exist once examined) remain unsharded
pending this same design-fidelity gap process, or a human decision to
proceed differently.

🧍 **HUMAN GATE** (`analyze_report`): pending. Approval unlocks dispatch.
