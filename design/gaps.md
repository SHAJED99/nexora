# Design gaps — what the design doesn't cover, and what we'll do about it

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
