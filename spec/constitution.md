# Project Constitution — NEXORA

> The project-specific principles every agent and every task inherits,
> distinct from `AGENTS.md` (the harness's own process rules). Derived from
> `documentation/BRD.md` §3 (Core Principles) and §64 (Major Business Rules).
> This file needs explicit human acceptance — these are the invariants that
> make a technically-correct implementation still the wrong one if violated.

**Status:** 🧍 AWAITING HUMAN ACCEPTANCE
**Date:** 2026-08-26

---

## The five non-negotiables

### 1. Offline-first is not a feature, it's the floor
NEXORA must remain useful when the Internet is unavailable, Firebase is
unavailable, a peer is temporarily unavailable, connectivity changes, a route
disappears, or the network partitions. Any design or task that silently
assumes connectivity — a spinner with no offline fallback, a feature that
just breaks with no network — has violated this principle, not just missed
an edge case. *(BRD §3.1)*

### 2. Security first, always
All private communication is end-to-end encrypted, full stop. Intermediate
relays must never be able to decrypt message contents. Firebase must never
have access to private conversation content. When a task's convenience and
this principle conflict, this principle wins — there is no "just for now"
exception. *(BRD §3.2, §41)*

### 3. No transport is a second-class citizen
NEXORA must not assume a fixed mapping like "Bluetooth = discovery only" or
"Internet = calls only." Any available transport may carry any supported
communication type when technically possible. A task that hardcodes a
transport-to-feature binding is building an assumption the BRD explicitly
rejects. *(BRD §3.3)*

### 4. Battery is a factor, never the deciding vote
Routing decisions consider multiple factors. Battery consumption must never
by itself determine the best route — a task that optimizes purely for
battery life at the expense of reliability has inverted this principle.
*(BRD §3.4, §31)*

### 5. Privacy is the user's to control, not the system's to assume
Users control: trusted users, trusted devices, blocked users, location
sharing (global and per-user), storage management, notification privacy,
and account/device visibility. A task that makes one of these choices *for*
the user, rather than exposing it as a control, has taken a decision that
isn't the implementation's to make. *(BRD §3.5)*

---

## Load-bearing business rules (the ones that break the product if violated)

These are drawn from BRD §64's full 40-rule table — not a duplicate of it,
just the subset where getting it wrong isn't a bug, it's a trust or safety
failure:

- **Migration is make-before-break.** The old connection is never terminated
  before the new one is ready and validated. *(BRD §30)*
- **Relays cannot decrypt.** Not "shouldn't" — architecturally cannot.
  *(BRD §27, §41)*
- **Blocking is mutual invisibility, not just a filtered inbox.** In a shared
  group, a blocked pair sees nothing of each other — messages, presence,
  activity, location, reactions. *(BRD §13, §125 design)*
- **Conflict resolution always favors the more restrictive state.**
  BLOCK > TRUST, LOCATION-OFF > LOCATION-ON, REVOKED > ACTIVE,
  REMOVED > MEMBER. When two devices disagree on a security-sensitive state,
  the restrictive one wins, never the permissive one. *(BRD §39)*
- **Lost keys mean lost history — by design.** If all cryptographic keys are
  permanently lost, encrypted historical content is not recoverable. This is
  a stated security property, not a support failure to work around.
  *(BRD §55)*
- **A device can't be force-updated with zero connectivity.** The system
  uses the last known policy while offline; it cannot retroactively enforce
  a policy a fully-offline device never received. *(BRD §61.8)*

---

## What this constitution does NOT cover

Exact technology choices (crypto library, database, routing algorithm) are
explicitly out of scope here — those are `spec/genesis` ADRs, a human
decision made with full options and trade-offs, not a principle to assert.
See `spec/srs.md` §Open items for what's still pending a decision.

---

## 🧍 Human acceptance

- [ ] The five non-negotiables above are accepted as-is
- [ ] The load-bearing business rules subset is correct and complete enough
- [ ] Nothing here contradicts intent that didn't make it into the BRD

**Corrections from the human:**
