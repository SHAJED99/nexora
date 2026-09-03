# E10 · Notifications & Background Operation · Progress

**Status:** **sharded 2026-09-04 — 10 tasks, awaiting the 🧍 `analyze_report`
gate before any dispatch.** `E10-T01` and `E10-T02` are dispatchable the
moment that gate clears (T02 additionally fires 🧍 `db_schema_migration` and
carries a cross-epic dependency on `E09-T01` for the schema version).
`E10-T08` is **`blocked`** on `ADR-0007` (background execution architecture,
`⏳ AWAITING HUMAN`) and takes `E10-T09`/`E10-T10` with it. **Backend/native
only** — this epic ships no screen; see §Why there is no frontend task. ·
**Started:** — · **Completed:** — · **Progress:** 0/10

## Tasks

| Task | Title | Layer | Size | MoSCoW | Status | depends_on |
|---|---|---|---|---|---|---|
| E10-T01 | Native notification boundary — Pigeon `NotificationApi`, channels, POST_NOTIFICATIONS | cross-cutting | M | must | todo | — |
| E10-T02 | Notification preferences — Drift migration v16 + repository | backend | M | must | todo | E09-T01 |
| E10-T03 | Notification policy + dispatcher; new-message notifications | backend | M | must | todo | T01, T02 |
| E10-T04 | Incoming-call notifications — `CallSignaling` seam | backend | S | should | todo | T03 |
| E10-T05 | Connection-request notifications — `PrekeyExchange` seam | backend | S | should | todo | T04 |
| E10-T06 | Group-event notifications — `GroupMembershipService` seam | backend | S | should | todo | T05 |
| E10-T07 | Storage-warning notifications — `StorageManager.latestPlan` observer | backend | S | should | todo | T06 |
| E10-T08 | Android foreground service — retained engine, persistent notification | cross-cutting | M | must | **blocked** | T01 |
| E10-T09 | Power-state signals — Doze, Battery Saver, screen lock, restriction | cross-cutting | S | should | todo | T08 |
| E10-T10 | Adaptive background policy — one tick, cadence + discovery | backend | M | should | todo | T07, T09 |

## State machine

```
todo ──▶ in-progress ──▶ review-requested ──┬─▶ changes-requested ──▶ in-progress
                                            └─▶ done ──▶ 🧍 verified
                    side states: blocked (needs a human answer) · frozen (rate limit)
```

`E10-T08` sits in `blocked` from the start. `ADR-0007` presents four
background-execution options with an advisory recommendation and its
`Decision` line reads `⏳ AWAITING HUMAN`. This is the gate `E06-T06.md:128-133`
demanded in writing before any background-execution code — a new manifest
permission set and an architecture choice, both rule 3. T08 leaves `blocked`
when ADR-0007 is `accepted` and §S1 (service type) is settled, not when
someone feels ready. `T09`/`T10` are `todo` but transitively unreachable
until then.

## DAG

```mermaid
graph TD
  ADR["ADR-0007 · background execution<br/>🧍 AWAITING HUMAN"]
  T01["E10-T01 · notification boundary<br/>M · must"]
  T02["E10-T02 · preferences, migration v16<br/>M · must<br/>🧍 db_schema_migration"]
  T03["E10-T03 · policy + dispatcher, messages<br/>M · must"]
  T04["E10-T04 · incoming calls<br/>S · should"]
  T05["E10-T05 · connection requests<br/>S · should"]
  T06["E10-T06 · group events<br/>S · should"]
  T07["E10-T07 · storage warnings<br/>S · should"]
  T08["E10-T08 · foreground service<br/>M · must<br/>🛑 blocked: ADR-0007"]
  T09["E10-T09 · power-state signals<br/>S · should"]
  T10["E10-T10 · adaptive background policy<br/>M · should"]
  E09T01["E09-T01 · schema v15<br/>(E09's task — schema ordering)"]

  E09T01 -.->|schema version| T02
  T01 --> T03
  T02 --> T03
  T03 --> T04
  T04 --> T05
  T05 --> T06
  T06 --> T07
  T01 --> T08
  ADR -.->|unblocks| T08
  T08 --> T09
  T07 --> T10
  T09 --> T10

  style T08 stroke-dasharray: 5 5
  style ADR stroke-dasharray: 5 5
  style E09T01 stroke-dasharray: 5 5
```

Two independent lines run through this epic: the **notification line**
(T01 → T03 → T04 → T05 → T06 → T07) and the **background line**
(T01 → T08 → T09), joining at T10. The T04→T05→T06→T07 chain is serialized
*on purpose* — each of those tasks registers a source in `lib/app/bindings.dart`,
and serializing is honest where an empty-by-assertion matrix would not be.

## Anti-collision matrix

Only tasks that could be unblocked simultaneously are compared.
Simultaneously-unblocked pairs: **(T01, T02)**, **(T03, T08)**,
**(T04, T09)**, **(T05, T09)**, **(T06, T09)**, **(T07, T09)**.

| | T01 | T02 | T03 | T04 | T05 | T06 | T07 | T08 | T09 |
|---|---|---|---|---|---|---|---|---|---|
| **T01** | — | **∅** | — | — | — | — | — | — | — |
| **T02** | **∅** | — | — | — | — | — | — | — | — |
| **T03** | — | — | — | — | — | — | — | **∅** | — |
| **T04** | — | — | — | — | — | — | — | — | **∅** |
| **T05** | — | — | — | — | — | — | — | — | **∅** |
| **T06** | — | — | — | — | — | — | — | — | **∅** |
| **T07** | — | — | — | — | — | — | — | — | **∅** |

(`—` = the pair cannot be unblocked at the same time, so no comparison is
needed. `∅` = no shared file.)

Why each `∅` is real, not asserted:

- **T01 ∥ T02** — T01 is `pigeons/notifications.dart` + `lib/core/notifications/`
  + the two Android notification files + `MainActivity.kt` + the manifest.
  T02 is `lib/core/persistence/` + one repository + tests. Nothing overlaps.
- **T03 ∥ T08** — T03 is `lib/core/notifications/{policy,dispatcher,sources}`
  + `lib/app/bindings.dart`. T08 is `pigeons/background.dart` +
  `lib/core/background/` + the three Android background files +
  `MainActivity.kt` + the manifest. T08 does **not** touch `bindings.dart`
  (its composition-root wiring is deliberately deferred to T10, precisely so
  this pair stays disjoint).
- **T04/T05/T06/T07 ∥ T09** — the notification line touches
  `lib/core/notifications/sources/`, `bindings.dart`, and one E04–E08 seam
  file each (`call_signaling.dart`, `prekey_exchange.dart`,
  `group_membership_service.dart`, none for T07). T09 touches
  `pigeons/background.dart`, the background generated/native files and
  `lib/core/background/`. Disjoint.

Files written by more than one task, each **serialized by `depends_on`, not
by luck**:

| File | Writers | Serialized by |
|---|---|---|
| `android/app/src/main/MainActivity.kt` | T01 registers the notification host; T08 the background host | `T08 depends_on: [E10-T01]` |
| `android/app/src/main/AndroidManifest.xml` | T01 adds `POST_NOTIFICATIONS`; T08 adds `FOREGROUND_SERVICE` + `<service>` | `T08 depends_on: [E10-T01]` |
| `lib/app/bindings.dart` | T03, T04, T05, T06, T07 each register a source; T10 adds the lifecycle observer | the T03→T04→T05→T06→T07→T10 chain |
| `pigeons/background.dart` + its two generated files | T08 creates; T09 extends | `T09 depends_on: [E10-T08]` |
| `lib/core/background/background_service.dart` + `background_stub.dart` | T08 creates; T09 extends | same |
| `lib/core/persistence/database.dart` + `database.g.dart` | `E09-T01` (v15) and `E10-T02` (v16) — **a cross-epic collision** | `T02 depends_on: [E09-T01]` |

**Matrix empty.**

## Why there is no frontend task in this epic

`design_screens: [settings]` in the epic frontmatter is aspirational. Two
surfaces would be needed and neither is shardable under rule 2:

1. **The Notifications sub-screen.** `design/screens/settings.md` draws a
   *row* — elements 38-42, `notifications` · `Notifications` · `Alerts,
   silent modes, LED behaviors` — and **no destination screen exists in any
   of the fourteen measured contracts**. There is no `design/gaps.md` entry
   for it either (the closest precedents are `GAP-005`, still 🟡 proposed for
   Privacy & Security, and `GAP-024`, approved for Storage). A frontend task
   without an approved `design_contract:` is not shardable. `OQ-E10-1`.
2. **The Battery / background-execution sub-screen.** Same shape: elements
   33-37, `battery_full_alt` · `Battery` · `Background execution, power
   saving modes`, a row with no destination. `OQ-E10-1`.

Consequence, stated plainly: after this epic the notification categories and
privacy level are persisted, enforced and tested, and a user **cannot change
any of them from inside the app**. That is rule 2 working as intended, and it
is worth knowing before the gate clears rather than after.

A third surface is also fenced out: `E06-T12.md:116-117` handed "notifications,
background status, or connectivity change alerts" on the **Dashboard** to
E10 — but `design/screens/dashboard.md` is an *approved, measured* contract
with no such element, so adding one is an extra element needing its own
`design/gaps.md` entry and human approval. `OQ-E10-9`.

The copy this epic must ship anyway — notification titles/bodies and the
permanent foreground-service notification — is proposed inside each task's §5
so a reviewer can check it, and is flagged for the human at the analyze gate
rather than presented as approved design.

## Event log (append-only)
- 2026-08-26 E10 drafted during Wave 1 epic-breakdown; deferred to a later wave.
- 2026-09-04 `skills/task-sharding` pass. Step 0 (inherited obligations) read
  E04's and E06's `retro.md` §Open follow-ups, their `epic.md` §Bug sweep /
  §Open Questions, and every bug file in both epics (`E04-B01..B03`,
  `E06-B01..B04`) plus `E05-B02`, `E08-T06`, `E09-T05` and the E06 task files
  that name E10. **Neither retro mentions E10 at all** — all thirteen
  obligations live in task files. Findings in `epic.md` §ANALYZE REPORT.
  Epic EARS extended from 1 to 6 criteria so all five `traces_to:` FR ids own
  one (`EARS-NOTIFY-1/2`, `EARS-PLAT-2/3/4` added — no new scope; the FR ids
  were already claimed). `ADR-0007` written and left `⏳ AWAITING HUMAN`.
  Ten tasks written from `epics/_templates/task.template.md`. Collision
  matrix empty. `python agent/orchestrator/scheduler.py --validate` green.
  ANALYZE REPORT appended to `epic.md`; 🧍 `analyze_report` gate ⏳ AWAITING
  HUMAN — **no task dispatches until it clears.**
