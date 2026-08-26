---
id: E12
title: Account Recovery & Device Enrollment
status: todo
type: feature
priority: { moscow: should, wsjf: 3.5 }
depends_on: [E01, E03]
traces_to: [FR-RECOVER-001, FR-RECOVER-002]
external_services: []
ui_surface: [mobile]
design_screens: []
---
# E12 · Account Recovery & Device Enrollment

## Business goal
Let a user add a new device authorized by an existing trusted device, and
be honest that losing all cryptographic keys means historical content is
gone by design — not a bug to be worked around.

## Scope
**In scope:** new-device enrollment flow vouched for by an existing trusted
device; explicit, clear "no recovery" messaging when all keys are lost.
**Out of scope:** any recovery mechanism that would contradict FR-RECOVER-002
— this must never be silently "solved" by weakening the security property.

## Acceptance criteria (epic-level, EARS)
- **EARS-RECOVER-1**: WHERE possible, an existing trusted device SHALL authorize a new device's enrollment. (FR-RECOVER-001)
- **EARS-RECOVER-2**: IF all cryptographic keys are permanently lost, THEN encrypted historical content SHALL NOT be recoverable. (FR-RECOVER-002 — intentional, not a defect)

## Tasks
<sharded when this epic's wave comes up>

## Open Questions
None new.

## Analyze report / Retro
<pending>
