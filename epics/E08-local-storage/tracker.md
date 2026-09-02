# E08 · Local Storage & Management · Progress

**Status:** `E08-T01` (schema migration) and `E08-T07` (design gap pass)
both merged, reviewed APPROVE. All 6 open questions from sharding
resolved by the human 2026-09-02 (see `epic.md` §Open Questions). ·
**Started:** 2026-09-02 ·
**Completed:** — · **Progress:** 2/8 sharded (+1 prospective)

**Remaining gate before T08/T09 can proceed:**
- 🧍 `design_contract_approval` for `GAP-024`…`GAP-027` (`design/gaps.md`)
  — ⏳ AWAITING HUMAN — gates T08's build, and gates T09 being sharded at
  all. `E08-T07` produced the contracts; approval of the gap entries
  themselves is a separate, still-open gate.

**Cleared 2026-09-02:** `analyze_report` (human resolved all 6 OQs at
sharding), `db_schema_migration` (`OQ-E08-T01-1`, human approved T01's
DDL as specified), `OQ-E08-1` (storage denominator — device free space +
no fabricated percentage), `OQ-E08-3` (Smart Mode excludes conversation
content by default).

## Tasks

| id | title | layer | size | MoSCoW | depends_on | status |
|---|---|---|---|---|---|---|
| E08-T01 | Storage schema migration v14 | backend | M | must | — | done · builder (sonnet) → reviewer (opus) · APPROVE · squash-merged `4507119` (PR #17) + follow-up fix `43b891f` |
| E08-T02 | Storage inventory read model | backend | M | must | T01 | todo |
| E08-T03 | Access-frequency signals | backend | S | should | T01 | todo |
| E08-T04 | Smart Mode — the eight-factor plan | backend | M | must | T01, T02, T03 | todo |
| E08-T05 | Manual policies + mode selection | backend | S | should | T01, T02 | todo |
| E08-T06 | Retention execution + decision log + wiring | backend | M | must | T04, T05 | todo |
| E08-T07 | Design gap pass | docs | M | must | — | done · planner (opus) → reviewer (sonnet) · APPROVE · squash-merged `a94e483` (PR #16) |
| E08-T08 | Dashboard Local Storage card | frontend | M | must | T06, T07 | todo — blocked on 🧍 `design_contract_approval` GAP-024/025 |
| E08-T09 | Storage settings screen | frontend | M | should | T05, T06, T07 | **prospective — not sharded** |

**Why T09 has no task file yet:** rule 2. Its `design_contract:` would be
`design/screens/settings-storage.md`, which `E08-T07` has not written —
`scheduler.py --validate` rejected exactly that and was right to. Shard it
the moment T07 lands and `GAP-024` is cleared. **When sharding it, do not
give it `test/design/design_probe_test.dart`** — `E08-T08` owns that file.

```mermaid
graph TD
  T01[T01 schema v14] --> T02[T02 inventory]
  T01 --> T03[T03 access signals]
  T01 --> T05[T05 manual policies]
  T02 --> T04[T04 Smart Mode]
  T03 --> T04
  T02 --> T05
  T04 --> T06[T06 execute + log + wire]
  T05 --> T06
  T07[T07 design gap pass] --> T08[T08 dashboard card]
  T06 --> T08
  T07 -.-> T09[T09 storage settings screen · prospective]
  T06 -.-> T09
  T05 -.-> T09
```

**Parallel sets, in order:** {T01, T07} → {T02, T03} → {T04, T05} → {T06} →
{T08}, with T09 sharded and slotted after T07 lands. WIP cap is 3
(`harness.yaml`), so the widest set fits.

**Anti-collision:** no two tasks in any parallel set share a file. Sole
owners of the contended paths: `lib/core/persistence/*` → T01 ·
`lib/app/bindings.dart` + `messaging_coordinator.dart` → T06 ·
`lib/features/dashboard/**` + `test/design/design_probe_test.dart` → T08 ·
`lib/features/chat/**` → T03 · `design/**` → T07. `lib/app/routes.dart`
and `lib/features/settings/**` are reserved for T09 and touched by no
sharded task.

## Carried-forward observations (not yet a task)

_(empty at sharding — created deliberately so it has a reader from day one.
`L-process-008`, a rule since E06: **read this section before each new
dispatch and cross-check the next task's `files:` fence.** E06's
highest-severity finding, `E06-B02` (S1), sat correctly recorded in this
exact section for eight tasks with no reader.)_

- **2026-09-02 · E08 sharding · the eight factors are not eight equal
  things (advisory, S3).** Six of `FR-STORE-005`'s factors have real inputs
  in this build; *storage pressure* and *importance* have none
  (`OQ-E08-1`, `OQ-E08-4`). `E08-T04` reports them `unavailable` rather
  than defaulting them — **check at every downstream dispatch that no
  reader has quietly started treating `Unavailable` as `0.0`**, which would
  reintroduce the synthesized-measurement defect E04-B03 established the
  prohibition against. Owner: T06, T08 and T09 dispatches.

- **2026-09-02 · E08 sharding · relay retention has an owner already
  (advisory, S4).** `RelayEngine.reclaimPayloads` (E04-B02) on
  `MessagingCoordinator`'s tick (E06-T06) owns relay payload TTL. Three
  E08 fences forbid touching it. **Check at T06's dispatch** that the
  storage pass appended to the tick has not been placed *before* the
  existing reclaim, and that a storage-pass failure cannot abort the
  messaging work in the same tick.

- **2026-09-02 · E08 sharding · FR-STORE-002/003 are claimed by this epic
  and built by nobody (`OQ-E08-5`).** Recorded here as well as in the
  epic's Open Questions so it survives the epic close: if the human
  chooses option (ii), it needs an IMP report at the time the media-path
  task is created, not at E08's retro.

- **2026-09-02 · E08-T01 review (F2) · `onCreate` is not re-runnable at
  all — pre-existing, not introduced by T01 (advisory, S3).** A fresh
  install killed mid-`onCreate` and reopened fails on
  `SqliteException(1): index idx_messages_conversation_created_at already
  exists` — an E05-era `Migrator.createIndex` call with no `IF NOT
  EXISTS`. Reproduces identically on `epic_08` base, unrelated to storage.
  Out of E08's fence entirely; recorded so it has a reader before the E08
  sweep (or any future infra-hardening pass) rather than being lost.

## Event log (append-only)
- 2026-08-26 E08 drafted during Wave 1 epic-breakdown; deferred to a later wave.
- 2026-09-02 Sharded into 8 tasks (+1 prospective) by the planner against `development` @
  `66d3a3f` (698/698 green, E07 and its retro fully merged).
  `skills/task-sharding` §0 run before slicing per `L-process-007`: E06's
  and E07's `retro.md`, both trackers' §Carried-forward observations and
  §Bug sweep, E06's `epic.md` (whose T15/T17 rows name E08 by id), E07's
  `epic.md` PTT/FR-STORE-002 passage, `design/gaps.md` and
  `dashboard_controller.dart`'s own header were all read — **12 inherited
  obligations enumerated, 0 dropped** (see `epic.md` §Inherited
  obligations). Design gap pass added `GAP-024`…`GAP-027` to
  `design/gaps.md`, all 🟡 with bare `approved by:` lines
  (`L-process-002`); two of the four deliberately carry **no proposal**,
  only named forks. **Six Open Questions raised rather than guessed** —
  two 🔴 blocking (`OQ-E08-1` the storage denominator, `OQ-E08-3` what
  Smart Mode may delete by default), four ⚠️ important (`OQ-E08-2`
  NFR-SCALE-001's missing number, `OQ-E08-4` the undefined "importance"
  and "temporary status", `OQ-E08-5` FR-STORE-002/003 have no owner,
  `OQ-E08-6` E08 is not in an approved wave). Analyze report appended to
  `epic.md`; 🧍 `analyze_report` gate ⏳.
- 2026-09-02 **A-002 checked explicitly, as the sharding brief asked.**
  A-002's own recorded statement covers *group size and relay hop count*,
  and its revisit trigger names the groups and routing epics — **storage
  is outside its scope**, so E08 cannot defer under it. Raised as
  `OQ-E08-2` with an advisory to extend the same placeholder *shape* to
  storage via a new `A-004`, which keeps E08 unblocked without pretending
  A-002 already covered it.
- 2026-09-02 **`E08-T09` deferred to prospective during the same pass.**
  The first draft sharded it with `design_contract:
  design/screens/settings-storage.md`; `scheduler.py --validate` rejected
  it — that file is `E08-T07`'s deliverable and does not exist yet. Rule 2
  and E07's own precedent both say the same thing, so the task file was
  removed rather than the contract faked, its shape recorded in `epic.md`
  §Prospective and in `GAP-024`, and its one inherited obligation (the
  `L-design-002` probe-fixture seed) re-homed to `E08-T08`, which owns that
  file. Validator clean afterwards.

## Review log

### E08-T01 — 2026-09-02 — 📋 **APPROVE** (reviewer: `claude-opus-5`; `executed_by`: `claude-sonnet-5` ✅ rule 5)

- **DDL: verified against a real `sqlite_master` dump**, not source
  reading — column-for-column identical to the human-approved §5 contract.
  `budget_bytes INTEGER NULL` with no `DEFAULT`, both PKs and both indexes
  exact.
- **scope: clean.** `pubspec.yaml`/`pubspec.lock` zero bytes changed;
  `messages`/`delivery_states`/`relay_packets`/`routes`/`sync_cursors`/
  group-crypto tables confirmed untouched by diff AND by the migration
  test's own byte-identical DDL assertion pre/post.
- **atomicity: proven by differential fault injection**, not just read.
  Reviewer threw inside the migration step with and without the
  transaction wrap — without it, all three tables persisted half-created
  after a simulated crash (the exact hazard §6 named); with it, zero
  tables and `user_version` unchanged.
- **exact-set-equality migration test: independently re-falsified.**
  Reviewer injected their own extra table, reproduced the claimed failure
  signature exactly, reverted, confirmed green — not trusting the
  builder's report of their own falsification.
- **default-row tests: confirmed structurally distinct** `onCreate`
  (`NativeDatabase.memory()` → `wasCreated`) vs. `onUpgrade` (raw v13 DB →
  `hadUpgrade`) paths — no shared hook that could fake one via the other.
- **`database.g.dart`: confirmed genuinely regenerated.** Reviewer reran
  `build_runner` themselves — byte-identical output, zero diff.
- **suite: 713/713**, `flutter analyze` clean, both re-run by reviewer.

**Two non-blocking findings, both recorded rather than gated on:**
- **F1 (S3) — the default-row insert wasn't retry-safe** against a crash
  in drift's post-`onUpgrade` version-stamping window (reproduced via
  fault injection: `UNIQUE constraint failed` on re-run). Reviewer's
  recommended fix (`InsertMode.insertOrIgnore` on both insert call sites,
  zero risk, no re-review needed) applied directly by the orchestrator as
  a same-day follow-up commit (`43b891f`) — re-verified 713/713 green,
  analyze clean.
- **F2 (S3, pre-existing, not introduced by this task)** — see
  §Carried-forward observations above.

**Ready to squash-merge — done.** Squash-merged to `epic_08` as `4507119`
(PR #17), plus the F1 follow-up fix `43b891f`.

### E08-T07 — 2026-09-02 — 📋 **APPROVE** (reviewer: `claude-sonnet-5`; `executed_by`: `claude-opus-5` ✅ rule 5)

- **scope: in-contract** — diff confined to exactly the 4 claimed paths.
- **`approved by:` lines on GAP-024/025/026/027: directly grepped, genuinely
  blank** — no self-signature (`L-process-002`).
- **rule 2 primitive reuse: spot-checked**, including one honestly
  disclosed deviation (a title colour substituted because the parent
  screen's own value wasn't in its own measured token table).
- **`dashboard.md`'s generated table region: confirmed byte-identical**
  to HEAD via diff — only the new Derived-state section added.
- **OQ-E08-1/OQ-E08-3 fidelity: verified against the full open-question
  text**, not a paraphrase — copy matches the human's actual decision
  exactly (no fabricated percentage, "Not measured" never "0", Smart
  Mode's content-exclusion copy, empty state framed as expected-default
  not rare).
- **No forbidden UI element** (Clean Now / apply-now / dialog / delete
  affordance) found anywhere — confirmed by grep and cross-checked that
  no dialog primitive exists anywhere in this design system.
- Zero Dart files touched; suite result provably a no-op. Design gate
  correctly n/a for a pre-build derived contract.

**Ready to squash-merge — done.** Squash-merged to `epic_08` as `a94e483`
(PR #16).
