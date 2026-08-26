---
id: E07
title: Groups & Voice Calls
status: todo
type: feature
priority: { moscow: should, wsjf: 2.1 }
depends_on: [E06]
traces_to: [FR-COMM-002, FR-GROUP-001, FR-GROUP-002, FR-GROUP-003, FR-GROUP-004, FR-GROUP-005, FR-GROUP-006, FR-CALL-001, FR-CALL-002, FR-CALL-003]
external_services: []
ui_surface: [mobile]
design_screens: [conversations, chat]
---
# E07 · Groups & Voice Calls

## Business goal
Extends E06's proven 1:1 chat to groups (Owner/Admin/Member roles, key
rotation on membership change) and adds secure voice calls over the same
routing architecture, with priority and mid-call migration.

## User-visible outcome
A user creates/joins a group and communicates with it; a user places a
voice call that survives a route change without dropping.

## Scope
**In scope:** group roles/management, group key rotation (Sender-Keys layer
on E03's protocol), the group-chat UI (Conversations "Groups" tab, per E06's
deferred gap), voice calls with routing priority and make-before-break
mid-call migration.
**Out of scope:** anything E06 already delivers for 1:1.

## Data model / API surface / Screens
Deferred to this epic's own task-sharding pass — see `spec/srs.md`
FR-GROUP-*/FR-CALL-* and `spec/feature-list.md`'s Personal & Group
Communication module for full detail.

## Acceptance criteria (epic-level, EARS)
- **EARS-GROUP-1**: WHEN group membership changes, the system SHALL rotate the group's encryption keys. (FR-GROUP-004)
- **EARS-GROUP-2**: A newly added member SHALL NOT automatically gain access to historical group communication. (FR-GROUP-006 — v1 default per Q-FUNC-006: no exception path exists)
- **EARS-CALL-1**: WHEN a better route becomes available mid-call, the system SHALL migrate without dropping the call (make-before-break). (FR-CALL-003)

## Tasks
<sharded when this epic's wave comes up>

## Risks
| Risk | Mitigation |
|------|-----------|
| Group key rotation is genuinely hard on top of a 1:1-first crypto layer (E03) | Confirm E03's Sender-Keys layering plan (see E03's OQ) before sharding this epic, not after |

## Open Questions
- **OQ-E07-1 — Q-FUNC-006 default confirmed.** Per prior human decision: v1 has no mechanism for granting a re-added member historical access. Carried here for task-sharding to encode explicitly, not re-litigate.
  - **Status:** ⚪ deferred (decided)
  - **Answered by:** human (via Q&A during genesis)
  - **Date:** 2026-08-26

## Analyze report / Retro
<pending>
