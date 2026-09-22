# Feature List — NEXORA

> Module → Feature → Use Case hierarchy, derived from `documentation/BRD.md`
> §4 (Product Scope) and §66.1 (BRD Scope). Each feature links to the FR ids
> in `spec/srs.md` that define it. This is the shape `skills/epic-breakdown`
> will turn into epics — modules are the natural epic-grouping candidates,
> not a commitment to that grouping.

**Status:** draft — 🧍 not yet human-reviewed
**Date:** 2026-08-26

---

## Module: Identity & Auth
- **Feature: Google Sign-In** — FR-AUTH-001, FR-AUTH-002, FR-AUTH-005
  - UC: User signs in with Google on first launch
- **Feature: Device Identity** — FR-AUTH-003, FR-AUTH-004
  - UC: App generates a device cryptographic identity on install
  - UC: User has multiple devices, each independently identified

## Module: Relationships & Trust
- **Feature: Connection Requests** — FR-TRUST-001–005
  - UC: Device A requests a connection with device B
  - UC: B auto-accepts a trusted device's request
  - UC: B evaluates an unknown device's request
- **Feature: Relationship Controls** — FR-TRUST-006
  (FR-TRUST-007 ⛔ descoped 2026-09-06, `IMP-002` — relationship config is
  local-only per device; no cross-device sync)
  - UC: User configures auto-accept and authentication requirements
- **Feature: Blocking** — FR-BLOCK-001–003
  - UC: User blocks another user
  - UC: Blocked users are mutually invisible within a shared group

## Module: Personal & Group Communication
- **Feature: Personal Chat** — FR-COMM-001
  - UC: User sends/receives text, voice messages, PTT, attachments, location with a contact
- **Feature: Group Chat** — FR-COMM-002, FR-GROUP-001–006
  - UC: Owner creates and manages a group
  - UC: Member sends/receives group communication
  - UC: Group keys rotate on membership change
- **Feature: Voice Calls** — FR-CALL-001–003
  - UC: User places a secure voice call
  - UC: Call migrates to a better route mid-call without dropping

## Module: Offline & Local Storage
- **Feature: Local Conversation Storage** — FR-STORE-001, FR-STORE-002
  - UC: Conversation history persists locally, split Personal/Groups
- **Feature: Storage Management** — FR-STORE-003–007
  - UC: User selects a storage management mode
  - UC: Smart Mode auto-removes low-value data and explains why
  - UC: Dashboard surfaces a storage warning

## Module: Mesh Networking
- **Feature: Device Discovery** — FR-DISC-001–003
  - UC: App discovers nearby devices over available transports
- **Feature: Multi-Hop Relay** — FR-ROUTE-001–004
  - UC: Message relays through an intermediate device
  - UC: Relay store-and-forwards while destination is unreachable
- **Feature: Dynamic Routing** — FR-ROUTE-005–009
  - UC: App evaluates and migrates to a better route (make-before-break)
  - UC: App recovers from a route failure

## Module: Messaging Reliability
- **Feature: Offline Message Queue** — FR-MSG-001, FR-MSG-002
  - UC: User composes a message while offline; it sends once connectivity returns
- **Feature: Delivery Guarantees** — FR-MSG-003, FR-MSG-004
  - UC: Duplicate packets don't create duplicate messages
  - UC: Out-of-order packets reassemble into correct message order
- **Feature: Multi-Device Sync** — FR-MSG-005, FR-MSG-006
  - UC: A user's second device catches up on missed data
- **Feature: Conflict Resolution** — FR-MSG-007, FR-MSG-008 (✂️ `FR-MSG-008`
  narrowed 2026-09-22 to REVOKE-DEVICE only — `IMP-004`; TRUST/BLOCK/UNBLOCK/
  REMOVE-TRUST are not represented as synced discrete events)
  - UC: Security-state conflicts resolve toward the more restrictive state

## Module: Security & Encryption
- **Feature: End-to-End Encryption** — FR-SEC-001, FR-SEC-002, FR-SEC-004
  - UC: Two devices establish an encrypted channel relays/Firebase can't read
- **Feature: Threat Protection** — FR-SEC-003
  - UC: App detects/resists impersonation, replay, MITM, Sybil abuse

## Module: Location Sharing
- **Feature: Location Controls** — FR-LOC-001–005
  - UC: User toggles location sharing globally and per-contact
  - UC: App shows last-known location with a visible staleness indicator

## Module: Notifications & Background
- **Feature: Notifications** — FR-NOTIFY-001–002
- **Feature: Background Operation** — FR-PLAT-001–003
  - UC: App maintains connectivity/sync while backgrounded, respecting Doze/Battery Saver

## Module: Firebase Integration
- **Feature: Metadata Sync** — FR-FB-001, FR-FB-002
  - UC: Device/trust/config metadata syncs via Firebase without ever carrying plaintext

## Module: Account Recovery
- **Feature: Device Enrollment via Trusted Device** — FR-RECOVER-001, FR-RECOVER-002
  - UC: User adds a new device authorized by an existing trusted device
  - UC: User loses all keys and is informed recovery is impossible by design

## Module: Abuse Prevention & Diagnostics
- **Feature: Abuse Controls** — FR-ABUSE-001
- **Feature: Privacy-Safe Diagnostics** — FR-DIAG-001, FR-DIAG-002

## Module: Application Version Management
- **Feature: Version Enforcement** — FR-VER-001–011
  - UC: App checks version policy and blocks communication if unsupported
  - UC: User is prompted through a mandatory, non-dismissible update flow
  - UC: App preserves local data across a mandatory update

## Module: Design System (cross-cutting, not a standalone epic)
- **Feature: Material 3 Theming** — FR-UI-001–003
- **Feature: Progressive Disclosure** — FR-UI-004
- **Feature: Localization & RTL** — FR-UI-005

---

## Not yet a module (explicitly out of BRD scope, §66.2)
Exact Flutter packages, exact cryptographic library, exact database package,
exact Firebase collection schema, exact Android service implementation, exact
routing algorithm, exact wire protocol, exact UI component implementation —
all genesis ADR / task-sharding territory, not features.
