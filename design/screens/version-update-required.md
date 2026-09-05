---
id: version-update-required
impl_path: /version-update-required
source: derived
derived_from: [welcome, devices]
states: [default]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-VER-006, FR-VER-009]
gap: GAP-029
---
# version-update-required · derived design contract

> **`source: derived` — hand-written, not generated.** The design source
> draws no mandatory-update state anywhere, and — checked across every
> one of the fourteen measured screens — draws **no dialog or bottom-sheet
> primitive at all**. `dashboard.md`'s own derived `warning-expanded`
> state (`GAP-025`) already established this finding for a similarly
> blocking moment: "the design draws no dialog or sheet primitive
> anywhere, and inventing one would be inventing a visual language." A
> mandatory, non-dismissible update block is derived the same way — as a
> full-screen state in `welcome.md`'s own centred layout, never an
> invented dialog.
>
> **Built against GAP-029, approved by the human on 2026-09-05 ("approved
> as proposed"). Not independently approved by an agent.**

- **Route:** `/version-update-required` — a new route. Exactly when it is
  entered (at launch, mid-session, or both) is a behavioral decision for
  whichever task builds it, not a placement this contract settles
  (`design/gaps.md` GAP-029's own note).
- **Parent contracts:** `design/screens/welcome.md` (frame, icon/heading/
  subtitle sizing, button shape) · `design/screens/devices.md` (the
  non-branded primary button fill, the `warning` status colour)
- **Leads to:** the platform's Google Play in-app update flow (external,
  not a route this app owns) on the one button press. There is no "leads
  to" for anything else — this screen has no other affordance.

## Derivation boundary — what is NOT derived

1. **New copy.** Every string this contract introduces is proposed copy,
   in `welcome.md`'s own plain, direct voice. Listed verbatim in §Copy.
2. **Nothing else.** Every size, colour, weight, radius and family below
   is grep-verifiable in one of the two parent contracts' measured token
   tables.

Explicitly out of this contract: the actual version-check logic, the
Google Play in-app update API call, and whether/how the system back
gesture is suppressed — all backend/platform-integration concerns,
`E14`'s own task contracts, not this file. Also out of scope: the
`UPDATE_AVAILABLE` (non-blocking, dismissible) state — this contract
covers only `UPDATE_REQUIRED`, per `GAP-029`'s own boundary; a dismissible
nudge is a separate, smaller gap if the design ever needs one.

## Surface story — which parent supplies what
`welcome.md` is the **frame**: the centred column layout, the icon size
(`60×60`, element 1), the heading sizing (`22px` `w500`, element 3), the
body-text sizing (`14px`, element 4), and the full-width button shape
(`326×58`, `r9999px`, element 5) — not its Google-branded fill, for the
same reason `device-enrollment.md` didn't reuse it: a white/Google-logo
button here would misleadingly suggest a sign-in action. `devices.md`
supplies the non-branded primary button fill (`bg rgb(53, 37, 205)`,
`12px` `w500` `rgb(255, 255, 255)` label, element 6) and the `warning`
status colour (`rgb(245, 158, 11)`, element 29) for the icon, since this
state is exactly "needs the user's attention," this design's own existing
meaning for that colour.

## States

### 1. `default` (the only state)
This condition has no sub-states — it is reached, blocks everything else,
and is left only by actually completing the update (at which point the
app restarts into its normal flow; there is no "success" screen to
design, the condition simply stops being true). `warning` icon at
`welcome.md`'s icon size. Heading states plainly that the app cannot be
used until updated. Body states, explicitly, that local data is
preserved (`FR-VER-009` — stated so a blocked user is never left
guessing whether updating will erase their history; the same "state the
property, don't leave it implicit" discipline `device-enrollment.md`'s
`no-recovery-notice` state applies for `FR-RECOVER-002`). One button
opens the platform update flow. **No secondary button, no back
navigation, no dismiss affordance of any kind** — `FR-VER-006`'s
"non-dismissible" is a structural absence: there is nothing else on this
screen to tap, not a disabled-looking button standing in for one.

## Elements — the build checklist

| # | role | copy / label | size | key styles (cited from the parent contracts) |
|---|---|---|---|---|
| VUR1 | `generic` | `warning` | 60×60 | `60px` · `rgb(245, 158, 11)` — the welcome icon sizing (element 1), the devices `warning` colour (element 29) |
| VUR2 | `heading:2` | `Update required` | — | `22px` · `w500` · `rgb(203, 219, 245)` — the welcome subtitle-heading treatment (element 3) |
| VUR3 | `generic` | `A new version of Nexora is required to continue. Your messages, files and settings are safe and will still be here after you update.` | — | `14px` · `rgb(211, 228, 254)` — the welcome body treatment (element 4) |
| VUR4 | `button` | `Update now` | 326×58 | `r9999px` shape from welcome (element 5); fill `bg rgb(53, 37, 205)`, label `12px` `w500` `rgb(255, 255, 255)` — the devices `Discover` button treatment (element 6), not welcome's own Google-branded fill |

## Copy — verbatim
Strings this contract introduces (proposed copy):

- `Update required`
- `A new version of Nexora is required to continue. Your messages, files and settings are safe and will still be here after you update.`
- `Update now`

Reused unchanged from `devices.md`: `warning`.

No glyph in this contract is new.

## Tokens — every value cited from a parent contract's measured table
| role | value | source contract | used here for |
|---|---|---|---|
| text colour ⁂ | `rgb(245, 158, 11)` | devices, element 29 | VUR1 |
| text colour | `rgb(203, 219, 245)` | welcome | VUR2 |
| text colour | `rgb(211, 228, 254)` | welcome | VUR3 |
| text colour | `rgb(255, 255, 255)` | devices | VUR4 label |
| surface / fill | `rgb(53, 37, 205)` | devices | VUR4 fill |
| font size | `60px` | welcome | VUR1 |
| font size | `22px` | welcome | VUR2 |
| font size | `14px` | welcome | VUR3 |
| font size | `12px` | devices | VUR4 label |
| font weight | `500` | welcome · devices | VUR2, VUR4 |
| radius | `9999px` | welcome · devices | VUR4 |
| font family | `Material Symbols Outlined` | devices | VUR1 |
| font family | `Inter` | welcome | VUR2, VUR3, VUR4 |

> ⁂ `rgb(245, 158, 11)` is measured on `devices.md`'s element 29, not
> listed in that screen's own generator token table (single-use values
> aren't always listed) — same caveat `device-enrollment.md` and
> `group-create.md` already documented for their own single-use measured
> values.

## Derivation
| What | Borrowed from | Serves |
|---|---|---|
| centred frame, icon size, heading/body sizing, button shape | `design/screens/welcome.md` (elements 1, 3, 4, 5) | FR-VER-006 |
| non-branded primary button fill, `warning` status colour | `design/screens/devices.md` (elements 6, 29) | FR-VER-006 |

**Spec served:** `FR-VER-006` (block communication, present a
non-dismissible mandatory update prompt via Google Play), `FR-VER-009`
(mandatory updates must not delete local data — stated to the user, not
just true underneath).

## Notes for the implementing agent
- **Non-dismissible is structural.** Do not add a close icon, a swipe-to-
  dismiss gesture, or a system-back no-op disguised as a button — the
  absence of any such control IS the requirement. If the platform's own
  chrome (status bar back gesture, etc.) needs suppressing to make this
  true, that is this task's own job to get right, not a visual element to
  add here.
- The exact moment this route is entered (splash/launch check vs. a
  mid-session check that can interrupt an active screen) is left to the
  build task, per `GAP-029`'s own note — this contract only fixes what
  the screen looks like once reached.
- Once built, extract the built state as its own golden — from then on it
  is regression-gated like every other screen (`design-fidelity` §3).
