---
id: E11
title: Firebase Metadata Sync
status: todo
type: feature
priority: { moscow: should, wsjf: 3.5 }
depends_on: [E01, E02]
traces_to: [FR-FB-001, FR-FB-002]
external_services: [Firebase]
ui_surface: []
design_screens: []
---
# E11 · Firebase Metadata Sync

## Business goal
The full Firebase data-boundary implementation — everything Firebase *may*
store (auth, identity, device registry, trust/block metadata, config,
revocation, push info, version policy) and the hard boundary of what it
*must never* store (plaintext, recordings, keys, permanent location).

## Scope
**In scope:** the complete boundary-respecting Firestore/Realtime-DB schema,
revocation propagation, push-notification token registry, version-policy
delivery. E01/E02 already carved out a *minimal* slice of this (auth +
basic trust-config sync) during Wave 1 — this epic completes the rest and
should reconcile with whatever minimal wrapper E01 built rather than
replacing it wholesale.

## Acceptance criteria (epic-level, EARS)
- **EARS-FB-1**: Firebase SHALL NOT store message plaintext, voice/call recordings, private/session keys, or permanent private location history. (FR-FB-002) — this is the epic's non-negotiable constraint, testable by schema review.

## Tasks
<sharded when this epic's wave comes up>

## Risks
| Risk | Mitigation |
|------|-----------|
| Divergence from E01's minimal wrapper (built earlier, different task, different context) | This epic's first task should be a reconciliation pass reading E01's actual implementation before extending it |

## Open Questions
None new.

## Analyze report / Retro
<pending>
