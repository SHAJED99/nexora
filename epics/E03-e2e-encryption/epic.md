---
id: E03
title: E2E Encryption & Threat Protection
status: todo
type: feature
priority: { moscow: must, wsjf: 3.5 }
depends_on: [E01]
traces_to: [FR-SEC-001, FR-SEC-002, FR-SEC-003, FR-SEC-004]
external_services: []
ui_surface: []
design_screens: []
---
# E03 · E2E Encryption & Threat Protection

## Business goal
Implement the Signal-style (X3DH + Double Ratchet) protocol accepted in
ADR-0003, on top of E01's device identity, so that every later communication
epic has a real encrypted channel to build on rather than plaintext.

## User-visible outcome
None directly (no new screen) — this epic is infrastructure the wedge (E06)
depends on. Its "user-visible" proof is the wedge working securely.

## Scope
**In scope**
- X3DH key agreement using E01's device identity key material
- Double Ratchet session state (per device-pair), forward secrecy,
  post-compromise security
- Threat protections named in FR-SEC-003 to the extent they're protocol-level
  (replay protection via ratchet counters, MITM resistance via authenticated
  key exchange) — flooding/Sybil/device-impersonation controls that are
  *policy* rather than *protocol* belong to E13 (Abuse Prevention)
- `core/crypto` (genesis stub) becomes real

**Out of scope**
- Group encryption / Sender-Keys layering (that's E07's job, built on this
  epic's 1:1 primitives)
- Transport-level security (E04 handles authenticated peer connections;
  this epic assumes a byte pipe exists, encrypted or not, and encrypts on
  top of it)

## Data model
Session/ratchet state per device-pair (root key, chain keys, message
counters) — stored locally, never in Firebase (`FR-FB-002`).

## API surface
No external API — a library-level interface (`core/crypto`) that E05/E06
call to encrypt/decrypt outgoing/incoming payloads.

## Screens
None.

## Acceptance criteria (epic-level, EARS)
- **EARS-SEC-1**: The system SHALL end-to-end encrypt all private communication such that only authorized endpoints can decrypt it. (FR-SEC-001)
- **EARS-SEC-2**: Relay devices, Firebase, and network infrastructure SHALL NOT have access to plaintext communication content. (FR-SEC-002)
- **EARS-SEC-3**: The system SHALL implement E2E encryption via X3DH + Double Ratchet (ADR-0003), not an ad hoc scheme. (FR-SEC-004)

Cross-cutting: **NFR-SEC-001** (strong E2E security/privacy) binds here as
the primary epic-level NFR.

## Tasks
<sharded by `skills/task-sharding` once this epic is approved>

## Test strategy
Known-answer tests against the X3DH/Double Ratchet spec vectors where
available; a two-party session test proving forward secrecy (compromising
a later key doesn't reveal earlier plaintext) and post-compromise recovery.
This is security-critical — expect the review gate's security lens
(`skills/review` references/security.md) to apply in full.

## Risks
| Risk | Mitigation |
|------|-----------|
| Rolling a subtly-wrong ratchet implementation is exactly the failure mode ADR-0003 chose Signal-style specifically to avoid | Use a maintained libsignal-derived Dart/Flutter library where one exists rather than hand-rolling from primitives; task-sharding should name the specific library as an implementation-choice ADR follow-up if one wasn't already picked |
| This is the highest-consequence epic to get wrong and hardest to test exhaustively | Independent security review (rule 5) is non-negotiable here; consider an external audit before this ships past a wave-1 internal build |

## Open Questions
- **OQ-E03-1 — specific crypto library.** ADR-0003 accepted the protocol *family* (Signal-style); task-sharding needs the specific Dart/Flutter library (or a justified from-primitives build) named before tasks can be written with real function signatures.
  - **Status:** 🟡 open
  - **Answer:** _<empty>_
  - **Answered by:** _<empty>_
  - **Date:** _<empty>_

## Analyze report
<pending — appended once tasks are sharded>

## Retro
→ `retro.md` (written after E03 completion)
