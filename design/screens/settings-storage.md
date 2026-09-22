---
id: settings-storage
impl_path: /settings/storage
source: derived
derived_from: [settings, devices, dashboard]
states: [default, loading, empty, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-STORE-004, FR-STORE-007]
gap: GAP-024
---
# settings-storage · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **one row** for this journey and nothing else: `settings.md` elements 29-31
> (`sd_storage` · `Storage` · `Local cache, message retention, export`). There
> is no Storage sub-screen, no mode selector, no parameter input and no
> explanation list anywhere in the seven measured contracts. This contract
> composes the screen **only** from primitives `design/screens/settings.md`,
> `design/screens/devices.md` and `design/screens/dashboard.md` already
> measure.
>
> **Built against `GAP-024`, which is 🟡 proposed and NOT approved.** Its
> `approved by:` line in `design/gaps.md` is deliberately bare
> (`L-process-002`). This contract is the *proposal* the human reads at the
> 🧍 `design_contract_approval` gate; it is **not** independently approved by
> an agent, and `E08-T09` does not build from it until the human clears it.
> Written by `E08-T07`.
>
> **No golden exists and `make design-verify SCREEN=settings-storage` cannot
> run until the build does.** A derived screen has no extractable source —
> its golden is extracted *from the build*, per `design-fidelity` §3, exactly
> as `group-create.md` and `group-manage.md` record. `E08-T09`'s reviewer
> should expect that and not read it as a missing artifact.

- **Route:** `/settings/storage`, reached by tapping `settings.md`'s Storage
  row (elements 28-32). Registering the route and wiring the row's tap is
  **`E08-T09`'s** job, not this contract's. Every other settings row keeps its
  existing behaviour untouched.
- **Parent contracts:** `design/screens/settings.md` (frame, page and card
  surfaces, row geometry, heading + body typography, icon treatment, the
  `sd_storage` glyph) · `design/screens/devices.md` (the list row with a
  trailing metadata slot and a state label — this design's only existing
  "a list of things each with a status" shape) · `design/screens/dashboard.md`
  (the `Local Storage` heading and the usage-line treatment, and the
  `radio_button_unchecked` glyph)
- **Source of truth for what the screen *says*:** `E08-T04`'s `RetentionPlan`
  (`categoryKey`, `bytes`, `reason`, per-factor availability) and `E08-T05`'s
  `StorageSettingsRepository`. This screen holds **no** second policy rule of
  its own. If a widget and the plan ever disagree, the plan wins and the
  widget is the bug.

## The prohibition this screen exists to keep

**There is no `Clean Now` button on this screen. There is no apply-now, no
confirmation dialog, no "free up space" action, and no delete affordance —
not even a disabled one.** `FR-STORE-006` says in as many words that the user
does not need to press one, and `EARS-STORE-2` makes it a criterion. Every
storage screen anyone has ever seen has such a button, which is exactly why
the prohibition is written into the *contract* and not only into the task
that wrote it: the next person to touch this screen inherits this paragraph.

Changing a mode changes what the **next** plan says. It runs nothing, applies
nothing and deletes nothing (`E08-T05` §2, `E08-T06` owns execution alone).

## Derivation boundary — what is NOT derived

1. **A settings *detail* screen has no measured precedent in this design at
   all.** `settings.md` is a **menu**: nine rows that lead somewhere, and none
   of the somewheres is drawn. Deriving the destination from `devices.md`'s
   list-of-rows-with-status is the honest reading — devices is the only screen
   in the source that shows a list of things each carrying a state label and a
   secondary metadata line, which is structurally what a mode list and a
   decision list are. **The alternative, named rather than hidden:** treat the
   Storage screen as another *menu* (mode → its own sub-screen). Rejected
   because it puts a two-tap wall in front of a three-option choice, and
   because it multiplies undesigned destinations rather than closing one. If
   the human prefers it, this is the line to say so on.
2. **Geometry comes from `devices.md`; colour comes from `settings.md`.**
   `devices.md` is a light surface (`rgb(11, 28, 48)` **text**) and
   `settings.md` is a dark one (`rgb(11, 28, 48)` **page fill**). Carrying
   devices' row *colours* onto a settings child would put near-black text on a
   near-black page. Only the row's **shape** — leading glyph, title, secondary
   line, trailing slot, state label — is borrowed; every colour below is a
   `settings.md` value.
3. **One measured value is deliberately not copied.** `settings.md` element 6
   measures the screen title as `28px` `w600` `rgb(234, 241, 255)`, but
   `rgb(234, 241, 255)` does **not** appear in settings' own measured token
   table. Using it would put a value in a derived contract that
   `DOC-STORE-17`'s check cannot find in a source table. SS3 below uses
   `rgb(248, 249, 255)` — which is in that table (8 uses) and is the colour of
   every `heading:3` on the parent screen. Same reasoning `group-manage.md`
   §Derivation boundary 2 applied to devices' `r4px`.
4. **No text-input primitive exists in any parent.** None of the three parent
   contracts draws a textbox. The parameter field (SS17) is therefore
   **not** derived from an input; they are the parent's own **card surface**
   (`rgb(33, 49, 69)`, `r12px`) carrying a `JetBrains Mono` numeral in the
   parent's own `14px` body size — every value from settings' table. The named
   alternative is `conversations.md`'s measured search field (`14px`, fill
   `rgb(229, 238, 255)`, `r8px`), which `group-manage.md` GM3 borrowed for the
   same reason; it is rejected here only because its light fill belongs to a
   light screen. Recorded so the difference from GM3 reads as a decision, not
   drift.
5. **No error colour is invented.** `settings.md` measures no red;
   `devices.md`'s `rgb(186, 26, 26)` carries *destructive/blocked* semantics
   that a validation message does not have. The validation state uses
   `error_outline` at a muted parent colour — GAP-009's already-approved
   precedent for exactly this problem, reused rather than re-opened.
6. **No new glyph.** Every glyph below already exists in a measured contract:
   `sd_storage` (settings 29), `radio_button_checked` (devices 21),
   `radio_button_unchecked` (dashboard 33), `warning` (dashboard 17),
   `error_outline` (GAP-009, approved 2026-08-29), and `arrow_back`
   (`chat.md` element 2 — the same cross-screen navigation borrow
   `group-manage.md` GM2 makes). Nothing is flagged
   `[glyph — pending human confirmation]`.
7. **No export control.** `settings.md` element 31's subtitle promises
   `Local cache, message retention, export`, and **no `FR-STORE-*` id
   requires an export**. Building one from a subtitle would be inventing scope
   from copy. It is recorded as `GAP-027` — a fork with no proposal — and this
   screen simply has no export element. See §Open.

Out of this contract entirely: the eight-factor scoring itself (`E08-T04`),
the executor and its allow-list (`E08-T06`), the dashboard card and its
expanded state (`GAP-025`, `design/screens/dashboard.md` §Derived state), and
anything about *what* is stored (`FR-STORE-002`/`003`, unowned — `OQ-E08-5`).

## Surface story — which parent supplies what

`settings.md` supplies the **frame and the palette**: the header icon-button
(40×40 `r9999px`, glyph `24px` `rgb(195, 192, 255)` — elements 1/2, 4/5), the
screen title/subtitle pair (6/7), the card surface `rgb(26, 44, 66)` with
`r12px` and the `rgba(199, 196, 216, 0.1)` hairline, the `heading:3` treatment
(`22px` `w500` `rgb(248, 249, 255)` — 10/15/20/25/30), the body line (`14px`
`rgb(199, 196, 216)` — 11/16/21/26/31), the tertiary/inactive glyph colour
`rgb(119, 117, 135)` (12/17/22/27/32), and the `sd_storage` glyph (29).

`devices.md` supplies the **list vocabulary**: the row with a leading glyph, a
title, a secondary line and a trailing slot (elements 8-15), and the
`12px` `w500` **state-label** treatment (14/22/30/38) that a row uses to say
what it currently is.

`dashboard.md` supplies the **storage vocabulary**: the `Local Storage`
heading (element 15) and the usage-line treatment (element 16), plus the
`radio_button_unchecked` glyph (element 33) and `warning` (element 17).

## States

### 1. `default`
The frame, the usage summary with its real measured figures, the three-mode
selector with the active mode marked, the active mode's parameter field (only
when the active mode has one), and the explanation list for the latest plan.

### 2. `loading`
The frame with the usage summary and the explanation list unpopulated. **No
spinner and no skeleton** — none of the three parents draws either, so none is
invented (`group-manage.md` §6 set this precedent). The mode selector still
renders and is still usable; reading a settings row does not wait on an
inventory pass.

### 3. `empty` — a required state, not an edge case
**The latest plan has no candidate groups: nothing is scheduled for removal.**
This is the *expected* reading on a default install, not a rare one — see
§"What the default screen must not imply" below. The explanation list is
replaced by one centred line (SS27) in GAP-002's already-approved treatment.
The usage summary and the mode selector are unchanged.

A closely related sub-case, rendered identically: **no plan has run yet**
(first launch, before the first pass). The screen says the same thing, because
"nothing is scheduled" is true in both.

### 4. `error`
One centred line in the explanation-list area (SS28), GAP-002's treatment
again. The usage summary and the mode selector are **not** cleared — a failed
inventory read must not make the user's own chosen mode disappear.

## What the default screen must not imply — `OQ-E08-3`

The human answered `OQ-E08-3` on **2026-09-02** with option **(a)**: Smart
Mode's allow-list **excludes conversation content entirely**; message content
is removed **only** under a manual policy the user explicitly turns on.

Smart Mode is the default (`FR-STORE-004`), so on a default install **nothing
this screen describes will delete a message**. Two consequences are binding on
the copy below:

- **SS12 exists.** The Smart Mode row carries a plain consequence line saying
  conversation content is not removed. Leaving it out would let a user read
  the eight-factor language as a threat to their history, which the human's
  answer says it is not.
- **SS13 exists, and only on the two manual rows.** A mode that *can* remove
  conversation content says so before it is chosen, not after.
- **Nothing on this screen is phrased as imminent.** The BRD's own tense is
  future — `Will remove:` (§20, §22) — and the `empty` state's copy says
  plainly that there is nothing scheduled. No countdown, no "X days left", no
  badge, no urgency colour.

## Elements — the build checklist

Every row cites the parent element its styling comes from. A value that
appears here and in no parent's measured token table is a defect
(`DOC-STORE-17`).

### Frame
| # | role | copy / label | size | key styles (cited from the parent contracts) |
|---|---|---|---|---|
| SS1 | `button` | — | 40×40 | `r9999px` — the settings header icon-button (settings 1/4) |
| SS2 | `generic` | `arrow_back` | 24×24 | `24px` · `rgb(195, 192, 255)` — the settings header glyph treatment (settings 2/5); glyph borrowed from `chat.md` element 2, per §Derivation boundary 6 |
| SS3 | `heading:2` | `Storage` | 358×36 | `28px` · `w600` · `rgb(248, 249, 255)` — the settings screen title (settings 6) with the colour substitution of §Derivation boundary 3. Copy is `settings.md` element 30's own heading, unchanged |
| SS4 | `generic` | `Choose how NEXORA manages local storage.` | 358×40 | `14px` · `rgb(199, 196, 216)` — the settings screen subtitle (settings 7) |

### Usage summary (`FR-STORE-007` context, `GAP-026`)
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| SS5 | `generic` | `sd_storage` | 24×24 | `24px` · `rgb(195, 192, 255)` — the settings Storage row glyph (settings 29), unchanged |
| SS6 | `heading:3` | `Local Storage` | 236×28 | `22px` · `w500` · `rgb(248, 249, 255)` — the settings `heading:3` (settings 10/15/20/25/30). Copy reused verbatim from `dashboard.md` element 15 — no new string |
| SS7 | `generic` | (the measured total — format `N MB used`) | 236×20 | `14px` · `rgb(199, 196, 216)` — the settings body line (settings 11), carrying `dashboard.md` element 16's `… used` suffix. **`JetBrains Mono` for the numeral** (settings' own family table). **Real measured bytes, never a percentage** — see below |
| SS8 | `generic` | (per-class label — see §Copy for the format set) | — | `14px` · `w500` · `rgb(248, 249, 255)` — the devices row title *shape* (devices 9/17/25/33) in the settings palette, per §Derivation boundary 2 |
| SS9 | `generic` | (that class's measured bytes) | — | `12px` · `w500` · `rgb(199, 196, 216)` · `JetBrains Mono` — the devices state-label treatment (devices 14/22/30/38) in the settings palette |

**SS7 renders bytes, not `45% used`.** The human answered `OQ-E08-1` on
2026-09-02 with **(a) + (c)**: device free space via Pigeon feeds Smart Mode's
*pressure factor*, and **the user-facing figure is the real measured byte
total — no fabricated percentage**. `storage_policy_settings.budget_bytes`
stays NULL until a budget is chosen, so no denominator exists to divide by.
This is `GAP-026`'s disclosed deviation from the measured `45% used` string,
recorded there, not decided here.

**A class that could not be measured renders as unmeasured, never as `0`**
(`E08-T02` §2). Its SS9 slot carries the unmeasured wording from §Copy.

### Mode selector — `FR-STORE-004`
Three rows, in `FR-STORE-004`'s own order. Exactly one is selected. Selecting
a row writes the mode and nothing else.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| SS10 | `button` | — | 356×~104 | the settings row card — fill `rgb(26, 44, 66)` · `r12px` · border `rgba(199, 196, 216, 0.1)` (settings 8/13/18/23/28) |
| SS11 | `heading:3` | `Smart Mode` \| `Delete data older than X days` \| `Delete old data when storage exceeds X MB` | 236×28 | `22px` · `w500` · `rgb(248, 249, 255)` — settings `heading:3`. Copy is BRD §19's mode list verbatim; `Smart Mode` also matches `dashboard.md` element 18's existing string |
| SS12 | `generic` | `Smart Mode doesn't remove conversation content.` | 236×40 | `14px` · `rgb(199, 196, 216)` — settings body line (settings 11). **Smart Mode row only.** Required by `OQ-E08-3`'s answer — see §"What the default screen must not imply" |
| SS13 | `generic` | `This mode can remove conversation content.` | 236×40 | as SS12. **The two manual rows only** |
| SS14 | `generic` | `radio_button_checked` | 24×24 | `24px` · `rgb(195, 192, 255)` — the settings active-icon colour (settings 24/29); glyph from devices 21. **Selected row only** |
| SS15 | `generic` | `radio_button_unchecked` | 24×24 | `24px` · `rgb(119, 117, 135)` — the settings inactive glyph colour (settings 12/17/22/27/32); glyph from dashboard 33. **Unselected rows only** |

The trailing slot occupied by SS14/SS15 is `settings.md`'s own
`chevron_right` slot (12/17/22/27/32), same box, same colour roles.
**`chevron_right` itself is not drawn here** — it promises navigation, and
these rows select rather than navigate.

### Parameter fields — `FR-STORE-004`
Rendered **only** for the currently selected manual mode; the other two modes'
parameters are absent, not disabled. `E08-T05` §2's validation is the
authority (`olderThanDays` ≥ 1, `maxBytes` ≥ 1 MiB); this screen states it, it
does not define it.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| SS16 | `generic` | `Days` \| `Limit (MB)` | — | `12px` · `w500` · `rgb(199, 196, 216)` — the devices state-label treatment in the settings palette |
| SS17 | `textbox:text` | (the numeric value) | 358×~40 | `14px` · `JetBrains Mono` · `rgb(248, 249, 255)` · fill `rgb(33, 49, 69)` · `r12px` — the parent card surface per §Derivation boundary 4 |
| SS18 | `generic` | `error_outline` | 18×18 | `18px` · `rgb(199, 196, 216)` — GAP-009's approved treatment (icon shape, not a new colour). **Validation-error only** |
| SS19 | `generic` | `Enter a whole number of days, 1 or more.` \| `Enter a size of at least 1 MB.` | — | `14px` · `rgb(199, 196, 216)` — settings body line. **Validation-error only.** No red is introduced (§Derivation boundary 5) |

### Explanation list — `FR-STORE-007`
One row per candidate group in `E08-T04`'s latest `RetentionPlan`, then the
`Why:` summary. **Reading this list runs nothing** — the screen observes the
latest plan; it never triggers a pass, and a screen that starts a retention
pass in order to render is a screen that deletes data because someone opened
it.

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| SS20 | `generic` | `Will remove:` | — | `12px` · `w500` · `rgb(199, 196, 216)` — the devices state-label treatment. Copy verbatim from BRD §20/§22, future tense as written |
| SS21 | `generic` | (category label — see §Copy) | — | `14px` · `w500` · `rgb(248, 249, 255)` — as SS8 |
| SS22 | `generic` | (that group's measured bytes) | — | `12px` · `w500` · `rgb(199, 196, 216)` · `JetBrains Mono` — as SS9 |
| SS23 | `generic` | (the group's reason — see §Copy) | — | `14px` · `rgb(199, 196, 216)` — settings body line |
| SS24 | `generic` | `Why:` | — | as SS20. Copy verbatim from BRD §22 |
| SS25 | `generic` | (the plan's summary sentence) | — | `14px` · `rgb(199, 196, 216)` — settings body line |
| SS26 | `generic` | `warning` | 18×18 | `18px` · `rgb(199, 196, 216)` — `dashboard.md` element 17's glyph and size, in the settings palette. **Renders only when the plan carries the same warning condition the dashboard card shows** — this screen never raises a warning the dashboard does not |

### States `empty` and `error`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| SS27 | `generic` | `Nothing to remove right now.` | — | `14px` · `rgb(199, 196, 216)`, centred — GAP-002's approved empty treatment |
| SS28 | `generic` | `Couldn't read local storage. Try again.` | — | as SS27 — GAP-002's treatment; no error colour invented (GAP-009) |

## Copy — verbatim

**Reused unchanged from a measured contract** (no new string):
- `Storage` — `settings.md` element 30
- `sd_storage` — `settings.md` element 29
- `Local Storage` — `dashboard.md` element 15
- `warning` — `dashboard.md` element 17
- `radio_button_unchecked` — `dashboard.md` element 33
- `radio_button_checked` — `devices.md` element 21
- `arrow_back` — `chat.md` element 2
- `error_outline` — GAP-009, approved 2026-08-29

**Taken verbatim from the BRD** (a spec source, not agent voice):
- `Smart Mode` *(BRD §19; also `dashboard.md` element 18's own string)*
- `Delete data older than X days` *(BRD §19)*
- `Delete old data when storage exceeds X MB` *(BRD §19)*
- `Will remove:` *(BRD §20, §22)*
- `Why:` *(BRD §22)*
- `Temporary cache` *(BRD §20 — maps to `StorageItemKind.relayPayload`, per `E08-T02` §2)*
- `Voice messages` · `Call recordings` · `Old attachments` *(BRD §20 — these categories produce zero items in this build, `E08-T02` §2; they are listed so the format is fixed before the media path exists, not because data exists today)*
- `Rarely accessed` · `No longer required` *(BRD §20/§22 reason strings)*

**Proposed copy this contract introduces** — every string below is an agent
proposal in the parents' voice and is what the 🧍 gate is being asked to
approve:
- `Choose how NEXORA manages local storage.` *(SS4)*
- `Smart Mode doesn't remove conversation content.` *(SS12 — states `OQ-E08-3`'s answer, does not decide it)*
- `This mode can remove conversation content.` *(SS13)*
- `Days` · `Limit (MB)` *(SS16)*
- `Enter a whole number of days, 1 or more.` *(SS19)*
- `Enter a size of at least 1 MB.` *(SS19)*
- `Nothing to remove right now.` *(SS27)*
- `Couldn't read local storage. Try again.` *(SS28)*
- `Messages` *(a category label; no BRD source — the BRD's worked example is media only)*
- `Database file` *(a category label; no BRD source — `StorageItemKind.databaseFile`)*
- `Older than N days` *(reason format; BRD §22 writes `Older than 45 days` / `Older than 60 days` as **examples**)*
- `Over the size limit` *(reason format for `RetentionReason.overSizeLimit`; no BRD source)*
- `Not measured` *(SS9/SS22 when a class could not be measured — never `0`)*

**Format strings — the format is the contract, the number is data:**
- `N MB used` *(SS7)*
- `N MB` *(SS9, SS22)*
- `N members`-style pluralisation is **not** used here; byte figures carry a
  unit, not a count.

**The BRD's example figures are NOT copy.** `820 MB`, `620 MB`, `310 MB` and
`50 MB` (BRD §20/§22) are illustrative numbers in a worked example. Putting
any of them on this screen would print a fabricated figure — the exact defect
`dashboard_controller.dart`'s `isMeasured: false` header exists to prevent.
Every number this screen shows comes from `E08-T02`'s real measurement or the
row does not render.

## Tokens — every value cited from a parent contract's measured table

`rgb(11, 28, 48)` is used below **only** as settings' own page *fill*; §Derivation
boundary 2 names the same value in devices' *text* role precisely to say it is
not borrowed in that role. `rgb(234, 241, 255)`, `rgb(186, 26, 26)` and
`rgb(229, 238, 255)` appear only in §Derivation boundary 3/4/5 as values
deliberately **not** used.

| role | value | source contract (measured table) | used here for |
|---|---|---|---|
| page fill | `rgb(11, 28, 48)` | settings | the screen ground (settings' own page surface) |
| surface / fill | `rgb(26, 44, 66)` | settings | SS10 row cards, the usage card |
| surface / fill | `rgb(33, 49, 69)` | settings | SS17 field fill |
| border | `rgba(199, 196, 216, 0.1)` | settings | card hairlines |
| text colour | `rgb(248, 249, 255)` | settings | SS3, SS6, SS8, SS11, SS17, SS21 |
| text colour | `rgb(199, 196, 216)` | settings | SS4, SS7, SS9, SS12, SS13, SS16, SS18-SS20, SS22-SS28 |
| text colour | `rgb(195, 192, 255)` | settings | SS2, SS5, SS14 |
| text colour | `rgb(119, 117, 135)` | settings | SS15 |
| font size | `28px` | settings | SS3 |
| font size | `24px` | settings · devices | SS2, SS5, SS14, SS15 |
| font size | `22px` | settings · devices · dashboard | SS6, SS11 |
| font size | `18px` | dashboard | SS18, SS26 |
| font size | `14px` | settings · devices · dashboard | SS4, SS7, SS8, SS12, SS13, SS17, SS19, SS21, SS23, SS25, SS27, SS28 |
| font size | `12px` | settings · devices · dashboard | SS9, SS16, SS20, SS22, SS24 |
| font weight | `600` | settings · devices · dashboard | SS3 |
| font weight | `500` | settings · devices · dashboard | SS6, SS8, SS9, SS11, SS16, SS20, SS21, SS22, SS24 |
| font weight | `400` | settings · devices · dashboard | all other prose |
| radius | `12px` | settings · devices · dashboard | SS10, SS17 |
| radius | `9999px` | settings · devices · dashboard | SS1 |
| font family | `Material Symbols Outlined` | settings · devices · dashboard | every glyph |
| font family | `Inter` | settings · devices · dashboard | all prose |
| font family | `JetBrains Mono` | settings · devices · dashboard | every numeral (SS7, SS9, SS17, SS22) |

## Derivation

| What | Borrowed from | Serves |
|---|---|---|
| frame, palette, header icon-button, screen title/subtitle, row card, `heading:3`, body line, tertiary glyph colour, `sd_storage` | `design/screens/settings.md` (elements 1/2, 4/5, 6, 7, 8/13/18/23/28, 10/15/20/25/30, 11/16/21/26/31, 12/17/22/27/32, 29) | FR-STORE-004, FR-STORE-007 |
| the list row with a trailing slot and a state label; the `radio_button_checked` glyph | `design/screens/devices.md` (elements 8-15, 14/22/30/38, 21) | FR-STORE-004, FR-STORE-007 |
| `Local Storage` heading, the `… used` usage line, `warning`, `radio_button_unchecked` | `design/screens/dashboard.md` (elements 15, 16, 17, 33) | FR-STORE-007 |
| `arrow_back` glyph | `design/screens/chat.md` (element 2) — the same borrow `group-manage.md` GM2 makes | navigation |
| centred empty / error line | GAP-002, approved and built | FR-STORE-007 |
| `error_outline` at a muted colour instead of a new red | GAP-009, approved 2026-08-29 | FR-STORE-004 |
| the byte-not-percentage decision | `OQ-E08-1` answered by the human 2026-09-02, option (c); `GAP-026` | FR-STORE-006 |
| what Smart Mode may remove, and therefore SS12/SS13's copy | `OQ-E08-3` answered by the human 2026-09-02, option (a) | FR-STORE-004, FR-STORE-005 |
| the mode names, `Will remove:`, `Why:`, the categories and reason strings | `documentation/BRD.md` §19, §20, §22 | FR-STORE-004, FR-STORE-007 |
| what each row actually says | `E08-T04` `RetentionPlan` · `E08-T05` `StorageSettingsRepository` — not design sources, the **authority** | FR-STORE-004, FR-STORE-007 |

**Spec served:** `FR-STORE-004` (the three modes and their parameters — SS10-SS17
is that requirement rendered), `FR-STORE-007` (the decisions the active policy
made, with reasons — SS20-SS26). `FR-STORE-006`'s "not requiring a Clean Now
action" is served by an **absence**, which is why it is written down at the top
rather than left to be noticed.

## Open — put to the human, not decided

1. **The unavailable-factor wording.** `E08-T04` reports each of
   `FR-STORE-005`'s eight factors as scored or `Unavailable(reason)`, and a
   factor can be unavailable for reasons that outlive `OQ-E08-4`'s answer —
   *storage pressure* is unavailable until the Pigeon free-space channel
   `OQ-E08-1`(a) authorises actually ships. `FR-STORE-007` requires an
   explanation, and an explanation that silently omits a factor is not one.
   **No copy is proposed**, because how much of the machinery a user should
   be shown is a product judgement: the options are (a) say nothing and
   explain only from the factors that did score; (b) one line naming the
   unavailable factors; (c) a per-factor list. *No advisory* — this is
   `OQ-E08-4`'s neighbourhood and the answer that resolved *importance* does
   not resolve *wording*.
2. **`GAP-027` — "export".** `settings.md` element 31 promises it and no
   requirement asks for it. This screen has no export element. The fork is
   recorded in `design/gaps.md` GAP-027 with **no proposal**, and tracked as
   `OQ-E08-T07-1`. Nothing here quietly designs it.
3. **`GAP-026` — the denominator.** SS7 shows bytes. If a user-visible budget
   is later wanted (`OQ-E08-1` option (b), deferred not rejected),
   `storage_policy_settings.budget_bytes` is where it lands and this screen is
   where it would be set — which would add one field, not a new screen.
   Recorded so the future change has a named home.
4. **Screen-as-detail vs screen-as-menu** — §Derivation boundary 1. The
   alternative is named there; the advisory is the detail screen.

## Notes for the implementing agent (`E08-T09`)

- **Never re-implement policy in a widget.** Read `RetentionPlan` and
  `StorageSettingsRepository`. Two similar answers is the failure `E08-T04`
  and `E08-T05` exist to prevent.
- **The screen observes; it never triggers a pass.** No `refresh()` on build,
  no pass on pull-to-refresh.
- **Row layout: read `E06-B01` first.** A title plus a trailing slot after a
  `Spacer()` with no width bound is exactly the 57px overflow that hung
  `flutter test` for a full 10-minute timeout. SS11 is the flexible child with
  an ellipsis policy; SS12/SS13 wrap.
- A mode with no parameter renders **no** field — absent, not disabled.
- Once built, extract the built screen as its own golden, then this contract
  is gated by `make design-verify SCREEN=settings-storage` like every other.
