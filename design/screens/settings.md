---
id: settings
impl_path: /settings
source: ui
states: [default]
viewports: [390x844]
golden: design\golden\settings\default@390x844/
elements: 74
generated_by: design/tools/contract.mjs
generated_at: 2026-08-26T10:52:48.638Z
---
# settings · design contract

> **Generated — do not hand-edit the tables.** Regenerate with
> `make design-contract SCREEN=settings` after the design changes.
> Hand-written sections at the bottom (Journey gaps, Notes) are preserved by you,
> not by the generator — keep them below the marker.
>
> **Rule 2 (design is law).** Every element below exists in the build, with that
> copy, character for character. The gate is `make design-verify SCREEN=settings`
> — it fails on a missing element, changed copy, or an off-token style.
> Deliberate divergence goes in the task's §Deviations with its spec reason, and
> in `design/gaps.md`. Silence is not an option.

- **Route:** `/settings`
- **Golden:** `design\golden\settings\default@390x844/page.png` (screenshot) + `probe.json` (machine truth)
- **Captured:** 74 visible elements · 20 surfaces · 37 distinct strings
- **Page:** 390×844 viewport, 1205px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
| text colour | `rgb(199, 196, 216)` | 15 |
| text colour | `rgb(248, 249, 255)` | 8 |
| text colour | `rgb(119, 117, 135)` | 8 |
| text colour | `rgb(195, 192, 255)` | 5 |
| text colour | `rgb(220, 233, 255)` | 3 |
| text colour | `rgb(103, 244, 183)` | 2 |
| surface / fill | `rgb(26, 44, 66)` | 4 |
| surface / fill | `rgb(11, 28, 48)` | 3 |
| surface / fill | `rgb(33, 49, 69)` | 3 |
| surface / fill | `rgb(0, 33, 19)` | 2 |
| surface / fill | `rgb(15, 0, 105)` | 2 |
| surface / fill | `rgb(0, 30, 47)` | 1 |
| border | `rgba(199, 196, 216, 0.1)` | 5 |
| font size | `24px` | 22 |
| font size | `14px` | 9 |
| font size | `22px` | 8 |
| font size | `12px` | 4 |
| font size | `28px` | 2 |
| font weight | `400` | 31 |
| font weight | `500` | 12 |
| font weight | `600` | 2 |
| radius | `9999px` | 9 |
| radius | `12px` | 4 |
| font family | `Material Symbols Outlined` | 22 |
| font family | `Inter` | 17 |
| font family | `JetBrains Mono` | 4 |
| font family | `Geist` | 2 |

## Elements — the build checklist

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| 1 | `button` | — | 40×40 | r9999px |
| 2 | `generic` | hub | 24×24 | 24px · rgb(195, 192, 255) |
| 3 | `heading:1` | NEXORA | 111×36 | 28px · w600 · rgb(195, 192, 255) |
| 4 | `button` | — | 40×40 | r9999px |
| 5 | `generic` | lock | 24×24 | 24px · rgb(195, 192, 255) |
| 6 | `heading:2` | Settings | 358×36 | 28px · w600 · rgb(234, 241, 255) |
| 7 | `generic` | Manage your secure connection preferences and device configurations. | 358×40 | 14px · rgb(199, 196, 216) |
| 8 | `button` | — | 356×104 | — |
| 9 | `generic` | account_circle | 24×24 | 24px · rgb(137, 206, 255) |
| 10 | `heading:3` | Account | 236×28 | 22px · w500 · rgb(248, 249, 255) |
| 11 | `generic` | Profile, identity keys, linked devices | 236×40 | 14px · rgb(199, 196, 216) |
| 12 | `generic` | chevron_right | 24×24 | 24px · rgb(119, 117, 135) |
| 13 | `button` | — | 356×105 | — |
| 14 | `generic` | security | 24×24 | 24px · rgb(103, 244, 183) |
| 15 | `heading:3` | Privacy & Security | 236×28 | 22px · w500 · rgb(248, 249, 255) |
| 16 | `generic` | Encryption protocols, app lock, permissions | 236×40 | 14px · rgb(199, 196, 216) |
| 17 | `generic` | chevron_right | 24×24 | 24px · rgb(119, 117, 135) |
| 18 | `button` | — | 356×104 | — |
| 19 | `generic` | policy | 24×24 | 24px · rgb(103, 244, 183) |
| 20 | `heading:3` | Security Center | 236×28 | 22px · w500 · rgb(248, 249, 255) |
| 21 | `generic` | Threat logs, network audits, certificates | 236×40 | 14px · rgb(199, 196, 216) |
| 22 | `generic` | chevron_right | 24×24 | 24px · rgb(119, 117, 135) |
| 23 | `button` | — | 356×85 | — |
| 24 | `generic` | wifi_tethering | 24×24 | 24px · rgb(195, 192, 255) |
| 25 | `heading:3` | Network | 236×28 | 22px · w500 · rgb(248, 249, 255) |
| 26 | `generic` | Data usage, mesh routing, proxy | 236×20 | 14px · rgb(199, 196, 216) |
| 27 | `generic` | chevron_right | 24×24 | 24px · rgb(119, 117, 135) |
| 28 | `button` | — | 356×104 | — |
| 29 | `generic` | sd_storage | 24×24 | 24px · rgb(195, 192, 255) |
| 30 | `heading:3` | Storage | 236×28 | 22px · w500 · rgb(248, 249, 255) |
| 31 | `generic` | Local cache, message retention, export | 236×40 | 14px · rgb(199, 196, 216) |
| 32 | `generic` | chevron_right | 24×24 | 24px · rgb(119, 117, 135) |
| 33 | `button` | — | 356×105 | — |
| 34 | `generic` | battery_full_alt | 24×24 | 24px · rgb(220, 233, 255) |
| 35 | `heading:3` | Battery | 236×28 | 22px · w500 · rgb(248, 249, 255) |
| 36 | `generic` | Background execution, power saving modes | 236×40 | 14px · rgb(199, 196, 216) |
| 37 | `generic` | chevron_right | 24×24 | 24px · rgb(119, 117, 135) |
| 38 | `button` | — | 356×105 | — |
| 39 | `generic` | notifications | 24×24 | 24px · rgb(220, 233, 255) |
| 40 | `heading:3` | Notifications | 236×28 | 22px · w500 · rgb(248, 249, 255) |
| 41 | `generic` | Alerts, silent modes, LED behaviors | 236×40 | 14px · rgb(199, 196, 216) |
| 42 | `generic` | chevron_right | 24×24 | 24px · rgb(119, 117, 135) |
| 43 | `button` | — | 356×104 | — |
| 44 | `generic` | info | 24×24 | 24px · rgb(220, 233, 255) |
| 45 | `heading:3` | About / Updates | 236×28 | 22px · w500 · rgb(248, 249, 255) |
| 46 | `generic` | Version 2.4.1, release notes, diagnostic logs | 236×40 | 14px · rgb(199, 196, 216) |
| 47 | `generic` | chevron_right | 24×24 | 24px · rgb(119, 117, 135) |
| 48 | `button` | — | 101×52 | r8px |
| 49 | `generic` | dashboard | 24×24 | 24px · rgb(199, 196, 216) |
| 50 | `generic` | Dashboard | 69×16 | 12px · w500 · rgb(199, 196, 216) |
| 51 | `button` | — | 132×52 | r8px |
| 52 | `generic` | chat | 24×24 | 24px · rgb(199, 196, 216) |
| 53 | `generic` | Conversations | 100×16 | 12px · w500 · rgb(199, 196, 216) |
| 54 | `button` | — | 86×52 | r8px |
| 55 | `generic` | router | 24×24 | 24px · rgb(199, 196, 216) |
| 56 | `generic` | Devices | 54×16 | 12px · w500 · rgb(199, 196, 216) |
| 57 | `button` | — | 94×52 | bg rgb(79, 70, 229) · r9999px |
| 58 | `generic` | settings | 24×24 | 24px · rgb(218, 215, 255) |
| 59 | `generic` | Settings | 62×16 | 12px · w500 · rgb(218, 215, 255) |

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

- `hub`
- `NEXORA`
- `lock`
- `Settings`
- `Manage your secure connection preferences and device configurations.`
- `account_circle`
- `Account`
- `Profile, identity keys, linked devices`
- `chevron_right`
- `security`
- `Privacy & Security`
- `Encryption protocols, app lock, permissions`
- `policy`
- `Security Center`
- `Threat logs, network audits, certificates`
- `wifi_tethering`
- `Network`
- `Data usage, mesh routing, proxy`
- `sd_storage`
- `Storage`
- `Local cache, message retention, export`
- `battery_full_alt`
- `Battery`
- `Background execution, power saving modes`
- `notifications`
- `Notifications`
- `Alerts, silent modes, LED behaviors`
- `info`
- `About / Updates`
- `Version 2.4.1, release notes, diagnostic logs`
- `dashboard`
- `Dashboard`
- `chat`
- `Conversations`
- `router`
- `Devices`
- `settings`

<!-- ── generated above · hand-written below ────────────────────────────── -->

## Journey gaps
> States, flows or screens the SPEC requires that this design does not show.
> Fill from the BRD / SRS / feature list, keep consistent with the primitives
> above, log each one in `design/gaps.md`, and get 🧍 human approval before
> building. Do not invent silently.

- (none identified yet)

## Notes for the implementing agent
- (exact copy quirks, dynamic data, anything the probe cannot see)
