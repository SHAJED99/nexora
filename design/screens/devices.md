---
id: devices
impl_path: /devices
source: ui
states: [default]
viewports: [390x844]
golden: design\golden\devices\default@390x844/
elements: 61
generated_by: design/tools/contract.mjs
generated_at: 2026-08-26T10:52:48.637Z
---
# devices · design contract

> **Generated — do not hand-edit the tables.** Regenerate with
> `make design-contract SCREEN=devices` after the design changes.
> Hand-written sections at the bottom (Journey gaps, Notes) are preserved by you,
> not by the generator — keep them below the marker.
>
> **Rule 2 (design is law).** Every element below exists in the build, with that
> copy, character for character. The gate is `make design-verify SCREEN=devices`
> — it fails on a missing element, changed copy, or an off-token style.
> Deliberate divergence goes in the task's §Deviations with its spec reason, and
> in `design/gaps.md`. Silence is not an option.

- **Route:** `/devices`
- **Golden:** `design\golden\devices\default@390x844/page.png` (screenshot) + `probe.json` (machine truth)
- **Captured:** 61 visible elements · 12 surfaces · 38 distinct strings
- **Page:** 390×844 viewport, 993px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
| text colour | `rgb(70, 69, 85)` | 14 |
| text colour | `rgb(11, 28, 48)` | 5 |
| text colour | `rgb(119, 117, 135)` | 5 |
| text colour | `rgb(195, 192, 255)` | 4 |
| text colour | `rgb(137, 206, 255)` | 3 |
| text colour | `rgb(186, 26, 26)` | 3 |
| surface / fill | `rgba(239, 244, 255, 0.1)` | 4 |
| surface / fill | `rgb(33, 49, 69)` | 1 |
| surface / fill | `rgb(53, 37, 205)` | 1 |
| surface / fill | `rgba(79, 70, 229, 0.2)` | 1 |
| surface / fill | `rgba(57, 184, 253, 0.2)` | 1 |
| surface / fill | `rgba(211, 228, 254, 0.2)` | 1 |
| border | `rgba(199, 196, 216, 0.1)` | 5 |
| font size | `24px` | 14 |
| font size | `12px` | 9 |
| font size | `16px` | 8 |
| font size | `11px` | 8 |
| font size | `28px` | 1 |
| font size | `22px` | 1 |
| font weight | `400` | 28 |
| font weight | `500` | 14 |
| font weight | `600` | 1 |
| radius | `9999px` | 5 |
| radius | `12px` | 4 |
| radius | `8px` | 1 |
| font family | `Material Symbols Outlined` | 19 |
| font family | `JetBrains Mono` | 17 |
| font family | `Inter` | 6 |
| font family | `Geist` | 1 |

## Elements — the build checklist

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| 1 | `generic` | hub | 24×24 | 24px · rgb(195, 192, 255) |
| 2 | `heading:1` | NEXORA | 111×36 | 28px · w600 · rgb(195, 192, 255) |
| 3 | `generic` | lock | 24×24 | 24px · rgb(195, 192, 255) |
| 4 | `heading:2` | Network Nodes | 242×28 | 22px · w500 · rgb(11, 28, 48) |
| 5 | `generic` | Manage paired and nearby devices. | 242×40 | 14px · rgb(70, 69, 85) |
| 6 | `button` | Discover | 116×34 | 12px · w500 · rgb(255, 255, 255) · bg rgb(53, 37, 205) · r8px |
| 7 | `generic` | search | 18×18 | 18px · rgb(255, 255, 255) |
| 8 | `generic` | laptop_mac | 24×24 | 24px · rgb(195, 192, 255) |
| 9 | `heading:3` | Ahmed's Laptop | 131×24 | w500 · rgb(11, 28, 48) |
| 10 | `generic` | Wi-Fi Direct | 131×16 | 11px · rgb(70, 69, 85) |
| 11 | `button` | — | 24×30 | — |
| 12 | `generic` | more_vert | 24×24 | 24px · rgb(119, 117, 135) |
| 13 | `generic` | check_circle | 16×16 | rgb(78, 222, 163) |
| 14 | `generic` | Trusted Node | 92×16 | 12px · w500 · rgb(78, 222, 163) |
| 15 | `generic` | Last seen: Just now | 125×16 | 11px · rgb(70, 69, 85) |
| 16 | `generic` | smartphone | 24×24 | 24px · rgb(137, 206, 255) |
| 17 | `heading:3` | Rahim's Phone | 119×24 | w500 · rgb(11, 28, 48) |
| 18 | `generic` | Bluetooth LE | 119×16 | 11px · rgb(70, 69, 85) |
| 19 | `button` | — | 24×30 | — |
| 20 | `generic` | more_vert | 24×24 | 24px · rgb(119, 117, 135) |
| 21 | `generic` | radio_button_checked | 16×16 | rgb(137, 206, 255) |
| 22 | `generic` | Allowed | 54×16 | 12px · w500 · rgb(137, 206, 255) |
| 23 | `generic` | Last seen: 2m ago | 112×16 | 11px · rgb(70, 69, 85) |
| 24 | `generic` | router | 24×24 | 24px · rgb(119, 117, 135) |
| 25 | `heading:3` | Unknown Device | 135×24 | w500 · rgb(11, 28, 48) |
| 26 | `generic` | Mesh Proximity | 135×16 | 11px · rgb(70, 69, 85) |
| 27 | `button` | — | 24×30 | — |
| 28 | `generic` | more_vert | 24×24 | 24px · rgb(119, 117, 135) |
| 29 | `generic` | warning | 16×16 | rgb(245, 158, 11) |
| 30 | `generic` | Unknown | 54×16 | 12px · w500 · rgb(245, 158, 11) |
| 31 | `button` | Verify | 56×24 | 11px · rgb(53, 37, 205) · r4px |
| 32 | `generic` | desktop_windows | 24×24 | 24px · rgb(186, 26, 26) |
| 33 | `heading:3` | Old Tablet | 82×24 | w500 · rgb(11, 28, 48) |
| 34 | `generic` | Wi-Fi Direct | 82×16 | 11px · rgb(70, 69, 85) |
| 35 | `button` | — | 24×30 | — |
| 36 | `generic` | more_vert | 24×24 | 24px · rgb(119, 117, 135) |
| 37 | `generic` | block | 16×16 | rgb(186, 26, 26) |
| 38 | `generic` | Blocked | 54×16 | 12px · w500 · rgb(186, 26, 26) |
| 39 | `generic` | Last seen: 5d ago | 112×16 | 11px · rgb(70, 69, 85) |
| 40 | `link` | — | 101×52 | r8px |
| 41 | `generic` | dashboard | 24×24 | 24px · rgb(70, 69, 85) |
| 42 | `generic` | Dashboard | 69×16 | 12px · w500 · rgb(70, 69, 85) |
| 43 | `link` | — | 132×52 | r8px |
| 44 | `generic` | chat | 24×24 | 24px · rgb(70, 69, 85) |
| 45 | `generic` | Conversations | 100×16 | 12px · w500 · rgb(70, 69, 85) |
| 46 | `link` | — | 86×52 | bg rgb(79, 70, 229) · r9999px |
| 47 | `generic` | router | 24×24 | 24px · rgb(218, 215, 255) |
| 48 | `generic` | Devices | 54×16 | 12px · w500 · rgb(218, 215, 255) |
| 49 | `link` | — | 94×52 | r8px |
| 50 | `generic` | settings | 24×24 | 24px · rgb(70, 69, 85) |
| 51 | `generic` | Settings | 62×16 | 12px · w500 · rgb(70, 69, 85) |

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

- `hub`
- `NEXORA`
- `lock`
- `Network Nodes`
- `Manage paired and nearby devices.`
- `Discover`
- `search`
- `laptop_mac`
- `Ahmed's Laptop`
- `Wi-Fi Direct`
- `more_vert`
- `check_circle`
- `Trusted Node`
- `Last seen: Just now`
- `smartphone`
- `Rahim's Phone`
- `Bluetooth LE`
- `radio_button_checked`
- `Allowed`
- `Last seen: 2m ago`
- `router`
- `Unknown Device`
- `Mesh Proximity`
- `warning`
- `Unknown`
- `Verify`
- `desktop_windows`
- `Old Tablet`
- `block`
- `Blocked`
- `Last seen: 5d ago`
- `dashboard`
- `Dashboard`
- `chat`
- `Conversations`
- `Devices`
- `settings`
- `Settings`

<!-- ── generated above · hand-written below ────────────────────────────── -->

## Journey gaps
> States, flows or screens the SPEC requires that this design does not show.
> Fill from the BRD / SRS / feature list, keep consistent with the primitives
> above, log each one in `design/gaps.md`, and get 🧍 human approval before
> building. Do not invent silently.

- **GAP-028 (E12, `FR-RECOVER-001`)** — a pending new-device enrollment
  request has no row here. Proposed: a new row at the top of this list,
  reusing this screen's own status-chip + trailing-button treatment
  (the `Unknown`/`Verify` row is the closest existing shape), with
  `Approve`/`Deny` in place of the single `Verify` action — full
  derivation in `design/gaps.md` GAP-028 and the new
  `design/screens/device-enrollment-approval.md` contract. ✅ approved
  (human, 2026-09-05) — not yet built.

## Notes for the implementing agent
- (exact copy quirks, dynamic data, anything the probe cannot see)
