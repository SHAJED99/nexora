# Lessons — process

Real findings from **this** project's reviews. Format + ladder: `README.md`.
`skills/retro` writes here; `agent/hooks/lesson-inject.py` injects these
automatically for matching tasks (see `index.yaml`).

## L-process-001 — a task-file `review_outcome` with an unquoted colon breaks YAML frontmatter parsing silently, and the error message points at the wrong problem
- date: 2026-08-27 | source: `scheduler.py --validate`, orchestrator session
- situation: Three task files' `review_outcome:` values contained an
  unquoted colon inside descriptive text (e.g. `changes_requested (1
  blocking: fixed post-review)`). YAML read the colon as a new mapping key,
  which made the whole frontmatter block fail to parse — and the
  validator's downstream symptom was "missing traces_to" on all three
  files, which is misleading: the field wasn't missing, the parse failed
  before any field could be read.
- root cause: nothing enforces or reminds that free-text frontmatter values
  (`review_outcome`, and by the same logic any hand-written summary field)
  need quoting the moment they contain a colon, a task file template
  doesn't flag it, and the validator's error for an unparseable frontmatter
  block reports as if specific fields were absent rather than surfacing
  the parse failure itself.
- fix applied: quoted all three values. Not yet fixed at the root — the
  validator could be more honest about "frontmatter failed to parse" vs
  "field X is missing", and task templates could show a quoted example
  for any free-text field.
- recurrence: 1
- status: lesson

## L-process-002 — an agent should never sign a human-only gate-approval line, but it keeps needing to be told, not assumed
- date: 2026-08-27 | source: E02-T02 review (Opus), E02-T03 (avoided proactively)
- situation: E02-T02's first pass wrote `design/gaps.md` GAP-004's `approved
  by:` line as `claude-code (orchestrator)` — an agent signing its own
  design-fidelity human gate. Caught in review and corrected to genuinely
  pending. E02-T03's GAP-005 was written correctly-pending from the start,
  but only because the dispatch prompt explicitly said so — the underlying
  convention isn't yet load-bearing without being restated each time.
- root cause: `design/gaps.md`'s own template says "🧍 human-approved before
  it is built", but nothing stops an agent from filling in the `approved
  by:` line with its own name — the template shows the slot, not who may
  fill it. Same shape of risk applies to any other `approved by:` /
  `cleared by:` line across the harness (ADR decisions, other human gates).
- fix applied: corrected the one instance found; no systemic fix yet — the
  next agent to touch a gap/gate file still has to be told, not blocked.
- recurrence: 1 (2 near-misses if counting the proactive avoidance, but the
  underlying gap — nothing *prevents* the mistake — hasn't recurred as a
  build yet, so keeping this at 1 rather than inflating the count)
- status: lesson

## L-process-003 — the orchestrator itself committed a fix directly to `development`, violating rule 4
- date: 2026-08-27 | source: this session, self-caught
- situation: While fixing the YAML-quoting bug (L-process-001) across
  three task files, the fix was committed straight to `development`
  instead of on its own branch — rule 4 ("never commit directly to
  `development`") applies to every contributor, including the orchestrator
  doing quick doc/config fixes, not just feature work.
- root cause: small, mechanical, "obviously safe" fixes read as exempt from
  the branch discipline that governs everything else, but the rule doesn't
  carve out an exception for size or confidence — every direct-to-
  `development` commit is the same violation regardless of how small.
- fix applied: acknowledged to the human rather than silently rewriting
  history (no force-push/rebase of shared branches); the fix was still
  correct, so it was left in place and later work continued on proper
  branches.
- recurrence: 1
- status: lesson

## L-process-004 — `git add -A` picks up leftover worktree directories as embedded git repos
- date: 2026-08-26 | source: this session, self-caught before commit
- situation: Several completed/interrupted agent worktrees under
  `.claude/worktrees/<id>/` couldn't be cleanly removed (Windows path-length
  limits on `git worktree remove`), so they remained on disk as untracked
  directories — each one its own `.git`-containing repo. A later `git add
  -A` staged all of them as embedded git repositories (Git's own warning
  caught it before commit).
- root cause: `.claude/worktrees/` isn't gitignored, and leftover worktree
  directories (which the harness's own worktree-cleanup step can't always
  remove on this OS) look like ordinary untracked files to a broad `git add
  -A`, which doesn't distinguish "untracked file" from "untracked nested
  git repository."
- fix applied: unstaged everything and re-staged only the explicitly
  intended file list for that commit at the time. Systemic fix applied in
  this retro: added `.claude/worktrees/` to `.gitignore` — a mechanical
  control (git itself now ignores the path) rather than a rule to remember.
- recurrence: 1
- status: promoted-to-hook(.gitignore)

## L-process-005 — a task's own `files:` fence can be individually correct and still leave a spec-level completeness gap the analyze report's cross-task-contradiction check doesn't catch
- date: 2026-08-27 | source: E04-B03 (end-of-epic bug sweep)
- situation: E04-T02 built a fully-tested routing engine consuming
  `recordLinkMeasurement(latencyMs, lossRate, batteryDrain)`. E04-T03a
  defined the Pigeon transport contract (ADR-0004's one boundary
  definition point) with discovery/connection/data events but no
  link-quality signal. Neither task was wrong against its own `files:`
  fence and contract — T02 correctly didn't invent a data source outside
  its scope, T03a correctly scoped to "define the boundary once." The
  epic's analyze report's "Contract sanity" check passed, because it
  checks whether tasks *contradict* each other, not whether the union of
  what they build is *sufficient* for what the epic's own scope promises.
  Result: a routing engine with zero production data source, undiscovered
  until the end-of-epic sweep, on a real device `computeRoute()` would
  always return `null`.
- root cause: task-sharding's collision matrix and scope-fence checks
  verify non-contradiction between tasks, not sufficiency of the whole.
  "Every task is individually correct and non-overlapping" is a weaker
  property than "the tasks together deliver the epic's stated scope" —
  nothing in `skills/task-sharding`'s Analyze gate currently checks the
  second thing.
- fix applied: none yet — this occurrence was caught by the bug sweep
  (a later, more expensive stage than task-sharding's own Analyze gate)
  rather than at sharding time. Fixed for this instance via E04-B03
  (extended the Pigeon contract, human-approved ADR-0004 boundary change).
  No systemic fix applied — one occurrence isn't promotion territory yet.
  A future occurrence should prompt adding a "does every FR/EARS id the
  epic claims as in-scope have an actual producer, not just a consumer,
  among the sharded tasks" check to `skills/task-sharding`'s Analyze gate.
  **2026-08-29 (E05 retro) — the lesson worked as a lesson.** E05's own
  analyze report explicitly ran the sufficiency check this lesson asks for
  (`epic.md` §Analyze report, "Contract sanity") and found two genuine gaps
  (no prekey-bundle exchange, no gap-fill protocol), recorded as
  OQ-E05-T02-1/OQ-E05-T04-1 instead of leaving them undiscoverable. Not
  incremented: no *new occurrence of the miss* happened. E05's two seam bugs
  (B01, B02) are adjacent but distinct shapes — see L-process-006 and
  L-process-007.
- recurrence: 1
- status: lesson

## L-process-006 — a task file can describe *another* task's obligation in prose, and nothing checks that the other task's own contract agrees, so the obligation ends up owned by nobody
- date: 2026-08-29 | source: E05-B01 (end-of-epic bug sweep)
- situation: `E05-T03.md` §3 defined the wire envelope and stated plainly
  who writes it — "gets serialized INTO what E03 encrypts on the sending
  side (T02)" — and `receive_message_use_case.dart:40-42` repeated the claim
  in source as settled fact. **E05-T02's file never mentions an envelope**:
  its §3 says only "calls `CryptoService.encrypt(...)`", and its §5
  signature takes an opaque `plaintext`. T02 shipped first (`ea7c9fb`),
  T03 second (`984f83e`), each reviewed and APPROVEd correctly within its
  own fences. Result: the wire format had a consumer and no producer —
  reviewer's probe fed T02's real output to T03's deserializer and got
  `FormatException`, and the worse mode was a silent mis-parse into a
  garbage row that could evict a legitimate message via dedup. Every
  EARS-MSG-2/3 test in the epic proved dedup and ordering only against
  test-fabricated envelopes.
- root cause: the harness has no rule that an obligation is only real when
  the **owning** task's own contract states it. A task file is authoritative
  for its own scope, but nothing stops it from *narrating* a sibling's
  behaviour, and prose about another task is invisible to (a) that task's
  `files:` fence, (b) that task's reviewer, who checks the task in front of
  them, and (c) the analyze gate, whose "Contract sanity" check looks for
  tasks that *contradict* each other. Two tasks silently agreeing that
  someone else does the work contradicts nothing. Distinct from
  L-process-005: there the union of tasks was insufficient for the epic's
  scope; here the union *describes* the work correctly and no task's binding
  contract carries it.
- fix applied: E05-B01 (P2) — envelope moved to a shared file with two real
  importers, send side serializes before encrypting (sequence number
  reserved in-transaction first, so no read-then-write race reintroduced),
  `deserialize` hardened with a format-version byte, and the false source
  comment corrected. Systemic fix applied in this retro: a new Analyze-gate
  check in `skills/task-sharding` — any task file naming another task id or
  a sibling's behaviour in prose must have that obligation independently
  stated in the named task's own contract, or the prose is deleted and the
  obligation becomes an Open Question with an owner.
- recurrence: 1
- status: promoted-to-rule — `agent/skills/task-sharding/SKILL.md` (Analyze
  gate, "Obligation ownership" row), 2026-08-29 via `skills/retro`,
  🧍 `retro_promotions` ⏳ awaiting human. Promoted at recurrence 1 rather
  than 2 because the check is mechanical and cheap at sharding time (grep
  each task file for other task ids, then read the named task's contract),
  and because it is the third member in two epics of one family — the
  Analyze gate verifying non-contradiction while nobody verifies ownership
  or sufficiency (E04-B03, E05-B01, E05-B02).

## L-process-007 — an obligation handed from one epic to the next at a merge gate has no reader: the next epic's sharding never looks at the previous epic's retro or bug-sweep advisories
- date: 2026-08-29 | source: E05-B02 (found by sweep) + the E04-B03
  link-quality carry-forward (found by this retro, still open)
- situation: two obligations were written down at E04's close, in the exact
  places the harness tells you to write them, and **both were dropped by
  E05's planning**:
  1. `E04-B02.md`'s approved review advisory said the relay retention
     guarantee "only becomes real once **E05 wires both onto a scheduler**",
     and E04's `retro.md` repeated it. No E05 task file mentions a
     scheduler; `grep -rn "processQueue\|sweepExpired\|reclaimPayloads" lib/`
     had zero call sites at the end of the epic, so EARS-MSG-1's "and send
     once a route is available" half had no mechanism at all (E05-B02, S2).
     Rediscovered only because the sweep reviewer chose, off her own bat, to
     re-read E04's bug files.
  2. E04's `retro.md` §Open follow-ups: "E05 must wire real RSSI/latency/
     loss measurements into the now-extended Pigeon contract". Nothing in
     `epics/E05-messaging-reliability/` mentions rssi, `onLinkQuality` or
     `recordLinkMeasurement`; `transport_service.dart:182` and
     `transport_api.g.dart:362` still carry comments saying this "is E05's
     job". This one the sweep did **not** catch either — it was found by
     this retro, and E05 closes with it still unwired.
- root cause: the analyze gate's inputs are the epic's own `epic.md`, its
  task files and `spec/`. Nothing in `skills/task-sharding` reads the
  *previous* epic's `retro.md`, its bug files' advisories, or its merge-gate
  notes, so an inter-epic obligation is written into artifacts that have no
  downstream reader. The advisory in a closed bug file is the weakest
  possible carrier: it is correct, dated, attributed — and orphaned. Rule 8
  ("memory before work") is enforced for *lessons* by a hook; nothing
  equivalent exists for *carry-forwards*.
- fix applied: E05-B02 closed as **deferred to E06 with the owning epic
  named** (🧍 human decision, 2026-08-29) precisely so it is not lost a
  third time. The link-quality carry-forward is re-recorded in this retro's
  §Open follow-ups and must be carried into E06's sharding as a named
  dependency. Systemic fix applied in this retro: a new Analyze-gate check
  in `skills/task-sharding` — before an epic's tasks dispatch, read every
  `depends_on:` epic's `retro.md` §Open follow-ups and its bug files'
  advisories for obligations addressed to this epic, and show each one as
  covered-by-task-id, or carried as an explicit Open Question with an owner.
- recurrence: 2 (two independent dropped handoffs out of two written at
  E04's close — a 100% loss rate for this carrier)
- status: promoted-to-rule — `agent/skills/task-sharding/SKILL.md` (Analyze
  gate, "Inherited obligations" row + step 0 of the procedure), 2026-08-29
  via `skills/retro`, 🧍 `retro_promotions` ⏳ awaiting human. A hook is
  plausible here and is **recommended, not built**: `make validate` could
  fail an epic whose `depends_on:` epics' retros contain "must" language
  naming it, unless that epic's files cite the source. The parsing is
  heuristic (English in a retro), so it belongs to a human's judgement about
  false-positive tolerance before it becomes a blocking check.
