# Design gaps — what the design doesn't cover, and what we'll do about it

**Gate:** 🧍 `design_contract_approval` — ⏳ AWAITING HUMAN
(reopened by the **E07 sharding pass**, 2026-08-31, for **GAP-018 ·
GAP-019 · GAP-020 · GAP-021 · GAP-022** — the groups-and-calls gap pass —
and for the three derived contracts `E07-T12` will write against them:
`design/screens/group-create.md`, `design/screens/group-manage.md`,
`design/screens/call.md`. **Nothing derived from GAP-018…GAP-022 is
shardable as a frontend task until this line reads cleared.** `E07-T08`
— the Conversations *Groups* section — is **not** gated by this reopening:
it builds elements 21-33 of the already-approved, already-measured
`conversations.md` contract and closes GAP-006, which was approved on
2026-08-29 with "rows deferred to E07" written into it.)

**Clearance history**
- ✅ cleared by human on 2026-08-26 — the original 7-screen contract
  extraction + gap pass, per Q-DESIGN-001 in `spec/questions.md`.
- ✅ cleared by human on 2026-08-30 — GAP-014/015/016 approved, GAP-017
  decided. See each entry below for the fork decisions.
- Gaps added later by feature epics (GAP-001…GAP-013) each carry their own
  `approved by:` line below and are tracked independently; several are still
  pending the human's actual sign-off.

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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — proposal as written: re-measure against the
  golden capture once E06-T01's gate is live, replace or promote the
  approximated value accordingly
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction to proceed without waiting, 2026-08-29) — "No devices yet"
  in `devicesSectionSubtitle`, as proposed, no new visual language
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — replace placeholders once E04's real metadata
  is wired, as proposed
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — SnackBar no-op as proposed, consistent with
  the "not yet available" affordance pattern used elsewhere in this epic
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — proposal as written: a design pass is needed
  before this sub-screen is shardable; not built until then
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — proposal as written: heading kept, rows
  deferred to E07, copy "No groups yet" for the empty treatment (matches
  GAP-002's established voice)
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — copy "No conversations yet", same voice as
  GAP-002/GAP-006
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — pill copy "No messages yet — say hello",
  reusing the day-divider pill's own typography/fill unchanged
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — `Failed` renders as `error_outline` at the
  existing muted grey token `rgb(70,69,85)` (already used for `done_all`
  grey on this screen), distinguished by icon shape alone rather than
  inventing a new off-palette colour; message stays visible in the list,
  never silently dropped. `Accepted`/`Stored` render identically to
  `Sent`'s glyph (no distinct visual) since the design draws no third
  tick and OQ-E06-T10-2 below retires the question rather than forwarding
  it a third time.
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — proposal as written: `add`/`mic` present and
  tappable but no-op with a "not yet available" affordance, transfer
  bubble data-driven only
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — proposal as written: real on-disk figure if
  cheaply available, disclosed placeholder otherwise, static copy for the
  Smart Mode line until E08
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — proposal as written: Network Status card
  navigates to `/devices`
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
- **approved by:** orchestrator (recommendation applied per user's standing
  instruction, 2026-08-29) — copy: "No peers nearby" (no peers reachable),
  "No route to this peer" (peers exist, no path); dot renders in the
  existing muted `rgb(70,69,85)` for both, no new colour
- **built:** E06-T08

<!-- ── E06-T13 rich-message-type gap pass — the second half of FR-COMM-001,
     2026-08-30. These four are NOT approved. Every `approved by:` line below
     is deliberately empty (L-process-002 — an agent-approved design gap has
     already cost this project once). The gate line at the top of this file is
     ⏳ AWAITING HUMAN for exactly these entries. ── -->

## GAP-014 — chat, voice messages: no recording UI and no playback bubble
- **status:** 🟢 approved
- **screen:** chat (`design/screens/chat.md`) → new derived contract
  `design/screens/chat-voice.md`
- **spec:** FR-COMM-001 — "personal communication via text, **voice
  messages**, PTT, voice calls, attachments, and location sharing";
  FR-UI-001 (Material 3, no competing visual language). E06 `epic.md` §Risks
  puts these behind text-first as follow-on tasks inside this epic.
- **design shows:** a `mic` button on the accent fill (chat elements 30-31)
  and nothing else. No recording state, no elapsed counter, no cancel
  affordance, no voice bubble, no playback control anywhere in the design
  source.
- **derived from:** `chat.md`'s own measured primitives only — the composer
  button geometry (48×48, `r9999px`, chat 26/30), the accent fill
  `rgb(53, 37, 205)` with `rgb(255, 255, 255)` glyphs (chat 30-31), the
  header icon-button (40×46, `r9999px`, chat 1/7) for cancel, the
  timestamp treatment (`12px` `w500` `rgb(70, 69, 85)`, chat 11/13) for the
  elapsed counter, the text-bubble box (270-272×48, chat 12/15/20) for the
  playback bubble, and the measured `2px` radius for the progress track.
  `circle` is borrowed as an existing glyph from
  `design/screens/dashboard.md` (element 7), the way GAP-009 borrowed that
  screen's glyphs rather than inventing new ones.
- **proposal:** three surfaces, all inside the existing chat screen — a
  recording composer (dot + `M:SS` counter + `Recording…` + cancel), a
  cancel affordance, and a playback bubble (play/pause + a plain progress
  track + duration) that is the text bubble with its body replaced. Detail
  in `design/screens/chat-voice.md`. **Three things are deliberately put to
  you rather than decided:**
  (a) **press-and-hold vs tap-to-toggle recording** — a real product choice,
  not a detail: hold buys a slide-to-cancel gesture and no stop button and is
  unusable for a long message; toggle buys an explicit stop button and costs
  an extra tap on a two-second one. The contract specifies **both** variants'
  elements so the visual language is fixed either way; the unchosen variant's
  rows get struck at approval. No advisory pick — the answer depends on how
  long a typical NEXORA voice message is, which is your knowledge, not the
  agent's.
  (b) **waveform vs plain progress** — the design draws no waveform primitive
  anywhere, so the contract proposes a plain track built from the measured
  `2px` radius. A waveform is a new design element and needs you.
  (c) **glyph names** for stop / close / play / pause. No contract in
  `design/screens/` draws any of them. Their family, size and colour are
  measured tokens; only the glyph identity is proposed copy, flagged
  `[glyph — pending human confirmation]` in the contract.
  Codec, bit rate, max length and storage are explicitly **not** proposed
  here — engineering, and partly E08's.
- **approved by:** human, 2026-08-30 — **tap-to-toggle** (not press-and-hold):
  an explicit stop button is easier to get right on a phone and doesn't risk
  losing a long recording to an early-lifted finger; the V2/V7 "toggle"
  rows stand, the press-and-hold/slide-to-cancel rows (V8's cancel-gesture
  use) are struck. Glyph names (`stop_circle`, `close`, `play_arrow`,
  `pause`) approved as proposed — no change needed. Plain progress track
  (not waveform) approved as proposed, since a waveform would invent a new
  design primitive the source doesn't have.
- **built:** not built — contract approved; the voice-message frontend task
  is now shardable

## GAP-015 — chat, attachments: the picker has no destination and the transfer card has no terminal states
- **status:** 🟢 approved
- **screen:** chat (`design/screens/chat.md`) → new derived contract
  `design/screens/chat-attachment.md`
- **spec:** FR-COMM-001 — "…**attachments**…"; FR-UI-001
- **design shows:** the `add` button (chat 26-27), and — unusually for this
  pass — a real, fully drawn attachment primitive: the in-progress transfer
  bubble `troubleshoot` / `Backup: Family Photos` / `In progress... 78%`
  (chat 16-18). What it does **not** draw is where `add` leads, and what the
  card looks like once the transfer completes or fails.
- **derived from:** that transfer card itself, kept exactly as measured —
  `troubleshoot` `24px` `rgb(0, 101, 145)`, title `12px` `w700`
  `rgb(11, 28, 48)`, subtitle `12px` `w500` `rgb(70, 69, 85)` (chat 16-18).
  The picker reuses the screen's own card tokens (`rgb(255, 255, 255)` fill,
  `12px` radius, `rgba(199, 196, 216, 0.2)` border, the single measured
  shadow) with the `add` button's icon treatment (`24px`
  `rgb(53, 37, 205)`, chat 27) on its rows. `check_circle` is borrowed from
  `design/screens/dashboard.md` (element 23) but tinted with **this** card's
  own `rgb(0, 101, 145)` so no new value enters the chat screen; the failed
  state inherits GAP-009's already-approved `error_outline` at
  `rgb(70, 69, 85)` rather than re-opening that decision.
- **proposal:** four states, one card. A source picker from `add`
  (photo/video, camera, file — plus the location row GAP-016 specifies, in
  the same picker), the in-progress card unchanged, a completed card
  (`check_circle` + file size in the subtitle slot), and a failed card
  (`error_outline` + `Transfer failed`) that **stays in the thread** rather
  than disappearing. Progress stays a percentage in text; the design draws
  no progress bar and one is not invented. **Put to you rather than decided:**
  the picker's **container form** — bottom sheet vs anchored menu — because
  the design draws no sheet, menu or dialog anywhere, and the picker's row
  contents are derivable while its container is not. Advisory: a bottom
  sheet, since the composer is at the bottom of a 390×844 viewport and the
  app has no anchored-menu precedent to be consistent with — but this is a
  recommendation, not a decision. Also flagged: the three source glyphs.
  File size limits, chunking, MIME allow-lists and retention are **not**
  proposed here — E08 owns storage.
- **approved by:** human, 2026-08-30 — **bottom sheet** (not anchored menu),
  per the contract's own advisory. Source glyphs (`image`, `photo_camera`,
  `attach_file`) approved as proposed.
- **built:** not built — contract approved; the attachment frontend task is
  now shardable

## GAP-016 — chat, location-in-chat: no share entry point and no received bubble
- **status:** 🟢 approved
- **screen:** chat (`design/screens/chat.md`) → new derived contract
  `design/screens/chat-location.md`
- **spec:** FR-COMM-001 — "…and **location sharing**"; FR-LOC-005 (never
  represent stale location as live — the one location requirement this
  contract genuinely must discharge in pixels); FR-UI-001
- **design shows:** nothing. No location affordance, no location bubble, no
  map, no pin, and no image anywhere in the chat contract other than the
  38×38 avatar (chat element 3).
- **derived from:** the same transfer-card treatment as GAP-015 (chat 16-18)
  inside the text bubble's box (270-272×48, chat 12/15/20) — icon `24px`,
  title `12px` `w700`, subtitle `12px` `w500`, the picker row treatment
  (`24px` `rgb(53, 37, 205)` + `12px` `w500` `rgb(11, 28, 48)`, chat 27) for
  the share entry, the muted `rgb(70, 69, 85)` for the disabled and
  unavailable treatments, and the existing timestamp + delivery-tick
  elements (chat 11/14/22/25) unchanged.
- **proposal:** one row in GAP-015's picker (`Location`), and a location
  message rendered as a **card, not a map** — the design owns no map
  primitive and deriving one would be inventing an element, so the bubble is
  the transfer card's icon/title/subtitle with the subtitle carrying the
  freshness string (`Shared just now` vs `Last known · h:mm AM`, which is how
  FR-LOC-005 is discharged and is therefore not optional). An unavailable
  location keeps its card in the thread with the muted treatment rather than
  vanishing. **Explicit boundary — this contract governs rendering only and
  must not be read as redefining anything it touches:** FR-TRUST-006's
  location-access control stays where it is (GAP-005's undesigned
  Privacy & Security sub-screen); FR-MSG-007's `LOCATION-OFF > LOCATION-ON`
  conflict precedence is untouched and a rendered bubble is never evidence
  that sharing is permitted — the permission check happens before the bubble
  exists; **FR-LOC-001…005 and location sharing as a capability belong to
  E09**, and this contract assumes a message the permission layer already
  allowed. Live-vs-static location, update frequency and share duration are
  E09's, not proposed here. **Put to you rather than decided:** whether an
  in-thread **map preview** is wanted at all (it would be a new design
  element and a new dependency, so it is a design pass plus rule 3, not a
  derivation), and the `place` / `location_off` glyph names.
- **approved by:** human, 2026-08-30 — **card-only, no map preview**. A map
  is a separate design pass and rule-3 decision, not a blocker for
  text-first location sharing; ship the card now. `place` / `location_off`
  glyphs approved as proposed.
- **built:** not built — contract approved; the location-in-chat frontend
  task is now shardable, and still additionally depends on E09's permission
  model existing

## GAP-017 — chat, PTT: no design source, no derivable primitive, and no contract proposed
- **status:** ⚪ deferred — decided, not a design proposal. Tracked as
  **`OQ-E06-T13-1`** in `epics/E06-personal-chat/tasks/E06-T13.md`
  §Open Questions and in `epic.md` §Open Questions. Owner: **human**.
- **screen:** chat (`design/screens/chat.md`) — **no derived contract
  written, deliberately**
- **spec:** FR-COMM-001 — "…text, voice messages, **PTT**, voice calls…";
  `spec/feature-list.md` §Personal Communication UC ("User sends/receives
  text, voice messages, PTT, attachments, location with a contact")
- **design shows:** nothing that implies a PTT mode. The `mic` button (chat
  30-31) reads as voice-message recording and is already claimed by GAP-014;
  there is no transmitting state, no channel indicator, no listening state,
  and no half-duplex affordance anywhere in any of the seven contracts.
- **derived from:** **N/A — nothing.** Push-to-talk is a *mode* (hold to
  transmit, release to listen, near-real-time), not a message bubble.
  Composing one out of bubble geometry and a mic button would not be
  deriving an omitted state from existing primitives; it would be inventing
  an interaction model, which rule 2 forbids as squarely as dropping an
  element does. The honest output here is a question.
- **proposal:** **none — this entry exists to record that no proposal is
  being made.** The questions that must be answered before PTT can have a
  design at all: is it a live half-duplex stream (which is a transport
  problem, much closer to E07's voice-call work than to messaging), or a
  fast voice-message loop layered on GAP-014? Does a PTT transmission leave
  a message in the thread afterwards, or is it ephemeral? Is it
  per-conversation, or its own surface? **Advisory recommendation: park PTT
  until E07's voice-call work settles the real-time transport question**,
  then design it once against a transport that exists — a half-duplex live
  stream shares E07's problems and almost none of E06's. Recorded with an
  owner so it is not silently dropped from FR-COMM-001's scope; a
  re-home to E07 is itself a scope decision and would go through
  `skills/change-impact`.
- **decided by:** human, 2026-08-30 — agree with the advisory. **Park PTT
  until E07's voice-call work settles the real-time transport question**;
  re-home the FR-COMM-001 PTT obligation to E07 via `skills/change-impact`
  rather than attempting it in E06. `OQ-E06-T13-1` closes as answered, not
  as still-open.
- **built:** not built and not shardable — no contract exists; PTT is out of
  E06's scope, owned by E07 going forward
- **superseded by:** _(pending — `E07-T13` is GAP-017's named owner and will
  supersede this entry by reference once `OQ-E07-3` is answered. This entry
  is never edited; see `E07-T13` §4.)_

<!-- ── E07 (Groups & Voice Calls) gap pass — added at E07 task-sharding, 2026-08-31 ── -->

## GAP-018 — group creation has no design source at all
- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/group-create.md`
- **spec:** FR-GROUP-001, FR-GROUP-002 ("the Owner shall be able to …"
  presupposes a group exists and someone made it); `spec/feature-list.md`
  §Personal & Group Communication → "UC: Owner creates and manages a group"
- **design shows:** nothing. None of the seven measured screens contains a
  create-group entry point, a member picker, or a group-name field. The
  Conversations screen draws a `Groups` heading and three populated rows
  (elements 21-33) and no way to have made any of them.
- **derived from:** `conversations.md`'s own list vocabulary — the search
  field, the `heading:2` section heading at 22px w500 `rgb(234, 241, 255)`,
  and the row treatment (leading 24px icon, title w500 `rgb(11, 28, 48)`,
  secondary line 14px `rgb(70, 69, 85)`) — plus `devices.md`'s per-peer row
  with a trailing action, which is this design's only existing "act on one
  item in a list of peers" shape.
- **proposal:** one screen: a group-name text field in the search field's
  measured treatment, then a selectable list of trusted contacts using the
  Conversations row shape with a trailing selection affordance borrowed
  from `devices.md`, then a primary action. States: empty (no trusted
  contacts yet — reuse GAP-002's centred-subtitle pattern), loading, error,
  and a disabled primary action until a name and ≥1 member exist. **Entry
  point is deliberately not proposed here** — the design draws no
  affordance on Conversations and adding one is itself a change to a
  measured screen; `E07-T12` proposes it as part of the contract and the
  human approves it there, or it waits.
- **approved by:** _<empty — 🧍 human>_
- **built:** _(not yet — `E07-T12` writes the contract; the build task is
  prospective)_

## GAP-019 — group management (roles, membership, deletion) has no design source
- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/group-manage.md`
- **spec:** FR-GROUP-001 (Owner/Admin/Member), FR-GROUP-002 (rename, add,
  remove, assign admins, transfer ownership, delete), FR-GROUP-003 (Admins
  perform permitted actions; Members participate)
- **design shows:** nothing. There is no group detail screen, no member
  list, no role label, and no destructive-action treatment anywhere in the
  seven contracts.
- **derived from:** `devices.md`'s per-device row (the closest existing
  "list of peers with a per-row action and a state label") and
  `conversations.md`'s section headings; the destructive action reuses no
  existing primitive because none exists — see the fork below.
- **proposal:** an editable group name (Owner/Admin only), a member list
  with a role label per row, per-row actions rendered **only when
  `GroupPermissions.allows` says so** (`E07-T02`'s matrix is the source of
  truth, not a second UI-side rule), and leave/delete at the bottom. **The
  role-forbidden state is a required state, not an edge case**: a Member
  opening this screen sees the roster and no actions at all.
  **Two forks for the human:**
  (1) *Destructive confirmation* — the design has no dialog primitive
  anywhere. Options: (a) a full-screen confirm step reusing this screen's
  own typography; (b) introduce a modal primitive (new visual language,
  which rule 2 says not to invent silently). *Advisory: (a).*
  (2) *Where roles are shown* — a text label per row versus an icon.
  *Advisory: a text label*, because the design's icon set carries no role
  semantics and inventing one is inventing language.
- **approved by:** _<empty — 🧍 human>_
- **built:** _(not yet — `E07-T12` writes the contract; the build task is
  prospective)_

## GAP-020 — the chat thread draws only 1:1 bubbles; a group thread needs sender attribution and event lines
- **status:** 🟡 proposed
- **screen:** chat (`design/screens/chat.md`) — a state, not a new screen
- **spec:** FR-COMM-002 ("group communication via text, PTT, voice calls,
  attachments, and **group events**"), FR-GROUP-002/003
- **design shows:** a 1:1 thread only — incoming and outgoing bubbles with
  no sender name, and no system/event line of any kind. The Conversations
  screen *does* draw a sender prefix for a group row (`David Chen:`,
  element 26, 14px w500 `rgb(11, 28, 48)`), which is the only place the
  design acknowledges that a group message has an author.
- **derived from:** element 26's exact sender-name treatment, lifted from
  the list row into the thread as a per-bubble attribution line; the event
  line derives from `chat.md`'s own secondary-text treatment (14px
  `rgb(70, 69, 85)`), centred, with no bubble surface.
- **proposal:** in a group thread, an incoming bubble carries a sender
  attribution line in element 26's treatment; outgoing bubbles do not
  (the design never labels the user to themselves). Membership changes
  render as centred, surface-less event lines — "Ahmed added David",
  "Group renamed to Work" — one per `group_events` row (`E07-T01`).
  **Open, and deliberately not decided here:** whether a *blocked* member's
  messages are dropped, hidden or placeholdered inside a group thread —
  that is `OQ-E07-13` on `E07-T07`, and it is a product decision, not a
  layout one. This entry does not answer it.
- **approved by:** _<empty — 🧍 human>_
- **built:** _(not yet — blocked on `OQ-E07-13` as well as this gate)_

## GAP-021 — voice calls have no design source: no outgoing, incoming, in-call or failed state
- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/call.md`
- **spec:** FR-CALL-001 (secure voice calls over the same routing
  architecture), FR-CALL-002 (priority), FR-CALL-003 (mid-call migration);
  `spec/feature-list.md` §Voice Calls → "UC: User places a secure voice
  call"
- **design shows:** nothing. No call screen, no ringing state, no call
  controls, and no call affordance on any of the seven contracts —
  including `chat.md`, whose header has no call button.
- **derived from:** `chat.md`'s header treatment (peer identity, the 24px
  icon-button vocabulary) for identity and controls, and `dashboard.md`'s
  status-card treatment for connection quality — the same card `GAP-014`
  already borrowed once, so this is an established borrowing, not a new
  one.
- **proposal:** one surface with four states — outgoing/ringing, incoming
  (accept + decline), in-call (elapsed duration, mute, hang up, a
  connection-quality readout in the dashboard card's treatment), and
  **failed**, which today is the state `NullCallMediaTransport` produces
  (`E07-T09` §2) and which must say honestly that audio cannot be carried
  rather than showing a connected call. **Constraint on the contract:**
  every control must trace to FR-CALL-001/002/003 or to a state
  `CallSession` can actually be in — no speaker toggle, no video, no
  add-participant, because nothing in the spec requires them and a drawn
  button is a promise. **Fork for the human:** the *entry point* — a call
  button in `chat.md`'s header is the obvious place and the design draws
  none, so adding it modifies a measured screen. *Advisory: propose it in
  the contract and let this gate decide it, rather than a build task adding
  it quietly.*
- **approved by:** _<empty — 🧍 human>_
- **built:** _(not yet — `E07-T12` writes the contract; the build task is
  prospective)_

## GAP-022 — mid-call route migration is invisible to the user, and it may need to stay that way
- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/call.md` — a state within it
- **spec:** FR-CALL-003 ("evaluate it, establish and validate it, migrate
  the call, and then terminate the old route — minimizing call
  interruption")
- **design shows:** nothing — there is no call screen at all, let alone a
  transition indicator.
- **derived from:** `dashboard.md`'s network-status card, whose degraded
  and disconnected variants `GAP-013` already covers, is the only existing
  treatment for "the connection changed underneath you".
- **proposal:** **show nothing during a successful migration.** FR-CALL-003's
  own words are "minimizing call interruption"; a migration that succeeds
  is a non-event, and surfacing it invites the user to worry about
  something the system just handled. Surface only the *degraded* case — a
  migration abandoned with the route quality already poor — reusing
  GAP-013's degraded card treatment inside the in-call state. Recorded as a
  gap rather than assumed, because "show nothing" is a design decision that
  looks like an omission, and the next person to read the call contract
  should find it written down. **Fork:** if you would rather see a
  transient "switching connection" indicator, that is cheap to add and this
  entry is where to say so. *Advisory: silent on success, GAP-013's
  treatment on degradation.*
- **approved by:** _<empty — 🧍 human>_
- **built:** _(not yet)_

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
