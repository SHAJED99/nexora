---
id: settings-shell
impl_path: n/a — a shared frame, not a route
source: derived
derived_from: [settings, settings-storage, chat]
states: [default]
viewports: [390x844]
golden: none — a shell has no screen of its own to extract
spec: [FR-UI-006, FR-UI-007, FR-UI-008]
gap: GAP-031
---
# settings-shell · derived design contract (a **shell**, not a screen)

> **`source: derived` — hand-written, not generated.** This file has no route,
> no golden and no `make design-verify` run of its own. It exists so that the
> eight Settings destinations `FR-UI-006` requires do not each derive their own
> frame from the same parent and arrive at eight slightly different ones — each
> internally consistent, each passing its own gate, and collectively not one
> design. That is `design-fidelity`'s opening failure, moved up a level.
>
> **Built against `GAP-031`, 🟡 proposed and NOT approved.** Its
> `approved by:` line in `design/gaps.md` is deliberately bare
> (`L-process-002`). This is the *proposal* the human reads at the
> 🧍 `design_contract_approval` gate. Written by the E15 planning pass,
> 2026-09-08.
>
> **Nothing here is new.** Every value below is measured in
> `design/screens/settings.md` or already derived and human-approved in
> `design/screens/settings-storage.md` (GAP-024, ✅ 2026-09-02). If a value
> appears here and in neither of those, it is a defect in this file.

## What a sub-screen contract inherits from this file

Each of the eight sub-screen contracts declares
`derived_from: [settings-shell, …]` and describes **only its own content**.
It does not restate the frame, and it may not change it. A sub-screen that
needs a frame element this file does not have raises it as a new gap rather
than adding one locally.

## The frame — every sub-screen has exactly these, in this order

| id | role | copy / label | source of every value |
|---|---|---|---|
| SH1 | `button` | — (back affordance, 40×40, `r9999px`) | `settings.md` elements 1/4 (header icon-button geometry) |
| SH2 | `generic` | `arrow_back` | glyph from `chat.md` element 2 — the same cross-screen navigation borrow `group-manage.md` GM2 and `settings-storage.md` §6 already make; colour `rgb(195, 192, 255)` at `24px` from `settings.md` elements 2/5 |
| SH3 | `heading:2` | _(the sub-screen's own title — each contract fixes its own string)_ | `settings.md` element 6's geometry (`28px` `w600`), **colour `rgb(248, 249, 255)`** |
| SH4 | `generic` | _(the sub-screen's own one-line subtitle)_ | `settings.md` element 7 — `14px` `rgb(199, 196, 216)` |

**SH3's colour is deliberately not `settings.md`'s measured `rgb(234, 241, 255)`.**
That value does not appear in `settings.md`'s own measured token table, so a
derived contract using it would carry a value the token check cannot find in
any source table. `rgb(248, 249, 255)` is in that table (8 uses) and is the
colour of every `heading:3` on the parent. This is the identical decision
`settings-storage.md` §Derivation boundary 3 already made and the human
already approved — restated here so the eight screens inherit it once.

## The card and row vocabulary

| id | role | what it is | source |
|---|---|---|---|
| SH5 | `generic` | **section card** — surface `rgb(26, 44, 66)`, `r12px`, `rgba(199, 196, 216, 0.1)` hairline | `settings.md` (card surface, radius, border) |
| SH6 | `heading:3` | **section heading** — `22px` `w500` `rgb(248, 249, 255)` | `settings.md` elements 10/15/20/25/30 |
| SH7 | `generic` | **body / secondary line** — `14px` `rgb(199, 196, 216)` | `settings.md` elements 11/16/21/26/31 |
| SH8 | `generic` | **row leading glyph** — `24px`; colour is the row's own, drawn only from `settings.md`'s measured set (`rgb(195, 192, 255)`, `rgb(220, 233, 255)`, `rgb(137, 206, 255)`, `rgb(103, 244, 183)`) | `settings.md` elements 9/14/19/24/29/34/39/44 |
| SH9 | `generic` | **tertiary / inactive glyph** — `24px` `rgb(119, 117, 135)` | `settings.md` elements 12/17/22/27/32 |
| SH10 | `generic` | **state label** — `12px` `w500`; says what a row currently *is* | `devices.md` elements 14/22/30/38, via `settings-storage.md`'s already-approved borrow |
| SH11 | `generic` | **machine value** — `JetBrains Mono`, `14px` | `settings.md`'s measured font family (4 uses) |
| SH12 | `generic` | **selection state glyph** — `radio_button_checked` / `radio_button_unchecked`, `24px` | `devices.md` element 21 / `dashboard.md` element 33, via `settings-storage.md` SS14-16 |
| SH13 | `generic` | **empty / error line** — one centred line at `14px` `rgb(199, 196, 216)` | GAP-002's approved treatment, via `settings-storage.md` SS27/SS28 |

## What this shell deliberately does NOT contain

1. **No switch/toggle primitive.** This design measures none, anywhere. An
   on/off state is SH12, not an invented switch. Checked across all seven
   measured contracts before writing this line.
2. **No dialog, no bottom sheet, no modal.** `GAP-025` established that this
   design draws none and that inventing one invents a visual language;
   `GAP-029` re-confirmed it and derived a full screen instead. Any
   sub-screen needing a confirmation gets a screen (see `sign-out-confirm.md`).
3. **No spinner and no skeleton.** No parent draws either.
   `settings-storage.md` §States 2 set this precedent: a loading sub-screen
   renders the frame with its content lines unpopulated.
4. **No error colour.** `settings.md` measures no red. `devices.md`'s
   `rgb(186, 26, 26)` carries destructive/blocked semantics that a failed read
   does not have. Errors use SH13 at the muted body colour, which is GAP-009's
   already-approved treatment for exactly this.
5. **No new glyph.** Every glyph a sub-screen uses is already measured in
   `settings.md`, `devices.md`, `dashboard.md`, `chat.md` or
   `settings-storage.md`. A sub-screen that needs one that is not raises it as
   a fork in `design/gaps.md`, flagged `[glyph — pending human confirmation]`.
6. **No bottom navigation bar.** `settings.md` elements 48-59 draw it because
   `/settings` is a top-level tab destination. A sub-screen is pushed on top of
   that tab, not a peer of it, and no parent draws a nav bar on a pushed
   screen. Stated explicitly because the temptation to copy the parent's
   footer wholesale is obvious and would be wrong.

## States — the same three for every sub-screen

- **`default`** — the frame plus the screen's own content.
- **`loading`** — the frame renders immediately; content lines are unpopulated
  (see §5 above). The frame never waits on a read.
- **`empty` / `error`** — one SH13 line in place of the affected section only.
  **A failed read of one section never clears another**, and never clears a
  setting the user themselves chose — the same rule `settings-storage.md`
  §States 4 states for its mode selector.

## Notes for the implementing agent
- Build this as **one shared widget** the eight screens compose, not as a
  pattern eight screens re-type. `E15-T03` owns that widget; the eight screen
  tasks consume it and may not fork it.
- Back navigation is the platform's ordinary pop (`FR-UI-008`). SH1 and the
  system back gesture do the same thing; neither is suppressed.
