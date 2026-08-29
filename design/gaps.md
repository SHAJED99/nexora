# Design gaps — what the design doesn't cover, and what we'll do about it

**Gate:** 🧍 `design_contract_approval` — ✅ cleared by human on 2026-08-26
(the original 7-screen contract extraction + gap pass, per Q-DESIGN-001 in
`spec/questions.md`. Gaps added later by feature epics — GAP-002/003/004 —
each carry their own `approved by:` line below and are tracked
independently; several are still pending your actual sign-off.)

Rule 2 has two halves. Every part of the provided design gets implemented as
accurately as possible **and** every journey it omits gets completed from the
BRD / SRS / feature list, consistent with the design that exists.

This file is the second half. Everything here is 🧍 human-approved before it is
built — "what should happen when the list is empty" is a product decision
wearing a UI costume.

**Method:** `agent/skills/design-fidelity/references/gaps.md`
**Rule:** a gap cites a spec id. No id → it's an idea, not a gap; ideas go to
the human. And no gap gets filled quietly inside an implementation task — that
is how a product acquires seven different empty states.

## Status legend
🟡 proposed · 🟢 approved · ⚪ deferred · ✅ built (golden extracted)

---

<!-- Template — copy, don't edit this one.

## GAP-001 — <screen>, <what's missing>
- **status:** 🟡 proposed
- **screen:** <id> (`design/screens/<id>.md`) — or "new screen"
- **spec:** FR-XXXX-000, UC-0.0.0 — "<the EARS criterion that requires it>"
- **design shows:** <what the design actually drew>
- **derived from:** <the primitives this reuses, from the contract's token table>
- **proposal:** <one paragraph — what gets built>
- **approved by:** _<human>_ on _<date>_
- **built:** <task id> · golden extracted ✅

-->

## GAP-001 — welcome, page background color not in the contract's token table
- **status:** 🟡 proposed
- **screen:** welcome (`design/screens/welcome.md`)
- **spec:** epics/E00-genesis/epic.md (genesis walking skeleton, no FR id — this is a genesis-scaffold token gap, not a feature/journey gap)
- **design shows:** the contract's measured token table has no page-background value (the Stitch golden capture's background reads through a light surface token, not a standalone page-bg entry)
- **derived from:** `lib/core/design/tokens.dart:14` (`welcomeBg = Color(0xFF0B1420)`) — approximated by the E00-T05 builder to give the welcome screen a background, not measured from the golden capture
- **proposal:** when the first real design-fidelity pass runs against the built app (post-genesis, see OQ-E00-3), re-measure the actual page background from `design/golden/welcome/default@390x844/probe.json` and replace this approximation with the measured value, or confirm it already matches and promote it into the contract's token table
- **approved by:** _<pending — flagged during E00 review, 2026-08-26; not blocking merge since the skeleton has no design-verify gate yet (OQ-E00-3)>_
- **built:** E00-T05 · golden extracted ⚪ (not yet re-verified against a running build)

## GAP-002 — devices, empty state (no relationships stored yet)
- **status:** 🟡 proposed
- **screen:** devices (`design/screens/devices.md`)
- **spec:** FR-DISC-001 — the Devices screen renders whatever this side has
  already evaluated locally; the design's default state shows four example
  rows and never shows zero
- **design shows:** four populated device rows, no empty-list treatment
- **derived from:** the screen's own body typography
  (`NexoraTextStyles.devicesSectionSubtitle`, 14px `rgb(70,69,85)`) — no new
  visual language, just the existing subtitle style centered where the list
  would be
- **proposal:** render a single centered `Text('No devices yet')` in the
  list area, styled with `devicesSectionSubtitle`, when
  `RelationshipRepository.listAll()` returns empty
- **approved by:** _<pending — flagged during E02-T02 implementation,
  2026-08-26; not blocking merge since there is no design-verify gate for
  compiled Flutter apps yet (OQ-E00-3)>_
- **built:** E02-T02 · golden extracted ⚪ (no gate to extract against yet)

## GAP-003 — devices, device name and transport type are not modeled yet
- **status:** 🟡 proposed
- **screen:** devices (`design/screens/devices.md`)
- **spec:** FR-DISC-001, FR-TRUST-003 — the design's four example rows show
  a human-readable device name ("Ahmed's Laptop") and a transport-type
  subtitle ("Wi-Fi Direct"); `RelationshipRepository` (E02-T01) stores only
  `deviceId` / `state` / `updatedAt` — no name, no transport metadata. That
  data only exists once real device discovery (E04) populates it.
- **design shows:** distinct per-device names and transport subtitles, and
  a per-device leading icon that (in the four example rows) happens to use
  a distinct color per row
- **derived from:** the row's own structure — the `deviceId` string stands
  in for the name (element 9/17/25/33 role), a fixed placeholder
  `"Paired locally"` stands in for the transport subtitle (element
  10/18/26/34 role) until E04 supplies real metadata, and the leading icon
  (`Icons.devices`, element 8/16/24/32 role) is tinted by `RelationshipState`
  using the same token each state's example row in the golden capture
  happens to use, since no per-device type is known
- **proposal:** once E04 supplies real device metadata (name + transport),
  replace the `deviceId`/`"Paired locally"` placeholders with the real
  fields; re-extract the golden then
- **approved by:** _<pending — flagged during E02-T02 implementation,
  2026-08-26; not blocking merge, OQ-E00-3 gate gap>_
- **built:** E02-T02 · golden extracted ⚪ (no gate to extract against yet)

## GAP-004 — devices, "Discover" button has no real behavior yet
- **status:** ⚪ deferred
- **screen:** devices (`design/screens/devices.md`)
- **spec:** FR-DISC-001 — device discovery does not exist until E04
- **design shows:** a functioning "Discover" button (element 6) that
  presumably starts a scan
- **derived from:** N/A — behavior deferred, not derived; the button is
  rendered exactly per the contract and remains tappable
- **proposal:** intentionally a no-op for E02-T02 — tapping shows a
  SnackBar ("Device discovery isn't available yet."); E04 wires the real
  scan behavior behind the same button
- **approved by:** _<pending — flagged during E02-T02 task-sharding as
  OQ-E02-T02-1, 2026-08-26; this line needs the human's name, not the
  agent's — an agent cannot sign its own gap-approval gate (rule 2/3)>_
- **built:** E02-T02 · golden extracted ⚪ (no gate to extract against yet)

## GAP-005 — settings, "Privacy & Security" sub-screen has no design source
- **status:** 🟡 proposed
- **screen:** settings (`design/screens/settings.md`) — or "new screen"
- **spec:** FR-TRUST-006 — auto-accept-trusted, auto-accept-specific,
  require-auth-for-unknown, block-list view, location-access toggle all
  need a real settings surface; the design's "Privacy & Security" row
  (element 15/21 — icon `security`, "Encryption protocols, app lock,
  permissions") is only a menu entry, not the sub-screen itself
- **design shows:** a tappable row that implies a destination screen, with
  no destination screen drawn anywhere in the design source
- **derived from:** N/A — not derived yet; this gap only proposes that the
  sub-screen needs a design pass, not what it should contain
- **proposal:** once a design pass produces `design/screens/settings-privacy.md`
  (or similar), shard a task from it that implements FR-TRUST-006's actual
  controls, consistent with `settings.md`'s row/card primitives
  (`NexoraColors.settingsRowFill`/`devicesRowBorder`, row typography)
- **approved by:** _<pending — needs the human's actual sign-off, not an agent's>_
- **built:** not built — this is the proposal only (E02-T03 builds the
  menu row that links to it; the row's tap currently shows a "Coming soon"
  SnackBar per OQ-E02-T03-1)

<!-- ── E06 (Personal Chat) gap pass — added at E06 task-sharding, 2026-08-29 ── -->

## GAP-006 — conversations, the "Groups" section has no data until E07
- **status:** ⚪ deferred (until E07)
- **screen:** conversations (`design/screens/conversations.md`)
- **spec:** FR-GROUP-001/002/003 — groups are E07's scope; E06's own
  `epic.md` §Screens explicitly instructs logging this at sharding
- **design shows:** a `Groups` heading (element 21) with three populated
  rows — `Family` / `Work` / their previews, `dns`, `group_off`,
  `cloud_off`, `David Chen:` (elements 22-33)
- **derived from:** the same section heading + row typography the
  `Personal` section uses (`heading:2` 22px w500 `rgb(234,241,255)`,
  row preview 14px `rgb(70,69,85)`) — the empty treatment reuses the
  centered-subtitle pattern already approved for GAP-002 (devices empty
  state), no new visual language
- **proposal:** E06 renders the `Groups` heading exactly as the contract
  measures it, with a single centered subtitle line in place of the three
  rows. The heading is NOT deleted (rule 2/design-fidelity rule 3 — never
  delete a design element to satisfy the data layer). The three group rows
  are recorded here as knowingly-absent until E07 populates them; the
  design-verify report will show them as missing elements and that finding
  traces to this entry.
- **approved by:** _<pending — needs the human's actual sign-off>_
- **built:** E06-T09 (heading + empty treatment) · rows deferred to E07

## GAP-007 — conversations, empty state (no conversations at all)
- **status:** 🟡 proposed
- **screen:** conversations (`design/screens/conversations.md`)
- **spec:** FR-COMM-001, FR-TRUST-003 — on a fresh install with no trusted
  or allowed peer, the Personal list is legitimately empty; the design only
  ever draws two populated rows (`Ahmed`, `Rahim`)
- **design shows:** two populated Personal rows, no zero-row treatment
- **derived from:** the GAP-002 pattern (centered body subtitle in the
  screen's own 14px `rgb(70,69,85)` body style), placed where the rows
  would be; search field, headings and bottom nav stay exactly as measured
- **proposal:** the Personal section shows one centered line when no
  conversation exists. Copy is a product decision, not an agent's — pending
  the human, E06-T09 uses the same wording pattern GAP-002 was approved
  with rather than inventing a new voice.
- **approved by:** _<pending — needs the human's actual sign-off>_
- **built:** E06-T09

## GAP-008 — chat, empty state (a conversation with no messages yet)
- **status:** 🟡 proposed
- **screen:** chat (`design/screens/chat.md`)
- **spec:** FR-COMM-001 — "start a conversation" is the entry point into
  this epic's whole journey; the design draws five populated bubbles and a
  `Today` day-divider and never shows zero
- **design shows:** a populated thread only (elements 9-25)
- **derived from:** the day-divider pill's own typography/fill
  (12px w500 `rgb(70,69,85)` on `rgb(239,244,255)`, r9999px) — the empty
  treatment reuses that pill as a single centered line; header and composer
  are unchanged
- **proposal:** an empty thread renders header + composer exactly as
  measured, with one centered pill in place of the message list. No new
  colour, radius or font is introduced.
- **approved by:** _<pending — needs the human's actual sign-off>_
- **built:** E06-T10

## GAP-009 — chat, the design draws no failed / no-session / queued-forever message state
- **status:** 🟡 proposed
- **screen:** chat (`design/screens/chat.md`)
- **spec:** FR-MSG-002 — the delivery-state set includes `Failed`, and
  FR-MSG-001 includes a message that is queued while offline. The design
  only draws two tick glyphs: `check` (element 25) and `done_all` in two
  colours (elements 14 `rgb(103,244,183)`, 22 `rgb(70,69,85)`) — three
  visual states for a seven-state machine
- **design shows:** `check`, grey `done_all`, green `done_all`. No failed
  indicator, no "no session with this contact" affordance
- **derived from:** the dashboard contract, which *does* draw the two
  states chat omits — `radio_button_unchecked` 14px `rgb(70,69,85)` next
  to `Message queued — will send when connected.` (dashboard elements
  33-34) and `check_circle` 14px `rgb(0,83,56)` (element 23). Reusing the
  dashboard's own glyphs keeps one visual language across the two screens
  instead of inventing a third.
- **proposal:** map the state machine onto the glyphs the design already
  owns — `Queued` → `radio_button_unchecked` (dashboard 33),
  `Sent` → `check` (chat 25), `Delivered` → grey `done_all` (chat 22),
  `Read` → green `done_all` (chat 14), `Failed` → **needs a human call**:
  no design source anywhere draws a failure glyph, and inventing an error
  colour would be the first off-palette token in the app. Tracked as
  `OQ-E06-T10-1`; until answered, `Failed` renders as `Queued`'s glyph
  with the message still in the list (never silently dropped).
  `Accepted` and `Stored` have no distinct glyph because the design draws
  none — see `OQ-E06-T10-2` (what `Stored` even means, inherited from
  `OQ-E05-T03-1`).
- **approved by:** _<pending — needs the human's actual sign-off>_
- **built:** E06-T10

## GAP-010 — chat, the composer and the transfer card promise message types E06 text-first does not build
- **status:** ⚪ deferred (within E06 — see E06-T11)
- **screen:** chat (`design/screens/chat.md`)
- **spec:** FR-COMM-001 — text, voice messages, PTT, attachments and
  location are all in the epic's scope; the epic's own §Risks mitigation is
  to ship text first and sub-shard the rest
- **design shows:** an `add` button (elements 26-27), a `mic` button on the
  accent fill (elements 30-31), and a file-transfer bubble
  (`troubleshoot` / `Backup: Family Photos` / `In progress... 78%`,
  elements 16-18) — i.e. attachment and voice affordances plus a
  transfer-progress bubble, with **no** design anywhere for the recording
  UI, the PTT interaction, the attachment picker, a voice-message bubble,
  or a location bubble
- **derived from:** not derived yet — this entry proposes that a design
  pass is needed, it does not invent the screens
- **proposal:** E06-T10 renders `add` and `mic` exactly as measured
  (present, correctly styled, tappable) but they are no-ops with a
  "not yet available" affordance in the pattern GAP-004 was approved with
  for the Devices "Discover" button. The transfer bubble is not rendered
  when no transfer exists (it is data-driven content, not chrome).
  E06-T11 then runs a real gap pass producing derived contracts for the
  rich message types, 🧍 approved, before any of them is sharded — rule 2:
  a frontend task without a design contract is not shardable.
- **approved by:** _<pending — needs the human's actual sign-off>_
- **built:** E06-T10 (the no-op affordances) · E06-T11 (the contracts)

## GAP-011 — dashboard, the Local Storage card has no data source until E08
- **status:** ⚪ deferred (until E08)
- **screen:** dashboard (`design/screens/dashboard.md`)
- **spec:** E06 `epic.md` §Scope explicitly puts storage management in E08
  ("messages just accumulate for now")
- **design shows:** `Local Storage` / `45% used` / `warning` /
  `Smart Mode - Older than 10 days` (elements 15-18)
- **derived from:** the card is kept exactly as measured; only its numbers
  are unfed
- **proposal:** E06-T08 renders the card and its labels character for
  character. `45% used` becomes the real on-disk figure if it is cheaply
  available from the existing Drift file size, otherwise the card renders
  with the measured labels and a placeholder value **disclosed in the
  task's §Deviations and here** — never a fabricated percentage presented
  as measured. `Smart Mode - Older than 10 days` is static copy until E08
  builds the retention policy it describes.
- **approved by:** _<pending — needs the human's actual sign-off>_
- **built:** E06-T08

## GAP-012 — dashboard, FR-UI-004's "one tap away" detail destination is not drawn
- **status:** 🟡 proposed
- **screen:** dashboard (`design/screens/dashboard.md`)
- **spec:** FR-UI-004 / EARS-COMM-2 — "advanced technical detail (route,
  transport, latency) shall be available one tap away, not shown by
  default". The requirement names a second surface; the design draws only
  the summary card
- **design shows:** the Network Status card (elements 5-14) with
  `Connected`, `Encryption`/`Secure`, `Latency`/`24ms`. Nothing drawn is a
  destination.
- **derived from:** the existing Devices screen (`design/screens/devices.md`)
  already *is* the route/transport detail surface — it lists peers, their
  transports and their states, and the bottom nav already routes to it
- **proposal:** the Network Status card is the tap target and it navigates
  to `/devices` rather than to a newly-invented screen. This satisfies
  FR-UI-004 with a surface the design already owns and the app already
  builds, and introduces no undesigned screen. If the human wants a
  dedicated route-detail screen instead, that is a new design pass, not an
  agent's invention.
- **approved by:** _<pending — needs the human's actual sign-off>_
- **built:** E06-T08

## GAP-013 — dashboard, the disconnected / degraded variants of the Network Status card
- **status:** 🟡 proposed
- **screen:** dashboard (`design/screens/dashboard.md`)
- **spec:** FR-UI-004 ("communicate connectivity state simply") and
  FR-ROUTE-009 (a route can fail and none may exist) — the app is
  offline-first by construction, so "not connected" is a normal state, not
  an error
- **design shows:** the connected state only — `circle`
  `rgb(0,101,145)` + `Connected` (elements 7-8) and a concrete `24ms`
- **derived from:** the same row, same glyph, same typography; only the
  status word and the dot colour change, drawn from tokens the contract
  already measures on this screen (`rgb(70,69,85)` body text for a muted
  dot, as used on elements 12-14)
- **proposal:** one status row, three data-driven readings — connected
  (as measured), no peers, and no route to the selected peer. Latency shows
  the real measurement from E06-T02's link-quality wiring, and shows a
  neutral placeholder rather than a fabricated number when no measurement
  exists yet. Exact copy for the non-connected readings is a product
  decision pending the human; nothing is invented silently.
- **approved by:** _<pending — needs the human's actual sign-off>_
- **built:** E06-T08

## The usual suspects

Checklist for the gap pass. In rough order of how often each is missed:

| Category | Typically missing from a design |
|---|---|
| Error states | validation, 401/403, 404, 500, network dead |
| Empty states | first-run, no results, filtered-to-nothing |
| Loading | skeletons, spinners, optimistic updates |
| Boundary data | very long strings, huge numbers, deep nesting |
| Whole journeys | password reset, invite, onboarding, offboarding |
| Permission variants | the same screen for a role with less access |
| Responsive | design shows desktop; the spec promises mobile |
| Confirmation | destructive-action dialogs |
