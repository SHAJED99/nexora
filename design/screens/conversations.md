---
id: conversations
impl_path: /conversations
source: ui
states: [default]
viewports: [390x844]
golden: design\golden\conversations\default@390x844/
elements: 57
generated_by: design/tools/contract.mjs
generated_at: 2026-08-26T10:52:48.635Z
---
# conversations · design contract

> **Generated — do not hand-edit the tables.** Regenerate with
> `make design-contract SCREEN=conversations` after the design changes.
> Hand-written sections at the bottom (Journey gaps, Notes) are preserved by you,
> not by the generator — keep them below the marker.
>
> **Rule 2 (design is law).** Every element below exists in the build, with that
> copy, character for character. The gate is `make design-verify SCREEN=conversations`
> — it fails on a missing element, changed copy, or an off-token style.
> Deliberate divergence goes in the task's §Deviations with its spec reason, and
> in `design/gaps.md`. Silence is not an option.

- **Route:** `/conversations`
- **Golden:** `design\golden\conversations\default@390x844/page.png` (screenshot) + `probe.json` (machine truth)
- **Captured:** 57 visible elements · 14 surfaces · 32 distinct strings
- **Page:** 390×844 viewport, 844px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
| text colour | `rgb(119, 117, 135)` | 11 |
| text colour | `rgb(70, 69, 85)` | 8 |
| text colour | `rgb(195, 192, 255)` | 6 |
| text colour | `rgb(11, 28, 48)` | 5 |
| text colour | `rgb(234, 241, 255)` | 2 |
| text colour | `rgb(255, 255, 255)` | 2 |
| surface / fill | `rgb(229, 238, 255)` | 5 |
| surface / fill | `rgb(33, 49, 69)` | 2 |
| surface / fill | `rgb(203, 219, 245)` | 2 |
| surface / fill | `rgb(0, 101, 145)` | 1 |
| surface / fill | `rgb(57, 184, 253)` | 1 |
| surface / fill | `rgb(53, 37, 205)` | 1 |
| border | `rgba(199, 196, 216, 0.1)` | 5 |
| border | `rgba(199, 196, 216, 0.2)` | 4 |
| border | `rgb(199, 196, 216)` | 1 |
| border | `rgb(229, 238, 255)` | 1 |
| font size | `24px` | 9 |
| font size | `12px` | 8 |
| font size | `16px` | 7 |
| font size | `14px` | 5 |
| font size | `20px` | 4 |
| font size | `22px` | 3 |
| font weight | `400` | 20 |
| font weight | `500` | 15 |
| font weight | `600` | 1 |
| font weight | `700` | 1 |
| radius | `8px` | 7 |
| radius | `9999px` | 5 |
| font family | `Material Symbols Outlined` | 16 |
| font family | `Inter` | 12 |
| font family | `JetBrains Mono` | 8 |
| font family | `Geist` | 1 |
| shadow | `rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.05) 0px 1px 2px 0px` | 1 |

## Elements — the build checklist

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| 1 | `button` | — | 48×48 | r9999px |
| 2 | `generic` | hub | 24×24 | 24px · rgb(195, 192, 255) |
| 3 | `heading:1` | NEXORA | 143×36 | 28px · w600 · rgb(195, 192, 255) |
| 4 | `button` | — | 48×48 | r9999px |
| 5 | `generic` | search | 24×24 | 24px · rgb(195, 192, 255) |
| 6 | `generic` | search | 24×24 | 24px · rgb(119, 117, 135) |
| 7 | `textbox:text` | placeholder: Search conversations... | 358×39 | 14px · bg rgb(229, 238, 255) · r8px |
| 8 | `heading:2` | Personal | 358×28 | 22px · w500 · rgb(234, 241, 255) |
| 9 | `image` | — | 46×46 | — |
| 10 | `generic` | Ahmed | 65×24 | w500 · rgb(11, 28, 48) |
| 11 | `generic` | 10:42 AM | 62×16 | 12px · w500 · rgb(70, 69, 85) |
| 12 | `generic` | check | 16×16 | rgb(78, 222, 163) |
| 13 | `generic` | Sounds good, see you then! | 191×20 | 14px · rgb(70, 69, 85) |
| 14 | `generic` | lock | 20×20 | 20px · rgb(195, 192, 255) |
| 15 | `generic` | MS | 35×28 | 22px · w500 · rgb(53, 37, 205) |
| 16 | `generic` | Rahim | 58×24 | w500 · rgb(11, 28, 48) |
| 17 | `generic` | Yesterday | 69×16 | 12px · w500 · rgb(70, 69, 85) |
| 18 | `generic` | check | 16×16 | rgb(119, 117, 135) |
| 19 | `generic` | Can you call me back? | 154×20 | 14px · rgb(70, 69, 85) |
| 20 | `generic` | lock | 20×20 | 20px · rgb(195, 192, 255) |
| 21 | `heading:2` | Groups | 358×28 | 22px · w500 · rgb(234, 241, 255) |
| 22 | `generic` | dns | 24×24 | 24px · rgb(0, 70, 102) |
| 23 | `generic` | Family | 61×24 | w500 · rgb(11, 28, 48) |
| 24 | `generic` | 08:15 AM | 62×16 | 12px · w500 · rgb(70, 69, 85) |
| 25 | `generic` | Don't forget dinner at 7! | 216×20 | 14px · rgb(70, 69, 85) |
| 26 | `generic` | David Chen: | 84×17 | 14px · w500 · rgb(11, 28, 48) |
| 27 | `generic` | lock | 20×20 | 20px · rgb(195, 192, 255) |
| 28 | `generic` | group_off | 24×24 | 24px · rgb(119, 117, 135) |
| 29 | `generic` | Work | 50×24 | w500 · rgb(11, 28, 48) |
| 30 | `generic` | Oct 12 | 46×16 | 12px · w500 · rgb(70, 69, 85) |
| 31 | `generic` | cloud_off | 16×16 | rgb(119, 117, 135) |
| 32 | `generic` | Thanks everyone for today! | 188×20 | 14px · rgb(70, 69, 85) |
| 33 | `generic` | lock | 20×20 | 20px · rgb(119, 117, 135) |
| 34 | `link` | — | 101×52 | r8px |
| 35 | `generic` | dashboard | 24×24 | 24px · rgb(119, 117, 135) |
| 36 | `generic` | Dashboard | 69×16 | 12px · w500 · rgb(119, 117, 135) |
| 37 | `link` | — | 148×52 | bg rgb(79, 70, 229) · r9999px |
| 38 | `generic` | chat | 24×24 | 24px · rgb(255, 255, 255) |
| 39 | `generic` | Conversations | 100×16 | 12px · w700 · rgb(255, 255, 255) |
| 40 | `link` | — | 86×52 | r8px |
| 41 | `generic` | router | 24×24 | 24px · rgb(119, 117, 135) |
| 42 | `generic` | Devices | 54×16 | 12px · w500 · rgb(119, 117, 135) |
| 43 | `link` | — | 94×52 | r8px |
| 44 | `generic` | settings | 24×24 | 24px · rgb(119, 117, 135) |
| 45 | `generic` | Settings | 62×16 | 12px · w500 · rgb(119, 117, 135) |

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

- `hub`
- `NEXORA`
- `search`
- `Personal`
- `Ahmed`
- `10:42 AM`
- `check`
- `Sounds good, see you then!`
- `lock`
- `MS`
- `Rahim`
- `Yesterday`
- `Can you call me back?`
- `Groups`
- `dns`
- `Family`
- `08:15 AM`
- `Don't forget dinner at 7!`
- `David Chen:`
- `group_off`
- `Work`
- `Oct 12`
- `cloud_off`
- `Thanks everyone for today!`
- `dashboard`
- `Dashboard`
- `chat`
- `Conversations`
- `router`
- `Devices`
- `settings`
- `Settings`

<!-- ── generated above · hand-written below ────────────────────────────── -->

## Journey gaps
> States, flows or screens the SPEC requires that this design does not show.
> Fill from the BRD / SRS / feature list, keep consistent with the primitives
> above, log each one in `design/gaps.md`, and get 🧍 human approval before
> building. Do not invent silently.

- (none identified yet)

## Notes for the implementing agent
- (exact copy quirks, dynamic data, anything the probe cannot see)
