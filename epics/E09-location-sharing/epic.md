---
id: E09
title: Location Sharing
status: todo
type: feature
priority: { moscow: could, wsjf: 3.7 }
depends_on: [E02, E03, E04]
traces_to: [FR-LOC-001, FR-LOC-002, FR-LOC-003, FR-LOC-004, FR-LOC-005]
external_services: []
ui_surface: [mobile]
design_screens: [settings]
---
# E09 · Location Sharing

## Business goal
Let users share live location with per-contact granularity, encrypted,
gated by connection + authorization + global + per-user toggles all
holding simultaneously.

## Scope
**In scope:** global + per-user toggles, the four-condition visibility gate
(connected AND authorized AND global-on AND per-user-on), encrypted location
data, last-known-location-with-timestamp fallback (never presented as live).
**Out of scope:** the UI screens showing another user's location on a map —
map-widget design isn't in the current design contracts; a gap-pass item
for this epic's task-sharding.

## Acceptance criteria (epic-level, EARS)
- **EARS-LOC-1**: The system SHALL show a user's location only when connected AND authorized AND global-sharing-on AND per-user-sharing-on ALL hold. (FR-LOC-003)
- **EARS-LOC-2**: IF live location is unavailable, THEN the system MAY show last-known location with a visible timestamp, and SHALL NOT present it as live. (FR-LOC-005)

## Tasks
<sharded when this epic's wave comes up>

## Open Questions
- **OQ-E09-1 — no map/location-display screen exists in the design contracts.** Needs a design gap entry (`design/gaps.md`) tracing to FR-LOC-* before this epic's UI tasks can be sharded.
  - **Status:** 🟡 open

## Analyze report / Retro
<pending>
