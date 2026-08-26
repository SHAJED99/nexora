---
id: E01
title: Identity & Access
status: todo
type: feature
priority: { moscow: must, wsjf: 4.8 }
depends_on: []
traces_to: [FR-AUTH-001, FR-AUTH-002, FR-AUTH-003, FR-AUTH-004, FR-AUTH-005]
external_services: [Google Auth, Firebase]
ui_surface: [mobile]
design_screens: [welcome, login]
---
# E01 · Identity & Access

## Business goal
Every device that runs NEXORA has a real, independent account identity
(Google/Firebase) and a real, independent cryptographic device identity
(ADR-0005) — the two foundations every later epic (trust, encryption, sync,
recovery) is built on top of.

## User-visible outcome
A user can sign in with Google on first launch and land on a real dashboard
with a real per-device identity established — replacing genesis's stubbed
1-second delay with the real thing.

## Scope
**In scope**
- Real Google Sign-In (Firebase Auth) replacing the genesis stub
- Per-device cryptographic identity generation on install (ADR-0003's key
  material scaffolding — not the full ratchet protocol, that's E03)
- Multi-device-per-account support (each device its own local state)
- A minimal Firebase client wrapper for account/device metadata (the thin
  slice noted in `epics/README.md`'s risk section — full scope stays E11's)

**Out of scope**
- E2E encryption protocol itself (E03)
- Trust/connection-request evaluation (E02)
- Account recovery via a trusted device (E12)

## Data model
`device_identities` (already scaffolded in genesis, `lib/core/persistence/database.dart`)
gains real fields for the device's public key material. A new
`accounts` concept links a Firebase UID to one or more local device
identities — table design is this epic's task-sharding job.

## API surface
Firebase Auth SDK (Google provider) + a minimal Firestore/Realtime-DB
wrapper scoped strictly to `FR-FB-001`'s allowed fields — no message
content, no keys, ever (`FR-FB-002`).

## Screens
| Screen | Route | Design contract | Task |
|---|---|---|---|
| Welcome | /welcome | `design/screens/welcome.md` | (already built in genesis; this epic swaps the stub for real auth) |
| Login | /login | `design/screens/login.md` | (already built in genesis; this epic swaps the stub for real auth) |

**Gaps:** none new — genesis's `design/gaps.md` GAP-001 (welcome page
background) should be resolved as part of this epic's first UI task now
that design-fidelity gating exists to check it (see OQ-E00-3).

## Acceptance criteria (epic-level, EARS)
- **EARS-AUTH-1**: WHEN a user taps "Continue with Google" on first launch, the system SHALL authenticate via Firebase Auth and create/link an account identity. (FR-AUTH-001)
- **EARS-AUTH-2**: The system SHALL generate a device-level cryptographic identity independent of account identity, on install. (FR-AUTH-003)
- **EARS-AUTH-3**: IF a user signs in on a second device, THEN the system SHALL treat it as an independent device identity under the same account, not a replacement. (FR-AUTH-004)
- **EARS-AUTH-4**: The welcome screen SHALL offer no authentication path other than Google Sign-In. (FR-AUTH-005)

## Tasks
<sharded by `skills/task-sharding` once this epic is approved>

## Test strategy
Real Firebase Auth flow (Google test account or emulator), a real device-identity
generation test, and a multi-device test (two simulated installs, same
account, independent device rows). Design-verify gate runs against welcome/login
once E00-T05's design-fidelity follow-up (OQ-E00-3) lands.

## Risks
| Risk | Mitigation |
|------|-----------|
| Firebase project/config doesn't exist yet | First task: provision a Firebase project — `new_dependency`/`secrets_or_env_change` human gates apply |
| Device-identity key material overlaps with E03's crypto scope | Keep this epic to *generating and storing* the identity; E03 owns the ratchet/session protocol built on top of it |

## Open Questions
- **OQ-E01-1 — Firebase project provisioning.** ✅ Resolved. Project `nexora-b3a97` (display name "NEXORA") already existed under `shajedurrahmanpanna.storage3@gmail.com` — confirmed as the right one to use. Android app registered (`com.nexora.nexora`, app id `1:941031756225:android:1418978da131e449651f40`), both debug-keystore SHA-1/SHA-256 fingerprints added, Google Sign-In enabled as an Auth provider and deployed (`firebase deploy --only auth`), and the real `google-services.json` (with a populated `oauth_client`) written to `android/app/`. Task-sharding can proceed against a real backend.
  - **Status:** 🟢 answered
  - **Answer:** Use `nexora-b3a97`; full Android + Google Sign-In wiring done 2026-08-26 via the `firebase` MCP server (`agent/mcp/firebase.md`).
  - **Answered by:** human (via Q&A) + claude-code (MCP-driven provisioning)
  - **Date:** 2026-08-26
  - **Follow-up:** release-signing SHA-1/SHA-256 (separate from the debug keystore used here) must be added to this same Android app before any signed/release build ships — track at E01 task-sharding, not forgotten.

## Analyze report
<pending — appended once tasks are sharded>

## Retro
→ `retro.md` (written after E01 completion)
