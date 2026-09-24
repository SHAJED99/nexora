---
id: chat-group
impl_path: /groups/[id]
source: derived
derived_from: [chat, conversations]
states: [thread, bubble-incoming-attributed, event-line, empty]
blocked_states:
  # State 3 is specified below but NOT buildable: its copy is GAP-045,
  # unapproved. Listed here rather than in `states[]` so the frontmatter does
  # not declare a state this same contract says does not exist.
  - name: bubble-blocked-placeholder
    blocked_by: GAP-045
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

**No copy is invented in this contract.** The human decided on 2026-09-25 that
a blocked member's messages are *"represented as placeholders rather than
being silently dropped or rendered as normal readable messages"* — that is a
**behaviour**, and behaviour is not words. Rule 2 requires a derived element
to be human-approved before it is built, so state 3 renders an **empty bubble
body** rather than a sentence nobody approved. That satisfies all three of the
human's rules using only the measured bubble box.

Candidate words are carried in **`GAP-045`**, unapproved, with three options.
**State 3 is gated on it** — an empty bubble body reads as a failed message,
not as a blocked one, so there is no honest interim (see state 3). The other
four states, and the entire create → open → send → read journey, are not
gated on it.

One **pairing** of existing tokens is new — G11's `14px` + `rgb(70, 69, 85)`
— and it is new because GAP-020's own human-approved text specifies it. See
the disclosure under state 4; it is disclosed rather than quietly normalised.

Also explicitly out of this contract: attachments, voice, PTT and location
inside a group thread (their own contracts, each with its own gap), group
calls, the `more_vert` overflow menu, and any membership-management
affordance (`group-manage.md`).

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
| G7 | `button` | — 48×48 · bg `rgb(53, 37, 205)` · `r9999px` | chat 30 |
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
| G10 | `generic` | *(copy undecided — `GAP-045`, three candidates, one human answer)* | the inbound bubble box, chat 12/15/20, unchanged |

Rules, all three from the human's answer:
- the message **is** represented — never silently dropped from the thread;
- its body is **not** rendered readable;
- it keeps G9's sender attribution, because hiding *who* it was from would be
  a second, undecided product behaviour.

**No copy is invented here, and that is deliberate.** The human decided the
*behaviour*; nothing in the design or in the answer supplies *words*, and
rule 2 requires a derived element to be human-approved before it is built.

**But an empty body is not a placeholder, and this contract will not pretend
otherwise.** The measured inbound bubble is a filled, rounded surface
(`chat.md` 12/20/23). Rendered with a name, a timestamp and nothing inside,
it reads as *a message that failed to load* — which is a different claim
about the app than "this sender is blocked", and arguably a worse one than
the `(unable to decrypt this message)` string this contract already rejects
as false.

So **state 3 is blocked on `GAP-045`**, and says so rather than shipping an
ambiguous surface. `GAP-045` names three candidate strings and needs one
human answer.

### What the app does in the meantime — the interim behaviour, stated

"Not built" is not a runtime behaviour, so this contract names one.

A group thread that rendered states 1, 2, 4 and 5 but had no state 3 would
show a blocked member's message **as an ordinary readable bubble** — exactly
the outcome the human's 2026-09-25 answer forbids. Shipping the other four
states is therefore not a partial win; it is a regression against a decision
already taken.

**So the whole thread build (`E07-T18`) is gated on `GAP-045`, not just state
3.** Until then the app keeps the behaviour it already ships: a group row tap
is non-navigating and acknowledges itself honestly
(`ConversationsController.openGroup`, `E07-B01`'s human-chosen fix direction
(a), merged 2026-09-02). That is a real, deliberate, already-reviewed
behaviour — not a gap — and it stays until one string is chosen.

**Why the existing placeholder is not reused:** `chat_view.dart:355` renders
`(unable to decrypt this message)` for a null plaintext. Here that would be
**false** — a blocked member still holds a valid sender key, so the message
decrypts; it is withheld by policy, not by failure.

### 4. `event-line`
GAP-020's approved rule, verbatim: *"Membership changes render as centred,
surface-less event lines — 'Ahmed added David', 'Group renamed to Work' — one
per `group_events` row."*

| id | role | copy / label | source |
|---|---|---|---|
| G11 | `generic` | *(event sentence)* `14px` · `rgb(70, 69, 85)`, centred, **no bubble surface** | **GAP-020, human-approved 2026-08-31**, verbatim |

> **Disclosure (rule 2, and it matters).** GAP-020 describes this pairing as
> *"`chat.md`'s own secondary-text treatment (14px `rgb(70, 69, 85)`)"*. In
> `chat.md`'s measured table that colour appears **only at 12px** (elements
> 11, 13, 18, 19, 21, 24); 14px appears at `rgb(11, 28, 48)` (element 15).
> **The exact pair `14px` + `rgb(70, 69, 85)` is not measured anywhere.** It
> is written here because the human approved GAP-020 with those words in it,
> not because the parent table contains it — and saying so is the point.
> **The weight differs too, and GAP-020 does not mention it:** every measured
> use of `rgb(70, 69, 85)` in `chat.md` is `w500` (elements 11, 13, 18, 19,
> 21, 24). G11 states no weight, so it renders at the `w400` default. Neither
> `14px` nor `w400` is measured with this colour anywhere.
> Raised as an open item in `E07-T17` §5b rather than silently normalised
> to 12px, which would contradict an approved gap.

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
| secondary text | `12px` `w500` `rgb(70, 69, 85)` | chat 18 |
| timestamp | `12px` `w500` `rgb(70, 69, 85)` | chat 11/13 |
| composer send | 48×48 `r9999px` bg `rgb(53, 37, 205)` | chat 30 |

**No new colour, size, radius, font or glyph enters the app through this
contract.** One *pairing* of two existing tokens is new — `14px` +
`rgb(70, 69, 85)` on G11 — and it is new because GAP-020's approved text
specifies it; see the disclosure under state 4. No blanket “nothing is new”
claim is made here, because that claim would be false.
