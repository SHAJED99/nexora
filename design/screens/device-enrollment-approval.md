---
id: device-enrollment-approval
impl_path: n/a — a row appended to /devices, not its own route
source: derived
derived_from: [devices]
states: [pending]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-RECOVER-001]
gap: GAP-028
---
# device-enrollment-approval · derived design contract

> **`source: derived` — hand-written, not generated.** The design source
> draws no "a new device wants to join" state anywhere. `devices.md`'s own
> row vocabulary — specifically its `Unknown`/`Verify` row (elements 24-31,
> a device the account doesn't yet trust, with one trailing decision
> button) — is the closest existing shape: a pending enrollment request is
> exactly "a device whose trust status I have not yet decided," just from
> a different cause. This contract composes ONE row from that vocabulary,
> plus `devices.md`'s own `Blocked` row's colour for the negative action.
>
> **Built against GAP-028, approved by the human on 2026-09-05 ("approved
> as proposed"). Not independently approved by an agent.**

- **Route:** none — per `design/gaps.md` GAP-028's own proposal, this is
  not a screen navigation. A pending request renders as a new row at the
  **top** of `/devices`'s existing list, ahead of every established device
  row. `devices.md` itself is not hand-edited to add it (design-fidelity
  rule 1) — this contract is what a build task reads instead, and
  `devices.md`'s own generated element table is untouched.
- **Parent contract:** `design/screens/devices.md`

## Derivation boundary — what is NOT derived

1. **New copy.** The row's label copy is proposed here (§Copy), in
   `devices.md`'s own voice (short, factual, no exclamation — matching
   `Last seen: Just now` / `Unknown Device`).
2. **Nothing else.** Every size, colour, weight, radius and family below
   is grep-verifiable in `devices.md`'s own measured token table or
   element list.

Explicitly out of this contract: whether a push notification (`E10`)
accompanies a pending request (left to whichever task builds it, per
GAP-028's own note), the enrollment protocol itself (device discovery,
the actual approve/deny wire exchange — backend, `E12`'s own task
contracts), and anything about `devices.md`'s OTHER rows, which are
unchanged.

## Surface story — which parent supplies what
`devices.md` supplies the entire row: the icon + title + secondary-line
layout (`Unknown Device`/`Mesh Proximity`, elements 24-26), the trailing
more-menu slot (element 27/28 — kept, unchanged, for consistency with
every other row, even though this row's real decision lives in the two
new buttons below it, not behind the menu), the `warning` status glyph +
label pair (elements 29/30, `rgb(245, 158, 11)`) repurposed for "awaiting
your decision" rather than "unverified," and the `Verify` button's
treatment (element 31, `11px · w500 · rgb(53, 37, 205) · r4px`) reused
for `Approve`. `Deny` borrows the `Blocked` row's colour (element 38,
`rgb(186, 26, 26)`) as its label/border colour, in the same small-button
shape as `Verify` — this design has no second small-button shape to
borrow from, so `Approve`/`Deny` are the same button treatment in two
colours, exactly as `devices.md`'s own state labels reuse one text
treatment in four colours (green/blue/orange/red) rather than four
different label styles.

## States

### 1. `pending` (the only state)
A request exists or it doesn't — there is no loading/error state in the
UI's own terms, matching GAP-028's own note for
`device-enrollment-approval.md`: "this is a synchronous local decision,
not a network round-trip." Tapping `Approve` or `Deny` resolves the
request; the row is removed from the top of the list either way (approved
requests become a normal established-device row per the existing
`devices.md` vocabulary once trust is recorded — no new row shape for
that; denied requests simply disappear, nothing to show).

## Elements — the build checklist

| # | role | copy / label | size | key styles (cited from `devices.md`) |
|---|---|---|---|---|
| DEA1 | `generic` | (device platform icon, e.g. `smartphone`/`laptop_mac`) | 24×24 | `24px` — the devices row leading icon, colour per platform as devices' own rows already vary it (elements 8/16/24/32) |
| DEA2 | `heading:3` | (requesting device's platform name, e.g. `New Phone`) | — | `w500` · `rgb(11, 28, 48)` — the devices row title (elements 9/17/25/33) |
| DEA3 | `generic` | (a short fingerprint/code, e.g. `Code: 4F2A`) | — | `11px` · `rgb(70, 69, 85)` — the devices row secondary line (elements 10/18/26/34) |
| DEA4 | `button` | — | 24×30 | the devices per-row trailing more-menu slot, unchanged (elements 11/19/27/35) |
| DEA5 | `generic` | `more_vert` | 24×24 | `24px` · `rgb(119, 117, 135)` — unchanged (elements 12/20/28/36) |
| DEA6 | `generic` | `warning` | 16×16 | `rgb(245, 158, 11)` — the devices `Unknown`-row status glyph, repurposed (element 29) |
| DEA7 | `generic` | `Awaiting your approval` | — | `12px` · `w500` · `rgb(245, 158, 11)` — same treatment as devices' `Unknown` label (element 30), new copy |
| DEA8 | `button` | `Approve` | 56×24 | `11px` · `w500` · `rgb(53, 37, 205)` · `r4px` — the devices `Verify` button, unchanged treatment, new label (element 31) |
| DEA9 | `button` | `Deny` | 56×24 | `11px` · `w500` · `rgb(186, 26, 26)` · `r4px` — same button shape as DEA8, coloured with the devices `Blocked` state's own colour (element 38) |

## Copy — verbatim
Strings this contract introduces (proposed copy):

- `Awaiting your approval`
- `Approve`
- `Deny`

Reused unchanged from `devices.md`: `more_vert`, `warning`.

No glyph in this contract is new.

## Tokens — every value cited from `devices.md`'s measured table
| role | value | used here for |
|---|---|---|
| text colour | `rgb(11, 28, 48)` | DEA2 title |
| text colour | `rgb(70, 69, 85)` | DEA3 secondary line |
| text colour | `rgb(119, 117, 135)` | DEA5 menu glyph |
| text colour | `rgb(245, 158, 11)` | DEA6, DEA7 |
| text colour | `rgb(53, 37, 205)` | DEA8 |
| text colour | `rgb(186, 26, 26)` | DEA9 |
| font size | `24px` | DEA1, DEA5 |
| font size | `12px` | DEA7 |
| font size | `11px` | DEA3, DEA8, DEA9 |
| font weight | `500` | DEA2, DEA7, DEA8, DEA9 |
| radius | `4px` | DEA8, DEA9 |
| font family | `Material Symbols Outlined` | DEA1, DEA5, DEA6 |
| font family | `Inter` | prose |

## Derivation
| What | Borrowed from | Serves |
|---|---|---|
| entire row layout, icon/title/secondary-line, trailing menu slot, status glyph+label pair, small-button shape | `design/screens/devices.md` (elements 8-12, 24-31, 37-38) | FR-RECOVER-001 |

**Spec served:** `FR-RECOVER-001` ("where possible, an existing trusted
device shall authorize the new device's enrollment").

## Notes for the implementing agent
- This row is prepended to `devices.md`'s existing list, never inserted
  elsewhere in it and never replacing any established row.
- `Approve`/`Deny`'s actual effect (recording trust, notifying the
  requesting device, any key exchange) is `E12`'s own backend task
  contracts — this file only fixes what the row looks like and which two
  actions it offers.
- Once built, extract the built state as its own golden — from then on it
  is regression-gated like every other screen (`design-fidelity` §3).
