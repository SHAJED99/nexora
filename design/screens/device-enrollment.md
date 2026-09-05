---
id: device-enrollment
impl_path: /device-enrollment
source: derived
derived_from: [welcome, devices]
states: [waiting, denied, no-recovery-notice]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-RECOVER-001, FR-RECOVER-002]
gap: GAP-028
---
# device-enrollment · derived design contract

> **`source: derived` — hand-written, not generated.** The design source
> draws nothing between a successful Google sign-in and the dashboard
> redirect. `welcome.md`'s centred, single-focus layout (icon, heading,
> subtitle, one primary button) is this design's only "one decision,
> nothing else on screen" shape, and is reused here for every state.
> `welcome.md`'s own button is Google-branded (white fill, Google logo)
> and reusing it here would misleadingly read as another Google sign-in
> — so the primary action instead borrows `devices.md`'s generic
> `Discover` button treatment, this design's only non-branded primary
> button.
>
> **Built against GAP-028, approved by the human on 2026-09-05 ("approved
> as proposed"). Not independently approved by an agent.**

- **Route:** `/device-enrollment` — a new route, reached from the login
  flow (`design/screens/login.md`'s own Journey gaps note) before the
  existing `/dashboard` redirect, only when the signed-in account already
  owns other devices with local history this new device cannot read.
  Registering the route and deciding exactly when to route here is the
  build task's job, not this contract's.
- **Parent contracts:** `design/screens/welcome.md` (frame, icon/heading/
  subtitle sizing, button shape) · `design/screens/devices.md` (the
  generic primary button fill/label, the `warning` status colour)
- **Leads to:** `/dashboard` on success (no new screen — falls through to
  the existing redirect, same pattern `group-create.md` used for its own
  success case) or after choosing to continue without recovery.

## Derivation boundary — what is NOT derived

1. **New copy.** Every string this contract introduces is proposed copy,
   in `welcome.md`'s own voice (short, plain, no jargon — matching
   `Secure communication that keeps working when the network doesn't.`).
   Listed verbatim in §Copy.
2. **Nothing else.** Every size, colour, weight, radius and family below
   is grep-verifiable in one of the two parent contracts' measured token
   tables.

Explicitly out of this contract: the enrollment protocol itself (how a
trusted device is actually discovered/contacted, the approve/deny wire
exchange, timeout duration) — backend, `E12`'s own task contracts; and
exactly when/how this route is entered from `login.md` — a behavioral
decision for whichever task builds it.

## Surface story — which parent supplies what
`welcome.md` is the **frame**: the centred column layout, the icon size
(`60×60`, element 1), the `heading:2`-equivalent subtitle sizing (`22px`
`w500`, element 3), the body-text sizing (`14px`, element 4), and the
full-width stacked-button shape (`326×58`, `r9999px`, element 5) — though
not its fill colour, per the header note above. `devices.md` supplies the
one thing `welcome.md` has no equivalent for: a non-branded primary
button fill (`bg rgb(53, 37, 205)`, `12px` `w500` `rgb(255, 255, 255)`
label, element 6) and the `warning` status colour (`rgb(245, 158, 11)`,
element 29) used on the no-recovery notice.

## States

### 1. `waiting`
Reached immediately on entering this route. The app is attempting to
reach an existing trusted device on the mesh. Icon: `hub` (this design's
own app-identity glyph, `welcome.md` element 1, not a new one) at the
same size, to read as "still Nexora," not an error. Heading states what's
happening; subtitle shows a short pairing code/fingerprint the user could
read aloud to whoever is at the trusted device (the actual code value is
backend-supplied, not this contract's concern). One button: "Continue
without history" — present from the start, never hidden while waiting,
so a user is never trapped on this screen (`EARS`-level: the choice to
skip must always be reachable, not only after a timeout).

### 2. `denied`
The trusted device declined, or the request timed out with no device
reachable. Same frame, updated heading/subtitle — plain restatement, no
blame copy (mirrors `group-create.md`'s own `error` state discipline:
"no blame copy", same reasoning here even though this is a denial, not a
failure). Same single button as `waiting`.

### 3. `no-recovery-notice`
Reached after choosing "Continue without history" from either prior
state. States `FR-RECOVER-002`'s property plainly: historical content
on other devices cannot be recovered here, and that this is by design,
not an error (the `FR-RECOVER-002` clause itself: "intentional, not a
defect" — that framing belongs in the copy, not left implicit). Icon:
the `warning` glyph (devices' own `rgb(245, 158, 11)`, at `welcome.md`'s
icon size) — not the `hub` glyph, since this is the one state where
something the user should attend to is being stated. One button:
"Continue" — proceeds to `/dashboard`.

## Elements — the build checklist

### Frame (all states)
| # | role | copy / label | size | key styles (cited from the parent contracts) |
|---|---|---|---|---|
| DE1 | `generic` | `hub` (waiting/denied) or `warning` (no-recovery-notice) | 60×60 | `60px` · `rgb(218, 215, 255)` (welcome element 1) or `rgb(245, 158, 11)` (devices element 29) per state above |
| DE2 | `heading:2` | (state heading, see §Copy) | — | `22px` · `w500` · `rgb(203, 219, 245)` — the welcome subtitle-heading treatment (element 3) |
| DE3 | `generic` | (state body text, see §Copy) | — | `14px` · `rgb(211, 228, 254)` — the welcome body treatment (element 4) |
| DE4 | `button` | (state button label, see §Copy) | 326×58 | `r9999px` shape from welcome (element 5); fill `bg rgb(53, 37, 205)`, label `12px` `w500` `rgb(255, 255, 255)` — the devices `Discover` button treatment (element 6), not welcome's own Google-branded fill |

## Copy — verbatim
Strings this contract introduces (proposed copy):

- `Looking for a trusted device…` (heading, `waiting`)
- `Ask a trusted device nearby to approve this one. Code: [pairing code]` (body, `waiting`)
- `No trusted device responded` (heading, `denied`)
- `You can try again later from Settings, or continue without your history.` (body, `denied`)
- `You're starting fresh` (heading, `no-recovery-notice`)
- `Without an existing device to vouch for this one, messages and files from before today can't be recovered here. This is expected — not an error.` (body, `no-recovery-notice`)
- `Continue without history` (button, `waiting`/`denied`)
- `Continue` (button, `no-recovery-notice`)

Reused unchanged from `welcome.md`: `hub`.
Reused unchanged from `devices.md`: `warning`.

No glyph in this contract is new.

## Tokens — every value cited from a parent contract's measured table
| role | value | source contract | used here for |
|---|---|---|---|
| text colour | `rgb(218, 215, 255)` | welcome | DE1 `hub` |
| text colour ⁂ | `rgb(245, 158, 11)` | devices, element 29 | DE1 `warning` |
| text colour | `rgb(203, 219, 245)` | welcome | DE2 |
| text colour | `rgb(211, 228, 254)` | welcome | DE3 |
| text colour | `rgb(255, 255, 255)` | devices | DE4 label |
| surface / fill | `rgb(53, 37, 205)` | devices | DE4 fill |
| font size | `60px` | welcome | DE1 |
| font size | `22px` | welcome | DE2 |
| font size | `14px` | welcome | DE3 |
| font size | `12px` | devices | DE4 label |
| font weight | `500` | welcome · devices | DE2, DE4 |
| radius | `9999px` | welcome · devices | DE4 |
| font family | `Material Symbols Outlined` | welcome · devices | DE1 |
| font family | `Inter` | welcome | DE2, DE3, DE4 |

> ⁂ `rgb(245, 158, 11)` is measured on `devices.md`'s element 29
> (the `Unknown`/`warning` row), not listed in that screen's own
> generator token table (single-use values aren't always listed) — same
> caveat `group-create.md` already documented for its own single-use
> measured values.

## Derivation
| What | Borrowed from | Serves |
|---|---|---|
| centred frame, icon size, heading/body sizing, button shape | `design/screens/welcome.md` (elements 1, 3, 4, 5) | FR-RECOVER-001 |
| non-branded primary button fill, `warning` status colour | `design/screens/devices.md` (elements 6, 29) | FR-RECOVER-001, FR-RECOVER-002 |

**Spec served:** `FR-RECOVER-001` (new-device enrollment authorized by an
existing trusted device, where possible), `FR-RECOVER-002` (permanently
lost keys mean historical content is not recoverable — an intentional
property, stated to the user rather than left silent).

## Notes for the implementing agent
- The "Continue without history" button must be reachable from the very
  first frame of `waiting` — never gate it behind a timeout. A user who
  has genuinely lost every device must never be stuck waiting
  indefinitely for one that will never answer.
- `no-recovery-notice`'s copy is deliberately explicit that this is
  expected behavior, not a bug — `FR-RECOVER-002`'s own text calls this
  out, and a support ticket asking "why did I lose my messages" is the
  failure mode this copy exists to prevent.
- The actual pairing code/fingerprint value, and how enrollment is
  actually attempted over the mesh, are backend concerns — `E12`'s own
  task contracts, not this file.
- Once built, extract each state as its own golden — from then on this
  screen is regression-gated like every other screen (`design-fidelity`
  §3).
