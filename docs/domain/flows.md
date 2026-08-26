# Core Flows — NEXORA

> The end-to-end flows the business actually cares about, walked start to
> finish. Each references the FR ids in `spec/srs.md` that define its steps.

**Date:** 2026-08-26

## Flow 1 — Onboarding & first connection
```
Google Login (FR-AUTH-001)
  → Account created, device identity generated (FR-AUTH-003)
  → Device setup / permissions
  → Discover nearby devices (FR-DISC-001)
  → Send connection request (FR-TRUST-003)
      ├─ Trusted → Auto-Accept (FR-TRUST-004)
      └─ Unknown → Authentication required
  → Bidirectional authorization confirmed (FR-TRUST-005)
  → Secure channel established (FR-SEC-001)
  → {Chat, PTT, Call} available
  → Dynamic routing selects transport (FR-ROUTE-005)
  → Relay if no direct path (FR-ROUTE-001)
  → Message reaches destination
```
Source: BRD §63; documentation/Design.md §80–87 (first-run detail)

## Flow 2 — Sending a message while offline
```
User composes message
  → Saved locally (FR-MSG-001)
  → Outgoing queue
  → Wait for a route
  → Route becomes available → Send
  → Delivery state progresses: Queued → Sent → Accepted → Delivered → Read
     (FR-MSG-002)
  → Duplicate-safe (FR-MSG-003), order-safe (FR-MSG-004)
```
Source: BRD §33–36

## Flow 3 — Route migration (idle or mid-call)
```
Current route active
  → Better route discovered
  → Calculate route cost (FR-ROUTE-007, multi-factor)
  → Sufficiently better? (threshold: Q-FUNC-005, open)
      no → stay on current route
      yes → Establish new connection
          → Validate new connection
          → Move traffic to new connection
          → Terminate old connection (FR-ROUTE-006, make-before-break)
```
For calls specifically, this repeats mid-session with the added constraint
of minimizing interruption (FR-CALL-003).
Source: BRD §29–30, §53

## Flow 4 — Blocking a user
```
User A blocks User B (FR-BLOCK-001)
  → Direct communication between A and B prevented
  → If A and B share a group (FR-BLOCK-002):
      → A and B become mutually invisible within that group
         (messages, presence, activity, location, reactions)
      → Group encryption denies each the ability to decrypt the other
         (FR-BLOCK-003)
```
Source: BRD §12–14

## Flow 5 — Group membership change
```
Owner/Admin removes or adds a member (FR-GROUP-002)
  → Group encryption keys rotate (FR-GROUP-004)
  → Removed member: loses access to all FUTURE group communication
     (FR-GROUP-005)
  → Added member: does NOT automatically get access to HISTORICAL
     communication (FR-GROUP-006; no exception mechanism defined — v1 has
     none, per Q-FUNC-006's answer)
```
Source: BRD §51

## Flow 6 — Mandatory application update
```
Firebase/cached policy evaluated: currentBuild < minimumSupportedBuild?
  yes → UPDATE_REQUIRED
      → Application communication blocked (FR-VER-006)
      → Non-dismissible prompt shown
      → User redirected to Google Play (FR-VER-007)
      → Local data (messages, recordings, settings) preserved throughout
         (FR-VER-009)
  no, but currentBuild < latestBuild → UPDATE_AVAILABLE (optional, dismissible)
  no → UP_TO_DATE, continue normally
```
If offline: last known policy is used (FR-VER-008); a fully-offline device
cannot be force-updated (constitution — "no force-update at zero
connectivity").
Source: BRD §61.1–9

## Flow 7 — Account recovery / new device enrollment
```
User authenticates (Google) on a new device
  → Where an existing trusted device is available:
      → Existing trusted device authorizes the new device
      → New device enrolled
  → If ALL cryptographic keys are permanently lost across all devices:
      → Encrypted historical content is NOT recoverable (FR-RECOVER-002,
         intentional security property — not a bug to fix)
```
Source: BRD §55
