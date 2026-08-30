---
id: chat-attachment
impl_path: /chat/[id]
source: derived
derived_from: chat
states: [picker, transfer-in-progress, transfer-complete, transfer-failed]
viewports: [390x844]
golden: none yet — extract from the build once approved and implemented
spec: [FR-COMM-001, FR-UI-001]
gap: GAP-015
---
# chat-attachment · derived design contract

> **`source: derived` — hand-written, not generated.** Unlike voice and
> location, this journey has a real primitive to derive from: `chat.md`
> **already draws the in-progress transfer bubble** — `troubleshoot` /
> `Backup: Family Photos` / `In progress... 78%` (chat elements 16-18). That
> card is the design's own attachment treatment, drawn but unwired. This
> contract keeps it exactly as measured and adds only the states around it:
> where a transfer is started from, and what the card looks like when it
> finishes or fails.
>
> **Not yet law.** 🟡 proposed, gated by 🧍 `design_contract_approval` on
> `design/gaps.md` (GAP-015).

- **Route:** `/chat/[id]`
- **Parent contract:** `design/screens/chat.md`

## Derivation boundary — what is NOT derived
1. **The picker container.** The design draws the `add` button (chat 26-27)
   and no destination — no bottom sheet, no menu, no dialog exists anywhere in
   `design/screens/`. The picker's *contents* below are derived from measured
   tokens; its **container form** (bottom sheet vs anchored menu) is a product
   choice put to the human in GAP-015.
2. **The picker's source glyphs** (photo / camera / file). No contract draws
   them. Marked **[glyph — pending human confirmation]**, exactly as in
   `chat-voice.md`.
3. **Not decided here:** file size limits, chunking, MIME allow-lists,
   retention, or where the bytes live. Storage is E08's; transport chunking is
   an engineering decision for the task sharded from this contract.

## States

### 1. `picker` — entered from `add` (chat 26-27)
A short list of sources. Three rows, one per source, in the card treatment the
transfer bubble already uses.

| # | role | copy / label | size | key styles (cited from `chat.md`) |
|---|---|---|---|---|
| A1 | `generic` | (picker container) | — | `bg rgb(255, 255, 255)` · `r12px` · border `rgba(199, 196, 216, 0.2)` · the one shadow token this screen measures (see the token table below) — all four are chat's own card tokens |
| A2 | `generic` | `image` **[glyph — pending human confirmation]** | 24×24 | `24px` · `rgb(53, 37, 205)` — the `add` button's own icon treatment (chat 27) |
| A3 | `generic` | `Photo or video` | — | `12px` · `w500` · `rgb(11, 28, 48)` |
| A4 | `generic` | `photo_camera` **[glyph — pending confirmation]** | 24×24 | as A2 |
| A5 | `generic` | `Camera` | — | as A3 |
| A6 | `generic` | `attach_file` **[glyph — pending confirmation]** | 24×24 | as A2 |
| A7 | `generic` | `File` | — | as A3 |

Location sharing is *also* reached from `add` — see `design/screens/chat-location.md`
(GAP-016). The two contracts share this one picker; the location row is
specified there, not duplicated here.

### 2. `transfer-in-progress` — **measured, not derived**
This is `chat.md` elements 16-18 verbatim. It is reproduced here for the
implementing agent's convenience and is **not** a new specification — if this
table and `chat.md` ever disagree, `chat.md` wins and this file is wrong.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| A8 | `generic` | `troubleshoot` | 24×24 | `24px` · `rgb(0, 101, 145)` |
| A9 | `generic` | (file name, e.g. `Backup: Family Photos`) | 220×16 | `12px` · `w700` · `rgb(11, 28, 48)` |
| A10 | `generic` | `In progress... 78%` | 220×16 | `12px` · `w500` · `rgb(70, 69, 85)` |
| A11 | `generic` | `10:48 AM` | 62×16 | `12px` · `w500` · `rgb(70, 69, 85)` |

The `78%` is data. The string shape `In progress... %d%%` — three dots, one
space, no space before the percent — is the contract, character for character,
because the gate compares copy exactly.

### 3. `transfer-complete` — derived
Same card, same three rows, two substitutions. Nothing moves.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| A12 | `generic` | `check_circle` | 24×24 | `24px` · `rgb(0, 101, 145)` — glyph borrowed from `design/screens/dashboard.md` (element 23), tinted with **this card's own** measured colour rather than the dashboard's, so no new value enters chat |
| A13 | `generic` | (file name) | 220×16 | unchanged from A9 |
| A14 | `generic` | (size, e.g. `12.4 MB`) | 220×16 | `12px` · `w500` · `rgb(70, 69, 85)` — the subtitle slot A10 vacates |

### 4. `transfer-failed` — derived
Same card again. Uses the failure treatment **GAP-009 already settled for this
screen** — `error_outline` at the muted `rgb(70, 69, 85)`, distinguished by
icon shape rather than by a new error colour. This contract does not re-open
that decision; it inherits it.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| A15 | `generic` | `error_outline` | 24×24 | `24px` · `rgb(70, 69, 85)` — per GAP-009's approved mapping |
| A16 | `generic` | (file name) | 220×16 | unchanged from A9 |
| A17 | `generic` | `Transfer failed` | 220×16 | `12px` · `w500` · `rgb(70, 69, 85)` |

The failed card **stays in the thread**. Rule from GAP-009, restated because it
is the one people break: a message is never silently dropped from the list.

## Copy — verbatim
Introduced by this contract:

- `Photo or video`
- `Camera`
- `File`
- `Transfer failed`
- `image` · `photo_camera` · `attach_file` *[glyphs — pending confirmation]*

Reused unchanged from `chat.md`: `add`, `troubleshoot`, `In progress... 78%`.
Reused from `design/screens/dashboard.md`: `check_circle` (element 23).
`error_outline` is drawn in **no** design source — it enters via GAP-009's
already-approved failure mapping for this screen, not via this contract.

## Tokens — all cited by name from `chat.md`'s measured table
| role | value | used here for |
|---|---|---|
| text colour | `rgb(70, 69, 85)` | subtitles, the failure glyph and its label |
| text colour | `rgb(53, 37, 205)` | picker source glyphs |
| text colour | `rgb(11, 28, 48)` | file names, picker row labels |
| text colour | `rgb(0, 101, 145)` | the transfer glyph, in-progress and complete |
| surface / fill | `rgb(255, 255, 255)` | the picker container |
| border | `rgba(199, 196, 216, 0.2)` | the picker container edge |
| font size | `12px` | every label on the card and in the picker |
| font size | `24px` | every icon |
| font weight | `700` | file name |
| font weight | `500` | subtitles and picker labels |
| radius | `12px` | the picker container — the screen's own card radius (`chat.md` measures `12px` ×4) |
| font family | `Material Symbols Outlined` | icons |
| font family | `Inter` | labels |
| shadow | `rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.05) 0px 1px 2px 0px` | the picker container |

## Notes for the implementing agent
- The in-progress card is **already in the design**. Do not restyle it, do not
  "improve" it, and do not regenerate `chat.md` to add it — it is there.
- Three states, one card. If completed and failed end up looking structurally
  different from in-progress, the derivation has drifted into design.
- Progress is a percentage in text, not a bar. The design draws no bar.
