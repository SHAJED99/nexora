---
id: E08
title: Local Storage & Management
status: todo
type: feature
priority: { moscow: should, wsjf: 3.0 }
depends_on: [E06]
traces_to: [FR-STORE-001, FR-STORE-002, FR-STORE-003, FR-STORE-004, FR-STORE-005, FR-STORE-006, FR-STORE-007]
external_services: []
ui_surface: [mobile]
design_screens: [dashboard, settings]
---
# E08 · Local Storage & Management

## Business goal
Give users control over local storage growth (voice/PTT/call recordings,
attachments, conversation history) via a default "Smart Mode" that explains
its own decisions, plus manual policies.

## User-visible outcome
Storage warnings on the dashboard, an explainable Smart Mode, and manual
delete-by-age/size policies.

## Scope
**In scope:** Smart Mode heuristic (age/size/type/access-frequency/activity/
pressure/temp-status/importance), manual policies, dashboard storage
warnings (informational only, no forced action), decision explanations.
**Out of scope:** anything about what's stored (E06/E07 own that) — this
epic only manages lifecycle.

## Acceptance criteria (epic-level, EARS)
- **EARS-STORE-1**: WHILE Smart Mode is active, the system SHALL determine removal candidates using the eight named factors. (FR-STORE-005)
- **EARS-STORE-2**: The dashboard SHALL show storage warnings as informational only, never requiring a "Clean Now" action. (FR-STORE-006)

Cross-cutting: **NFR-SCALE-001** *(needs number, A-002 placeholder)*,
**NFR-PRIV-001** bind here.

## Tasks
<sharded when this epic's wave comes up>

## Open Questions
None new.

## Analyze report / Retro
<pending>
