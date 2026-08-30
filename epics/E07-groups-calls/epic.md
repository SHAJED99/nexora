---
id: E07
title: Groups & Voice Calls
status: todo
type: feature
priority: { moscow: should, wsjf: 2.1 }
depends_on: [E06]
traces_to: [FR-COMM-001, FR-COMM-002, FR-GROUP-001, FR-GROUP-002, FR-GROUP-003, FR-GROUP-004, FR-GROUP-005, FR-GROUP-006, FR-CALL-001, FR-CALL-002, FR-CALL-003]
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
mid-call migration, **push-to-talk (PTT)** — re-homed here from E06 by human
decision on 2026-08-30 (`IMP-001`; see Open Questions) because PTT is a
half-duplex live-transport mode that shares this epic's real-time transport
problems and almost none of E06's async-messaging ones. Design it once
E07's voice-call transport question is settled, not before.
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
- **OQ-E07-2 — PTT (push-to-talk) re-homed here from E06.** E06-T13's design
  gap pass found PTT has no design source and no derivable primitive
  (`GAP-017` / `OQ-E06-T13-1` in E06). The human decided to park it until
  this epic's voice-call work settles the real-time transport question,
  then design PTT once against a transport that exists, via `IMP-001`. No
  contract exists yet; this epic's own task-sharding pass must carry it as
  a named obligation, not rediscover it — same failure shape as E05-B02's
  relay-queue handoff.
  - **Status:** 🟡 open (owner: this epic's sharding pass)
  - **Answered by:** human
  - **Date:** 2026-08-30

## Analyze report / Retro
<pending>
