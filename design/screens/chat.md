---
id: chat
impl_path: /chat/[id]
source: ui
states: [default]
viewports: [390x844]
golden: design\golden\chat\default@390x844/
elements: 43
generated_by: design/tools/contract.mjs
generated_at: 2026-08-26T10:52:48.636Z
---
# chat · design contract

> **Generated — do not hand-edit the tables.** Regenerate with
> `make design-contract SCREEN=chat` after the design changes.
> Hand-written sections at the bottom (Journey gaps, Notes) are preserved by you,
> not by the generator — keep them below the marker.
>
> **Rule 2 (design is law).** Every element below exists in the build, with that
> copy, character for character. The gate is `make design-verify SCREEN=chat`
> — it fails on a missing element, changed copy, or an off-token style.
> Deliberate divergence goes in the task's §Deviations with its spec reason, and
> in `design/gaps.md`. Silence is not an option.

- **Route:** `/chat/[id]`
- **Golden:** `design\golden\chat\default@390x844/page.png` (screenshot) + `probe.json` (machine truth)
- **Captured:** 43 visible elements · 14 surfaces · 23 distinct strings
- **Page:** 390×844 viewport, 884px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
| text colour | `rgb(70, 69, 85)` | 11 |
| text colour | `rgb(53, 37, 205)` | 5 |
| text colour | `rgb(255, 255, 255)` | 4 |
| text colour | `rgb(11, 28, 48)` | 3 |
| text colour | `rgb(103, 244, 183)` | 1 |
| text colour | `rgb(0, 101, 145)` | 1 |
| surface / fill | `rgb(53, 37, 205)` | 4 |
| surface / fill | `rgb(248, 249, 255)` | 3 |
| surface / fill | `rgb(239, 244, 255)` | 3 |
| surface / fill | `rgb(220, 233, 255)` | 1 |
| surface / fill | `rgb(229, 238, 255)` | 1 |
| surface / fill | `rgb(255, 255, 255)` | 1 |
| border | `rgba(199, 196, 216, 0.1)` | 4 |
| border | `rgba(199, 196, 216, 0.2)` | 2 |
| font size | `12px` | 9 |
| font size | `16px` | 8 |
| font size | `24px` | 6 |
| font size | `22px` | 1 |
| font size | `14px` | 1 |
| font weight | `400` | 15 |
| font weight | `500` | 9 |
| font weight | `700` | 1 |
| radius | `12px` | 4 |
| radius | `9999px` | 3 |
| radius | `2px` | 2 |
| radius | `8px` | 1 |
| font family | `Material Symbols Outlined` | 10 |
| font family | `JetBrains Mono` | 9 |
| font family | `Inter` | 6 |
| shadow | `rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.05) 0px 1px 2px 0px` | 5 |

## Elements — the build checklist

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| 1 | `button` | — | 40×46 | r9999px |
| 2 | `generic` | arrow_back | 24×24 | 24px · rgb(70, 69, 85) |
| 3 | `image` | — | 38×38 | — |
| 4 | `heading:1` | Ahmed | 172×28 | 22px · w500 · rgb(53, 37, 205) |
| 5 | `generic` | lock | 14×14 | 14px · rgb(53, 37, 205) |
| 6 | `generic` | End-to-end encrypted | 154×16 | 12px · w500 · rgb(53, 37, 205) |
| 7 | `button` | — | 40×46 | r9999px |
| 8 | `generic` | more_vert | 24×24 | 24px · rgb(70, 69, 85) |
| 9 | `generic` | Today | 57×26 | 12px · w500 · rgb(70, 69, 85) · bg rgb(239, 244, 255) · r9999px |
| 10 | `generic` | The latest node synchronization is complete. Encryption keys have been rotated successfully across the mesh network. | 270×96 | rgb(11, 28, 48) |
| 11 | `generic` | 10:42 AM | 62×16 | 12px · w500 · rgb(70, 69, 85) |
| 12 | `generic` | Are you free to grab lunch tomorrow? | 272×48 | rgb(255, 255, 255) |
| 13 | `generic` | 10:45 AM | 62×16 | 12px · w500 · rgb(70, 69, 85) |
| 14 | `generic` | done_all | 16×16 | rgb(103, 244, 183) |
| 15 | `generic` | Sure, let's meet at 1pm at the usual place. | 270×48 | rgb(11, 28, 48) |
| 16 | `generic` | troubleshoot | 24×24 | 24px · rgb(0, 101, 145) |
| 17 | `generic` | Backup: Family Photos | 220×16 | 12px · w700 · rgb(11, 28, 48) |
| 18 | `generic` | In progress... 78% | 220×16 | 12px · w500 · rgb(70, 69, 85) |
| 19 | `generic` | 10:48 AM | 62×16 | 12px · w500 · rgb(70, 69, 85) |
| 20 | `generic` | Let me know when you're on your way. | 272×48 | rgb(255, 255, 255) |
| 21 | `generic` | 10:50 AM | 62×16 | 12px · w500 · rgb(70, 69, 85) |
| 22 | `generic` | done_all | 16×16 | rgb(70, 69, 85) |
| 23 | `generic` | I'll bring an umbrella just in case. | 266×24 | rgb(255, 255, 255) |
| 24 | `generic` | 10:51 AM | 62×16 | 12px · w500 · rgb(70, 69, 85) |
| 25 | `generic` | check | 16×16 | rgb(70, 69, 85) |
| 26 | `button` | — | 48×48 | r9999px |
| 27 | `generic` | add | 24×24 | 24px · rgb(53, 37, 205) |
| 28 | `textbox:multiline` | placeholder: Secure message... | 214×24 | — |
| 29 | `generic` | lock | 24×24 | 24px · rgb(53, 37, 205) |
| 30 | `button` | — | 48×48 | bg rgb(53, 37, 205) · r9999px |
| 31 | `generic` | mic | 24×24 | 24px · rgb(255, 255, 255) |

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

- `arrow_back`
- `Ahmed`
- `lock`
- `End-to-end encrypted`
- `more_vert`
- `Today`
- `The latest node synchronization is complete. Encryption keys have been rotated successfully across the mesh network.`
- `10:42 AM`
- `Are you free to grab lunch tomorrow?`
- `10:45 AM`
- `done_all`
- `Sure, let's meet at 1pm at the usual place.`
- `troubleshoot`
- `Backup: Family Photos`
- `In progress... 78%`
- `10:48 AM`
- `Let me know when you're on your way.`
- `10:50 AM`
- `I'll bring an umbrella just in case.`
- `10:51 AM`
- `check`
- `add`
- `mic`

<!-- ── generated above · hand-written below ────────────────────────────── -->

## Journey gaps
> States, flows or screens the SPEC requires that this design does not show.
> Fill from the BRD / SRS / feature list, keep consistent with the primitives
> above, log each one in `design/gaps.md`, and get 🧍 human approval before
> building. Do not invent silently.

- (none identified yet)

## Notes for the implementing agent
- (exact copy quirks, dynamic data, anything the probe cannot see)
