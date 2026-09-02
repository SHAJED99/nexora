# E07 · Groups & Voice Calls — Retro

**Run:** 2026-09-02, retroactively (after the epic had already merged into
`development` — see L-process-013 below, the first finding this retro
produced). Evidence: `tracker.md`'s full review log, `make health`,
`epic.md`, all 18 task/bug files' review-log entries and Open Questions.

## What shipped
14 tasks (group data model + migration, role permissions, membership
protocol, Sender-Keys group crypto + rotation, group message fan-out,
conversation read model widened to groups, the Conversations screen's
Groups section, call session/signaling, realtime traffic priority,
make-before-break route migration, a design gap pass, and PTT's
disposition) + 4 bugs found by the sweep, 2 fixed (`B01` S2 live, `B04` S3
flake) and 2 correctly deferred (`B02`/`B03`, latent behind a still-
prospective media-path task). 698/698 tests, `flutter analyze` clean,
P1/P2 = 0. Every task/bug independently reviewed by a different model
(rule 5), with falsification (revert the fix, confirm it fails for the
right reason, restore) as the default verification style throughout —
this held even for the sweep's own two fixes, and one review went further
than the builder's own testing twice (`B01`'s silent-no-op probe, `B04`'s
construction-based CSPRNG argument beating any finite test-run count).

## What recurred (the retro's actual job)
- **A genuine cross-task composition gap, same shape twice in one epic.**
  `E07-T14` closed `OQ-E07-T06-2` (the group send path never wired into
  `MessagingStack`) before merge — caught proactively. `E07-B03` is the
  *same shape* for the call vertical (`CallMigrationController` never
  wired into `lib/`) — not caught proactively, found only at the sweep.
  Task-sharding's own dependency slicing (group vertical vs. call
  vertical, each independently reviewed) is exactly what let the same
  composition-gap pattern happen twice without either instance teaching
  the other, because they're in different verticals of one epic.
- **Every bug file the sweep wrote needed the same two mechanical fixes**
  (empty `files:` fence, invalid `status: open`) — see `L-process-011`/
  `L-process-012`. 4-for-4 and 4-for-4. Both are now rules in
  `skills/bug-sweep`.
- **The design-fidelity gate's own capability gap held its ground twice,
  unprompted** (`L-frontend-001`'s InkWell-swallowing rule, confirmed by
  `T08` and `B01` independently disclosing the same pre-existing red
  score rather than routing around it) — a rule working exactly as
  intended, worth recording as a success, not just misses.
- **A design-probe fixture gap went unfixed across three separate
  reader-moments** (`T08`'s reviewer, `B01`'s reviewer, and the
  carried-forward note itself) without anyone being positioned to fix it
  — `L-design-002`, new rule in `skills/design-fidelity`.
- **Two pre-existing lessons (`L-process-001`, `L-process-010`) had sat at
  `recurrence: 2, status: lesson` since E06**, flagged by `make health`
  H6 as overdue for promotion. Neither is E07's own miss, but this retro
  is when they finally got promoted — to a hook (frontmatter parse
  failures are now a hard `--validate` error, not a soft warning) and a
  rule (`reviewed_by` must lead with a declared model string), respectively.
- **`make health`'s own H4 check had a bug**, not a task: its regex only
  matched the feature-task fence heading, so every compliant bug-task
  fence (`## What this fix does NOT do`, the heading `L-process-009`
  itself established) read as absent since the day that rule was written.
  Fixed directly (`L-process-014`) — a verifier that was never actually
  run against its own documented example.

## The retro's own miss, found by running late
This retro ran **after** `epic_07` had already merged into `development`
— the orchestrator cleared both human gates and merged without writing
`retro.md` first, because `make health`'s H3 check only reads `epic.md`'s
`status:` field (still `todo`, never flipped) and had nothing to flag.
Recorded as `L-process-013`; H3 now also checks `git merge-base
--is-ancestor <epic-branch> development` directly, so a stale frontmatter
field can't hide this again. No epic content needed to change — the merge
itself was sound (independently re-verified: 698/698, clean analyze, no
conflicts) — only the process gap needed closing.

## Also surfaced, not previously known
`L-process-015`: rule 9's `runs/`/`metrics.csv` logging has never fired
for any epic in this project, because every dispatch this session (and,
from the empty state of both paths, every prior epic's) went through the
Agent tool directly rather than `agent/adapters/run-claude.sh`, the only
thing wired to write either artifact. Left as a lesson, not a fix — which
of "build a logging shim for Agent-tool dispatch" or "correct the rule to
say it doesn't apply here" is a human process-design call, not an
inference for one epic's retro to make alone. Consequence: §5's estimate
calibration step has no data to run on, for any epic, and didn't for this
one either.

## Promotions this retro (🧍 `retro_promotions` — awaiting human)
| Lesson | → | Where |
|---|---|---|
| `L-process-001` | hook | `agent/orchestrator/scheduler.py` — frontmatter parse failure is now a hard `--validate` error |
| `L-process-010` | rule | `agent/skills/review/SKILL.md` — `reviewed_by` must lead with a declared model string |
| `L-process-011` | rule | `agent/skills/bug-sweep/SKILL.md` — bug files need a best-effort `files:` fence at authoring time |
| `L-process-012` | rule | `agent/skills/bug-sweep/SKILL.md` — bug files use `status: blocked`, not an invented word |
| `L-design-002` | rule | `agent/skills/design-fidelity/SKILL.md` — widening a screen's data shape requires updating the shared probe fixture or a named follow-up |

`L-process-013`, `L-process-014`, `L-process-015` are recorded as
lessons/direct-fixes, not rule promotions — see each entry in
`agent/memory/lessons/process.md` for why.

## Calibrate the estimates
No data — see `L-process-015`. Nothing to adjust in `skills/task-sharding`
this retro.

## Open follow-ups for the next epic's sharding to read
- `E07-B02`/`E07-B03` (P3, deferred): both need the prospective real-time
  media-path task, which must reshape the `RoutingEngine.onRouteFailure`
  seam (`B02`) and wire `CallMigrationController` into `CallSignaling`'s
  session lifecycle (`B03`) — both already scoped in each bug file.
- The design-probe fixture still seeds zero groups (`L-design-002`) —
  whichever task next touches `test/design/design_probe_test.dart` should
  close this, not just re-disclose it a fourth time.
- `epic.md`'s `analyze_report` gate (the disclosed MoSCoW exception from
  sharding time) is still ⏳ awaiting human acceptance — non-blocking, but
  worth clearing rather than carrying indefinitely.
