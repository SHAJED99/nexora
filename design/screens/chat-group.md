---
id: chat-group
impl_path: /groups/[id]
source: derived
derived_from: [chat, conversations]
states: [thread, bubble-incoming-attributed, event-line, bubble-blocked-placeholder, empty]
# GAP-045 answered by the human 2026-09-25 (option (b)), so state 3 is no
# longer blocked and returns to `states[]`. The `blocked_states` key this
# file briefly carried is gone with it.
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

**No copy is invented in this contract.** One string had no source — the
blocked-member placeholder — and it was carried as `GAP-045` until the human
chose option **(b)** on 2026-09-25: `Message hidden — contact is blocked`.
It is approved, not proposed, and it is the only copy here that is not
already measured on a parent screen.

**No token pairing is invented either, as of 2026-09-25.** G11's event line
briefly carried `14px` + `rgb(70, 69, 85)` because `GAP-020`'s approved prose
said so; that prose was wrong about its own source, and the human reconciled
it to the measured `12px` `w500`. Both readings and the reconciliation are
recorded under state 4 — `GAP-020` itself is left byte-unchanged.

**One element is specified and deliberately NOT built:** G7's send button.
Its geometry and fill are measured, but its glyph **identity** was not —
`send` appears in no contract and nowhere in this app, the same shape
`GAP-014` handled for record-stop/play/pause. Carried as **`GAP-047`** and
resolved by the human on 2026-09-25 as **option (c): no send button on any
screen.** The composer submits from the keyboard's own send key, which is
exactly what the shipped 1:1 composer does. No new glyph, no new glyph
contract, and `chat.md` untouched.

**One derivation remains, and it is placement, not value:** G8's `dns` glyph
has a measured glyph, size and colour (`conversations.md` element 22) but is
measured in a *list row* and used here in a *thread header*.

Also explicitly out of this contract: attachments, voice, PTT and location
inside a group thread (their own contracts, each with its own gap), group
calls, delivery ticks (`chat.md`'s tick elements belong to the 1:1 contract;
GAP-020 derives none for groups), the `more_vert` overflow menu, and any
membership-management affordance (`group-manage.md`).

## States

### 1. `thread`
`chat.md`'s thread, with the header naming the group instead of a peer. Not
every parent element carries over, and the two that do not are named here
rather than silently dropped (rule 2):

| id | role | copy / label | source |
|---|---|---|---|
| G1 | `button` | — 40×46 `r9999px` | chat 1 |
| G2 | `generic` | `arrow_back` 24×24 · `24px` `rgb(70, 69, 85)` | chat 2 |
| G3 | `heading:1` | *(the group's name)* `22px` · `w500` · `rgb(53, 37, 205)` | chat 4 |
| G4 | `generic` | `lock` 14×14 · `14px` `rgb(53, 37, 205)` | chat 5 |
| G5 | `generic` | `End-to-end encrypted` `12px` · `w500` · `rgb(53, 37, 205)` | chat 6 — verbatim, unchanged |
| G6 | `textbox:multiline` | placeholder: `Secure message...` | chat 28 — verbatim |
| ~~G7~~ | ~~`button`~~ | **NOT BUILT — `GAP-047` resolved as option (c), human, 2026-09-25: no send button on any screen; the composer submits from the keyboard's own send key, exactly as the shipped 1:1 composer does** | — |
| G8 | `generic` | `dns` 24×24 · `24px` `rgb(0, 70, 102)` | conversations 22 |

**Two parent elements are deliberately not carried over:**

- **chat 3, the 38×38 peer avatar** — a per-person image, and a group has no
  single person. `conversations.md`'s `Groups` section faced the identical
  problem and resolved it with the `dns` glyph at `24px` `rgb(0, 70, 102)`
  (element 22). That glyph is **G8** above: reused, not invented, and now in
  the table rather than only in prose. **Role adapted, and that is a
  stretch worth naming:** in `conversations.md` the glyph sits in a *list
  row*; here it sits in a *thread header*. The glyph, size and colour are
  measured; the placement is derived. Disclosed rather than presented as a
  clean reuse.
- **chat 7-8, the `more_vert` overflow button** — the 1:1 thread's overflow
  menu. A group thread's overflow actions are membership management, which is
  `group-manage.md`'s scope and is explicitly out of this contract (§
  Derivation boundary). Rendering an overflow button with nothing behind it
  would be the inert-affordance mistake `E07-B01` already cost this project,
  so it is omitted until `group-manage.md` is built.

### 2. `bubble-incoming-attributed`
GAP-020's approved rule, verbatim: *"in a group thread, an incoming bubble
carries a sender attribution line in element 26's treatment; outgoing bubbles
do not (the design never labels the user to themselves)."*

| id | role | copy / label | source |
|---|---|---|---|
| G9 | `generic` | *(sender name)* `14px` · `w500` · `rgb(11, 28, 48)` | conversations 26 (`David Chen:`) — the one place the design acknowledges a group message has an author |

The bubble body itself is `chat.md`'s measured inbound box (270-272×48, chat
12/15/20), unchanged. Outgoing bubbles carry **no** G9.

### 3. `bubble-blocked-placeholder`
The human's 2026-09-25 `OQ-E07-13` answer.

| id | role | copy / label | source |
|---|---|---|---|
| G10 | `generic` | `Message hidden — contact is blocked` — **✅ GAP-045 option (b), human-approved 2026-09-25** | the inbound bubble box, chat 12/15/20, unchanged |

Rules, all three from the human's answer:
- the message **is** represented — never silently dropped from the thread;
- its body is **not** rendered readable;
- it keeps G9's sender attribution, because hiding *who* it was from would be
  a second, undecided product behaviour.

**✅ `GAP-045` answered by the human, 2026-09-25: option (b),
`Message hidden — contact is blocked`**, with the instruction *"Do not
describe it as undecryptable, failed to load, or otherwise imply a
cryptographic/decryption failure."*

That instruction is the whole point of the string, and it is why the three
rejected readings are recorded here rather than forgotten:

- `(unable to decrypt this message)` — the existing primitive
  (`chat_view.dart:355`). **False here**: a blocked member still holds a
  valid sender key, so the message decrypts. It is withheld by **policy**.
- an **empty** bubble body — the measured inbound bubble is a filled
  surface, so a name and a timestamp over nothing reads as *a message that
  failed to load*. Also a decryption-failure implication, just an implicit
  one.
- **dropping** the message — explicitly forbidden by the human's
  `OQ-E07-13` answer.

Option (b) says *hidden*, names *blocked* as the reason, and makes no claim
about cryptography. The word "hidden" is load-bearing.

### 4. `event-line`
GAP-020's approved rule, verbatim: *"Membership changes render as centred,
surface-less event lines — 'Ahmed added David', 'Group renamed to Work' — one
per `group_events` row."*

| id | role | copy / label | source |
|---|---|---|---|
| G11 | `generic` | *(event sentence)* `12px` · `w500` · `rgb(70, 69, 85)`, centred, **no bubble surface** | chat 18 — measured, exactly |

> **Reconciliation, recorded rather than concealed (human decision,
> 2026-09-25).** `GAP-020`'s approved prose described the event line as
> *"`chat.md`'s own secondary-text treatment (14px `rgb(70, 69, 85)`)"*.
> That description was **wrong about its own source**: in `chat.md`'s
> measured table `rgb(70, 69, 85)` appears only at `12px` `w500` (elements
> 11, 13, 18, 19, 21, 24). `14px` appears once, at `rgb(11, 28, 48)`
> (element 15). The pair GAP-020 named exists nowhere.
>
> The human resolved it on 2026-09-25: *"Match the existing measured
> contract: **12px, w500** rather than the contradictory approved 14px
> wording. Record the reconciliation honestly; do not alter measurements to
> conceal it."*
>
> So G11 is `12px` `w500`, and **`GAP-020`'s text is left byte-unchanged** in
> `design/gaps.md` — it records what a human approved on 2026-08-31, and
> editing it to agree with today would destroy that record. The
> contradiction lives here, with both readings and the date that settled it.

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
| encryption notice | `12px` `w500` `rgb(53, 37, 205)` | chat 6 (element 5 is the `lock` glyph at `14px`, cited separately as G4) |
| group glyph | `dns` `24px` `rgb(0, 70, 102)` | conversations 22 |
| sender attribution | `14px` `w500` `rgb(11, 28, 48)` | conversations 26 |
| bubble box | 270-272×48 | chat 12/15/20 |
| outgoing bubble fill | `rgb(53, 37, 205)` | chat 30 |
| secondary text / event line | `12px` `w500` `rgb(70, 69, 85)` | chat 18 |
| timestamp | `12px` `w500` `rgb(70, 69, 85)` | chat 11/13 |
| composer send | 48×48 `r9999px` bg `rgb(53, 37, 205)` | chat 30 |

**No new colour, size, radius, font or glyph enters the app through this
contract, and as of the 2026-09-25 reconciliation no new token *pairing*
either** — G11 now uses `chat.md` element 18's measured `12px` `w500`
`rgb(70, 69, 85)` exactly. The one remaining derivation is **placement**, not
value: G8's `dns` glyph is measured in a `conversations.md` list row and is
used here in a thread header.
