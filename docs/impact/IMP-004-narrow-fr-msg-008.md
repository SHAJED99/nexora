# IMP-004 — Narrow FR-MSG-008 to the implemented REVOKE-DEVICE operation

**Gate:** 🧍 `change_impact_approval` — ✅ cleared by Shajedur Rahman Panna on 2026-09-22
(this report is the blast-radius walk, written **before** any edit lands, per `skills/change-impact`
§1–3; the patch it covers was applied after this gate was cleared)

**Class:** narrowed scope. A named functional requirement's scope is reduced to
the behaviour that is actually built. No id is created, no id is retired, no
code or test changes, no ADR is superseded.

**Raised by:** the traceability blocker inventory (2026-09-22). `FR-MSG-008`
sits in `req_no_test`: no task ever claimed it and no EARS criterion cites it.
The investigation that followed found that one of its five change types is
fully built and synced, and that the other four lost their consumer when
`FR-TRUST-007` was descoped (`IMP-002`).

## The change

`FR-MSG-008` currently requires five security-sensitive relationship changes
(TRUST, BLOCK, UNBLOCK, REMOVE-TRUST, REVOKE-DEVICE) to be represented as
discrete events/operations. It is narrowed to **REVOKE-DEVICE only**, which is
the one the system actually implements this way. The requirement keeps its id,
its `traces_to: BRD §40` and its "discrete operation, for predictable
synchronization across the account's own devices" intent.

## The decision (human, 2026-09-22)

Option (b) of three presented: **narrow, rather than descope in full or build
the missing event model.** The human additionally directed:

- the narrowed wording must **not** use the word "monotonic";
- **`EARS-FB-10` only** carries the new citation — `EARS-FB-11` must not, since
  it is an `FR-MSG-007` merge criterion and a second citation there would
  repeat the citation-drift pattern already being cleaned up;
- `documentation/BRD.md` is **not** edited.

## Why this is honest, not a coverage manoeuvre

`E11-T04` built `DeviceRevocationService` and the `device_revocations` table: a
discrete revocation record written locally and best-effort published to the
account's Firebase device registry, with `pullRevocations` merging the other
way. That is what the narrowed sentence asks for, and it predates this report
by weeks. The narrowing adds no test and changes no behaviour — it makes the
requirement describe the system as built, and states plainly what is not built.

## What is NOT claimed

**TRUST, BLOCK, UNBLOCK and REMOVE-TRUST are NOT represented as synced discrete
events.** They remain mutable relationship state — one `relationships` row per
device, overwritten in place by `upsert` — with no event or operation log and
no cross-device propagation. BRD §40 keeps the original five-change scope; the
SRS requirement is deliberately narrower. **Reviving event-based
synchronization for those four requires a new FR id and a fresh human
decision.**

## Blast radius

| Artifact | id | Impact | Action |
|---|---|---|---|
| `spec/srs.md` | `FR-MSG-008` | The requirement being narrowed | **edit** — narrowed wording + a "Why narrowed" note; id, intent and BRD trace retained |
| `documentation/BRD.md` | §40 | The source document states five changes | **no edit** — the BRD is the human's source of record; the gap is documented in the SRS instead |
| `spec/feature-list.md` | Feature: Conflict Resolution | Lists `FR-MSG-007, FR-MSG-008` | **edit** — narrowing note added; `FR-MSG-007` unaffected |
| `spec/knowledge-map.yaml` | — | Carries no `FR-MSG-*` pointer | no edit needed (verified by grep) |
| `spec/srs.md` | `FR-MSG-007` | Precedence table incl. BLOCK > TRUST | **no change** — separate requirement, own criterion (`EARS-MSG-4`), own tests |
| `spec/srs.md` | `FR-TRUST-007` | Already descoped (`IMP-002`) | no change — cited here as the reason the four lost their consumer |
| `spec/srs.md` | `FR-FB-001` | Names revocation information among what Firebase may store | no change — `EARS-FB-10` keeps citing it; the new citation is additive |
| `epics/E11-firebase-sync/epic.md` | `EARS-FB-10` | Gains `FR-MSG-008` | **edit** — `(FR-FB-001)` → `(FR-FB-001, FR-MSG-008)` |
| `epics/E11-firebase-sync/tasks/E11-T04.md` | `EARS-FB-10` | Same criterion, restated in the owning task | **edit** — identical change, so the two declarations cannot drift |
| `epics/E11-firebase-sync/epic.md` | `EARS-FB-11/12/13` | Support the same feature | **no change** — `EARS-FB-11` deliberately not cited (human decision above) |
| `epics/E11-firebase-sync/tasks/E11-T04.md` | `traces_to:` | Did not list `FR-MSG-008`, leaving the requirement in the non-blocking `req_no_task` class | **edit** — `FR-MSG-008` added; `E11-T04` is the task that built the revocation operation |
| `epics/E05-messaging-reliability/epic.md` | `traces_to:` | Still lists `FR-MSG-008`, which E05 never sharded | **not edited** — historical record, and the id stays live, so the trace is not wrong. See Follow-ups |
| `epics/E05-messaging-reliability/epic.md` | Analyze report | Records the EARS trace as passing while `FR-MSG-008` owned no criterion | **not edited** — historical; the gap is routed in Follow-ups |
| `agent/memory/decisions/ADR-0008` | — | Governs the Firebase sync boundary | **no change** — it neither creates nor depends on `FR-MSG-008`; the revocation node predates and survives this |
| `agent/memory/decisions/ADR-0005` | — | Device identity/session independent per device | **no change** — unaffected; it is part of why the four have no consumer |
| Open questions | — | No OQ cites `FR-MSG-008` (repo-wide grep) | no action |
| `lib/core/services/device_revocation_service.dart`, `lib/core/persistence/revocation_table.dart` | — | The implementation the narrowed requirement describes | **no change** |
| `lib/features/messaging/domain/conflict_resolver.dart` | — | Header anticipates future `RelationshipRepository` integration; `resolveTrust` still has no production caller | **no change** — recorded as a standing observation, not a defect |
| Tests | `test_EARS_FB_10_revoke_writes_local_then_firebase` | Becomes the evidence for `FR-MSG-008` | **no change** — it already exists and passes |
| `docs/traceability.md` | — | Generated | **regenerate** |
| `docs/impact/IMP-002-descope-fr-trust-007.md` | — | Cited as the cause for the four | **no edit** — this is a separate, later decision |

## Effort / risk

**Effort:** XS — four documentation lines plus this report. **Risk: low.** No
code, test, ADR, OQ or task-status change, so no behaviour can regress; the
suite is unchanged and must stay green. The real risk is *epistemic*: a reader
must not come away believing all five change types are event-based. That is
mitigated by stating the exclusion in all three places a reader lands —
`spec/srs.md`, `spec/feature-list.md`, and this report.

## Deviation from `skills/change-impact` §5

That step says "changed behavior gets **new ids**". No behaviour changes here —
the system is untouched and the requirement is being reduced to what already
exists — and the human explicitly directed that no new requirement number be
invented. Recorded as a deliberate, human-directed deviation rather than left
implicit.

## Traceability effect

Measured against the baseline at `c312f8a`:

| Class | Before | After | Blocking? |
|---|---:|---:|---|
| requirement with no test | 13 | 12 | yes |
| `done` task with no EARS test | 8 | 8 | yes |
| `done` task whose dependency is not done | 0 | 0 | yes |
| superseded ADR still cited | 0 | 0 | yes |
| **Blocking orphans** | **21** | **20** | |
| requirement owning no EARS criterion | 13 | 12 | no |
| requirement with no task | 6 | 5 | no |
| `done` task tracing only descoped requirements | 1 | 1 | no |

All other orphan classes are unchanged. `FR-MSG-008` now reaches `EARS-FB-10`
→ `test_EARS_FB_10_revoke_writes_local_then_firebase`
(`test/core/services/device_revocation_service_test.dart`).

## Follow-ups (routed, not performed here)

| # | Item | Owner |
|---|---|---|
| 1 | `FR-MSG-008` was never sharded into a task by E05, and E05's analyze report still records its EARS trace as passing. A sharding-gate gap, independent of this change | planner, at retro |
| 2 | `ConflictResolver.resolveTrust` has had no production caller since `E12-B03`/`E12-B11` — live and tested, but unreached | planner, standing observation |
