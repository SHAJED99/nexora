# Design gaps — what the design doesn't cover, and what we'll do about it

**Gate:** 🧍 `design_contract_approval` — ✅ **CLEARED BY HUMAN, 2026-09-08**
(`AskUserQuestion` — "Yes, approve and start dispatching tasks", given
alongside approval of `change_impact_approval`, `epic_breakdown_and_wave`
and `analyze_report` in the same answer) for **GAP-031 … GAP-039** — the
settings-sub-screen and sign-out gap pass — and for the nine derived
contracts written against them: `design/screens/settings-shell.md` (not a
screen — the shared shell, recorded as a contract so eight screens cannot
each invent one), `settings-notifications.md`, `settings-privacy.md`,
`settings-security-center.md`, `settings-account.md`, `settings-network.md`,
`settings-battery.md`, `settings-about.md`, and `sign-out-confirm.md`.
**`design/screens/settings-storage.md` (GAP-024) is NOT reopened** — it was
approved 2026-09-02, is byte-unchanged, and `E15-T09` simply builds it.
The clearances recorded below this line stand exactly as the human set them; an
agent does not re-open them and does not re-clear them.

**The nine named forks with no proposal** (LED, app lock, permissions,
certificates, data usage, proxy, OS deep link, release notes, and the
shared destructive-colour fork inherited from GAP-021) were **not**
individually resolved by this approval — the human approved dispatch in
general, not each specific design micro-decision. Per AGENTS.md rule 3's
2026-09-06 extended autonomy grant (human stepping away, decide rather
than wait), these are delegated to whichever task owns each fork: pick
the option most consistent with this design system's existing
conventions, record the choice and reasoning in that task's own file the
way a human answer would be recorded, and only escalate back to a
genuine Open Question if no existing convention gives a reasonable
default.

**Previously:** ✅ CLEARED BY HUMAN, 2026-08-31
(reopened by the **E07 sharding pass**, 2026-08-31, for **GAP-018 ·
GAP-019 · GAP-020 · GAP-021 · GAP-022** — the groups-and-calls gap pass —
and for the three derived contracts `E07-T12` will write against them:
`design/screens/group-create.md`, `design/screens/group-manage.md`,
`design/screens/call.md`. All five approved with the fork decisions below
(GAP-020's *build* still separately waits on `OQ-E07-13`, a product
decision, not a design one). `E07-T08` — the Conversations *Groups*
section — was never gated by this reopening: it builds elements 21-33 of
the already-approved, already-measured `conversations.md` contract and
closes GAP-006, which was approved on 2026-08-29 with "rows deferred to
E07" written into it.)

> **E12/E14 reopening, cleared 2026-09-05.** E12 (Account Recovery &
> Device Enrollment) and E14 (Version & Update Management) task-sharding
> reopened this gate for **GAP-028** and **GAP-029**. GAP-028: new-device
> enrollment and the "no recovery" notice, neither shown anywhere in the
> design — two derived screens proposed, `device-enrollment.md` (the new
> device's own journey) and `device-enrollment-approval.md` (the existing
> trusted device's approval prompt), both derived from `devices.md`'s
> row/status-chip vocabulary and `welcome.md`'s centred single-focus
> layout. GAP-029: the mandatory-update block, also absent from the
> design — one derived full-screen state, `version-update-required.md`,
> deliberately NOT a dialog (this design draws no dialog/sheet primitive
> anywhere, same finding `GAP-025` already recorded). **Both approved as
> proposed, 2026-09-05.** `E12`/`E14`'s frontend tasks may now be sharded
> against `device-enrollment.md`, `device-enrollment-approval.md` and
> `version-update-required.md` once those contracts are written. `E14`
> separately
> carries its own `OQ-E14-1` (an unrelated scope-placement question, no
> UI surface) still open regardless of this gate.

> **E08 reopening, cleared 2026-09-02.** `E08-T07`'s design gap pass
> reopened this gate for **GAP-024 · GAP-025 · GAP-026 · GAP-027** (the
> Storage settings sub-screen, the dashboard warning's expanded state,
> the storage-percentage denominator, and the settings row's "export"
> subtitle). All four approved: GAP-024/025 as proposed; GAP-026 as the
> record of the already-made `OQ-E08-1` decision; GAP-027's fork resolved
> as (c) — no export control, the subtitle stays a disclosed copy
> artifact. `E08-T08` (dashboard card) and the future `E08-T09` (Storage
> settings screen, once sharded) may now build against `design/screens/
> settings-storage.md` and `dashboard.md`'s new derived state.

> **`E07-T12` follow-up, 2026-08-31.** The three contracts named in that
> clearance now exist (`group-create.md`, `group-manage.md`, `call.md`) and
> each records what it derived and from where. The gate line above is left
> **as the human set it** — it is not re-opened by an agent and it is not
> re-cleared by one. Four things remain genuinely undecided and are listed in
> their own entries rather than assumed: GAP-018's **entry point** (which
> GAP-018 itself deferred into the contract — **since decided: ✅ approved by
> the human 2026-09-25, built by `E07-T16`; see
> `design/screens/group-create.md` §Open**), and GAP-021's **destructive
> treatment**, **three glyph names** and **two copy strings**. None of them is
> approved below; every `approved by:` line written by `E07-T12` is
> deliberately absent (`L-process-002`).

> **`E07-T13` follow-up, 2026-08-31.** One new entry, **GAP-023**, records the
> PTT disposition and supersedes GAP-017 **by reference** (GAP-017 is
> byte-unchanged — it records a decision the human already made). GAP-023 is
> 🟡 **proposed and not approved**: its `approved by:` line is deliberately
> bare (`L-process-002`) and it carries four explicit forks, the first of
> which is the reading of PTT itself. The gate line above is left **as the
> human set it** — an agent does not re-open it and does not re-clear it.

> **E08 sharding pass, 2026-09-02.** Four new entries — **GAP-024 ·
> GAP-025 · GAP-026 · GAP-027** — record the local-storage gap pass. All
> four are 🟡 **proposed and not approved**: every `approved by:` line is
> deliberately bare (`L-process-002`), and two of them (GAP-026's
> denominator, GAP-027's export) carry **no proposal at all**, only named
> forks, because both would otherwise write a number or a scope the spec
> does not contain. `E08-T07` writes the derived contract
> `design/screens/settings-storage.md` against GAP-024/GAP-025;
> **`E08-T08` does not build until the human clears these, and `E08-T09`
> (the Storage screen itself) is not even sharded yet — rule 2 forbids a
> frontend task pointing at a contract that does not exist, and
> `scheduler.py --validate` enforces it.** The gate line above is left
> **as the human set it** —
> an agent does not re-open it and does not re-clear it.

> **`E08-T07` follow-up, 2026-09-02.** The derived design work `GAP-024` and
> `GAP-025` describe now exists: the new contract
> `design/screens/settings-storage.md`, and a hand-written
> **§Derived state — `warning-expanded`** appended below the generated marker
> in `design/screens/dashboard.md` (whose generated tables are
> **byte-unchanged** — `design-fidelity` rule 1). Each records what it derived
> and from where, introduces **no new token, colour, radius or glyph**, and
> contains **no `Clean Now`, apply-now, confirmation or delete affordance** —
> `FR-STORE-006` says the user does not need to press one, and that
> prohibition is written into the contracts, not only into the task. **All
> four entries below remain 🟡 proposed: every `approved by:` line is
> deliberately bare** (`L-process-002`), `GAP-026` and `GAP-027` still carry
> **no proposal at all**, and one further fork — how a category with an
> `Unavailable` factor is worded — is named in both contracts' §Open with no
> advisory. `OQ-E08-1`'s answer is *recorded* under `GAP-026` as a citation;
> recording a human's answer is not signing their approval line. The gate line
> above is left **as the human set it** — an agent does not re-open it and
> does not re-clear it.

**Clearance history**
- ✅ cleared by human on 2026-08-26 — the original 7-screen contract
  extraction + gap pass, per Q-DESIGN-001 in `spec/questions.md`.
- ✅ cleared by human on 2026-08-30 — GAP-014/015/016 approved, GAP-017
  decided. See each entry below for the fork decisions.
- ✅ cleared by human on 2026-08-31 — GAP-018/019/020/021/022 approved
  (E07 groups-and-calls gap pass). See each entry below for the fork
  decisions.
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
- **built:** E06-T09 (heading + empty treatment) · rows built by **E07-T08**
  (2026-09-02) — real per-group rows now render when `watchConversations()`
  returns groups; the empty "No groups yet" treatment stays for a zero-group
  device. Golden not re-extracted: `test/design/design_probe_test.dart`'s
  `conversations` fixture (T01-owned, out of E07-T08's `files:` fence) seeds
  no group data, so the design gate still reports the three rows as absent
  — see E07-T08's own Run log for why that is a probe-fixture limitation,
  not a code defect.

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
- **approved by:** ✅ human, 2026-08-31 — approved as proposed
- **built:** contract written — `design/screens/group-create.md` (`E07-T12`,
  2026-08-31). Not built in code; the build task is prospective. Golden is
  extracted **after** the build, per `design-fidelity` §3.
- **still open after this entry's approval (`E07-T12`, 2026-08-31):** the
  **entry point**, which this entry deliberately deferred into the contract
  ("`E07-T12` proposes it as part of the contract and the human approves it
  there, or it waits"). The proposal now exists — `group-create.md` §Open —
  and is an `add` icon-button in `conversations.md`'s header, in that
  screen's own 48×48 `r9999px` / `24px` `rgb(195, 192, 255)` vocabulary.
  It is **not** covered by the 2026-08-31 clearance above and is **not**
  approved by an agent (`L-process-002`). Until the human says so, no build
  task adds any affordance to `conversations.md`; `/groups/new` is reachable
  only by direct navigation, which blocks nothing else in this contract.

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
- **approved by:** ✅ human, 2026-08-31 — both advisories accepted: (1) a
  full-screen confirm step for leave/delete, no new modal primitive;
  (2) a text label per row for roles, not an icon
- **built:** contract written — `design/screens/group-manage.md` (`E07-T12`,
  2026-08-31), with both fork decisions honoured literally: a full-screen
  confirm step (no scrim, no elevation, no modal primitive) and a plain
  `12px` `w500` text label per row for the role. Not built in code; the
  build task is prospective.
- **clarified by `E07-T12` (2026-08-31), not re-decided:** this entry's
  "a Member … sees the roster and no actions at all" is one row stronger
  than `E07-T02`'s matrix, which this entry itself names as the source of
  truth: `allows(member, leave)` is **`true`** — every role may leave. The
  contract therefore renders **no management action** for a Member and keeps
  `Leave group`. Correspondingly, an **Owner** sees no `Leave group` at all
  (`allows(owner, leave)` is `false` until ownership is transferred). If the
  human prefers the literal reading of this entry over the matrix, say so
  here and the contract changes; the matrix is not edited from the UI side.
- **`more_vert` deliberately unused (`E07-T12`):** `devices.md` draws it, but
  it implies a menu surface no contract in `design/screens/` measures.
  Per-row actions are inline chips in devices element 31's own treatment
  instead. Recorded so the difference from `devices.md` reads as a decision,
  not drift.

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
- **approved by:** ✅ human, 2026-08-31 — approved as proposed (build still
  waits on `OQ-E07-13`, unresolved by this approval)
- **built:** _(not yet — blocked on `OQ-E07-13` as well as this gate)_
- **no contract written by `E07-T12` (2026-08-31), deliberately:** this gap is
  a **state on `chat.md`**, not a new screen, and `E07-T12` §4 forbids
  designing group-thread rendering beyond naming the gap while `OQ-E07-13`
  (a blocked member's messages inside a group thread — a product decision) is
  unanswered. `chat.md` is a generated contract and is not hand-edited
  (`design-fidelity` rule 1). The approved derivation stands as written here:
  the sender-attribution line takes `conversations.md` element 26's treatment
  (`14px` `w500` `rgb(11, 28, 48)`) on **incoming** bubbles only, and event
  lines are centred, surface-less, in `chat.md`'s `14px` `rgb(70, 69, 85)`,
  one per `group_events` row. Whoever writes that contract inherits this
  paragraph and answers `OQ-E07-13` first.

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
- **approved by:** ✅ human, 2026-08-31 — approved as proposed, including
  adding a call-entry icon-button to `chat.md`'s header
- **built:** contract written — `design/screens/call.md` (`E07-T12`,
  2026-08-31), four states plus the approved `chat.md` header entry point
  (elements C24/C25, in chat's own 40×46 `r9999px` / `24px`
  `rgb(70, 69, 85)` header vocabulary). No speaker toggle, no video, no
  add-participant, and **no element for FR-CALL-002** — priority is a routing
  weight with no user-facing state. Not built in code; the build task is
  prospective.
- **three items `E07-T12` left open rather than decide (`L-process-002`):**
  (a) the **destructive treatment** for decline/hang up — neither parent
  contract measures a red; advisory is to tint the `call_end` glyph
  `rgb(186, 26, 26)` (devices' measured destructive *text* colour) as a
  cross-screen borrow in GAP-009's pattern, with the fallback until answered
  being the ordinary `rgb(53, 37, 205)` glyph and **no** new colour;
  (b) three **glyph identities** — `call`, `call_end`, `mic_off` (family,
  size and colour are measured; only the names are proposed), in
  `chat-voice.md`'s established pattern; (c) two **copy strings** —
  `Connection degraded` and the media-unavailable line.
- **note for the reviewer:** `make design-verify SCREEN=chat` will report the
  header call button as an **extra element**. That finding traces here, per
  `design-fidelity` §6. `chat.md` was **not** hand-edited (rule 1).

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
- **approved by:** ✅ human, 2026-08-31 — approved as proposed: silent on a
  successful migration, GAP-013's degraded-card treatment on an abandoned one
- **built:** contract written — the `in-call` / `in-call-degraded` state pair
  in `design/screens/call.md` (`E07-T12`, 2026-08-31). The two states differ
  in exactly two cells (the status dot's colour and the status word); nothing
  moves, appears or is added, because a mid-call layout shift would defeat the
  quietness this entry chose. `attempted`, `validated` and `completed`
  migration events render nothing at all. Not built in code.

<!-- ── PTT disposition — supersedes GAP-017 by reference (E07-T13, 2026-08-31) ── -->

## GAP-023 — PTT, answered: a hold-to-transmit delta on GAP-014's approved voice-message contract

- **status:** 🟢 approved — **supersedes `GAP-017` by reference.** GAP-017
  is not edited: it records the human's 2026-08-30 decision to park PTT
  until the real-time transport question settled, and it stays exactly as
  written. This entry is what that parking condition was waiting for.
- **screen:** chat (`design/screens/chat.md`) → a **delta on the already-approved
  derived contract `design/screens/chat-voice.md`** (GAP-014). No new screen,
  no new route.
- **spec:** FR-COMM-001 ("personal communication via text, voice messages,
  **PTT**, voice calls, attachments, and location sharing") · FR-COMM-002
  ("group communication via text, **PTT**, voice calls, attachments, and
  group events") · **FR-STORE-002** ("store voice messages, **PTT
  recordings**, and call recordings locally on-device") · **FR-NOTIFY-001**
  (PTT is its own notification class, listed beside "new messages, voice
  messages … incoming calls") · FR-PLAT-001 (background operation includes
  PTT) · `spec/feature-list.md` §Personal Communication UC ("User
  sends/receives text, voice messages, PTT, attachments, location **with a
  contact**") · FR-UI-001 (Material 3, no competing visual language)
- **owner:** `E07-T13`, the named owner of `OQ-E07-2` / `IMP-001`. Outcome
  **(b)** of the three its §2 allows: *PTT layers on GAP-014's
  voice-message recording UI with a small delta contract.*

### The precondition that had to clear first
`OQ-E07-3` — what carries live call audio — was resolved by the human on
**2026-08-31: (a) datagram audio over the existing mesh with an Opus codec,
with (c) a native real-time Pigeon channel as the named fallback if measured
multi-hop-BLE latency proves unworkable**, the latency risk accepted
knowingly rather than resolved by measurement first. GAP-017 could not be
answered before that, which is exactly why the human parked it.

### GAP-017's three questions, answered

**Q1 — Is PTT a live half-duplex stream (a transport problem), or a fast
voice-message loop layered on GAP-014? → A fast voice-message loop, in v1.**

The tempting read of `OQ-E07-3`'s answer is that PTT is now nearly free: with
a datagram path over the mesh, PTT is the same path with a hold-to-transmit
gate and no duplex mixing. That is true, and it is **not** the whole picture:

- **"Free" is conditional on work that does not exist yet.** The datagram
  media path is a *prospective, unsharded* task (`epic.md` §Follow-on), and
  `OQ-E07-3`'s own answer says `OQ-E06-T04-2` — real-hardware multi-hop-BLE
  latency, never measured — "should still be prioritized before the
  media-path prospective task is sharded, so the fallback can be exercised
  cheaply if (a) doesn't hold up". Making PTT depend on that chain would be a
  fourth deferral wearing a contract, which is precisely what `E07-T13`
  exists to prevent.
- **The spec describes an artifact, not a channel.** Three requirements
  constrain PTT and none of them describes a live session: **FR-STORE-002**
  says a PTT transmission is *stored on-device as a recording*;
  **FR-NOTIFY-001** gives PTT its own *notification* class, which only means
  something if a transmission can arrive while nobody is holding the channel
  open; and PTT appears in FR-COMM-001/002 in the list of *message types*,
  between voice messages and voice calls. **FR-CALL-001/002/003 — the entire
  call chapter — never mention PTT.** A live half-duplex channel is a
  reading the spec permits but nowhere requires; a stored, notifiable,
  per-conversation recording is the reading the spec actually writes down.
- **On this product's transport, the message reading is the more honest
  one.** E04's mesh is store-and-forward with a TTL measured in days; a live
  route between two specific devices is the lucky case, not the normal one.
  A walkie-talkie that only works when the peer happens to be reachable *at
  that instant* fails silently most of the time; a hold-to-talk clip that
  arrives in seconds when a route exists and minutes when it doesn't is the
  same feature, degrading correctly.
- **What `OQ-E07-3` genuinely buys PTT is the codec, not the channel.**
  Opus is now an authorized dependency (for calls). GAP-014 deliberately left
  codec, bit rate and max length out of scope as engineering; with Opus
  chosen, PTT needs **no new dependency at all** — which is what makes this
  delta small. FR-STORE-003's low-CPU/low-battery/low-bandwidth voice profile
  applies to it unchanged.

**This is an interpretation, and it is put to you as one** — see §Forks below.

**Q2 — Does a PTT transmission leave a message in the thread, or is it
ephemeral? → It leaves a message. This is decided by the spec, not by this
entry.**

**FR-STORE-002** says the system *shall* store PTT recordings locally
on-device. Ephemeral PTT would contradict a "shall" (rule 1), so this was
never actually an open design question — it was an open question that had a
spec answer nobody had gone looking for. The artifact is **GAP-014's already
approved voice bubble (`chat-voice.md` V10-V16), unchanged**: same geometry,
same play/pause glyphs, same plain progress track, same timestamp and
delivery-tick treatment. A second, near-identical bubble type for "the same
object recorded with a different gesture" would be a competing visual
language for one artifact — FR-UI-001, and rule 2's "never silently invent
one".

*Boundary:* FR-STORE-002 also names **call recordings**, which no epic
currently claims and which this entry does **not** decide anything about —
flagged here only so it has been seen once. It is E08's (local storage), and
`E07-T09` §4 explicitly persists no call history.

**Q3 — Per-conversation, or its own surface? → Per-conversation. No new
route, no new screen, no PTT channel list.**

Every spec id that names PTT places it inside a conversation: FR-COMM-001
scopes it to *personal* communication, FR-COMM-002 to *group* communication,
and `spec/feature-list.md`'s UC says "with a contact". Nothing in `spec/`
names a PTT surface, a channel roster, or a global talk button. A dedicated
PTT screen would be an invented navigation destination with no id behind it —
which rule 2 forbids as squarely as dropping one.

### The delta — what actually gets built

Deliberately written **into this entry rather than into
`design/screens/chat-voice.md`**: `E07-T13`'s `files:` fence permits
`design/gaps.md` and `epic.md` only (rule 6), and a contract file should not
be amended before the human has approved the amendment (`L-process-002`).
Once this entry is approved, a follow-on docs task writes these rows into
`chat-voice.md` as a `ptt-transmitting` state and the build task follows.
Everything below is either an **unchanged** GAP-014 row or is named as new.

| # | role | copy / label | derived from |
|---|---|---|---|
| P1 | `button` | — (the existing `mic` button, chat 30/31) | **no new element.** PTT is entered by **press-and-hold on the same 48×48 accent `mic` button**; a *tap* still starts a tap-to-toggle voice message exactly as the human approved on 2026-08-30. The gesture is the feature's own name |
| P2 | `generic` | `circle` 12×12, `rgb(53, 37, 205)` | GAP-014 **V3**, unchanged — the transmitting dot |
| P3 | `generic` | `0:07` (`M:SS`) | GAP-014 **V4**, unchanged — the elapsed counter, `JetBrains Mono`, `12px` `w500` `rgb(70, 69, 85)` |
| P4 | `generic` | `Transmitting…` | **one new copy string**, in GAP-014 **V5**'s exact treatment (the `Recording…` slot). Flagged for sign-off below |
| P5 | — | (no stop button, no cancel button) | GAP-014's **V1/V2** (stop) and **V6/V7** (cancel) are **absent** in this state: the finger is the control, and release commits. Nothing is added to compensate |
| P6 | `generic` | GAP-014 **V10-V16**, unchanged | the delivered artifact is the approved voice bubble, in both alignments, with the same delivery-tick set (GAP-009) |

**Not visually distinguished from a voice message.** A PTT clip and a voice
message produce the same bubble. FR-STORE-002 separates them as *storage
classes*, not as visual ones, and FR-NOTIFY-001 separates them as
*notification* classes — so the difference the user experiences is in
arrival, not in the thread. *Advisory, and a fork below:* an incoming PTT
clip **auto-plays when its thread is already open** and otherwise raises
FR-NOTIFY-001's PTT notification; a voice message never auto-plays. That is
the whole behavioural difference, and it needs no pixel.

**Explicitly not proposed here:** any claim on FR-CALL-002's real-time
traffic priority (`E07-T10`). FR-CALL-002 names *calls*; a PTT clip is an
ordinary message on the ordinary pipeline in v1. Engineering may later
argue for a priority class, and that is an engineering change with its own
gate, not something this entry grants quietly.

### Group floor control (FR-COMM-002)

FR-COMM-002 names PTT for groups in one word, and one word in the spec is
still spec (rule 1). **Group PTT is in v1 scope and needs no floor control,
and that is the strongest single argument for this disposition.**

- Under the **live half-duplex** reading, a group PTT channel is a floor
  arbitration problem: who holds the floor, what happens on simultaneous
  press, whether a queue exists, how a stale floor is reclaimed when its
  holder walks out of range. On an intermittent multi-hop mesh with no
  central authority, that is a distributed-consensus problem with **no spec
  text, no ADR and no derivable design primitive** behind it. It would have
  to be raised as its own blocking question.
- Under the **message** reading adopted here, **there is no floor.** Two
  members holding the button at once produce two clips, exactly as two
  members typing at once produce two messages. Group PTT is then the
  existing group fan-out (`E07-T04`/`T05`/`T06`) carrying a voice bubble,
  rendered with GAP-020's already-approved sender-attribution line on
  incoming bubbles. Zero new mechanism, zero new floor state, zero new
  design element.
- **Therefore group PTT is neither deferred nor re-homed.** It rides the
  same delta as 1:1 PTT and inherits GAP-020's build precondition
  (`OQ-E07-13`, the blocked-member-in-a-group-thread product decision) — the
  same precondition every other group-thread bubble already has, not a new
  one invented for PTT.
- **If the human takes the live-channel fork below**, floor control comes
  back and is *not* solvable inside this delta: it would need its own
  blocking question and its own owner, and this paragraph is the record that
  says so in advance.

### Forks — put to you, not decided

1. **The reading itself (the one that matters).** This entry reads PTT as a
   hold-to-transmit clip that is stored, notified and rendered as a voice
   bubble. If your intent for PTT is a genuinely **live half-duplex channel**
   — hold the button and the other person hears you *now*, nothing kept —
   then (i) FR-STORE-002 needs an amendment, because it says the opposite;
   (ii) PTT becomes downstream of the media-path prospective task and of
   `OQ-E06-T04-2`'s hardware latency numbers; and (iii) group PTT needs a
   floor-control design that does not exist. Say so here and it routes
   through `skills/change-impact` as a changed requirement. **Advisory:
   ship this reading now.** The two are not exclusive — a live mode can be
   added later over the same button and the same bubble artifact (which
   FR-STORE-002 requires either way), so this is a subset, not a fork that
   closes a door. **Named trigger for revisiting:** the media-path task
   shipping *and* `OQ-E06-T04-2` producing real multi-hop-BLE latency
   numbers.
2. **Press-and-hold on the `mic` button.** On 2026-08-30 you chose
   tap-to-toggle for voice messages and struck GAP-014's press-and-hold rows.
   This entry does **not** reverse that — tap still toggles — but it does
   put a *second* gesture on the same button. The alternative is a third
   composer button, which costs real width in a 390px row that already
   carries `add` (chat 26), a 214px textbox (chat 28), `lock` (chat 29) and
   `mic` (chat 30). *Advisory: the long-press, because "push to talk" is the
   gesture the feature is named after; a hidden affordance is the honest
   cost, and it is smaller than a crowded rail.*
3. **The `Transmitting…` string**, and whether a slip-of-the-finger
   sub-second clip should be discarded rather than sent. A minimum-duration
   discard needs no new element (the state simply ends), but "how short is
   too short" is a product number, not a measured token, so no value is
   proposed.
4. **Auto-play on receipt** for an incoming PTT clip in an open thread (see
   the delta table). It is the only behavioural difference between PTT and a
   voice message, and it is a product decision wearing a UI costume.

- **derived from:** `design/screens/chat-voice.md` (GAP-014, approved
  2026-08-30) in its entirety — V3/V4/V5 for the transmitting state,
  V10-V16 for the artifact; `design/screens/chat.md` elements 30-31 for the
  button that carries the gesture; `design/gaps.md` GAP-020 (approved
  2026-08-31) for group sender attribution; GAP-009's approved delivery-tick
  mapping. **No new token, no new geometry, no new glyph** — the only new
  string is `Transmitting…`.
- **approved by:** ✅ human, 2026-08-31 — all four forks accepted as
  advised: (1) the stored-clip reading, shipped now, not the live
  half-duplex channel; (2) press-and-hold on the existing `mic` button, no
  new composer element; (3) a minimum-duration threshold discards a
  slip-of-the-finger sub-second press-and-release rather than sending it
  (exact threshold left to the builder as an engineering choice); (4)
  auto-play on receipt when the clip's conversation thread is already open
- **built:** not built — this entry is the disposition, not the build. On
  approval: one docs task folds the delta into
  `design/screens/chat-voice.md` as a `ptt-transmitting` state, then the
  PTT build task (`epic.md` §Follow-on) becomes shardable for the first
  time.
- **supersedes:** `GAP-017` — **by reference, unedited.** GAP-017's
  `superseded by:` line is deliberately left as its author wrote it; the
  pointer that matters is this one.

<!-- ── E08 (Local Storage & Management) gap pass — added at E08 task-sharding,
     2026-09-02. These four are NOT approved. Every `approved by:` line below
     is deliberately empty (`L-process-002`). `E08-T07` writes the derived
     contract these describe; `E08-T08` and `E08-T09` are gated on the
     human clearing them. The gate line at the top of this file is left
     exactly as the human set it — an agent does not re-open it and does
     not re-clear it (the practice this file already records twice). ── -->

## GAP-024 — settings, the "Storage" row has no destination screen
- **status:** 🟡 proposed
- **screen:** settings (`design/screens/settings.md`) → new derived contract
  `design/screens/settings-storage.md`
- **spec:** FR-STORE-004 (the user chooses Smart Mode / older-than-X-days /
  over-X-MB) and FR-STORE-007 (the decisions the active policy made, with
  reasons). Both need a real surface; the design draws only the menu row.
- **design shows:** elements 29-30 — icon `sd_storage`, heading `Storage`,
  subtitle `Local cache, message retention, export`. A tappable row that
  implies a destination, with no destination drawn anywhere in the source.
- **derived from:** exactly the shape `GAP-005` was approved with for the
  Privacy & Security row — a design pass produces the sub-screen contract
  first, then a task builds from it. Primitives come from `settings.md`
  (frame, row fill/border, heading + body typography, icon backdrop) and
  `devices.md` (a list of rows with trailing metadata); the usage summary
  reuses `dashboard.md`'s Local Storage card typography.
- **proposal:** `E08-T07` writes `design/screens/settings-storage.md` as a
  `source: derived` contract containing: the three-mode selector, the two
  manual-policy parameter inputs with their validation error state, the
  measured usage summary, and the decision-explanation list. **No
  "Clean Now", no apply-now, no destructive affordance** — FR-STORE-006
  says the user does not need to press one, and this screen must not
  reintroduce it by the back door. Route `/settings/storage`; every other
  settings row keeps its existing behaviour untouched.
- **approved by:** human, 2026-09-02
- **built:** not built — `E08-T07` writes the contract, `E08-T09` builds it
- **contract written (`E08-T07`, 2026-09-02):**
  `design/screens/settings-storage.md` now exists and records what it derived
  and from where. It is written **against** this still-unapproved proposal and
  is **not** independently approved by an agent (`L-process-002`). Four things
  it deliberately did not decide are listed in its §Open: the
  unavailable-factor wording, `GAP-027`'s export, `GAP-026`'s denominator, and
  the screen-as-detail-vs-menu reading. Three derivation decisions are recorded
  in its §Derivation boundary rather than left to look like drift: geometry is
  borrowed from `devices.md` while **colour comes from `settings.md`** (devices
  is a light screen, settings a dark one, and `rgb(11, 28, 48)` is text on one
  and page fill on the other); `settings.md` element 6's title colour
  `rgb(234, 241, 255)` is **not** used because it is absent from settings' own
  measured token table (`group-manage.md`'s `r4px` reasoning); and the
  parameter field is built from the parent's own card surface rather than
  `conversations.md`'s light-filled search field. **No new token, no new glyph,
  no new radius.** No golden exists and the screen cannot be gated by
  `make design-verify` until `E08-T09` builds it.

## GAP-025 — dashboard, the storage warning has no expanded state
- **status:** 🟡 proposed
- **screen:** dashboard (`design/screens/dashboard.md`)
- **spec:** FR-STORE-007 — "when a storage warning is expanded, the system
  shall show the specific decisions the active policy made and explain
  why". The design draws the collapsed card only.
- **design shows:** elements 15-18 — `Local Storage`, `45% used`,
  `warning`, `Smart Mode - Older than 10 days`. Nothing drawn is expanded,
  and nothing drawn is a destination.
- **derived from:** the card's own measured frame and typography, extended
  downward in the pattern BRD §22's worked example describes (a category
  list — label, byte figure, one-line reason — then a "Why" summary). Body
  text uses the card's existing `rgb(70,69,85)` 12px w500 (element 18); the
  category labels reuse the card heading's scale one step down. No new
  token, no new geometry.
- **proposal:** tapping the card toggles an expansion **in place** — not a
  navigation, not a dialog. The expansion lists one row per category from
  the latest decision pass with its real measured bytes and its reason
  string, followed by the "Why" summary sentence. Expanding runs nothing,
  applies nothing and deletes nothing (EARS-STORE-2).
- **approved by:** human, 2026-09-02
- **built:** not built — `E08-T07` contracts it, `E08-T08` builds it
- **contract written (`E08-T07`, 2026-09-02):** appended to
  `design/screens/dashboard.md` as a hand-written
  **§Derived state — `warning-expanded`**, below the generated marker. **The
  generated tables are byte-unchanged** (`design-fidelity` rule 1). Written
  against this still-unapproved proposal; not agent-approved
  (`L-process-002`). Recorded there rather than assumed: **no expand/collapse
  glyph is drawn** — `GAP-012` already established on this same screen that a
  card becomes a tap target without acquiring a chevron, and `dashboard.md`
  measures no expand glyph; and the expansion **cannot be gated by
  `make design-verify SCREEN=dashboard`** until the build exists and a second
  golden is extracted, so `E08-T08`'s reviewer should expect the state to be
  invisible to the gate. Two of the collapsed card's measured strings will
  report as **copy findings** once E08 feeds it — `45% used` (→ `GAP-026`) and
  `Smart Mode - Older than 10 days` (→ `GAP-011`'s approved resolution, which
  made it static "until E08 builds the retention policy it describes").
  Neither is a silent rewrite.

## GAP-026 — dashboard, `45% used` has no denominator, and no copy exists for that
- **status:** 🟡 proposed — **fork, no proposal** (`OQ-E08-1`)
- **screen:** dashboard (`design/screens/dashboard.md`)
- **spec:** FR-STORE-006, NFR-SCALE-001 *(needs number)*
- **design shows:** `45% used` (element 16) — a percentage, which requires a
  total to divide by.
- **derived from:** nothing. `GAP-011` already recorded that no quota exists
  "anywhere in this schema or spec", and `dashboard_controller.dart` has
  carried `isMeasured: false` ever since rather than fabricate one. E08
  measures the numerator honestly (`E08-T02`) and still has no denominator.
- **the fork (a product decision, not a design one):** (a) a device-volume
  free-space reading, which needs a platform measurement Dart has no API
  for — reachable via Pigeon under ADR-0004 with **no new dependency**;
  (b) a user-set app storage budget with a human-supplied default, and the
  percentage computed against it; (c) no percentage at all — the card
  renders its real measured byte total, and the measured string `45% used`
  becomes a **disclosed deviation** with this entry as its reason.
- **no proposal is offered**, deliberately: every option here writes a
  number or a mechanism the spec does not contain, and `NFR-SCALE-001`'s
  missing number is exactly what `OQ-E08-1`/`OQ-E08-2` put to the human.
  Until it is answered, `E08-T08` ships option (c) and discloses it.
- **`OQ-E08-1` has since been answered — recorded here, not decided here
  (`E08-T07`, 2026-09-02).** The human answered on **2026-09-02**: **(a)**
  device free space via a Pigeon channel feeds Smart Mode's *pressure factor*,
  **+ (c)** the dashboard card shows the **real measured byte total, no
  fabricated percentage**; **(b)** a user-set budget is *deferred, not decided
  against* — `storage_policy_settings.budget_bytes` stays NULL and ready. The
  full text is in `epics/E08-local-storage/epic.md` §Open Questions. **This
  entry's own `approved by:` line stays bare**: answering the question is not
  the same act as signing off this gap entry, and an agent does not perform the
  second on the strength of the first (`L-process-002`). Both
  `design/screens/dashboard.md` §Derived state and
  `design/screens/settings-storage.md` render bytes accordingly and cite this
  entry as the deviation's reason.
- **approved by:** human, 2026-09-02 (approving this gap entry's record of
  the `OQ-E08-1` decision already made — not a new decision)
- **built:** not built

## GAP-027 — settings, the Storage row promises "export" and no requirement asks for it
- **status:** 🟡 proposed — **fork, no proposal** (`OQ-E08-T07-1`)
- **screen:** settings (`design/screens/settings.md`)
- **spec:** none — and that is the finding. `FR-STORE-001..007` cover
  storage, lifecycle, warnings and explanations. **No id anywhere requires
  an export.** The word appears only in a subtitle the design drew.
- **design shows:** element 30's subtitle, `Local cache, message retention,
  export`.
- **derived from:** nothing — a subtitle is not a specification, and
  building an export flow from one would be inventing scope from copy
  (this file's own rule: "a gap cites a spec id. No id → it's an idea").
- **the fork:** (a) export is real and needs an SRS amendment plus its own
  task, routed through `skills/change-impact`; (b) export is not v1 scope
  and the subtitle is a disclosed copy deviation on the settings row; (c)
  the subtitle stays as measured and the Storage screen simply has no
  export control, with this entry as the record of why.
- **still open after `E08-T07` (2026-09-02):** the contract
  `design/screens/settings-storage.md` was written with **no export element of
  any kind**, and says so in its §Derivation boundary 7 and §Open 2 rather than
  leaving the absence to be read as an oversight. **No proposal is added here**
  — all three forks above stand exactly as written, and picking one is the
  human's (`OQ-E08-T07-1`). Until then the Storage screen simply has no export
  control and `settings.md` element 31's subtitle stays as measured.
- **`OQ-E08-T07-1` resolved (human, 2026-09-02): fork (c).** No export
  control anywhere in this build. The `export` word in element 30/31's
  subtitle stays as a disclosed, measured copy artifact rather than a
  claim about built functionality — this entry is its record. Not
  routed through `skills/change-impact`: no scope was added or removed,
  since nothing was ever going to be built for it.
- **approved by:** human, 2026-09-02
- **built:** not built

## GAP-028 — new-device enrollment and the "no recovery" notice have no design source at all

- **status:** ✅ approved
- **screen:** _(new, derived)_ `design/screens/device-enrollment.md` (the
  NEW device's own journey) and `design/screens/device-enrollment-approval.md`
  (the EXISTING trusted device's approval prompt)
- **spec:** `FR-RECOVER-001` ("a new device shall be registerable using the
  user's authenticated account; where possible, an existing trusted device
  shall authorize the new device's enrollment"), `FR-RECOVER-002` ("if all
  cryptographic keys are permanently lost, encrypted historical content
  shall not be recoverable — intentional, not a defect");
  `spec/feature-list.md` → "Feature: Device Enrollment via Trusted Device".
- **design shows:** nothing. `login.md`/`welcome.md` cover Google sign-in
  only and stop at the dashboard redirect (E01-T01's own walking-skeleton
  scope) — neither shows what happens when the signed-in account already
  has other devices with local history this new device cannot read.
  `devices.md` shows an established device list (`Trusted Node`/`Allowed`/
  `Unknown`/`Blocked` rows) with no "a new device wants to join" state at
  all. No screen anywhere states the FR-RECOVER-002 "no recovery"
  property to a user.
- **derived from:** `devices.md`'s own row vocabulary is the closest fit
  for both derived screens — its status-chip treatment (`check_circle` /
  `rgb(78, 222, 163)` "Trusted Node"; `warning` / `rgb(245, 158, 11)`
  "Unknown" + a `Verify` button at `11px · rgb(53, 37, 205) · r4px`) is
  exactly the "peer needs a decision from me" shape `device-enrollment-approval.md`
  needs, just re-labelled. `welcome.md`'s centred-icon/heading/subtitle
  treatment (`60px`/`57px` display type, `14px rgb(211, 228, 254)` body)
  is the closest fit for `device-enrollment.md`'s waiting/notice states,
  since both are full-screen, single-focus moments before the dashboard
  is reached. `settings.md`'s row/subtitle shape covers the entry point
  (see below).
- **proposal — two screens, one journey:**
  1. **`device-enrollment.md`** (new device, reached after Google sign-in
     when the account already owns other devices, before the dashboard
     redirect): a choice state — "Ask a trusted device to let this one
     in" vs. "Continue without history" — in `welcome.md`'s centred
     layout with two stacked buttons (primary/secondary, reusing
     `welcome.md`'s own button treatment); a waiting state (spinner +
     a short device fingerprint/code, cancel action) once enrollment is
     requested; a success state (brief confirmation, then the existing
     dashboard redirect, no new screen needed); a denied/timeout state
     (plain restatement of the choice, no blame copy); and the **no
     recovery notice** — shown either after choosing "Continue without
     history" or after a timeout with no trusted device reachable,
     stating plainly that historical content on other devices cannot be
     recovered here (`FR-RECOVER-002`'s own "intentional, not a defect"
     framing belongs in this copy, not left implicit).
  2. **`device-enrollment-approval.md`** (existing trusted device,
     reachable while the app is foregrounded or via a notification per
     `E10`'s existing per-source notification mechanism — this screen
     covers the in-app prompt only, not the notification copy itself,
     which is `E10`'s own concern if this becomes a real notification
     category): one row, `devices.md`'s row shape, labelled with the
     requesting device's platform + a short fingerprint, an `Approve`
     button (primary treatment) and a `Deny` button (`devices.md`'s
     `Blocked`-row-adjacent red, `rgb(186, 26, 26)`, for the destructive
     option) side by side where `devices.md`'s single `Verify` button
     sits today.
  3. **Entry point**: `devices.md`'s existing "Journey gaps" section
     (currently "(none identified yet)") is the anchor — a pending
     enrollment request, once one exists, appears as a new row at the
     TOP of the existing device list using `device-enrollment-approval.md`'s
     row, not a separate screen navigation. This keeps `devices.md`
     itself the one place trust decisions about other devices are made,
     consistent with its own existing `Verify`/`Blocked` rows. **Not
     proposed here**: whether a push notification (E10) accompanies this,
     left to whichever task builds it, same reasoning `GAP-018` used for
     deferring `conversations.md`'s own entry-point affordance.
  4. States needed on `device-enrollment.md`: choice, waiting, denied/
     timeout, no-recovery-notice (success has no new screen — it falls
     through to the existing dashboard redirect). States needed on
     `device-enrollment-approval.md`: the one row (no separate loading/
     error state — this is a synchronous local decision, not a network
     round-trip in the UI's own terms, whatever the backend does
     underneath is out of this screen's concern).
- **approved by:** human (shajed99), 2026-09-05 — approved as proposed
- **built:** contracts written — `design/screens/device-enrollment.md` and
  `design/screens/device-enrollment-approval.md` (2026-09-05). Not built
  in code; the build tasks are prospective (`E12` task-sharding). Golden
  is extracted **after** the build, per `design-fidelity` §3.

## GAP-029 — the mandatory-update block has no design source at all

- **status:** ✅ approved
- **screen:** _(new, derived)_ `design/screens/version-update-required.md`
- **spec:** `FR-VER-006` ("WHEN installed version is UPDATE_REQUIRED, the
  system SHALL block communication and present a non-dismissible mandatory
  update prompt via Google Play"), `FR-VER-009` ("mandatory updates SHALL
  NOT delete local messages, recordings, attachments, settings, or
  history" — a behavioral constraint, not a visual one, noted here only
  so the copy doesn't imply data loss). `spec/srs.md`'s `FR-VER` block.
- **design shows:** nothing. No screen in this design draws a mandatory,
  non-dismissible block of any kind, and — material to how this must be
  derived — **the design draws no dialog or bottom-sheet primitive
  anywhere in the whole measured set** (`dashboard.md`'s own
  `warning-expanded` derived state, `GAP-025`, established this same
  finding: "the design draws no dialog or sheet primitive anywhere, and
  inventing one would be inventing a visual language"). A mandatory
  update block is at least as blocking as that state and must be derived
  the same way — as a full-screen state, never an invented dialog.
- **derived from:** `welcome.md`'s centred single-focus layout (icon,
  `28px`/`22px` heading sizes, `14px` body, stacked primary button) is
  this design's only existing "one decision, nothing else on screen"
  shape and the closest fit for a blocking, non-dismissible state.
  `devices.md`'s `warning` icon token (`rgb(245, 158, 11)`) is this
  design's own vocabulary for "needs attention," reused here rather than
  inventing a new severity colour.
- **proposal:** one screen, one state (this condition has no sub-states —
  it is reached, blocks, and is left only by actually updating): the
  `warning` icon at `welcome.md`'s icon size, a heading stating the app
  cannot be used until updated, body copy naming that local data is
  preserved (`FR-VER-009`, stated plainly so a blocked user is not left
  guessing whether updating will erase their history), and ONE primary
  button that opens Google Play's in-app update flow — no secondary
  button, no back navigation, no dismiss affordance of any kind (`FR-VER-006`'s
  "non-dismissible" is a structural absence, not a disabled-looking
  button — there is nothing else on this screen to tap). System back
  gesture/button handling (whether it's suppressed entirely or a no-op)
  is a behavioral decision for whichever task builds this, not a visual
  one this contract needs to settle.
- **out of scope for this gap:** the `UPDATE_AVAILABLE` (non-blocking,
  dismissible) state `FR-VER`'s own state machine also implies — this
  gap covers only the `UPDATE_REQUIRED` block `EARS-VER-1` names as its
  epic-level criterion. A dismissible "update available" nudge, if the
  design needs one, is a separate, smaller gap (likely a `settings.md` or
  `dashboard.md` row, not a full screen) and is not proposed here.
- **note:** `E14`'s own `OQ-E14-1` (where `FR-VER-004`'s simulation
  framework lives, this epic or `E04`) is unrelated to this gap and does
  not block it — that question has no UI surface either way.
- **approved by:** human (shajed99), 2026-09-05 — approved as proposed
- **built:** contract written — `design/screens/version-update-required.md`
  (2026-09-05). Not built in code; the build task is prospective (`E14`
  task-sharding). Golden is extracted **after** the build, per
  `design-fidelity` §3.

## GAP-030 — no way to start a new conversation with an already-trusted device

- **status:** ✅ approved
- **screen:** `design/screens/devices.md` (existing screen, one new
  per-row affordance — no new screen)
- **spec:** `FR-COMM-001` ("the system SHALL support sending/receiving
  text... in a 1:1 conversation") presumes a conversation can be reached
  in the first place; `spec/feature-list.md`'s Personal Chat feature.
- **design shows:** `conversations.md` lists existing conversations only
  (no compose/add affordance — `GAP-007`'s own empty-state note never
  proposed one either); `devices.md`'s established rows (`Trusted Node`/
  `Allowed`) offer only the kebab menu's `Block` action — no way to reach
  `chat.md` for a device with no conversation yet. Confirmed by live
  two-device on-hardware testing (2026-09-08, `E06-B05`'s own Run log):
  mutual Bluetooth trust between two real phones was established
  end-to-end, and there was then no in-app path to actually exchange a
  message — `ChatController`'s own `conversationId == peerDeviceId`
  convention means the mechanism exists in code, nothing in any screen
  ever reaches it for a peer with no prior message history.
- **derived from:** `devices.md`'s own row already carries a trailing
  kebab (`more_vert`, elements 12/20/28/36) for the one existing per-row
  action (`Block`). The closest existing primitive for a SECOND per-row
  action is the `Unknown` row's own `Verify` button (`OnProcessButtonWidget`,
  `11px · rgb(53, 37, 205) · r4px`, `devices.md`'s own measured value) —
  same button treatment, new icon/label, placed in the same trailing
  position, only on rows that already have somewhere to go (`Trusted`/
  `Allowed` — never `Unknown`, which has no session to message yet, and
  never `Blocked`, which must not gain a new way to reach a blocked peer).
- **proposal:** add a `Message` icon-button (`Icons.chat`, matching this
  app's own bottom-nav glyph for the same concept) to each `Trusted`/
  `Allowed` row, positioned before the existing kebab. Tapping it
  navigates to `Routes.chat` (`/chat/<deviceId>`, the peer's own device
  id as `conversationId` — already a real, working route with its own
  binding; nothing about the destination screen changes). No new screen,
  no new state on `devices.md` itself — this is the entry point
  `conversations.md`'s own empty state has never had, filed against
  `devices.md` instead since that is where a trust decision (and now a
  "start talking to them" decision) is already made about a specific
  device.
- **approved by:** human (shajed99), 2026-09-08 — approved as proposed,
  in response to a direct question about whether to build this now to
  complete real two-device hardware verification (`OQ-E06-T04-2`).
- **built:** prospective — `E06` (`E06-T14`, sharded same day as approval).

## GAP-031 — a Settings *destination* has no design source; eight of them are now needed at once

- **status:** 🟡 proposed
- **screen:** _(new, derived — a **shell**, not a screen)_
  `design/screens/settings-shell.md`
- **spec:** `FR-UI-006` (every Settings row navigates to a dedicated
  sub-screen), `FR-UI-008` (back returns to the hub).
- **design shows:** `settings.md` is a **menu and only a menu** — eight rows
  that lead somewhere, and *not one* of the somewheres is drawn anywhere in the
  measured set. `settings-storage.md` (GAP-024, approved 2026-09-02) already
  crossed this boundary once, for one row, and wrote down exactly how
  (§Derivation boundary 1–7, §Surface story). Nothing has changed about the
  design since.
- **derived from:** `settings-storage.md` itself — promoted from "one screen's
  private derivation" to **the shared shell all eight destinations use**.
  Concretely: `settings.md`'s frame and palette (the 40×40 `r9999px` header
  icon-button with its `24px` `rgb(195, 192, 255)` glyph; the screen
  title/subtitle pair; the card surface `rgb(26, 44, 66)` at `r12px` with the
  `rgba(199, 196, 216, 0.1)` hairline; `heading:3` at `22px` `w500`
  `rgb(248, 249, 255)`; the body line at `14px` `rgb(199, 196, 216)`; the
  tertiary glyph colour `rgb(119, 117, 135)`), plus `chat.md` element 2's
  `arrow_back` for the back affordance — the same cross-screen borrow
  `group-manage.md` GM2 and `settings-storage.md` §6 already make.
- **proposal:** one hand-written shell contract that fixes the frame once — back
  button, screen heading, screen subtitle, and the card/row vocabulary — and
  which each of the eight sub-screen contracts cites as its parent instead of
  re-deriving it. The eight contracts then describe **only their own content**.
  Nothing new is invented here at all: every value is already measured in
  `settings.md` or already derived and approved in `settings-storage.md`.
- **why a shell and not eight independent derivations:** eight agents each
  deriving a frame from the same parent will produce eight slightly different
  frames, and the gate will pass all eight (each is internally consistent with
  its own contract). That is the exact failure `design-fidelity` opens with,
  moved up a level.
- **out of scope:** the *content* of any individual screen — each has its own
  entry below.
- **approved by:**
- **built:** prospective — `E15-T03`.

## GAP-032 — Notifications settings screen (row 7) has no design source

- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/settings-notifications.md`
- **spec:** `FR-NOTIFY-003` (the screen), presenting `FR-NOTIFY-001`'s
  categories and `FR-NOTIFY-002`'s privacy level.
- **design shows:** `settings.md` elements 38-42 only — one row: `notifications`
  · `Notifications` · `Alerts, silent modes, LED behaviors`.
- **derived from:** `GAP-031`'s shell for the frame. For the per-category
  switches there is **no measured switch/toggle primitive anywhere in this
  design** — checked across all seven measured contracts. The nearest measured
  "this is currently on / this is currently off" vocabulary is
  `devices.md`'s `radio_button_checked` (element 21) /
  `dashboard.md`'s `radio_button_unchecked` (element 33), which
  `settings-storage.md` SS14-16 already uses for exactly this purpose (mode
  selection) and which GAP-024 approved.
- **proposal:** the shell frame; one card listing the **nine user-facing
  categories** (`message`, `voiceMessage`, `ptt`, `incomingCall`,
  `connectionRequest`, `trustRequest`, `groupEvent`, `securityEvent`,
  `storageWarning` — `backgroundService` is deliberately absent, it is not a
  user preference: `notification_tables.dart`'s own header), each a row with a
  title, a one-line description and the checked/unchecked glyph as its state;
  and a second card with the three privacy levels (`full`, `senderOnly`,
  `hidden`) in the same `settings-storage.md` mode-selector treatment.
- **the one honest disclosure this screen must carry:** `full` (sender name +
  message preview) **has no supported mechanism today** — plaintext is
  decrypted only in the screen layer, and a background dispatcher cannot reach
  it (`E10-T02`'s own header, `E06-T09.md:64-68`). The value is storable and
  stored; it is not honoured. Per `FR-UI-007` the screen states this on the
  `full` row rather than offering a control that silently does nothing.
- **fork, no proposal — `LED behaviors`:** the row's designed subtitle promises
  it. **No `FR-NOTIFY-*` id requires an LED control, and no code implements
  one.** Same shape as `GAP-027` (the Storage row's "export"), which the human
  resolved as (c) — no control, the subtitle stays a disclosed copy artifact.
  Named here rather than assumed: (a) mirror GAP-027 — no LED control;
  (b) add one, which is new scope needing a new FR id. **No proposal.**
- **approved by:**
- **built:** prospective — `E15-T04`.

## GAP-033 — Privacy & Security settings screen (row 2) has no design source

- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/settings-privacy.md`
- **spec:** `FR-SEC-005`, presenting `FR-SEC-001`, `FR-LOC-001`, `FR-LOC-002`,
  `FR-NOTIFY-002`.
- **design shows:** `settings.md` elements 13-17 only — `security` ·
  `Privacy & Security` · `Encryption protocols, app lock, permissions`.
- **derived from:** `GAP-031`'s shell; the on/off vocabulary from GAP-032; the
  per-peer list row from `devices.md` elements 8-15 (leading glyph, title,
  secondary line, trailing state) — this design's only measured
  "list of peers each with a state".
- **proposal:** the shell frame; a read-only **Encryption** card naming the
  protocol actually in force (`ADR-0003`: X3DH + Double Ratchet for 1:1, a
  sender-keys scheme for groups) with no control — it is not a setting;
  a **Location** card with the global switch (`LocationSettingsRepository
  .watchGlobalEnabled`/`writeGlobalEnabled`, shipped in `E09-T01`) and, beneath
  it, the per-peer rows from `readAllPeerEnabled()`; and a **Notification
  privacy** row that states the current level and navigates to
  `settings-notifications` rather than duplicating its control (one setting,
  one owner — the `E05-B03` "state defined in two documents" trap).
- **fork, no proposal — `app lock`:** the subtitle promises it. `ADR-0005`'s
  consequences say "the app implements its own local session/lock mechanism
  independent of Firebase Auth's session state" — but **no such lock exists in
  `lib/` and no FR id requires one**. Options: (a) GAP-027 treatment — no
  control, disclosed absence; (b) build an app lock, which is genuinely new
  scope (a new FR, plausibly a new ADR, certainly not this epic).
  **No proposal.**
- **fork, no proposal — `permissions`:** the subtitle promises it. Android
  runtime permissions are real and the app holds several
  (`FR-PLAT-003`), but nothing in `spec/` requires a permissions *screen*, and
  the platform already owns that UI. Options: (a) a read-only list of which
  permissions are granted, with a deep link to the OS settings; (b) GAP-027
  treatment. **No proposal.**
- **approved by:**
- **built:** prospective — `E15-T05`.

## GAP-034 — Security Center screen (row 3) has no design source

- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/settings-security-center.md`
- **spec:** `FR-DIAG-003`, presenting `FR-SEC-003`, `FR-ABUSE-001`,
  `FR-DIAG-001`, bounded absolutely by `FR-DIAG-002`.
- **design shows:** `settings.md` elements 18-22 only — `policy` ·
  `Security Center` · `Threat logs, network audits, certificates`.
- **derived from:** `GAP-031`'s shell; `devices.md`'s row-with-status-chip
  vocabulary for each record; `settings-storage.md` SS27's centred single-line
  empty treatment (itself GAP-002's approved treatment) for "nothing to show",
  which on a healthy install is the **expected** state, not an edge case.
- **proposal:** the shell frame and four read-only sections, each rendering
  records the app **already holds** and nothing else: device revocations
  (`DeviceRevocations`), trusted-identity records
  (`SignalTrustedIdentities`), blocked peers (`Relationships` where state is
  blocked), and abuse rate-limit denials (`RateLimitCounters`). No action
  affordance of any kind on this screen — it reports, it does not remediate;
  blocking/unblocking already lives on `devices.md` and must not gain a second
  home.
- **the prohibition this screen exists to keep:** `FR-DIAG-002` is absolute.
  No key material, no session material, no plaintext, no location. A record
  renders as *what happened, to which device id, when* — never as *what was in
  it*. Written into the contract, not only into the task, because a "security
  log" is the single most tempting place in this app to print a key.
- **fork, no proposal — `certificates`:** the subtitle promises it. This app has
  no certificate concept at all — `ADR-0003` is a Signal-protocol design with
  identity keys, not X.509. Options: (a) GAP-027 treatment; (b) render the
  identity-key fingerprints under that heading, which renames an existing
  concept to match a subtitle and is arguably worse. **No proposal.**
- **approved by:**
- **built:** prospective — `E15-T06`.

## GAP-035 — Account screen (row 1) has no design source, and must carry a destructive action

- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/settings-account.md`
- **spec:** `FR-AUTH-013` (the screen), `FR-AUTH-006`/`FR-AUTH-007` (the
  sign-out action it hosts and how it must be presented).
- **design shows:** `settings.md` elements 8-12 only — `account_circle` ·
  `Account` · `Profile, identity keys, linked devices`. **No sign-out, no
  destructive action, and no destructive treatment exists anywhere in the
  measured set** except `devices.md`'s `rgb(186, 26, 26)`, which carries
  *blocked/destructive* semantics (GAP-021 left its treatment explicitly
  undecided and it has stayed that way).
- **derived from:** `GAP-031`'s shell; `devices.md`'s row vocabulary for the
  linked-device list; `device-enrollment.md`'s already-approved treatment for
  presenting *this device's own* identity.
- **proposal:** the shell frame; an **Account** card (the signed-in Google
  account identifier from `DeviceIdentities.accountUid`); a **This device**
  card (the identity-key fingerprint, in the `JetBrains Mono` treatment
  `settings.md` already measures for machine values); a **Linked devices**
  list (`FirebaseMetadataService.readOwnDeviceIds`) in `devices.md`'s row
  shape; and, last on the screen and visually separated, a single **Sign out**
  row that navigates to `sign-out-confirm` (GAP-039) — never acting directly.
- **fork, no proposal — the destructive colour:** `rgb(186, 26, 26)` is the
  only red this design measures, and GAP-021 deliberately left "what
  destructive looks like" undecided rather than settling it by agent taste.
  Options: (a) reuse `rgb(186, 26, 26)` and thereby settle GAP-021 by
  precedent; (b) keep the Sign out row in the ordinary row treatment and carry
  the whole destructive weight on the confirmation screen (GAP-039), which
  already has nothing else on it. **No proposal** — this is the same decision
  GAP-021 parked, and it should be made once, deliberately, for both.
- **note:** `Profile` in the subtitle is satisfied by the account identifier;
  this app has no profile *object* and none is invented.
- **approved by:**
- **built:** prospective — `E15-T07`.

## GAP-036 — Network settings screen (row 4) has no design source

- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/settings-network.md`
- **spec:** `FR-ROUTE-010`, presenting `FR-DISC-001`, `FR-ROUTE-005`,
  `FR-ROUTE-007`, and satisfying `FR-UI-004`'s "advanced technical detail one
  tap away, not shown by default".
- **design shows:** `settings.md` elements 23-27 only — `wifi_tethering` ·
  `Network` · `Data usage, mesh routing, proxy`.
- **derived from:** `GAP-031`'s shell; `dashboard.md`'s already-measured
  connectivity vocabulary (this design's own way of saying what the network is
  doing); `devices.md`'s row-with-status for per-destination routes.
- **proposal:** the shell frame; a **Transports** card listing the transports
  the platform reports available (`TransportService`); a **Routes** card
  listing, per reachable destination, the active route's hop count and its
  measured link quality (`RoutingEngine.activeRouteFor`, `LinkQuality`) — each
  in `devices.md`'s row shape. Read-only: there is no user-settable routing
  knob in `spec/` and none is invented.
- **`FR-ROUTE-010`'s "unavailable rather than a value" clause is load-bearing
  here.** `RoutingEngine` and `RouteCostCalculator` already report some cost
  factors as unavailable rather than defaulting them (`E08-T04` set this
  precedent for storage and `FR-ROUTE-007` is still `[NEEDS FORMULA]`,
  `Q-ARCH-004`). The screen renders "unavailable", never a zero.
- **fork, no proposal — `Data usage` and `proxy`:** the subtitle promises both.
  **Neither exists**: nothing in `lib/` meters bytes, and this app has no proxy
  concept at all. Options: (a) GAP-027 treatment for both; (b) add byte
  metering, which is new scope and a new FR. **No proposal.**
- **approved by:**
- **built:** prospective — `E15-T08`.

## GAP-037 — Battery settings screen (row 6) has no design source

- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/settings-battery.md`
- **spec:** `FR-PLAT-004`, presenting `FR-PLAT-001`, `FR-PLAT-002`,
  `NFR-BATT-001`.
- **design shows:** `settings.md` elements 33-37 only — `battery_full_alt` ·
  `Battery` · `Background execution, power saving modes`.
- **derived from:** `GAP-031`'s shell; `devices.md`'s row-with-status for each
  restriction; the same read-only posture as GAP-036.
- **proposal:** the shell frame; a **Background operation** card stating
  whether the foreground service is currently running; a **Restrictions in
  effect** list (Doze, Battery Saver, background-execution restriction — the
  three `FR-PLAT-002` names, read from `PowerState`), each a row with a state
  label; and the resulting **Background plan** (`BackgroundPlan`) stated
  plainly. Where the platform exposes it, one row deep-links to the OS's own
  battery-optimization settings — `FR-PLAT-004` explicitly forbids
  reimplementing them.
- **fork, no proposal — the deep link:** opening the OS battery settings needs
  a platform call this app's Pigeon boundary does not have today
  (`ADR-0004`). Options: (a) add it to the existing background Pigeon API —
  small, but it is a native-boundary change; (b) ship the screen read-only with
  no deep link. **No proposal.**
- **approved by:**
- **built:** prospective — `E15-T08`.

## GAP-038 — About / Updates screen (row 8) has no design source

- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/settings-about.md`
- **spec:** `FR-VER-012`, presenting `FR-VER-005`, `FR-VER-008`,
  `FR-DIAG-001`, bounded by `FR-DIAG-002`.
- **design shows:** `settings.md` elements 43-47 only — `info` ·
  `About / Updates` · `Version 2.4.1, release notes, diagnostic logs`.
- **derived from:** `GAP-031`'s shell; `version-update-required.md`'s
  already-approved version vocabulary; `settings-storage.md`'s `JetBrains Mono`
  treatment for machine values.
- **proposal:** the shell frame; a **Version** card (installed version and
  build number from `PackageInfo`, and the version state
  `EvaluateVersionStateUseCase` evaluates to); a **Policy** card (the cached
  minimum-supported build and when it was last fetched,
  `VersionPolicyService.cached()`); and a **Diagnostics** section rendering the
  local log, subject in full to `FR-DIAG-002`.
- **a disclosed copy artifact, already shipped:** `settings.md` element 46
  measures the literal string `Version 2.4.1, release notes, diagnostic logs`
  and the gate compares it character for character. **The real build number is
  not 2.4.1 and never will be.** That string is on the *hub* row, which
  `E02-T03` already built and gated; it is recorded here so nobody "fixes" it
  into a dynamic value and reds the `settings` gate. The **sub-screen** shows
  the real version; the hub row keeps the design's literal copy. Same class of
  artifact as `GAP-027`.
- **fork, no proposal — `release notes`:** the subtitle promises them. There is
  no release-note source, local or remote, and no FR requires one. Options:
  (a) GAP-027 treatment; (b) a link out to the Play listing, which is a new
  external dependency on a page this app does not control. **No proposal.**
- **approved by:**
- **built:** prospective — `E15-T10`.

## GAP-039 — the sign-out confirmation has no design source, and must not be a dialog

- **status:** 🟡 proposed
- **screen:** _(new, derived)_ `design/screens/sign-out-confirm.md`
- **spec:** `FR-AUTH-007` (destructive, irreversible, explicit confirmation
  naming what is lost), citing `FR-AUTH-006` for the scope of the loss and
  `FR-RECOVER-002` for why it is unrecoverable.
- **design shows:** nothing. No confirmation of any kind anywhere in the
  measured set — and, materially, **this design draws no dialog or
  bottom-sheet primitive anywhere**, a finding `GAP-025` established and
  `GAP-029` re-confirmed and acted on.
- **derived from:** `welcome.md`'s centred single-focus layout — this design's
  only "one decision, nothing else on screen" shape — exactly as `GAP-029`
  derived the mandatory-update block. `devices.md`'s `warning` token
  (`rgb(245, 158, 11)`) is this design's own vocabulary for "needs attention"
  and is reused rather than inventing a severity colour.
- **proposal:** one full screen, one state. The `warning` glyph at
  `welcome.md`'s icon size; a heading naming the action; body copy that states
  **plainly and specifically** what is destroyed — this device's identity and
  keys, every message and its history, every trusted relationship, every
  group, and all settings — and that content encrypted under those keys can
  never be recovered (`FR-RECOVER-002`, stated so a user is not left guessing);
  then two stacked affordances, the destructive confirm and a cancel that
  returns to `settings-account`. **A dialog is forbidden here** for the same
  reason `GAP-029` forbade one: inventing a dialog primitive invents a visual
  language.
- **why a whole screen for a confirmation:** because the alternative in this
  design is inventing one. It is also the correct weight — this is the single
  most destructive action in the product, and it is irreversible.
- **fork, inherited from GAP-035 — the destructive colour:** the same
  unresolved question. Whatever GAP-035 is answered as applies here.
- **out of scope:** any "are you sure?" second confirmation, any typed
  confirmation phrase, and any progress/spinner state during the wipe — none
  of the three has a measured precedent, and the first two are scope the spec
  does not contain.
- **approved by:**
- **built:** prospective — `E15-T07`.

## GAP-040 — Privacy & Security must SAY it has no app lock or permissions manager, not just omit them

- **status:** ✅ approved
- **screen:** `design/screens/settings-privacy.md` (adds PV22 to the
  already-approved GAP-033 contract; not reopening GAP-033 itself, which
  stands as the human cleared it 2026-09-08).
- **spec:** `FR-UI-007`, specifically `EARS-UI-9`'s second clause — "WHERE a
  Settings row's subtitle names a capability the application does not
  implement, the sub-screen SHALL state the absence **and** SHALL NOT
  present a control or a value for it." `E15-T05` round 2 review
  implemented the second half (no control — closed-set allowlist test,
  this same round) but never the first: the "SHALL state the absence"
  clause had no rendered element anywhere, because GAP-033's own two forks
  (app lock, permissions) were carried as forks with **no proposal** and
  nothing was ever built against either.
- **design shows:** nothing — same as GAP-033 itself. The `settings.md` hub
  row's subtitle (`Encryption protocols, app lock, permissions`) is the
  only place either word appears in the measured design.
- **derived from:** `settings-privacy.md`'s own SH7 body-line vocabulary —
  the same style PV6 and PV17 already use for a plain factual statement
  about what this screen does and doesn't do. No new token, no new
  component: this is one more SH7 line, placed at the end of the screen's
  content the way PV2's subtitle sits outside any card.
- **the fork this closes:** GAP-033 carried two forks with no proposal —
  "fork, no proposal — `app lock`" and "fork, no proposal — `permissions`"
  — each offering, as option (a), the `GAP-027` treatment: no control,
  disclosed absence. GAP-027's own resolution (`OQ-E08-T07-1`, human,
  2026-09-02) applied that as a **silent omission** (no control, no
  on-screen text either) — sufficient there because nothing in
  `settings-storage.md`'s own spec required stating the absence. Here
  `EARS-UI-9` itself requires the statement, so silent omission alone does
  not satisfy the criterion. This entry adds the missing half: the same
  "no control" answer, plus one rendered line saying so, because the EARS
  criterion — not agent taste — requires it.
- **proposal (now built, per the human decision below):** one new element,
  PV22, an SH7 body line reading `App lock and a permissions manager are
  not available in this version.`, placed after the Location sharing card,
  outside any card (same "generic, outside a card" placement PV2's
  subtitle already uses). No icon, no control, no link — a statement only.
- **approved by:** human, 2026-09-09 — direct decision in the E15-T05
  round-3 review-fix session (not an agent assumption): "add a new small
  text element to the screen stating that app lock and permissions
  controls are not implemented," closing both of GAP-033's no-proposal
  forks the same way, in favour of `GAP-027`'s option (a) plus the
  explicit statement `EARS-UI-9` itself requires. Not routed through
  `skills/change-impact`: this narrows an already-forked absence into a
  disclosed statement of that same absence — it adds no control, no
  write path and no new capability, so there is no scope to assess an
  impact against.
- **built:** `E15-T05` (round 3) — `lib/features/settings/privacy/presentation/privacy_settings_view.dart`,
  `design/screens/settings-privacy.md` PV22, golden regenerated.

## GAP-041 — chat, the header avatar has no real image data source

- **status:** 🟡 proposed
- **screen:** chat (`design/screens/chat.md`)
- **spec:** no FR currently requires a real avatar image; found as a
  by-product of `E06-B07` (design-probe root-cause pass), not proposed by
  a task that set out to build avatars.
- **design shows:** element 3 — an `image` role, 38×38, at the header's
  avatar position (`design/screens/chat.md`'s own element table). This app
  (`chat_view.dart`'s `_Header`) renders a 38×38 `Container` filled with
  the peer's initials text instead — the same "no per-device/per-peer
  image data source yet" situation `GAP-003` names for the **devices**
  screen, but `GAP-003` is explicitly scoped to that screen and to
  name/transport metadata, not to chat's own avatar — so this is its own,
  previously-unlogged gap, not a re-use of GAP-003 (found and corrected
  during `E06-B07`'s independent review, round 1 — the code comment at
  `chat_view.dart:130` citing "GAP-003 precedent" was itself the error
  this entry fixes: a real gap existed, it just had never been given its
  own name).
- **derived from:** the same initials-fallback pattern already established
  for this exact situation elsewhere in this codebase (`_Header`'s own
  `_initialsOf` helper, and the devices screen's own row-icon fallback
  under `GAP-003`) — no new visual language, same avatar-backdrop token
  (`_avatarBackdrop`) and initials-in-a-circle shape the golden's own
  avatar position measures.
- **proposal:** keep rendering the initials fallback (as already built)
  until a real avatar-image data source exists (a peer-supplied profile
  image, if this product ever adds one — no spec currently requires it);
  no code change proposed by this gap entry itself.
- **approved by:**
- **built:** already built as the initials fallback (`E06-T11`,
  `chat_view.dart`'s `_Header`) — this entry only gives that pre-existing,
  undisclosed divergence a name and an owner; no new build implied unless
  a future FR requires a real image.

## GAP-042 — devices, the overflow menu has no reverse action for a blocked row

- **status:** 🟢 built
- **screen:** devices (`design/screens/devices.md`)
- **spec:** `FR-BLOCK-001` — blocking prevents direct communication; nothing
  makes it one-way. Found via human live-device testing (`E02-B01`), not a
  design-probe finding.
- **design shows:** element 24 (`devices.md`'s own element table), a
  `PopupMenuButton` with a single measured item, `Block`. The design has
  no row state for "already blocked" and so no measured second item either.
- **derived from:** the same `PopupMenuItem<String>` primitive already in
  this exact menu (`devices_view.dart`), and the same
  `RelationshipRepository.upsert` call `DevicesController.verify()` already
  makes for the Unknown → Allowed transition — no new visual language, no
  new backend capability, just a second label on an existing menu wired to
  an existing repository call with a different target state.
- **proposal:** for a row whose `RelationshipState` is `blocked`, the menu
  item reads `Unblock` instead of `Block`; selecting it calls the new
  `DevicesController.unblock(deviceId)`, restoring `RelationshipState.
  allowed` (mirroring `verify()`'s own choice of tier, not `trusted`).
- **approved by:** human request, 2026-09-13 (live device testing:
  "If i block someone, no button for unblock or anything") — direct
  instruction to add it, not a proposal awaiting sign-off.
- **built:** `E02-B01`, 2026-09-13.

## GAP-043 — devices, this device's own Bluetooth name has no display anywhere

- **status:** 🟢 built
- **screen:** devices (`design/screens/devices.md`)
- **spec:** `FR-DISC-001` — no FR requires this specific display; found via
  human live-device testing (`E04-B19`), same category as `GAP-042`.
- **design shows:** element 5 (`devices.md`'s own element table), the
  fixed subtitle "Manage paired and nearby devices." The design has no
  element for this device's own identity anywhere on the screen.
- **derived from:** the existing `devicesSectionSubtitle` text token,
  same style as element 5 immediately above it — no new visual language,
  just an additional line rendered only once the native value resolves.
- **proposal:** a new subtitle line, "Visible to nearby devices as:
  &lt;name&gt;", populated from a new `TransportApi.getLocalDeviceName()`
  Pigeon call (`BluetoothAdapter.name`). Deliberately the device's Bluetooth
  **name**, never its address — `E04-B17`/`E04-B18`'s own live findings
  showed a raw Bluetooth address read back from the OS can be a generic,
  non-unique masked placeholder on some OEM builds, which would make an
  "address" display actively misleading; the name is what a peer's own OS
  pairing UI actually shows, so it is the only value that helps a user
  complete a real pairing.
- **approved by:** human request, 2026-09-13 (live device testing:
  "add own device mac name somewhere. So user can understand what to
  connect") — direct instruction, narrowed from the literal request (a MAC
  address) to the device name for the reason above, disclosed rather than
  silently substituted.
- **built:** `E04-B19`, 2026-09-13.

## GAP-044 — settings-privacy, FR-TRUST-006's connection-request controls have no design source

- **status:** 🟡 proposed — the human approved the design pass on
  2026-09-22; the element scope below still needs its own sign-off
- **screen:** settings-privacy (`design/screens/settings-privacy.md`) — an
  **extension of the built screen**, not a new one (the same shape `GAP-023`
  used to extend `GAP-014`)
- **spec:** `FR-TRUST-006` — of its six configurable rules, *location access*
  is built (PV16-PV20, `LocationSettingsRepository`, `E09-T01`) and *block
  specific users* lives on `devices.md`. The other four — auto-accept trusted
  devices, auto-accept specific users, require authentication for unknown
  users, and allow/disable communication — have **no surface anywhere**.
- **design shows:** nothing. `settings.md`'s Privacy & Security row (elements
  13-17) is a menu entry; the built screen covers encryption, notification
  privacy and location only.
- **derived from:** the built contract's own measured primitives only — `SH5`
  section card, `SH6` `heading:3`, `SH7` row, `SH8` glyph, `SH12` state label,
  `SH13` empty/error copy. **No new primitive is introduced.**
- **proposal:** one new section, `Connection requests`, elements PV23-PV30:

  | id | role | control | backing |
  |---|---|---|---|
  | PV23 | section card (`SH5`) | — | existing primitive |
  | PV24 | `heading:3` — `Connection requests` | — | `SH6` |
  | PV25 | row + toggle | **Auto-accept trusted devices** | `FR-TRUST-004`, already built and tested (`EARS-TRUST-1`) |
  | PV26 | row + toggle | **Require authentication for unknown senders** | wires the inert `requireAuthForUnknown` flag |
  | PV27 | row → sub-list | **Auto-accept specific people** | wires the inert `autoAcceptSpecific` flag |
  | PV28 | ⛔ **not specified** | *allow/disable communication* | **blocked on `Q-FUNC-011`** — scope undecided, see below |
  | PV29 | row → `/devices` | **Blocked devices** — reports the count and navigates; offers **no action** | preserves §Derivation-boundary item 5's single home for blocking |
  | PV30 | `generic` | empty / error copy | `SH13` |

- **PV28 is deliberately unspecified.** `FR-TRUST-006`'s "allow/disable
  communication" has no defined scope — new connection requests only, or
  existing conversations too. Raised as **`Q-FUNC-011`** and left open by
  human decision, 2026-09-22. **PV28 is the only blocked element**; PV23-PV27,
  PV29 and PV30 are unaffected by it.
- **prerequisite, not a design question:** there is **no settings store**.
  `LocationSettingsRepository` persists the location toggles; nothing persists
  trust preferences. PV25-PV27 need one before they are more than decoration,
  and wiring them is what finally makes `autoAcceptSpecific` /
  `requireAuthForUnknown` live (`OQ-E02-T01-2`). **No test passes either flag
  as `true` today**, so both branches need first-time coverage.
- **supersedes:** `GAP-005`'s proposal, which predates this screen existing.
  `GAP-005` asked for a Privacy & Security sub-screen for `FR-TRUST-006`;
  `IMP-003` caused one to be built (`GAP-033`, `E15-T05`) scoped to location
  and notification privacy instead. This entry records the remainder.
- **approved by:** _(pending — element scope)_
- **built:** not built — this entry is the proposal only.

## GAP-045 — a blocked member's message in a group thread has no words
- **status:** 🟢 **approved — option (b), human, 2026-09-25.** Was
  🟡 proposed and blocking the whole `E07-T18` build; unblocked by that
  answer.
- **screen:** chat-group (`design/screens/chat-group.md`, state 3) — element
  `G10`
- **spec:** FR-COMM-002, FR-TRUST-004
- **design shows:** nothing. The design source draws a 1:1 thread only, and
  neither GAP-020 nor the human's 2026-09-25 `OQ-E07-13` answer supplies copy.
  The answer fixes the **behaviour** — *"a blocked member's messages should
  remain represented as placeholders rather than being silently dropped or
  rendered as normal readable messages"* — and behaviour is not words.
- **why the existing placeholder cannot be reused:** `chat_view.dart:355`
  already renders `(unable to decrypt this message)` for a null plaintext.
  For a blocked member that sentence is **false**: a blocked member is still a
  group member holding a valid sender key, so the message usually decrypts
  without difficulty. It is withheld by **policy**, not by failure. Reusing
  that string would make the app misreport its own reason.
- **derived from:** nothing yet — that is the gap. Whichever string is chosen
  renders in the measured inbound bubble box (`chat.md` 12/15/20); no new
  colour or size is proposed for it.
- **options, none chosen:**
  - (a) `Message from a blocked contact`
  - (b) `Message hidden — contact is blocked` — says *why*, at the cost of
    being longer than any other bubble string in the app.
  - (c) `Blocked` — matches the one-word register `devices.md` uses for its
    status chips, but reads as a label on the *message* rather than its sender.
- **approved by:** _(pending — which of (a)/(b)/(c), or none)_
- **built:** _(not yet — `E07-T18` builds states 1, 2, 4 and 5 and leaves
  state 3 for whichever string is chosen)_

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

## GAP-046 — no design source draws a navigation rail or drawer (FR-UI-003's medium/expanded width classes)
- **status:** ⏸ **deferred out of v1 by human decision, 2026-09-25** — not
  proposed, not approved, not built. Recorded so the absence is a decision
  with a date on it rather than an oversight nobody wrote down.
- **screen:** all four navigation-bearing screens — `dashboard`,
  `conversations`, `devices`, `settings`
- **spec:** FR-UI-003
- **design shows:** the **compact** width class only. `conversations.md`
  elements 34-45 (and the matching rows on the other three) draw a four-
  destination bottom bar: Dashboard, Conversations, Devices, Settings. No
  contract in `design/screens/` draws a `NavigationRail` or a
  `NavigationDrawer` at any viewport; every contract is measured at
  `390x844` alone.
- **implementation state, measured 2026-09-25:** `grep` for
  `NavigationRail`, `NavigationDrawer`, `MediaQuery` width logic and
  `LayoutBuilder` across `lib/` returns **0 matches**. Four views hand-build
  a `_BottomNav`. Compact is built and designed; medium and expanded are
  neither.
- **derived from:** _(nothing — deferred before any derivation was
  attempted, deliberately: deriving a rail and a drawer from a design that
  draws neither, for form factors v1 does not ship on, is exactly the
  invented-journey work rule 2 forbids)_
- **human decision, 2026-09-25, verbatim:** *"Treat medium/expanded
  responsive navigation as a tablet/foldable scope item rather than blocking
  phone usability. Record the deferral explicitly; do not fabricate
  NavigationRail/NavigationDrawer implementation."*
- **approved by:** n/a — a deferral, not a derivation. Nothing here is
  approved for build because nothing here is proposed for build.
- **built:** _(no, and deliberately not)_
- **consequence, stated plainly:** `FR-UI-003` stays a **blocking orphan** in
  `make trace`. That is correct and must not be "fixed": the requirement
  genuinely has no full implementation and no test. Writing a test against
  the compact half and marking the requirement covered would convert a real
  gap into bookkeeping — the precise failure `docs/product-completeness-
  audit.md` exists to document.

## GAP-047 — the send affordance has no glyph, on any screen
- **status:** 🟡 proposed — **not built.** `E07-T18` ships the group
  composer with no send button at all rather than invent one.
- **screen:** chat-group (`design/screens/chat-group.md`, G7) — and, in
  passing, `chat.md` itself
- **spec:** FR-COMM-001, FR-COMM-002
- **design shows:** a 48×48 `r9999px` button on the accent fill
  `rgb(53, 37, 205)` carrying the glyph **`mic`** (`chat.md` elements
  30-31). The design source draws **no send glyph anywhere**, and
  `grep` confirms none of the other contracts does either.
- **the consequence, already shipping:** `chat_view.dart:479` renders that
  `mic` faithfully, so the 1:1 chat screen's only round accent button is a
  microphone that does not record (voice is GAP-014, unbuilt). Messages are
  sent from the **keyboard's own send key**. That is the designed behaviour
  being followed, not a defect introduced by a build — but it is worth
  naming, because a user reasonably reads a prominent round button next to
  a text field as "send".
- **derived from:** _(nothing — that is the gap. The button's geometry,
  fill and glyph size are all measured; only the glyph IDENTITY is missing,
  exactly the shape GAP-014 handled for record-stop/play/pause.)_
- **options, none chosen:**
  - (a) `send` — the Material Symbols paper-plane, the near-universal
    convention. A new glyph identity in this app.
  - (b) `arrow_upward` — also new, but a weaker convention.
  - (c) keep the composer button-less on every screen and send only from
    the keyboard, and change `chat.md`'s `mic` to something honest when
    GAP-014's voice work lands. Invents nothing; leaves the round button on
    the 1:1 screen still reading as "send" until then.
- **approved by:** _(pending — which of (a)/(b)/(c))_
- **built:** _(no. `E07-T18`'s composer submits from the keyboard's send
  key, which is exactly what the shipped 1:1 composer already does, so no
  new behaviour and no new glyph enters the app.)_
