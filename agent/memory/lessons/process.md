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
- recurrence: 2
- status: promoted-to-hook — `agent/orchestrator/scheduler.py` (`frontmatter()`
  now records every parse failure, and `validate()` raises it as its own
  hard `--validate` error naming it a YAML parse failure, not a missing
  field), 2026-09-02 via `skills/retro` (E07), 🧍 `retro_promotions` ✅
  approved by the human, 2026-09-02. Closes the exact gap the second occurrence (E06-T01)
  predicted: `--validate`/`--status` can no longer silently miscount a
  task because its frontmatter didn't parse.
- **2026-08-30 (E06 post-merge status check) — recurred, and the consequence
  got worse.** `E06-T01.md`'s `executed_by:` field (not `review_outcome:`
  this time — the same shape, a different free-text field) had an unquoted
  colon inside a long run-log-style description. `scheduler.py --validate`
  and `--status` printed the "bad frontmatter" warning on **every single
  run this whole epic** — it was visible the entire time and never acted
  on, because the warning reads as background noise next to the
  pass/fail summary beneath it. The concrete cost this time: `--status`
  silently miscounted E06-T01 as `todo` (the YAML-parse-failure default)
  in the epic progress table, even though the task was long done and
  merged — an epic that was actually 16/17 done + 1 blocked displayed as
  having an untouched task. Found only because a human asked "is the
  status data right?" and the answer required actually reading the
  warning that had been printing the whole time. Fixed the same way as
  before (quote the value). Not yet promoted to a rule/hook — the
  detection already exists (the validator prints it every time); the gap
  is that a soft `⚠` warning sitting above a clean-looking pass/fail
  summary doesn't get read. Two occurrences, two different fields, same
  shape: the next occurrence should trigger promoting this from "always
  quote free-text values" (a habit) to a hook that fails `--validate`
  outright on any unparseable task frontmatter, not just warns.

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
- recurrence: 2 (2026-09-18: recurred in this session. A `git add -A` in a five-file frontmatter fix swept in ~20 unrelated paths — `.claude/skills/review/SKILL.md`, `.firebaserc`, and a pile of `.verify_shots/*.png|txt` binaries — all of which the same session had repeatedly verified as pre-existing and deliberately untouched. Caught only because the commit's CRLF warnings named files the author knew were not his. Undone with `git reset --soft HEAD~1` before push.)
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
  🧍 `retro_promotions` ✅ approved by the human, 2026-09-03 (E08 retro —
  retroactive cleanup, live and operating successfully since 2026-08-29).
  Promoted at recurrence 1 rather than 2 because the check is mechanical
  and cheap at sharding time (grep each task file for other task ids, then
  read the named task's contract), and because it is the third member in
  two epics of one family — the Analyze gate verifying non-contradiction
  while nobody verifies ownership or sufficiency (E04-B03, E05-B01, E05-B02).

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
  via `skills/retro`, 🧍 `retro_promotions` ✅ approved by the human,
  2026-09-03 (E08 retro — retroactive cleanup, live and operating
  successfully since 2026-08-29). A hook is plausible here and is
  **recommended, not built**: `make validate` could
  fail an epic whose `depends_on:` epics' retros contain "must" language
  naming it, unless that epic's files cite the source. The parsing is
  heuristic (English in a retro), so it belongs to a human's judgement about
  false-positive tolerance before it becomes a blocking check.

## L-process-008 — a carried-forward observation raised by a task's own reviewer, recorded correctly in the epic tracker, still has no reader until the end-of-epic sweep — same family as L-process-006/007, but *within* one epic, not across two
- date: 2026-08-30 | source: E06 bug sweep (`E06-B02`, `E06-B04`), independently in the same sweep (`E06-B03`)
- situation: two observations were written into `epics/E06-personal-chat/tracker.md`'s
  §Carried-forward observations, in exactly the place the harness tells a
  reviewer to put an out-of-fence finding:
  1. E06-T03's reviewer flagged `devices_controller.dart:31`'s fallback
     `TransportService()` on 2026-08-29, with an explicit recommendation
     ("T04 should either wire the shared instance or confirm the fallback
     is dead code"). **Eight tasks** (T04-T12) touched the messaging stack
     or `bindings.dart` between that flag and the sweep that finally closed
     it as `E06-B02` — an **S1**, the epic's highest-severity bug: the
     fallback silently hijacked every native transport event the moment a
     user opened a normal nav destination, with zero error surfaced.
  2. Independently, T12's reviewer named the same *shape* of risk mid-epic
     ("the delivery-tick glyph mapping is now duplicated in three places
     ... flagged as a latent drift risk") without checking whether it had
     already drifted — checking all three screens side by side was out of
     T12's own fence. The sweep found it had (`E06-B03`, S3).
  Both observations were correct, dated, attributed, and sitting in the
  right file. Neither was read again until the sweep — the single most
  expensive and latest point this project checks anything.
- root cause: `skills/task-sharding`'s "Inherited obligations" check (the
  L-process-007 promotion) reads a **previous epic's** `retro.md` and bug
  advisories, once, at sharding time, before any task in the current epic
  dispatches. Nothing re-reads the **current** epic's own accumulating
  §Carried-forward observations between dispatches — the exact artifact a
  mid-epic reviewer is told to write to has a reader only at the sweep, by
  design. An 8-task gap between "flagged" and "read" is not a coincidence
  of this epic; it is what an unread carrier does every time nothing forces
  it to be read sooner.
- fix applied: both closed as their own bug tasks (`E06-B02` P1, `E06-B03`
  P2) after the sweep found them. Systemic fix proposed in this retro: when
  dispatching each task within an epic (not just at the epic's own
  sharding), the dispatcher checks the epic tracker's own §Carried-forward
  observations for anything unresolved and, if the next task's `files:`
  fence touches the same file/area, either folds in the fix or explicitly
  notes why it's staying out of scope — so an observation's silence stops
  being the default and starts requiring a reason.
- recurrence: 2 (two independent carry-forwards raised mid-epic, both
  unread until the sweep, in the same epic's own evidence)
- status: promoted-to-rule — `agent/skills/bug-sweep/SKILL.md` (a new "read
  the epic's own carried-forward observations before dispatching the next
  task" step) and a cross-reference from `agent/skills/task-sharding/SKILL.md`'s
  existing Inherited-obligations row (which currently only reads *other*
  epics), 2026-08-30 via `skills/retro`, 🧍 `retro_promotions` ✅ approved
  by the human, 2026-08-30.

## L-process-009 — a bug task file has no required §4 scope-fence, unlike a feature task file, and an agent fixing a bug fills that gap with its own judgement
- date: 2026-08-30 | source: `make health` H4, this retro — `E06-B02`,
  `E06-B03`, `E06-B04` (and the pre-existing `E05-B02`) all fail the check
- situation: `make health`'s H4 ("tasks have a real scope fence") failed on
  every bug task file written or open in this project's history so far —
  not a missing-but-empty §4, an **absent** one. Feature task files in this
  project reliably carry a "What this task does NOT do" section (every
  `E06-T*.md` has one); the bug task template this session used to write
  `E06-B02`/`B03`/`B04` (following `E06-B01`'s own shape, which itself set
  the pattern) never asks for one.
- root cause: the bug-task template (`skills/bug-sweep`'s own file-writing
  guidance) inherited the feature-task file's other sections (Repro,
  Severity, Proposed fix direction, Implementation checklist) but not its
  scope fence. A fix built from a bug report with no stated "do NOT do X"
  list is exactly the shape `make health`'s own fix message warns about:
  "an agent with an empty fence fills the space with its own judgement,
  and its judgement is not the plan" — for a bug this is doubly risky,
  since a bug fix is inherently a smaller, more surgical diff where scope
  creep is both easier to justify in the moment ("while I'm in here...")
  and easier to miss in review (the diff already looks small).
- fix applied: none yet on the already-merged `E06-B02`/`B03` (both
  reviewed and closed without a scope fence, and neither review found
  scope creep — the control held by luck, not by design, in both cases).
  Systemic fix proposed in this retro: add a required §4-equivalent
  ("What this fix does NOT do") to the bug-task file shape
  `skills/bug-sweep`'s "Writing a bug task that gets fixed once" section
  describes, alongside Repro/Expected/Actual/Severity.
- recurrence: 4 (`E05-B02`, `E06-B02`, `E06-B03`, `E06-B04` — every bug
  task file in the project so far)
- status: promoted-to-rule — `agent/skills/bug-sweep/SKILL.md` ("Writing a
  bug task that gets fixed once" section, new required scope-fence bullet),
  2026-08-30 via `skills/retro`, 🧍 `retro_promotions` ✅ approved by the
  human, 2026-08-30.

## L-process-010 — a rate-limit-deviation review's `reviewed_by` free text documents the deviation honestly but isn't machine-parseable against `harness.yaml`'s model list, so rule 5 becomes unverifiable by anything except reading the prose
- date: 2026-08-30 | source: `make health` H5 — `E06-B01`, `E06-T07`
- situation: during a weekly account-wide rate-limit freeze, the
  orchestrator reviewed `E06-B01` and `E06-T07` directly rather than
  waiting, and disclosed this thoroughly in each task file's own DoD/Run
  log prose (falsification re-run, full-suite re-run, explicit "this is a
  rate-limit deviation" note). `make health`'s H5 check still flags both:
  the `reviewed_by` field's free text ("orchestrator (independent
  re-verification, direct — not a dispatched reviewer subagent, due to a
  weekly rate-limit freeze...)") names no model string from
  `harness.yaml`'s `review_routing.models` list, so the health check
  cannot confirm rule 5 (`reviewed_by` ≠ `executed_by`, different model)
  held — even though, in both cases, it genuinely did (a different model
  tier did the reviewing, and the prose says so).
- root cause: the deviation was disclosed for a human reader, not for the
  mechanical check. `harness.yaml`'s model list is the only thing H5 can
  compare against, and prose explaining *why* a deviation happened doesn't
  satisfy a check looking for *which model* reviewed. The two goals
  (honest human-readable disclosure, machine-verifiable rule-5 compliance)
  were treated as one problem when they need two answers in the same field.
- fix applied: none yet on the already-merged `E06-B01`/`E06-T07` (cosmetic
  doc fix, not worth reopening a closed, correctly-reviewed task). Going
  forward: when a rate-limit (or other) deviation puts the orchestrator in
  the reviewer seat, `reviewed_by` should still lead with the actual model
  identifier from `harness.yaml`'s list (e.g. `claude-sonnet-5 (direct,
  rate-limit deviation — see Run log for full disclosure)`), so H5 can
  parse compliance mechanically and the full explanation still lives in the
  Run log where a human reads it.
- recurrence: 2
- status: promoted-to-rule — `agent/skills/review/SKILL.md` (new stated
  rule: `reviewed_by` must lead with a declared model string, always, even
  under a disclosed deviation — full explanation goes in the Run log
  instead), 2026-09-02 via `skills/retro` (E07), 🧍 `retro_promotions` ✅
  approved by the human, 2026-09-02.

## L-process-011 — a bug-sweep-authored bug task's `files:` fence ships fully empty (all three lists), not just missing a §4 narrative section — a distinct template gap from L-process-009, and it hit 4-for-4 in one sweep
- date: 2026-09-02 | source: E07 end-of-epic bug sweep — `E07-B01`, `B02`,
  `B03`, `B04` all shipped with `files: {create: [], update: [], delete: []}`
- situation: `make health` H4 only checks for the §4 prose fence
  (L-process-009's fix), not the YAML `files:` list — so it stayed silent
  while every one of this sweep's 4 bug files went to `status: blocked`
  with an empty `files:` fence. `E07-B04`'s reviewer flagged it explicitly:
  scope wasn't mechanically verifiable from the task file at all, and had
  to be judged against `required_context` + the §4 prose instead. Two of
  the four (`B01`, `B04`) were later backfilled once a fix landed — but
  that happens *after* the fact, by whoever fixes or reviews, not at
  authoring time when it would actually constrain the fixer.
- root cause: `skills/bug-sweep`'s file-writing guidance tells the sweep
  agent what prose sections a bug file needs (Repro/Expected/Actual/
  Severity, and now the §4 fence from L-process-009) but never says
  whether `files:` should be filled at authoring time. A reviewer reading
  a bug report mid-investigation usually already knows which files are
  implicated (it's in the "found_in"/"required_context" reasoning) — the
  gap is that nothing asks for it to be written down where the scheduler
  and a mechanical check can see it.
- fix applied: backfilled `E07-B04`'s fence post-fix for the historical
  record (orchestrator). Systemic fix proposed in this retro: `skills/
  bug-sweep`'s bug-file-writing section should require `files:` to be
  filled with the sweep's own best-effort file list (the same files named
  in "found_in"/"Repro"), even before a priority or fix direction is set —
  a rough guess narrows the fixer's judgement the same way a feature
  task's fence does, and can always be widened later if the real fix needs
  more.
- recurrence: 4 (`E07-B01`, `B02`, `B03`, `B04` — every bug file this
  sweep produced)
- status: promoted-to-rule — `agent/skills/bug-sweep/SKILL.md` ("Writing a
  bug task that gets fixed once" section, alongside the L-process-009 §4
  requirement: require a best-effort `files:` fence at authoring time, not
  just at fix time), 2026-09-02 via `skills/retro`, 🧍 `retro_promotions`
  ✅ approved by the human, 2026-09-02.

## L-process-012 — `skills/bug-sweep` never names the valid `status:` value for a newly-found bug, so the sweep agent invented one (`open`) that isn't in `harness.yaml`'s status vocabulary
- date: 2026-09-02 | source: E07 end-of-epic bug sweep — all 4 new bug files
- situation: `scheduler.py --validate` caught this immediately and loudly
  (`unknown status 'open'`, 4 failures) before any dispatch happened — the
  mechanical control worked exactly as designed. But it worked *after* the
  sweep agent had already merged a commit with invalid frontmatter into
  `epic_07`, requiring a follow-up orchestrator commit to fix. `E06-B04`
  (the precedent this session copied the bug-file shape from) correctly
  used `status: blocked`, so the right value already existed as a
  same-project example — the sweep agent just wasn't told to look for it.
- root cause: `skills/bug-sweep`'s procedure describes severity, priority,
  repro and the scope fence in detail, but doesn't say what `status:` a
  freshly-authored bug task should carry, or point at `harness.yaml`'s
  `scheduler.statuses` list as the source of truth. An agent writing
  frontmatter from a mental model of "not started yet" reaches for a
  plausible English word (`open`, `new`, `pending`) rather than the
  project's actual enum.
- fix applied: orchestrator corrected all 4 files to `status: blocked`
  post-hoc (matching `E06-B04`'s convention — bugs awaiting the
  `bug_priorities` human gate are `blocked`, not `todo`). Systemic fix
  proposed in this retro: `skills/bug-sweep`'s file-writing guidance should
  state the exact status value (`blocked`, pending the priority gate) and
  cite `harness.yaml`'s `scheduler.statuses` list directly, the same way
  L-process-009's fix named the exact section title needed.
- recurrence: 2 (2026-09-18: recurred 3/3 on newly-filed bug files —
  `E01-B01`, `E04-B38`, `E04-B39` — all written with `status: open`, all
  caught by `--validate` exactly as in 2026-09-02. Notably the author had
  READ this very lesson file earlier in the same session and still reached
  for the plausible English word. **The promoted rule did not reach this
  case**: it lives in `skills/bug-sweep`, but these bugs were filed from a
  REVIEW GATE and from incidental discovery during live testing, not from a
  sweep — so nothing in the path the author was actually following named
  the enum. A rule scoped to one skill cannot cover every way a bug file
  gets authored; that is the real finding.)
- status: promoted-to-rule, and now a **HOOK CANDIDATE** (recurrence 2,
  mechanically checkable — the ladder says a hook beats a rule). Concrete
  next rung: have `scheduler.py --validate`'s existing `unknown status`
  error also PRINT the valid vocabulary from `harness.yaml`'s
  `scheduler.statuses`, so the fix is obvious at the point of failure
  instead of requiring the author to know where the enum lives. Cheap, and
  it reaches every authoring path rather than one skill.
- original status: promoted-to-rule — `agent/skills/bug-sweep/SKILL.md` (same
  section as L-process-011), 2026-09-02 via `skills/retro`, 🧍
  `retro_promotions` ✅ approved by the human, 2026-09-02.

## L-process-013 — an epic can be merged into `development` with its mandatory retro never run, because `make health`'s H3 check keys off `epic.md`'s `status:` field, and nothing forces that field to flip before the merge happens
- date: 2026-09-02 | source: this session, self-caught — E07 was merged
  into `development` (`431190b`) before `skills/retro` ran at all
- situation: the orchestrator ran E07's bug sweep, cleared the human
  `bug_priorities` and `verified` gates, and merged `epic_07` into
  `development` — all without writing `retro.md`, without updating
  `epics/E07-groups-calls/epic.md`'s `status:` from its sharding-time
  value (`todo`) to `done`, and without running the lesson/rule promotion
  ladder. `make health`'s H3 ("completed epics have retros") reported
  **pass** the entire time, because it only flags an epic whose `epic.md`
  `status:` is in the `DONE` set (`done`/`verified`) and has no
  `retro.md` — E07's `epic.md` still said `todo`, so H3 had nothing to
  check against, even though the epic was, in every real sense (14/14
  tasks + bug sweep + both human gates), completely done. `E06` avoided
  this by coincidence of order, not by a rule: its retro commits happened
  to land on the epic branch before the merge, so `epic.md`'s `status:`
  was already `done` by the time anyone could check.
- root cause: `skills/retro`'s own "Where to look next" names its
  prerequisites as bug-sweep completion and the epic's merge into
  `development` — but the actual E06 precedent (and the skill's spirit)
  is retro-before-merge, with the merge folding the retro commits in
  along with everything else. Nothing enforces that order: the `verified`
  human gate and the merge step don't check for `retro.md`'s existence,
  and `epic.md`'s `status:` field — the one signal `make health` H3
  actually reads — has no step in the workflow that requires updating it
  before or during the merge.
- fix applied: this retro itself, run retroactively after the merge
  (evidence was all still available: tracker history, review log,
  `metrics.csv`, `make health`). `epic.md`'s `status:` corrected to `done`
  as part of this retro. Systemic fix proposed: the `verified` gate's own
  checklist (wherever it's defined — `epics/<id>/tracker.md` §Gates, or a
  future scheduler check) should require `retro.md` to exist before the
  gate can be marked cleared, and `make health`'s H3 should additionally
  flag any epic branch that `git merge-base --is-ancestor`-checks as
  already merged into `development` with no `retro.md`, regardless of
  what `epic.md`'s `status:` field says — so the check can't be defeated
  by a stale frontmatter field the way it just was.
- recurrence: 1
- status: promoted-to-hook — `agent/orchestrator/health.py`'s H3 check now
  does the merge-base-ancestry check proposed above, independent of
  `epic.md`'s `status:` field.

- **2026-09-03 (E08 retro) — the hook fired correctly on the exact
  recurrence it was built for, and this time nothing shipped broken.** E08
  merged into `development` (PR #30) before its retro ran — `make health`
  caught it immediately: *"E08's branch is already merged into development
  with no retro.md, regardless of `epic.md`'s status: 'todo' field."*
  Difference from E07's occurrence: the human asked for the retro in the
  same session, immediately after the merge, rather than it being missed
  for an entire session boundary — so the gap this hook exists to catch was
  open for minutes, not indefinitely. `epic.md`'s `status:` corrected to
  `done` as part of this retro, same as E07's. Not incremented as a new
  miss (the hook did its job); recorded as evidence the promoted hook
  works, and that `skills/release`'s own precondition wording ("its retro
  done") is satisfied by retro-before-next-release rather than strictly
  retro-before-epic-merge — the harness tolerates the latter ordering as
  long as H3 keeps catching the gap before anything ships past it.

## L-process-014 — `make health`'s H4 check itself only recognized the feature-task scope-fence heading, so every correctly-written bug-task fence read as absent since L-process-009 introduced the convention
- date: 2026-09-02 | source: E07 retro, investigating an H4 false positive
  on `E07-B02`/`E07-B03` (and, on closer look, `E06-B04` too)
- situation: `agent/orchestrator/health.py`'s H4 regex was
  `^##\s*4\.\s*What this task does NOT do` — matching only the feature
  task's numbered heading. `skills/bug-sweep`'s own L-process-009 fix
  established a *different* heading for bug files, `## What this fix does
  NOT do` (no "4.", "fix" not "task") — and every bug file in this
  project, including the ones L-process-009 itself cited as exemplars,
  used that heading. The check has been reporting a false "absent fence"
  on every compliant bug file since the rule it's supposed to verify was
  written, and nobody had re-run `make health` against a bug file with a
  real fence closely enough to notice until this retro.
- root cause: L-process-009's fix was written into `skills/bug-sweep` (the
  content guidance) without a matching update to `health.py`'s H4 check
  (the verification), even though both exist to enforce the same rule.
  The two live in different files with no cross-reference, so a content
  convention and its own verifier drifted apart the moment the convention
  was invented — the mechanical check was never actually exercised
  against real compliant output before now.
- fix applied: `health.py`'s H4 regex widened to
  `^##\s*(?:4\.\s*)?What this (?:task|fix) does NOT do` and re-run —
  confirmed 4/4 previously-flagged bug files now correctly pass. No task
  file needed to change; only the check was wrong.
- recurrence: 2
- **2026-09-24, third instance of the same root cause — and the second time
  in THIS regex.** The widened form above still hard-coded the numeral `4`
  (`(?:4\.\s*)?`), so a bug file numbering its fence `## 3. What this task
  does NOT do` read as "no scope-fence section at all". Five files use that
  numbering — `E00-B01`, `E01-B01`, `E04-B13`, `E04-B15`, `E06-B01` (§1 Goal,
  §2 Findings, §3 fence, §4 Risks) — and `E01-B01` was the one open task
  among them, so H4 failed the whole run on a fence that was present and
  properly filled. Fixed by accepting any leading section number,
  `(?:\d+\.\s*)?`; H4 now passes. The position of the section was never
  what made it a fence.
  The root cause is identical all three times: **the regex enumerates the
  exact heading forms someone has already seen, instead of matching the
  shape.** Each fix added one more observed form rather than removing the
  assumption, which is why it keeps recurring. Recurrence bumped 1 -> 2 for
  this reason (the H6 instance below was already recorded as the same
  pattern, one file down).
- status: fixed directly (mechanical, no ladder needed — a check
  verifying its own stated rule against its own stated example output is
  not a judgement call). Worth remembering for future rule/hook pairs
  written in the same retro: verify the hook actually matches the
  convention it's checking before closing the loop, not just that it runs
  without crashing.
- **Same session, second instance:** H6's own `status:`/`recurrence:`
  regexes used unanchored `re.search`, so a lesson whose prose legitimately
  says `status: blocked` mid-sentence (this retro's own `L-process-011`,
  describing the bug-file convention it's about) matched *before* the
  real `- status: promoted-to-rule` field further down the same block —
  H6 reported a fresh, correctly-promoted lesson as still unpromoted.
  Fixed by anchoring both regexes to `^-\s*(field):` (start-of-line,
  the actual frontmatter-style bullet), re-run, confirmed correct. Same
  root pattern as the H4 fix above — recorded here rather than as a
  separate numbered lesson, since it's the identical "check was written
  once, never re-run against a real qualifying example" gap, one file
  down.

## L-process-015 — rule 9's logging (`runs/<task_id>/` + per-epic `metrics.csv`) has a 0% compliance rate project-wide, because dispatch via the Agent tool never goes through `agent/adapters/run-claude.sh`, the only thing that writes either artifact
- date: 2026-09-02 | source: E07 retro, checking `skills/retro` §5
  (calibrate estimates) — found no `metrics.csv` exists for ANY epic,
  and `runs/` is empty project-wide, not just for E07
- situation: `AGENTS.md` rule 9 and `CLAUDE.md` both name
  `agent/adapters/run-claude.sh <task-id> "<prompt>"` as how a headless
  task run gets captured into `runs/<task_id>/` and its epic's
  `metrics.csv`. Every task and bug this session (and, from the empty
  state of both paths, every prior epic's too) was dispatched with the
  Agent tool directly — an in-process subagent, not a shelled-out
  `run-claude.sh` invocation — so nothing ever wrote to either location.
  `skills/retro` §5 ("actual >1.5x the estimate for a tier, twice ->
  adjust `skills/task-sharding`'s tier guidance") has never had a single
  data point to work from, for any epic, ever.
- root cause: the harness's cost/logging design assumes one specific
  dispatch mechanism (a shell script wrapping the Claude CLI headlessly),
  but the orchestrator role in *this* environment (an interactive Claude
  Code session with the Agent tool available) has a second, equally valid
  way to dispatch work that the logging pipeline was never wired to. Rule
  9 states the requirement but not which dispatch path it applies to, so
  an orchestrator using the Agent tool exclusively — which every session
  transcript in this project shows happening — satisfies the letter of
  "dispatch the work" while silently never satisfying the logging rule at
  all, with no error, warning, or health check surfacing the gap (`make
  health`'s 7 checks don't include one for this).
- fix applied: none yet — retroactively reconstructing `runs/`/
  `metrics.csv` for 7 completed epics is not this retro's job, and would
  produce fabricated timing/cost data for work already done. Systemic fix
  proposed: either (a) the Agent-tool dispatch path gets its own
  lightweight logging shim (append a `metrics.csv` row + a `runs/<task_id>/`
  summary when an orchestrator squash-merges a task, using data already
  available at that point — PR number, commit hash, review outcome — even
  without the exact cost/token numbers `run-claude.sh` captures), or (b)
  rule 9 and `CLAUDE.md` are corrected to say plainly that logging is
  `run-claude.sh`-specific and doesn't apply to Agent-tool dispatch, so the
  gap stops reading as a violation and `skills/retro` §5 stops expecting
  data that structurally cannot exist. A new `make health` check
  (H8?) flagging "an epic with `done` tasks but no `metrics.csv`" would
  make this visible going forward regardless of which fix direction is
  chosen.
- recurrence: 2 (checked again at E08's retro — still no `metrics.csv` for
  any of 8 completed epics, `runs/` still empty project-wide; the gap has
  now persisted across two consecutive retros where it was explicitly
  looked for and found unchanged)
- status: promoted-to-rule — human chose (b) at E08's retro, 2026-09-03:
  `AGENTS.md` rule 9 and `CLAUDE.md` both amended to state plainly that
  `runs/`/`metrics.csv` logging is `run-claude.sh`-specific and does not
  apply to Agent-tool dispatch; `skills/retro` §5 amended to say the same
  so future retros don't re-flag the absence as a gap. 🧍 `retro_promotions`
  ✅ approved by the human, 2026-09-03.

## L-process-016 — the orchestrator implemented a bug fix directly (not via a dispatched builder) and then ran the merge command itself, with no independent review ever dispatched — rule 5 was violated by the same actor at both ends, and nothing stopped it
- date: 2026-09-12 | source: E04-B11, live hands-on hardware debugging session
- situation: mid-investigation, on real hardware, the orchestrator diagnosed
  and fixed a real defect (`BluetoothTransport.send()` blocking the
  platform thread) directly rather than dispatching a builder — a
  reasonable call given the live-device context made a fresh subagent
  costly to hand off to. It committed, pushed, opened the PR — all fine.
  Then, in the same tool-call flow as checking whether the branch could be
  cleaned up, it ran `gh pr merge` without ever dispatching a reviewer
  first. The merge succeeded and landed in `development` before anyone
  noticed. A post-hoc independent review was dispatched afterward to
  correct the gap (verdict: the fix itself was sound, changes-requested
  only on two stale comments — no revert needed) — but the gate was
  bypassed, not honored late.
- root cause: rule 5 ("reviewed_by must differ from executed_by") is
  self-enforced by convention (the orchestrator remembering to dispatch a
  reviewer before merging), not mechanically gated anywhere. When the
  SAME actor writes the fix, opens the PR, and later runs merge commands
  in the same extended tool-call sequence (e.g. while doing routine
  worktree/branch cleanup right after opening a PR — the exact moment this
  happened), there is no check between "PR exists" and "PR merges" that
  confirms a different `reviewed_by` was ever recorded on the task file.
  Every other merge in this project's history went through review first
  because the orchestrator happened to remember to dispatch one — this is
  the first time it didn't, and nothing but habit was ever preventing it.
- fix applied: none yet (mechanical). The post-hoc review this incident
  produced is a one-time correction, not a systemic fix. Proposed
  direction: a `make health` check (or a `scheduler.py --validate`
  addition) that flags any task file whose PR was merged into
  `development` while `reviewed_by` is empty, unset, or equal to
  `executed_by` — cheap to check (both are already recorded in task-file
  frontmatter) and would have caught this within one validate run instead
  of requiring after-the-fact discovery.
- recurrence: 3 (per the E10 and E11 retros' own bump; re-checked 2026-09-16)
- status: promoted-to-rule — `agent/skills/review/SKILL.md` ("Never merge
  without a recorded review"), 2026-09-16 via `skills/retro`,
  🧍 `retro_promotions` decided under the human's explicit delegation ("on
  you", 2026-09-16). The mechanical next rung (a `make health` /
  `scheduler.py --validate` check flagging a `done` task whose `reviewed_by`
  is empty or equals `executed_by`) is NOT built yet; it touches harness
  code and historical task files, so it is left as a follow-up.
- **2026-09-24 — the unbuilt rung above is now CONFIRMED absent by direct
  inspection, not merely proposed.** Recurrence is deliberately NOT bumped:
  this was an authorised exception, not a violation, and `skills/retro` says
  the recurrence count is what decides automation priority, so inflating it
  with a non-failure would corrupt the signal. What happened: on `E00-B01`
  the human directed (2026-09-24) that Claude Opus serve as the rule-5
  reviewer and that Gemini not be used where Opus is available. The reviewer
  was therefore a genuinely separate context — a dispatched subagent with no
  access to the implementing session — but the same model as `executed_by`.
  H5 emitted no finding for `E00-B01` at all — and the reason is subtler, and
  more useful, than "the check does not exist".

  **H5 already implements most of what this lesson proposed.** The loop at
  `agent/orchestrator/health.py:287` runs three tests over every `done` task:
  an empty `reviewed_by` is a hard **fail** (`:291-293`);
  `reviewed_by == executed_by` is a hard **fail** (`:294-296`); and a
  `reviewed_by` naming no model from `harness.yaml` `review_routing.models`
  is a **warn** (`:297-300`). So the "empty" half of the proposed rung is
  fully built, and the "equals" half is built too.

  **What actually fails is the comparison's shape.** `:294` is
  *whole-string*, case-insensitive equality:
  `rv.strip().lower() == ex.strip().lower()`. `E00-B01` carries
  `executed_by: opus (interactive session)` and
  `reviewed_by: "opus (dispatched reviewer subagent, separate context ...)"`.
  Same model, different strings — so the equality test passes vacuously and
  H5 stays silent. Note that `executed_by`'s own trailing parenthetical is
  enough to defeat `:294` on its own: even a bare `reviewed_by: opus` would
  not be whole-string-equal to `opus (interactive session)`. Both fields
  carry prose, and either one alone breaks the match.

  **The convention that makes this routine is the project's own.**
  `L-process-010`'s rule in `.claude/skills/review/SKILL.md` requires that
  `reviewed_by` **lead with** a model string from `review_routing.models`,
  and explicitly pushes full disclosure out to the Run log rather than into
  this field. It does not mandate a parenthetical — but its own worked
  example carries one (`claude-sonnet-5 (direct, rate-limit deviation — see
  Run log …)`), so a trailing qualifier is normalised in practice, and
  `executed_by` has no such rule at all. The result is that most real task
  files have prose in at least one of the two fields, and `:294` therefore
  almost never fires even when the models genuinely match.

  The fix, if this is ever built out, is **not** a new check — it is making
  `:294` compare the leading model token (the text before the first `(` or
  `,`) **of both fields**, not the whole strings. That would yield `opus` vs
  `opus` here and fire the hard fail as intended. It would still not
  normalise a bare `opus` against a fully qualified `claude-opus-5`; that is
  a further step, not solved by tokenising alone.

  Recorded 2026-09-24 after two wrong drafts: the first asserted that H5
  never compares the two fields at all, and the second cited every line
  number nine lines too high (`:303` for what is `:294`). The "+3" figure in
  that second fix's own commit message is itself wrong, and is left standing
  as the third small instance of the same disease. Both were caught by the reviewer reading
  `health.py` rather than the note. A lesson that misstates the code it
  cites is worse than no lesson, which is why the errors are left visible
  here rather than quietly overwritten — the failure mode this whole entry
  is about is a check drifting from the thing it claims to check, and a
  lesson drifting from the code it claims to describe is the same disease.

## L-process-017 — a new service, method or stream is built, tested and approved, but nothing in production ever calls it, so the feature silently does not exist
- date: 2026-09-16 | source: consolidation at the 2026-09-16 gate
  clean-up. The E12, E13 and E14 retros (drafted 2026-09-15) each proposed
  promoting this pattern under the id `L-process-007`, but L-process-007
  is a different lesson (dropped inter-epic handoffs) and was already
  promoted. This entry gives the pattern its own id.
- situation: the same shape recurred across the project: `E04-B05`
  (`TransportService.connect()` had zero production callers, so relay
  sends could never succeed), `E04-B03` (no production link-quality data
  source), `E05-B02` (`processQueue`/`sweepExpired`/`reclaimPayloads` had
  zero call sites; see L-process-007's own evidence), plus the
  unwired-capability findings named in the E12, E13 and E14 retros.
- root cause: unit tests call the new code directly, so a green suite says
  nothing about whether the app ever reaches it. Review checks the diff
  against the task contract, and the contract names the new code, not
  the call site that must use it.
- fix applied: a review rule (`agent/skills/review/SKILL.md`, "Every new
  capability has a production caller"): for each new public
  class/method/stream in the diff, the reviewer greps `lib/` outside
  tests for a real caller, or confirms the task file names the later task
  that owns wiring it as an Open Question. A dead-code analysis hook, as
  the E13 retro suggested, is the next rung and is not built.
- recurrence: 3 (at least 3, and the true count is higher — E04-B05,
  E04-B03, E05-B02; further instances per the E12–E14 retros. Written `3+`
  until 2026-09-24; the bare integer is what `agent/orchestrator/lessons.py`
  parses, and "3" is the floor, so no information is lost by the change.)
- status: promoted-to-rule — `agent/skills/review/SKILL.md`, 2026-09-16,
  🧍 `retro_promotions` decided under the human's explicit delegation ("on
  you", 2026-09-16).

## L-process-018 — a live hardware test's raw logs are read once, summarised into counters, and never persisted, so the evidence is gone before the write-up and the run has to be repeated
- date: 2026-09-18 | source: E04-B36's first fix-build run (2026-09-16
  10:47–10:51), re-run 2026-09-18 01:38–01:53.
- situation: the fix build was installed on both phones and the live check
  was run. The link did drop within ~4–8 s — a decisive improvement over
  E04-B35 — but what was kept was a set of derived counters
  (`pixel_teardown_lines=0 pixel_port_rfc_closed=1 redmi_adapter_lines=2`)
  plus a handful of lines pasted into the session. Two days later, writing
  the run log required naming *which* code path closed the socket. The
  counters could not answer that: `redmi_adapter_lines=2` matched a regex
  that three different log statements satisfy. Going back for the lines
  found the phones' `main` ring buffer (2 MiB) had already rolled — the
  earliest surviving app line was ~37 h after the test. The evidence was
  unrecoverable and the whole run had to be repeated on both devices,
  including re-driving the human's personal phone.
- root cause: the harness treats a live hardware check as a step that
  yields a verdict, not as a step that produces an *artifact*. Nothing in
  `skills/implement` or a task's §8 "Manual" block says where the raw
  output is written, so the natural move — poll, grep, report the number —
  destroys the primary source at the moment it is read. A device log
  buffer is volatile and small; unlike a test suite, the check cannot be
  re-derived later from the same inputs, because the inputs are gone.
  The counters also encouraged a second error: a regex count invites a
  mechanism claim it cannot support, which is exactly what §6 of E04-B36
  already forbade after two wrong root causes in the same bug.
- fix applied: for any live hardware check, clear the device buffers and
  start a raw `logcat -v time > <file>` per device *before* the stimulus,
  keep the files as the run's artifact, and quote from the files in the
  run log. Grep the files afterwards with one pattern per distinct log
  statement, never one pattern spanning several — a count over a shared
  pattern cannot name a mechanism. The 2026-09-18 re-run followed this and
  produced the quotable lines the first run could not
  (`adapter state=13, tearing down 1 link(s)` at T₀+43 ms, and the losing
  `ACL disconnect … no registered socket, ignored` 818 ms after the read
  loop's own `port_rfc_closed`).
- recurrence: 1
- status: lesson. Next rung if it recurs: a rule in `skills/implement`
  that a task with a §8 Manual block must name the artifact path for each
  check, checked at review the way `files:` already is.

## L-process-019 — a checklist box is written while PLANNING the work, the plan then changes, and the drafted text ships as a claim that the work was done
- date: 2026-09-18 | source: E04-B36's second review round, caught by the
  reviewer (claude-sonnet-5).
- situation: E04-B36's DoD item read "§8 live checks run... **check 3 run**
  (see run log)". Check 3 (idle link 3 minutes) had never been executed on any
  build. The text was drafted in the same edit that split check 2 out to
  E04-B38, at a moment when running check 3 next looked cheap. Minutes later
  the plan changed — the phones needed reinstalling, which signs both apps out
  and needs a human at the Google account picker — and the already-written
  claim was never revisited. In the SAME turn, the message sent to the
  reviewer said plainly "check 3 has still not been run", so the task file and
  its author's own disclosure contradicted each other.
- root cause: a status field was authored as part of a *plan*, not as a record
  of an *observation*, and nothing forced reconciliation when the plan
  changed. This is distinct from the failures already on file: not reasoning
  ahead of evidence (`L-process-016`/`-017`), and not losing the evidence
  (`L-process-018`), but writing the intended outcome into a completion
  record and never correcting it. It is more dangerous than an honest gap,
  because round 1 of the same review had left the box correctly UNTICKED — the
  file got less truthful as it got closer to merge.
- fix applied: the box was unticked and rewritten to state what actually
  happened, including why check 3 cannot run unattended. Rule for future work:
  **never write a checklist/DoD box in the same edit that plans the work it
  describes.** Tick a box only in an edit whose sole purpose is recording an
  observation that has already happened, and whose text quotes the evidence.
  If a box must mention future work, it stays unticked and says "NOT RUN".
- recurrence: 1
- status: lesson. Next rung if it recurs: a `make health` / validate check that
  flags any `- [x]` DoD or checklist line in a task file whose text contains a
  forward-looking or unevidenced phrase (no commit hash, no quoted log line,
  no evidence-file reference), the same way rule 6 already fences `files:`.

## L-process-020 — a merged commit message is testimony, not measurement: it lives in the repository and so reads as repo state, but it records only what someone believed when they wrote it, and is never re-checked. Six factual errors in one session came from sourcing a claim from anywhere other than command output; the last was copied out of my own earlier commit body
- date: 2026-09-24 | source: PRs #309-#322, one session — `#311`/`#314`
  (case 1), `#309` (case 2), `#319` (case 3), `#315`/`#316` (case 4),
  `#315` (case 5), `#321`/`#322` (case 6)
- situation: six claims asserted in prose, each wrong, each correctable by a
  one-line command:

  | # | Claim | Truth | Where the wrong value came from |
  |---|---|---|---|
  | 1 | `(12 tags)` typed into a reviewer's evidence package | 13 | recalled |
  | 2 | line citations in a lesson file | off by +9, then mis-described as +3 | counted in a printed `sed` window, whose display position is not the file offset |
  | 3 | "18 transcribable reviewers" | 0 | `\s*` in `^reviewed_by:\s*(.*)$` crosses newlines under `re.M`, so the capture took the NEXT field's line |
  | 4 | "both H8 sites are E04-owned", then "corrected" to not-E04 | both ARE E04-authored; the original was right | read the directory path, not `git blame` |
  | 5 | "the grep count doubled" | unchanged, 1 per file | written from intent, then left stale after the fix removed the cause |
  | 6 | "six merges stale" | **14** | copied from my own merged `#321` commit body |

  Case 6 is the one that names the trap. "Six" was not invented: it is the
  count in `#306`'s subject line, `chore(E06-B01): repair six stale or invalid
  traceability records` — an adjacent, unrelated fact about the same file,
  which reached the changelog through a commit message I had written myself a
  few hours earlier.
- root cause: writing a claim and verifying it feel like one act and are two.
  Case 6 adds the specific trap: **a merged commit message is inside the
  repository, so it wears the costume of repo state.** It is not. It is a
  claim that was true, or was not, when it was written, and nothing re-checks
  it afterwards. It is also the source least likely to trip suspicion,
  because it is one's own prior reasoning.

  The only things that count as sources are **command output** and **file
  contents at a named ref**. A commit body, a PR description, an earlier
  paragraph of the document being edited, and a previous agent's report are
  all testimony.
- fix applied: none mechanical — this is a discipline, not a check, and
  saying otherwise would be its own instance of the failure.

  What the record actually shows about the Rule-5 gate, counted rather than
  asserted: **four of the six** (cases 2, 4, 5, 6) were caught by an
  independent review. **Case 3 the author caught** on re-count, before it
  became a 90-file backfill. **Case 1 the review got backwards** — it raised
  S2/BLOCKING against a document that was correct, because the author's
  hand-typed evidence package said 12; the author re-derived 13 and rejected
  the finding. That last one is the useful shape: a poisoned evidence package
  turns the gate against a correct document, because a toolless reviewer
  cannot re-derive anything and the package IS its reality.

  Evidence limit, stated so the entry audits itself: five of the six
  attributions are itemised in a merged commit body. Case 5's is not —
  `#315` records "round 2 REQUEST CHANGES (1x S3)" without naming which
  finding that S3 was, so the link rests on the session record. It is the
  one claim here that a future reader cannot re-derive from the repo alone.

  Two habits that did work and should stay:
  1. Build the evidence block by RUNNING the commands in the same tool call
     that writes the prose (`{ ... } > file`), and paste the output, rather
     than narrating what the tree is about to become.
  2. When a change makes something a document says untrue, re-run that
     document's own claims against the post-change tree before pushing. Twice
     this session a fix left the prose describing the pre-fix state, and once
     the commit correcting a miscount introduced a fresh one.
- recurrence: 6 (`(12 tags)`, the +9 citations, "18 reviewers", the H8
  ownership over-correction, the doubled-grep claim, "six merges stale" —
  every factual claim I sourced from something other than a command this
  session). Counted per instance, following `L-process-011`, which recorded
  four instances from a single sweep as `recurrence: 4`.
- status: lesson

## L-process-021 — a negative claim is only as good as the search designed to falsify it. Three times in one session a command ran, its output was real, and the sentence built on it asserted something the command had not measured. This is `L-process-020`'s mirror image: there the evidence was recalled; here it was freshly produced and genuinely true, and still did not support the proposition
- date: 2026-09-24 | source: PRs #324-#329, one session — `#324`/`#327`
  (case 1), `#327` (case 2, caught pre-commit), `#327`/`#329` (case 3)
- situation: three confident negatives, each false, each produced by a real
  command whose output was accurate:

  | # | Claim written | Command actually run | What that command could not see |
  |---|---|---|---|
  | 1 | "There is no navigation chrome of any kind" | `grep -rln "NavigationBar\|NavigationRail\|TabBar\|IndexedStack" lib` → no matches | a bottom nav hand-built from `Container`+`Row`+`_NavItem`, present in **four** views, and drawn by `dashboard.md` elements 37/40/43/46 |
  | 2 | "three nav items" | read `dashboard_view.dart` as far as the third `Expanded` | the fourth `Expanded` (Settings), 8 lines further down |
  | 3 | "the first full design-gate baseline"; the screens had been "reporting FAIL into a void" | ran `design-verify` across all 17 probe-backed screens | `epics/E06-personal-chat/tracker.md`, which records the same 16-screen run on **2026-09-12**, twelve days earlier, with three of the four numbers character-identical and all 32 independently reproduced by that reviewer |

  Case 1 names the trap exactly. A grep for three class names establishes
  that those three class names are absent from `lib/`. It says nothing
  whatever about whether the application has navigation — and the gap between
  those two propositions is invisible at the moment of writing, because the
  command *did* run and its output *was* true.

  Case 3 is the expensive one, because the falsifying evidence was in the
  repository, written by a previous agent, in the obvious place: the epic's
  own tracker. Nothing was hidden. The search was simply never aimed there.
- root cause: **an existential claim and a universal claim need opposite
  searches, and grep only ever supports the existential one.** `grep X` finding
  a hit proves "X exists" — sound. `grep X` finding nothing proves "this
  spelling of X is absent", which is not "no X exists" unless the search
  enumerated every spelling an X could have. Every case above is that
  substitution, made silently.

  The second-order cause is *where* the search ran. All three searched `lib/`
  or the current tree. This repository keeps its own history of what was
  measured — `epics/*/tracker.md`, `retro.md`, merge notes, `design/gaps.md` —
  and a claim of novelty ("first", "nobody has", "never been") is a claim
  about that record, not about the code. None of the three searched it.
- fix: before writing any sentence containing *no*, *none*, *never*, *nobody*,
  *first* or *only*:
  1. Name what an instance would look like **if it existed**, and search for
     that, not for the absence. For "no navigation": search for what the screen
     renders at the bottom, or read the design contract's element table — not
     for framework class names.
  2. Enumerate the spellings. A hand-rolled equivalent of a framework widget
     is the default outcome in a codebase with a measured design, not an edge
     case — three of this project's four "missing" UI findings were hand-built
     equivalents.
  3. For any claim of novelty, grep the **record** as well as the code:
     `epics/*/tracker.md`, `epics/*/retro.md`, `design/gaps.md`. If a previous
     agent measured it, they wrote it down.
  4. Read to the end of the construct before counting it. Case 2 was four
     items reported as three because the fourth was below the visible window.
- prevention: a reviewer instruction, since this is not mechanically
  checkable: when a PR body or document asserts a negative or a novelty, the
  reviewer's job is to spend one search trying to falsify it. That is what
  caught cases 1 and 3 here — both were found by a reviewer checking a claim
  in a *different* PR, not by the document re-reading itself.
- recurrence: 3 ("no navigation chrome of any kind", "three nav items", "the
  first full design-gate baseline"). Counted per instance, following
  `L-process-011` and `L-process-020`.
- status: lesson
