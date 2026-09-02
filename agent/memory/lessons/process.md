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
  field), 2026-09-02 via `skills/retro` (E07), 🧍 `retro_promotions` ⏳
  awaiting human. Closes the exact gap the second occurrence (E06-T01)
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
  instead), 2026-09-02 via `skills/retro` (E07), 🧍 `retro_promotions` ⏳
  awaiting human.

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
  ⏳ awaiting human.

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
- recurrence: 1 (first observed — but 4/4 bug files in the one sweep that
  produced it, so treating this as load-bearing enough to promote now
  rather than waiting for a second sweep to repeat it)
- status: promoted-to-rule — `agent/skills/bug-sweep/SKILL.md` (same
  section as L-process-011), 2026-09-02 via `skills/retro`, 🧍
  `retro_promotions` ⏳ awaiting human.

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
- status: lesson

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
- recurrence: 1
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
- recurrence: 1 (first time anyone checked; the underlying gap is
  project-wide across all 7 completed epics, not new to E07)
- status: lesson — deliberately not promoted straight to a rule/hook this
  retro, since which of (a)/(b) above is correct is a process-design
  choice with real cost implications (building a logging shim vs.
  admitting a stated rule doesn't apply to how this project actually
  runs), and `skills/retro` Rule 2 reserves that kind of change for a
  human decision, not an inference made under one epic's retro alone.
