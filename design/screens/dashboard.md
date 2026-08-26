---
id: dashboard
impl_path: /dashboard
source: ui
states: [default]
viewports: [390x844]
golden: design\golden\dashboard\default@390x844/
elements: 63
generated_by: design/tools/contract.mjs
generated_at: 2026-08-26T10:52:48.634Z
---
# dashboard · design contract

> **Generated — do not hand-edit the tables.** Regenerate with
> `make design-contract SCREEN=dashboard` after the design changes.
> Hand-written sections at the bottom (Journey gaps, Notes) are preserved by you,
> not by the generator — keep them below the marker.
>
> **Rule 2 (design is law).** Every element below exists in the build, with that
> copy, character for character. The gate is `make design-verify SCREEN=dashboard`
> — it fails on a missing element, changed copy, or an off-token style.
> Deliberate divergence goes in the task's §Deviations with its spec reason, and
> in `design/gaps.md`. Silence is not an option.

- **Route:** `/dashboard`
- **Golden:** `design\golden\dashboard\default@390x844/page.png` (screenshot) + `probe.json` (machine truth)
- **Captured:** 63 visible elements · 18 surfaces · 37 distinct strings
- **Page:** 390×844 viewport, 844px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
| text colour | `rgb(70, 69, 85)` | 22 |
| text colour | `rgb(11, 28, 48)` | 7 |
| text colour | `rgb(53, 37, 205)` | 4 |
| text colour | `rgb(0, 83, 56)` | 3 |
| text colour | `rgb(218, 215, 255)` | 2 |
| text colour | `rgb(0, 101, 145)` | 1 |
| surface / fill | `rgb(248, 249, 255)` | 5 |
| surface / fill | `rgb(239, 244, 255)` | 5 |
| surface / fill | `rgb(211, 228, 254)` | 4 |
| surface / fill | `rgb(229, 238, 255)` | 2 |
| surface / fill | `rgb(53, 37, 205)` | 1 |
| surface / fill | `rgb(79, 70, 229)` | 1 |
| border | `rgba(11, 28, 48, 0.1)` | 5 |
| border | `rgba(11, 28, 48, 0.05)` | 1 |
| border | `rgba(199, 196, 216, 0.1)` | 1 |
| font size | `12px` | 12 |
| font size | `14px` | 9 |
| font size | `24px` | 7 |
| font size | `16px` | 4 |
| font size | `22px` | 3 |
| font size | `18px` | 3 |
| font weight | `500` | 20 |
| font weight | `400` | 18 |
| font weight | `600` | 1 |
| radius | `9999px` | 7 |
| radius | `8px` | 6 |
| radius | `12px` | 2 |
| font family | `Material Symbols Outlined` | 14 |
| font family | `Inter` | 12 |
| font family | `JetBrains Mono` | 12 |
| font family | `Geist` | 1 |

## Elements — the build checklist

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| 1 | `generic` | hub | 24×24 | 24px · rgb(53, 37, 205) |
| 2 | `heading:1` | NEXORA | 111×36 | 28px · w600 · rgb(53, 37, 205) |
| 3 | `button` | — | 48×48 | r9999px |
| 4 | `generic` | lock | 24×24 | 24px · rgb(53, 37, 205) |
| 5 | `heading:2` | Network Status | 177×28 | 22px · w500 · rgb(11, 28, 48) |
| 6 | `generic` | Primary Node Connection | 177×16 | 12px · w500 · rgb(70, 69, 85) |
| 7 | `generic` | circle | 16×16 | rgb(0, 101, 145) |
| 8 | `generic` | Connected | 69×16 | 12px · w500 · rgb(11, 28, 48) |
| 9 | `generic` | lock | 18×18 | 18px · rgb(0, 83, 56) |
| 10 | `generic` | Encryption | 77×16 | 12px · w500 · rgb(0, 83, 56) |
| 11 | `generic` | Secure | 142×20 | 14px · w500 · rgb(70, 69, 85) |
| 12 | `generic` | speed | 18×18 | 18px · rgb(70, 69, 85) |
| 13 | `generic` | Latency | 54×16 | 12px · w500 · rgb(70, 69, 85) |
| 14 | `generic` | 24ms | 142×20 | 14px · w500 · rgb(70, 69, 85) |
| 15 | `heading:3` | Local Storage | 145×28 | 22px · w500 · rgb(11, 28, 48) |
| 16 | `generic` | 45% used | 69×20 | 14px · rgb(70, 69, 85) |
| 17 | `generic` | warning | 18×18 | 18px · rgb(70, 69, 85) |
| 18 | `generic` | Smart Mode - Older than 10 days | 239×16 | 12px · w500 · rgb(70, 69, 85) |
| 19 | `heading:3` | Recent Conversations | 358×28 | 22px · w500 · rgb(11, 28, 48) |
| 20 | `image` | — | 48×48 | — |
| 21 | `generic` | Family | 53×24 | w500 · rgb(11, 28, 48) |
| 22 | `generic` | 12:45 | 39×16 | 12px · w500 · rgb(70, 69, 85) |
| 23 | `generic` | check_circle | 14×14 | 14px · rgb(0, 83, 56) |
| 24 | `generic` | See you at 7pm! | 110×20 | 14px · rgb(70, 69, 85) |
| 25 | `image` | — | 48×48 | — |
| 26 | `generic` | Rahim | 50×24 | w500 · rgb(11, 28, 48) |
| 27 | `generic` | Yesterday | 69×16 | 12px · w500 · rgb(70, 69, 85) |
| 28 | `generic` | lock | 14×14 | 14px · rgb(53, 37, 205) |
| 29 | `generic` | Got your message, thanks! | 183×20 | 14px · rgb(70, 69, 85) |
| 30 | `generic` | person | 24×24 | 24px · rgb(70, 69, 85) |
| 31 | `generic` | Ahmed | 57×24 | w500 · rgb(11, 28, 48) |
| 32 | `generic` | Oct 12 | 46×16 | 12px · w500 · rgb(70, 69, 85) |
| 33 | `generic` | radio_button_unchecked | 14×14 | 14px · rgb(70, 69, 85) |
| 34 | `generic` | Message queued — will send when connected. | 258×20 | 14px · rgb(70, 69, 85) |
| 35 | `button` | — | 101×52 | bg rgb(79, 70, 229) · r9999px |
| 36 | `generic` | dashboard | 24×24 | 24px · rgb(218, 215, 255) |
| 37 | `generic` | Dashboard | 69×16 | 12px · w500 · rgb(218, 215, 255) |
| 38 | `button` | — | 132×52 | r9999px |
| 39 | `generic` | chat | 24×24 | 24px · rgb(70, 69, 85) |
| 40 | `generic` | Conversations | 100×16 | 12px · w500 · rgb(70, 69, 85) |
| 41 | `button` | — | 86×52 | r9999px |
| 42 | `generic` | router | 24×24 | 24px · rgb(70, 69, 85) |
| 43 | `generic` | Devices | 54×16 | 12px · w500 · rgb(70, 69, 85) |
| 44 | `button` | — | 94×52 | r9999px |
| 45 | `generic` | settings | 24×24 | 24px · rgb(70, 69, 85) |
| 46 | `generic` | Settings | 62×16 | 12px · w500 · rgb(70, 69, 85) |

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

- `hub`
- `NEXORA`
- `lock`
- `Network Status`
- `Primary Node Connection`
- `circle`
- `Connected`
- `Encryption`
- `Secure`
- `speed`
- `Latency`
- `24ms`
- `Local Storage`
- `45% used`
- `warning`
- `Smart Mode - Older than 10 days`
- `Recent Conversations`
- `Family`
- `12:45`
- `check_circle`
- `See you at 7pm!`
- `Rahim`
- `Yesterday`
- `Got your message, thanks!`
- `person`
- `Ahmed`
- `Oct 12`
- `radio_button_unchecked`
- `Message queued — will send when connected.`
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
