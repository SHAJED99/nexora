---
status: accepted
date: 2026-08-26
proposed_by: claude-code (genesis T01)
decided_by: human, 2026-08-26
traces_to: [FR-AUTH-001, FR-AUTH-002, FR-AUTH-003, FR-RECOVER-001]
---

# ADR-0005 — Auth/session strategy (account identity ↔ device identity)

## Context
BRD already fixes the providers — Google Authentication for account
identity, Firebase Authentication to maintain it (FR-AUTH-001) — those are
not open choices. What's open is the *relationship* between the two
identity layers this domain has: account identity (Google/Firebase) and
device cryptographic identity (FR-AUTH-003, independent per install,
explicitly NOT replaced by account auth per FR-AUTH-002). The session
strategy has to define how a Firebase Auth session maps to which device
identity is "active," how that's re-established after app restart/token
refresh, and how a new device gets vouched for by an existing trusted one
(FR-RECOVER-001) without ever conflating the two identity layers.

## Options considered
1. **Firebase session is a thin account pointer; device identity/session is
   entirely local and independent, linked only by an account-id ↔
   device-id mapping stored in Firebase per FR-FB-001** — pros: cleanly
   matches BRD's own stated separation (FR-AUTH-002); device identity/keys
   never need to touch Firebase Auth's token lifecycle at all, so a Firebase
   token refresh or re-login can never accidentally affect cryptographic
   state. cons: app needs its own local session/lock mechanism independent
   of Firebase Auth's session state, effectively two session systems to
   reason about.
2. **Derive/wrap device session from the Firebase Auth session directly
   (e.g. custom claims carrying device-id)** — pros: one session lifecycle
   to manage, less code. cons: conflates account and device identity exactly
   where BRD says not to (FR-AUTH-002); a Firebase token expiry/refresh
   event would ripple into device/crypto session state, which is a much
   more sensitive thing to have failure-mode coupling with.

## Comparison matrix
| Criterion | Independent sessions | Coupled via Firebase claims |
|---|---|---|
| Matches FR-AUTH-002 (account ≠ device identity) | Strong | Weak |
| Failure isolation (Firebase outage doesn't affect local device session) | Strong (device works offline regardless) | Weak (coupled) |
| Implementation simplicity | Two systems | One system |
| New-device enrollment via trusted device (FR-RECOVER-001) | Clean — vouching is a device-to-device act | Muddier — implies Firebase-level trust delegation |

## Agent recommendation (advisory — NOT the decision)
**Independent sessions — Firebase Auth session as a thin account pointer,
device identity/session fully local and independent.** This is really just
making FR-AUTH-002 (already stated as a requirement, not a preference)
architecturally real rather than aspirational, and it directly supports the
offline-first constitution — device-level functionality must never depend
on a live Firebase session. Final call is yours.

## Decision
✅ Accepted — chosen option: **Independent sessions** — Firebase Auth
session as a thin account pointer; device identity/session fully local and
independent, linked only by an account-id ↔ device-id mapping in Firebase
(FR-FB-001).

## Consequences
- Device cryptographic identity/session never depends on Firebase Auth's
  token lifecycle — a Firebase token refresh, expiry, or outage cannot
  affect local device/crypto session state.
- The app implements its own local session/lock mechanism independent of
  Firebase Auth's session state.
- New-device enrollment via an existing trusted device (FR-RECOVER-001) is
  a device-to-device vouching act, not a Firebase-level trust delegation.
- This makes FR-AUTH-002 (account identity ≠ device identity) architecturally
  real, not just stated.
