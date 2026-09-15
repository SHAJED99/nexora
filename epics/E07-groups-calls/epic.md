---
id: E07
title: Groups & Voice Calls
status: done
type: feature
priority: { moscow: should, wsjf: 2.1 }
depends_on: [E06]
traces_to: [FR-COMM-001, FR-COMM-002, FR-GROUP-001, FR-GROUP-002, FR-GROUP-003, FR-GROUP-004, FR-GROUP-005, FR-GROUP-006, FR-CALL-001, FR-CALL-002, FR-CALL-003]
external_services: []
ui_surface: [mobile]
design_screens: [conversations, chat]
---
# E07 · Groups & Voice Calls

## Business goal
Extends E06's proven 1:1 chat to groups (Owner/Admin/Member roles, key
rotation on membership change) and adds secure voice calls over the same
routing architecture, with priority and mid-call migration.

## User-visible outcome
A user creates/joins a group and communicates with it; a user places a
voice call that survives a route change without dropping.

## Scope
**In scope:** group roles/management, group key rotation (Sender-Keys layer
on E03's protocol), the group-chat UI (Conversations "Groups" tab, per E06's
deferred gap), voice calls with routing priority and make-before-break
mid-call migration, **push-to-talk (PTT)** — re-homed here from E06 by human
decision on 2026-08-30 (`IMP-001`; see Open Questions) because PTT is a
half-duplex live-transport mode that shares this epic's real-time transport
problems and almost none of E06's async-messaging ones. Design it once
E07's voice-call transport question is settled, not before.
**Out of scope:** anything E06 already delivers for 1:1.

## Data model / API surface / Screens

**Data model** — four new tables and one migration, `12 → 13`, owned
entirely by `E07-T01` and 🧍 gated by `OQ-E07-4`: `groups`,
`group_members`, `group_sender_keys`, `group_events`. Group *messages* are
ordinary rows in E05's existing `messages` table, keyed by the group's
`conversationId` — no parallel message table (`E07-T06` §2). No table is
added for calls: FR-CALL-001/002/003 require no call history and inventing
one would open a schema gate for scope nobody asked for.

**API surface** — none. This app has no server (ADR-0005). The "API" this
epic adds is three new control-frame kinds on the keyed dispatch seam
`OQ-E06-T08-2` retrofitted into `InboundPipeline`: `3` group membership
(`E07-T03`), `4` group key distribution (`E07-T04`), `5` call signaling
(`E07-T09`) — joining `1` prekey exchange and `2` delivery ack.

**Screens**

| Screen | Route | Design contract | Task |
|---|---|---|---|
| Conversations · Groups section | `/conversations` | `design/screens/conversations.md` (elements 21-33, **measured**) | **E07-T08** |
| Group thread rendering | `/chat/:id` | `chat.md` + **GAP-020** (derived, 🟡) | prospective |
| Group create | _(new)_ | `design/screens/group-create.md` — **GAP-018**, written by `E07-T12` | prospective |
| Group manage | _(new)_ | `design/screens/group-manage.md` — **GAP-019**, written by `E07-T12` | prospective |
| Call (outgoing/incoming/in-call/failed) | _(new)_ | `design/screens/call.md` — **GAP-021/022**, written by `E07-T12` | prospective |

Only **E07-T08** is a sharded frontend task, because it is the only one
whose contract already exists and is approved. The rest are prospective by
rule 2 — no contract, no frontend task — and become shardable the moment
`design/gaps.md`'s `design_contract_approval` line reads cleared for
GAP-018…GAP-022.

## Acceptance criteria (epic-level, EARS)
- **EARS-GROUP-1**: WHEN group membership changes, the system SHALL rotate the group's encryption keys. (FR-GROUP-004) → **E07-T05**
- **EARS-GROUP-2**: A newly added member SHALL NOT automatically gain access to historical group communication. (FR-GROUP-006 — v1 default per Q-FUNC-006: no exception path exists) → **E07-T05**
- **EARS-CALL-1**: WHEN a better route becomes available mid-call, the system SHALL migrate without dropping the call (make-before-break). (FR-CALL-003) → **E07-T11**

## Tasks
Sharded 2026-08-31 against `development` @ `73eb4b3` (384/384 green).
Groups first (a complete, shippable vertical), calls second (signaling and
routing behaviour that is real today, with the media path held behind a
🧍 rule-3 decision).

| Task | Title | Layer | Size | MoSCoW | depends_on |
|---|---|---|---|---|---|
| E07-T01 | Group data model + schema migration ⛔🧍 | backend | M | must | — |
| E07-T02 | Group role permission matrix (Owner/Admin/Member) | backend | S | must | T01 |
| E07-T03 | Group membership control protocol (create/rename/add/remove/promote/transfer/delete) | backend | M | must | T02 |
| E07-T04 | Drift-backed `SenderKeyStore` + group sender-key distribution | backend | M | must | T01, T03 |
| E07-T05 | **Key rotation on membership change + historical-access exclusion** | backend | M | must | T04 |
| E07-T06 | Group message send/receive fan-out | backend | M | must | T05 |
| E07-T07 | Conversation read model widened to groups | backend | S | must | T06 |
| E07-T08 | Conversations "Groups" section — real rows (closes GAP-006) | frontend | M | must | T07 |
| E07-T09 | Call session state machine + signaling | backend | M | should | T04 |
| E07-T10 | Real-time traffic profile + call priority (FR-CALL-002) | backend | M | should | T09 |
| E07-T11 | **Make-before-break call route migration** ⛔ | backend | M | must | T09, T10 |
| E07-T12 | E07 design gap pass — derived contracts (group create/manage, call) | docs | M | must | — |
| E07-T13 | **PTT — resolve `OQ-E07-2` and produce its disposition** ✅ *(2026-08-31: outcome (b), `GAP-023` — layered on GAP-014, unblocked by `OQ-E07-3`)* | docs | S | could | T12 |

⛔ = carries or is blocked by a 🧍 Open Question. See §Open Questions and
`tracker.md` §Blocked.

**Follow-on (listed, NOT sharded — rule 2 and rule 3 both bind here).**
Sharding any of these now would consume a contract or a decision in the
same breath as requesting it, which is exactly what the gates exist to
prevent.

| Prospective task | Layer | Blocked by |
|---|---|---|
| Real-time media path — capture, encode, encrypt, transmit, decode, play | backend | **`OQ-E07-3` ✅ resolved 2026-08-31** (option (a), datagram audio over the existing mesh + Opus codec; (c) native Pigeon channel as the named fallback). Not yet shardable: `OQ-E07-3`'s own resolution text says `OQ-E06-T04-2` (real two-device Bluetooth hardware verification of E04-T03b/T03c/T05's actual data path, still 🟡 open, a human action — not satisfied by this session's own discovery-only device testing that produced `E04-B04`) should be prioritized first, so the fallback can be exercised cheaply if (a) doesn't hold up at real multi-hop latency |
| Group thread rendering — per-sender attribution + membership event lines | frontend | GAP-020 (🟡) **and** `OQ-E07-10` (blocked-member behaviour in a group thread) |
| Group create screen | frontend | GAP-018 (🟡) + `E07-T12`'s contract |
| Group manage screen (roles, membership, delete) | frontend | GAP-019 (🟡) + `E07-T12`'s contract |
| Call screens (outgoing/incoming/in-call/failed) | frontend | GAP-021/022 (🟡) + `E07-T12`'s contract |
| **PTT build (1:1 and group)** — hold-to-transmit on the existing `mic` button, Opus clip, delivered as a voice bubble | frontend + backend | **`OQ-E07-3` ✅ and `E07-T13`'s disposition ✅ (2026-08-31, outcome (b), `GAP-023`).** Now blocked only by **`GAP-023`'s own 🧍 design approval** — on which the delta is folded into `design/screens/chat-voice.md` as a `ptt-transmitting` state, and this becomes shardable. Depends on GAP-014's voice-message build landing first (it is the artifact); the group half additionally inherits GAP-020's `OQ-E07-13`, like every other group-thread bubble |
| Group voice calls (conferencing) | backend | `OQ-E07-11` — FR-COMM-002 names them; the shape depends entirely on `OQ-E07-3` |
| One-time-prekey reclaim policy | backend | `OQ-E07-9` — inherited from E03, trigger now real |

## Test strategy
Three simulated devices in one process (the two-stack pattern
`E06-T07`'s `prekey_exchange_test.dart` established, extended to three).
The epic's own proof is one journey: A, B and C are in a group; A removes
C; A sends; **B renders the message and C cannot decrypt it, explicitly and
loudly.** If that journey does not hold, FR-GROUP-004/005/006 are claims
rather than facts, and nothing else in the epic matters.

The call half's proof is the ordered-sequence test in `E07-T11`: a fake
`CallMediaTransport` that records the exact order of `attach`/`detach`, and
a session that stays `active` across every failure mode.

## Risks
| Risk | Mitigation |
|------|-----------|
| Group key rotation is genuinely hard on top of a 1:1-first crypto layer (E03) | **Discharged at this sharding pass, before slicing** — ADR-0003's deferred layering is specified concretely in `E07-T04` §2 (libsignal's own `GroupCipher`/`SenderKeyStore`, epoch folded into the group half of `SenderKeyName`, distribution over pairwise sessions) and recorded as `OQ-E07-8` for cheap rejection. The one part that is genuinely the human's — the schema it persists into — is `OQ-E07-4` and blocks `E07-T01` |
| **Voice calls have no transport.** E04's mesh/relay is store-and-forward over a Pigeon `send(deviceId, bytes) -> Future<bool>`; nothing in E01–E06 targets live audio, and no ADR covers it | **`OQ-E07-3`, 🧍 blocking, raised rather than guessed.** The epic is sliced so that everything *not* downstream of it — signaling, priority, migration control — is built and tested now, and the media path is a named prospective task behind an abstract seam (`CallMediaTransport`) that all three candidate answers plug into unchanged |
| PTT gets dropped for a third time | **`E07-T13` is a named task whose entire purpose is `OQ-E07-2`'s discharge**, with three acceptable outcomes and "revisit later" explicitly not among them. This is `IMP-001` §Effort/risk's stated failure mode, given an owner. **Closed 2026-08-31: outcome (b) — `GAP-023`, PTT layered on GAP-014's approved voice-message contract, 1:1 and group both in v1, nothing re-homed.** The risk did not materialise |
| E06-B04's unauthenticated `frame.source` is inherited by three new control protocols | Every new control frame in this epic is authenticated by the **decrypting Signal session's address**, never by `frame.source` (`E07-T03` §2, `E07-T04` §2, `E07-T09` §2), each with a forged-actor test. E11 still owns the underlying fix |
| Widening `ConversationSummary` breaks every 1:1 call site | Deliberate — nullable `peerDeviceId` turns each assumption into a compile error rather than a silent wrong render (`E07-T07` §6). Fence amendments, not quiet widening |

## Open Questions

- **OQ-E07-1 — Q-FUNC-006 default confirmed.** Per prior human decision: v1 has no mechanism for granting a re-added member historical access. Carried here for task-sharding to encode explicitly, not re-litigate.
  - **Status:** ⚪ deferred (decided) — **encoded by `E07-T05`** (§2, plus
    `test_EARS_GROUP_2_no_api_exists_to_grant_historical_access`, which
    makes the decision mechanically checkable rather than merely honoured)
  - **Answered by:** human (via Q&A during genesis)
  - **Date:** 2026-08-26

- **OQ-E07-2 — PTT (push-to-talk) re-homed here from E06.** E06-T13's design
  gap pass found PTT has no design source and no derivable primitive
  (`GAP-017` / `OQ-E06-T13-1` in E06). The human decided to park it until
  this epic's voice-call work settles the real-time transport question,
  then design PTT once against a transport that exists, via `IMP-001`. No
  contract exists yet; this epic's own task-sharding pass must carry it as
  a named obligation, not rediscover it — same failure shape as E05-B02's
  relay-queue handoff.
  - **Status:** 🟢 **resolved 2026-08-31 by `E07-T13`, outcome (b) — PTT
    layers on `GAP-014`'s approved voice-message contract with a small
    delta, recorded as `GAP-023`**, which supersedes `GAP-017` by reference
    (GAP-017 itself is unedited). Not contracted-from-scratch, not re-homed,
    and explicitly not a fourth undated deferral. The *disposition* is
    closed; the delta's **design approval is open** at the existing
    `design_contract_approval` gate on `design/gaps.md` (GAP-023 is 🟡 with a
    bare `approved by:` line and four named forks).
  - **Answer (verbatim, `GAP-023`):**
    - **Q1 — live half-duplex stream, or a fast voice-message loop layered
      on GAP-014?** *"A fast voice-message loop, in v1."* The datagram-mesh
      answer to `OQ-E07-3` does make a live PTT stream cheap **in
      principle** — but only downstream of the media-path prospective task,
      which is itself unsharded and which `OQ-E07-3`'s own answer says
      should follow `OQ-E06-T04-2`'s real-hardware latency numbers; making
      PTT depend on that chain would be *"a fourth deferral wearing a
      contract"*. And the spec describes an artifact rather than a channel:
      **FR-STORE-002** stores PTT recordings, **FR-NOTIFY-001** gives PTT
      its own notification class, PTT sits in FR-COMM-001/002's list of
      *message types*, and **FR-CALL-001/002/003 never mention it**. What
      `OQ-E07-3` genuinely buys PTT is *"the codec, not the channel"* —
      Opus is now authorized, so the delta needs **no new dependency**.
    - **Q2 — does a transmission leave a message, or is it ephemeral?**
      *"It leaves a message. This is decided by the spec, not by this
      entry."* **FR-STORE-002** says the system *shall* store PTT
      recordings on-device; ephemeral PTT would contradict a "shall"
      (rule 1). The artifact is GAP-014's already-approved voice bubble
      (`chat-voice.md` V10-V16) **unchanged** — a second near-identical
      bubble type would be a competing visual language for one object
      (FR-UI-001).
    - **Q3 — per-conversation, or its own surface?** *"Per-conversation.
      No new route, no new screen, no PTT channel list."* Every spec id
      naming PTT places it inside a conversation (FR-COMM-001 personal,
      FR-COMM-002 group, `feature-list.md` "with a contact"); a dedicated
      PTT surface would be an invented destination with no id behind it.
    - **Group PTT (FR-COMM-002) — in v1 scope, and needs no floor
      control.** Under the live-channel reading a group channel is a floor
      arbitration problem with no spec text, no ADR and no derivable
      primitive. Under the message reading *"there is no floor"* — two
      members holding the button at once produce two clips, exactly as two
      members typing at once produce two messages. Group PTT is the
      existing group fan-out (`T04`/`T05`/`T06`) carrying a voice bubble
      with GAP-020's approved sender attribution: zero new mechanism.
      Neither deferred nor re-homed; it inherits GAP-020's existing
      `OQ-E07-13` build precondition, not a new one.
    - **The one fork that matters, put to the human:** if PTT is meant to
      be a genuinely live half-duplex channel, then FR-STORE-002 needs an
      amendment (it says the opposite), PTT becomes downstream of the
      media path and `OQ-E06-T04-2`, and group floor control needs a design
      that does not exist — that route goes through `skills/change-impact`.
      *Advisory: ship this reading now;* the two are a subset relation, not
      an exclusive choice, and the **named revisit trigger** is the
      media-path task shipping *and* `OQ-E06-T04-2` producing real
      multi-hop-BLE latency numbers.
  - **Answered by:** `E07-T13` (planner) for the disposition and the
    delta; **human** for the 2026-08-30 parking decision (`GAP-017` /
    `IMP-001`) and for the 2026-08-31 `OQ-E07-3` answer this was waiting on.
    The delta's own design sign-off is **not** claimed here.
  - **Date:** 2026-08-31 (parked 2026-08-30; unblocked and resolved
    2026-08-31)
  - **No `IMP-002` was written**, deliberately: outcome (b) keeps
    FR-COMM-001/002's PTT clause **in v1 in full** for both 1:1 and groups.
    Nothing is dropped or re-homed, so there is no `dropped scope` change
    to walk. `IMP-002` was reserved for outcome (c), which was not taken.

- **OQ-E07-3 — what carries live call audio? 🔴 BLOCKING, and a rule-3
  human decision (architecture + a new dependency).** *Raised at sharding
  rather than guessed.*

  **Why this is not the agent's call.** Everything E01–E06 built moves
  *opaque, store-and-forward* bytes: `TransportService.send(deviceId,
  Uint8List) -> Future<bool>` over Pigeon (ADR-0004), queued in
  `relay_packets` with a TTL measured in days, delivered when a route
  happens to exist. Live audio needs the opposite properties — bounded
  latency, tolerance of loss, no queuing, a codec, microphone and speaker
  access. **No accepted ADR covers any of that**, and every option below
  requires at least one new dependency, which rule 3 reserves to you
  regardless of which is technically best.

  | | (a) Datagram audio over the existing mesh | (b) WebRTC (`flutter_webrtc`) for media | (c) Native real-time path via a new Pigeon channel |
  |---|---|---|---|
  | New dependency | an Opus codec + a mic/speaker plugin | `flutter_webrtc` (large, plus signaling glue) | a mic/speaker plugin; codec possibly native |
  | Fits FR-CALL-001 "same dynamic routing architecture" | ✅ directly — it *is* the mesh | ❌ WebRTC brings its own ICE/transport and expects IP connectivity | ✅ if the native side routes through the same links |
  | Works with no internet / no infrastructure (the product's premise) | ✅ | ⚠️ ICE/STUN normally presume IP reachability; peer-to-peer over BLE is not a supported WebRTC transport | ✅ |
  | Make-before-break (FR-CALL-003) | ✅ trivial — address frames to the new next hop, overlap is a few duplicated packets | ⚠️ WebRTC does its own ICE restart; `E07-T11`'s controller becomes a thin driver over someone else's logic | ⚠️ needs two concurrent native connections — a Pigeon API change (ADR-0004) |
  | Latency realism over multi-hop BLE | ⚠️ genuinely uncertain; this is the honest risk | n/a (different transport) | ⚠️ same uncertainty, better ceiling |
  | Effort | medium — jitter buffer, pacing, loss concealment all become ours | high to integrate, then much is handled | high — real native work on both platforms |
  | Security | ✅ reuses the Signal session; audio frames encrypt like everything else | ⚠️ DTLS-SRTP is WebRTC's own; a second crypto stack alongside ADR-0003 | ✅ same as (a) |

  **Advisory recommendation: (a), with (c) as the fallback if measured
  latency proves unworkable.** (a) is the only option that keeps one
  transport, one crypto protocol and one routing engine — and FR-CALL-001
  says in so many words that calls use *the same dynamic routing
  architecture as other communication*. (b) is the fastest route to audio
  that works and the worst fit for this product: it introduces a second
  transport and a second crypto stack, and it quietly assumes the IP
  connectivity that NEXORA exists to do without. **The honest caveat: none
  of us knows yet whether multi-hop BLE can carry a call at acceptable
  latency** — `OQ-E06-T04-2` is still open, the transport has never run on
  real hardware, and that measurement should probably precede this
  decision rather than follow it.

  - **Status:** 🟢 resolved — **(a) datagram audio over the existing mesh +
    Opus codec**, with **(c) native real-time Pigeon channel as the named
    fallback** if measured multi-hop-BLE latency proves unworkable. The
    latency risk is accepted knowingly, not resolved by measurement first —
    `OQ-E06-T04-2` (real-hardware transport numbers) should still be
    prioritized before the media-path prospective task is sharded, so the
    fallback can be exercised cheaply if (a) doesn't hold up. This unblocks
    the media-path prospective task, `E07-T13` (PTT), and `OQ-E07-12` (the
    media half of make-before-break). `E07-T09`/`T10`/`T11` were never
    blocked by this — they're sliced to be independent of it.
  - **Answered by:** human
  - **Date:** 2026-08-31

**Raised on individual tasks** (full text, options and advisories live on
the task files — this table is the index):

| id | Task | Priority | Question |
|---|---|---|---|
| **OQ-E07-4** | T01 | 🧍 **blocking** | The group schema migration 12 → 13. Three forks called out: epoch in the sender-key PK, retained-vs-deleted removed members, `group_events` as its own table. Rule 3 names schema migrations explicitly |
| OQ-E07-5 | T02 | important | How much may an Admin actually do? FR-GROUP-003 is genuinely silent. Advisory: the narrow matrix — widening later is one line, narrowing later is an incident |
| OQ-E07-6 | T03 | important | Membership frames ride pairwise Signal sessions (vs. a new signing scheme, vs. waiting for E11). A security posture, recorded rather than silently chosen. Advisory: pairwise sessions |
| OQ-E07-7 | T03 | ⚪ deferred | A device that misses a membership epoch cannot catch up. The group instance of `OQ-E06-T06-2`. **Owner: E11**; advisory: one gap-fill protocol, not two |
| OQ-E07-8 | T04 | ⚪ decided (within ADR-0003) | The concrete Sender-Keys ↔ Double Ratchet layering. Written out in full for cheap rejection; the schema half is `OQ-E07-4` |
| OQ-E07-9 | T04 | important | Group fan-out sharpens E03's one-time-prekey leak (`OQ-E06-T07-2`) — up to N−1 prekeys per first distribution. **Owner: human to assign** to E07 or E11 |
| OQ-E07-10 | T07 | important | What does "blocked users are mutually invisible within a shared group" mean *inside the thread*? **Owner: the group-thread UI task**; advisory: drop at the pipeline, one blocking mechanism |
| OQ-E07-11 | T09 | important | Are group voice calls in v1? FR-COMM-002 names them; FR-CALL-001/002/003 are singular. Advisory: 1:1 only, re-scope after `OQ-E07-3` |
| OQ-E07-12 | T11 | 🟡 blocked by `OQ-E07-3` | The *media* half of make-before-break. The control half is `E07-T11`; the seam is shaped so all three `OQ-E07-3` answers plug in unchanged |

**Design gaps added at sharding** — GAP-018 (group create), GAP-019 (group
manage), GAP-020 (group thread attribution + event lines), GAP-021 (call
surfaces), GAP-022 (migration is invisible, deliberately) in
`design/gaps.md`, all 🟡 with bare `approved by:` lines. 🧍
`design_contract_approval` is **reopened**. `E07-T08` is deliberately *not*
gated by that reopening — it builds already-measured, already-approved
elements 21-33 of `conversations.md` and closes GAP-006, whose own approval
line reads "rows deferred to E07".

## Analyze report
*(`skills/task-sharding` §6, run 2026-08-31 against E07-T01…T13, on
`development` @ `73eb4b3`, 384/384 tests green)*

| Check | Result | Notes |
|---|---|---|
| EARS trace | ✅ pass | All three epic-level criteria are owned by a named task: **EARS-GROUP-1** → T05, **EARS-GROUP-2** → T05, **EARS-CALL-1** → T11. Every task carries ≥1 `traces_to:` FR id and ≥1 EARS criterion. New sub-ids (GROUP-3…16, CALL-2…11, COMM-29…34, UI-3…7) each cite an existing FR and none collides with an id already used in E01–E06 (checked mechanically across `epics/`, `spec/`, `lib/`, `test/`). **EARS-CALL-1 is the one worth naming:** it is owned in full by T11's *control* sequence, with the media half carried as `OQ-E07-12` rather than left implicit — the criterion is not half-owned, it is owned with a stated boundary |
| Contract sanity | ✅ pass | No API surface (no server, ADR-0005). The four new control kinds are allocated **once, in one place** — 3 (T03), 4 (T04), 5 (T09) — extending the keyed dispatch seam `OQ-E06-T08-2` built, exactly as T07/T08 extended it in E06, with no re-versioning of `RelayPacketFrame`. One sender-key store (T04) with one writer (T04) and one policy caller (T05). One read model (T07) consumed by one screen (T08) and by the prospective group-thread task. `ConversationSummary` is widened in one task, not forked. Union-sufficiency check run: it found that a call has **no media transport at all**, which is why `NullCallMediaTransport` exists and why `OQ-E07-3` is blocking — the honest v1 state is a call that rings and then truthfully fails, never one that pretends |
| Collision matrix | ✅ pass | Empty for every parallelizable pair. Shared files are serialized by `depends_on`: `lib/core/messaging/messaging_stack.dart` on the chain **T03 → T04 → T09** (three registrations, three tasks, never concurrent); `lib/core/persistence/*` on **T01 alone**; `inbound_pipeline.dart` on **T06 alone**; `conversation_repository.dart` on **T07 alone**; `design/gaps.md` on **T12 → T13**. **T09's `depends_on: [E07-T04]` is a deliberate serialization, not a semantic dependency** — call signaling needs nothing from the sender-key layer, but both register into `messaging_stack.dart`, and E06-T04's precedent (registering through `bindings.dart` specifically to dodge the messaging_stack chain) was considered and rejected here because it would split one registration pattern into two. Recorded so a reader does not "fix" the DAG by removing it. Parallel sets: {T01, T12}; then {T02}; then {T04 ∥ nothing}; then {T06, T09}; then {T07, T10}; then {T08, T11, T13} |
| Scope fences | ✅ pass | All 13 §4 sections non-empty and specific to the temptation each task invites — T01's "do not bump `schemaVersion` before `OQ-E07-4` is 🟢", T04's "do not implement a ratchet, KDF, cipher or padding scheme; if a primitive is missing, stop", T05's "do not leave a hook for history-sharing — a hook is a reversal in waiting", T08's "do not add a create-group affordance, not even a disabled one", T09's "does not persist call history — no table, no migration", T11's "do not add a second migration heuristic", T12's "does not propose a PTT contract", T13's "does not answer `OQ-E07-3` on the human's behalf" |
| MoSCoW inflation | ⚠️ **exception, justified** | 10/13 `must` (77%) — the same ratio E06 disclosed, and checked rather than asserted. The group vertical **T01 → T02 → T03 → T04 → T05 → T06 → T07 → T08** is a strict chain in which no link delivers user value alone: a permission matrix nothing calls, a protocol with no key layer, a key layer with no rotation, and a rotation with no messages are each worth exactly nothing, and the epic's entire user-visible outcome ("a user creates/joins a group and communicates with it") requires all eight. T11 is `must` because it owns an epic-level EARS criterion. T12 is `must` because rule 2 makes every remaining frontend task unshardable without it. The three non-`must` tasks were graded on their merits, not to fix the ratio: **T09/T10 `should`** (calls are the epic's second half; the product ships a working group chat without them) and **T13 `could`** (a disposition document — valuable, and genuinely the last thing that should be built) |
| Size | ✅ pass | 10×M, 3×S, **no L**. The two candidates for L were split deliberately: group crypto became T04 (store + distribution) and T05 (rotation + exclusion policy) rather than one "group encryption" task; and calls became T09 (session + signaling), T10 (priority), T11 (migration) rather than one "voice calls" task — a split that also happens to isolate everything blocked by `OQ-E07-3` into a prospective task rather than stalling three sharded ones |
| Design | ✅ pass | **One** `layer: frontend` task, T08, with `design_contract: design/screens/conversations.md` — a file that exists, has a golden, and whose elements 21-33 this task builds. Every other UI surface in this epic is **prospective, not sharded**, precisely because its contract does not exist yet; sharding them would point `design_contract:` at a file `E07-T12` has not written. Gap pass performed at sharding as the planner's charter requires: GAP-018…GAP-022 appended to `design/gaps.md`, all 🟡, all with bare `approved by:` lines, `design_contract_approval` reopened. GAP-022 is worth naming — it proposes showing the user **nothing** during a successful migration, recorded as a gap precisely because a deliberate absence is indistinguishable from an oversight unless it is written down |
| Obligation ownership | ✅ pass | Grepped every task file for every other task id and for sibling-naming prose. Five cross-task obligations found, and each is independently stated in the **owning** task's binding contract, not only in the sibling's prose: (1) **T04's `ensureOwnChain`/`distributeTo`/`discardChains` are called by nobody in T04** — T05's `functions:` and §3 declare each call and its order; (2) **T01's `newGroupId` prefix is relied on by T07's read model** — T07 §2 states the id-space widening independently and tests it; (3) **T09's `CallMediaTransport` seam is driven by T11** — T11's `functions:` and §5's ordered sequence state the attach/detach contract independently; (4) **T03's epoch bump is what triggers T05's rotation** — T05 §2 states the trigger and T05's own tests assert it, rather than T03 promising it; (5) **T12's derived contracts are consumed by the prospective UI tasks** — those are listed as prospective *because* the contracts do not exist, which is the ownership made structural. One prose-only obligation was found and fixed during the pass: T07's original text described the group-thread blocked-member behaviour as someone else's job without naming an owner — now `OQ-E07-10` with an explicit owner and a revisit trigger |
| **Inherited obligations** | ⚠️ **pass with 4 explicitly-owned open items and 4 explicitly declined** | §0 was run before slicing. **17 obligations enumerated, 0 silently dropped.** Full table below |

### Inherited obligations — §0 pass

Sources read in full before slicing: `epics/E06-personal-chat/retro.md`
(§Open follow-ups and §What went wrong), `epics/E06-personal-chat/
tracker.md` (§Bug sweep, §Carried-forward observations, merge-gate notes),
`epics/E05-messaging-reliability/retro.md`, `epics/E03-e2e-encryption/
retro.md`, `docs/impact/IMP-001-ptt-rehome-to-e07.md`, `design/gaps.md`
(GAP-006, GAP-017), the E06 bug files `E06-B02/B03/B04`, and
`E06-T09.md`'s own forward-looking note about the conversation id space.

| # | Obligation (source) | Disposition |
|---|---|---|
| 1 | **PTT re-homed to E07** — `IMP-001`, `GAP-017`, `OQ-E06-T13-1`, and this epic's own `OQ-E07-2`. `IMP-001` §Effort/risk names the exact risk: *"if E07's sharding pass doesn't read `OQ-E07-2`, the obligation could be dropped a second time"* | **covered-by E07-T13** — a named task with an EARS criterion (`EARS-UI-7`) whose pass condition is that PTT ends this epic in one of three recorded dispositions, and explicitly **not** as a fourth deferral |
| 2 | **GAP-006 — the Conversations "Groups" rows are deferred to E07** (`built:` line: *"rows deferred to E07"*) | **covered-by E07-T08**, which closes GAP-006 and updates its `built:` line as a DoD item |
| 3 | **E06-T09 §2: "Group conversations (E07) will need a different id space… `conversationId` is documented as opaque to callers so E07 can widen it"** | **covered-by E07-T01** (the `g:`-prefixed id space) **and E07-T07** (the read-model widening), with `test_messages_page_works_unchanged_on_a_group_conversation_id` proving the opacity claim held |
| 4 | **`drift_signal_store.dart`'s own header: "`SenderKeyStore` … is explicitly out of scope — that belongs to E07"** | **covered-by E07-T04** — the Drift-backed `SenderKeyStore` is that file's named successor |
| 5 | **ADR-0003 §Consequences: group rotation and new-member exclusion are *"built explicitly on top of this layer, not assumed to fall out of it natively — flagged for the groups/encryption epic's task-sharding to design deliberately"*** | **covered-by E07-T04 §2 (the layering) + E07-T05 (the rotation policy)**, and recorded as `OQ-E07-8` so the human can reject the design cheaply. This epic's own §Risks row required it be confirmed *before* sharding, not after — done |
| 6 | **`OQ-E07-1` / Q-FUNC-006 — no historical access for a re-added member, decided by the human** | **covered-by E07-T05**, encoded as a hard refusal plus `test_EARS_GROUP_2_no_api_exists_to_grant_historical_access` — the decision is mechanically checkable, not merely honoured |
| 7 | **E06-B04 → E11: `frame.source` is unauthenticated, and E07 adds three new control protocols on top of it** | **covered-by E07-T03/T04/T09**, each of which authenticates by the decrypting Signal session's address and carries a forged-actor test. The underlying fix stays E11's — this epic routes around the weakness rather than inheriting it. **This is the one obligation the sweep would most likely have caught late**: a forgeable "remove member" frame is an S1 waiting to happen, and it was not in any retro — it came out of reading E06-B04 against E07's new protocols |
| 8 | **`OQ-E06-T07-2` / E03 retro: issued-but-never-consumed one-time prekeys leak permanently; "needs a policy before bundles issue at real volume"** | **owned Open Question `OQ-E07-9`** — group fan-out makes the trigger real (up to N−1 prekeys per first distribution). Not fixed inside T04 (that would blur key management into key distribution); **owner: human to assign** to E07 or E11, and T04 asserts the consumption in a test so the number is visible |
| 9 | **`OQ-E06-T06-2` / `OQ-E05-T04-1` — no multi-device gap-fill protocol; owner E11** | **owned Open Question `OQ-E07-7`** — E07 produces the *group* instance of the same problem (a device offline across a membership change). Advisory: fold into E11's one protocol rather than build a second. Owner and revisit trigger both named |
| 10 | **`OQ-E06-T06-3` — `RelayDeliveryState.failed` is never assigned and is excluded from `reclaimPayloads`'s reclaim set; the constraint travels with whoever first writes it** | **explicitly declined, with the constraint kept alive** — T03, T06 and T10 each carry a §4 line forbidding writing `failed`, so the trigger stays untriggered by this epic and the constraint is not inherited silently |
| 11 | **E06 retro §5: the delivery-tick *colour* tokens diverge across chat/dashboard/conversations; "worth a future S4 cleanup rather than being forgotten"** | **explicitly declined for E07, with reason** — T08 edits `conversations_view.dart` and could fix it in passing, which is exactly why the fence forbids it: a drive-by fix to a shared token across three screens is out-of-scope work on merged code (rule 6). **Routed as a standing S4 chore**, and named here so the decline is visible rather than an omission |
| 12 | **E06-B03's lesson: the delivery-glyph *mapping* must be shared, not re-derived per screen** | **covered-by E07-T08 §2/§4** — reuse the shared mapping, with `test_delivery_glyphs_are_the_shared_mapping_not_a_local_switch` |
| 13 | **L-frontend-001 (rule, promoted 2026-08-30): never reshape the widget tree to score better against the design gate** | **covered-by E07-T08 §4 + `test_no_raw_listener_widgets`** — the only frontend task in this epic carries the rule explicitly, because E06 had to hand-type this warning into two dispatch prompts |
| 14 | **L-process-008 (rule): read the tracker's own carry-forward section before each new dispatch** · **L-process-009 (rule): every bug task file needs a scope fence** | **process obligations, not task obligations** — recorded in `tracker.md` §Carried-forward observations (created empty at sharding so it has a reader from day one) and to be honoured when any E07 bug file is written |
| 15 | **`OQ-E06-T04-2` — E04's transport has never run on real Bluetooth hardware** | **explicitly declined as an E07 task, and escalated** — it is a human action, not code, and it now blocks something concrete: `OQ-E07-3`'s honest answer depends on whether multi-hop BLE can carry a call at all. Named in `OQ-E07-3`'s own caveat rather than left in E06's question table |
| 16 | **`metrics.csv` still does not exist** — carried by every retro since E00; E05's and E06's both said it should stop being a retro line | **explicitly NOT owned by an E07 task**, for E06's own stated reason: it is harness infrastructure with no FR/NFR id, so a task for it fails rule 1 and `make validate`. **Routed to the human as a harness item.** Seventh consecutive epic to record it |
| 17 | **The lesson hook never injects `qa.md`** — `index.yaml` maps no layer to the `qa` area (E05 and E06 retros) | **explicitly NOT owned by an E07 task** — a harness-configuration change affecting every dispatch, which two retros have said should not be made silently. **Routed to the human** |

**Net on this row:** 17 obligations — **9 covered by a named task, 4
carried as explicitly-owned Open Questions with owners and revisit
triggers, 4 explicitly declined with reasons and re-homed. Zero silently
dropped.** One obligation (#7) was not written down in any retro and was
found only by reading E06-B04's bug file against this epic's new
protocols — which is the argument for §0 reading bug files, not just
retros.

**Net overall:** 7/9 clean pass, 1 disclosed MoSCoW exception with an
evidenced justification, 1 Inherited-obligations pass with its open items
enumerated above. **One 🔴 blocking architecture question raised rather
than guessed (`OQ-E07-3`, the real-time media transport), plus one 🧍
schema-migration gate (`OQ-E07-4`)** — both rule 3's, both with options,
honest trade-offs and an advisory recommendation.

🧍 **HUMAN GATE** (`analyze_report`) — ✅ cleared retroactively, 2026-09-16, under the human's explicit delegation ("on you"), including acceptance of the disclosed MoSCoW exception. E07 was already fully built, swept, reviewed and merged; this only closes the bookkeeping line.

**What is dispatchable today, and what is not.** `E07-T02`, `E07-T03` and
`E07-T12` are dispatchable the moment this gate clears. **`E07-T01` is
not** — its schema migration is `OQ-E07-4`, and the whole group chain
(T02…T08) sits behind it. The call chain `E07-T09/T10/T11` is dispatchable
and deliberately independent of `OQ-E07-3`; only the media path, PTT
(`E07-T13`) and the four prospective UI tasks are blocked by a human
answer. This epic therefore **cannot fully proceed under the standing
"continue without per-gate pauses" instruction**: a schema migration and a
transport/dependency choice are both squarely rule 3's, and neither has a
safe default an agent may assume.

## Retro
→ `retro.md` (written after E07 completion)
