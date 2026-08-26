---
id: E13
title: Abuse Prevention & Diagnostics
status: todo
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
<sharded when this epic's wave comes up>

## Open Questions
None new.

## Analyze report / Retro
<pending>
