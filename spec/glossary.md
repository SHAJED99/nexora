# Glossary — NEXORA

> Terms used precisely and consistently from here forward. If a task or ADR
> uses one of these words differently than defined here, that's a defect in
> the task/ADR, not a valid alternate meaning.

**Status:** draft — 🧍 not yet human-reviewed
**Date:** 2026-08-26

| Term | Definition | Source |
|---|---|---|
| **Device identity** | A per-installation cryptographic identity, independent of the account (Google) identity. One user may have several. | BRD §6 |
| **Trusted** (relationship state) | A device the receiving side has configured to auto-accept connection requests, skipping normal authentication. | BRD §8–9 |
| **Allowed** (relationship state) | A device permitted to connect but not auto-accepted; distinct from Trusted. | BRD §8 |
| **Unknown** (relationship state) | A device with no prior relationship; requires authentication before connecting. | BRD §8, §123 (design) |
| **Blocked** (relationship state) | A device/user explicitly denied — mutual invisibility in shared groups, no direct communication. | BRD §8, §12–14 |
| **Bidirectional authorization** | Both sides of a connection must independently allow it; one side trusting the other is not sufficient. | BRD §10 |
| **Relay** | An intermediate device carrying encrypted routing/payload data for two devices without a direct connection; cannot decrypt content. | BRD §25, §27 |
| **Store-and-forward** | A relay temporarily holding encrypted packets when the destination is unreachable, forwarding once reachable. | BRD §26 |
| **Route migration** | Switching a connection's underlying transport/path when a better one is found, via make-before-break. | BRD §29–30 |
| **Make-before-break** | Migration discipline: establish + validate the new connection before terminating the old one. | BRD §30 |
| **Route cost** | A multi-factor score (battery, latency, reliability, bandwidth, hop count, congestion, stability, packet loss, traffic type) used to compare routes. | BRD §31 |
| **Smart Mode** | The default local-storage management mode; auto-selects removal candidates by age/size/type/access/pressure/importance and explains its choices. | BRD §19–22 |
| **PTT** | Push-to-talk — a real-time, one-way-at-a-time voice communication mode, supported personally and in groups. | BRD §15 |
| **Mesh** / **mesh network** | The dynamic, transport-agnostic, multi-hop peer network NEXORA forms between devices — no fixed topology. | BRD §1, product tagline |
| **Transport-agnostic** | No communication feature is permanently bound to one transport (Bluetooth/Wi-Fi/Internet/etc.) — any available transport may carry any supported type. | BRD §3.3, §24 |
| **Delivery state** | A message's lifecycle status: Queued, Sent, Accepted, Delivered, Stored, Read, Failed. | BRD §34 |
| **Conflict resolution precedence** | The rule that security-sensitive state conflicts resolve toward the more restrictive value: BLOCK>TRUST, LOCATION-OFF>LOCATION-ON, REVOKED>ACTIVE, REMOVED>MEMBER. | BRD §39 |
| **Group roles** | Owner (full control incl. delete/transfer), Admin (permitted management actions), Member (participates only). | BRD §50 |
| **Key rotation** | Regenerating a group's encryption keys on membership change, so removed members lose future access. | BRD §51 |
| **Version policy** | A remotely configurable record of minimum/latest supported build, version, and protocol — drives UP_TO_DATE / UPDATE_AVAILABLE / UPDATE_REQUIRED. | BRD §61.3 |
| **Mandatory update** | A non-dismissible update requirement that blocks app communication until satisfied, delivered via Google Play. | BRD §61.5 |
| **Protocol version** vs **Crypto version** vs **Database schema version** vs **App version/Build** | Four independently tracked version axes with different negotiation purposes — never conflate them. | BRD §61.10, §58 |
| **Progressive disclosure** | The UX principle that default views stay simple ("You're connected") while technical detail is available on demand, not shown by default. | documentation/Design.md §100–103, §132 |
| **Design contract** | The machine-checked `design/screens/<id>.md` file `make design-verify` gates a build against — generated from a golden capture, not hand-written. | agent/skills/design-fidelity |

## Terms deliberately NOT yet defined

These appear in the BRD/Design but their precise meaning is an open question,
not yet settled — using them in a task before their question resolves would
bake in a guess:

| Term | Open question |
|---|---|
| "Sufficiently better route" | Q-FUNC-005 — no numeric threshold defined |
| Cryptographic protocol name (e.g. "the ratchet") | Q-ARCH-003 — protocol family undecided |
| "Explicit permission" (for historical group access) | Q-FUNC-006 — no mechanism described; v1 default is no exception path |
