---
id: E09
title: Location Sharing
status: in-progress
type: feature
priority: { moscow: could, wsjf: 3.7 }
depends_on: [E02, E03, E04]
traces_to: [FR-LOC-001, FR-LOC-002, FR-LOC-003, FR-LOC-004, FR-LOC-005]
external_services: []
ui_surface: [mobile]
design_screens: [settings]
---
# E09 · Location Sharing

## Business goal
Let users share live location with per-contact granularity, encrypted,
gated by connection + authorization + global + per-user toggles all
holding simultaneously.

## Scope
**In scope:** global + per-user toggles, the four-condition visibility gate
(connected AND authorized AND global-on AND per-user-on), encrypted location
data, last-known-location-with-timestamp fallback (never presented as live).
**Out of scope:** the UI screens showing another user's location on a map —
map-widget design isn't in the current design contracts; a gap-pass item
for this epic's task-sharding.

## Acceptance criteria (epic-level, EARS)
- **EARS-LOC-1**: The system SHALL show a user's location only when connected AND authorized AND global-sharing-on AND per-user-sharing-on ALL hold. (FR-LOC-003)
- **EARS-LOC-2**: IF live location is unavailable, THEN the system MAY show last-known location with a visible timestamp, and SHALL NOT present it as live. (FR-LOC-005)
- **EARS-LOC-3**: The system SHALL persist a single app-wide location-sharing setting, defaulting to off. (FR-LOC-001)
- **EARS-LOC-4**: The system SHALL persist a per-user location-sharing setting that is *additional to* the global one — per-user on with global off resolves to off, per `FR-MSG-007`'s `LOCATION-OFF > LOCATION-ON` precedence — and SHALL treat a peer with no stored setting as off. (FR-LOC-002, FR-MSG-007)
- **EARS-LOC-5**: The system SHALL encrypt location data end to end, SHALL NOT let a blocked peer read or write location state in either direction, and SHALL NOT accumulate a location history — locally (at most one stored fix per peer) or in Firebase. (FR-LOC-004)

> **Added at sharding, 2026-09-04.** The epic shipped from `epic-breakdown`
> with two criteria while its `traces_to:` claimed five FR ids, so
> `FR-LOC-001`, `FR-LOC-002` and `FR-LOC-004` owned no EARS id and would have
> failed the Analyze gate's EARS-trace row. `EARS-LOC-3/4/5` add criteria for
> requirements this epic **already claimed** — no requirement is added, changed
> or retired, so this is EARS authoring within `skills/task-sharding`, not a
> scope change routed through `skills/change-impact`.

## Tasks

| Task | Title | Layer | Size | MoSCoW | EARS owned | Status |
|---|---|---|---|---|---|---|
| E09-T01 | Location schema migration v15 — global toggle, per-peer toggles, single last-known fix per peer | backend | M | must | LOC-3, LOC-5 (no-history half), LOC-6 | **done** · APPROVE · `764b150` (PR #32) |
| E09-T02 | Location sharing settings repository + the four-condition visibility policy | backend | M | must | LOC-1, LOC-4, LOC-7 | **done** · APPROVE · `f6f3117` (PR #35) |
| E09-T03 | Encrypted location share wire protocol (control kind 7) — gated send and gated receive | backend | M | must | LOC-5 (encryption + blocked halves), LOC-8…12 | **done** · APPROVE · `4c03aa2` (PR #38) |
| E09-T04 | Last-known-location fallback with explicit freshness — stale is never presented as live | backend | S | should | LOC-2, LOC-13, LOC-14 | **done** · CHANGES→APPROVE · `ab03dba` (PR #41) |
| E09-T05 | Device location acquisition — real `LocationSource`, runtime permission, composition-root wiring | backend | M | should | LOC-15, LOC-16, LOC-17 | **done** · CHANGES→APPROVE · `9a221c4` (PR #42) · on-device steps 4/5 not performed |

### Bug tasks (filed by the 2026-09-04 sweep)

| Bug | Title | Sev | Prio | Status |
|---|---|---|---|---|
| E09-B01 | `LocationReadModel.watch()` never re-evaluates the policy on a relationship change — a blocked peer stays visible | S2 | P2 | todo |
| E09-B02 | Blocking a peer never deletes their stored coordinates; `E09-T04` §4 hands retention to E08, which does not own it | S2 | P2 | todo |
| E09-B03 | `AndroidManifest.xml` comment claims an E04 Bluetooth regression check that `E09-T05` §9 records as never performed | S3 | P2 | todo |
| E09-B04 | Tracker/epic status never advanced past sharding — `0/5`, all `todo`, five merges unrecorded | S3 | P2 | **done** |
| E09-B05 | Rule 5 breach — T01/T02/T03 reviewed by the same model that implemented them | S2 | P2 | todo |

**Build-complete 2026-09-04; bug sweep run the same day. P1 = 0, P2 = 5 (4
outstanding), so the epic→`development` PR gate is CLOSED** per
`skills/release`.

DAG, collision matrix, the "why there is no frontend task" rationale, and the
**full §Bug sweep report** (suite run, 17/17 EARS trace, cross-task seam
table, scope-creep pass, the 🧍 `bug_priorities` gate and the on-device
merge-gate condition): `tracker.md`.

## Open Questions
- **OQ-E09-1 — no map/location-display screen exists in the design contracts.** Needs a design gap entry (`design/gaps.md`) tracing to FR-LOC-* before this epic's UI tasks can be sharded.
  - **Status:** 🟢 answered — resolved by the design pass this epic was waiting on.
  - **Answer:** `GAP-016` was opened and **approved by the human on 2026-08-30** ("card-only, no map preview — a map is a separate design pass and rule-3 decision, not a blocker for text-first location sharing"), producing the derived contract `design/screens/chat-location.md`. The location *display* surface therefore exists, is card-shaped, and is **owned by `E06-T18`**, not by E09 (`epics/E06-personal-chat/epic.md` line 110, blocked on "E09's permission model existing"). E09 sharding as backend-only is the consequence: it builds the permission model that unblocks that task. A map remains explicitly out of scope for both.
  - **Answered by:** human (GAP-016), read at sharding 2026-09-04
  - **Date:** 2026-08-30
- **OQ-E09-2 — the toggles have no settings surface, and `design_screens: [settings]` in this epic's frontmatter is aspirational.** `FR-LOC-001`/`FR-LOC-002` need a screen for the user to actually operate the toggles. It would belong in the **Privacy & Security sub-screen**, which has no design source: `design/gaps.md` `GAP-005` is 🟡 *proposed* (a design pass is needed; not approved, not built) and E02 carries the matching open `OQ-E02-T03-1`. Per rule 2 that screen is not shardable, so E09 ships the toggles' persistence, policy and enforcement with **no UI to set them** — they can only be changed programmatically or in the database until the design pass happens.
  - **Status:** 🟡 open — **important, not blocking this epic's tasks.** Every EARS criterion here is provable without the screen; the epic simply is not user-operable until it exists.
  - **Owner:** human (a design pass, then a frontend task in whichever epic owns the Privacy & Security sub-screen)
- **OQ-E09-3 — `RelayDeliveryState.failed` remains unwritten, by choice.** Inherited from E04-B02's advisory (see §ANALYZE REPORT, Inherited obligations). Carried on `E09-T03` as `OQ-E09-T03-2` with **human** as owner.
  - **Status:** 🟡 open — owned, not dropped

## ANALYZE REPORT — 2026-09-04

**Gate:** 🧍 `analyze_report` — ✅ cleared by human (decision authority
explicitly delegated to the agent for this session) on 2026-09-04.
All five items under "For the human, before you clear this gate" below were
reviewed and decided; answers recorded in each task's own Open Questions
section. `E09-T05`'s two blocking rule-3 questions are answered — its
`status` moved `blocked` → `todo`.

Sharded by: planner · 5 tasks · `python agent/orchestrator/scheduler.py
--validate` → **green** (`harness: 15 epics, 85 tasks — DAG OK ✓`; 80 tasks
before this pass).

### Step 0 — Inherited obligations (read before slicing)

Sources read in full: `retro.md` §Open follow-ups and `epic.md` §Bug sweep for
**E02**, **E03**, **E04** (this epic's `depends_on:`), plus every bug file in
those three epics and their review advisories, plus a repo-wide grep for
`E09` / `location` / `FR-LOC` / `EARS-LOC`.

**Finding: none of E02, E03 or E04 names E09 anywhere.** Their carry-forwards
are addressed to E05/E06/E07/E11/E13. What E09 genuinely inherits is (a) three
advisories addressed to *"whichever epic first does X"* where E09 is or could
be that epic, (b) one hard structural constraint in a file E09 must edit, and
(c) the E09-directed obligations that live *outside* those three epics.

| # | Obligation | Source | Disposition |
|---|---|---|---|
| 1 | **`RelayDeliveryState.failed` is declared, assigned nowhere, and excluded from `reclaimPayloads()`'s reclaim set — "whichever epic first writes `failed` inherits exactly the retention defect B02 just closed"** | E04 `retro.md` §Open follow-ups; `E04-B02.md` review advisory ("should be carried as an explicit note on whatever task introduces `failed`") | **Explicit Open Question with a named owner** — `OQ-E09-T03-2`, owner **human**. A failed location share is the natural first producer of `failed`, so `E09-T03` §4 *forbids* writing it and returns `transportFailed` to its own caller instead. Widening the terminal-state/reclaim set is a rule-3 change to E04's data lifecycle. |
| 2 | **`ACCESS_FINE_LOCATION` is capped `maxSdkVersion="30"` and `BLUETOOTH_SCAN` asserts `neverForLocation`** — E04's manifest posture, which E09 is the first feature to actually contradict | `E04-T03b.md:388-396`; `android/app/src/main/AndroidManifest.xml` | **covered-by-`E09-T05`** — §2 states the constraint, §5 contracts the manifest edit as confined to the location declaration, §4 forbids touching the `BLUETOOTH_SCAN` element, and manual steps 4 + 5 require an on-device Bluetooth regression check on API ≤30 **and** API 31+. Blocking `OQ-E09-T05-2` puts the choice to the human. |
| 3 | **Catch `CryptoDecryptFailure` / `CryptoDecryptFailureReason`, never `libsignal` exception types** (E03-B03's resolution, landed under E06-T02) | E03 `retro.md` §Open follow-ups item 1; `E03-B03.md:131-145` | **covered-by-`E09-T03`** — §2 and the receive sequence in §5 both name it; `test_EARS_LOC_12_undecryptable_frame_dropped` proves it. |
| 4 | **The forward-secrecy guarantee is bounded to in-order messages — "should be stated wherever that guarantee is ever shown to a user, flagged for whichever epic writes that copy"** | E03 `retro.md` §Open follow-ups item 3; `E03-T03.md:441-451` (note N-1) | **Not applicable to E09 as sharded, and said so rather than silently passed on.** E09 writes **no user-facing copy at all** — `E09-T04` §4 explicitly forbids strings, because the location card's copy is `design/screens/chat-location.md`'s and is built by `E06-T18`. The advisory therefore follows the copy to `E06-T18`, not here. |
| 5 | **Issued-but-never-consumed one-time prekeys leak from the pool permanently** — "needs an expiry/reclaim policy before transport issues bundles at real volume" | E03 `retro.md` §Open follow-ups item 2; `E03-B02.md` Run log | **Noted, not claimed.** E09 adds a new 1:1 encrypted sub-protocol, which increases prekey churn at the margin, but `E09-T03` reuses `stack.prekeyExchange.ensureSession` unchanged and issues no bundles of its own. It neither worsens nor fixes the leak. Still owned by E03's carry-forward, unassigned. |
| 6 | **`signal_identity` stores the local identity keypair in plaintext SQLite; no at-rest encryption for the Drift file is tracked in `spec/`** | E03 `retro.md` §Open follow-ups item 4 | **Noted, not claimed — but E09 widens the blast radius**, because `location_fixes` puts peers' coordinates in that same unencrypted file. Recorded here so the security-lens pass before release knows location is now in scope. No E09 task can fix it (it is a `spec/`-level gap, rule 3). |
| 7 | **On-device Bluetooth verification of E04's transport is still unticked** — no hardware-free test exists for real socket I/O | E04 `retro.md` §Open follow-ups item 1 | **Noted, not claimed.** E09's wire path rides that unverified transport, as E05–E08 already do. `E09-T05`'s manual steps 4/5 add the first *location-motivated* on-device check, which partially serves it. |
| 8 | **GAP-005 / `OQ-E02-T03-1`: the Privacy & Security sub-screen has no design source; FR-TRUST-006's location-access toggle lives there** | E02 `retro.md` §Open follow-ups item 1; `E02-T03.md:44-70, 163-168` | **Explicit Open Question — `OQ-E09-2` above**, owner **human**. This is why E09 shards with no frontend task; `E09-T02` §4 additionally forbids conflating `FR-TRUST-006`'s location-access control with `FR-LOC-001`'s global toggle. |
| 9 | **`EvaluateConnectionRequestUseCase`'s `autoAcceptSpecific` / `requireAuthForUnknown` flags are accepted but inert** until a settings store exists | `E02-T01.md:206-209` (`OQ-E02-T01-2`, ⚪ deferred) | **Noted and fenced.** `E09-T02` §4 forbids activating them — E09 builds a *location* settings store, not FR-TRUST-006's, and switching those flags on would be an unreviewed change to E02's connection semantics. |
| 10 | **`E06-T18` (location-in-chat card) is blocked on "E09's permission model existing (FR-LOC-001/002/003)"** | `epics/E06-personal-chat/epic.md:110`; `design/gaps.md` GAP-016; `design/screens/chat-location.md` §Scope fence | **covered-by-`E09-T02` + `E09-T04`** — T02 delivers the four-condition policy with the *reason* enum the contract's two distinct states need, T04 delivers the `live`/`lastKnown`/`unavailable` reading with a mandatory timestamp that discharges `FR-LOC-005` in the data rather than in the pixels. `OQ-E09-T04-2` names `E06-T18` as the affected consumer of the one known limitation. |
| 11 | **Reuse, don't re-derive, `ConflictResolver.resolveLocationSharing`** (E05-T05, built and untested-in-production since E05 — it has had **no production caller**) | `E05-T05.md`; `lib/features/messaging/domain/conflict_resolver.dart:68`; `FR-MSG-007` | **covered-by-`E09-T02`** — §2 requires the call, §4 forbids re-deriving it, and `test_EARS_LOC_4_global_off_beats_peer_on` asserts the value *equals* the function's output so the delegation is proven rather than coincidental. E09-T02 is that function's first caller. |
| 12 | **`EARS-FB-1` (E11): Firebase must not become a permanent location-history store · `EARS-DIAG-1` (E13): never log sensitive location data** | `epics/E11-firebase-sync/epic.md:30`; `epics/E13-abuse-diagnostics/epic.md:31`; `FR-LOC-004` | **covered structurally** — `E09-T01` makes no-history a *schema* invariant (`location_fixes` PK = one row per peer, no history table exists to write to); every task's §4 forbids a Firebase path; every task's §4 and §9 forbid logging a coordinate, accuracy, peer id or sharing state. |

### Analyze gate checks

| Check | Verdict | Evidence / offending ids |
|---|---|---|
| **EARS trace** | ✅ **pass** *(after a fix)* | Epic EARS ↔ task coverage is now total in both directions: LOC-1→T02, LOC-2→T04, LOC-3→T01, LOC-4→T02, LOC-5→T01 (no-history half) + T03 (encryption + blocked-access halves). Task-level LOC-6→T01, LOC-7→T02, LOC-8…12→T03, LOC-13/14→T04, LOC-15…17→T05. No orphan in either direction. **The fix:** the epic arrived with only LOC-1/LOC-2 while claiming five FR ids, so `FR-LOC-001`, `FR-LOC-002` and `FR-LOC-004` had no criterion — this check *failed as found* and was repaired by adding `EARS-LOC-3/4/5` (see the note under §Acceptance criteria). Disclosed rather than quietly corrected. |
| **Contract sanity** | ✅ pass | No HTTP endpoints in this epic — the "API" is a mesh wire format, contracted byte-by-byte in `E09-T03` §5 with explicit tags, a version byte, an explicit `0xFFFFFFFF` "not reported" sentinel, and a named `FormatException` for every rejection case. One list-shaped read exists (`readAllPeerEnabled`) and its §5 entry **declares why it needs no pagination** (bounded by the device's relationship count, which `RelationshipRepository.listAll` already returns unpaginated) rather than omitting the question. `controlKind = 7` verified unused against all six existing `kControlKind*` constants. No endpoint or function is defined twice across tasks. Casing and repository shape follow `docs/conventions.md` and `StorageSettingsRepository`'s precedent. |
| **Collision matrix** | ✅ pass — **empty** | Only `T04` ∥ `T05` can be unblocked simultaneously, and their `files:` are disjoint (`tracker.md` §Anti-collision matrix). The two genuinely shared files are serialized by `depends_on`, not by hope: `messaging_stack.dart` (T03 creates the registration, T05 swaps the source — `T05 depends_on T03`) and `location_fix_repository.dart` (T03 creates, T04 extends — `T04 depends_on T03`). |
| **Scope fences** | ✅ pass | All five §4 sections are populated with task-specific temptations, not boilerplate: T01 "no history table under any name"; T02 "do not re-derive the precedence", "do not activate E02's inert flags"; T03 "no `PayloadType` value", "no `RelayDeliveryState.failed`", "do not hoist `currentFix()` above the policy check"; T04 "no user-facing string, no timestamp formatting"; T05 "no background location", "do not edit the `BLUETOOTH_SCAN` element". |
| **MoSCoW inflation** | ✅ pass | 3/5 `must` = **60%**, at the threshold, not over. T01/T02/T03 are genuinely must — without them the epic delivers nothing and `E06-T18` stays blocked. **T04 is `should`**: `FR-LOC-005` says the system *may* show last-known, so the epic is shippable without the fallback (the SHALL-NOT is then vacuous). **T05 is `should`**: the epic's actual deliverable — the permission model `E06-T18` waits on — lands with T01–T03 even while the dependency decision is outstanding. Graded on value, not on scheduling. |
| **Size** | ✅ pass | XS 0 · S 1 · M 4 · **L 0**. Nothing to split. The largest, T03, was checked against the "two unrelated ands" smell: its send and receive halves are one protocol with one gate that must be enforced on both sides — splitting them would create precisely the "each side assumes the other gates" failure §2 exists to prevent. |
| **Design** | ✅ pass | **Zero `layer: frontend` tasks**, so no `design_contract:` is required and none is claimed. Verified deliberate, not accidental: (a) the toggles' settings surface has no approved contract — `GAP-005` is 🟡 *proposed*, so rule 2 makes it unshardable (`OQ-E09-2`); (b) the location card's contract `design/screens/chat-location.md` **is** approved (GAP-016 🟢, 2026-08-30) but is **already owned by `E06-T18`**, and duplicating it here would give one contract two owners. Both recorded in `tracker.md` §Why there is no frontend task. |
| **Obligation ownership** | ✅ pass | Every cross-task reference was grepped and checked against the named task's own contract. `E09-T03` §4 says the real `LocationSource` "belongs to `E09-T05`" — and `E09-T05` §1, §3, §7 and its DoD independently state that wiring as its own deliverable ("**This is also the task that closes E09's own wiring obligation**"), rather than merely being named by T03. `E09-T04` §4 hands copy and formatting to `E06-T18` — which is E06's already-listed prospective task, not an invented owner. `E09-T02` §4 hands `FR-TRUST-006` to `OQ-E02-T03-1`, an existing open question with a human owner. No obligation is described in one file and unclaimed in the file that should own it. |
| **Inherited obligations** | ✅ pass | Twelve rows above, each disposed as **covered-by-`<task-id>`**, an **explicit Open Question with a named owner**, or **noted-not-claimed with a reason**. Two carried as owned questions (`OQ-E09-T03-2` → human, `OQ-E09-2` → human) and one closed (`OQ-E09-1`, resolved by GAP-016's 2026-08-30 approval). Nothing is left in prose without a reader. |

### For the human, before you clear this gate

Five things worth a deliberate look — three are decisions only you can make:

1. **`E09-T01`'s schema also fires 🧍 `db_schema_migration`** (`OQ-E09-T01-1`).
   The two shapes worth your eye: **global sharing defaults to OFF** on upgrade
   (an existing install does not silently become shareable), and
   `location_fixes` has **`peer_device_id` as its primary key** — that PK *is*
   `FR-LOC-004`'s no-permanent-history guarantee, made structural rather than
   procedural.
2. **`E09-T05` is `blocked` on two rule-3 calls** — `OQ-E09-T05-1` (which
   location package; advisory `geolocator`, with a Pigeon-of-our-own option
   consistent with ADR-0004) and `OQ-E09-T05-2` (lifting
   `ACCESS_FINE_LOCATION`'s `maxSdkVersion="30"` cap, plus fine-vs-coarse,
   which is a privacy-posture choice). **T01–T04 do not need these answers**
   and can be dispatched the moment this gate clears.
3. **`OQ-E09-T03-1` — one-shot sharing.** `GAP-016` and `chat-location.md` both
   hand "live vs static, update frequency, share duration" to E09 and `spec/`
   answers none of it. This shard implements **static, one shot**: one call,
   one fix, no periodic republish, no revoke message. Anything richer is new
   scope through `skills/change-impact`.
4. **`OQ-E09-2` — the toggles will have no UI.** After this epic, `FR-LOC-001`
   and `FR-LOC-002` are persisted, enforced and tested, but a user cannot
   change them from inside the app until the Privacy & Security design pass
   happens. That is rule 2 working as intended, and it is worth knowing before
   you approve rather than after.
5. **`OQ-E09-T04-1`** picks a 2-minute live/stale window as a defensible
   default, not a specified one — `FR-LOC-005` is satisfied at any threshold
   because the requirement is that stale is *labelled*, not that the boundary
   is a particular number.

## Retro
<pending — after `E09-B01`/`B02`/`B03`/`B05` close and the human `verified`
gate>. Three items are already booked for it, so they are not lost if the
retro is written by someone who did not run the sweep:
1. **`E09-B05` — the rule-5 routing miss.** Mechanically checkable
   (`reviewed_by` model ≠ `executed_by` model); a `L-process-*` lesson with a
   `make health` / `scheduler.py --validate` check as its promotion step.
   Audit E01–E08 for the same pattern — this sweep did not.
2. **`E09-B04` — the un-stamped tracker.** The stamping habit fired on the
   *commit message* (`docs(E09): T0n merged`) and stopped there, five times
   running. Candidate health check: an epic whose task files say `done` while
   its tracker says `todo`.
3. **The on-device gap** (`E09-T05` steps 3/4/5), still open, still human-owned
   — the third epic in a row to inherit E04's unverified-transport problem.
