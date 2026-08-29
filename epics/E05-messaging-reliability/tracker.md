# E05 · Messaging Reliability & Multi-Device Sync · Progress

**Status:** in-progress · **Started:** 2026-08-29 · **Completed:** — · **Progress:** 1/5

> Only the ORCHESTRATOR edits this file.

## Tasks
- [ ] E05-T01 · Message domain model + delivery-state machine + tables · changes-requested (round 1: index missing on upgrade migration) · builder (sonnet) → reviewer (opus)
- [ ] E05-T02 · Offline outgoing message queue · todo · builder (sonnet) → reviewer (opus)
- [ ] E05-T03 · Incoming message handling (dedup, ordering) · todo · builder (sonnet) → reviewer (opus)
- [ ] E05-T04 · Multi-device sync cursors · todo · builder (sonnet) → reviewer (opus)
- [x] E05-T05 · Conflict resolution (security-restrictive precedence) · done · builder (sonnet) → reviewer (opus) APPROVE, squash-merged af86907

## Dependency graph
```mermaid
graph LR
  T01[E05-T01] --> T02[E05-T02]
  T01 --> T03[E05-T03]
  T01 --> T04[E05-T04]
  T05[E05-T05]
```
T02/T03/T04 all depend only on T01 and touch disjoint files (`domain/
send_message_use_case.dart` vs `domain/receive_message_use_case.dart` vs
`persistence/sync_tables.dart` + `domain/sync_cursor_service.dart`) — safe
to dispatch in parallel once T01 lands. T05 has no dependencies at all
(pure functions over E02's existing `RelationshipState`) — safe to
dispatch immediately, in parallel with T01.

## Review log
(none yet)

## Blocked / Frozen
(none)

## Event log (append-only)
- 2026-08-29 E05-T05 built (builder-sonnet), reviewed APPROVE (reviewer-opus,
  independent verification of RelationshipState ordering against
  relationship.dart + FR-TRUST-004), squash-merged to epic_05 (af86907).
- 2026-08-29 E05-T01 built (builder-sonnet, resumed from an interrupted
  prior session), 180/180 tests, status review-requested; independent
  opus review found a real blocker (round 1, CHANGES): the v10->v11
  migration's createTable() does not also create the declared
  idx_messages_conversation_created_at index (drift only does this via
  createAll() on fresh installs) -- upgrading installs silently get no
  index on the keyset-paginated messages query. Fix dispatched to
  builder-sonnet.
- 2026-08-27 E05 sharded into 5 tasks (task-sharding skill). No epic-level
  Open Questions blocked sharding, but two task-level Open Questions were
  surfaced and left open rather than guessed at: OQ-E05-T02-1 (no
  prekey-bundle exchange mechanism exists anywhere yet — E01-E04 never
  built one, so real end-to-end sending is impossible until it's answered,
  likely E06's problem) and OQ-E05-T04-1 (the gap-fill protocol for
  multi-device sync isn't built — this epic only produces the cursor data
  such a mechanism would need). Both are honest scope boundaries, not
  blockers to sharding these 5 tasks, which are each independently
  buildable and testable without either gap being closed.
