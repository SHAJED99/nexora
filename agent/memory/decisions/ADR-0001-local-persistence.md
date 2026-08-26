---
status: accepted
date: 2026-08-26
proposed_by: claude-code (genesis T01)
decided_by: human, 2026-08-26
traces_to: [FR-STORE-001, FR-STORE-002, FR-MSG-001, docs/domain/entities.md]
---

# ADR-0001 — Local persistence layer

## Context
NEXORA is offline-first by constitution (constitution.md §1) — the entire
app must function with zero connectivity, meaning **local storage is the
primary datastore**, not a cache in front of a server. It needs to hold:
conversations, messages (incl. large binary voice/attachment data),
delivery-state machines, relationship/trust state, an outgoing message queue,
group membership + rotating encryption keys, and relay-hop metadata for
in-transit packets. BRD §16-22 requires structured storage-management
policies (Smart Mode) that need to query by age/size/type/access-frequency —
this needs to be genuinely queryable, not just a key-value blob store.
Flutter is the fixed framework (BRD header); the database choice is
explicitly BRD's to defer (§66.2).

## Options considered
1. **Drift (SQLite, type-safe Dart ORM)** — pros: compile-time-checked SQL,
   real relational queries (needed for Smart Mode's multi-factor filtering),
   mature migration tooling, large Flutter community, works offline
   trivially since SQLite is embedded. cons: schema migrations need care
   given FR-VER-003's "must not destroy local conversations" constraint;
   more boilerplate than a NoSQL object store for simple key-value data.
2. **Isar** — pros: fast, NoSQL-style but with real indexes/queries, decent
   Flutter-native ergonomics, async by default. cons: newer/smaller
   ecosystem than SQLite-based options, migration tooling less mature, long-
   term maintenance status less certain than SQLite (a 30-year-old format).
3. **Hive** — pros: very fast, very simple key-value/box model, minimal
   boilerplate. cons: not genuinely queryable — Smart Mode's storage-policy
   logic (filter by age AND size AND type AND access-frequency) would need
   to be implemented in application code scanning boxes, not the database;
   weak for the relational shape of conversations→messages→attachments.
4. **sqflite (raw SQLite, no ORM)** — pros: maximum control, zero
   abstraction tax. cons: hand-written SQL and migrations for a schema this
   size (7+ entity types) is significant ongoing toil with no compile-time
   safety.

## Comparison matrix
| Criterion | Drift | Isar | Hive | sqflite |
|---|---|---|---|---|
| Queryability for Smart Mode (multi-factor filter) | Strong | Strong | Weak | Strong (manual) |
| Migration safety (FR-VER-003) | Strong (tooling) | Moderate | Weak (no schema) | Manual, error-prone |
| Offline-first fit | Native (embedded) | Native (embedded) | Native (embedded) | Native (embedded) |
| Ecosystem maturity | High (SQLite-based) | Moderate | High | High |
| Boilerplate / dev speed | Moderate | Low | Very low | High |

## Agent recommendation (advisory — NOT the decision)
**Drift.** Smart Mode's storage policy is a genuinely relational,
multi-factor query problem, not a key-value lookup — SQLite's query engine
handles that naturally, and Drift adds compile-time safety plus mature
migration tooling that directly serves FR-VER-003's "must not destroy local
conversations across updates" requirement. Final call is yours.

## Decision
✅ Accepted — chosen option: **Drift (SQLite, type-safe Dart ORM)**.

## Consequences
- All local persistence (conversations, messages, attachments metadata,
  delivery-state, trust/relationship state, outgoing queue, group membership
  + rotating keys, relay-hop metadata) is modeled as Drift tables with
  compile-time-checked queries.
- Smart Mode's multi-factor storage policy (age/size/type/access-frequency)
  is implemented as real SQL queries, not application-level box scans.
- Schema migrations use Drift's migration tooling; FR-VER-003 ("must not
  destroy local conversations across updates") is enforced via versioned,
  tested migration steps.
- `docs/conventions.md` (T02) will record the schema-migration convention.
