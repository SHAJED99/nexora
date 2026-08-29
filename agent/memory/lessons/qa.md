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
  🧍 `retro_promotions` ⏳ awaiting human.
