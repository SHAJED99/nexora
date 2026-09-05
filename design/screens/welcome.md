---
id: welcome
impl_path: /welcome
source: ui
states: [default]
viewports: [390x844]
golden: design\golden\welcome\default@390x844/
elements: 11
generated_by: design/tools/contract.mjs
generated_at: 2026-08-26T10:52:48.631Z
---
# welcome · design contract

> **Generated — do not hand-edit the tables.** Regenerate with
> `make design-contract SCREEN=welcome` after the design changes.
> Hand-written sections at the bottom (Journey gaps, Notes) are preserved by you,
> not by the generator — keep them below the marker.
>
> **Rule 2 (design is law).** Every element below exists in the build, with that
> copy, character for character. The gate is `make design-verify SCREEN=welcome`
> — it fails on a missing element, changed copy, or an off-token style.
> Deliberate divergence goes in the task's §Deviations with its spec reason, and
> in `design/gaps.md`. Silence is not an option.

- **Route:** `/welcome`
- **Golden:** `design\golden\welcome\default@390x844/page.png` (screenshot) + `probe.json` (machine truth)
- **Captured:** 11 visible elements · 3 surfaces · 7 distinct strings
- **Page:** 390×844 viewport, 884px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
| text colour | `rgb(211, 228, 254)` | 3 |
| text colour | `rgb(218, 215, 255)` | 1 |
| text colour | `rgb(195, 192, 255)` | 1 |
| text colour | `rgb(203, 219, 245)` | 1 |
| text colour | `rgb(60, 64, 67)` | 1 |
| surface / fill | `rgb(33, 49, 69)` | 1 |
| surface / fill | `rgb(79, 70, 229)` | 1 |
| surface / fill | `rgb(248, 249, 255)` | 1 |
| border | `rgb(199, 196, 216)` | 1 |
| font size | `14px` | 2 |
| font size | `60px` | 1 |
| font size | `57px` | 1 |
| font size | `22px` | 1 |
| font size | `16px` | 1 |
| font size | `12px` | 1 |
| font weight | `400` | 4 |
| font weight | `500` | 2 |
| font weight | `600` | 1 |
| radius | `24px` | 1 |
| radius | `9999px` | 1 |
| font family | `Inter` | 3 |
| font family | `Material Symbols Outlined` | 2 |
| font family | `Geist` | 1 |
| font family | `JetBrains Mono` | 1 |
| shadow | `rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(79, 70, 229, 0.3) 0px 0px 40px 0px` | 1 |
| shadow | `rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 1px 3px 0px, rgba(0, 0, 0, 0.06) 0px 1px 2px 0px` | 1 |

## Elements — the build checklist

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| 1 | `generic` | hub | 60×60 | 60px · rgb(218, 215, 255) |
| 2 | `heading:1` | NEXORA | 227×64 | 57px · w600 · rgb(195, 192, 255) |
| 3 | `generic` | Connect beyond the network. | 280×56 | 22px · w500 · rgb(203, 219, 245) |
| 4 | `generic` | Secure communication that keeps working when the network doesn't. | 280×40 | 14px · rgb(211, 228, 254) |
| 5 | `button` | — | 326×58 | bg rgb(248, 249, 255) · r9999px |
| 6 | `image` | Google logo | 20×20 | — |
| 7 | `generic` | Continue with Google | 173×24 | rgb(60, 64, 67) |
| 8 | `generic` | End-to-end encrypted mesh | 326×16 | 12px · w500 · rgb(211, 228, 254) |
| 9 | `generic` | lock | 14×14 | 14px · rgb(211, 228, 254) |

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

- `hub`
- `NEXORA`
- `Connect beyond the network.`
- `Secure communication that keeps working when the network doesn't.`
- `Continue with Google`
- `End-to-end encrypted mesh`
- `lock`

<!-- ── generated above · hand-written below ────────────────────────────── -->

## Journey gaps
> States, flows or screens the SPEC requires that this design does not show.
> Fill from the BRD / SRS / feature list, keep consistent with the primitives
> above, log each one in `design/gaps.md`, and get 🧍 human approval before
> building. Do not invent silently.

- **GAP-029 (E14, `FR-VER-006`)** — a mandatory (`UPDATE_REQUIRED`)
  version block has no screen anywhere in this design. Proposed: a new
  `design/screens/version-update-required.md` full-screen state, in this
  screen's own centred single-focus layout — reached wherever the
  version-check actually runs (at launch and/or mid-session, a behavioral
  decision for whichever task builds it, not a placement this contract
  settles) — full derivation in `design/gaps.md` GAP-029. ✅ approved
  (human, 2026-09-05) — not yet built.

## Notes for the implementing agent
- (exact copy quirks, dynamic data, anything the probe cannot see)
