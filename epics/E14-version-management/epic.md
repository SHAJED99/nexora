---
id: E14
title: Version & Update Management
status: todo
type: feature
priority: { moscow: should, wsjf: 2.75 }
depends_on: []
traces_to: [FR-VER-001, FR-VER-002, FR-VER-003, FR-VER-004, FR-VER-005, FR-VER-006, FR-VER-007, FR-VER-008, FR-VER-009, FR-VER-010, FR-VER-011]
external_services: [Google Play]
ui_surface: [mobile]
design_screens: []
---
# E14 · Version & Update Management

## Business goal
Version negotiation (app/build/protocol/crypto/db), a mandatory-update
enforcement mechanism via Google Play's in-app update API, and safe schema
migrations that never destroy local conversations.

## Scope
**In scope:** version-state machine (UP_TO_DATE/UPDATE_AVAILABLE/
UPDATE_REQUIRED), non-dismissible mandatory-update UI, cached/offline
policy evaluation, signed version policy, migration-safe app updates.
**Out of scope:** FR-VER-004's simulation-framework requirement — noted as
likely belonging inside E04 instead (see E04's Test strategy), since that's
where route/network simulation is actually useful; flag at task-sharding if
you'd rather it live here.

## Acceptance criteria (epic-level, EARS)
- **EARS-VER-1**: WHEN installed version is UPDATE_REQUIRED, the system SHALL block communication and present a non-dismissible mandatory update prompt via Google Play. (FR-VER-006)
- **EARS-VER-2**: Mandatory updates SHALL NOT delete local messages, recordings, attachments, settings, or history. (FR-VER-009)

## Tasks
<sharded when this epic's wave comes up>

## Open Questions
- **OQ-E14-1 — where does FR-VER-004's simulation framework actually live?** Candidate homes: this epic (its own FR id) or E04 (where it's actually useful). Needs a human call at task-sharding time, not a silent pick.
  - **Status:** 🟡 open

## Analyze report / Retro
<pending>
