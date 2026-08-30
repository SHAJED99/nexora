---
id: E06
title: Personal Chat
status: todo
type: feature
priority: { moscow: must, wsjf: 4.2 }
depends_on: [E02, E03, E04, E05]
traces_to: [FR-COMM-001]
external_services: []
ui_surface: [mobile]
design_screens: [dashboard, conversations, chat]
---
# E06 · Personal Chat ★ (the wedge)

## Business goal
**This is the epic that makes NEXORA worth using.** Two people exchange
text, voice messages, PTT, attachments, and location — encrypted, routed
over whatever transport is available, working offline — end to end, for
real, replacing genesis's stub with the actual product.

## User-visible outcome
A user opens a conversation, sends a message to a trusted/allowed contact,
and it arrives — even if that contact isn't directly reachable, even if the
sender is offline when they compose it. This is the first fully-real user
journey in the app.

## Scope
**In scope**
- Text messaging (1:1) — the minimum real wedge
- Voice messages, PTT, attachments, location-in-chat (FR-COMM-001's full
  scope) — may be sub-sharded into their own tasks/waves within this epic
  if text-first proves out faster feedback
- Dashboard, Conversations list, and Chat screens, wired to real data
  (E02 trust states gate who appears, E03 encrypts, E04 routes, E05
  guarantees delivery semantics)

**Out of scope**
- Group chat (E07)
- Voice/video calls (E07)
- Storage management UI (E08) — messages just accumulate for now

## Data model
Consumes E05's `messages`/`delivery_states` tables directly; no new tables
beyond what a UI needs (e.g. a `conversations` view/index for the list
screen) — task-sharding decides.

## API surface
None new — this epic is the presentation + orchestration layer over
E02–E05's data/domain layers.

## Screens
| Screen | Route | Design contract | Task |
|---|---|---|---|
| Dashboard | /dashboard | `design/screens/dashboard.md` | connectivity status, entry point |
| Conversations | /conversations | `design/screens/conversations.md` | Personal/Groups list (Personal populated here; Groups stays empty until E07) |
| Chat | /chat/:id | `design/screens/chat.md` | the actual conversation view |

**Gaps:** the Conversations screen's "Groups" tab will show an empty state
this epic doesn't populate — that's a real gap (design shows content, this
epic doesn't build groups yet). Log it in `design/gaps.md` at task-sharding,
traced to `FR-GROUP-*`, with `status: deferred` until E07.

## Acceptance criteria (epic-level, EARS)
- **EARS-COMM-1**: The system SHALL support sending/receiving text, voice messages, PTT, attachments, and location in a 1:1 conversation. (FR-COMM-001)
- **EARS-COMM-2**: The default view SHALL communicate connectivity simply ("You're connected"); route/transport detail SHALL be one tap away. (FR-UI-004)

Cross-cutting: **NFR-PERF-001** *(needs number)*, **NFR-BATT-001** *(needs
number)* bind here — chat is where responsiveness matters most to a user.

## Tasks
Sharded 2026-08-29 against `development` @ `35710f7`. Text-first, per
§Risks; the rich message types become shardable after T13's gap pass.

| Task | Title | Layer | Size | MoSCoW | depends_on |
|---|---|---|---|---|---|
| E06-T01 | Flutter-capable design-fidelity gate (closes OQ-E00-3) | infra | M | must | — |
| E06-T02 | Relay wire-packet framing + ciphertext type tag (closes OQ-E05-B01-1, E03-B03) | backend | M | must | — |
| E06-T03 | Messaging composition root (DI + startup crypto/identity init) | backend | M | must | T02 |
| E06-T04 | Link-quality wiring (closes E04-B03's carry-forward) | backend | M | must | T03 |
| E06-T05 | Live inbound pipeline — deliver or forward | backend | M | must | T03 |
| E06-T06 | MessagingCoordinator — relay driver, cursors, reconciliation (closes E05-B02) ⛔ | backend | M | must | T05 |
| E06-T07 | Prekey-bundle exchange (closes OQ-E05-T02-1) ⛔ | backend | M | must | T06 |
| E06-T08 | Delivery acknowledgements (Accepted/Delivered/Read) | backend | M | should | T07 |
| E06-T09 | Conversation read model | backend | S | must | T03 |
| E06-T10 | Conversations screen | frontend | M | must | T01, T09 |
| E06-T11 | **Chat screen (text-only) — the wedge** | frontend | M | must | T06, T07, T10 |
| E06-T12 | Dashboard screen | frontend | M | should | T04, T11 |
| E06-T13 | Design gap pass — voice/PTT/attachments/location | docs | S | could | T11 |

⛔ = carries a 🧍 blocking Open Question. See `tracker.md` §Blocked.

**Follow-on (not shardable yet — rule 2: no contract, no frontend task).**
Voice messages, PTT, attachments and location-in-chat become shardable once
T13's derived contracts are 🧍 approved. They are in FR-COMM-001's scope and
in this epic's; they are not in this shard.

T13 ran that gap pass on 2026-08-30 and produced three derived contracts plus
one recorded question. The follow-ons below are **listed, not sharded** — they
become shardable the moment `design/gaps.md`'s `design_contract_approval` gate
line reads cleared, and not one moment earlier. Sharding them now would
approve the contracts and consume them in the same breath, which is exactly
what the gate exists to prevent.

| Prospective task | Title | Layer | Est. | Design contract | Blocked by |
|---|---|---|---|---|---|
| E06-T14 | Voice messages — record, cancel, playback bubble | frontend | M | `design/screens/chat-voice.md` | 🧍 GAP-014 cleared **and** the press-and-hold / tap-to-toggle choice answered |
| E06-T15 | Voice-message capture + storage plumbing (codec, duration cap, on-disk placement) | backend | M | n/a | E06-T14's contract; overlaps E08's storage scope — settle the boundary before sharding |
| E06-T16 | Attachments — picker, send, in-progress/complete/failed card | frontend | M | `design/screens/chat-attachment.md` | 🧍 GAP-015 cleared **and** the picker container form (sheet vs menu) answered |
| E06-T17 | Attachment transfer plumbing (chunking, resume, size limits) | backend | M | n/a | E06-T16's contract; E08 owns retention — fence it explicitly |
| E06-T18 | Location-in-chat — share row + location bubble incl. FR-LOC-005 staleness | frontend | S | `design/screens/chat-location.md` | 🧍 GAP-016 cleared **and** E09's permission model existing (FR-LOC-001/002/003) |
| — | **PTT** | — | — | **none — deliberately** | `OQ-E06-T13-1` / GAP-017. No contract, no derivable primitive. Advisory: re-home to E07 alongside the real-time transport work; a re-home is a scope decision and goes through `skills/change-impact` |

Ids above are **placeholders for the planning pass that follows approval**,
not reservations — the pass may split, merge or renumber them, and E06-T15 /
E06-T17 may turn out to belong to E08 rather than here.

## Test strategy
End-to-end: two real (or emulated) devices, one sends a text message while
the other is offline, message queues, arrives on reconnect, decrypts
correctly, displays in order. This IS the epic's own proof — if this
journey doesn't work, nothing upstream mattered.

## Risks
| Risk | Mitigation |
|------|-----------|
| Largest UI surface of Wave 1 — three screens, real-time updates | Sub-shard text-only first; voice/PTT/attachments/location as follow-on tasks within the epic rather than one giant task |
| First epic to actually need the Flutter-capable design-fidelity gate (OQ-E00-3) | Build that gate as this epic's first or second task, not as an afterthought — every screen after this inherits it |

## Open Questions
Raised at sharding (2026-08-29). Two are 🧍 **blocking** and gate the wedge.

| id | Task | Priority | Question |
|---|---|---|---|
| **OQ-E06-T06-1** | T06 | 🔴 **blocking** | What drives the relay queue — timer, event, both, or background execution? (rule 3: architecture + battery/OS-lifecycle policy; inherited from E05-B02's human deferral). Advisory: (c) timer floor + event triggers, 60 s, foreground-only; background as an E10 task |
| **OQ-E06-T07-1** | T07 | 🔴 **blocking** | Over what channel does a device obtain a peer's prekey bundle — mesh-inline, a Firebase directory, or both? (touches ADR-0005's "thin account pointer" stance and the offline-first premise). Advisory: (a) mesh-inline for E06, Firebase fallback as an E11 task |
| **OQ-E06-T01-1** | T01 | 🟠 blocking for T10/T11/T12 | The app ships none of the three fonts every contract measures. Add the assets (new dependency, rule 3), scope a threshold relaxation (🧍 `design_threshold_relaxation`), or leave three screens permanently red. Advisory: add the assets |
| OQ-E06-T02-1 | T02 | important | The relay frame header is unsigned — a relay can redirect or expire a packet it forwards. Advisory: accept for v1, revisit at the pre-release security-lens pass |
| OQ-E06-T04-1 | T04 | important | `batteryDrain` has no producer. Advisory: a documented neutral constant now; peer-reported battery is a protocol change for the epic that needs it |
| OQ-E06-T04-2 | T04 | important (human action) | E04's transport has still never run on real Bluetooth hardware, and this epic puts real traffic on it |
| OQ-E06-T05-1 | T05 | important | Should an undecryptable message from a trusted contact be surfaced to the user? Advisory: count it, show nothing in E06, shard the surface with safety numbers |
| OQ-E06-T06-2 | T06 | ⚪ deferred | The multi-device gap-fill protocol (inherited OQ-E05-T04-1). Owner: **E11**; trigger: the first journey with two registered devices |
| OQ-E06-T06-3 | T06 | ⚪ deferred | `RelayDeliveryState.failed` and its reclaim-set defect. Owner: whoever first writes `failed`; the constraint travels with it |
| OQ-E06-T07-2 | T07 | important | One-time prekeys leak from the pool permanently (inherited from E03). T07 is what finally makes the trigger condition real |
| OQ-E06-T08-1 | T08 | important | Are read receipts sent, and is it a setting? Advisory: a setting defaulting to off, sharded into E02's settings surface |
| OQ-E06-T11-1 | T11 | important | No design source for a failed message. Advisory: reuse the queued glyph; design a real treatment with T13's gap pass |
| OQ-E06-T11-2 | T11 | important | What `Stored` means (inherited OQ-E05-T03-1, now two epics old). Advisory: document as unused now, retire at the next SRS amendment |
| OQ-E06-T11-3 | T11 | optional | Forward secrecy is bounded to in-order messages, and this screen is where the guarantee is shown (inherited from E03). Advisory: state it in GAP-005's Privacy & Security sub-screen |
| OQ-E06-T13-1 | T13 | important | PTT has no design source and no derivable primitive. Advisory: re-home to E07, alongside the real-time transport work |

Genesis-level **OQ-E00-3** is closed by **E06-T01**.

**Design gaps added at sharding** — GAP-006…GAP-013 in `design/gaps.md`,
all 🟡 awaiting 🧍 sign-off, plus GAP-002/003/004/005 still unsigned from
E02. T10/T11/T12 may not start until `design_contract_approval` clears.

## Analyze report
*(`skills/task-sharding` §6, run 2026-08-29 against E06-T01…T13, on
`development` @ `35710f7`, 250/250 tests green)*

| Check | Result | Notes |
|---|---|---|
| EARS trace | ✅ pass | Both epic-level criteria are owned: **EARS-COMM-1** → T11 (text slice; voice/PTT/attachments/location deferred to the follow-on tasks T13 makes shardable, recorded in §Tasks, not dropped), **EARS-COMM-2** → T12. Every task carries ≥1 `traces_to:` FR/NFR id. New sub-ids (COMM-3…COMM-28, ROUTE-10…12, MSG-7…9, UI-1/2) each cite an existing FR. **EARS-MSG-1** — E05's orphaned criterion, whose "and send once a route is available" half had no mechanism anywhere — is claimed by T06 with a regression test required to be red on `35710f7`. |
| Contract sanity | ✅ pass | One wire frame (T02) with one producer (T03's encrypt adapter) and one consumer (T05) — the exact producer/consumer pair whose absence was E05-B01, now asserted by a test in **both** tasks. One read model (T09) consumed identically by T10/T11/T12, so two screens cannot disagree about recency or blocking. `PayloadType.control` is defined once (T02) and extended at a declared seam by T07 and T08 rather than by re-versioning. No endpoints (no API surface in this epic). **Union-sufficiency check (L-process-005) run explicitly**: it found the acknowledgement gap — `Delivered`/`Read` had no producer on any device while the design draws three tick treatments — now owned by T08, and it found that `Failed` and `Stored` have no honest UI mapping, recorded as OQ-E06-T11-1/2 rather than guessed. |
| Collision matrix | ✅ pass | Empty for every parallelizable pair. Shared files are serialized by `depends_on`: `lib/core/messaging/messaging_stack.dart` on the chain T03→T06→T07→T08, and `lib/app/routes.dart` on T10→T11→T12. **T04 registers through `lib/app/bindings.dart` specifically so it does not collide with the messaging_stack chain** — a deliberate reshard, not a coincidence. Parallel sets: {T01, T02}; then {T04, T05, T09}; then T10 alongside the backend chain. T05 updates **no** existing file at all. |
| Scope fences | ✅ pass | All 13 §4 sections non-empty and specific to the temptation each task invites — e.g. T05's FR-ROUTE-003 prohibition (never decode a payload on the forward branch, asserted by a test that fails the run if `decrypt` is called), T11's "do not turn the inert `mic` button into a Send button", T09's "do not add a `previewText` field", T12's "do not synthesize a latency". |
| MoSCoW inflation | ⚠️ exception, justified | 10/13 `must` (77%). Same shape as E03/E04/E05 and, this time, checked rather than asserted: the wedge journey is a strict chain — a frame with no composition root sends nothing, a composition root with no inbound pipeline receives nothing, a pipeline with no driver forwards nothing, and a driver with no session encrypts nothing. Each of T02→T03→T05→T06→T07 delivers zero user value alone. The three non-`must` tasks are the genuinely deferrable slices and were graded down on their merits, not to fix the ratio: T08 (acks — the product works without ticks advancing), T12 (dashboard — a second surface over the same read model), T13 (a planning pass for a deferred half of the epic). T01 is `must` because rule 2 has been unenforceable for six epics and three screens land here. |
| Size | ✅ pass | 11×M, 2×S, **no L**. The epic's own §Risks mitigation (text-first, rich types as follow-ons) is what keeps T11 at M; the alternative single "chat screen" task including voice/PTT/attachments/location would have been a clear L. |
| Design | ✅ pass | Three `layer: frontend` tasks, each with an existing `design_contract:` — T10→`design/screens/conversations.md`, T11→`chat.md`, T12→`dashboard.md`. All three files exist with goldens. **Gap pass performed at sharding, as the epic instructed**: GAP-006…GAP-013 added to `design/gaps.md` (Groups empty until E07, conversations/chat empty states, the delivery-glyph mapping, the inert `add`/`mic` affordances, the E08 storage card, FR-UI-004's one-tap destination, the disconnected status readings). All 🟡 with empty `approved by:` lines — **the three UI tasks are gated on 🧍 `design_contract_approval`**, and T13 produces the derived contracts the rich message types need before any of them can be sharded. |
| Obligation ownership | ✅ pass | Grepped every task file for every other task id and for sibling-naming prose. Three cross-task obligations found, and each is independently stated in the owning task's binding contract, not only in the sibling's prose: (1) **T05's `start()` is called by nobody in T05** — declared in T06's §3 *and* in T06's `functions:` block as the purpose of `MessagingCoordinator.start()`; (2) **T02's `PayloadType.control` is used by nobody in T02** — T07 and T08 each declare their own control sub-protocol and their own `handleControlFrame` in their `functions:`; (3) **T09 deliberately excludes preview decryption** and names the screen layer as the owner — T10's §2 and its `ConversationsController` contract state the decryption obligation independently. This is the check L-process-006 added at recurrence 1 after E05-B01; it was run mechanically, and it changed the shard (T06's `functions:` block gained an explicit line for T05's `start()`). |
| **Inherited obligations** | ⚠️ **pass with 5 explicitly-owned open items and 3 explicitly-declined** | §0 was run for the first time since L-process-007's promotion. See the full table below — **24 obligations enumerated, 0 silently dropped.** |

### Inherited obligations — §0 pass

Sources read in full before slicing: `epics/E02-trust-blocking/retro.md`,
`epics/E03-e2e-encryption/retro.md`, `epics/E04-mesh-routing/retro.md`,
`epics/E05-messaging-reliability/retro.md`, the bug files `E04-B02.md`,
`E04-B03.md`, `E05-B01.md`, `E05-B02.md`, `E05-B03.md`, the `## Open
Questions` of `E05-T02/T03/T04`, and E05's own §Bug sweep merge-gate notes.

| # | Obligation (source) | Disposition |
|---|---|---|
| 1 | **E04-B03 link-quality wiring** — E04 retro: *"E05 must wire real RSSI/latency/loss into the now-extended Pigeon contract"*; E05 retro escalated it to 🔴 *"twice-dropped … must enter E06's sharding as a named dependency"* | **covered-by E06-T04** — its own task, with `test_EARS_ROUTE_11_*` required to be red on `35710f7` |
| 2 | **E05-B02 relay-queue driver** — `processQueue`/`sweepExpired`/`reclaimPayloads` have zero callers; human deferred to E06 with the owning epic named | **covered-by E06-T06**, with E05-B02's own §Repro grep required in the DoD |
| 3 | **E04-B02 retention guarantee** — *"only becomes real once … both [are wired] onto a scheduler"* | **covered-by E06-T06** (`reclaimPayloads` on the tick, E04-B02's established order) |
| 4 | **`SyncCursorService.recordLocalProgress` has no caller, and its doc comment claims one** (E05-B02 §Related) | **covered-by E06-T06** — wiring *and* the comment correction, both in `files:` |
| 5 | **OQ-E05-B01-1 — who re-types relayed bytes into a `CiphertextMessage`**; reviewer's suggested fix: carry `getType()` in E04's relay framing | **covered-by E06-T02** (the tag), **E06-T03** (producer adapter), **E06-T05** (consumer) — three tasks, one seam, with a round-trip test in each |
| 6 | **OQ-E05-T02-1 — no prekey-bundle exchange exists anywhere** | **covered-by E06-T07** — and it carries 🧍 `OQ-E06-T07-1` because the *channel* is unsettled by any ADR |
| 7 | **OQ-E05-T04-1 — no gap-fill protocol** | **owned Open Question `OQ-E06-T06-2`** — ⚪ deferred, **owner: E11**, revisit trigger named ("the first journey with two registered devices"), extension points named (T02's `control` tag, T05's `ControlHandler`). Deferred because nothing in E06 has a second device to catch up with; building it here would be speculative protocol design |
| 8 | **OQ-E05-T03-1 — what `Stored` means** | **owned Open Question `OQ-E06-T11-2`** with options + advisory. Honest finding recorded: E06's UI does not need the distinction either, so the recommendation is to answer or retire it rather than forward it a third time |
| 9 | **E05-B03 — `Sent` = durably enqueued locally** (human resolution) | **covered-by E06-T11 §2** — the UI must not imply the radio sent it; `Queued` gets its own glyph precisely for this, per GAP-009 |
| 10 | **`delivery_states` has no product writer** (E05-T02 review, obs. 2) | **covered-by E06-T06** — the coordinator is the one component that sees every transition |
| 11 | **`SendMessageUseCase._generateId` is unique per instance only; two instances collide on `messages.id`** (E05-T02 review, obs. 4) | **covered-by E06-T03** — single-instance registration is a stated correctness requirement with `test_EARS_COMM_6_stack_is_a_single_instance` |
| 12 | **Crash between `enqueue` and the `sent` UPDATE leaves an unreconciled `queued` row** (E05-T02 review, obs. 3) | **covered-by E06-T06** — `reconcileQueuedMessages()` at startup, idempotent |
| 13 | **`_requireStore` makes a misconfiguration surface as `messaging.no_session`** (E05-T02 review, obs. 5, S4) | **covered-by E06-T02** — the typed failure taxonomy replaces the overloaded `StateError` path |
| 14 | **`RelayDeliveryState.failed` is never assigned and is excluded from `reclaimPayloads`'s reclaim set** (E04 retro) | **owned Open Question `OQ-E06-T06-3`** — ⚪ deferred with the constraint attached: whoever first writes `failed` must extend the reclaim set in the same change or state why not. T06 §4 explicitly forbids writing it, so the defect is not inherited silently |
| 15 | **E03-B03 — `InvalidMessageException` not exported; deferred to whoever first wraps a `catch` around `decrypt()`** | **covered-by E06-T02** (the taxonomy) + **E06-T05** (the catch). E06 is that epic |
| 16 | **Issued-but-never-consumed one-time prekeys leak permanently; needs a policy "before bundles issue at real volume"** (E03 retro) | **owned Open Question `OQ-E06-T07-2`** — the trigger condition is now met by T07, mitigated meanwhile by T07's trust gate and counters, sized as its own task once the channel question is answered |
| 17 | **Forward secrecy is bounded to in-order messages; "should be stated wherever that guarantee is shown to a user"** (E03 retro) | **owned Open Question `OQ-E06-T11-3`** — T11 is the task that prints "End-to-end encrypted"; advisory routes it into GAP-005's Privacy & Security sub-screen |
| 18 | **OQ-E00-3 — no Flutter-capable design gate**; E02 retro: *"before E06 (the wedge) reaches review"*; this epic's own §Risks: first or second task | **covered-by E06-T01** — first task, blocks all three UI tasks |
| 19 | **No font-family theming anywhere; needs a font-asset dependency decision (rule 3)** (E02 retro, S3) | **owned Open Question `OQ-E06-T01-1`** — 🟡 **blocking for T10/T11/T12**, because the moment the gate is live every text element reports an off-token finding and the only alternative is a 🧍 threshold relaxation |
| 20 | **GAP-002/003/004/005 still need the human's actual sign-off** (E02 retro; L-process-002) | **carried forward and compounded** — this shard adds GAP-006…GAP-013, all 🟡 with empty `approved by:` lines. T10/T11/T12 are gated on `design_contract_approval`. Recorded here so the backlog of unsigned gaps is visible at one gate rather than eight |
| 21 | **`metrics.csv` still does not exist** — carried by every retro since E00; E05's retro: *"it should stop being a retro line and become a task"* | **explicitly NOT owned by an E06 task, and here is why** — it is harness infrastructure with no FR/NFR id, so a task for it would violate rule 1's `traces_to:` requirement and `make validate` would reject it. **Routed to the human as a harness item**, not left in a retro: it needs either a spec id (an NFR about process observability) or a decision that it lives outside the epic system. Six retros have now recorded it |
| 22 | **The lesson hook never injects `qa.md`** — `index.yaml` maps no layer to the `qa` area (E05 retro) | **explicitly NOT owned by an E06 task** — a harness-configuration change affecting every dispatch, which E05's retro itself said should not be made silently. **Routed to the human** |
| 23 | **`ConflictResolver` has no caller** (E05 sweep: *"a real seam for whoever wires it"*) | **explicitly declined for E06, with reason** — conflict resolution serves FR-MSG-006/007 across *devices of one account*, and E06 has no second device and no Firebase sync path. **Owner: E11 (Firebase Sync)**, which owns FR-MSG-006's "identify missing information, synchronize, and resolve conflicts". Recorded so the decline is visible rather than an omission |
| 24 | **`signal_identity` stores the local identity keypair in plaintext SQLite; "worth a security-lens pass before release"** (E03 retro) · and **`DevicesController.verify()` bypasses the domain layer** (E02 retro) | **explicitly declined for E06, with reason** — neither is touched by any E06 task's `files:`, and fixing either from inside this epic would be out-of-fence work on merged code (rule 6). The first is routed to the pre-release security-lens pass, where `OQ-E06-T02-1` (unsigned frame headers) also lands; the second remains E02 backlog |

**Net on this row:** 24 obligations, 16 covered by a named task, 5 carried
as explicitly-owned Open Questions with owners and revisit triggers, 3
explicitly declined with reasons and re-homed. **Zero silently dropped** —
which is the whole point of the rule, given that the same carrier lost two
obligations at a 100% rate across E04→E05.

**Net overall:** 7/9 clean pass, 1 disclosed MoSCoW exception with an
evidenced justification, 1 Inherited-obligations pass with its open items
enumerated above. Two 🧍 blocking architecture questions raised rather than
guessed (`OQ-E06-T06-1` relay-queue trigger model, `OQ-E06-T07-1` prekey
channel), each with options, honest trade-offs and an advisory
recommendation, per rule 3.

🧍 **HUMAN GATE** (`analyze_report`) — ⏳ AWAITING HUMAN.
Note that unlike previous epics, this one **cannot fully proceed under the
standing "continue without per-gate pauses" instruction**: T06 and T07 carry
blocking questions that rule 3 reserves for you, and T11 — the wedge —
depends on both. T01, T02, T03, T04, T05, T09 and T10 are dispatchable
today; the design-gap sign-off and `OQ-E06-T01-1` gate T10/T11/T12.

## Retro
→ `retro.md` (written after E06 completion)
