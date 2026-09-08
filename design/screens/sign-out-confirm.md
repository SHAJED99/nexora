---
id: sign-out-confirm
impl_path: /settings/sign-out-confirm
source: derived
derived_from: [welcome, devices, version-update-required, settings-shell]
states: [default]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-AUTH-007, FR-AUTH-006, FR-AUTH-008, FR-RECOVER-002]
gap: GAP-039
---
# sign-out-confirm · derived design contract

> **`source: derived` — hand-written, not generated.** The design source shows
> **nothing** for this journey: no confirmation of any kind anywhere in the
> measured set, and — materially — **this design draws no dialog or
> bottom-sheet primitive anywhere**. That finding is not new: `GAP-025`
> established it, and `GAP-029` re-confirmed it and derived a **full screen**
> instead of inventing a dialog. This contract does the same thing for the same
> reason.
>
> **Built against `GAP-039`, 🟡 proposed and NOT approved** (bare
> `approved by:`, `L-process-002`). It shares `GAP-035`'s **unresolved fork on
> the destructive treatment**; SO6 below is written without asserting a colour.
> **No golden until the build exists.**

- **Route:** `/settings/sign-out-confirm`, reached **only** from
  `settings-account.md` AC14. Nothing else links here.
- **What this screen does:** exactly one thing. It states what will be
  destroyed and offers two choices. It performs no read of any kind — every
  string on it is static — so it has no loading, empty or error state.

## The prohibitions this screen exists to keep

**1. This is not a dialog.** Not an `AlertDialog`, not a `showModalBottomSheet`,
not a snackbar with an action. It is a route, pushed like any other screen.
`GAP-025` and `GAP-029` both recorded that inventing a dialog primitive invents
a visual language this design does not have, and the second-most destructive
action in the product (a blocking update) already got a full screen for exactly
this reason. The most destructive one gets no less.

**2. The confirm affordance is not the default, not the first, and not
pre-focused.** SO7 (cancel) is reachable by the system back gesture and by the
back affordance; SO6 requires a deliberate tap on the thing that says what it
does.

**3. The copy names what is lost, concretely.** `FR-AUTH-007` says "naming what
is permanently lost". SO4's list is that naming, and it is not a summary — a
user who reads "sign out" and loses six months of messages was not warned by
the word "sign out".

**4. There is no progress state.** No spinner, no "wiping…" screen, no
percentage. This design draws none (`settings-shell.md` §3), and `FR-AUTH-009`
already makes an interrupted wipe safe by resuming it at next launch rather
than by watching it. Once SO6 is tapped, the next thing the user sees is the
welcome screen (`FR-AUTH-012`).

## Elements — the build checklist

There is **no `settings-shell.md` frame here** — this is a `welcome.md`-shaped
single-focus screen, not a settings destination. It is the same structural
choice `version-update-required.md` made.

| id | role | copy / label | derivation |
|---|---|---|---|
| SO1 | `button` | — (back affordance, 40×40 `r9999px`) | `settings.md` elements 1/4 geometry; glyph `arrow_back` per SH2. Present because — unlike `version-update-required.md` — this screen **is** dismissible; cancelling is a legitimate outcome |
| SO2 | `generic` | `warning` glyph at `welcome.md`'s icon size, `rgb(245, 158, 11)` | `devices.md`'s measured `warning` token — this design's own "needs attention" vocabulary, reused exactly as `GAP-029` reused it |
| SO3 | `heading:1` | `Sign out and erase this device?` | `welcome.md`'s centred heading treatment |
| SO4 | `generic` | the loss list — see §Copy | `welcome.md` body, `14px` |
| SO5 | `generic` | `This cannot be undone. Anything encrypted with these keys can never be read again, on this device or any other.` | same |
| SO6 | `button` | `Sign out and erase` | `welcome.md`'s stacked primary button; **colour pending `GAP-035`/`GAP-039`'s fork** |
| SO7 | `button` | `Cancel` | the same button shape in the neutral treatment, stacked below SO6 |

## Copy — verbatim

- `Sign out and erase this device?`
- `Signing out permanently deletes everything this app keeps on this device:`
- `Your device identity and all of its encryption keys`
- `Every message, voice message and call recording, and all history`
- `Every trusted device and every block you have set`
- `Every group this device belongs to`
- `All of your settings`
- `This cannot be undone. Anything encrypted with these keys can never be read again, on this device or any other.`
- `Signing back in creates a brand-new identity, as if the app had just been installed.`
- `Sign out and erase`
- `Cancel`

The nine-line block is SO4 + SO5. The `Signing back in creates a brand-new
identity…` line matters as much as the loss list: without it, a user
reasonably assumes signing back in restores what they had, which is exactly
what `FR-AUTH-008` says will not happen.

Every phrase in the loss list maps to a real surface in `FR-AUTH-006`'s
enumeration — identity and keys, messages and recordings, trust and blocks,
groups, settings. Nothing is claimed that is not deleted, and nothing that is
deleted is left unmentioned.

## States

One: `default`. Every string is static; there is nothing to load, nothing to be
empty, and nothing that can fail to read.

## Derivation boundary — what is NOT derived

1. **No typed-confirmation phrase** ("type ERASE to continue"). No measured
   text-input primitive exists on any dark surface in this design
   (`settings-storage.md` §Derivation boundary 4), and `FR-AUTH-007` asks for an
   explicit confirmation, not a friction ritual.
2. **No second confirmation.** One deliberate screen is the confirmation.
3. **No "export before you go" affordance.** `GAP-027` already resolved that
   this app has no export, and offering one here would be the cruellest
   possible place to promise something that does not exist.
4. **No countdown, no undo window.** `FR-AUTH-006` is immediate and
   `FR-AUTH-009` completes an interrupted wipe rather than reversing it. An
   undo affordance would be a lie the persistence layer cannot honour.
5. **No destructive colour asserted.** Shared, unanswered, with `GAP-035`.

## Notes for the implementing agent
- Built by `E15-T07` together with `settings-account.md` — one journey, one
  task, so the two screens' copy cannot drift apart.
- SO6 calls `E15-T01`'s sign-out use case and nothing else. This screen
  contains no persistence logic, no `AppDatabase` handle and no navigation
  target other than `/welcome` (on confirm) and pop (on cancel).
