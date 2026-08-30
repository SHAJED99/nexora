---
id: chat-voice
impl_path: /chat/[id]
source: derived
derived_from: chat
states: [composer-idle, recording, recording-cancel-hint, bubble-idle, bubble-playing]
viewports: [390x844]
golden: none yet — extract from the build once approved and implemented
spec: [FR-COMM-001, FR-UI-001]
gap: GAP-014
---
# chat-voice · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> a `mic` button (chat elements 30-31) and nothing else about voice messages:
> no recording indicator, no cancel affordance, no playback bubble. This
> contract composes those three surfaces **only** from primitives
> `design/screens/chat.md` already measures.
>
> **Not yet law.** It is 🟡 proposed and gated by 🧍 `design_contract_approval`
> on `design/gaps.md` (GAP-014). Nothing is sharded or built from it until the
> human clears that gate. Once built, extract the built screen as its own
> golden — from then on it is regression-gated like every other screen.

- **Route:** `/chat/[id]` — the same screen; this contract covers the composer's
  recording mode and one additional message-bubble variant.
- **Parent contract:** `design/screens/chat.md` (all tokens below are cited by
  name from its measured table)

## Derivation boundary — what is NOT derived
One thing in this contract has no source anywhere in the design: the **glyph
names** for record-stop, play and pause. `chat.md` draws `mic`, and no contract
in `design/screens/` draws a play, pause, stop or close glyph (checked across
all seven). The *family, size and colour* of those icons ARE measured tokens
(`Material Symbols Outlined`, `24px`, `rgb(255, 255, 255)` on the accent button —
chat elements 30-31); only the glyph identity is proposed copy. Each such
string is marked **[glyph — pending human confirmation]** below and is listed in
GAP-014 for sign-off. Inventing them silently is exactly what rule 2 forbids;
proposing them with the source named is not.

Also explicitly out of this contract: audio codec, bit rate, maximum recording
length, file size, and where the audio is stored. Those are engineering and
storage decisions (several belong to E08), not design.

## The interaction question this contract does NOT settle
**Press-and-hold to record, or tap-to-toggle?** These produce different
surfaces — hold gives you a slide-to-cancel gesture and no stop button;
toggle gives you an explicit stop button and no gesture. The design draws
neither, and the choice changes what a user can do (hold is unusable for a
long message; toggle costs an extra tap for a two-second one). It is a
product decision, put to the human in GAP-014. **This contract specifies both
variants' elements** so that whichever is chosen, the visual language is
already fixed; the unchosen variant's rows are then dropped at approval.

## States

### 1. `composer-idle`
Unchanged from `chat.md` elements 26-31. The `mic` button is the entry point.

### 2. `recording`
The composer row is replaced in place — same 48×48 button rail (chat 26/30), same row
height. Nothing above the composer changes.

### 3. `recording-cancel-hint`
Only present in the **press-and-hold** variant: the state the composer enters
while the user's finger has moved past the cancel threshold.

### 4. `bubble-idle` / 5. `bubble-playing`
A voice message in the thread, in both bubble alignments (outbound on the
accent fill, inbound on the light surface), before and during playback.

## Elements — the build checklist

### State `recording`
| # | role | copy / label | size | key styles (all cited from `chat.md`) |
|---|---|---|---|---|
| V1 | `button` | — | 48×48 | `r9999px` — the composer button geometry (chat 26/30) |
| V2 | `generic` | `stop_circle` **[glyph — pending human confirmation]** | 24×24 | `24px` · `rgb(255, 255, 255)` on `bg rgb(53, 37, 205)` — the `mic` button's own treatment (chat 30-31) |
| V3 | `generic` | `circle` | 12×12 | `12px` · `rgb(53, 37, 205)` — the recording dot; `circle` is an existing glyph (dashboard element 7), tinted with chat's accent text colour |
| V4 | `generic` | `0:07` | 62×16 | `12px` · `w500` · `rgb(70, 69, 85)` — the elapsed counter reuses the message-timestamp treatment exactly (chat 11/13/19/21/24) |
| V5 | `generic` | `Recording…` | — | `12px` · `w500` · `rgb(70, 69, 85)` — the day-divider/timestamp body treatment |
| V6 | `button` | — | 40×46 | `r9999px` — the header icon-button geometry (chat 1/7), used for cancel |
| V7 | `generic` | `close` **[glyph — pending human confirmation]** | 24×24 | `24px` · `rgb(70, 69, 85)` — the `arrow_back`/`more_vert` header-icon treatment (chat 2/8) |

**Tap-to-toggle variant** uses V1-V7 as listed.
**Press-and-hold variant** drops V1/V2 (there is no stop button — release
stops) and keeps V3-V5; V6/V7 are replaced by V8/V9 below.

### State `recording-cancel-hint` (press-and-hold variant only)
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| V8 | `generic` | `arrow_back` | 24×24 | `24px` · `rgb(70, 69, 85)` — an existing chat glyph (chat 2), reused unrotated as the slide-to-cancel indicator |
| V9 | `generic` | `Slide to cancel` | — | `12px` · `w500` · `rgb(70, 69, 85)` |

### States `bubble-idle` / `bubble-playing`
The voice bubble is the **text bubble's geometry with its body text replaced**
by a three-part row. It does not introduce a card, a border or a shadow the
text bubble does not already have.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| V10 | `generic` | (bubble container) | 270×48 | the text-bubble box (chat 12/15/20 measure 270-272×48); outbound `bg rgb(53, 37, 205)`, inbound the same light surface the built inbound text bubble already uses — no new surface token |
| V11 | `generic` | `play_arrow` **[glyph — pending human confirmation]** | 24×24 | `24px` · outbound `rgb(255, 255, 255)`, inbound `rgb(11, 28, 48)` — the bubble's own text colours (chat 12/20/23 vs 10/15) |
| V12 | `generic` | `pause` **[glyph — pending human confirmation]** | 24×24 | same as V11 — replaces V11 in `bubble-playing` |
| V13 | `generic` | (progress track) | 160×2 | `r2px` — the `2px` radius the contract already measures (chat token table, radius `2px` ×2); track in the bubble's text colour at reduced opacity, fill in the bubble's text colour at full |
| V14 | `generic` | `0:07` | 62×16 | `12px` · `w500` · outbound `rgb(255, 255, 255)`, inbound `rgb(70, 69, 85)` — the timestamp treatment (chat 11/13) |
| V15 | `generic` | `10:52 AM` | 62×16 | `12px` · `w500` · `rgb(70, 69, 85)` — the existing per-message timestamp, unchanged |
| V16 | `generic` | `check` / `done_all` | 16×16 | unchanged from chat 14/22/25 — a voice message carries the same delivery-state glyph set as a text message (GAP-009) |

**Waveform or plain progress?** A waveform requires a visual primitive the
design does not draw anywhere. V13 is therefore a **plain progress track**
built from the measured `2px` radius. A waveform, if wanted, is a new design
element and belongs to the human, not to a derivation — noted in GAP-014.

## Copy — verbatim
Strings this contract introduces. Everything else on the screen is `chat.md`'s
copy, unchanged.

- `Recording…`
- `Slide to cancel` *(press-and-hold variant only)*
- `0:07` *(format `M:SS`; the value is data, the format is the contract)*
- `stop_circle` *[glyph — pending confirmation]*
- `close` *[glyph — pending confirmation]*
- `play_arrow` *[glyph — pending confirmation]*
- `pause` *[glyph — pending confirmation]*

Reused unchanged from `chat.md`: `arrow_back`, `mic`, `check`, `done_all`.
Reused from `design/screens/dashboard.md`: `circle`.

## Tokens — all cited by name from `chat.md`'s measured table
No value here is new. Every row below is grep-verifiable in
`design/screens/chat.md` §"Tokens this screen actually uses".

| role | value | used here for |
|---|---|---|
| text colour | `rgb(70, 69, 85)` | elapsed counter, `Recording…`, cancel glyph, inbound duration |
| text colour | `rgb(53, 37, 205)` | the recording dot |
| text colour | `rgb(255, 255, 255)` | glyphs on the accent button, outbound bubble content |
| text colour | `rgb(11, 28, 48)` | inbound bubble content |
| surface / fill | `rgb(53, 37, 205)` | the record button, the outbound bubble |
| font size | `12px` | counters, labels, timestamps |
| font size | `24px` | all icons |
| font weight | `500` | counters and labels |
| radius | `9999px` | the record and cancel buttons |
| radius | `2px` | the playback progress track |
| font family | `Material Symbols Outlined` | all icons |
| font family | `Inter` | `Recording…`, `Slide to cancel` |
| font family | `JetBrains Mono` | the `M:SS` duration counters — the family the existing timestamps use |

## Notes for the implementing agent
- Do **not** build this until GAP-014 is 🧍 approved and one recording
  interaction (hold or toggle) has been chosen. Building both is waste;
  guessing one is the failure this contract exists to prevent.
- The bubble is the text bubble. If you find yourself adding a border, a
  shadow or a radius the text bubble does not have, stop — that is a new
  design element and it needs the human.
- Delivery-state glyphs come from GAP-009's approved mapping, not from here.
