# E03 · E2E Encryption & Threat Protection — Retro

**Date:** 2026-08-27 · **Epic status:** done, pending merge to `main`

## What shipped
The real Signal protocol stack: `libsignal_protocol_dart`-backed persistent
identity/prekey/session stores (T01), durable remote-peer identity trust
across restarts (T01b, closing a spec gap T01's own review found), local
identity + prekey bundle generation with a monotonic allocation counter
(T02 + bug B01), and the real `CryptoService` — X3DH session establishment
and Double Ratchet encrypt/decrypt with five independently mutation-tested
security-proof tests (T03). A final bug sweep found and closed one more
live defect (B02) before the epic closed.

## What recurred — the epic's central finding
**The same invariant broke four times: "never hand out an id/prekey
already issued," each time in a different reader of the same table.**

1. E03-T02: prekey-id allocator derived the next id from `max(live rows)`
   — correct until the pool drained, then restarted at 1 (→ **E03-B01**).
2. E03-B01's own fix, same-day review: the new counter's wrap-around
   modulus used the library's advertised `MAX_VALUE` instead of its real
   `MAX_VALUE - 1` — caught only because the reviewer read the library
   source instead of trusting the constant's name.
3. E03-B02 (end-of-epic sweep, after B01 had already shipped):
   `getLocalPreKeyBundle()` read `rows.first` — B01 gave the table a
   counter for *allocation*; nothing updated *issuance*, a sibling reader
   of the same table.
4. E03-B02's own fix, same-day review: `replenishOneTimePreKeys()` still
   counted live rows, not *issuable* rows — a third reader of the same
   table, still not re-audited, found inside the very fix meant to close
   this class of bug.

Every instance was caught in independent review (rule 5) before merge — no
shipped defect — but four rounds on one invariant is a system problem, not
a people problem. Logged as `agent/memory/lessons/backend.md` L-backend-003
at recurrence 4, **promoted to a rule** in `agent/skills/implement/SKILL.md`
§6 Self-review this retro — 🧍 `retro_promotions` gate, pending human
approval. No mechanical hook yet: the pattern is semantic ("this table now
has an authoritative counter — audit every reader"), not syntactically
greppable with the tooling this project currently has.

A smaller, distinct finding: **E03-T01's review** found remote-peer identity
trust was kept in-memory only, forgotten on restart — not a recurrence of
anything else in this epic, closed cleanly by E03-T01b the same day it was
raised.

## What got promoted
- **L-backend-003 → rule** (`implement/SKILL.md` §6, this retro).

## What the numbers said
No `metrics.csv` — same gap as E00/E01/E02, still not fixed mechanically.
7 tasks total (5 planned + 2 sweep-found bugs) against a 3-task estimate —
the two extra were genuine sweep findings on a strictly-linear, single-owner
invariant (one table, one counter, four readers), not a scope-estimation
miss; the epic's own Analyze report flagged 100% `must` tasks as a
MoSCoW-inflation exception precisely because every task in this chain was
a hard prerequisite for the next.

## Open follow-ups carried forward
- **E03-B03** (S3, P3, backlog): `InvalidMessageException` isn't exported
  from the `libsignal_protocol_dart` barrel — no catchable type for the
  commonest decrypt failure. Deliberately deferred to whichever of E05/E06
  first wraps a `catch` around `decrypt()`, so the exception taxonomy is
  shaped by real UI needs (which failures are silent vs. must raise a
  safety-number warning) instead of designed in isolation.
- **Issued-but-never-consumed one-time prekeys leak from the pool
  permanently** (noted in E03-B02's Run log, not built) — needs an
  expiry/reclaim policy before E04's transport starts issuing bundles at
  real volume.
- **Skipped/undelivered message keys stay decryptable from a compromised
  device** (confirmed correct Signal behavior, needed for out-of-order
  delivery, not a bug) — bounds the forward-secrecy claim to in-order
  messages; should be stated wherever that guarantee is ever shown to a
  user, flagged for whichever epic writes that copy.
- `signal_identity` stores the local identity keypair in plaintext SQLite
  (noted in E03-T01b's review) — no at-rest encryption for the Drift file
  is tracked anywhere in `spec/`. Worth a security-lens pass before release,
  not urgent for internal builds.
- OQ-E00-3 (no Flutter-capable design-fidelity gate) is n/a to this epic
  (no UI), but remains open and unaffected by E03's work.
