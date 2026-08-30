---
id: chat-location
impl_path: /chat/[id]
source: derived
derived_from: chat
states: [picker-row, bubble-sent, bubble-received, bubble-stale, bubble-unavailable]
viewports: [390x844]
golden: none yet — extract from the build once approved and implemented
spec: [FR-COMM-001, FR-UI-001, FR-LOC-005]
gap: GAP-016
---
# chat-location · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> no location affordance and no location bubble. This contract covers exactly
> two things: **how a location share is started from the composer's `add`
> button, and how a shared location renders inside the chat thread.** Nothing
> else.
>
> **Not yet law.** 🟡 proposed, gated by 🧍 `design_contract_approval` on
> `design/gaps.md` (GAP-016).

- **Route:** `/chat/[id]`
- **Parent contract:** `design/screens/chat.md`

## Scope fence — this contract governs rendering only
Location is already a governed capability in this product, and it is **not
governed here**:

- **FR-TRUST-006** owns the location-access control (the user setting that
  permits location at all). Its surface is `GAP-005`'s undesigned
  Privacy & Security sub-screen, not this file.
- **FR-LOC-001 / FR-LOC-002 / FR-LOC-003** own the global toggle, the
  per-user toggle, and the four-condition visibility rule. **E09
  (Location Sharing)** owns all of them.
- **FR-MSG-007** owns the conflict precedence `LOCATION-OFF > LOCATION-ON`
  (and `BLOCK > TRUST`). Nothing in this contract may weaken it — in
  particular, a *rendered* location bubble is never evidence that sharing is
  permitted; the permission check happens before the bubble exists.
- **FR-LOC-004** owns encryption and the no-permanent-history constraint.

This contract therefore assumes a location message **that the permission layer
has already allowed**, and specifies only its pixels. If building it requires a
permission decision, that decision is E09's and the correct move is to stop and
raise it — not to settle it in a UI task.

## Derivation boundary — what is NOT derived
1. **There is no map.** No contract in `design/screens/` draws a map, a map
   thumbnail, a pin on a tile, or any image other than the 38×38 avatar
   (chat element 3). A map preview would be a genuinely new design element, and
   deriving one from bubble primitives is inventing. **This contract renders a
   location as a card, not as a map** — the same icon + title + subtitle
   treatment the design's own transfer bubble uses (chat 16-18). Opening the
   location in a map is a hand-off to the platform map or to an E09 surface,
   both outside this contract. If the human wants an in-thread map preview,
   that is a new design pass, and GAP-016 says so.
2. **Glyph names** (`place`, `location_off`) are drawn nowhere; marked
   **[glyph — pending human confirmation]**.
3. Live-vs-static location, update frequency, and how long a share stays
   active are **E09's**, not this contract's.

## States

### 1. `picker-row` — the share entry point
Location is one row in the same picker `design/screens/chat-attachment.md`
specifies for the `add` button (chat 26-27). It is defined here, once, and not
duplicated there.

| # | role | copy / label | size | key styles (cited from `chat.md`) |
|---|---|---|---|---|
| L1 | `generic` | `place` **[glyph — pending confirmation]** | 24×24 | `24px` · `rgb(53, 37, 205)` — the `add` button's own icon treatment (chat 27) |
| L2 | `generic` | `Location` | — | `12px` · `w500` · `rgb(11, 28, 48)` — the picker row label treatment |

When location is not permitted (FR-LOC-003's conditions fail, or FR-MSG-007
resolves to `LOCATION-OFF`), the row is **shown and disabled**, never removed —
design-fidelity rule 3, never delete an element to satisfy the data layer. The
disabled treatment is the muted body colour `rgb(70, 69, 85)` on both L1 and
L2; no new value, no opacity token (the design measures none).

### 2. `bubble-sent` / 3. `bubble-received`
The transfer-card treatment (chat 16-18), in the bubble the thread already
uses. Same geometry, same three rows.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| L3 | `generic` | (bubble container) | 270×48 | the text-bubble box (chat 12/15/20 measure 270-272×48); outbound `bg rgb(53, 37, 205)`, inbound the light surface the built inbound text bubble already uses — no new surface token |
| L4 | `generic` | `place` **[glyph — pending confirmation]** | 24×24 | `24px` · outbound `rgb(255, 255, 255)`, inbound `rgb(0, 101, 145)` — the transfer card's own glyph colour (chat 16) on the light side |
| L5 | `generic` | `Location` | 220×16 | `12px` · `w700` · outbound `rgb(255, 255, 255)`, inbound `rgb(11, 28, 48)` — the transfer card's title treatment (chat 17) |
| L6 | `generic` | (subtitle — see below) | 220×16 | `12px` · `w500` · outbound `rgb(255, 255, 255)`, inbound `rgb(70, 69, 85)` — the transfer card's subtitle treatment (chat 18) |
| L7 | `generic` | `10:53 AM` | 62×16 | `12px` · `w500` · `rgb(70, 69, 85)` — the existing per-message timestamp, unchanged |
| L8 | `generic` | `check` / `done_all` | 16×16 | unchanged from chat 14/22/25 — same delivery-state glyph set as any other message (GAP-009) |

### 4. `bubble-stale` — required by FR-LOC-005
FR-LOC-005: *"shall never represent stale location as live"*. The subtitle slot
L6 is where that obligation is discharged, because the design gives this card
exactly one subtitle line and it already carries a status string
(`In progress... 78%`). So:

| variant | L6 copy |
|---|---|
| live | `Shared just now` |
| stale | `Last known · 10:41 AM` |

The **stale variant is not optional and not a nicety** — a location card
without a visible timestamp violates FR-LOC-005 regardless of how it looks.

### 5. `bubble-unavailable`
A location that can no longer be resolved (the sender revoked sharing, or
FR-LOC-003's conditions stopped holding). The card stays in the thread — never
silently removed — with the failure treatment GAP-009 already approved for this
screen.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| L9 | `generic` | `location_off` **[glyph — pending confirmation]** | 24×24 | `24px` · `rgb(70, 69, 85)` — the muted treatment GAP-009 approved for failure, distinguished by icon shape rather than a new error colour |
| L10 | `generic` | `Location unavailable` | 220×16 | `12px` · `w500` · `rgb(70, 69, 85)` |

## Copy — verbatim
Introduced by this contract:

- `Location`
- `Shared just now`
- `Last known · 10:41 AM` *(format `Last known · h:mm AM`; the time is data, the
  shape is the contract — the `h:mm AM` form matches chat's existing timestamps)*
- `Location unavailable`
- `place` · `location_off` *[glyphs — pending confirmation]*

Reused unchanged from `chat.md`: `add`, `check`, `done_all`.

## Tokens — all cited by name from `chat.md`'s measured table
| role | value | used here for |
|---|---|---|
| text colour | `rgb(70, 69, 85)` | subtitles, disabled picker row, the unavailable treatment |
| text colour | `rgb(53, 37, 205)` | the picker row glyph |
| text colour | `rgb(255, 255, 255)` | outbound bubble content |
| text colour | `rgb(11, 28, 48)` | inbound title, picker row label |
| text colour | `rgb(0, 101, 145)` | the inbound location glyph (the transfer card's colour) |
| surface / fill | `rgb(53, 37, 205)` | the outbound bubble |
| font size | `12px` | every label and timestamp |
| font size | `24px` | every icon |
| font weight | `700` | the card title |
| font weight | `500` | subtitles, labels, timestamps |
| font family | `Material Symbols Outlined` | icons |
| font family | `Inter` | labels |
| font family | `JetBrains Mono` | the timestamp in the stale subtitle — the family the existing timestamps use |

## Notes for the implementing agent
- If the task you are building needs to decide *whether* a location may be
  shared, you are in E09's scope and outside this contract. Stop and raise it.
- No map. If you are reaching for a map SDK, re-read the derivation boundary.
- The stale timestamp is a requirement (FR-LOC-005), not a decoration.
