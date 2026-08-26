# NEXORA

## Connect beyond the network

# Business Requirements Document (BRD)

**Product Name:** NEXORA
**Product Tagline:** Connect beyond the network
**Document Type:** Business Requirements Document (BRD)
**Document Version:** 1.0
**Status:** Draft — Architecture Decisions Consolidated
**Primary Platform:** Android-first
**Application Framework:** Flutter
**Authentication:** Google Authentication
**Backend:** Firebase
**Communication Model:** Offline-first, peer-to-peer, multi-hop mesh
**Connectivity Model:** Transport-agnostic
**Security Model:** End-to-end encrypted communication

---

# Table of Contents

- [NEXORA](#nexora)
  - [Connect beyond the network](#connect-beyond-the-network)
- [Business Requirements Document (BRD)](#business-requirements-document-brd)
- [Table of Contents](#table-of-contents)
- [1. Executive Summary](#1-executive-summary)
- [2. Business Objectives](#2-business-objectives)
- [3. Core Principles](#3-core-principles)
  - [3.1 Offline First](#31-offline-first)
  - [3.2 Security First](#32-security-first)
  - [3.3 Transport Agnostic](#33-transport-agnostic)
  - [3.4 Cost-Aware Routing](#34-cost-aware-routing)
  - [3.5 User-Controlled Privacy](#35-user-controlled-privacy)
- [4. Product Scope](#4-product-scope)
- [5. User Authentication](#5-user-authentication)
- [6. Device Identity](#6-device-identity)
- [7. Persistent Device Relationships](#7-persistent-device-relationships)
- [8. Connection Request System](#8-connection-request-system)
- [9. Trusted Device Auto-Accept](#9-trusted-device-auto-accept)
- [10. Bidirectional Authorization](#10-bidirectional-authorization)
- [11. User Relationship Controls](#11-user-relationship-controls)
- [12. Blocking](#12-blocking)
- [13. Blocked Users in Groups](#13-blocked-users-in-groups)
- [14. Group Encryption and Blocking](#14-group-encryption-and-blocking)
- [15. Communication Types](#15-communication-types)
  - [Personal Communication](#personal-communication)
  - [Group Communication](#group-communication)
- [16. Local Conversation Storage](#16-local-conversation-storage)
- [17. Local Voice Storage](#17-local-voice-storage)
- [18. Voice Quality](#18-voice-quality)
- [19. Local Storage Management](#19-local-storage-management)
- [20. Smart Storage Management](#20-smart-storage-management)
- [21. Storage Warning](#21-storage-warning)
- [22. Storage Decision Details](#22-storage-decision-details)
- [23. Device Discovery](#23-device-discovery)
- [24. Network Connectivity](#24-network-connectivity)
- [25. Multi-Hop Communication](#25-multi-hop-communication)
- [26. Store-and-Forward](#26-store-and-forward)
- [27. Relay Security](#27-relay-security)
- [28. Relay Storage](#28-relay-storage)
- [29. Dynamic Routing](#29-dynamic-routing)
- [30. Connection Migration](#30-connection-migration)
- [31. Routing Cost](#31-routing-cost)
    - [Text](#text)
    - [File Transfer](#file-transfer)
    - [Voice Calls](#voice-calls)
    - [Discovery](#discovery)
- [32. Route Failure](#32-route-failure)
- [33. Offline Messaging](#33-offline-messaging)
- [34. Delivery States](#34-delivery-states)
- [35. Duplicate Protection](#35-duplicate-protection)
- [36. Message Ordering](#36-message-ordering)
- [37. Multi-Device Synchronization](#37-multi-device-synchronization)
- [38. Offline Synchronization](#38-offline-synchronization)
- [39. Conflict Resolution](#39-conflict-resolution)
- [40. Event-Based Security Changes](#40-event-based-security-changes)
- [41. End-to-End Encryption](#41-end-to-end-encryption)
- [42. Security Threat Protection](#42-security-threat-protection)
- [43. Location Sharing](#43-location-sharing)
- [44. Location Eligibility](#44-location-eligibility)
- [45. Location Privacy](#45-location-privacy)
- [46. Last Known Location](#46-last-known-location)
- [47. Notification System](#47-notification-system)
- [48. Background Operation](#48-background-operation)
- [49. Android Integration](#49-android-integration)
- [50. Groups](#50-groups)
- [51. Group Membership Changes](#51-group-membership-changes)
- [52. Voice Calls](#52-voice-calls)
- [53. Call Route Migration](#53-call-route-migration)
- [54. Firebase Architecture](#54-firebase-architecture)
- [55. Account Recovery](#55-account-recovery)
- [56. Abuse Prevention](#56-abuse-prevention)
- [57. Diagnostics](#57-diagnostics)
- [58. Protocol Versioning](#58-protocol-versioning)
- [59. Application Updates](#59-application-updates)
- [60. Testing and Simulation](#60-testing-and-simulation)
- [61. Application Version Management](#61-application-version-management)
  - [61.1 Objectives](#611-objectives)
  - [61.2 Version States](#612-version-states)
    - [Up to Date](#up-to-date)
    - [Update Available](#update-available)
    - [Update Required](#update-required)
  - [61.3 Version Policy](#613-version-policy)
  - [61.4 Build Number Enforcement](#614-build-number-enforcement)
  - [61.5 Mandatory Update](#615-mandatory-update)
  - [61.6 Google Play Update](#616-google-play-update)
  - [61.7 Offline Version Policy](#617-offline-version-policy)
  - [61.8 Important Offline Limitation](#618-important-offline-limitation)
  - [61.9 Local Data Preservation](#619-local-data-preservation)
  - [61.10 Version Categories](#6110-version-categories)
  - [61.11 Emergency Security Update](#6111-emergency-security-update)
  - [61.12 Version Policy Security](#6112-version-policy-security)
- [62. Non-Functional Requirements](#62-non-functional-requirements)
  - [62.1 Security](#621-security)
  - [62.2 Reliability](#622-reliability)
  - [62.3 Performance](#623-performance)
  - [62.4 Battery](#624-battery)
  - [62.5 Scalability](#625-scalability)
  - [62.6 Privacy](#626-privacy)
- [63. High-Level User Flow](#63-high-level-user-flow)
- [64. Major Business Rules](#64-major-business-rules)
- [65. High-Level System Architecture](#65-high-level-system-architecture)
- [66. BRD Scope](#66-brd-scope)
  - [66.1 In Scope](#661-in-scope)
  - [66.2 Out of Scope for the BRD](#662-out-of-scope-for-the-brd)
- [67. Product Vision](#67-product-vision)
- [68. Future Technical Design Phase](#68-future-technical-design-phase)
- [Final Product Definition](#final-product-definition)
  - [NEXORA](#nexora-1)
    - [Connect beyond the network](#connect-beyond-the-network-1)

---

# 1. Executive Summary

NEXORA is a secure, offline-first communication platform designed to allow users to communicate even when traditional Internet connectivity is unavailable or unreliable.

NEXORA enables devices to communicate directly or through other participating devices using a dynamic peer-to-peer and multi-hop network.

The system is transport-agnostic and may use:

- Bluetooth
- Wi-Fi
- Wi-Fi Direct
- Local networks
- Internet
- Other compatible communication transports

No transport is permanently restricted to a specific communication feature.

For example, if Bluetooth is the only available connection between two devices, Bluetooth may be used for:

- Messaging
- Voice messages
- PTT
- Voice calls
- File transfer
- Synchronization

even if the connection is slower or less efficient.

NEXORA dynamically evaluates available communication routes based on multiple factors such as:

- Battery consumption
- Latency
- Reliability
- Bandwidth
- Hop count
- Stability
- Congestion
- Packet loss
- Traffic type

Battery consumption is important but shall never be the sole routing criterion.

NEXORA also provides:

- Google authentication
- Firebase-backed device and relationship information
- Trusted users/devices
- Automatic trust-based connection acceptance
- User blocking
- Group communication
- End-to-end encrypted communication
- Offline messaging
- Store-and-forward communication
- Dynamic route migration
- Local conversation storage
- Voice message and call recording
- Live location sharing
- Multi-device synchronization
- Intelligent storage management
- Application version enforcement

---

# 2. Business Objectives

NEXORA shall provide:

1. Reliable communication without continuous Internet connectivity.
2. Secure end-to-end encrypted communication.
3. Dynamic use of available network paths.
4. Automatic migration between communication routes.
5. Offline-first functionality.
6. Strong user-controlled privacy.
7. Persistent user/device relationships.
8. Local-first conversation storage.
9. Efficient battery and network usage.
10. Resilient communication during network failures.
11. Controlled application version compatibility.
12. A scalable architecture capable of supporting future communication features.

---

# 3. Core Principles

## 3.1 Offline First

NEXORA must remain useful when:

- Internet is unavailable.
- Firebase is unavailable.
- A peer is temporarily unavailable.
- Network connectivity changes.
- A route disappears.
- A network becomes partitioned.

---

## 3.2 Security First

All private communication must be end-to-end encrypted.

Intermediate relay devices must not be able to decrypt message contents.

Firebase must not have access to private conversation content.

---

## 3.3 Transport Agnostic

NEXORA must not assume:

```text
Bluetooth = Discovery only
Wi-Fi = Data only
Internet = Calls only
```

Instead:

> Any available transport may carry any supported communication type when technically possible.

---

## 3.4 Cost-Aware Routing

Routing decisions must consider multiple factors.

Battery consumption alone must never determine the best route.

---

## 3.5 User-Controlled Privacy

Users control:

* Trusted users
* Trusted devices
* Blocked users
* Location sharing
* Per-user location access
* Storage management
* Notification privacy
* Account/device visibility

---

# 4. Product Scope

NEXORA includes:

* User authentication
* Device identity
* Device relationships
* Trust management
* Blocking
* Personal chat
* Group chat
* PTT
* Voice messages
* Voice calls
* Group calls
* Attachments
* Live location
* Offline communication
* Multi-hop routing
* Relay communication
* Store-and-forward
* Dynamic route migration
* Local data storage
* Storage management
* Synchronization
* Firebase integration
* Background operation
* Security management
* Application version management

---

# 5. User Authentication

Users shall authenticate using Google Authentication.

Firebase Authentication will maintain the user's identity.

Authentication is used to establish the user's account identity but does not replace device-level cryptographic identity.

---

# 6. Device Identity

Every application installation shall have its own unique cryptographic device identity.

One user may have multiple devices.

Example:

```text
User A

├── Phone A1
├── Tablet A2
└── Other Device A3
```

Each device maintains its own local state and cryptographic identity.

---

# 7. Persistent Device Relationships

When A and B establish a trusted relationship:

```text
A <-> B
```

the relationship shall be stored persistently.

Firebase shall maintain appropriate relationship metadata.

If the application is uninstalled and later reinstalled, the user should not unnecessarily need to recreate existing relationships.

However, security-sensitive device identity may still require re-verification or re-enrollment.

---

# 8. Connection Request System

A may send a connection request to B.

```text
A -> B
```

B evaluates its own configuration.

Possible states include:

* Trusted
* Allowed
* Unknown
* Blocked

The receiving device independently evaluates whether the connection is permitted.

---

# 9. Trusted Device Auto-Accept

If B has configured A as trusted:

```text
A -> B

B recognizes A as trusted

        ↓

Auto Accept
```

The normal authentication flow may be skipped when the existing trusted relationship is valid.

---

# 10. Bidirectional Authorization

Connection authorization is evaluated independently by both sides.

Example:

```text
A trusts B

B blocks A
```

Result:

```text
Connection rejected
```

A allowing B is not sufficient.

B allowing A is also required.

---

# 11. User Relationship Controls

Users may control relationship behavior through configurable settings.

Possible controls include:

* Automatically accept trusted devices
* Automatically accept specific users
* Require authentication for unknown users
* Block specific users
* Allow communication
* Disable communication
* Control location access

Relevant relationship configuration may be synchronized through Firebase.

---

# 12. Blocking

Blocking is a strong communication boundary.

If:

```text
A blocks B
```

A and B cannot directly communicate.

Blocking affects all applicable communication functionality.

---

# 13. Blocked Users in Groups

If A blocks B and both are members of the same group:

```text
Group

A
B
C
```

where C is the group owner:

A and B remain group members, but A and B are completely invisible to one another.

A and B cannot:

* Read each other's messages.
* See each other's activities.
* See each other's presence.
* See each other's location.
* Communicate directly.
* See interaction originating from the blocked member.

---

# 14. Group Encryption and Blocking

Group communication is encrypted.

Blocked members must not possess the required cryptographic material to decrypt communication from the blocked member.

Therefore:

```text
A cannot decrypt B
B cannot decrypt A
```

even though both are members of the same group.

---

# 15. Communication Types

## Personal Communication

NEXORA shall support:

* Text messages
* Voice messages
* PTT
* Voice calls
* Attachments
* Location sharing

## Group Communication

NEXORA shall support:

* Text
* PTT
* Voice calls
* Attachments
* Group events

---

# 16. Local Conversation Storage

Conversation history shall be stored locally.

The UI shall provide separate areas for:

```text
Personal

Groups
```

Example:

```text
Conversations

Personal
├── User A
├── User B
└── User C

Groups
├── Family
├── Work
└── Friends
```

---

# 17. Local Voice Storage

The application shall store supported conversation audio locally.

This includes:

* Voice messages
* PTT recordings
* Call recordings

Local storage is device-specific.

---

# 18. Voice Quality

Voice communication shall prioritize battery efficiency.

The default voice profile shall be optimized for:

* Low CPU usage
* Low battery consumption
* Efficient network usage
* Practical voice quality

---

# 19. Local Storage Management

NEXORA communication data may consume significant local storage.

The user shall be able to configure storage management.

Available modes:

1. Smart Mode
2. Delete data older than X days
3. Delete old data when storage exceeds X MB

Default:

```text
Smart Mode
```

---

# 20. Smart Storage Management

Smart Mode shall automatically determine which data should be removed.

Possible factors:

* Age
* Size
* File type
* Access frequency
* Conversation activity
* Storage pressure
* Temporary status
* Importance

Example:

```text
Will remove:

Voice messages       820 MB
Older than 45 days

Call recordings      620 MB
Older than 60 days

Old attachments      310 MB
Rarely accessed

Temporary cache       50 MB
No longer required
```

---

# 21. Storage Warning

The main dashboard shall show storage warnings when appropriate.

Example:

```text
Smart Mode - Older than 10 days
```

The warning is informational.

The user does not need to press a "Clean Now" button.

---

# 22. Storage Decision Details

Expanding the warning shall show the decisions made by the selected storage policy.

Example:

```text
Smart Mode

Will remove:

Voice messages       820 MB
Older than 45 days

Call recordings      620 MB
Older than 60 days

Old attachments      310 MB
Rarely accessed

Temporary cache       50 MB
No longer required

Why:

Storage pressure is high and these items
have low recent usage.
```

The application shall explain why the storage management function selected each category.

---

# 23. Device Discovery

NEXORA shall support discovery using available technologies.

Potential mechanisms:

* Bluetooth
* Wi-Fi
* Wi-Fi Direct
* Local network
* Internet-assisted discovery
* Peer-assisted discovery

Discovery does not automatically grant authorization.

---

# 24. Network Connectivity

NEXORA shall support multiple communication transports.

Potential transports:

* Bluetooth
* Wi-Fi Direct
* Local Wi-Fi
* Internet
* Other compatible transports

No transport shall be permanently restricted to a particular feature.

---

# 25. Multi-Hop Communication

A and B do not need a direct connection.

Example:

```text
A -> C -> D -> B
```

C and D may act as relay devices.

---

# 26. Store-and-Forward

When the destination is temporarily unavailable, an intermediary device may temporarily store encrypted packets.

Example:

```text
A -> C

B unavailable

C temporarily stores encrypted data
```

When B becomes reachable:

```text
C -> B
```

The data is forwarded.

---

# 27. Relay Security

Relay devices must not decrypt end-to-end encrypted communication.

A relay can process:

* Routing information
* Encrypted payloads
* Packet metadata required for delivery
* Temporary storage information

A relay cannot access plaintext conversation content.

---

# 28. Relay Storage

Relay data is temporary.

Relay packets should contain metadata such as:

* Packet ID
* Destination
* Priority
* Size
* Creation time
* Expiration time
* Delivery state

After successful delivery, the relay copy should be removed when no longer required.

---

# 29. Dynamic Routing

NEXORA shall continuously evaluate available routes.

Example:

```text
A <-> B

Current:
Bluetooth
```

Later:

```text
Wi-Fi becomes available
```

The system evaluates whether Wi-Fi provides a sufficiently better route.

---

# 30. Connection Migration

When a better route is discovered:

```text
1. Discover better connection
2. Calculate route cost
3. Establish new connection
4. Validate new connection
5. Move traffic to new connection
6. Terminate old connection
```

The old connection must not be terminated before the new connection is ready.

Migration should only occur when the improvement justifies the transition cost.

---

# 31. Routing Cost

Route cost shall consider:

* Battery
* Latency
* Reliability
* Bandwidth
* Hop count
* Congestion
* Stability
* Packet loss
* Traffic type

Different communication types may prioritize different factors.

### Text

Prioritize:

* Reliability
* Battery
* Bandwidth

### File Transfer

Prioritize:

* Bandwidth
* Reliability
* Battery

### Voice Calls

Prioritize:

* Latency
* Jitter
* Packet loss
* Stability
* Battery

### Discovery

Prioritize:

* Battery efficiency

---

# 32. Route Failure

When a route fails:

```text
Detect failure
      |
      v
Search alternatives
      |
      +---- Alternative ----> Migrate
      |
      +---- No alternative --> Queue / Retry
```

The system should recover automatically whenever possible.

---

# 33. Offline Messaging

Messages created while offline shall be saved locally.

```text
Create message
      |
      v
Save locally
      |
      v
Outgoing queue
      |
      v
Wait for route
      |
      v
Send
```

---

# 34. Delivery States

Messages may use states such as:

* Queued
* Sent
* Accepted
* Delivered
* Stored
* Read
* Failed

The exact UI representation may evolve.

---

# 35. Duplicate Protection

Every message and network operation shall have a unique identifier.

Duplicate packets must not create duplicate messages.

---

# 36. Message Ordering

The system shall maintain logical message ordering even when network packets arrive out of order.

---

# 37. Multi-Device Synchronization

A user may have multiple registered devices.

Example:

```text
User A

A1
A2
A3
```

Devices shall synchronize relevant missing information.

Only required data should be transferred.

---

# 38. Offline Synchronization

NEXORA must continue functioning without Firebase.

When connectivity returns:

```text
Reconnect
   |
   v
Exchange synchronization metadata
   |
   v
Identify missing information
   |
   v
Synchronize
   |
   v
Resolve conflicts
```

---

# 39. Conflict Resolution

Conflicts shall be resolved according to object type and security priority.

Security-sensitive states should favor the more restrictive state.

Examples:

```text
BLOCK > TRUST

LOCATION OFF > LOCATION ON

REVOKED > ACTIVE

REMOVED > MEMBER
```

---

# 40. Event-Based Security Changes

Security-sensitive relationship changes shall be represented as events or operations.

Examples:

```text
TRUST B
BLOCK B
UNBLOCK B
REMOVE TRUST B
REVOKE DEVICE
```

This provides predictable synchronization across devices.

---

# 41. End-to-End Encryption

All private communication shall be end-to-end encrypted.

Only authorized endpoints may decrypt communication.

The following entities must not have access to plaintext:

* Relay devices
* Firebase
* Network infrastructure
* Other intermediary devices

---

# 42. Security Threat Protection

NEXORA shall protect against:

* Device impersonation
* Man-in-the-middle attacks
* Replay attacks
* Packet modification
* Malicious relay behavior
* Flooding
* Unauthorized synchronization
* Stolen-device scenarios
* Compromised devices
* Fake devices
* Sybil-style abuse

---

# 43. Location Sharing

Users may enable or disable live location sharing.

There shall be a global setting:

```text
Location Sharing

ON
OFF
```

Users may also control location sharing per user.

Example:

```text
User B -> Allowed
User C -> Disabled
User D -> Allowed
```

---

# 44. Location Eligibility

Location may be visible only when all required conditions are satisfied:

```text
Connected relationship
        +
User is authorized
        +
Global location sharing enabled
        +
Per-user location sharing enabled
```

If any required condition fails:

```text
Location unavailable
```

---

# 45. Location Privacy

Blocked users cannot access each other's location.

Location information shall be encrypted.

Firebase shall not become the permanent location-history database.

---

# 46. Last Known Location

If live location is unavailable, NEXORA may show the last known location.

The timestamp must be visible.

Example:

```text
Last known location

Dhaka

Updated 12 minutes ago
```

The application must not represent stale location as live.

---

# 47. Notification System

Notifications shall support:

* New messages
* Voice messages
* PTT
* Incoming calls
* Connection requests
* Trust requests
* Group events
* Security events
* Storage warnings

Notification privacy should be configurable.

---

# 48. Background Operation

NEXORA shall support background functionality where permitted by Android.

Potential background operations include:

* Peer discovery
* Message synchronization
* Network maintenance
* Calls
* PTT
* Location sharing

The system must account for:

* Android Doze
* Battery Saver
* Background restrictions
* App process termination
* Screen lock

---

# 49. Android Integration

Android-native components shall handle system-sensitive functionality where required.

Potential responsibilities include:

* Bluetooth
* Nearby devices
* Wi-Fi
* Foreground services
* Background networking
* Notifications
* Microphone
* Location
* System connectivity

Flutter shall communicate with native components through defined interfaces.

---

# 50. Groups

Groups shall support:

```text
Owner
Admin
Member
```

The owner may:

* Rename the group
* Add members
* Remove members
* Assign administrators
* Transfer ownership
* Delete the group

Admins may perform permitted group management actions.

Members participate in normal communication.

---

# 51. Group Membership Changes

When membership changes, group encryption keys shall be appropriately rotated.

A removed member must not be able to decrypt future group communication.

A newly added member must not automatically gain access to historical communication unless explicitly permitted by the system.

---

# 52. Voice Calls

NEXORA shall support secure voice calls.

Call communication uses the same dynamic routing architecture.

Calls should receive higher network priority than non-real-time synchronization.

---

# 53. Call Route Migration

If a better connection becomes available during a call:

```text
Current route
     |
     v
Evaluate new route
     |
     v
New route sufficiently better?
     |
     v
Establish new route
     |
     v
Migrate call
     |
     v
Terminate old route
```

The objective is to minimize call interruption.

---

# 54. Firebase Architecture

Firebase may store:

* Authentication information
* User identity
* Device registry metadata
* Device public identity information
* Trust metadata
* Block metadata
* User configuration
* Revocation information
* Push notification information
* Application version policy

Firebase must not store private communication plaintext.

Firebase should not store:

* Message plaintext
* Voice recordings
* Call recordings
* Private keys
* Session keys
* Permanent private location history

---

# 55. Account Recovery

A new device may be registered using the user's authenticated account.

Where possible:

```text
Existing trusted device
        |
        v
Authorize new device
        |
        v
New device enrolled
```

If all cryptographic keys are permanently lost, encrypted historical content may not be recoverable.

This is an intentional security property.

---

# 56. Abuse Prevention

NEXORA shall implement controls against:

* Connection request spam
* Message flooding
* Relay abuse
* Storage exhaustion
* Group invitation spam
* Device registration abuse
* Battery exhaustion attacks
* Network resource abuse

---

# 57. Diagnostics

Diagnostics must provide useful operational information without exposing sensitive content.

Allowed example:

```text
Route migrated

Bluetooth -> Wi-Fi

Reason:
Improved route cost

Latency:
X ms

Packet loss:
X%

Migration:
Successful
```

The system must never log:

* Message plaintext
* Private keys
* Session keys
* Voice content
* Sensitive personal data
* Sensitive location data

---

# 58. Protocol Versioning

Communication protocols shall include version information.

Example:

```text
App Version:
1.8.0

Build:
108

Protocol:
3

Crypto:
2

Database:
7
```

Devices negotiate compatible communication features.

If a protocol is no longer compatible or secure, the connection may be rejected.

---

# 59. Application Updates

Application updates shall support migration of:

* Database schema
* Local configuration
* Cryptographic structures
* Communication protocol
* Synchronization metadata

Updates must not intentionally destroy existing local conversations.

---

# 60. Testing and Simulation

NEXORA shall have a testing/simulation framework capable of simulating:

* Multiple routes
* Battery changes
* Latency
* Bandwidth
* Packet loss
* Device failure
* Bluetooth availability
* Wi-Fi availability
* Internet availability
* Relay failure
* Network partitions
* Route migration
* Synchronization
* Security policy changes

Example:

```text
A -> B -> C
A -> D -> C
```

If:

```text
Route A-B-C = Cost 80
Route A-D-C = Cost 45
```

the routing engine should select:

```text
A-D-C
```

If D's battery becomes critically low, the routing engine should reevaluate and potentially migrate back.

---

# 61. Application Version Management

Application version management is a mandatory part of the NEXORA architecture.

## 61.1 Objectives

NEXORA must be able to:

* Enforce a minimum supported application version.
* Inform users about available updates.
* Force updates for obsolete or insecure versions.
* Prevent unsupported versions from communicating.
* Allow emergency security updates.
* Maintain compatibility between application and communication protocol versions.

---

## 61.2 Version States

The application shall support:

```text
UP_TO_DATE

UPDATE_AVAILABLE

UPDATE_REQUIRED
```

### Up to Date

```text
Installed Build: 108
Latest Build:    108

Continue normally.
```

### Update Available

```text
Installed Build: 107
Latest Build:    108

Show optional update.
User may continue.
```

### Update Required

```text
Installed Build: 104
Minimum Build:   105

Application communication is blocked.
User must update.
```

---

## 61.3 Version Policy

Firebase shall maintain a remotely configurable version policy.

Example:

```json
{
  "minimumSupportedBuild": 105,
  "latestBuild": 108,
  "minimumSupportedVersion": "1.5.0",
  "latestVersion": "1.8.0",
  "minimumProtocolVersion": 3,
  "latestProtocolVersion": 3,
  "maintenanceMode": false
}
```

The actual production structure may evolve.

---

## 61.4 Build Number Enforcement

The build number shall be the primary enforcement value.

Example:

```text
Version: 1.5.0
Build:   105
```

The system evaluates:

```text
currentBuild < minimumSupportedBuild
```

If true:

```text
UPDATE_REQUIRED
```

---

## 61.5 Mandatory Update

Mandatory updates shall not be dismissible.

Example:

```text
+--------------------------------+
|                                |
|        Update Required         |
|                                |
| This version of NEXORA is no   |
| longer supported.              |
|                                |
| Please update to continue      |
| using NEXORA.                  |
|                                |
|       [ Update NEXORA ]        |
|                                |
+--------------------------------+
```

The user must update through Google Play.

---

## 61.6 Google Play Update

Where supported, NEXORA shall use Google's Play in-app update mechanism.

Critical updates may use the Immediate Update flow.

The application must not attempt to silently download and install arbitrary APK files.

---

## 61.7 Offline Version Policy

Because NEXORA is offline-first, the application shall cache the last known valid version policy locally.

Example:

```text
Last known policy:

Minimum Build: 105
Latest Build:  108
Fetched:       <timestamp>
```

If Firebase is temporarily unavailable:

```text
Use last known policy.
```

---

## 61.8 Important Offline Limitation

A device cannot be remotely forced to update while it has absolutely no communication path to the policy authority.

Therefore:

```text
Offline
   |
   v
Use last known policy
```

When connectivity returns:

```text
Reconnect
   |
   v
Fetch current policy
   |
   v
Evaluate version
```

If the installed version is unsupported:

```text
Block communication
Require update
```

---

## 61.9 Local Data Preservation

Mandatory application updates must not delete local:

* Messages
* Voice messages
* Call recordings
* Attachments
* User settings
* Conversation history

Local data must remain available after the update.

---

## 61.10 Version Categories

NEXORA shall track:

```text
Application Version
Build Number
Protocol Version
Cryptographic Version
Database Schema Version
```

These versions have different purposes.

---

## 61.11 Emergency Security Update

NEXORA shall support emergency minimum-version enforcement.

Example:

```text
Critical vulnerability discovered.

Server policy:

minimumSupportedBuild = 120
```

All builds below 120 become unsupported when they receive the new policy.

---

## 61.12 Version Policy Security

Version policy should be protected against unauthorized modification.

Where appropriate, the policy should be cryptographically signed and verified by the application.

---

# 62. Non-Functional Requirements

## 62.1 Security

NEXORA must provide strong end-to-end security and privacy.

---

## 62.2 Reliability

The system should automatically recover from temporary network failures whenever possible.

---

## 62.3 Performance

The application should remain responsive during:

* Synchronization
* File transfer
* Route migration
* Background processing
* Database operations

---

## 62.4 Battery

The system should minimize unnecessary:

* Network scanning
* GPS operations
* Synchronization
* CPU usage
* Network traffic

Battery efficiency is important but must not override reliability and communication requirements.

---

## 62.5 Scalability

The architecture should support:

* Multiple devices per user
* Multiple groups
* Multiple relay paths
* Large local conversation histories
* Future communication features

---

## 62.6 Privacy

Private data should remain local whenever practical.

Central services should store only the information required for:

* Authentication
* Device management
* Synchronization
* Configuration
* Security
* Notifications

---

# 63. High-Level User Flow

```text
                     Google Login
                          |
                          v
                   Account Created
                          |
                          v
                    Device Setup
                          |
                          v
                  Discover Devices
                          |
                          v
                 Connection Request
                          |
             +------------+------------+
             |                         |
             v                         v
       Trusted Device            Unknown Device
             |                         |
        Auto Accept              Authentication
             |                         |
             +------------+------------+
                          |
                          v
                     Connection
                          |
                          v
                   Secure Channel
                          |
              +-----------+-----------+
              |           |           |
              v           v           v
            Chat         PTT         Call
              |           |           |
              +-----------+-----------+
                          |
                          v
                  Dynamic Routing
                          |
              +-----------+-----------+
              |           |           |
              v           v           v
          Bluetooth      Wi-Fi     Internet
              |           |           |
              +-----------+-----------+
                          |
                          v
                        Relay
                          |
                          v
                     Destination
```

---

# 64. Major Business Rules

| Rule                     | Requirement                                      |
| ------------------------ | ------------------------------------------------ |
| Authentication           | Google Authentication supported                  |
| Account                  | Firebase-backed                                  |
| Device Identity          | Unique cryptographic identity                    |
| Relationships            | Persisted                                        |
| Trust                    | Trusted users/devices can auto-accept            |
| Authorization            | Both sides independently authorize               |
| Block                    | Strong communication boundary                    |
| Group Block              | Blocked users are invisible to each other        |
| Group Encryption         | Blocked members cannot decrypt each other        |
| Encryption               | End-to-end                                       |
| Firebase                 | No private conversation plaintext                |
| Connectivity             | Transport-agnostic                               |
| Bluetooth                | May carry any supported communication            |
| Multi-Hop                | Supported                                        |
| Relay                    | Supported                                        |
| Relay Decryption         | Not permitted                                    |
| Store-and-Forward        | Supported                                        |
| Routing                  | Dynamic                                          |
| Routing Cost             | Multi-factor                                     |
| Battery                  | Never sole routing criterion                     |
| Migration                | Establish new route before terminating old route |
| Offline                  | Supported                                        |
| Messaging                | Locally persisted                                |
| Voice                    | Locally persisted                                |
| Calls                    | Locally recorded                                 |
| Storage                  | User-controlled                                  |
| Storage Default          | Smart Mode                                       |
| Storage Warning          | Informational                                    |
| Location                 | User controlled                                  |
| Location Access          | Trusted/connected users only                     |
| Location Per User        | Supported                                        |
| Location Global Control  | Supported                                        |
| Sync                     | Incremental                                      |
| Conflict                 | Security-aware                                   |
| Groups                   | Owner/Admin/Member                               |
| Group Key Rotation       | Required                                         |
| Calls                    | Secure and route-aware                           |
| Background               | Android-native support where required            |
| Diagnostics              | Privacy-safe                                     |
| Recovery                 | Existing trusted device preferred                |
| Version Control          | Mandatory                                        |
| Minimum Version          | Remotely configurable                            |
| Mandatory Update         | Required                                         |
| Update Source            | Google Play                                      |
| Local Data During Update | Preserved                                        |

---

# 65. High-Level System Architecture

```text
                         +------------------+
                         |  Google Auth     |
                         +--------+---------+
                                  |
                         +--------v---------+
                         |    Firebase      |
                         |                  |
                         | Auth             |
                         | User Metadata   |
                         | Device Metadata |
                         | Trust/Block     |
                         | Settings        |
                         | Version Policy  |
                         +--------+---------+
                                  |
                    +-------------v-------------+
                    | Identity & Authorization |
                    +-------------+-------------+
                                  |
                    +-------------v-------------+
                    | Communication Application |
                    |                           |
                    | Chat                      |
                    | PTT                       |
                    | Calls                     |
                    | Groups                    |
                    | Attachments               |
                    | Location                  |
                    +-------------+-------------+
                                  |
                    +-------------v-------------+
                    |     E2E Encryption        |
                    +-------------+-------------+
                                  |
                    +-------------v-------------+
                    |       Sync Engine         |
                    +-------------+-------------+
                                  |
                    +-------------v-------------+
                    |       Route Engine        |
                    +-------------+-------------+
                                  |
                    +-------------v-------------+
                    |       Relay Engine        |
                    +-------------+-------------+
                                  |
              +-------------------+-------------------+
              |                   |                   |
              v                   v                   v
         Bluetooth             Wi-Fi             Internet
              |                   |                   |
              +-------------------+-------------------+
                                  |
                                  v
                            Peer Devices
```

---

# 66. BRD Scope

## 66.1 In Scope

* Google authentication
* Firebase integration
* Device identity
* Device relationships
* Trust system
* Blocking
* Personal communication
* Group communication
* Text messaging
* Voice messages
* PTT
* Voice calls
* Group calls
* Attachments
* Live location
* Offline operation
* Multi-hop communication
* Relay
* Store-and-forward
* Dynamic routing
* Route migration
* Local storage
* Storage management
* Multi-device synchronization
* Security
* Background processing
* Android integration
* Version management
* Mandatory application updates

---

## 66.2 Out of Scope for the BRD

The BRD does not define exact implementation details such as:

* Exact Flutter packages
* Exact cryptographic library
* Exact database package
* Exact Firebase collection implementation
* Exact Android service implementation
* Exact routing algorithm
* Exact wire protocol
* Exact UI component implementation

These belong in the technical design and system requirements documents.

---

# 67. Product Vision

NEXORA is designed to become:

> **A secure, offline-first communication platform where devices can communicate directly or through other available network paths, automatically select and migrate between connections, and continue communicating even when traditional Internet connectivity is unavailable.**

The core product philosophy is:

```text
                 SECURE
                    +
              OFFLINE-FIRST
                    +
             MESH NETWORKING
                    +
             DYNAMIC ROUTING
                    +
             MULTI-FACTOR COST
                    +
          END-TO-END ENCRYPTION
                    +
         USER-CONTROLLED PRIVACY
                    +
         LOCAL-FIRST CONVERSATIONS
                    +
       PERSISTENT DEVICE RELATIONSHIPS
                    +
          AUTOMATIC RECOVERY
```

---

# 68. Future Technical Design Phase

After approval of this BRD, the next documentation phase should define the technical implementation.

The technical design should cover:

1. Flutter project architecture
2. Android native architecture
3. Domain models
4. Local database schema
5. Firebase schema
6. Authentication architecture
7. Device identity architecture
8. Cryptographic protocol
9. Key management
10. Network transport abstraction
11. Bluetooth implementation
12. Wi-Fi implementation
13. Relay protocol
14. Routing algorithm
15. Route cost calculation
16. Migration protocol
17. Offline queue
18. Synchronization engine
19. Conflict resolution engine
20. Group encryption
21. Call architecture
22. PTT architecture
23. Location architecture
24. Storage management engine
25. Version management
26. Android background services
27. Push notification architecture
28. Logging and diagnostics
29. Security threat model
30. Network simulation/testing

---

# Final Product Definition

## NEXORA

### Connect beyond the network

NEXORA is a:

**Secure + Offline-first + Peer-to-peer + Multi-hop + End-to-end encrypted communication platform**

supporting:

```text
                NEXORA
                   |
       +-----------+-----------+
       |           |           |
      CHAT        PTT        CALL
       |           |           |
       +-----------+-----------+
                   |
              GROUPS
                   |
              LOCATION
                   |
             FILE SHARING
                   |
           OFFLINE STORAGE
                   |
          MULTI-HOP NETWORK
                   |
          DYNAMIC ROUTING
                   |
        AUTOMATIC MIGRATION
                   |
        MULTIPLE TRANSPORTS
                   |
          TRUST + BLOCKING
                   |
        END-TO-END SECURITY
                   |
       GOOGLE AUTH + FIREBASE
                   |
          VERSION CONTROL
```

**Product Name:** NEXORA
**Tagline:** Connect beyond the network

**BRD Version:** 1.0
