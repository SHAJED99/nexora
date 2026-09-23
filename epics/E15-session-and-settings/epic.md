---
id: E15
title: Session Lifecycle & Settings Sub-Screens
status: done  # 2026-09-15 bookkeeping fix: tracker.md already records 14/14 done, completed 2026-09-11. (The "retro.md still owed" note that stood here until 2026-09-24 was stale: `epics/E15-session-and-settings/retro.md` exists and is dated 2026-09-11.)
type: feature
priority: { moscow: must, wsjf: 3.0 }
depends_on: [E01, E02, E08, E09, E10, E12, E13, E14]
traces_to: [FR-AUTH-006, FR-AUTH-007, FR-AUTH-008, FR-AUTH-009, FR-AUTH-010, FR-AUTH-011, FR-AUTH-012, FR-AUTH-013, FR-UI-006, FR-UI-007, FR-UI-008, FR-NOTIFY-003, FR-SEC-005, FR-DIAG-003, FR-ROUTE-010, FR-PLAT-004, FR-VER-012, FR-STORE-004, FR-STORE-005, FR-STORE-007]
external_services: [Firebase Authentication, Google Sign-In, Google Play]
ui_surface: [mobile]
design_screens:
  - design/screens/settings-shell.md
  - design/screens/settings-notifications.md
  - design/screens/settings-privacy.md
  - design/screens/settings-security-center.md
  - design/screens/settings-account.md
  - design/screens/sign-out-confirm.md
  - design/screens/settings-network.md
  - design/screens/settings-battery.md
  - design/screens/settings-storage.md
  - design/screens/settings-about.md
---
# E15 · Session Lifecycle & Settings Sub-Screens

**Injected mid-stream** by the human on 2026-09-08, through the front door:
`docs/impact/IMP-003-session-lifecycle-and-settings-subscreens.md`
(🧍 `change_impact_approval` — ✅ cleared by human, 2026-09-08). Nothing in this epic is
sharded from a pre-existing plan; every id it traces to was minted by that
report.

## Business goal
Close the three things a real user hit and reported. There is no way to sign
out at all. A returning user is walked through a welcome screen and a
"Continue with Google" tap they have already done. And eight of the Settings
screen's eight rows answer a tap with a "Coming soon" snackbar — a navigation
hub that navigates nowhere.

## User-visible outcome
A user can open the app and be *in* it, manage every part of it from Settings,
and — deliberately, with a full account of what it costs — erase this device
and walk away.

## Scope

**In scope**
- Sign-out that permanently erases all local state, and creates a brand-new
  device identity on next sign-in (`FR-AUTH-006`…`FR-AUTH-009`).
- Launch routing that skips welcome/login for a device that already has a
  local identity, **strictly subordinate to** the existing mandatory-update
  block (`FR-AUTH-010`…`FR-AUTH-012`).
- All eight Settings sub-screens (`FR-UI-006`), each built against its own
  design contract, plus the shared shell they compose and the sign-out
  confirmation screen.
- `E08-T09`, the Storage settings screen E08 deferred to a prospective slot —
  rehomed here as `E15-T09` with its reserved EARS ids intact.

**Out of scope**
- **Multi-identity / account switching.** Explicitly rejected by the human on
  2026-09-08 in favour of wipe-on-logout. `E13`'s carried-forward observation
  about two accounts on one device stays unreachable, by design.
- **Sign-out that keeps the identity.** Same decision; there is one sign-out
  and it wipes.
- **Every capability a Settings row's *subtitle* promises but no `FR-*` id
  requires** — LED behaviours, silent modes, app lock, a permissions screen,
  certificates, network audits, data-usage metering, proxy, release notes,
  export. Each is a named fork in `design/gaps.md` with **no proposal**, and
  `FR-UI-007` requires the sub-screen to disclose the absence rather than
  fabricate a control. This is `GAP-027`'s already-approved disposition,
  applied nine more times.
- **Any new backend, transport, crypto or storage behaviour.** Eight of the
  ten screens are read-only views over repositories that already ship.
- **A dismissible `UPDATE_AVAILABLE` nudge** (`GAP-029` §out of scope).
- `Q-SEC-009`'s remote-registry cleanup and `Q-FUNC-010`'s rate-limit
  disposition — **both blocking, both unanswered**; see §Open Questions.

## Data model
**None.** No new table, no migration, no `schemaVersion` bump. This epic
*deletes* the database file wholesale (`E15-T01`) and *reads* nine existing
tables; it introduces no column anywhere. The one new persistent artifact is a
single sentinel file (`E15-T01`), which cannot live in the database precisely
because the database is what is being destroyed.

## API surface
**None** (no server — `ADR-0005`). The only external calls are
`FirebaseAuth.signOut()`, `GoogleSignIn.signOut()`, and — contingent on
`Q-SEC-009` — `DeviceRevocationService.revoke()`, all of which already exist
or are one method on an existing service.

## Screens

| Screen | Route | Design contract | Task |
|---|---|---|---|
| Sub-screen shell | n/a (shared frame) | `design/screens/settings-shell.md` | E15-T03 |
| Notifications | `/settings/notifications` | `design/screens/settings-notifications.md` | E15-T04 |
| Privacy & Security | `/settings/privacy` | `design/screens/settings-privacy.md` | E15-T05 |
| Security Center | `/settings/security-center` | `design/screens/settings-security-center.md` | E15-T06 |
| Account | `/settings/account` | `design/screens/settings-account.md` | E15-T07 |
| Sign-out confirmation | `/settings/sign-out-confirm` | `design/screens/sign-out-confirm.md` | E15-T07 |
| Network | `/settings/network` | `design/screens/settings-network.md` | E15-T08 |
| Battery | `/settings/battery` | `design/screens/settings-battery.md` | E15-T08 |
| Storage | `/settings/storage` | `design/screens/settings-storage.md` | E15-T09 |
| About / Updates | `/settings/about` | `design/screens/settings-about.md` | E15-T10 |

**Gaps:** `GAP-031` … `GAP-039` (`design/gaps.md`), 🧍
`design_contract_approval` — ⏳ **REOPENED 2026-09-08**, all nine 🟡 proposed.
`GAP-024` (Storage) is **not** reopened — approved 2026-09-02, byte-unchanged,
and `E15-T09` simply builds it.

**No frontend task may be dispatched until that gate clears.** Three of the
nine entries carry forks with **no proposal** (`GAP-032` LED, `GAP-033` app
lock / permissions, `GAP-034` certificates, `GAP-036` data usage / proxy,
`GAP-037` OS deep link, `GAP-038` release notes) and two share one unresolved
destructive-treatment fork (`GAP-035`/`GAP-039`, inherited from `GAP-021`).

## Acceptance criteria (epic-level, EARS)

### Session lifecycle
- **EARS-AUTH-5**: WHEN the user confirms sign-out, the system SHALL delete the local database file and clear the Firebase Authentication session and the cached Google credential, leaving no local device cryptographic identity. (FR-AUTH-006, FR-AUTH-008)
- **EARS-AUTH-6**: IF a sign-out is interrupted before the erase completes, THEN on the next launch the system SHALL complete the erase before presenting any signed-in state. (FR-AUTH-009)
- **EARS-AUTH-7**: WHEN the user reaches the sign-out confirmation, the system SHALL name every category of data that will be destroyed and SHALL state that it is unrecoverable, before any destructive action is possible. (FR-AUTH-007, FR-RECOVER-002)
- **EARS-AUTH-8**: WHILE a local device cryptographic identity exists, WHEN the application launches, the system SHALL present the dashboard without presenting the welcome or login screens. (FR-AUTH-010)
- **EARS-AUTH-9**: IF the launch-time version evaluation is UPDATE_REQUIRED, THEN the system SHALL present the mandatory-update screen regardless of whether a local device identity exists. (FR-AUTH-011, FR-VER-006)
- **EARS-AUTH-10**: IF no local device cryptographic identity exists, THEN the application SHALL launch to the welcome screen. (FR-AUTH-012)
- **EARS-AUTH-11**: WHEN a device signs in after a completed sign-out, the system SHALL create a new device cryptographic identity rather than reusing any prior one. (FR-AUTH-008)
- **EARS-AUTH-12**: WHEN the Account screen is shown, the system SHALL present the signed-in account identifier, this device's own identity fingerprint, and the other devices registered to the account. (FR-AUTH-013)

### The hub
- **EARS-UI-8**: WHEN any Settings row is tapped, the system SHALL navigate to that row's sub-screen; no Settings row SHALL respond with a non-navigating acknowledgement. (FR-UI-006)
- **EARS-UI-9**: WHERE a Settings row's subtitle names a capability the application does not implement, the sub-screen SHALL state the absence and SHALL NOT present a control or a value for it. (FR-UI-007)
- **EARS-UI-10**: WHEN the back affordance is used on any Settings sub-screen, the system SHALL return to the Settings hub. (FR-UI-008)
- **EARS-UI-11**: IF a sub-screen's underlying read fails, THEN the system SHALL show that section's failure line and SHALL leave every other section, and every user-chosen setting, unchanged. (FR-UI-007, NFR-REL-001)

### The sub-screens
- **EARS-NOTIFY-16**: WHEN a notification category is switched on the Notifications screen, the system SHALL persist that choice through `NotificationSettingsRepository` and SHALL reflect the persisted value on the next read. (FR-NOTIFY-003, FR-NOTIFY-001)
- **EARS-NOTIFY-17**: WHERE the `full` notification privacy level has no supported mechanism, the Notifications screen SHALL state that it is unavailable rather than presenting it as a working option. (FR-NOTIFY-003, FR-NOTIFY-002, FR-UI-007)
- **EARS-SEC-4**: WHEN the global location switch is turned off on the Privacy & Security screen, the system SHALL persist it through `LocationSettingsRepository` and location SHALL be unavailable to every peer regardless of per-peer state. (FR-SEC-005, FR-LOC-001, FR-LOC-003)
- **EARS-SEC-5**: The Privacy & Security screen SHALL present the notification privacy level as a read-only value linking to the Notifications screen, and SHALL NOT write it. (FR-SEC-005, FR-NOTIFY-002)
- **EARS-DIAG-4**: The Security Center screen SHALL render only device identifiers, record types and timestamps, and SHALL NOT render key material, session material, message content or location data. (FR-DIAG-003, FR-DIAG-002)
- **EARS-DIAG-5**: The Security Center screen SHALL offer no action that changes trust, block or revocation state. (FR-DIAG-003)
- **EARS-ROUTE-13**: The Network screen SHALL present each transport and each active route from the shipped `TransportService`/`RoutingEngine` state, and SHALL present an unmeasured signal as unmeasured rather than as a numeric value. (FR-ROUTE-010, FR-ROUTE-007)
- **EARS-ROUTE-15**: The Network screen SHALL offer no control that changes transport selection or routing. (FR-ROUTE-010, FR-DISC-003)
- **EARS-PLAT-15**: The Battery screen SHALL present whether background operation is running and which of Doze, Battery Saver and background-execution restriction are in effect, reporting an unreported restriction as unknown. (FR-PLAT-004, FR-PLAT-002)
- **EARS-PLAT-16**: The Battery screen SHALL offer no control that purports to change an operating-system power restriction. (FR-PLAT-004)
- **EARS-VER-18**: The About screen SHALL present the installed version and build number, the cached version policy, and the evaluated version state, all read from the shipped `E14` components. (FR-VER-012, FR-VER-005, FR-VER-008)
- **EARS-VER-19**: The About screen's diagnostics section SHALL render log codes and timestamps only. (FR-VER-012, FR-DIAG-002)
- **EARS-STORE-20**: WHEN a storage management mode is selected on the Storage screen, the system SHALL persist it through `StorageSettingsRepository` and SHALL NOT execute any retention pass as a result. (FR-STORE-004)
- **EARS-STORE-21**: The Storage screen SHALL present the latest retention plan's decisions with their reasons, and SHALL present a plan with no candidates as nothing scheduled. (FR-STORE-007, FR-STORE-005)
- **EARS-STORE-22**: The Storage screen SHALL offer no apply-now, clean-now or delete affordance of any kind. (FR-STORE-006)

> `EARS-STORE-20`/`21`/`22` are the three ids **E08's own Analyze report
> reserved** for its prospective T09 ("written into its `GAP-024` shape, not
> minted here"). They are minted here, at the same numbers, rather than
> renumbered — the reservation is honoured, not stepped over.

### Cross-cutting NFRs bound here
- **NFR-PRIV-001** binds `E15-T01`: an erase that leaves recoverable key
  material in a SQLite WAL has not erased anything.
- **NFR-REL-001** binds every sub-screen via `EARS-UI-11`.
- **NFR-BATT-001** binds `E15-T08`: a status screen must not poll radios.

## Tasks

| Task | Title | Layer | Size | MoSCoW | Depends on |
|------|-------|-------|------|--------|-----------|
| E15-T01 | Sign-out: local data wipe service and sign-out use case | backend | M | must | — (🟡 blocked on Q-SEC-009, Q-FUNC-010) |
| E15-T02 | Session-aware launch routing, after the mandatory-update gate | backend | S | must | E15-T01 |
| E15-T03 | Settings sub-screen shell widget and design-gate registration | frontend | S | must | — |
| E15-T04 | Notifications settings screen | frontend | M | must | E15-T03 |
| E15-T05 | Privacy & Security settings screen | frontend | M | should | E15-T03 |
| E15-T06 | Security Center screen | frontend | M | should | E15-T03 |
| E15-T07 | Account screen and sign-out confirmation | frontend | M | must | E15-T01, E15-T03 |
| E15-T08 | Network and Battery settings screens | frontend | M | could | E15-T03 |
| E15-T09 | Storage settings screen (E08 carry-forward) | frontend | M | should | E15-T03 |
| E15-T10 | About / Updates screen | frontend | S | could | E15-T03 |
| E15-T11 | Settings hub wiring: eight routes, eight rows, probe consolidation | frontend | M | must | E15-T02, E15-T04, E15-T05, E15-T06, E15-T07, E15-T08, E15-T09, E15-T10 |

Build order follows the human's stated priority within what the DAG allows:
Notifications, then Privacy & Security / Security Center, then Account, then
Network / Storage / Battery / About.

## Test strategy
- **`E15-T01` is the one that must be falsified, not just tested.** Assert the
  *absence* of the file, and re-open a fresh `AppDatabase` afterwards to prove
  the next sign-in gets an empty schema — a test that only checks
  `deviceIdentities` is empty would pass against a wipe that deleted one table.
- **`E15-T02` composes with a shipped gate.** `initialRouteFor` already exists
  and is already tested; the new function must be tested for **both** orders —
  update-required with an identity, and update-required without one.
- Sub-screens: a widget test each plus a probe dump; the design gate is a
  **regression** gate from the first extraction onward (derived screens have no
  design source — `design-fidelity` §3).
- **Where the sweep should look hardest:** (1) the seam between `E15-T01`'s
  wipe and every GetX singleton holding a handle to the deleted file — a live
  `AppDatabase` on a deleted path is this epic's most likely crash; (2) the
  seam between `E15-T02`'s new routing and `E12-T03`'s enrollment gate, which
  also branches at launch and is exactly where `E12-B01` shipped an S1; (3)
  `E15-T11`'s eight-route wiring, where a single copy-pasted route constant
  sends two rows to one screen and every individual task still passes.

## Risks

| Risk | Mitigation |
|---|---|
| A live `AppDatabase`/`MessagingStack` handle survives the wipe and crashes on the next query | `E15-T01` closes and unregisters every GetX singleton **before** deleting the file, and `E15-T07` navigates with a stack-replacing `Get.offAllNamed` so no screen holding a controller survives |
| The wipe is interrupted (process kill mid-delete) and the app resumes half-erased | The sentinel file is written **before** the first delete and removed **after** the last; `E15-T02` completes a pending wipe before any routing decision (`EARS-AUTH-6`) |
| Launch-skip bypasses the mandatory-update block | `FR-AUTH-011` and `EARS-AUTH-9` make it subordinate by construction: `E15-T02` extends the **existing** `initialRouteFor`, and `updateRequired` returns before the identity is ever consulted |
| Logout+login trips `E12-T03`'s enrollment gate and strands a single-phone user | **Unmitigated and blocking** — `Q-FUNC-010`. `E15-T01` may not dispatch until it is answered. This is the same shape as `E12-B01`, which shipped |
| Eight screens each invent their own frame | `settings-shell.md` (`GAP-031`) plus a single shared widget owned by `E15-T03`; the eight screen tasks consume it and may not fork it |
| A screen invents a control for a capability the app lacks | `FR-UI-007` + `EARS-UI-9` + a named fork with **no proposal** in each gap entry; each contract's §Derivation boundary lists the specific temptation |
| Four shared files (`routes.dart`, `settings_controller.dart`, `design_probe_test.dart`, `sources.yaml`) collide across eight parallel screen tasks | Single-ownership: `E15-T03` owns `sources.yaml`, `E15-T11` owns the other three. No screen task touches any of them. See §Analyze report, Collision matrix |
| The `settings` screen's own gate goes red because someone "fixes" `Version 2.4.1` | Written into `settings-about.md`'s §Prohibition 1 and into `E15-T10`'s scope fence |

## Open Questions

- **OQ-E15-1 — Should this be one epic or two?** Session lifecycle
  (`FR-AUTH-006`…`012`) and the Settings build-out (`FR-UI-006`…`008`) are two
  functional areas, and `skills/epic-breakdown` §2 says the axis is functional
  area. They are kept together because they arrived as one human decision, they
  share one design gate reopening, and `E15-T07` genuinely spans both (the
  Account screen hosts the sign-out). **Recommendation: keep as one.** Split it
  if the human would rather approve the two waves independently.
  - **Status:** ⚪ deferred — decidable at the 🧍 `analyze_report` gate;
    nothing is blocked either way.
  - **Answer:** _<empty>_
  - **Answered by:** _<human>_
  - **Date:** _<YYYY-MM-DD>_

- **OQ-E15-2 — `Q-SEC-009` and `Q-FUNC-010` are 🟡 blocking and gate this
  epic's first task.** Recorded here as well as in `spec/questions.md` so the
  epic does not look dispatchable. `E15-T01` and `E15-T02` may not be
  dispatched while either is open; `E15-T03` through `E15-T06` and `E15-T08`
  through `E15-T10` are unaffected by them (they are gated only by
  `design_contract_approval`).
  - **Status:** 🟡 open
  - **Answer:** _<empty>_
  - **Answered by:** _<human>_
  - **Date:** _<YYYY-MM-DD>_

- **OQ-E15-3 — Nine design forks have no proposal.** `GAP-032` (LED),
  `GAP-033` (app lock, permissions), `GAP-034` (certificates, network audits),
  `GAP-035`/`GAP-039` (the shared destructive treatment, inherited from
  `GAP-021`), `GAP-036` (data usage, proxy), `GAP-037` (the OS deep link),
  `GAP-038` (release notes). Each is a place where an agent would otherwise
  have invented scope from a subtitle. All are answered at the 🧍
  `design_contract_approval` gate; the default disposition for every one of
  them is `GAP-027`'s already-approved (c) — no control, disclosed absence —
  **except** the destructive-treatment fork and `GAP-037`'s deep link, which
  genuinely need a decision.
  - **Status:** 🟡 open
  - **Answer:** _<empty>_
  - **Answered by:** _<human>_
  - **Date:** _<YYYY-MM-DD>_

## Analyze report

**Gate:** 🧍 `analyze_report` — ✅ cleared by human, 2026-09-08 (`AskUserQuestion`)
**Run:** 2026-09-08, against `development` @ `f0c6a71`, 11 tasks sharded.

| Check | Result | Evidence |
|---|---|---|
| **EARS trace** | ✅ pass | 24 epic-level criteria (AUTH-5…12, UI-8…11, NOTIFY-16/17, SEC-4/5, DIAG-4/5, ROUTE-13/14, PLAT-15/16, VER-18/19, STORE-20…22), each owned by exactly one named task and each citing at least one FR id that exists in `spec/srs.md`. Every task carries ≥1 `traces_to:` id and ≥1 EARS criterion. No orphan in either direction across the 20 FR ids this epic claims. New sub-ids are contiguous per area and checked against every id used in E00–E14 and in `test/` — `AUTH` was at 4, `UI` at 7, `NOTIFY` at 15, `SEC` at 3, `DIAG` at 3, `ROUTE` at 12, `PLAT` at 14, `VER` at 17, `STORE` at 19 with 20–22 reserved. **`EARS-STORE-20/21/22` are E08's own reservation, honoured at the same numbers rather than renumbered** |
| **Contract sanity** | ✅ pass | No API surface (no server, `ADR-0005`); the only external calls are `FirebaseAuth.signOut()`, `GoogleSignIn.signOut()` and (contingent) `DeviceRevocationService.revoke()`. **No schema migration and no `schemaVersion` bump** — this epic deletes the database, it does not change it. No list endpoint, so no pagination question. Every repository is read by exactly the tasks that display it and written by exactly one: `NotificationSettingsRepository` → T04 alone (T05 reads it read-only, stated in `settings-privacy.md`'s own prohibition); `LocationSettingsRepository` → T05 alone; `StorageSettingsRepository` → T09 alone. **One setting, one writer** — the `E05-B03` trap, checked explicitly |
| **Collision matrix** | ✅ pass (**by single ownership, not by luck**) | Four files would otherwise collide across the eight parallel screen tasks. Each has exactly one owner and no other task lists it: `design/sources.yaml` → **T03 alone** (all eight screen entries registered up front, so each screen task can run `make design-verify SCREEN=<id>` against its **own** fenced probe file via `--impl-probe`); `lib/app/routes.dart`, `lib/features/settings/presentation/settings_controller.dart`, `lib/features/settings/presentation/settings_binding.dart` and `test/design/design_probe_test.dart` → **T11 alone**. `lib/app/main.dart` → **T02 alone**. `lib/core/auth/google_auth_service.dart` → **T01 alone**. `test/widget_test.dart` → **T02 alone**. T04–T10 create only files under their own feature directory plus their own probe/widget test, and share nothing pairwise. **This is E08's own reservation being honoured**: its Analyze report reserved `lib/app/routes.dart` and `lib/features/settings/**` for its prospective T09 and warned "T09 must not be given the probe fixture when it is sharded, since T08 now owns that file" — `E15-T09` touches none of the three |
| **Scope fences** | ✅ pass | All 11 §4 sections are non-empty and name the tempting-but-wrong move *this* task invites, not a generic warning — e.g. T01 "do not delete rows instead of the file", T04 "do not use a Switch", T06 "do not add an unblock button", T09 "do not add a Clean Now button", T10 "do not fix `Version 2.4.1` on the hub row", T11 "do not touch any screen's own widget" |
| **MoSCoW inflation** | ✅ pass | 6/11 `must` (55%), 3 `should`, 2 `could`. Graded on merits and then checked, never adjusted to hit a ratio. The six: T01/T02 are the two decisions the human made; T03 is a hard precondition for seven tasks; T04 is the human's own stated first priority; T07 hosts the sign-out and is the only path to it; T11 is the task without which none of the other seven is reachable. The `could`s are honest: T08 (Network/Battery) and T10 (About) are read-only status views the product works without |
| **Size** | ✅ pass | No `L`. 2×S, 8×M, 1×S. T08 carries two screens and is the closest to the M/L line — justified because both are read-only status lists over shipped services with the same shell, the same four states and no write path at all; splitting them would produce two tasks whose combined non-shared content is one screen's worth |
| **Design** | ✅ pass **with a hard precondition** | All 9 frontend tasks carry a `design_contract:` and every one of the ten files it points at **exists on disk** (7 written by this pass, `sign-out-confirm.md` and `settings-shell.md` written by this pass, `settings-storage.md` pre-existing from `E08-T07`). **But `GAP-031`…`GAP-039` are 🟡 proposed and the 🧍 `design_contract_approval` gate is ⏳ REOPENED — no frontend task may dispatch until it clears.** This is rule 2's precondition, and it is the same posture `E08` took when it refused to shard T09 |
| **Obligation ownership** | ✅ pass | Grepped every task file for every other E15 task id. Seven cross-references exist and each names an obligation the referenced task's **own contract independently states**: T04–T10 each say "route registration and row wiring are T11's" — and **T11's own `files:` lists `routes.dart`, `settings_controller.dart` and `settings_binding.dart`, its §3 enumerates all eight routes and all eight rows by name, and its §8 owns `EARS-UI-8`/`EARS-UI-10`**. T04–T10 each say "probe consolidation is T11's" — T11's `files:` lists `test/design/design_probe_test.dart` and its §3 enumerates the eight blocks. T07 says "the wipe itself is T01's" — T01's `functions:` declares `SignOutUseCase.call()`. T02 says "the erase mechanism is T01's" — same. **No obligation is described in prose by one task and unclaimed by its named owner** |
| **Inherited obligations** | ✅ pass | Read `E08`'s `epic.md` §Analyze + `tracker.md`, `E10`'s, `E12`'s, `E13`'s `tracker.md`, and `E14`'s. Four hits, all covered: (1) **E08's prospective `T09`** ("shard it the moment T07 lands and the human clears GAP-024" — both happened) → **covered by `E15-T09`**, with its expected shape (`frontend`, `should`, M) and its reserved `EARS-STORE-20…22` honoured; (2) **E08's collision warning** about the probe fixture → **covered by the collision matrix above**, T09 touches neither `design_probe_test.dart` nor `routes.dart`; (3) **E13's carried-forward `SignInUseCase` observation** ("needs a reader before any account-switch or logout feature lands" — this is that feature) → **read and answered in `IMP-003` §"The E13 carried-forward observation"**, verified against `sign_in_use_case.dart` and `login_controller.dart` rather than assumed, and carried into `E15-T01` §2; (4) **E14's `initialRouteFor`/`VersionReconnectWatcher` launch-routing surface** → **covered by `E15-T02`**, which extends that exact function rather than adding a second routing decision beside it. **`E08`'s `OQ-E08-5` (FR-STORE-002/003 unowned) is NOT claimed by this epic** — it remains unowned and is named here rather than silently absorbed |

### What this report claimed, and what has since cleared
It did not claim the epic was ready to dispatch on its own — three gates stood
between this report and a first dispatch: 🧍 `change_impact_approval`
(`IMP-003`), 🧍 `design_contract_approval` (`design/gaps.md`, reopened), and
🧍 `analyze_report` (this line), plus the two 🟡 blocking questions gating
`E15-T01`/`E15-T02` specifically. **All five cleared 2026-09-08** — the human
answered both blocking questions and approved dispatch in one
`AskUserQuestion` round (see `spec/questions.md` Q-SEC-009/Q-FUNC-010,
`docs/impact/IMP-003-...`, `design/gaps.md`, and this line). Dispatch is open.
