# Software Requirements Specification — NEXORA

> Produced by `skills/genesis` T00 from `docs/business/BRD.md` +
> `documentation/Design.md`. This is the canonical, greppable source of truth
> from here forward — `docs/business/` is history. Every id here is atomic,
> traceable (`traces_to:` back to a BRD section), and testable. Where the BRD
> was qualitative only, the requirement stays qualitative rather than
> inventing a number (rule 1) — numeric targets are flagged `[NEEDS NUMBER]`
> and tracked as their own follow-up, not guessed.
>
> EARS forms used: **Ubiquitous** ("The system shall…"), **Event-driven**
> ("When \<trigger\>, the system shall…"), **State-driven** ("While \<state\>,
> the system shall…"), **Unwanted-behavior** ("If \<condition\>, then the
> system shall…"), **Optional** ("Where \<feature is enabled\>, the system
> shall…").

**Status:** draft — 🧍 not yet human-reviewed as a whole (individual facts were
sourced during intake; this is their first atomic-id rendering)
**Date:** 2026-08-26
**Traces from:** `spec/knowledge-map.yaml` facts F-001–F-072

---

## FR-AUTH — Authentication & Device Identity

- **FR-AUTH-001**: The system shall authenticate users via Google Authentication, with Firebase Authentication maintaining account identity. *(traces_to: BRD §5)*
- **FR-AUTH-002**: Account authentication shall not replace device-level cryptographic identity — the two are independent. *(traces_to: BRD §5)*
- **FR-AUTH-003**: Every application installation shall have its own unique cryptographic device identity. *(traces_to: BRD §6)*
- **FR-AUTH-004**: The system shall support multiple devices per user account, each maintaining its own local state and cryptographic identity. *(traces_to: BRD §6)*
- **FR-AUTH-005**: The welcome/first-launch screen shall offer Google Sign-In as the sole authentication method — no alternate login path shall exist. *(traces_to: documentation/Design.md §81; design/screens/welcome.md, confirmed during design review)*

## FR-TRUST — Device Relationships & Authorization

- **FR-TRUST-001**: When a trusted relationship is established between two devices, the system shall persist that relationship. *(traces_to: BRD §7)*
- **FR-TRUST-002**: If the application is uninstalled and reinstalled, the system shall not require the user to unnecessarily recreate existing relationships — while security-sensitive device identity may still require re-verification. *(traces_to: BRD §7)*
- **FR-TRUST-003**: When device A sends a connection request to device B, the system shall let B evaluate the request independently into one of: Trusted, Allowed, Unknown, Blocked. *(traces_to: BRD §8)*
- **FR-TRUST-004**: When B has configured A as trusted, the system shall auto-accept A's connection request, skipping the normal authentication flow. *(traces_to: BRD §9)*
- **FR-TRUST-005**: The system shall evaluate connection authorization independently on both sides — a connection is permitted only when both sides allow it. *(traces_to: BRD §10)*
- **FR-TRUST-006**: The system shall let users configure: auto-accept trusted devices, auto-accept specific users, require authentication for unknown users, block specific users, allow/disable communication, control location access. *(traces_to: BRD §11)*
- **FR-TRUST-007** — ⛔ **DESCOPED 2026-09-06** (human decision, `IMP-002`; the
  id is retained and never deleted, because prior tasks trace to it): Where
  Firebase is available, relevant relationship configuration shall synchronize
  through it. *(traces_to: BRD §11)*
  - **Why descoped.** Read narrowly per `ADR-0008`, this meant "an account's
    own devices agree on peer-relationship state". `ADR-0005` already makes
    device identity and session state fully independent per device, and each
    device evaluates authorization for itself (`FR-TRUST-003`,
    `FR-TRUST-005`) — so no product behaviour depends on two of an account's
    own devices holding the same trust/block opinion. The one case that
    genuinely needed a device-to-device signal was device-enrollment
    approval, and `E12-B03` moved that onto a dedicated enrollment-grant
    channel (`users/$uid/deviceEnrollmentGrants/*`, read directly rather than
    merged through `ConflictResolver`) precisely because routing an
    authorization *grant* through a restrictive-wins conflict resolver was
    that bug's root cause. What was left was
    `RelationshipSyncService.push`/`pull` (E11-T05) with no production caller
    at all — deleted by `E12-B11`.
  - **Not superseded, not re-scoped.** Nothing replaces this requirement.
    Cross-account relationship-state exchange was already declined
    permanently by `ADR-0008`; the own-account half is now declined too.
    Reviving it needs a new FR id and a fresh human decision, not a revert.

## FR-BLOCK — Blocking

- **FR-BLOCK-001**: If user A blocks user B, then the system shall prevent direct communication between A and B, affecting all applicable communication functionality. *(traces_to: BRD §12)*
- **FR-BLOCK-002**: If A blocks B and both are members of the same group, then the system shall make A and B completely invisible to one another within that group — including messages, activity, presence, and location. *(traces_to: BRD §13)*
- **FR-BLOCK-003**: The system shall deny blocked group members the cryptographic material required to decrypt each other's group communication, even while both remain members. *(traces_to: BRD §14)*

## FR-COMM — Communication Types

- **FR-COMM-001**: The system shall support personal communication via text, voice messages, PTT, voice calls, attachments, and location sharing. *(traces_to: BRD §15)*
- **FR-COMM-002**: The system shall support group communication via text, PTT, voice calls, attachments, and group events. *(traces_to: BRD §15)*

## FR-STORE — Local Storage & Management

- **FR-STORE-001**: The system shall store conversation history locally, with the UI providing separate Personal and Groups areas. *(traces_to: BRD §16)*
- **FR-STORE-002**: The system shall store voice messages, PTT recordings, and call recordings locally on-device. *(traces_to: BRD §17)*
- **FR-STORE-003**: The default voice profile shall prioritize low CPU usage, low battery consumption, and efficient network usage over voice quality. *(traces_to: BRD §18)*
- **FR-STORE-004**: The system shall let users choose a storage management mode: Smart Mode (default), delete-older-than-X-days, or delete-when-over-X-MB. *(traces_to: BRD §19)*
- **FR-STORE-005**: While Smart Mode is active, the system shall determine removal candidates using age, size, file type, access frequency, conversation activity, storage pressure, temporary status, and importance. *(traces_to: BRD §20)*
- **FR-STORE-006**: The main dashboard shall show storage warnings when appropriate, as an informational element — not requiring a "Clean Now" action. *(traces_to: BRD §21)*
- **FR-STORE-007**: When a storage warning is expanded, the system shall show the specific decisions the active policy made and explain why. *(traces_to: BRD §22)*

## FR-DISC — Device Discovery

- **FR-DISC-001**: The system shall support device discovery via Bluetooth, Wi-Fi, Wi-Fi Direct, local network, and Internet- or peer-assisted mechanisms. *(traces_to: BRD §23)*
- **FR-DISC-002**: Discovery shall not by itself grant any authorization. *(traces_to: BRD §23)*
- **FR-DISC-003**: The system shall not permanently restrict any transport to a single communication feature — any available transport may carry any supported communication type when technically possible. *(traces_to: BRD §3.3, §24)*

## FR-ROUTE — Multi-Hop Routing & Relay

- **FR-ROUTE-001**: The system shall support communication between two devices without a direct connection, via one or more relay devices. *(traces_to: BRD §25)*
- **FR-ROUTE-002**: When a destination is temporarily unavailable, the system shall let an intermediary device temporarily store encrypted packets and forward them once the destination becomes reachable (store-and-forward). *(traces_to: BRD §26)*
- **FR-ROUTE-003**: A relay device shall process routing information, encrypted payloads, and delivery metadata, and shall not be able to access plaintext conversation content. *(traces_to: BRD §27)*
- **FR-ROUTE-004**: Relay-held data shall be temporary, carrying packet id, destination, priority, size, creation time, expiration time, and delivery state; the relay copy shall be removed after successful delivery is no longer required. *(traces_to: BRD §28)*
- **FR-ROUTE-005**: The system shall continuously evaluate available routes and migrate when a sufficiently better route is found. *(traces_to: BRD §29–30)* **[NEEDS NUMBER — see Q-FUNC-005]**
- **FR-ROUTE-006**: When migrating to a new route, the system shall establish and validate the new connection, move traffic, and only then terminate the old connection (make-before-break) — the old connection shall never be terminated before the new one is ready. *(traces_to: BRD §30)*
- **FR-ROUTE-007**: The system shall calculate route cost from battery, latency, reliability, bandwidth, hop count, congestion, stability, packet loss, and traffic type; battery consumption alone shall never be the sole routing criterion. *(traces_to: BRD §3.4, §31)* **[NEEDS FORMULA — see Q-ARCH-004]**
- **FR-ROUTE-008**: Different traffic types shall prioritize different cost factors — text: reliability/battery/bandwidth; file transfer: bandwidth/reliability/battery; voice calls: latency/jitter/packet-loss/stability/battery; discovery: battery efficiency. *(traces_to: BRD §31)*
- **FR-ROUTE-009**: When a route fails, the system shall search for alternatives and migrate if one exists, or queue/retry if none exists. *(traces_to: BRD §32)*

## FR-MSG — Messaging Semantics

- **FR-MSG-001**: When a message is created while offline, the system shall save it locally, place it in an outgoing queue, and send it once a route becomes available. *(traces_to: BRD §33)*
- **FR-MSG-002**: The system shall represent message delivery using states including Queued, Sent, Accepted, Delivered, Stored, Read, and Failed. *(traces_to: BRD §34)*
- **FR-MSG-003**: Every message and network operation shall carry a unique identifier; the system shall not create duplicate messages from duplicate packets. *(traces_to: BRD §35)*
- **FR-MSG-004**: The system shall maintain logical message ordering even when network packets arrive out of order. *(traces_to: BRD §36)*
- **FR-MSG-005**: Where a user has multiple registered devices, the system shall synchronize only missing/required information between them, not a full re-sync. *(traces_to: BRD §37)*
- **FR-MSG-006**: The system shall continue functioning without Firebase; when connectivity returns, it shall exchange synchronization metadata, identify missing information, synchronize, and resolve conflicts. *(traces_to: BRD §38)*
- **FR-MSG-007**: When resolving conflicts, the system shall favor the more security-restrictive state per: BLOCK > TRUST, LOCATION-OFF > LOCATION-ON, REVOKED > ACTIVE, REMOVED > MEMBER. *(traces_to: BRD §39)*
- **FR-MSG-008**: The system shall represent security-sensitive relationship changes (TRUST, BLOCK, UNBLOCK, REMOVE-TRUST, REVOKE-DEVICE) as discrete events/operations, for predictable synchronization across devices. *(traces_to: BRD §40)*

## FR-SEC — Security

- **FR-SEC-001**: The system shall end-to-end encrypt all private communication; only authorized endpoints shall be able to decrypt it. *(traces_to: BRD §41)*
- **FR-SEC-002**: Relay devices, Firebase, network infrastructure, and other intermediary devices shall not have access to plaintext communication content. *(traces_to: BRD §41)*
- **FR-SEC-003**: The system shall protect against device impersonation, man-in-the-middle attacks, replay attacks, packet modification, malicious relay behavior, flooding, unauthorized synchronization, stolen-device scenarios, compromised devices, fake devices, and Sybil-style abuse. *(traces_to: BRD §42)*
- **FR-SEC-004**: The system shall implement end-to-end encryption using a defined cryptographic protocol family (key-exchange + ratchet scheme). *(traces_to: BRD §66.2 defers the library, not the protocol shape)* **[NEEDS DECISION — Q-ARCH-003, feeds ADR]**

## FR-LOC — Location Sharing

- **FR-LOC-001**: The system shall provide a global location-sharing on/off setting. *(traces_to: BRD §43)*
- **FR-LOC-002**: The system shall let users control location sharing per individual user, in addition to the global setting. *(traces_to: BRD §43)*
- **FR-LOC-003**: The system shall show a user's location only when the relationship is connected, the user is authorized, global location sharing is enabled, AND per-user location sharing is enabled for that relationship — if any condition fails, location shall be unavailable. *(traces_to: BRD §44)*
- **FR-LOC-004**: Blocked users shall not be able to access each other's location; location information shall be encrypted; Firebase shall not become a permanent location-history store. *(traces_to: BRD §45)*
- **FR-LOC-005**: If live location is unavailable, then the system may show the last known location with a visible timestamp, and shall never represent stale location as live. *(traces_to: BRD §46)*

## FR-NOTIFY — Notifications

- **FR-NOTIFY-001**: The system shall support notifications for new messages, voice messages, PTT, incoming calls, connection requests, trust requests, group events, security events, and storage warnings. *(traces_to: BRD §47)*
- **FR-NOTIFY-002**: Notification privacy shall be configurable. *(traces_to: BRD §47)*

## FR-PLAT — Platform / Background Operation

- **FR-PLAT-001**: The system shall support background operation — peer discovery, message synchronization, network maintenance, calls, PTT, location sharing — where permitted by Android. *(traces_to: BRD §48)*
- **FR-PLAT-002**: The system shall account for Android Doze, Battery Saver, background execution restrictions, app process termination, and screen lock when performing background operations. *(traces_to: BRD §48)*
- **FR-PLAT-003**: Android-native components shall handle system-sensitive functionality — Bluetooth, nearby devices, Wi-Fi, foreground services, background networking, notifications, microphone, location, system connectivity — with Flutter communicating through defined interfaces. *(traces_to: BRD §49)*

## FR-GROUP — Groups

- **FR-GROUP-001**: The system shall support group roles Owner, Admin, and Member. *(traces_to: BRD §50)*
- **FR-GROUP-002**: The Owner shall be able to rename the group, add members, remove members, assign administrators, transfer ownership, and delete the group. *(traces_to: BRD §50)*
- **FR-GROUP-003**: Admins shall be able to perform permitted group-management actions; Members shall participate in normal communication. *(traces_to: BRD §50)*
- **FR-GROUP-004**: When group membership changes, the system shall rotate the group's encryption keys. *(traces_to: BRD §51)*
- **FR-GROUP-005**: A removed group member shall not be able to decrypt future group communication. *(traces_to: BRD §51)*
- **FR-GROUP-006**: A newly added group member shall not automatically gain access to historical group communication. *(traces_to: BRD §51)* **[NEEDS MECHANISM if an exception path is wanted — see Q-FUNC-006; v1 default per that question's answer is "no exception path exists"]**

## FR-CALL — Voice Calls

- **FR-CALL-001**: The system shall support secure voice calls using the same dynamic routing architecture as other communication. *(traces_to: BRD §52)*
- **FR-CALL-002**: Calls shall receive higher network priority than non-real-time synchronization. *(traces_to: BRD §52)*
- **FR-CALL-003**: When a better connection becomes available during a call, the system shall evaluate it, establish and validate it, migrate the call, and then terminate the old route — minimizing call interruption. *(traces_to: BRD §53)*

## FR-FB — Firebase Data Boundary

- **FR-FB-001**: Firebase may store authentication information, user identity, device registry metadata, device public identity information, trust metadata, block metadata, user configuration, revocation information, push notification information, and application version policy. *(traces_to: BRD §54)*
- **FR-FB-002**: Firebase shall not store message plaintext, voice recordings, call recordings, private keys, session keys, or permanent private location history. *(traces_to: BRD §54)*

## FR-RECOVER — Account Recovery

- **FR-RECOVER-001**: A new device shall be registerable using the user's authenticated account; where possible, an existing trusted device shall authorize the new device's enrollment. *(traces_to: BRD §55)*
- **FR-RECOVER-002**: If all cryptographic keys are permanently lost, then encrypted historical content shall not be recoverable — this is an intentional security property, not a defect. *(traces_to: BRD §55)*

## FR-ABUSE — Abuse Prevention

- **FR-ABUSE-001**: The system shall implement controls against connection-request spam, message flooding, relay abuse, storage exhaustion, group-invitation spam, device-registration abuse, battery-exhaustion attacks, and network-resource abuse. *(traces_to: BRD §56)*

## FR-DIAG — Diagnostics

- **FR-DIAG-001**: Diagnostics shall provide useful operational information without exposing sensitive content. *(traces_to: BRD §57)*
- **FR-DIAG-002**: The system shall never log message plaintext, private keys, session keys, voice content, sensitive personal data, or sensitive location data. *(traces_to: BRD §57)*

## FR-VER — Protocol & Application Versioning

- **FR-VER-001**: Communication protocols shall include version information (app version, build, protocol version, crypto version, database version); devices shall negotiate compatible communication features. *(traces_to: BRD §58)*
- **FR-VER-002**: If a protocol is no longer compatible or secure, then the system may reject the connection. *(traces_to: BRD §58)*
- **FR-VER-003**: Application updates shall migrate database schema, local configuration, cryptographic structures, communication protocol, and synchronization metadata without intentionally destroying existing local conversations. *(traces_to: BRD §59)*
- **FR-VER-004**: The system shall provide a testing/simulation framework capable of simulating routes, battery changes, latency, bandwidth, packet loss, device failure, transport availability, relay failure, network partitions, route migration, synchronization, and security policy changes. *(traces_to: BRD §60)*
- **FR-VER-005**: The application shall support version states UP_TO_DATE, UPDATE_AVAILABLE, and UPDATE_REQUIRED, driven primarily by build-number comparison against a remotely configurable minimum-supported-build policy. *(traces_to: BRD §61.1–4)*
- **FR-VER-006**: When the installed version is UPDATE_REQUIRED, the system shall block application communication and present a non-dismissible mandatory update prompt directing the user to Google Play. *(traces_to: BRD §61.5)*
- **FR-VER-007**: Where supported, the system shall use Google Play's in-app update mechanism for critical updates (Immediate Update flow); the system shall never silently download or install arbitrary APK files. *(traces_to: BRD §61.6)*
- **FR-VER-008**: The system shall cache the last known valid version policy locally for offline use; on reconnect it shall fetch the current policy and re-evaluate. *(traces_to: BRD §61.7–8)*
- **FR-VER-009**: Mandatory application updates shall not delete local messages, voice messages, call recordings, attachments, user settings, or conversation history. *(traces_to: BRD §61.9)*
- **FR-VER-010**: The system shall support emergency minimum-version enforcement, capable of retroactively marking all builds below a newly published minimum as unsupported. *(traces_to: BRD §61.11)*
- **FR-VER-011**: Where appropriate, version policy shall be cryptographically signed and verified by the application, to protect against unauthorized modification. *(traces_to: BRD §61.12)*

## FR-UI — Design System & Interaction (see also design/screens/*.md, the binding contracts)

- **FR-UI-001**: The application shall use Material 3 exclusively as its design system, with no competing custom visual language. *(traces_to: documentation/Design.md §2.1)*
- **FR-UI-002**: The application shall support light, dark, and system theme, generated via a seeded ColorScheme. *(traces_to: documentation/Design.md §4–5)*
- **FR-UI-003**: Navigation shall adapt by width class — NavigationBar (compact), NavigationRail (medium), NavigationDrawer (expanded). *(traces_to: documentation/Design.md §11–13)*
- **FR-UI-004**: The default view shall communicate connectivity state simply ("You're connected"); advanced technical detail (route, transport, latency) shall be available one tap away, not shown by default. *(traces_to: documentation/Design.md §100–103, §132)*
- **FR-UI-005**: All visible strings shall come from localization resources; the UI shall support RTL layout via logical (not literal left/right) padding. *(traces_to: documentation/Design.md §111–112)*

---

## NFR — Non-Functional Requirements

- **NFR-SEC-001**: The system shall provide strong end-to-end security and privacy for all private communication. *(traces_to: BRD §62.1)*
- **NFR-REL-001**: The system should automatically recover from temporary network failures whenever possible. *(traces_to: BRD §62.2)*
- **NFR-PERF-001**: The application should remain responsive during synchronization, file transfer, route migration, background processing, and database operations. *(traces_to: BRD §62.3)* **[NEEDS NUMBER — no latency/frame-time target given anywhere]**
- **NFR-BATT-001**: The system should minimize unnecessary network scanning, GPS operations, synchronization, CPU usage, and network traffic — but battery efficiency shall never override reliability or communication requirements. *(traces_to: BRD §62.4)* **[NEEDS NUMBER — no battery-drain target given]**
- **NFR-SCALE-001**: The architecture should support multiple devices per user, multiple groups, multiple relay paths, large local conversation histories, and future communication features. *(traces_to: BRD §62.5)* **[NEEDS NUMBER — no concrete scale ceiling given; see A-002 for the placeholder-default approach]**
- **NFR-PRIV-001**: Private data should remain local whenever practical; central services should store only what's required for authentication, device management, synchronization, configuration, security, and notifications. *(traces_to: BRD §62.6, FR-FB-001/002)*

---

## Traceability

Every FR/NFR above traces to a BRD section (`traces_to:`). Reverse traceability
(BRD section → FR id) and the full requirement → epic → task → code → test
chain is computed by `skills/traceability` once epics/tasks exist — not
duplicated here.

## Open items feeding this SRS

Six requirements above are marked `[NEEDS NUMBER]`, `[NEEDS FORMULA]`, or
`[NEEDS DECISION]` — these map directly to `spec/questions.md`'s open/assumed
items (Q-ARCH-003, Q-ARCH-004, Q-FUNC-005, Q-FUNC-006) and to the NFR
numeric-target gap flagged in `spec/knowledge-map.yaml` risk R-003. They do not
block genesis's foundational ADRs, but they will block task-sharding for the
specific epics that touch them (routing/relay, groups/encryption) until
answered.
