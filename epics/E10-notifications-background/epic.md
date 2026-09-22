---
id: E10
title: Notifications & Background Operation
status: done (2026-09-05; 10/10 tasks + 10/10 bugs closed, P1/P2=0, all priority-stamped — ready for epic→development merge)
type: feature
priority: { moscow: should, wsjf: 3.6 }
depends_on: [E04, E06]
traces_to: [FR-NOTIFY-001, FR-NOTIFY-002, FR-PLAT-001, FR-PLAT-002, FR-PLAT-003]
external_services: []
ui_surface: [mobile]
design_screens: [settings]
---
# E10 · Notifications & Background Operation

## Business goal
Keep discovery/sync/calls/PTT/location working while backgrounded, within
Android's Doze/Battery-Saver/process-termination constraints, and notify
users of the events that matter.

## Scope
**In scope:** notification categories + privacy config, background service
architecture respecting Doze/Battery Saver/screen-lock, Android-native
foreground-service/background-networking components behind Pigeon (ADR-0004).
**Out of scope:** the transport/routing logic itself (E04) — this epic is
about *keeping it alive* in the background, not what it does.

## Acceptance criteria (epic-level, EARS)
- **EARS-NOTIFY-1**: WHEN a notifiable event occurs whose notification category is enabled, the system SHALL post an Android notification on that category's own channel. (FR-NOTIFY-001)
- **EARS-NOTIFY-2**: The system SHALL persist a configurable notification privacy level, SHALL default to a content-free presentation, and SHALL NOT decrypt message plaintext in order to build a notification. (FR-NOTIFY-002)
- **EARS-PLAT-1**: The system SHALL account for Doze, Battery Saver, background restrictions, process termination, and screen lock during background operation. (FR-PLAT-002)
- **EARS-PLAT-2**: WHILE the app is backgrounded and the foreground service is running, the system SHALL continue peer discovery, message synchronization and network maintenance through the **one existing** coordinator tick, and SHALL NOT introduce a second periodic driver. (FR-PLAT-001)
- **EARS-PLAT-3**: System-sensitive functionality — notifications, the foreground service, power-state queries — SHALL be implemented in Android-native components exposed to Flutter through a defined Pigeon interface. (FR-PLAT-003, ADR-0004)
- **EARS-PLAT-4**: WHILE the app process is alive but not in the foreground, the system SHALL continue to run the retention pass (`reclaimPayloads`) that NFR-SEC-001 depends on. (FR-PLAT-001, NFR-SEC-001)

> **Added at sharding, 2026-09-04.** The epic shipped from `epic-breakdown`
> with **one** criterion while its `traces_to:` claimed five FR ids, so
> `FR-NOTIFY-001`, `FR-NOTIFY-002`, `FR-PLAT-001` and `FR-PLAT-003` owned no
> EARS id and would have failed the Analyze gate's EARS-trace row.
> `EARS-NOTIFY-1/2` and `EARS-PLAT-2/3/4` add criteria for requirements this
> epic **already claimed** — no requirement is added, changed or retired, so
> this is EARS authoring within `skills/task-sharding`, not a scope change
> routed through `skills/change-impact`. Same disposition as E09's sharding
> pass made for the same defect.

Cross-cutting: **NFR-BATT-001** *(needs number)* binds here most directly
of any epic — and, per `E06-T06.md:528-534`, **nobody has ever measured it**.
`E10-T10` re-justifies the inherited 60 s tick floor rather than inheriting
it silently, and states what it did and did not measure.

## Tasks

| Task | Title | Layer | Size | MoSCoW | EARS owned | Status |
|---|---|---|---|---|---|---|
| E10-T01 | Native notification boundary — Pigeon `NotificationApi`, Android channels, POST_NOTIFICATIONS | cross-cutting | M | must | PLAT-5, PLAT-6 | todo |
| E10-T02 | Notification preferences — Drift migration v16 + repository | backend | M | must | NOTIFY-3, NOTIFY-4 | todo |
| E10-T03 | Notification policy + dispatcher; new-message notifications | backend | M | must | NOTIFY-5, 6, 7 | todo |
| E10-T04 | Incoming-call notifications — `CallSignaling` seam | backend | S | should | NOTIFY-8, 9 | todo |
| E10-T05 | Connection-request notifications — `PrekeyExchange` seam | backend | S | should | NOTIFY-10, 11 | todo |
| E10-T06 | Group-event notifications — `GroupMembershipService` seam | backend | S | should | NOTIFY-12, 13 | todo |
| E10-T07 | Storage-warning notifications — `StorageManager.latestPlan` observer | backend | S | should | NOTIFY-14, 15 | todo |
| E10-T08 | Android foreground service — retained engine, persistent notification, boot restart | cross-cutting | M | must | PLAT-7, 8, 9, 10 | todo (unblocked 2026-09-04 — ADR-0007 accepted) |
| E10-T09 | Power-state signals — Doze, Battery Saver, screen lock, restriction | cross-cutting | S | should | PLAT-17, 11 | todo |
| E10-T10 | Adaptive background policy — one tick, cadence + discovery | backend | M | should | PLAT-12, 13, 14 | todo |

DAG, collision matrix and the "why there is no frontend task" rationale:
`tracker.md`. Background-execution architecture:
`agent/memory/decisions/ADR-0007-background-execution.md` (🧍 awaiting human).

## Open Questions

- **OQ-E10-1 — no design source for any notification surface.** `settings.md`
  draws a `Notifications` row (elements 38-42) and a `Battery` row
  (elements 33-37); **neither has a destination screen** in any of the
  fourteen measured contracts, and neither has a `design/gaps.md` entry. Rule
  2 makes both unshardable. This also leaves every notification *string* this
  epic ships — including the permanent foreground-service notification
  Android requires — proposed-in-task-files rather than contracted.
  - **Status:** 🟡 open — **important, not blocking.** Every EARS criterion
    here is provable without the screens; the epic is simply not
    user-operable, and its copy is not design-approved.
  - **Owner:** human (a design gap pass, then a frontend task)
- **OQ-E10-2 — the `full` privacy level is stored but not honoured.**
  Message plaintext is decrypted only in the screen layer
  (`E06-T09.md:64-68`, which forbids by name exactly the background-decrypt
  path a preview notification would need). `E10-T03` stores `full` and
  downgrades it to `senderOnly`, disclosed and tested. Honouring it needs a
  controlled decrypt path outside the screen layer.
  - **Status:** 🟡 open — **not blocking**; the downgrade is tested
  - **Owner:** human (a plaintext-boundary decision)
- **OQ-E10-3 — PTT and voice messages have no discriminator, and PTT has no
  code at all.** `FR-NOTIFY-001` gives "voice messages" and "PTT" their own
  notification classes. `Message` carries only `ciphertext` + metadata
  (`message.dart`), so distinguishing them requires decryption (see
  `OQ-E10-2`), and a repo-wide grep finds **no PTT implementation anywhere in
  `lib/`**. Both arrive as `message` until that changes.
  - **Status:** 🟡 open — **not blocking**; disclosed in `E10-T03` §4
  - **Owner:** human
- **OQ-E10-4 — battery-optimisation exemption.**
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` + a user prompt is the only real
  mitigation for OEM battery-killers (`E06-T06.md:373`; three MIUI
  restrictions already on record). Play-policy sensitive. **Not built** —
  `E10-T08` §4 and `E10-T09` §4 both fence it out; `E10-T09` reads the
  status flag without prompting. ADR-0007 §S2.
  - **Status:** 🟡 open · **Owner:** human
- **OQ-E10-5 — restart after reboot.** `RECEIVE_BOOT_COMPLETED` + a boot
  receiver. `START_STICKY` covers process death, not reboot. Not built.
  ADR-0007 §S3.
  - **Status:** 🟡 open · **Owner:** human
- **OQ-E10-6 — "trust requests" have no producer.** `FR-NOTIFY-001` names
  the class; there is no inbound trust-request control frame, no control kind
  and no producer in the build. `E10-T05` fences it out rather than inventing
  a protocol.
  - **Status:** 🟡 open — is this E02 scope, or a new requirement?
  - **Owner:** human
- **OQ-E10-7 — "security events" have no definition and no producer.**
  `FR-NOTIFY-001` names the class and nothing in `spec/` says what a security
  event *is*. Rule 1: spec silent → ask, don't guess. E13
  (Abuse & Diagnostics) is the plausible owner. No task claims it.
  - **Status:** 🟡 open · **Owner:** human
- **OQ-E10-8 — Doze and the open RFCOMM read loop.** `E04-T03a.md:97-98`
  deferred Doze handling to "T03b/T03c's concern" and **neither built it** —
  a grep of all of E04 for `Doze` returns only those two lines. What happens
  to an open `BluetoothSocket` and its blocking read thread in Doze is
  unhandled, and unverifiable in this environment (no installable device —
  `E04-T03b` §Run log). `E10-T10` handles the *discovery* half in Dart and
  explicitly does not touch the native read loops.
  - **Status:** 🟡 open — **newly discovered orphan**, not inherited from a
    named source
  - **Owner:** human
- **OQ-E10-9 — Dashboard background status / connectivity alerts.**
  `E06-T12.md:116-117` handed these to E10, but `design/screens/dashboard.md`
  is an *approved, measured* contract with no such element; adding one is an
  extra element requiring a `design/gaps.md` entry and human approval
  (rule 2). Not built.
  - **Status:** 🟡 open · **Owner:** human (design pass)
- **OQ-E10-10 — background location.** `E09-T05.md:112-116` fenced
  `ACCESS_BACKGROUND_LOCATION`, continuous sampling and keeping location
  alive while backgrounded to "E10's stated scope". E09 is a **sibling, not a
  `depends_on`**, so this obligation would not have surfaced from a
  mechanical dependency sweep. Not built: it is a heavier permission with
  Play-review implications, and E09 itself has not landed.
  - **Status:** 🟡 open · **Owner:** human (rule 3, separable from ADR-0007)

## ANALYZE REPORT — 2026-09-04

**Gate:** 🧍 `analyze_report` — ✅ cleared by human (decision authority
explicitly delegated to the agent for this session) on 2026-09-04.

**Decisions recorded against the ten items above:**
1-4. **ADR-0007 accepted** — option 1 (foreground service + retained
   `FlutterEngine`), §S1 `connectedDevice`, §S2 deferred (no
   battery-exemption request yet, `OQ-E10-4` stays open pending on-device
   evidence), §S3 **pulled into scope** (boot-restart now built by
   `E10-T08`, superseding its earlier "does not build" fence; `OQ-E10-5`
   closed). `E10-T08`/`T09`/`T10` unblocked, `status: blocked` → `todo`.
5. `E10-T02` claims `schemaVersion: 16`, `depends_on: [E09-T01]`, confirmed
   correct — `E09-T01` merged 2026-09-04 (PR #32), so this holds as sharded.
6. `OQ-E10-1` — accepted as a known gap, same shape as `OQ-E09-2`: this
   epic ships fully enforced/tested but has no in-app settings UI until a
   design pass covers `settings.md`'s `Notifications`/`Battery` rows. The
   one exception — the mandatory foreground-service notification — ships
   with provisional copy per ADR-0007 §S4, not blocking.
7. `OQ-E10-2`/`OQ-E10-3` — accepted as sharded: ship the five buildable
   notification classes, disclose and test-as-downgraded the three that
   cannot be built as specified (full-preview privacy, voice-message
   distinction, PTT — none of which this codebase can support today).
8. `OQ-E10-6`/`OQ-E10-7` — trust-request and security-event notifications
   stay unbuilt, unowned open questions. `OQ-E10-7`'s "security events" is
   plausibly E13's (Abuse Prevention & Diagnostics) to define first — noted
   for that epic's own sharding pass, not claimed here.
9. `OQ-E10-8` — accepted as a genuine, previously-unowned gap: the native
   RFCOMM-during-Doze behavior stays unverified pending an installable
   device, same standing limitation as E04's other on-device gaps.
10. `OQ-E10-T10-2` — accepted: suppressing discovery in Doze is the right
    default given Android won't deliver scan results then anyway; the
    cadence table's six numbers stay tunable, unmeasured defaults.

Sharded by: planner · 10 tasks · one new ADR (`ADR-0007`, `⏳ AWAITING
HUMAN`) · `python agent/orchestrator/scheduler.py --validate` → **green**
(`harness: 15 epics, 95 tasks — DAG OK ✓`; 85 tasks before this pass).

### Step 0 — Inherited obligations (read before slicing)

Sources read in full: `retro.md` §Open follow-ups and `epic.md`
§Bug sweep/§Open Questions for **E04** and **E06** (this epic's
`depends_on:`), every bug file in both (`E04-B01..B03`, `E06-B01..B04`) and
their review advisories, plus `E05-B02.md` (the origin of the deferral
chain), `E08-T06.md`, `E09-T05.md`, and a repo-wide grep for
`E10` / `background` / `WorkManager` / `foreground service` / `Doze` /
`notification` / `battery`.

**Finding worth stating first: neither retro mentions E10, notifications,
background execution, Doze or a foreground service at all.** E04's §Open
follow-ups route to E05 and "whoever writes `failed`"; E06's route to E11,
design gaps, an S4 colour cleanup and the lesson hook. **Every one of E10's
thirteen obligations lives in a task file** — seven of them in `E06-T06.md`
alone. That is `L-process-008`'s failure mode (a carry-forward with no
reader) recurring *across* an epic boundary rather than within one, and it is
exactly what Step 0 exists to catch. Recorded here rather than passed on.

| # | Obligation | Source | Disposition |
|---|---|---|---|
| 1 | **Build option (d): Android background execution** — "explicitly NOT built here; it is named as an E10 task … which owns background-execution policy" | `E06-T06.md:395-400`, trade-off row `:373`, advisory `:375-381` | **covered-by-`E10-T08` + `E10-T10`** — T08 keeps the process alive; T10 makes the existing tick run and adapt while closed. ADR-0007 is the architecture choice this obligation implies. |
| 2 | **The dependency + manifest permission are their own 🧍 gates** — "that answer names a new dependency and a new manifest permission, which is itself a 🧍 gate … must be re-presented before code" | `E06-T06.md:128-133`, `:183-185` | **covered-by-`ADR-0007`** (written this pass, `⏳ AWAITING HUMAN`) — and `E10-T08` is `status: blocked` on it, so the gate is structural, not a note. **No new package is introduced at all**: FR-PLAT-003 + ADR-0004 make notifications and the service native-behind-Pigeon, so the "new dependency" half of the gate is discharged by *not incurring it*. |
| 3 | **`OQ-E06-T06-1`** — the epic-level index entry naming E10 as owner of background execution | `epics/E06-personal-chat/epic.md:134` | **covered-by-`ADR-0007`** — cited by id in the ADR's Context, closing the E05-B02 → E06-T06 → E10 chain in one document. |
| 4 | **The original human deferral** — "what happens in the background, on Android, with the app killed?" E06 answered only the foreground half | `E05-B02.md:140-145`, `:169-172` | **covered-by-`ADR-0007`** — quoted verbatim in its Context so the chain is visible in one place. |
| 5 | **`reclaimPayloads()` (NFR-SEC-001's retention guarantee) only runs while someone is looking** — "with the app closed, nothing forwards and nothing reclaims" | `E06-T06.md:382-384`, `:370` | **covered-by-`E10-T10`** as its **own** criterion and its **own** test — `EARS-PLAT-14` / `test_EARS_PLAT_14_reclaim_runs_while_backgrounded`, explicitly not folded into the forwarding criterion, per the advisory's own instruction. Also raised to epic level as `EARS-PLAT-4`. |
| 6 | **NFR-BATT-001 has never been measured; do not claim an outcome that was not measured** | `E06-T06.md:528-534`, `:201-203`, `:87-91` | **covered-by-`E10-T10`** — §2 re-justifies the 60 s floor rather than inheriting it, §5's cadence table labels every other number as unmeasured, §7/§9 require an honest measurement record including "not possible", and `OQ-E10-T10-1` carries the residue. `E10-T08` §6/§9 carry the same prohibition for the always-on change. |
| 7 | **OEM battery-killer behaviour is a named, evidenced risk** (three MIUI restrictions on record) | `E06-T06.md:373`; `E04-mesh-routing/retro.md:86-90` | **Split, deliberately.** The *risk* is covered-by-`E10-T08` §6 (`START_STICKY`, honest reporting of what was observed). The *mitigation* — a battery-optimisation exemption prompt — is **an explicit Open Question with a named owner** (`OQ-E10-4`, human; ADR-0007 §S2), because it is a Play-policy-sensitive permission and asking for it before there is on-device evidence the service is being killed is the wrong order. |
| 8 | **Doze handling was deferred by `E04-T03a` to T03b/T03c and built by neither** | `E04-T03a.md:97-98`; confirmed absent from `E04-T03b.md`/`E04-T03c.md` §4 and from the whole E04 epic by grep | **Split.** The Dart-side half — suppressing discovery in Doze — is **covered-by-`E10-T10`** (`EARS-PLAT-13`), and `E10-T09` makes Doze observable in this codebase for the first time. The native half — an open RFCOMM socket and its blocking read thread in Doze — is an **explicit Open Question with a named owner** (`OQ-E10-8`, human), because it is unverifiable without an installable device and `E10-T10` §4 forbids guessing at it. **Flagged as newly discovered and previously unowned**, not inherited from a named source: nothing addressed it to E10. |
| 9 | **`InboundPipeline` surfaces nothing to the user** — "Counters and a stream; no UI, no notification (E10)" | `E06-T05.md:124-125` | **covered-by-`E10-T03`** — the source *subscribes* to the existing `delivered` stream and `inbound_pipeline.dart` is deliberately absent from T03's `files:`, honouring T05's own fence against modifying it. |
| 10 | **Dashboard has no notifications, background status or connectivity alerts (E10)** | `E06-T12.md:116-117`, `:113-114` | **Explicit Open Question — `OQ-E10-9`**, owner **human**. `design/screens/dashboard.md` is an approved, measured contract with no such element; adding one is an *extra element* requiring a `design/gaps.md` entry and approval (rule 2). T12's companion fence ("do not synthesize a battery figure") is honoured by obligation 6's treatment. |
| 11 | **E08 forbade itself a second timer because E10 owns background operation; do not change tick semantics** | `E08-T06.md:119-120`, `:127-131` | **covered structurally, in four places** — it is `EARS-PLAT-2` at epic level; `E10-T08` §2/§4/§9 build *no scheduler at all* (the service keeps the process alive so the existing `Timer.periodic` keeps firing); `E10-T10` §4 limits its coordinator diff to an interval setter with a `test_EARS_PLAT_12_no_second_timer_created` assertion; and `E10-T07` §4 repeats the fence for the storage pass. |
| 12 | **Background location is E10's stated scope** (`ACCESS_BACKGROUND_LOCATION`, continuous sampling) | `E09-T05.md:112-116` | **Explicit Open Question — `OQ-E10-10`**, owner **human**. Not built. Noted as the second obligation a mechanical `depends_on` sweep would have missed: **E09 is a sibling, not a dependency**, and it names E10 by reading E10's own `epic.md`. |
| 13 | **A background job must not be the thing that decrypts previews** — "putting decryption in a repository that a future background job might call is how plaintext ends up somewhere nobody expected" | `E06-T09.md:64-68` | **covered-by-`E10-T02` + `E10-T03`** — privacy defaults to `hidden`, `full` is stored but downgraded and *tested as a downgrade*, `E10-T03` §4 forbids adding a decrypt path by name, and `test_EARS_NOTIFY_7` asserts the injected crypto double was **never called** rather than asserting by inspection. Raised to epic level as `EARS-NOTIFY-2`. |

Excluded after checking (so the next reader need not re-derive them):
"background **thread**" in `E04-T03b/c` and `E06-T11` (threading, not
execution); `backgroundColor` theme tokens in `E06-T10/T11/T12`;
`E06-T04`'s `batteryDrain` routing-cost constant, deferred to "whichever
future epic first exercises battery-aware routing" — **not** named to E10, so
not annexed here; and every E04/E06 retro follow-up, all of which are
addressed to E05/E07/E11 or to "whoever writes `failed`". **No bug file in
either epic mentions E10, notifications, background execution, Doze or a
foreground service.**

### Analyze gate checks

| Check | Verdict | Evidence / offending ids |
|---|---|---|
| **EARS trace** | ✅ **pass** *(after a fix)* | Both directions total. Epic → task: NOTIFY-1 → T01/T03/T04/T05/T06/T07; NOTIFY-2 → T02/T03; PLAT-1 → T08/T09/T10; PLAT-2 → T08/T10; PLAT-3 → T01/T08/T09; PLAT-4 → T10. Task-level: PLAT-5/6 → T01; NOTIFY-3/4 → T02; NOTIFY-5/6/7 → T03; 8/9 → T04; 10/11 → T05; 12/13 → T06; 14/15 → T07; PLAT-7/8/9 → T08; 10/11 → T09; 12/13/14 → T10. No orphan either way. **The fix:** the epic arrived with **one** criterion while claiming five FR ids — `FR-NOTIFY-001/002`, `FR-PLAT-001/003` owned none. This check *failed as found* and was repaired by adding `EARS-NOTIFY-1/2` + `EARS-PLAT-2/3/4` (see the note under §Acceptance criteria). Disclosed, not quietly corrected. |
| **Contract sanity** | ✅ pass | No HTTP endpoints in this epic. The two "APIs" are Pigeon schemas, each contracted in full in its owning task: `NotificationApi`/`NotificationEventsApi` (`E10-T01` §5) and `BackgroundApi`/`BackgroundEventsApi` (`E10-T08` §5, extended by `E10-T09` §5 — **one schema, one owner per method**, no method defined twice). No list-shaped read exists anywhere in the epic, so no pagination question is dodged. Error envelope is uniform and explicitly non-throwing at every boundary: `post()` → `false`, `startService()` → `false`, an unknown privacy string → `hidden`, a missing power signal → `false`. Enum-by-`.name` storage, generated-file discipline and repository shape all follow `docs/conventions.md` and `StorageSettingsRepository`'s precedent. The one genuinely cross-epic contract risk — the Drift schema version — is caught below. |
| **Collision matrix** | ✅ pass — **empty** | Six pairs can be unblocked simultaneously — (T01,T02), (T03,T08), (T04,T09), (T05,T09), (T06,T09), (T07,T09) — and every pair's `files:` lists are disjoint (`tracker.md` §Anti-collision matrix, with the reason per pair). Six files are written by more than one task and **every one is serialized by `depends_on`**: `MainActivity.kt` and `AndroidManifest.xml` (T01→T08), `bindings.dart` (the T03→T04→T05→T06→T07→T10 chain — serialized *on purpose*, since an empty matrix asserted over a shared composition root would be a lie), `pigeons/background.dart` + its generated pair and `background_service.dart`/`background_stub.dart` (T08→T09), and — the important one — **`database.dart`/`database.g.dart`, shared with the actively-in-flight `E09-T01`** (cross-epic `T02 depends_on: [E09-T01]`, see the human list below). |
| **Scope fences** | ✅ pass | All ten §4 sections are populated with this-task-specific temptations, not boilerplate. Samples: T01 "do not add a notification package — it would be a new dependency *and* a contradiction of ADR-0004"; T03 "do not add a decrypt path to any repository", "do not suppress for the open conversation"; T05 "do not activate E02's inert flags", "never notify a blocked peer"; T06 "do not emit from `_perform`", "do not notify for group *messages* — that would double-notify"; T07 "**zero E08 files touched**", "do not define a new threshold"; T08 "no `Timer`, `WorkManager`, isolate or second driver" + four fenced-out permissions; T09 "no manifest change in the diff", "no behaviour reacts to power state yet"; T10 "the coordinator diff is the interval setter and nothing else". |
| **MoSCoW inflation** | ✅ pass | 4/10 `must` = **40%**. Graded on value, not on scheduling, and the must-set is closed under dependency (no `must` depends on a `should`): **T01** (nothing notifies without the boundary), **T02** (`FR-NOTIFY-002` is a *shall*, and the conservative default is what keeps `OQ-E10-2` safe), **T03** (without a dispatcher, T01/T02 deliver nothing observable), **T08** (the epic's entire background premise; `FR-PLAT-001` is unimplemented without it). The six `should`s are genuine increments: T04–T07 each add one notification class to a working mechanism, T09 only *observes*, and T10 refines cadence — the epic ships something coherent without any one of them. |
| **Size** | ✅ pass | XS 0 · S 5 · M 5 · **L 0**. Nothing to split. Two were checked against the "two unrelated ands" smell: **T08** (service + engine retention are one mechanism — a service without a retained engine is a notification with nothing behind it) and **T10** (lifecycle + cadence + reconcile are one control loop over one tick; splitting them would create the "each half assumes the other schedules" failure §2 exists to prevent). The notification sources were split the *other* way for the same reason — four S tasks, one seam each, rather than one L "wire up the remaining classes". |
| **Design** | ✅ pass | **Zero `layer: frontend` tasks**, so no `design_contract:` is required and none is claimed. Verified deliberate, not accidental, and checked against the actual contracts rather than assumed: `design/screens/settings.md` draws a `Notifications` **row** (elements 38-42) and a `Battery` **row** (elements 33-37) with **no destination screen in any of the fourteen measured contracts and no `design/gaps.md` entry for either** (nearest precedents: `GAP-005` 🟡 proposed, `GAP-024` approved). Rule 2 therefore makes both unshardable — `OQ-E10-1`. A third surface, the Dashboard indicator E06-T12 handed over, is fenced for the same reason on an *approved* contract — `OQ-E10-9`. `design/gaps.md` was **not** edited and its gate line was **not** touched by this pass. |
| **Obligation ownership** | ✅ pass | Every task file was grepped for every other task id and for sibling-naming prose, then the named task's own contract was read. Four cross-references exist and all four are independently owned: `E10-T01` §4 says the foreground service "is `E10-T08`" — T08 §1/§3/§5/§7 state that build as its own deliverable; `E10-T03` §4 hands the remaining classes to "T04–T07" — each of those has its own `files:`, `functions:`, EARS ids and tests; `E10-T07` §4 says "`E10-T10` is where that is done, through the one existing tick" — T10 §3/§5 own `setTickInterval` and the lifecycle observer explicitly; `E10-T08` §4 says "wiring the lifecycle trigger is `E10-T10`" — T10 §3 lists exactly that wiring. **`E10-T09` is the deliberate near-miss and it is clean**: it *only* reports, and its §4 says so, with T10's contract independently owning every reaction. No obligation is described in one file and unclaimed in the file that should own it. |
| **Inherited obligations** | ✅ pass | Thirteen rows above, each disposed as **covered-by-`<task-id>`** (1, 3, 4, 5, 6, 9, 11, 13), an **explicit Open Question with a named owner** (7-mitigation → `OQ-E10-4`; 8-native-half → `OQ-E10-8`; 10 → `OQ-E10-9`; 12 → `OQ-E10-10`), or **covered by a new ADR that blocks the task** (2, 3, 4 → `ADR-0007` + `E10-T08` `status: blocked`). Nothing is left in prose without a reader. Two obligations would have been missed by a mechanical `depends_on` sweep and are flagged as such: **#8** (names no owner anywhere) and **#12** (lives in a sibling epic outside the dependency set). |

### For the human, before you clear this gate

Ten items. Six are decisions only you can make; the rest are things worth
knowing *before* you approve rather than after.

1. **`ADR-0007` — background execution architecture — is the big one, and it
   is the end of a three-epic deferral chain** (`E05-B02` → `E06-T06` →
   here). Four options with an honest matrix; the advisory is **option 1**, a
   foreground service holding a retained `FlutterEngine`, chosen because it
   is the only option that keeps the project's "exactly one periodic driver"
   invariant. **`E10-T08` is `blocked` until you decide, and it takes T09 and
   T10 with it.** T01–T07 do not need this answer and can dispatch the moment
   this gate clears.
2. **ADR-0007 §S1 — foreground service type**: `connectedDevice` (accurate)
   vs `dataSync` (easier to justify to Play). Advisory: `connectedDevice`.
   Needed to unblock T08 alongside item 1.
3. **ADR-0007 §S2 — battery-optimisation exemption (`OQ-E10-4`).** The only
   real mitigation for OEM battery-killers — and this project has three MIUI
   restrictions on record already. **Not built**, deliberately: advisory is to
   defer until there is on-device evidence the service is actually being
   killed, because asking for a permission Google scrutinises before we can
   show we need it is the wrong order. Say if you want it sooner.
4. **ADR-0007 §S3 — restart after reboot (`OQ-E10-5`).**
   `RECEIVE_BOOT_COMPLETED`. `START_STICKY` covers process death, not reboot.
   Not built. Without it, a phone restart silently stops the mesh until the
   user opens the app.
5. **`E10-T02` fires 🧍 `db_schema_migration`, and it collides with E09.**
   `schemaVersion` is `14` today; **`E09-T01` — which another agent is
   building right now — claims `15`**, so this task claims `16` and carries
   `depends_on: [E09-T01]` so `database.dart`/`database.g.dart` are only ever
   edited by one task at a time. **If you deprioritise or reorder E09, this
   becomes `from14to15` and the dependency drops — that is a planner call at
   dispatch, not the builder's.** The two shapes worth your eye: notification
   privacy **defaults to `hidden`** (an upgrade never starts showing previews
   it wasn't showing before), and `backgroundService` is deliberately **not**
   a user-switchable category (Android requires that notification; a switch
   that cannot work is worse than no switch).
6. **`OQ-E10-1` — this epic ships no settings screen, and its copy is not
   design-approved.** After E10, the nine categories and the privacy level are
   persisted, enforced and tested, and **a user cannot change any of them
   from inside the app**. Worse: Android *requires* a permanent
   foreground-service notification, so a string nobody designed will sit in
   every user's notification shade permanently. Every proposed string is
   listed in its task's §5 so you can read them, but they are proposals, not
   contracts. Fixing this properly means a design gap pass on the
   `Notifications` and `Battery` rows.
7. **`OQ-E10-2`/`OQ-E10-3` — three of the nine notification classes cannot be
   built as specified.** `full` privacy (message previews) needs plaintext
   outside the screen layer, which `E06-T09` forbids by name; "voice
   messages" cannot be distinguished from messages without that same
   decryption; and **PTT has no implementation anywhere in `lib/`**. All three
   are disclosed and tested-as-downgraded rather than quietly approximated.
8. **`OQ-E10-6`/`OQ-E10-7` — two more classes have no producer at all.**
   "Trust requests" have no control frame and no protocol; **"security
   events" have no definition anywhere in `spec/`** — rule 1 says ask, so:
   what is a security event, and is E13 its owner? Of `FR-NOTIFY-001`'s nine
   classes, this epic builds five.
9. **`OQ-E10-8` — a genuine orphan found by cross-check, not handed to us.**
   `E04-T03a` deferred Doze handling to T03b/T03c and **neither built it**;
   nothing names an owner. What happens to an open Bluetooth RFCOMM socket
   and its blocking read thread during Doze is unhandled and — with no
   installable device in this environment — unverifiable. `E10-T10` handles
   the Dart-side discovery half and explicitly refuses to guess at the native
   half.
10. **`OQ-E10-T10-2` — Doze suppresses peer discovery, and NFR-BATT-001 says
    battery "shall never override reliability or communication
    requirements".** Suppressing discovery in Doze is arguably exactly that
    override. It is defensible (Android will not deliver scan results in Doze
    anyway) but it is your trade-off to confirm, and the whole cadence table
    in `E10-T10` §5 is six unmeasured numbers you can change one at a time.
    Related: **nothing in this project has ever measured battery**
    (`E06-T06.md:528-534`), and E10 is the epic that makes the app run
    continuously.

## Bug sweep — 2026-09-04

**Gate:** 🧍 `bug_priorities` — severity is the reviewer's; **priority was set
under the decision authority explicitly delegated by the human for this
session** (same convention as this session's other gates). Full report,
evidence and the disposition of all 15 carried-forward observations:
`tracker.md` §Bug sweep.

Run in an isolated worktree off `epic_10`@`0f48d16`. **913/913 tests green,
`flutter analyze` clean** (one pre-existing E07 test-file info, not E10's).
Design gate n/a — zero frontend tasks, no contract to drift. **Scope audit
clean**: no task wrote outside its `files:` list, no Pigeon method exists
outside its §5 schema, every fence held under direct check.

**Seven defects. P1/P2 = 5, so the epic→`development` PR does not open yet.**

| id | sev | pri | what | status |
|---|---|---|---|---|
| `E10-B01` | **S2** | **P1** | `BootReceiver` is `android:exported="false"` → the system can never deliver `BOOT_COMPLETED`. **EARS-PLAT-10 / ADR-0007 §S3 is dead code on every device**, and has zero tests. | todo |
| `E10-B02` | S3 | P2 | Discovery runs in Doze/Battery Saver two ways (the `stoppedBySystem` short-circuit; power state never seeded at startup). The seam that applies the plan has no test. | todo |
| `E10-B03` | S3 | P2 | Four of five shipped notification classes post identical `NEXORA`/`Notification` copy; each owning task's §5 copy never reached the file that renders it. | todo |
| `E10-B04` | S3 | P2 | Every app reopen while the service runs leaks a `PowerStateMonitor`, 4 receivers, 2 Pigeon hosts and a destroyed `Activity` — unbounded, in the process this epic made permanent. | todo |
| `E10-B05` | S3 | P2 | After a process kill/reboot the service revives claiming to relay with no Dart isolate behind it. **`blocked`, `owner_agent: planner`** — needs a rule-3 decision ADR-0007 did not make. | blocked |
| `E10-B06` | S4 | P4 | Six unwired `dispose()`/`stop()`. **Assessed as inert, not a leak** — the tracker's four-entry "growing leak" framing is falsified. | todo |
| `E10-B07` | S4 | P3 | Five EARS criteria green on tests that cannot fail; mutations to the guarded lines survive the whole suite. | todo |

**Three findings the sweep produced that no task review could have:**
1. **`EARS-PLAT-10` is defined twice with different text** (`E10-T08.md:236`
   boot restart, `E10-T09.md:157` power-state emission), and `epic.md`'s task
   table above lists "PLAT-10, 11" as T09's. The boot criterion was
   effectively un-indexed, so the EARS-trace row looked green because **T09's**
   tests cover **T09's** PLAT-10. That is how a `must`-graded, ADR-accepted
   feature shipped statically broken with zero tests. **Renumbering is a
   planner call at retro.**
2. **The epic's real resource leak is native, not Dart.** Four tracker entries
   escalated the unwired `dispose()` pattern; at the sweep it is inert
   (`Get.put(permanent: true)` singletons, one per isolate, never regrown —
   T08's engine retention means `main()` is not re-entered). The unbounded
   leak `E10-T08` genuinely introduced is `MainActivity`'s re-attach path.
3. **Two reviewer probes falsified two green tests**: deleting the
   `full` → `senderOnly` privacy downgrade (`notification_policy.dart:91`)
   passes 49/49 notification tests, and mutating
   `storage_notification_source.dart:100` passes all 913 while introducing a
   double-notify.

**ADR-0007 note for the planner.** Option 1 was chosen on the argument that it
needs "no new Dart code path at all". True while the process lives; false the
moment it dies — `E10-B05` is exactly the second composition root options 2
and 3 were rejected for. The main decision stands; the comparison did not
price this in.

## Retro
<pending — after the P1/P2 bugs are fixed and re-verified>
