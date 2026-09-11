---
id: settings
impl_path: /settings
source: derived
states: [default]
viewports: [390x844]
golden: design\golden\settings\default@390x844/
elements: 30
generated_by: design/tools/contract.mjs
generated_at: 2026-09-11T14:32:35.522Z
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
- **Captured:** 30 visible elements · 22 surfaces · 16 distinct strings
- **Page:** 390×844 viewport, 844px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
| text colour | `rgb(195, 192, 255)` | 1 |
| text colour | `rgb(234, 241, 255)` | 1 |
| text colour | `rgb(199, 196, 216)` | 1 |
| surface / fill | `rgb(33, 49, 69)` | 6 |
| surface / fill | `rgb(26, 44, 66)` | 4 |
| surface / fill | `rgb(0, 33, 19)` | 4 |
| surface / fill | `rgb(15, 0, 105)` | 4 |
| surface / fill | `rgb(0, 30, 47)` | 2 |
| surface / fill | `rgb(11, 28, 48)` | 1 |
| border | `rgba(199, 196, 216, 0.102)` | 5 |
| font size | `28px` | 2 |
| font size | `14px` | 1 |
| font weight | `600` | 2 |
| font weight | `400` | 1 |
| radius | `174px` | 8 |
| radius | `24px` | 8 |
| radius | `12px` | 4 |
| radius | `9999px` | 1 |
| font family | `Roboto` | 2 |
| font family | `Geist` | 1 |

## Elements — the build checklist

| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| 1 | `generic` | hub | 24×24 | 24px · rgb(195, 192, 255) |
| 2 | `heading:1` | NEXORA | 170×40 | 28px · w600 · rgb(195, 192, 255) |
| 3 | `generic` | lock | 24×24 | 24px · rgb(195, 192, 255) |
| 4 | `heading:1` | Settings | 226×40 | 28px · w600 · rgb(234, 241, 255) |
| 5 | `generic` | Manage your secure connection preferences and device configurations. | 350×80 | 14px · rgb(199, 196, 216) |
| 6 | `button` | Account Profile, identity keys, linked devices | 348×125 | 22px · w500 · rgb(248, 249, 255) · bg rgb(0, 30, 47) · r174px |
| 7 | `button` | Privacy & Security Encryption protocols, app lock, permissions | 348×176 | 22px · w500 · rgb(248, 249, 255) · bg rgb(0, 33, 19) · r174px |
| 8 | `button` | Security Center Threat logs, network audits, certificates | 348×156 | 22px · w500 · rgb(248, 249, 255) · bg rgb(0, 33, 19) · r174px |
| 9 | `button` | Network Data usage, mesh routing, proxy | 348×125 | 22px · w500 · rgb(248, 249, 255) · bg rgb(15, 0, 105) · r174px |
| 10 | `button` | Storage Local cache, message retention, export | 348×145 | 22px · w500 · rgb(248, 249, 255) · bg rgb(15, 0, 105) · r174px |
| 11 | `button` | Battery Background execution, power saving modes | 348×145 | 22px · w500 · rgb(248, 249, 255) · bg rgb(33, 49, 69) · r174px |
| 12 | `button` | Notifications Alerts, silent modes, LED behaviors | 348×156 | 22px · w500 · rgb(248, 249, 255) · bg rgb(33, 49, 69) · r174px |
| 13 | `button` | About / Updates Version 2.4.1, release notes, diagnostic logs | 348×156 | 22px · w500 · rgb(248, 249, 255) · bg rgb(33, 49, 69) · r174px |
| 14 | `button` | Dashboard | 92×72 | 12px · w500 · rgb(199, 196, 216) |
| 15 | `button` | Conversations | 92×89 | 12px · w500 · rgb(199, 196, 216) |
| 16 | `button` | Devices | 92×72 | 12px · w500 · rgb(199, 196, 216) |
| 17 | `button` | Settings | 92×72 | 12px · w500 · rgb(218, 215, 255) · bg rgb(79, 70, 229) · r9999px |

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

- `hub`
- `NEXORA`
- `lock`
- `Settings`
- `Manage your secure connection preferences and device configurations.`
- `Account Profile, identity keys, linked devices`
- `Privacy & Security Encryption protocols, app lock, permissions`
- `Security Center Threat logs, network audits, certificates`
- `Network Data usage, mesh routing, proxy`
- `Storage Local cache, message retention, export`
- `Battery Background execution, power saving modes`
- `Notifications Alerts, silent modes, LED behaviors`
- `About / Updates Version 2.4.1, release notes, diagnostic logs`
- `Dashboard`
- `Conversations`
- `Devices`

<!-- ── generated above · hand-written below ────────────────────────────── -->

## Journey gaps
> States, flows or screens the SPEC requires that this design does not show.
> Fill from the BRD / SRS / feature list, keep consistent with the primitives
> above, log each one in `design/gaps.md`, and get 🧍 human approval before
> building. Do not invent silently.

- (none identified yet)

## Notes for the implementing agent
- (exact copy quirks, dynamic data, anything the probe cannot see)
- **Provenance (E15-T13, 2026-09-11):** this contract's golden was
  originally extracted from the HTML design source (`source: ui`,
  genesis, 2026-08-26) via a DOM walk — 74 elements, including HTML-only
  wrapper roles (`generic <body>`, `generic <header>`) and `<button>` DOM
  nodes that a Flutter `Scaffold`-scoped widget-tree walk has no
  equivalent for (`docs/design-gate-flutter.md §6`). It was never
  compared against a real Flutter build until `E15-T11` added this
  screen's first-ever probe block, and `--impl flutter` read 33.8%
  (25/74) as a result — a stale-golden problem, not a shipped-UI defect;
  the hub's actual appearance and behavior were confirmed correct across
  two independent E15-T11 reviews.
  `E15-T13` re-extracted the golden straight from that same probe block's
  fresh dump (`flutter test test/design/design_probe_test.dart` →
  `build/design-probe/settings.json`, copied verbatim to
  `probe.json`), then regenerated this contract with
  `node design/tools/contract.mjs --screen settings` — 30 elements now
  (widget-tree granularity groups each settings row into one tappable
  `button` carrying its own title+subtitle text, rather than the HTML
  walk's separate title/subtitle/chevron nodes), matching how every one
  of this epic's nine settings sub-screens already documents its own
  contract as `source: derived`. `design-verify SCREEN=settings
  --impl flutter` now reads 100% (30/30) with zero missing, re-roled,
  copy, style or layout findings — see
  `design/reports/settings/default@390x844/report.md`.
  `source: ui` → `source: derived` in this file's frontmatter reflects
  that the golden the gate checks against is now derived from the shipped
  Flutter build rather than the original HTML mockup.
