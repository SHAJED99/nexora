---
id: E03
title: E2E Encryption & Threat Protection
status: done
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
  - **Status:** ✅ resolved
  - **Answer:** `libsignal_protocol_dart` (mixin.dev publisher, pure Dart, v0.8.2 at
    time of decision) — implements X3DH, Double Ratchet, and Sender Keys
    (group sessions, needed later by E07) natively, no FFI/native build step
    for an Android-only app. Rejected: official Rust `libsignal` via
    flutter_rust_bridge (thinner adoption, AGPL-3.0, adds a native-binary
    supply chain); hand-rolling from `cryptography` package primitives
    (multi-week effort, high tail-risk of a silent forward-secrecy bug).
    **Note:** `libsignal_protocol_dart` is GPL-3.0-licensed as a dependency —
    accepted by the human as compatible with NEXORA's distribution model.
  - **Answered by:** human
  - **Date:** 2026-08-27

- **OQ-E03-T01-1 — remote-peer identity trust not persisted across
  restarts.** Raised by the reviewer during E03-T01's review: `saveIdentity`/
  `isTrustedIdentity`/`getIdentity` were implemented in-memory only, so a
  changed remote identity key (MITM/safety-number change) would not be
  detected across an app restart — undermining the epic's own FR-SEC-003
  claim. A schema change (rule 3 human gate).
  - **Status:** ✅ resolved
  - **Answer:** Sharded as a new task, **E03-T01b**, adding a
    `signal_trusted_identities` Drift table (schema v4→v5) and rewiring
    `DriftSignalProtocolStore` to it. E03-T03's `depends_on` updated to
    include it; E03-T03 stays blocked until E03-T01b is done.
  - **Answered by:** human
  - **Date:** 2026-08-27

## Analyze report
*(`skills/task-sharding` §6, run 2026-08-27 against E03-T01/T02/T03)*

| Check | Result | Notes |
|---|---|---|
| EARS trace | ✅ pass | EARS-SEC-1/2/3 (epic-level) each covered by ≥1 task-level EARS id: T01→EARS-SEC-3a, T02→EARS-SEC-3b/3c, T03→EARS-SEC-1/2/3 (the epic ids themselves, since T03 is where the full protocol claim is proven). No orphans either direction. |
| Contract sanity | ✅ pass | No REST/API endpoints in this epic (library-level interface only, per epic.md "API surface"). Function signatures across T01→T02→T03 form one consistent chain (`DriftSignalProtocolStore` → `IdentityService` → `CryptoService`), no two tasks define the same seam differently. |
| Collision matrix | ✅ pass (trivially) | Strictly linear `depends_on` chain (T01→T02→T03), no parallel dispatch candidates, so no file can collide. T01 touches `database.dart`/`.g.dart` + new files only; T02 adds one new file; T03 only edits `crypto_stub.dart` (already owned by no other in-flight task) + adds one test file. |
| Scope fences | ✅ pass | Every task's §4 is non-empty and epic-specific (see e.g. T03 explicitly fencing off auto-establish-on-demand and E07's Sender-Keys work). |
| MoSCoW inflation | ⚠️ exception, justified | 3/3 tasks (100%) are `must` — normally a re-grade signal. Not re-graded here: this is a 3-task infrastructure epic where each task is a strict prerequisite for the next and none is independently shippable (a store with no identity service, or an identity service with no encrypt/decrypt, delivers zero of the epic's user-facing security guarantee). Inflation as a smell applies to epics with a mix of core and optional work; this epic has no optional slice to mis-grade against. Flagging for the human gate rather than silently re-grading one task to `should` to make the metric pass. |
| Size | ✅ pass | T01 `M`, T02 `S`, T03 `M` — none `L`. T03's scope (session establishment + encrypt/decrypt + the 5 security proof tests) was the one candidate for a split; kept as one task because the tests *are* the deliverable's proof, not separable follow-up work, and splitting would let "establish session" ship as done before "prove forward secrecy" — the exact wrong signal for a security epic. |
| Design | ✅ pass (n/a) | No `layer: frontend` tasks in this epic; `design_contract: n/a` on all three, consistent with epic.md's "Screens: None." |

**Net:** 6/7 clean pass, 1 flagged exception (MoSCoW) with reasoning attached
for the human to accept or override at the gate below.

**Gate:** 🧍 `analyze_report` — ✅ cleared by human on 2026-08-27 (approved
as-is, including the MoSCoW exception reasoning above).

## Bug sweep
Run 2026-08-27 (`skills/bug-sweep`, Opus, against `epic_03` with all 5 tasks
done) — see `tracker.md` Event log for the full account. 2 findings:
E03-B02 (S2, live, P1 — fixed and merged same day) and E03-B03 (S3,
advisory P3, deferred to E05/E06's error-handling design). P1/P2 = 0 as of
the B02 merge — epic clear to proceed per `skills/bug-sweep`'s own gate
("the epic→dev PR opens only when P1/P2 = 0").

## Epic-completion gate
🧍 `epic_dev_merge` — build-complete, bug sweep clean (P1/P2 = 0), 70/70
green. Merge to `development` per rule 4 ("every merge into `development`
or `main` are human calls") — _<pending>_.

## Retro
→ `retro.md` (written after E03 completion)
