---
id: settings-privacy
impl_path: /settings/privacy
source: derived
derived_from: [settings-shell, settings, devices, settings-storage]
states: [default, loading, empty, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-SEC-005, FR-SEC-001, FR-LOC-001, FR-LOC-002, FR-NOTIFY-002, FR-UI-006, FR-UI-007, FR-UI-008, FR-TRUST-006]
gap: [GAP-033, GAP-044]
---
# settings-privacy · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **one row**: `settings.md` elements 13-17 (`security` · `Privacy & Security` ·
> `Encryption protocols, app lock, permissions`).
>
> **Built against `GAP-033`, 🟡 proposed and NOT approved** (bare
> `approved by:`, `L-process-002`). Frame from
> `design/screens/settings-shell.md` (`GAP-031`, also 🟡).
>
> **No golden until the build exists** — `design-fidelity` §3, same as every
> derived screen in this repo.

- **Route:** `/settings/privacy`, from `settings.md`'s Privacy & Security row.
  Route registration and row wiring are **`E15-T11`'s**, not this screen's.
- **Source of truth:** `LocationSettingsRepository`
  (`lib/features/location/data/`, shipped `E09-T01`) —
  `watchGlobalEnabled`/`writeGlobalEnabled`, `readAllPeerEnabled`,
  `writePeerEnabled`. Notification privacy is **read only** here; its writer is
  `settings-notifications`. `ADR-0003` supplies the protocol names, which are
  static text, not state.

## The prohibition this screen exists to keep

**The notification privacy level has exactly one writer, and it is not this
screen.** PV12 states the current level and navigates to
`/settings/notifications`. It does not offer the three options. Two screens
writing one setting is the "state defined in two documents" trap `E05-B03`
already cost this project once; one row that *reports and points* costs
nothing and cannot drift.

## Elements — the build checklist

Frame: SH1-SH4, with SH3 = `Privacy & Security`.

| id | role | copy / label | styling source |
|---|---|---|---|
| PV1 | `heading:2` | `Privacy & Security` | SH3 |
| PV2 | `generic` | `What this device protects, and what it shares.` | SH4 |
| PV3 | `generic` | section card | SH5 |
| PV4 | `generic` | `security` glyph, `rgb(103, 244, 183)` | SH8, `settings.md` element 14 |
| PV5 | `heading:3` | `Encryption` | SH6 |
| PV6 | `generic` | `Every private message is end-to-end encrypted. This cannot be turned off.` | SH7 |
| PV7 | `generic` | `Direct messages` + machine value `X3DH + Double Ratchet` | SH7 + SH11 |
| PV8 | `generic` | `Group messages` + machine value `Sender Keys` | SH7 + SH11 |
| PV9 | `generic` | section card | SH5 |
| PV10 | `heading:3` | `Notification privacy` | SH6 |
| PV11 | `generic` | current level, one of `Hidden` / `Sender only` / `Full` | SH10 (state label) |
| PV12 | row | `Change in Notifications` + `chevron_right` | SH7 + SH9, `settings.md` element 17 |
| PV13 | `generic` | section card | SH5 |
| PV14 | `generic` | `location_on` glyph, `rgb(195, 192, 255)` | SH8 — glyph `[pending human confirmation]`, see §Derivation boundary 4 |
| PV15 | `heading:3` | `Location sharing` | SH6 |
| PV16 | row | `Share my location` + state | SH7 + SH12 |
| PV17 | `generic` | `When this is off, no one can see your location, whatever their own setting says.` | SH7 |
| PV18 | `heading:3` | `Per person` | SH6 |
| PV19 | row ×N | one per peer with a location setting — peer id + state | `devices.md` row shape via SH8/SH7/SH12 |
| PV20 | `generic` | `No one has location sharing turned on yet.` | SH13 |
| PV21 | `generic` | `Settings could not be read.` | SH13 |
| PV23 | `generic` | section card | SH5 — `GAP-044` |
| PV24 | `heading:3` | `Connection requests` | SH6 — `GAP-044` |
| PV25 | row | `Auto-accept trusted devices` + state | SH7 + SH12 — `GAP-044` |
| PV26 | row | `Require authentication for unknown senders` + state | SH7 + SH12 — `GAP-044` |
| PV27 | row | `Auto-accept specific people` + `chevron_right` | SH7 + SH9 — `GAP-044` |
| PV29 | row | `Blocked devices` + count + `chevron_right` — navigates to `/devices`, no action here | SH7 + SH9 + SH12 — `GAP-044` |
| PV30 | `generic` | `Connection settings could not be read.` | SH13 — `GAP-044` |
| PV22 | `generic` | `App lock and a permissions manager are not available in this version.` | SH7, `GAP-040`, human-approved 2026-09-09 |

## Copy — verbatim

- `Privacy & Security`
- `What this device protects, and what it shares.`
- `Encryption`
- `Every private message is end-to-end encrypted. This cannot be turned off.`
- `Direct messages` · `X3DH + Double Ratchet`
- `Group messages` · `Sender Keys`
- `Notification privacy`
- `Change in Notifications`
- `Location sharing`
- `Share my location`
- `When this is off, no one can see your location, whatever their own setting says.`
- `Per person`
- `No one has location sharing turned on yet.`
- `Settings could not be read.`
- `App lock and a permissions manager are not available in this version.`
- `Connection requests`
- `Auto-accept trusted devices`
- `Require authentication for unknown senders`
- `Auto-accept specific people`
- `Blocked devices`
- `Connection settings could not be read.`

PV17 is not decoration: `FR-LOC-003` makes the global switch an **AND** over
four conditions, and a user who does not know that will read a per-person "on"
row as a promise the global switch silently overrides.

## States

1. **`default`** — three cards, real values, plus PV22.
2. **`loading`** — frame and cards render, values unpopulated. No spinner.
   PV22 still renders — it is a static statement, not a read.
3. **`empty`** — the per-person list only: PV20. The global switch and the
   encryption card are unchanged — an empty peer list is the ordinary state on
   a new install, not an error.
4. **`error`** — PV21 replaces the affected card's values only. **The global
   location switch is never cleared by a failed read of something else**
   (`settings-shell.md` §States).

PV22 is constant across every state above: it names a capability this build
never implements, not a value read from a repository, so no failure mode
touches it (`GAP-040`).

## Derivation boundary — what is NOT derived

1. **No app lock, and no placeholder for one.** The hub row's subtitle promises
   it and `ADR-0005`'s consequences mention "its own local session/lock
   mechanism" — but **no lock exists in `lib/` and no FR id requires one**.
   `GAP-033` carried this as a fork with **no proposal**; `GAP-040` (human,
   2026-09-09) closed it in favour of the `GAP-027` "no control" answer, plus
   PV22's explicit statement of the absence (`EARS-UI-9`'s second clause).
   Building an actual lock from a subtitle and an ADR consequence would still
   be inventing scope; a disabled control for it would be worse — PV22 is a
   sentence, not a control.
2. **No permissions list.** Same fork, same reason, same `GAP-040` resolution:
   nothing in `spec/` requires a permissions screen, Android already owns that
   UI, and PV22 states the absence rather than drawing a list.
3. **No protocol *choice*.** PV7/PV8 are read-only statements of fact.
   `ADR-0003` is an accepted architectural decision, not a preference; a
   control here would imply otherwise.
4. **`location_on` is flagged.** It is the natural Material Symbols name and
   matches this design's glyph family, but it is **not measured in any
   contract** — unlike every other glyph on this screen. Flagged
   `[glyph — pending human confirmation]` rather than asserted, per
   `settings-shell.md` §5.
5. **No block/unblock control.** Blocking lives on `devices.md` and keeps
   exactly one home (see also `settings-security-center.md`, which reports
   blocks and also offers no action).
7. **No duplicate block control, and no PV28.** PV29 reports the blocked-device
   count and navigates to `/devices`; it offers no action, so item 5 above
   still holds and blocking keeps exactly one home — two writers for one list
   is the trap `E05-B03` cost this project once. **PV28 is absent on purpose:**
   `FR-TRUST-006`'s "allow/disable communication" has no defined scope, raised
   as `Q-FUNC-011` and left open by human decision (2026-09-22). Drawing a
   control for an undecided behaviour would be inventing the behaviour.
   (`GAP-044`)
6. **No location history and no map.** `FR-LOC-004` explicitly forbids a
   permanent location store; a history view would imply one exists.
