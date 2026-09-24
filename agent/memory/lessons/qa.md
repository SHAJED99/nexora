# Lessons — qa

Real findings from **this** project's reviews. Format + ladder: `README.md`.
`skills/retro` writes here; `agent/hooks/lesson-inject.py` injects these
automatically for matching tasks (see `index.yaml`).

## L-qa-001 — ✅ REINFORCING: the reviewer breaking the fix and watching the test fail is what actually caught things; a green suite never did
- date: 2026-08-29 | source: E05 — T01, T02, T03, T04 and B01 reviews
- situation: this entry records a practice that **worked**, not a miss. Four
  independent times in one epic, a reviewer refused to accept a passing test
  as evidence and produced its own falsification instead:
  - **E05-T04**: the suite was green (232/232). The reviewer wrote
    `Future.wait([recordLocalProgress(...,10), recordLocalProgress(...,4)])`
    and got a cursor of 4 — a real lost-update race no existing test's shape
    could have shown (L-backend-003 #5).
  - **E05-T02**: rather than trust the passing sequence-number test, the
    reviewer ran a 60-way concurrent probe *and* read drift's own
    `NativeDatabase`/`NoTransactionDelegate` source to confirm the lock is
    actually held across `BEGIN`…`COMMIT`. The claim was true — and is now
    true *for a stated reason*, which is what let E05-B01's fix safely move
    encryption outside that transaction later.
  - **E05-T03**: same class re-checked and cleared on evidence (drift's
    locking plus `messages.id`'s PRIMARY KEY as a second line of defence),
    with the reasoning written down so it is not re-litigated.
  - **E05-B01 round 2**: the reviewer found the new regression test did not
    discriminate — the crafted buffer threw pre-fix too, for the wrong
    reason. The re-fix then deleted the version-byte check, watched the test
    fail (`Actual: <Instance of 'MessageEnvelope'>` — the garbage envelope
    parsing cleanly, exactly the bug), and restored it byte-for-byte. A test
    that had "passed" was proven worthless and replaced.
  - **E05-T01**: the same posture at a different altitude — the reviewer
    checked what drift's `createTable()` does on *upgrade* versus
    `createAll()` on a fresh install, and found upgraded installs would
    silently get no index on the keyset-paginated query. No test could have
    failed for this; only reading the library could.
- root cause (of why this works): a test proves the code does what the test
  says. It cannot prove the test says anything. The only cheap way to close
  that gap is to break the code deliberately and watch the test go red for
  the right reason — everything else is a green light with unverified wiring
  behind it. Reviewer-run probes have the additional property that the
  builder cannot have tuned the code to them.
- fix applied: nothing to fix — promoted so it stops depending on individual
  reviewer diligence. `skills/review` §2 now requires falsification for any
  test that is the sole evidence for a fix or an invariant/concurrency
  claim: break it, confirm it fails for the right reason, restore.
- recurrence: 5 (occurrences of the practice paying off, not of a miss)
- status: promoted-to-rule — `agent/skills/review/SKILL.md` §2
  ("Falsify the evidence"), 2026-08-29 via `skills/retro`,
  🧍 `retro_promotions` ✅ approved by the human, 2026-09-03 (E08 retro —
  retroactive cleanup, live and operating successfully since 2026-08-29).

- **2026-09-03 (E08 retro) — the promoted rule held through an entire
  epic-level bug sweep, at higher scale and against harder cases than
  anything it was promoted on.** Every one of E08's seven sweep bugs was
  closed only after the reviewer broke the fix and watched the right test
  fail: `E08-B01`/`E08-B02`'s reviewer built a real-database multi-kind
  interleaving probe to rule out a k-way-merge subtlety no unit test could
  see; `E08-B03`'s round-2 reviewer forced a 40,000-id/~80-chunk atomicity
  rollback rather than trust the round-1 fix's own smaller-scale proof;
  `E08-B07`'s round-2 reviewer wrote an independent probe with ages shuffled
  against ids specifically because the builder's own end-to-end test could
  not rule out an id-order/created-at-order coincidence, then asserted exact
  id-set equality across all three tables the fix touches — catching that
  the builder's own test had never re-exercised `E08-B03`'s orphan-row
  finding at all. Every falsification reproduced its exact predicted failure
  signature before being restored. Not incremented (no new occurrence of a
  miss the practice caused to be caught) — recorded because the rule paid
  for itself at real production-scale stakes this time, not toy fixtures.

## L-qa-002 — a truth-table sweep that asserts one field of a multi-field result (e.g. `isVisible`) but not another (e.g. `reason`) leaves the untested field's own precedence order unguarded, and this exact shape survived two independent review passes on the same test file before a third caught it
- date: 2026-09-04 | source: E09-B07 (delegation-proof test proved
  nothing) → its own fix's sweep test → E09-B12 (found by a later,
  separately-dispatched cross-model re-review of the same function)
- situation: `E09-B07`'s fix added a truth-table sweep over all four
  `(globalEnabled, peerEnabled)` input combinations, correctly comparing
  the policy's `isVisible` output against an independent resolver's
  verdict on the same inputs — closing the exact gap `E09-B07` itself
  found. But `isVisible` cannot distinguish `globalOff` from `peerOff`;
  both make it `false`. A later, independently-dispatched cross-model
  review of the *same function* (`E09-B05`'s re-review of `E09-T02`)
  found that no test anywhere asserted `result.reason` for the
  `(false, false)` combination — a mutant inverting the `globalOff >
  peerOff` precedence order survived the sweep `E09-B07` had just added,
  survived every other test in the file, and survived all 914 tests in
  the suite. Filed and fixed as `E09-B12` by extending the same sweep to
  also assert `reason`, not adding a fifth standalone test.
- root cause: a sweep loop that asserts *some* property across every
  input combination reads as "this combination is covered" even when
  the asserted property is coarser than the actual behavior being
  guarded. Nothing about `skills/review`'s falsification discipline
  (`L-qa-001`) distinguishes "this test executes the code path" from
  "this test's assertion is precise enough to catch the specific bug
  shape the reviewer is worried about" — both look identical in a
  passing test run, and only a reviewer who mutates the *specific
  precedence line* (not just the pass/fail of the wrapping condition)
  finds the gap.
- fix applied: none in project code beyond `E09-B12`'s own fix. Recorded
  as its own lesson because the pattern is a specific refinement of
  `L-qa-001`, not a duplicate: falsify not just "does some assertion in
  this test fail," but "does the assertion fail for a mutation of the
  EXACT line the test claims to guard" — a sweep over one field of a
  multi-field result needs a matching sweep (or an explicit companion
  assertion) over every other field the underlying decision produces.
- recurrence: 1
- status: lesson
