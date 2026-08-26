---
id: E06
title: Personal Chat
status: todo
type: feature
priority: { moscow: must, wsjf: 4.2 }
depends_on: [E02, E03, E04, E05]
traces_to: [FR-COMM-001]
external_services: []
ui_surface: [mobile]
design_screens: [dashboard, conversations, chat]
---
# E06 · Personal Chat ★ (the wedge)

## Business goal
**This is the epic that makes NEXORA worth using.** Two people exchange
text, voice messages, PTT, attachments, and location — encrypted, routed
over whatever transport is available, working offline — end to end, for
real, replacing genesis's stub with the actual product.

## User-visible outcome
A user opens a conversation, sends a message to a trusted/allowed contact,
and it arrives — even if that contact isn't directly reachable, even if the
sender is offline when they compose it. This is the first fully-real user
journey in the app.

## Scope
**In scope**
- Text messaging (1:1) — the minimum real wedge
- Voice messages, PTT, attachments, location-in-chat (FR-COMM-001's full
  scope) — may be sub-sharded into their own tasks/waves within this epic
  if text-first proves out faster feedback
- Dashboard, Conversations list, and Chat screens, wired to real data
  (E02 trust states gate who appears, E03 encrypts, E04 routes, E05
  guarantees delivery semantics)

**Out of scope**
- Group chat (E07)
- Voice/video calls (E07)
- Storage management UI (E08) — messages just accumulate for now

## Data model
Consumes E05's `messages`/`delivery_states` tables directly; no new tables
beyond what a UI needs (e.g. a `conversations` view/index for the list
screen) — task-sharding decides.

## API surface
None new — this epic is the presentation + orchestration layer over
E02–E05's data/domain layers.

## Screens
| Screen | Route | Design contract | Task |
|---|---|---|---|
| Dashboard | /dashboard | `design/screens/dashboard.md` | connectivity status, entry point |
| Conversations | /conversations | `design/screens/conversations.md` | Personal/Groups list (Personal populated here; Groups stays empty until E07) |
| Chat | /chat/:id | `design/screens/chat.md` | the actual conversation view |

**Gaps:** the Conversations screen's "Groups" tab will show an empty state
this epic doesn't populate — that's a real gap (design shows content, this
epic doesn't build groups yet). Log it in `design/gaps.md` at task-sharding,
traced to `FR-GROUP-*`, with `status: deferred` until E07.

## Acceptance criteria (epic-level, EARS)
- **EARS-COMM-1**: The system SHALL support sending/receiving text, voice messages, PTT, attachments, and location in a 1:1 conversation. (FR-COMM-001)
- **EARS-COMM-2**: The default view SHALL communicate connectivity simply ("You're connected"); route/transport detail SHALL be one tap away. (FR-UI-004)

Cross-cutting: **NFR-PERF-001** *(needs number)*, **NFR-BATT-001** *(needs
number)* bind here — chat is where responsiveness matters most to a user.

## Tasks
<sharded by `skills/task-sharding` once this epic is approved>

## Test strategy
End-to-end: two real (or emulated) devices, one sends a text message while
the other is offline, message queues, arrives on reconnect, decrypts
correctly, displays in order. This IS the epic's own proof — if this
journey doesn't work, nothing upstream mattered.

## Risks
| Risk | Mitigation |
|------|-----------|
| Largest UI surface of Wave 1 — three screens, real-time updates | Sub-shard text-only first; voice/PTT/attachments/location as follow-on tasks within the epic rather than one giant task |
| First epic to actually need the Flutter-capable design-fidelity gate (OQ-E00-3) | Build that gate as this epic's first or second task, not as an afterthought — every screen after this inherits it |

## Open Questions
_(none new beyond OQ-E00-3, tracked at genesis level)_

## Analyze report
<pending — appended once tasks are sharded>

## Retro
→ `retro.md` (written after E06 completion)
