---
id: chat-group
impl_path: /groups/[id]
source: derived
derived_from: [chat, conversations]
states: [thread, bubble-incoming-attributed, event-line, bubble-blocked-placeholder, empty]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-COMM-002, FR-GROUP-002, FR-GROUP-003]
gap: GAP-020
---
# chat-group · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> a **1:1** thread only: incoming and outgoing bubbles with no sender name,
> and no system/event line of any kind. This contract composes a group thread
> **only** from primitives `design/screens/chat.md` and
> `design/screens/conversations.md` already measure.
>
> **✅ GAP-020 approved by human, 2026-08-31** — "approved as proposed (build
> still waits on `OQ-E07-13`, unresolved by this approval)".
>
> **✅ `OQ-E07-13` answered by human, 2026-09-25** — *"In a group thread, a
> blocked member's messages should remain represented as placeholders rather
> than being silently dropped or rendered as normal readable messages."*
> Both preconditions GAP-020 named are therefore met, and this contract may
> be written and built.
>
> GAP-020 states explicitly that it is **a state on `chat.md`, not a new
> screen**, and that `chat.md` is generated and is never hand-edited
> (`design-fidelity` rule 1). This file is that state written down as its own
> derived contract — the same device `chat-voice.md`, `chat-attachment.md`
> and `chat-location.md` already use for states of the same parent screen.

- **Route:** `/groups/[id]`. **Not** `/chat/[id]`: `ChatController` is
  structurally 1:1 — it treats `conversationId` as a Signal **peer device
  id** and runs X3DH against it. `E07-B01` measured what happens when a group
  id reaches it, and the human closed that route to group ids on 2026-09-02
  (P1, fix direction (a)). `E07-B05` re-closed the second door. A separate
  route keeps that invariant intact instead of widening the 1:1 controller,
  which `E07-B01` §What this fix does NOT do explicitly forbids.
- **Parent contracts:** `design/screens/chat.md` (bubbles, composer, header)
  and `design/screens/conversations.md` (the sender-attribution treatment).
  Every token below is cited by name from one of their measured tables.

## Derivation boundary — what is NOT derived

**One string in this contract has no source anywhere in the design: the
blocked-member placeholder copy** (`G9` below). The human decided the
*behaviour* on 2026-09-25 — a placeholder, neither dropped nor readable —
but no design source, and no answer, supplies the words.

The existing placeholder primitive **cannot be reused as-is**:
`chat_view.dart:355` renders `(unable to decrypt this message)` for a null
plaintext. For a blocked member that sentence would be **false** — a blocked
member is still a group member holding a valid sender key, so the message
usually decrypts fine. It is withheld by policy, not by failure. Saying
"unable to decrypt" would misreport the app's own reason.

So `G9`'s copy is **proposed, not approved**, and is carried in `GAP-045`
with two named alternatives. It is built as proposed so the group journey is
usable end to end (the human's 2026-09-25 instruction to *"proceed to build
the complete group-thread journey"*), and it is a one-line change if the
human picks differently. Its *treatment* is not invented: it takes the
existing bubble box and the already-measured secondary text colour.

Also explicitly out of this contract: attachments, voice, PTT and location
inside a group thread (their own contracts, each with its own gap), group
calls, and any membership-management affordance (`group-manage.md`).

## States

### 1. `thread`
`chat.md`'s thread, unchanged, with the header naming the group instead of a
peer. Elements 1-8 keep their measured geometry.

| id | role | copy / label | source |
|---|---|---|---|
| G1 | `button` | — 40×46 `r9999px` | chat 1 |
| G2 | `generic` | `arrow_back` 24×24 · `24px` `rgb(70, 69, 85)` | chat 2 |
| G3 | `heading:1` | *(the group's name)* `22px` · `w500` · `rgb(53, 37, 205)` | chat 4 |
| G4 | `generic` | `lock` 14×14 · `14px` `rgb(53, 37, 205)` | chat 5 |
| G5 | `generic` | `End-to-end encrypted` `12px` · `w500` · `rgb(53, 37, 205)` | chat 6 — verbatim, unchanged |
| G6 | `textbox:multiline` | placeholder: `Secure message...` | chat 28 — verbatim |
| G7 | `button` | — 48×48 · bg `rgb(53, 37, 205)` · `r9999px` | chat 30 |

**`chat.md` element 3 (the 38×38 peer avatar) is NOT rendered.** The design
draws a per-person image there and a group has no single person. The
`Groups` section of `conversations.md` faced the identical problem and
resolved it with the `dns` glyph at `24px` `rgb(0, 70, 102)` (conversations
element 22) — reused here rather than inventing a group avatar.

### 2. `bubble-incoming-attributed`
GAP-020's approved rule, verbatim: *"in a group thread, an incoming bubble
carries a sender attribution line in element 26's treatment; outgoing bubbles
do not (the design never labels the user to themselves)."*

| id | role | copy / label | source |
|---|---|---|---|
| G8 | `generic` | *(sender name)* `14px` · `w500` · `rgb(11, 28, 48)` | conversations 26 (`David Chen:`) — the one place the design acknowledges a group message has an author |

The bubble body itself is `chat.md`'s measured inbound box (270-272×48, chat
12/15/20), unchanged. Outgoing bubbles carry **no** G8.

### 3. `bubble-blocked-placeholder`
The human's 2026-09-25 `OQ-E07-13` answer.

| id | role | copy / label | source |
|---|---|---|---|
| G9 | `generic` | `Message from a blocked contact` — **proposed copy, `GAP-045`, not approved** | treatment from chat 12/15/20 (the bubble box) + `rgb(70, 69, 85)` (chat 18's secondary text) |

Rules, all three from the human's answer:
- the message **is** represented — never silently dropped from the thread;
- its body is **not** rendered readable;
- it keeps G8's sender attribution, because hiding *who* it was from would be
  a second, undecided product behaviour.

### 4. `event-line`
GAP-020's approved rule, verbatim: *"Membership changes render as centred,
surface-less event lines — 'Ahmed added David', 'Group renamed to Work' — one
per `group_events` row."*

| id | role | copy / label | source |
|---|---|---|---|
| G10 | `generic` | *(event sentence)* `14px` · `rgb(70, 69, 85)`, centred, **no bubble surface** | chat.md's own secondary-text treatment, as GAP-020 specifies |

### 5. `empty`
A group with no messages yet — the state a user reaches immediately after
creating one, so it is not hypothetical. No new primitive: the thread frame
(state 1) renders with no bubbles. The design draws no empty-state
illustration or copy anywhere in seven contracts and none is invented here.

## Tokens used — every one already measured

| token | value | source |
|---|---|---|
| header glyph | `rgb(70, 69, 85)` `24px` | chat 2 |
| group title | `22px` `w500` `rgb(53, 37, 205)` | chat 4 |
| encryption notice | `12px` `w500` `rgb(53, 37, 205)` | chat 5-6 |
| group glyph | `dns` `24px` `rgb(0, 70, 102)` | conversations 22 |
| sender attribution | `14px` `w500` `rgb(11, 28, 48)` | conversations 26 |
| bubble box | 270-272×48 | chat 12/15/20 |
| outgoing bubble fill | `rgb(53, 37, 205)` | chat 30 |
| secondary text | `rgb(70, 69, 85)` | chat 18 |
| timestamp | `12px` `w500` `rgb(70, 69, 85)` | chat 11/13 |
| composer send | 48×48 `r9999px` bg `rgb(53, 37, 205)` | chat 30 |

**No new colour, size, radius or font enters the app through this contract.**
