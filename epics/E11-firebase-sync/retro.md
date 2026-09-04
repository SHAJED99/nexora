# E11 · Firebase Metadata Sync — Retro

**Date:** 2026-09-04 | **Sharded:** 2026-09-04 | **Build-complete:**
2026-09-04 | **Merged into `epic_11`:** progressively, 2026-09-04 |
**epic_11 → `development`:** not yet — PR #58 open, awaiting the human
merge gate.

## What shipped

6 sharded tasks (T01–T06: schema/path registry, security rules, device
registry semantics, revocation, own-account relationship mirror, public
device directory per `ADR-0008` option 2) + an original bug sweep (3
findings, all resolved) + a second, retroactive rule-5 re-review pass
(3 more findings: 2 fixed, 1 correctly deferred). Final state: **899/899
tests, `flutter analyze` clean, P1/P2 = 0**, verified locally at the
merge tip.

## What recurred (the richest signal — see `agent/memory/lessons/`)

1. **The third occurrence, in three epics this session, of the exact
   same rule-5 pattern: an epic's first two tasks reviewed same-model,
   later tasks correctly cross-model.** `E11-T01`/`T02` were both
   reviewed by `claude-sonnet-5` under "independent session" — the
   mitigation rule 5 explicitly rejects. Unlike E09 (where the epic's
   own bug sweep caught this as `E09-B05`), E11's bug sweep never
   surfaced it — the sweep found three real, different defects
   (`E11-B01`/`B02`/`B03`) without ever checking `reviewed_by` against
   `executed_by` across all six tasks. Caught only by this session
   deliberately repeating the `E09-B05` pattern-check against E10 and
   E11 after finding it once. Genuinely cross-model re-review of `T01`
   found one real S3 defect (`E11-B04`); of `T02`, one real S3 defect in
   scope (`E11-B05`) plus two more (S2/S3) on the neighboring
   `directory` node the same rules file owns (`E11-B06`, correctly
   deferred). Reinforces `L-process-016` (recurrence now 3 across E09/
   E10/E11) — the pattern is well past coincidence.
2. **A guard's regression test can be tautological in two distinct
   ways, and both slipped past a same-model review.** `E11-B04`: one
   test exercised a fake the test itself wrote, never the production
   service; two others compared a payload's *shape* to an allow-list,
   which is true identically whether the guard ran or not, because both
   real call sites can only ever build an already-safe payload. Neither
   is `E09-B07`'s exact shape (a delegation-proof comparing the wrong
   two things) or `E09-B12`'s (asserting one field of a result, not
   another) — a third distinct way a green test can prove nothing about
   the property it's named for. Filed as material for `L-qa-002`'s own
   pattern rather than a new lesson: "a test named for a guard's
   ordering, whose body never counts or blocks the guarded call,"
   generalizes `L-qa-002`'s "sweep asserts one field, not another" to
   "test observes the wrong thing entirely."
3. **A Firebase RTDB rules file can correctly validate every documented
   *leaf* field and still leave every documented *container* writable
   as an arbitrary blob**, because `.validate` does not cascade and a
   container with none of its own has no shape requirement at all —
   `$other`'s deny-unknown-child rule only ever fires on a named child,
   never on the container receiving a leaf instead of children. Found
   by a reviewer applying the security lens to an already-`APPROVE`d
   task specifically because rule 5 was known to be violated on it —
   the original same-model review verified every leaf's `.validate`
   string correctly and never asked "what if the write is a leaf at the
   container itself?" Fixed with `.validate: newData.hasChildren()` at
   every container level; falsified by stashing the fix and confirming
   the new tests fail with the exact predicted `Actual: <null>`.
4. **A permission-classifier block on a live mutation-based
   falsification (`L-infra-003`) recurred a second time, on a Firebase
   rules edit rather than a Dart decrypt-path edit** — same shape,
   different file type. Confirms `L-infra-003`'s scope is broader than
   "decrypt-adjacent Dart code": any edit that removes or weakens a
   security check, in any file type, appears to trip the same block.
   Not incrementing `L-infra-003`'s recurrence (same lesson, not a new
   occurrence needing its own entry) — noted here as reinforcing
   evidence for its own future promotion.
5. **A deferred-consequence bug's own resolution becomes precedent for
   the next one found in the same area.** `E11-B01` ("directory is never
   published, `status: blocked`, deferred to the first real consumer")
   was cited directly by `E11-B06` ("directory has two more real
   findings, also unreachable for the same reason, also deferred") —
   the first bug's own accepted resolution shape gave the second a
   ready-made, already-justified severity/priority/deferral pattern
   instead of re-litigating it from scratch.

## New lessons filed

None new this retro — all findings above are reinforcing evidence for
lessons already filed during `E09`'s retro this session
(`L-process-016`, `L-qa-002`, `L-infra-003`). Recurrence counts updated
in those files' own text rather than duplicated here (per the ladder's
own rule: never a second entry for the same lesson).

## Housekeeping fixed by this retro

- `epics/E11-firebase-sync/epic.md`'s `status:` field updated to record
  both the original sweep and the retroactive re-review pass.
- `E11-T01`/`E11-T02`'s `reviewed_by`/`reviewed_at`/`review_outcome`
  restamped to the genuine cross-model pass, with the superseded
  same-model review named explicitly rather than silently overwritten.

## Estimate calibration (§5)

No data — `metrics.csv` still doesn't exist for any epic (`L-process-015`,
resolved at E08's retro as a rule amendment).

## Open Questions — carried forward, not left dangling

- **`E11-B06` (directory-entry squatting + cross-account `ownerUid`
  readability) stays blocked** until a real `DeviceDirectoryService`
  caller exists (same gate `E11-B01` is already waiting on). Finding 1
  (squatting) is close to `ADR-0008`'s own territory and may need its
  own rule-3 pass once a caller is being designed, not a mechanical
  rules fix.
- **`OQ-E11-T06-1`/`-2`** (first-publish squatting, one-time prekey
  reuse) remain accurately described, unchanged by this retro.
  `OQ-E11-T06-3`'s *conclusion* (no delete path) is correct; its stated
  *mechanism* was corrected during the original sweep (folded there, not
  re-litigated here).
- **The permission classifier's scope** (now confirmed to cover both a
  Dart decrypt-path edit and a Firebase rules edit) is worth a
  concrete test the next time a similar block occurs: does it fire on
  *any* file under a to-be-determined content heuristic, or
  specifically on files this project's own crypto/security layer
  touches? Not answerable from two data points; flagged for whoever
  hits it a third time.

## Human decisions — still open

1. **`retro_promotions` gate** for the `L-process-016` recurrence bump
   (now 3, crossing the ladder's own "2nd time → becomes a rule"
   threshold a second time over) and the `L-infra-003` reinforcement.
2. **`E11-B06`'s finding 1 fix direction** (binding `$deviceId` to the
   identity being published) — flagged in the bug file as "close to
   `ADR-0008`'s own territory," a human call once a real caller is being
   built, not before.
3. **The `epic_11` → `development` merge itself** (PR #58, rule 5 —
   every task now genuinely cross-model reviewed, confirmed by this
   retro's own re-review pass, not merely claimed).
4. **`firebase deploy --only database`** — still entirely the human's
   action; this retro's `E11-B05` fix changes what gets deployed but
   does not touch who deploys it or when (`OQ-E11-T02-1`).

`make health` re-run after this retro's edits: H3 now passes for E11
(this file exists); H4/H5/H7's failures are unchanged E05/E06/E08
legacy, outside E11's scope, exactly as E08's and E09's own retros
already recorded.
