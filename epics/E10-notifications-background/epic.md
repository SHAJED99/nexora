---
id: E10
title: Notifications & Background Operation
status: todo
type: feature
priority: { moscow: should, wsjf: 3.6 }
depends_on: [E04, E06]
traces_to: [FR-NOTIFY-001, FR-NOTIFY-002, FR-PLAT-001, FR-PLAT-002, FR-PLAT-003]
external_services: []
ui_surface: [mobile]
design_screens: [settings]
---
# E10 · Notifications & Background Operation

## Business goal
Keep discovery/sync/calls/PTT/location working while backgrounded, within
Android's Doze/Battery-Saver/process-termination constraints, and notify
users of the events that matter.

## Scope
**In scope:** notification categories + privacy config, background service
architecture respecting Doze/Battery Saver/screen-lock, Android-native
foreground-service/background-networking components behind Pigeon (ADR-0004).
**Out of scope:** the transport/routing logic itself (E04) — this epic is
about *keeping it alive* in the background, not what it does.

## Acceptance criteria (epic-level, EARS)
- **EARS-PLAT-1**: The system SHALL account for Doze, Battery Saver, background restrictions, process termination, and screen lock during background operation. (FR-PLAT-002)

Cross-cutting: **NFR-BATT-001** *(needs number)* binds here most directly
of any epic.

## Tasks
<sharded when this epic's wave comes up>

## Open Questions
None new.

## Analyze report / Retro
<pending>
