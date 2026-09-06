# IMP-002 — Descope FR-TRUST-007 (own-account relationship-state sync)

**Gate:** 🧍 `change_impact_approval` — ✅ cleared by human on 2026-09-06
(decision made by the human and relayed with `E12-B11`'s dispatch; this report
is the record of that decision and of the walk performed while executing it,
written after the fact rather than before — noted here honestly rather than
implied otherwise)

**Class:** dropped scope. A named functional requirement becomes
not-applicable, and the code built for it is deleted.

**Raised by:** `E12-B11` (reviewer-found, during review of the `E12-B02` /
`E12-B03` fix), which offered two directions and explicitly left the choice to
the human as a spec decision.

## The change

`FR-TRUST-007` ("Where Firebase is available, relevant relationship
configuration shall synchronize through it") is marked **descoped**, and
`RelationshipSyncService` (`push` / `pull`, built by `E11-T05`) is deleted
along with its test file.

## The decision (human, 2026-09-06)

Formally descope `FR-TRUST-007` and delete the now-fully-dead
`RelationshipSyncService` code. The reasoning:

- Read narrowly per `ADR-0008`, `FR-TRUST-007` meant "an account's own devices
  agree on peer-relationship state". `ADR-0005` already makes device identity
  and session state fully independent per device, and each device evaluates
  authorization for itself (`FR-TRUST-003`, `FR-TRUST-005`) — so no product
  behaviour depends on two of an account's own devices holding the same
  trust/block opinion.
- The one use case that genuinely needed a device-to-device signal was
  **device-enrollment approval**. `E12-B03`'s fix moved that onto a dedicated
  enrollment-grant channel (`users/$uid/deviceEnrollmentGrants/*`, read
  directly rather than merged through `ConflictResolver`) — deliberately,
  because running an authorization *grant* through a restrictive-wins conflict
  resolver was that bug's root cause.
- `push` never had a production caller even before this epic (`E12-B02`'s
  original finding); `E12-B03` correctly removed `pull`'s last one. What
  remained was 186 lines of production code and 492 lines of test with no
  production caller at all.

**Nothing supersedes this requirement.** Cross-account relationship-state
exchange was already declined permanently by `ADR-0008`; the own-account half
is now declined too. Reviving it requires a new FR id and a fresh human
decision — not a revert of this report.

## Blast radius

| Artifact | id | Impact | Action |
|---|---|---|---|
| `spec/srs.md` | `FR-TRUST-007` | Requirement descoped | done — marked ⛔ DESCOPED with the reasoning inline; **id retained, text retained** (tasks trace to it) |
| `spec/feature-list.md` | Feature: Relationship Controls | Feature now `FR-TRUST-006` only | done — descope note added |
| `spec/knowledge-map.yaml` | — | No node: the map never carried an `FR-TRUST-*` requirement pointer | no edit needed (verified by grep) |
| `agent/memory/decisions/ADR-0008` | `ADR-0008` | Still accurate as history — it *narrowed* `FR-TRUST-007`, it did not create it. Its cross-account decline is unaffected | note added; **ADR not superseded and not edited in substance** — a descoped requirement does not reverse the decision that scoped it |
| `epics/E11-firebase-sync/epic.md` | `EARS-FB-14` | Sole criterion for `FR-TRUST-007` | done — marked ⛔ RETIRED, text kept |
| `epics/E11-firebase-sync/epic.md` | `EARS-FB-15` | Only reachable via `pull`'s remote read | done — marked ⛔ RETIRED. `ConflictResolver.resolveTrust` and `FR-MSG-007` are **untouched** and still tested |
| `epics/E11-firebase-sync/epic.md` | `EARS-FB-16` | Security rule on `users/$uid/relationships/*` | **no change** — the rule and its node still exist and are still correct; see Residual surface below |
| `epics/E11-firebase-sync/tasks/E11-T05.md` | `E11-T05` | The task that built the deleted code | **left untouched by design** — a completed task file is the historical record of what was built and why. A `## Descoped` note is added at its end only, changing no contract field |
| `lib/core/services/relationship_sync_service.dart` | — | 186 lines | **deleted** |
| `test/core/services/relationship_sync_service_test.dart` | — | 492 lines | **deleted** |
| `lib/core/services/firebase_paths.dart` | `relationships`, `relationship` | Doc comments cite `RelationshipSyncService` / `FR-TRUST-007` | done — comments corrected; **functions kept**, see Residual surface |
| `lib/core/services/firebase_boundary.dart` | `FirebaseNodeKind.relationship` | Allowlist comment cites `push` | done — comment corrected; entry kept |
| `lib/core/crypto/identity_service.dart`, `lib/core/services/device_directory_service.dart` | — | Comments cite `RelationshipSyncService` as a live sibling pattern | done — references re-pointed at `DeviceRevocationService`, which is live |
| `lib/features/location/domain/location_share_service.dart` | — | Comment defers work "to FR-TRUST-007 (E11)" | done — corrected to say the deferral target is descoped |
| `docs/firebase-schema.md` | `relationships/$peerDeviceId` row | Documents a node whose only writer is gone | done — row marked descoped/unused, cross-referenced to this report |
| `epics/E12-account-recovery/tasks/E12-B10.md` | `E12-B10` | `traces_to: [FR-TRUST-007]` is its **only** trace, and it is now a descoped id | **flagged, not edited** — see Follow-ups |
| `epics/E12-account-recovery/tasks/E12-B09.md` | `E12-B09` | Also traces `FR-RECOVER-001`, so it keeps a live trace | flagged only |
| `epics/E12-account-recovery/tasks/E12-B02.md`, `E12-B03.md` | — | `done` bugs tracing a now-descoped id | no action — historical, and both also trace `FR-RECOVER-001` |
| `epics/README.md` | Firebase dependency ordering note | Mentions `FR-TRUST-007` (E02) ordering | done — descope noted |
| Tests | `test_EARS_FB_14`, `test_EARS_FB_15` | Lived only in the deleted test file | removed with it — no orphan test asserts retired behaviour |

## Effort / risk

**Effort:** XS — a pure deletion plus documentation. **Risk: low, and
mechanically checkable.** The entire risk of this change is "something still
calls it", and that is answered by grep plus a green suite, not by judgement:
`grep -rn RelationshipSyncService lib/ test/` returned only the deleted files
and comments before the change, and returns nothing after it.

## Residual dead surface (deliberately NOT deleted here)

With the service gone, nothing reads or writes `users/$uid/relationships/*`.
Left in place on purpose, because removing them exceeds this bug's sanctioned
scope and one of them has an operational consequence:

1. `FirebasePaths.relationships` / `FirebasePaths.relationship` — pure
   functions, now unreferenced.
2. `FirebaseNodeKind.relationship` and its field allowlist — now unreferenced.
3. The `relationships` node in `database.rules.json` and `EARS-FB-16`, which
   guards it. **Deleting a deployed security rule is an operational change**,
   not a code cleanup, and is a rule-3 call the 2026-09-06 decision does not
   cover. Leaving a *restrictive* rule on an unused node is safe; removing it
   carelessly is not.

Each is marked in-place with a comment pointing here, so the next reader does
not rediscover them as a fresh bug.

## Follow-ups (routed, not performed here)

| # | Item | Owner |
|---|---|---|
| 1 | `E12-B10` (`status: todo`, S4) traces **only** `FR-TRUST-007`. Its subject — the device-enrollment-grant Firebase rule's same-account self-grant gap — is really `FR-RECOVER-001` work. Its `traces_to:` should be re-pointed before it is dispatched, or rule 1 is satisfied only by a descoped id | planner, at `E12-B10`'s dispatch. **Not edited here** — retargeting another open bug's contract is outside this bug's fence |
| 2 | Decide whether to retire the `relationships` node from `database.rules.json` (and with it `EARS-FB-16` and the path/allowlist helpers above) | human — operational/rule-3 call, needs its own decision |
| 3 | Regenerate `docs/traceability.md` so `FR-TRUST-007` reports as descoped rather than as an uncovered requirement | planner, next traceability run |
