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

- **`GAP-011`** — the Local Storage card had no data source until E08.
  Approved 2026-08-29, built by `E06-T08` with disclosed placeholders. E08
  supplies the real figures.
- **`GAP-012`** — `FR-UI-004`'s "one tap away" detail destination. Approved
  2026-08-29 (the Network Status card navigates to `/devices`), built by
  `E06-T08`.
- **`GAP-013`** — the disconnected / degraded Network Status variants.
  Approved 2026-08-29, built by `E06-T08`.
- **`GAP-025`** — **the storage warning has no expanded state.**
  `FR-STORE-007` requires that expanding a warning shows the decisions the
  active policy made and explains why; the design draws only the collapsed
  card (elements 15-18). The derived state is contracted immediately below.
  🟡 **proposed, not approved.**
- **`GAP-026`** — `45% used` (element 16) has no denominator. A fork with no
  proposal; see below and `design/gaps.md`.

<!-- ── Derived state, hand-written by E08-T07 (2026-09-02) against GAP-025.
     The generated tables above are BYTE-UNCHANGED (design-fidelity rule 1 —
     a generated table is never hand-edited). Everything below the marker is
     the hand-written half this contract's own header says is preserved by a
     person, not by the generator. ── -->

## Derived state — `warning-expanded` (`GAP-025`, `FR-STORE-007`)

> **`source: derived` for this state only.** The frontmatter's
> `states: [default]` describes what the design source *measured*; this
> section adds a state the source never drew. It is **not** part of the golden
> and **cannot be gated by `make design-verify SCREEN=dashboard`** until the
> build exists and a second golden is extracted — the same standing
> `group-create.md` and `group-manage.md` record. `E08-T08`'s reviewer should
> expect the expanded state to be invisible to the gate, and should read the
> collapsed card's rows against the generated table as usual.
>
> **Built against `GAP-025`, which is 🟡 proposed and NOT approved.** Its
> `approved by:` line in `design/gaps.md` is deliberately bare
> (`L-process-002`). This section is the proposal the human reads at the
> 🧍 `design_contract_approval` gate; an agent does not approve it.

### What this state is, and what it is not

Tapping the Local Storage card **toggles an expansion in place**. It is not a
navigation, not a dialog, not a bottom sheet — the design draws no dialog or
sheet primitive anywhere, and inventing one would be inventing a visual
language (rule 2). The card grows downward and the page scrolls.

**Expanding runs nothing, applies nothing and deletes nothing** —
`EARS-STORE-2` and `FR-STORE-006`. There is **no `Clean Now` button, no
apply-now, no confirmation prompt and no delete affordance, not even a
disabled one**, in either state of this card. `FR-STORE-006` says in as many
words that the user does not need to press one. This paragraph is in the
contract rather than only in the task that wrote it because the next person to
touch this card inherits it.

**No new affordance glyph is drawn for the expansion.** `GAP-012` already
established this screen's precedent: a card becomes a tap target without
acquiring a chevron. `dashboard.md` measures no expand/collapse glyph, and
borrowing `settings.md`'s `chevron_right` would promise navigation, which this
is not.

### The collapsed card, once E08 feeds it (`GAP-011` closing, `GAP-026`)

Elements 15-18 keep their measured styling exactly. Two of their four strings
become data:

| element | measured copy | what it becomes | why |
|---|---|---|---|
| 15 `Local Storage` | unchanged | unchanged | — |
| 16 `45% used` | **`N MB used`** — the real measured byte total | `OQ-E08-1` answered by the human on 2026-09-02: **(c)** for the card — real measured bytes, **no fabricated percentage**. `storage_policy_settings.budget_bytes` is NULL, so there is no denominator to divide by. This is `GAP-026`'s disclosed deviation, recorded there | `FR-STORE-006` |
| 17 `warning` | unchanged | rendered **only when the plan carries a warning condition**; absent otherwise | `FR-STORE-006` ("when appropriate") |
| 18 `Smart Mode - Older than 10 days` | **the active policy's real summary** — mode plus its actual parameter, in the measured string's own `<Mode> - <parameter>` shape | `GAP-011`'s approved resolution: static copy "until E08 builds the retention policy it describes". E08 has built it | `FR-STORE-004` |

The `45% used` and `Smart Mode - Older than 10 days` strings will therefore be
reported by the gate as **copy findings**. Both trace here and to `GAP-011` /
`GAP-026`, per `design-fidelity` §6. Neither is a silent rewrite.

### Elements — the expansion's build checklist

Every value below is in **this screen's own** measured token table. Nothing is
borrowed from another contract.

| # | role | copy / label | key styles (cited from the generated table above) |
|---|---|---|---|
| DX1 | `generic` | `Will remove:` | `12px` · `w500` · `rgb(70, 69, 85)` — element 18's exact treatment. Copy verbatim from BRD §20/§22, in its own future tense |
| DX2 | `generic` | (category label — see §Copy below) | `14px` · `w500` · `rgb(11, 28, 48)` — the recent-conversation row title (elements 21/26/31) |
| DX3 | `generic` | (that group's measured bytes, format `N MB`) | `12px` · `w500` · `rgb(70, 69, 85)` · `JetBrains Mono` — the timestamp treatment (elements 22/27/32) |
| DX4 | `generic` | (the group's reason — see §Copy below) | `12px` · `w500` · `rgb(70, 69, 85)` — element 18's treatment |
| DX5 | `generic` | `Why:` | as DX1. Copy verbatim from BRD §22 |
| DX6 | `generic` | (the plan's summary sentence) | `14px` · `rgb(70, 69, 85)` — the preview-line treatment (elements 24/29/34) |
| DX7 | `generic` | `Nothing to remove right now.` | as DX6, centred — GAP-002's approved empty treatment. **Replaces DX1-DX6 when the latest plan has no candidate group, and when no pass has run yet** |
| DX8 | `generic` | `Couldn't read local storage. Try again.` | as DX7 — GAP-002's treatment. No error colour is invented (GAP-009's precedent) |

DX2/DX3/DX4 repeat once per candidate group in `E08-T04`'s latest
`RetentionPlan`. The card reads `StorageManager.latestPlan` and
`StorageDecisionLog.latestPass()`; **it never triggers a pass in order to
render.** A screen that starts a retention pass because someone opened the app
is a screen that deletes data because someone opened the app.

**A class that could not be measured renders as `Not measured`, never as `0`**
(`E08-T02` §2).

### `DX7` is the expected default reading, not a rare one

The human answered `OQ-E08-3` on **2026-09-02** with option **(a)**: Smart
Mode's allow-list **excludes conversation content entirely**; message content
is removed **only** under a manual policy the user explicitly turns on. Smart
Mode is the default (`FR-STORE-004`), and relay payloads — the only other
sizeable class in this build — are already reclaimed on TTL by
`RelayEngine.reclaimPayloads` (`E04-B02`), which E08 must not duplicate.

So on a default install the honest expansion says **`Nothing to remove right
now.`** Nothing in either state may be phrased as imminent: no countdown, no
"X days left", no badge, no urgency colour, and no wording that implies
messages are about to be deleted. The BRD's own tense is future
(`Will remove:`), and this state is the one where that tense is load-bearing.

### Copy — the strings this state introduces

**Verbatim from the BRD** (a spec source, not agent voice):
- `Will remove:` *(BRD §20, §22)*
- `Why:` *(BRD §22)*
- `Temporary cache` *(BRD §20 — maps to `StorageItemKind.relayPayload`, `E08-T02` §2)*
- `Voice messages` · `Call recordings` · `Old attachments` *(BRD §20 — these produce zero items in this build; listed so the format is fixed before the media path exists, not because data exists today)*
- `Rarely accessed` · `No longer required` *(BRD §20/§22 reason strings)*

**Proposed copy** — agent proposals in this screen's voice, and what the 🧍
gate is being asked to approve:
- `Nothing to remove right now.` *(DX7)*
- `Couldn't read local storage. Try again.` *(DX8)*
- `Messages` · `Database file` *(category labels; no BRD source — the BRD's worked example is media only)*
- `Older than N days` *(reason format; BRD §22 writes `Older than 45 days` / `Older than 60 days` as **examples**)*
- `Over the size limit` *(reason format for `RetentionReason.overSizeLimit`; no BRD source)*
- `Not measured` *(DX3 when a class could not be measured)*

**Format strings — the format is the contract, the number is data:**
`N MB used` *(element 16)* · `N MB` *(DX3)* · `<Mode> - <parameter>`
*(element 18)*.

**The BRD's example figures are NOT copy.** `820 MB`, `620 MB`, `310 MB` and
`50 MB` (BRD §20/§22) are illustrative numbers in a worked example. Printing
any of them here would put a fabricated figure on the dashboard — the exact
defect `dashboard_controller.dart`'s `isMeasured: false` header exists to
prevent. Every number this card shows comes from `E08-T02`'s real measurement,
or the row does not render.

### Open — put to the human, not decided

1. **The unavailable-factor wording** (`OQ-E08-4`'s neighbourhood). `E08-T04`
   reports each of `FR-STORE-005`'s eight factors as scored or
   `Unavailable(reason)`, and a factor can stay unavailable after
   `OQ-E08-4`'s answer — *storage pressure* is unavailable until the Pigeon
   free-space channel `OQ-E08-1`(a) authorises actually ships. `FR-STORE-007`
   requires an explanation and an explanation that silently omits a factor is
   not one. **No copy is proposed and no advisory is offered:** how much of
   the machinery to show a user is a product judgement, and `OQ-E08-4`'s
   answer resolved *importance*, not *wording*. Same fork as
   `design/screens/settings-storage.md` §Open 1 — one question, two surfaces.
2. **`GAP-026` — the denominator.** Element 16 shows bytes. If a user-visible
   budget is later wanted (`OQ-E08-1` option (b), deferred not rejected),
   `storage_policy_settings.budget_bytes` is where it lands and the
   percentage returns here. Recorded so the future change has a named home.

## Notes for the implementing agent
- **Never re-implement policy in a widget.** Read `RetentionPlan`. Two similar
  answers is the failure `E08-T04` exists to prevent.
- **The card observes; it never triggers a pass.**
- `L-design-002` (a promoted rule) applies to `E08-T08`: this state widens the
  displayed data shape of a design-contracted screen, so
  `test/design/design_probe_test.dart`'s dashboard fixture must seed a storage
  plan, or the gate is structurally blind to everything above.
- Once built, extract the expanded state as its own golden so it is
  regression-gated from then on like everything else.
