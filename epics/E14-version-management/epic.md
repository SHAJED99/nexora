---
id: E14
title: Version & Update Management
status: todo
type: feature
priority: { moscow: should, wsjf: 2.75 }
depends_on: []
traces_to: [FR-VER-001, FR-VER-002, FR-VER-003, FR-VER-004, FR-VER-005, FR-VER-006, FR-VER-007, FR-VER-008, FR-VER-009, FR-VER-010, FR-VER-011]
external_services: [Google Play]
ui_surface: [mobile]
design_screens: []
---
# E14 · Version & Update Management

## Business goal
Version negotiation (app/build/protocol/crypto/db), a mandatory-update
enforcement mechanism via Google Play's in-app update API, and safe schema
migrations that never destroy local conversations.

## Scope
**In scope:** version-state machine (UP_TO_DATE/UPDATE_AVAILABLE/
UPDATE_REQUIRED), non-dismissible mandatory-update UI, cached/offline
policy evaluation, signed version policy, migration-safe app updates.
**Out of scope:** FR-VER-004's simulation-framework requirement — noted as
likely belonging inside E04 instead (see E04's Test strategy), since that's
where route/network simulation is actually useful; flag at task-sharding if
you'd rather it live here.

## Acceptance criteria (epic-level, EARS)
- **EARS-VER-1**: WHEN installed version is UPDATE_REQUIRED, the system SHALL block communication and present a non-dismissible mandatory update prompt via Google Play. (FR-VER-006)
- **EARS-VER-2**: Mandatory updates SHALL NOT delete local messages, recordings, attachments, settings, or history. (FR-VER-009)

## Tasks
6 tasks, sharded 2026-09-05 — see `tracker.md`. One (`T03`) is sharded but
blocked on a human decision (`OQ-E14-T03-1`).

| Task | Title |
|---|---|
| E14-T01 | Version-policy Firebase schema, boundary registration, and local offline cache |
| E14-T02 | Version state machine (UP_TO_DATE / UPDATE_AVAILABLE / UPDATE_REQUIRED) |
| E14-T03 | Verify the version policy's signature before trusting it — **blocked**, `OQ-E14-T03-1` |
| E14-T04 | Mandatory-update screen and Google Play in-app update integration |
| E14-T05 | Extend the relay frame's version check to reject incompatible peers gracefully |
| E14-T06 | Migration-safety regression suite — no upgrade path ever destroys local data |

## Open Questions
- **OQ-E14-1 — where does FR-VER-004's simulation framework actually live?** Candidate homes: this epic (its own FR id) or E04 (where it's actually useful). Needs a human call at task-sharding time, not a silent pick.
  - **Status:** 🟡 open — **still unresolved after this sharding pass.**
    No task in this pass claims `FR-VER-004`; it remains an orphaned EARS
    trace (see ANALYZE REPORT below) until this question is answered.
- **OQ-E14-T03-1** (task-level, full detail in `E14-T03.md`) — is policy
  signing (`FR-VER-011`) appropriate for v1, and if so, with what key
  infrastructure? Blocks `T03` only; every other task is unaffected.
  - **Status:** 🟡 open

## Analyze report / Retro

### ANALYZE REPORT (2026-09-05)

| Check | Result |
|---|---|
| **EARS trace** | **FAIL, one orphan, carried forward deliberately.** `FR-VER-004` (the simulation framework) has no owning task — `OQ-E14-1` was already open before this pass and remains open; sharding six tasks for the other ten FR ids without silently picking a home for this one is the correct move per that question's own text ("needs a human call... not a silent pick"). Every other FR id traces cleanly: `FR-VER-001`/`002` → `T05`; `FR-VER-003`/`009` → `T06`; `FR-VER-005`/`008`/`010` → `T01`/`T02`; `FR-VER-006`/`007` → `T04`; `FR-VER-011` → `T03` (blocked, not orphaned — a task exists, it names its own blocker). Epic-level `EARS-VER-1`/`EARS-VER-2` trace to `T04`'s `EARS-VER-10..12` and `T06`'s `EARS-VER-15/16` respectively. |
| **Contract sanity** | PASS (vacuous) — no API/list endpoints; internal backend + one new screen. |
| **Collision matrix** | PASS, empty. `T02`/`T04` both may touch `pubspec.yaml`; serialized by `T04`'s `depends_on: [E14-T02]`, never parallel. |
| **Scope fences** | PASS. Every task's §4 is non-empty. `T03`'s is unusually short (task has no contract yet) but still states what it explicitly does not do. |
| **MoSCoW inflation** | PASS. 3/6 `must` (`T01`, `T02`, `T06` — the shared dependency, the core state machine, and the data-safety proof) = 50%, under 60%. |
| **Size** | PASS. Three `S` (`T02`, `T03`, `T05`), three `M` (`T01`, `T04`, `T06`). No `L`. |
| **Design** | PASS. `T04` carries `design_contract:` pointing at `GAP-029`'s approved, written contract. |
| **Obligation ownership** | PASS. `T04` names `T02`'s state machine and `T01`'s cache in prose but only as its own upstream inputs, consistent with each task's own contract independently owning that work. |
| **Inherited obligations** | PASS. `depends_on: []` at the epic level — no epic to inherit from. `OQ-E11-2` (E11's own retro/tracker note naming E14 as this node's future owner) is claimed by `T01`, closing that inherited obligation explicitly rather than leaving it unread. |

**On `T03`'s `status: todo`/`side: blocked` with an empty `files:`
fence**: this is deliberate, not a template violation — `skills/
task-sharding`'s own sizing smell test ("can't write the test names
before the code exists? the spec isn't ready — that's an Open Question,
not a task") describes exactly this case. The task file exists so
`FR-VER-011` has a reader and a place to land the decision (per
`skills/task-sharding` §0's own concern about an obligation with no
reader), not because it is ready to build.

🧍 **HUMAN GATE** (`analyze_report`): pending. Approval unlocks dispatch
for every task except `T03`, which additionally needs
`OQ-E14-T03-1` answered before it has a contract to dispatch.
