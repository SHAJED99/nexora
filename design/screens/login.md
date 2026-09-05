---
id: login
impl_path: /login
source: ui
states: [default]
viewports: [390x844]
golden: design\golden\login\default@390x844/
elements: 7
generated_by: design/tools/contract.mjs
generated_at: 2026-08-26T10:52:48.638Z
---
# login · design contract

> **Generated — do not hand-edit the tables.** Regenerate with
> `make design-contract SCREEN=login` after the design changes.
> Hand-written sections at the bottom (Journey gaps, Notes) are preserved by you,
> not by the generator — keep them below the marker.
>
> **Rule 2 (design is law).** Every element below exists in the build, with that
> copy, character for character. The gate is `make design-verify SCREEN=login`
> — it fails on a missing element, changed copy, or an off-token style.
> Deliberate divergence goes in the task's §Deviations with its spec reason, and
> in `design/gaps.md`. Silence is not an option.

- **Route:** `/login`
- **Golden:** `design\golden\login\default@390x844/page.png` (screenshot) + `probe.json` (machine truth)
- **Captured:** 7 visible elements · 2 surfaces · 5 distinct strings
- **Page:** 390×844 viewport, 844px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
| text colour | `rgb(53, 37, 205)` | 3 |
| text colour | `rgb(11, 28, 48)` | 1 |
| text colour | `rgb(70, 69, 85)` | 1 |
| surface / fill | `rgb(248, 249, 255)` | 1 |
| surface / fill | `rgb(239, 244, 255)` | 1 |
| border | `rgba(199, 196, 216, 0.1)` | 1 |
| font size | `20px` | 1 |
| font size | `22px` | 1 |
| font size | `28px` | 1 |
| font size | `24px` | 1 |
| font size | `14px` | 1 |
| font weight | `400` | 3 |
| font weight | `500` | 1 |
| font weight | `600` | 1 |
| radius | `8px` | 1 |
| font family | `Material Symbols Outlined` | 2 |
| font family | `Inter` | 2 |
| font family | `Geist` | 1 |

## Elements — the build checklist

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| 1 | `generic` | hub | 20×20 | 20px · rgb(53, 37, 205) |
| 2 | `heading:1` | NEXORA | 88×28 | 22px · w500 · rgb(53, 37, 205) |
| 3 | `heading:2` | Signing in with Google... | 319×36 | 28px · w600 · rgb(11, 28, 48) |
| 4 | `generic` | lock | 24×24 | 24px · rgb(53, 37, 205) |
| 5 | `generic` | Authentication only. Your messages stay end-to-end encrypted and never pass through Google. | 280×60 | 14px · rgb(70, 69, 85) |

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

- `hub`
- `NEXORA`
- `Signing in with Google...`
- `lock`
- `Authentication only. Your messages stay end-to-end encrypted and never pass through Google.`

<!-- ── generated above · hand-written below ────────────────────────────── -->

## Journey gaps
> States, flows or screens the SPEC requires that this design does not show.
> Fill from the BRD / SRS / feature list, keep consistent with the primitives
> above, log each one in `design/gaps.md`, and get 🧍 human approval before
> building. Do not invent silently.

- **GAP-028 (E12, `FR-RECOVER-001`/`FR-RECOVER-002`)** — this design has
  nothing between a successful Google sign-in and the dashboard redirect
  for the case where the signed-in account already owns other devices
  with local history this new device cannot read. Proposed: a new
  `design/screens/device-enrollment.md` screen, reached here before the
  existing dashboard redirect when that condition holds — full
  derivation in `design/gaps.md` GAP-028. ✅ approved (human, 2026-09-05)
  — not yet built.

## Notes for the implementing agent
- (exact copy quirks, dynamic data, anything the probe cannot see)
