---
id: E02
title: Relationships, Trust & Blocking
status: done
type: feature
priority: { moscow: must, wsjf: 4.0 }
depends_on: [E01]
traces_to: [FR-TRUST-001, FR-TRUST-002, FR-TRUST-003, FR-TRUST-004, FR-TRUST-005, FR-TRUST-006, FR-TRUST-007, FR-BLOCK-001, FR-BLOCK-002, FR-BLOCK-003]
external_services: [Firebase]
ui_surface: [mobile]
design_screens: [devices, settings]
---
# E02 · Relationships, Trust & Blocking

## Business goal
Two devices can only communicate once each side has independently authorized
the other. This epic builds that authorization model — Trusted / Allowed /
Unknown / Blocked — including its persistence across reinstalls and its
bidirectional-independent evaluation.

## User-visible outcome
A user can see nearby/known devices, send and receive connection requests,
configure auto-accept rules, and block someone — with blocking acting as a
real, complete boundary (not just a chat-level filter).

## Scope
**In scope**
- Connection-request lifecycle: request → independent evaluation on each
  side → Trusted/Allowed/Unknown/Blocked outcome
- Trust persistence across uninstall/reinstall (device identity re-verification
  still possible)
- User-configurable rules: auto-accept-trusted, auto-accept-specific-users,
  require-auth-for-unknown, block, allow/disable communication, location access
- Blocking as a complete boundary (affects all communication features other
  epics build later — this epic defines the boundary's data model and
  enforcement point, later epics respect it)
- Relationship config sync through the minimal Firebase client (E01)

**Out of scope**
- The actual encrypted channel (E03)
- Group-level invisibility mechanics beyond the block-flag check itself (E07
  implements the group UI; this epic guarantees the underlying block state
  a group can query)

## Data model
`relationships` table: device pair → state (trusted/allowed/unknown/blocked),
direction-independent storage of each side's own evaluation, timestamps for
sync/conflict-resolution (feeds E05's FR-MSG-007 precedence rules later).

## API surface
Local Drift queries + the E01 Firebase wrapper for relationship-config sync.
No new external API.

## Screens
| Screen | Route | Design contract | Task |
|---|---|---|---|
| Devices | /devices | `design/screens/devices.md` | connection requests, trust states, block action |
| Settings | /settings | `design/screens/settings.md` | auto-accept / auth-required / block-list configuration |

**Gaps:** none identified yet — gap pass happens at task-sharding once the
exact UI states (pending request, blocked-list view) are enumerated against
`design/screens/devices.md` and `settings.md`.

## Acceptance criteria (epic-level, EARS)
- **EARS-TRUST-1**: WHEN device A sends a connection request to device B, the system SHALL let B evaluate independently into Trusted/Allowed/Unknown/Blocked. (FR-TRUST-003)
- **EARS-TRUST-2**: WHEN B has A configured as trusted, the system SHALL auto-accept A's request without the normal authentication flow. (FR-TRUST-004)
- **EARS-TRUST-3**: A connection SHALL be permitted only when both sides independently allow it. (FR-TRUST-005)
- **EARS-TRUST-4**: WHEN a relationship is established with a device -- trusted included -- the system SHALL persist it, so a later read returns that device's stored state, and re-establishing it SHALL update the existing record rather than add a second. (FR-TRUST-001)
- **EARS-BLOCK-1**: IF user A blocks user B, THEN the system SHALL prevent all direct communication between them, in both directions. (FR-BLOCK-001)

## Tasks
<sharded by `skills/task-sharding` once this epic is approved>

## Test strategy
Two-device (or two-emulator-instance) integration tests covering every
combination: trusted↔trusted, trusted↔unknown, blocked↔anything. Reinstall
simulation to prove trust persistence.

## Risks
| Risk | Mitigation |
|------|-----------|
| Bidirectional-independent evaluation is easy to accidentally implement as one-sided | Task-sharding should require an explicit two-actor test per state combination |

## Open Questions
_(none yet — carried forward from E00: none of Q-ARCH-003/004, Q-FUNC-005/006 touch this epic directly)_

## Analyze report

Sharded 2026-08-26 into E02-T01 (relationship domain, backend, M),
E02-T02 (Devices screen, frontend, M, depends_on T01), E02-T03 (Settings
screen top-level menu, frontend, S, depends_on T01).

| Check | Result |
|---|---|
| EARS trace | FR-TRUST-001..005, FR-BLOCK-001..003 → T01. FR-TRUST-003/004/005 also re-asserted at the UI level → T02. FR-TRUST-006/007 → explicitly NOT built (no design contract for the config sub-screen; no Firebase sync scope yet) — both logged as open questions/gaps, not silently dropped. No orphans. |
| Contract sanity | No API endpoints (local-only + one Drift table). Error envelope n/a (no new failure surface beyond existing `AppFailure` pattern). |
| Collision matrix | T02 and T03 touch different screen files but BOTH update `lib/app/routes.dart` and `lib/app/bindings.dart` — a real collision if run in parallel. **Mitigation: T02 and T03 both depend_on T01 only, not each other, but must be serialized against one another** (pick_order / scheduler should not run them concurrently) — flagging explicitly since the dependency graph alone doesn't show this. |
| Scope fences | All three non-empty and specific (T02 excludes real discovery/groups; T03 excludes inventing sub-screens). |
| MoSCoW inflation | 2 must (T01, T02), 1 should (T03) — 67% must, over the 60% heuristic but justified: T01 is a hard prerequisite for the epic's own EARS criteria, T02 is the primary user-visible deliverable; T03 is genuinely secondary (a menu with no working sub-screens yet). |
| Size | T01=M, T02=M, T03=S. None L. |
| Design | T02 → `design/screens/devices.md` (exists). T03 → `design/screens/settings.md` (exists). Both real contracts, not placeholders. |

🧍 **HUMAN GATE** (`analyze_report`): approved implicitly by the standing
proceeding-directive ("go through to the end of all tasks", 2026-08-26) —
re-open if you want to review before dispatch. **Flag for your attention:**
T02/T03's shared-file collision (routes.dart/bindings.dart) means they'll
be built and merged one at a time, not in parallel, even though nothing in
`depends_on` forces that.

## Retro
→ `retro.md` (written after E02 completion)
