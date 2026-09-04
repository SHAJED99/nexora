---
status: accepted
date: 2026-08-26
proposed_by: claude-code (genesis T01)
decided_by: human, 2026-08-26
traces_to: [FR-SEC-001, FR-SEC-002, FR-SEC-004, FR-GROUP-004, FR-GROUP-005, FR-GROUP-006, spec/questions.md Q-ARCH-003]
---

# ADR-0003 — Cryptographic protocol family

## Context
This is Q-ARCH-003 promoted to a formal ADR, per that question's own note
("flagged so it isn't skipped"). BRD §41/§66.2 mandates end-to-end
encryption and explicitly defers the *exact library*, but the *protocol
shape* is architectural: it directly determines how group key rotation on
membership change (FR-GROUP-004/005), multi-device key distribution
(FR-MSG-005), and account recovery's "keys lost = unrecoverable by design"
property (FR-RECOVER-002) all actually work. This choice has to be made once
and is exceptionally expensive to change later — nearly every feature epic
touches it.

## Options considered
1. **Signal Protocol (X3DH + Double Ratchet) for 1:1, Sender Keys for
   groups** — pros: the most battle-tested E2E scheme in production
   messaging (Signal, WhatsApp), strong forward secrecy + post-compromise
   security for 1:1, well-documented, several mature open-source
   implementations (libsignal). cons: Sender Keys (Signal's own group
   scheme) rotates keys per-sender not per-membership-change as cleanly as
   MLS — BRD's exact requirement ("rotate on membership change," FR-GROUP-004)
   needs to be layered on top rather than being native to the scheme.
2. **MLS (Messaging Layer Security, RFC 9420) for both 1:1 and groups** —
   pros: an IETF standard *designed* for exactly BRD's group-key-rotation
   requirement (a "TreeKEM" naturally supports efficient rekey on
   membership change) and unifies 1:1 as a 2-member group, one protocol for
   everything. cons: younger in production (finalized 2023), fewer mature
   Dart/Flutter implementations to build on than Signal-derived libraries,
   more complex to implement correctly from scratch.
3. **Custom scheme built from primitives (X25519 + AES-GCM + custom
   ratchet)** — pros: full control, no dependency on an external protocol's
   assumptions. cons: rolling your own crypto protocol is a well-known
   anti-pattern — subtle mistakes in ratchet/key-derivation logic are how
   real E2E systems get broken; BRD itself defers this exact choice because
   it's specialized, not because it's easy.

## Comparison matrix
| Criterion | Signal-style | MLS | Custom |
|---|---|---|---|
| Fit to group-key-rotation-on-membership-change (FR-GROUP-004) | Layered on top | Native | Build yourself |
| Production track record | Very high | Moderate (newer) | None |
| Dart/Flutter library maturity | Higher (libsignal ports exist) | Lower | N/A |
| Security review risk | Low (widely audited) | Low-moderate (newer standard) | High |
| Unifies 1:1 and group under one model | No (two schemes) | Yes | Depends |

## Agent recommendation (advisory — NOT the decision)
**Signal Protocol (X3DH + Double Ratchet) for 1:1, with a Sender-Keys-style
group scheme layered to satisfy FR-GROUP-004's rotation requirement.** It's
the most production-proven option with the most mature libraries to build
on, which matters given the amount of other novel complexity this project
already carries (custom mesh routing, multi-hop relay). MLS is architecturally
more elegant for the group case but is a bigger bet on a younger standard
with a thinner Flutter ecosystem — not the right place to take that risk on
top of everything else this product is already doing for the first time.
Final call is yours; this is one of the highest-consequence choices in the
whole project.

## Decision
✅ Accepted — chosen option: **Signal Protocol (X3DH + Double Ratchet) for
1:1, Sender-Keys-style group scheme layered on top for FR-GROUP-004's
rotation-on-membership-change requirement.**

## Consequences
- Q-ARCH-003 (`spec/questions.md`) is closed — fed into this ADR.
- 1:1 sessions use X3DH for initial key agreement and Double Ratchet for
  ongoing forward secrecy + post-compromise security.
- Group messaging layers a Sender-Keys-style scheme; group key rotation on
  membership change (FR-GROUP-004/005) and new-member historical-access
  exclusion (FR-GROUP-006, Q-FUNC-006 default) are built explicitly on top
  of this layer, not assumed to fall out of it natively — flagged for
  the groups/encryption epic's task-sharding to design deliberately.
- Library choice (e.g. a libsignal Dart port) is an implementation detail
  within this ADR, not a new foundational decision.
- Multi-device key distribution (FR-MSG-005) and account recovery's
  "unrecoverable if all keys lost" property (FR-RECOVER-002) are designed
  against this protocol family.

## Addendum (2026-09-04) — first-contact trust model: TOFU accepted app-wide

**Context.** `E09-B11` (escalated from `E09-B09`'s round-2 review) found that
`DriftSignalProtocolStore.isTrustedIdentity`'s unconditional trust-on-first-use
(TOFU) — implicit in choosing Signal Protocol, never separately decided — lets
an attacker plant a forged identity on any peer's first contact via any of
four decrypt call sites (messages, calls, group membership, group messages),
then walk that poisoned identity through anything gated only on "an identity
record exists." `E09-B09`'s location-specific `getIdentity != null` gate does
not close this (it only costs the attacker one extra frame) and additionally
breaks legitimate first-time location sharing between two already-trusted
peers with no prior Signal session.

**Decided by:** human (delegated: "do what is best" after reviewing a
plain-language walkthrough of options a/b/c and a recommendation),
2026-09-04.

**Decision.** ✅ **Accept TOFU's risk profile app-wide, as-is — the same
posture the reference Signal app itself ships with by default.** No
authenticated first-contact mechanism (safety-number comparison, QR-code
verification, or treating `E11`'s device directory as an authoritative
identity source) is built for v1.
- `E09-B09`'s location-specific gate is reverted — it doesn't close anything
  it was meant to close, and does regress the legitimate flow described
  above.
- The risk is documented, not silently accepted: any peer's *first* contact
  with another peer, on any feature, can have its identity key silently
  substituted by an on-path or co-present attacker who wins the race to send
  first. Subsequent messages on that session are protected by the Double
  Ratchet as designed; the exposure is strictly first-contact.
- Real authenticated first-contact (option (a) in `E09-B11`) is a legitimate
  future improvement — out-of-band verification UX, or leaning on `E11`'s
  device directory (`ADR-0008`) as an authoritative identity source — but is
  its own scoped epic, not a blocker for this one. Track as a follow-up, not
  an open question against a shipped feature.

**Rationale.** Building real first-contact authentication is a UX project in
its own right (a verification flow every pair of users would need to
complete), and BRD does not mandate it. Shipping with a documented, industry-
precedented risk (this is TOFU's known and accepted shape everywhere it is
used) is preferable to blocking the epic on an unscoped redesign, or shipping
a per-feature patch that provably does not close the hole it targets.

**Consequences.**
- `E09-B09`'s fix is reverted in
  `lib/features/location/domain/location_share_service.dart`.
- No code change to `DriftSignalProtocolStore.isTrustedIdentity` or any of the
  four sibling decrypt call sites `E09-B11` named.
- `E09-B11` and `E09-B09` are both closed by this addendum, not by a code fix
  that closes the exploit — the exploit is accepted, not eliminated.
- If a future epic builds authenticated first-contact, this addendum is
  superseded by a fresh ADR-0003 addendum (or a new ADR) at that time, not by
  editing this entry after the fact.
