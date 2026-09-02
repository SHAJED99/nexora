---
id: call
impl_path: /call/:id
source: derived
derived_from: [chat, dashboard]
states: [outgoing, incoming, in-call, in-call-degraded, failed]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-CALL-001, FR-CALL-002, FR-CALL-003, FR-COMM-001]
gap: [GAP-021, GAP-022]
---
# call · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **nothing** about voice calls: no call screen, no ringing state, no call
> controls, and no call affordance on any of the seven measured contracts —
> including `chat.md`, whose header has no call button. This contract composes
> the surface **only** from primitives `design/screens/chat.md` and
> `design/screens/dashboard.md` already measure.
>
> **Built against GAP-021 and GAP-022, both approved by the human on
> 2026-08-31** — GAP-021 "as proposed, including adding a call-entry
> icon-button to `chat.md`'s header"; GAP-022 "silent on a successful
> migration, GAP-013's degraded-card treatment on an abandoned one". This
> contract is *written against* those approvals; it is **not** independently
> approved by an agent, and the three items marked
> `[pending human confirmation]` below are genuinely open. Written by
> `E07-T12`.

- **Route:** `/call/:id` — a new route. Registering it is the build task's job.
- **Parent contracts:** `design/screens/chat.md` (peer identity, the header
  icon-button vocabulary, the composer button geometry, the timestamp
  treatment) · `design/screens/dashboard.md` (the network-status card, its
  status row and its latency readout)
- **State authority:** `CallSession` (`E07-T09`) and `CallMigrationEvent`
  (`E07-T11`). Every element below corresponds to a state the machine can
  actually be in. There is no element for a state it cannot reach.

## The constraint this contract exists to respect
GAP-021 states it plainly and it is the single most important line here:
**every control must trace to FR-CALL-001/002/003 or to a state `CallSession`
can actually be in.** So this contract draws:

- **no speaker toggle** — no spec id, no session state, no audio path;
- **no video** — FR-CALL-001 says *voice* calls;
- **no add-participant** — group calling is `OQ-E07-11`, explicitly out of
  v1 scope (`E07-T09` §2), and drawing the button would promise it;
- **no keypad, no hold, no record** — nothing in the SRS asks for them.

FR-CALL-002 (call priority) has **no element at all**, deliberately: it is a
routing weight, invisible by construction, and a UI control for it would be a
promise the spec never made.

## Derivation boundary — what is NOT derived

1. **Three glyph identities.** `chat.md` draws `mic`; no contract in
   `design/screens/` draws `call`, `call_end` or `mic_off` (checked across all
   seven). Their family, size and colour ARE measured tokens; only the glyph
   identity is proposed copy, marked `[glyph — pending human confirmation]`
   below — exactly how `chat-voice.md` handled the same problem.
2. **The destructive treatment for decline / hang up.** Neither parent
   contract measures a red. The two honest options are put to the human in
   §Open below; until one is chosen, the fallback is stated and is *not*
   a new colour.
3. **New copy.** Every string is listed in §Copy. Two of them are marked
   `[copy — pending human confirmation]` because they are product voice, not
   layout.
4. **Nothing else.** Every other value is grep-verifiable in a parent
   contract's measured token table.

Out of this contract entirely: the media transport itself (`OQ-E07-3`, a 🧍
rule-3 decision), codecs, echo cancellation, call history (`E07-T09` §4 adds
no table), and group calls (`OQ-E07-11`).

## States

### 1. `outgoing` — `outgoingPending` → `outgoingRinging`
Peer identity, a status line, and one control: cancel. `E07-T09`'s 45 s
caller-side ring timeout ends this state; nothing counts down on screen (the
design draws no countdown primitive, and a visible timer would make a normal
timeout feel like a fault).

### 2. `incoming` — `incomingRinging`
Peer identity, a status line, and **two** controls: decline and accept. The
callee stops ringing at 45 s too, so both ends agree without a round trip.

### 3. `in-call` — `active`
Peer identity, elapsed duration, the connection-quality card, and two
controls: mute and hang up. **A successful mid-call route migration renders
nothing** — GAP-022, approved: FR-CALL-003's own words are "minimizing call
interruption", and a migration that succeeded is a non-event.

### 4. `in-call-degraded` — `active`, after `CallMigrationEvent.abandoned`
Identical to `in-call`, with the status row switched to the degraded reading.
Entered **only** when a migration was abandoned and the active route's quality
is already poor (GAP-022's exact scope). Not entered on a successful
migration, and not entered on a single abandoned attempt over a healthy route.

### 5. `failed` — `ended(reason)`
The honest state. Today `NullCallMediaTransport` drives every answered call
here (`E07-T09` §2), and this state **must say that audio cannot be carried**.
It may never render as a connected call. Peer identity stays; the controls are
replaced by a single dismissal.

## Elements — the build checklist

### Identity block (all states)
| # | role | copy / label | size | key styles (cited from the parent contracts) |
|---|---|---|---|---|
| C1 | `image` | — | 38×38 | the chat header avatar (chat 3) |
| C2 | `heading:1` | (peer name) | 172×28 | `22px` · `w500` · `rgb(53, 37, 205)` — the chat header peer name (chat 4) |
| C3 | `generic` | `lock` | 14×14 | `14px` · `rgb(53, 37, 205)` — chat 5, unchanged |
| C4 | `generic` | `End-to-end encrypted` | 154×16 | `12px` · `w500` · `rgb(53, 37, 205)` — chat 6, copy unchanged. FR-CALL-001 says *secure* voice calls; this is the line the design already owns for saying so |

### Status row (all states) — the dashboard network-status treatment
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| C5 | `generic` | `circle` | 16×16 | `rgb(0, 101, 145)` in `in-call`; `rgb(70, 69, 85)` in every other state — dashboard 7, with GAP-013's already-approved muted-dot reading for the non-connected cases. No new colour |
| C6 | `generic` | (status word — see §Copy) | 69×16 | `12px` · `w500` · `rgb(11, 28, 48)` — dashboard 8, the `Connected` label treatment |

### State `outgoing`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| C7 | `button` | — | 48×48 | `r9999px` — the composer button geometry (chat 26) |
| C8 | `generic` | `call_end` `[glyph — pending human confirmation]` | 24×24 | `24px` · see §Open for the colour. Cancels the outgoing call (`CallEndReason.cancelled`) |

### State `incoming`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| C9 | `button` | — | 48×48 | `r9999px` (chat 26) — decline |
| C10 | `generic` | `call_end` `[glyph — pending human confirmation]` | 24×24 | `24px` · see §Open. `CallEndReason.declined` |
| C11 | `button` | — | 48×48 | `bg rgb(53, 37, 205)` · `r9999px` — the accent composer button (chat 30) — accept |
| C12 | `generic` | `call` `[glyph — pending human confirmation]` | 24×24 | `24px` · `rgb(255, 255, 255)` — the accent button's own glyph treatment (chat 31) |

### State `in-call` / `in-call-degraded`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| C13 | `generic` | `0:07` | 62×16 | `12px` · `w500` · `rgb(70, 69, 85)` · `JetBrains Mono` — the message-timestamp treatment (chat 11/13/19/21/24), format `M:SS`, exactly as `chat-voice.md` V4 borrowed it for its elapsed counter |
| C14 | `generic` | (quality card container) | — | `bg rgb(248, 249, 255)` · border `rgba(11, 28, 48, 0.1)` · `r8px` — the dashboard status-card treatment (dashboard token table), the same card GAP-014 already borrowed once |
| C15 | `generic` | `speed` | 18×18 | `18px` · `rgb(70, 69, 85)` — dashboard 12, unchanged |
| C16 | `generic` | `Latency` | 54×16 | `12px` · `w500` · `rgb(70, 69, 85)` — dashboard 13, copy unchanged |
| C17 | `generic` | (measured latency, e.g. `24ms`) | 142×20 | `14px` · `w500` · `rgb(70, 69, 85)` — dashboard 14. **A real measurement or a neutral placeholder — never a fabricated number** (GAP-013's approved rule, inherited verbatim) |
| C18 | `button` | — | 48×48 | `r9999px` (chat 26) — mute |
| C19 | `generic` | `mic` / `mic_off` `[glyph — pending human confirmation]` | 24×24 | `24px` · `rgb(53, 37, 205)` — the plain composer button's glyph treatment (chat 27). `mic` is chat's own glyph (chat 31); only `mic_off` is proposed |
| C20 | `button` | — | 48×48 | `r9999px` (chat 26) — hang up |
| C21 | `generic` | `call_end` `[glyph — pending human confirmation]` | 24×24 | `24px` · see §Open. `CallEndReason.hangup` |

**`in-call-degraded` differs from `in-call` in exactly two cells**: C5 renders
muted `rgb(70, 69, 85)` and C6 carries the degraded reading. Nothing moves,
nothing appears, nothing is added — GAP-022 chose the quietest treatment that
is still honest, and a layout shift mid-call would defeat it.

### State `failed`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| C22 | `generic` | (end-reason line — see §Copy) | — | `14px` · `rgb(70, 69, 85)` — the dashboard body treatment (dashboard 16/24/29/34), centred. No error colour is invented; GAP-009 refused to invent one for the same reason |
| C23 | `button` | `Close` | 116×34 | `12px` · `w500` · `rgb(255, 255, 255)` · `bg rgb(53, 37, 205)` · `r8px` — **borrowed from `devices.md` element 6** (`Discover`), this design's only measured primary button; neither parent contract measures one. Cited as a cross-screen borrow in §Tokens, the same way GAP-009 borrowed dashboard's glyphs into chat |

## The entry point — `chat.md`'s header (GAP-021, approved)
The human approved adding a call-entry icon-button to `chat.md`'s header,
using its existing 24px icon-button vocabulary. Specification:

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| C24 | `button` | — | 40×46 | `r9999px` — the chat header icon-button (chat 1/7), unchanged |
| C25 | `generic` | `call` `[glyph — pending human confirmation]` | 24×24 | `24px` · `rgb(70, 69, 85)` — the `arrow_back` / `more_vert` header-glyph treatment (chat 2/8), unchanged |

Placed in the header's trailing group, before `more_vert` (chat 7/8).

**Two consequences the build task must know.** (a) `chat.md` is **not**
hand-edited to add C24/C25 — `E07-T12` §4 and design-fidelity rule 1 both
forbid touching a generated contract. (b) `make design-verify SCREEN=chat`
will therefore report C24/C25 as **extra elements**; the reviewer traces that
finding to GAP-021, which is what design-fidelity §6 prescribes for extra
elements. It is a known, approved, traceable finding — not drift.

**In a group thread** the same button is not drawn: group calling is
`OQ-E07-11`, out of v1 scope. A call button on a group thread would promise
conferencing that does not exist.

## Copy — verbatim
Status words (C6), one per `CallState`:

- `Calling…` — `outgoingPending`
- `Ringing…` — `outgoingRinging`
- `Incoming call` — `incomingRinging`
- `Connected` — `active`. **Reused verbatim from `dashboard.md`** (element 8),
  not a new string
- `Connection degraded` `[copy — pending human confirmation]` — `active` after
  an abandoned migration over an already-poor route (GAP-022)
- `Call ended` — `ended`

End-reason lines (C22), one per `CallEndReason` (`E07-T09` §2) — proposed copy:

| reason | line |
|---|---|
| `failed` (no media transport — today's only answered-call outcome) | `Voice calls can't carry audio on this device yet.` `[copy — pending human confirmation]` |
| `declined` | `Call declined.` |
| `busy` | `They're on another call.` |
| `cancelled` | `Call cancelled.` |
| `hangup` | `Call ended.` |
| `timeout` | `No answer.` |
| `unreachable` | `No route to this peer.` — **reused verbatim from GAP-013's approved copy**, not a new string |

Other strings this contract introduces: `Close`.

Reused unchanged from `chat.md`: `lock`, `End-to-end encrypted`, `mic`.
Reused unchanged from `dashboard.md`: `circle`, `speed`, `Latency`,
`Connected`.

**The `failed` line is the one string in this contract that must not be
softened.** `E07-T09` §2 exists to make a call that cannot carry audio *say
so* rather than pretend. Copy that hides it would defeat the task that made
the honest state.

## Tokens — every value cited from a measured table

| role | value | source contract | used here for |
|---|---|---|---|
| text colour | `rgb(53, 37, 205)` | chat | C2, C3, C4, C19 |
| text colour | `rgb(70, 69, 85)` | chat · dashboard | C5 muted, C13, C15, C16, C17, C22, C25 |
| text colour | `rgb(11, 28, 48)` | chat · dashboard | C6 |
| text colour | `rgb(255, 255, 255)` | chat · dashboard | C12, C23 label |
| text colour | `rgb(0, 101, 145)` | chat · dashboard | C5 connected dot |
| surface / fill | `rgb(53, 37, 205)` | chat · dashboard | C11, C23 fill |
| surface / fill | `rgb(248, 249, 255)` | chat · dashboard | C14 card fill |
| border | `rgba(11, 28, 48, 0.1)` | dashboard | C14 card border |
| font size | `22px` | chat · dashboard | C2 |
| font size | `18px` | dashboard | C15 |
| font size | `14px` | chat · dashboard | C17, C22 |
| font size | `12px` | chat · dashboard | C4, C6, C13, C16, C23 |
| font size | `24px` | chat · dashboard | all control glyphs |
| font weight | `500` | chat · dashboard | labels, names, counters |
| radius | `9999px` | chat · dashboard | C7, C9, C11, C18, C20, C24 |
| radius | `8px` | chat · dashboard | C14, C23 |
| font family | `Material Symbols Outlined` | chat · dashboard | all glyphs |
| font family | `JetBrains Mono` | chat · dashboard | C13 duration |
| font family | `Inter` | chat · dashboard | all prose |
| **cross-screen borrow** | `116×34` primary button box | **devices** (element 6) | C23 — neither parent measures a primary button |
| **cross-screen borrow, pending** | `rgb(186, 26, 26)` | **devices** (32/37/38) | the destructive glyph colour — see §Open |

## Open — items genuinely awaiting the human

**1. The destructive treatment for decline / hang up (C8/C10/C21).**
Neither `chat.md` nor `dashboard.md` measures a red. Options:
- **(a) *Advisory*** — tint the `call_end` glyph `rgb(186, 26, 26)`, devices'
  measured destructive text colour, cited as a cross-screen borrow. This is
  the same borrowing pattern GAP-009 (dashboard glyphs into chat) and GAP-014
  (`circle` into chat) were approved with, and it keeps the value in its
  measured role — a *text* colour, never a fill. No red button exists anywhere
  in the design and none is proposed.
- **(b)** leave the glyph at `rgb(53, 37, 205)` (chat 27's treatment), so
  decline and hang up read no differently from mute.

**Fallback until answered: (b).** It is quieter than the design deserves, but
it invents nothing. Do not ship (a) before it is approved.

**2. Three glyph identities** — `call`, `call_end`, `mic_off`. Family, size
and colour are measured; only the names are proposed.

**3. Two copy strings** — `Connection degraded` and the media-unavailable
line. Product voice, not layout.

None of the above blocks the rest of the contract; a build task can be sharded
against it with these three items carried as its own open questions, provided
the fallback in (1) is what ships until the human answers.

## Derivation
| What | Borrowed from | Serves |
|---|---|---|
| peer identity block, the encryption line, header icon-button vocabulary, composer button geometry and glyph treatments, the `M:SS` timestamp treatment | `design/screens/chat.md` (elements 1/2, 3, 4, 5, 6, 7/8, 11/13, 26/27, 30/31) | FR-CALL-001, FR-COMM-001 |
| status row (`circle` + status word), latency readout, status-card container, body text treatment | `design/screens/dashboard.md` (elements 7, 8, 12, 13, 14, 16/24/29/34, card tokens) | FR-CALL-001, FR-CALL-003, FR-UI-004's "simple connectivity state" idiom |
| the muted-dot reading for every non-connected state, the never-fabricate-a-number rule, `No route to this peer.` | GAP-013, already approved | FR-CALL-003 |
| primary button box (C23) | `design/screens/devices.md` (element 6) | dismissal |
| silent-on-success, degraded-card-on-abandonment | GAP-022, approved 2026-08-31 | FR-CALL-003 |

**Spec served:** FR-CALL-001 (secure voice calls — C1-C4 and the whole
surface), FR-CALL-002 (priority — deliberately *no* element; see §The
constraint), FR-CALL-003 (migration — the `in-call` / `in-call-degraded`
pair), FR-COMM-001 ("…voice calls…"), `spec/feature-list.md` §Voice Calls →
"UC: User places a secure voice call".

## Notes for the implementing agent
- **`failed` is not an error screen, it is the truthful outcome.** Until
  `OQ-E07-3` is answered, every answered call reaches it (`E07-T09` §2). Build
  it first, not last.
- Read `CallState` from the session's broadcast stream. There is no
  "connecting…" state in this contract because there is none in the machine,
  and a UI that can be in an unrepresentable state is the stuck-forever
  spinner `E07-T09` §2 set out to prevent.
- Migration events (`E07-T11`) drive only the C5/C6 pair, and only on
  `abandoned` over an already-poor route. `attempted`, `validated` and
  `completed` render nothing. That is GAP-022's decision, not an oversight.
- Do not add a call button to a group thread (`OQ-E07-11`).
- Once built, extract the built screen as its own golden.
