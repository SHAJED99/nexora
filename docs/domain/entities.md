# Domain Entities & Relationships — NEXORA

> The nouns the business actually uses, and how they relate. Produced during
> `skills/genesis` T00 domain analysis, from `documentation/BRD.md`.

**Date:** 2026-08-26

## Core entities

| Entity | What it is | Key attributes (from BRD, not yet a schema) |
|---|---|---|
| **User** | A Google-authenticated account. | account id (Google), display identity |
| **Device** | One app installation, cryptographically identified independent of the account. | device id (crypto key-derived), owning user, local state |
| **Relationship** | A directed trust state from one device/user to another. | state (Trusted/Allowed/Unknown/Blocked), direction, persisted |
| **Connection** | An active or attempted link between two devices, possibly multi-hop. | current route, transport, cost, state |
| **Route** | A specific path (direct or via relays) between two devices at a point in time. | hop sequence, per-hop transport, computed cost |
| **Relay hop** | One intermediate device's participation in a route. | packet metadata (id, priority, size, created/expiry, delivery state) |
| **Message** | A unit of communication — text, voice message, PTT, attachment, location share. | unique id, sender, delivery state, timestamp, content (encrypted at rest/in transit) |
| **Conversation** | Personal (1:1) or Group thread grouping messages. | type (personal/group), participants, local storage |
| **Group** | A named multi-party conversation with roles. | owner, admins, members, encryption key generation (rotates on membership change) |
| **Call** | A real-time voice session, personal or group. | route, priority, migration history |
| **Version policy** | A remotely configured record of minimum/latest supported build/version/protocol. | minimumSupportedBuild, latestBuild, minimumProtocolVersion, maintenanceMode |
| **Storage policy** | A user-selected or Smart-Mode-derived local storage management configuration. | mode, thresholds, last decision + explanation |

## Relationships between entities

```
User 1───* Device            (one user, multiple devices)
Device *───* Device           (via Relationship: Trusted/Allowed/Unknown/Blocked,
                                independently evaluated per direction)
Device 2───* Connection ── 1 Route ── *  Relay hop  (multi-hop path)
User/Group 1───* Conversation 1───* Message
Group 1───* Device (via Membership: Owner/Admin/Member role)
Device 1───* Call
(global) 1 Version policy ──> every Device (evaluated locally, cached offline)
Device 1───1 Storage policy
```

## What's explicitly NOT modeled yet

Exact database schema, exact Firestore collection shapes, exact key-exchange
protocol data structures — all deferred to genesis ADR-000N (crypto protocol)
and task-sharding. This is the conceptual model rule 1 requires before any
schema gets written, not the schema itself.
