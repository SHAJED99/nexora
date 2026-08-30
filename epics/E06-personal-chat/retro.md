# E06 · Personal Chat ★ (the wedge) — Retro

**Date:** 2026-08-30 · **Epic status:** 13/13 tasks + 4/4 bugs closed
(B01 fixed, B02 fixed P1, B03 fixed P2, B04 deferred to E11 by human
decision), P1/P2 = 0, `epic_06` @ `be0804d`, pending the 🧍 human merge gate
into `development`.

## What shipped
The epic's own headline journey, for real: a Flutter-capable design-fidelity
gate closing OQ-E00-3 (T01); the relay wire-packet framing and ciphertext
type tag closing OQ-E05-B01-1 and E03-B03 (T02); a single-instance messaging
composition root (T03); real link-quality measurement replacing E04-B03's
twice-dropped null (T04); a live inbound pipeline enforcing FR-ROUTE-003's
confidentiality boundary (T05); `MessagingCoordinator`, the driver that
finally calls `processQueue`/`sweepExpired`/`reclaimPayloads`, closing
E05-B02 (T06); prekey-bundle exchange over the mesh with no auto-trust path,
closing OQ-E05-T02-1 (T07); delivery acknowledgements (T08); a conversation
read model shared by all three screens (T09); the Conversations, Chat and
Dashboard screens (T10-T12); and a design gap pass for voice/PTT/attachments/
location, left genuinely 🧍 unapproved (T13). 384/384 tests, `flutter analyze`
clean at close, suite grew 250 → 384 across the epic.

Two blocking human decisions (the relay-trigger model, the prekey-bundle
channel) and 12 pending design-gap sign-offs were resolved by applying each
task's own advisory recommendation, under the human's explicit standing
instruction to proceed without waiting and document every choice for
end-of-run review — every decision is inline in its task file's Open
Questions or `design/gaps.md`'s approval line, none silent.

## What went well

**Reviewer falsification kept paying — five more times, on top of E05's
five.** L-qa-001 (already a rule) held without exception: T04's Kotlin
loss-window guard, T06's re-entrancy coalescing claim, T07's untrusted-
identity-swallow prohibition (the single most security-critical line in the
epic), T09's single-grouped-query and tie-break-determinism claims, and
B02's full object-identity chain from `main.dart` through to
`DevicesController`'s constructor — every one independently re-derived or
re-broken by the reviewer, not read and trusted. B02's reviewer explicitly
recorded "no doubt" about the fix closing an S1 at the root, which is what
this practice is for.

**Real bugs were found and fixed inside task review, before ever reaching
the sweep** — T10's Listener/gesture-arena/accessibility regression, T11's
missing-Queued-bubble UX defect, T12's off-palette color bug. Each is a real
defect a green suite did not catch; each was caught by a reviewer running
its own probe, not by re-reading the diff.

**Two obligation-ownership near-misses were caught proactively, not by a
later sweep.** T06's reviewer flagged that `MessagingCoordinator.start()`
had no caller anywhere in the app, correctly out of T06's own `files:`
fence — resolved same-day as `OQ-E06-T06-4`, carried into T11's own contract
(fence amended to add the one-line call) rather than left as prose. T07's
reviewer found the control-handler seam T08 (not yet built) would collide
with — resolved as `OQ-E06-T08-2`, T08's own fence amended before it even
started. Both are the L-process-006 rule working exactly as designed.

**A weekly rate-limit freeze did not stop the epic.** Independent-review
capacity was blocked mid-epic; rather than wait, the orchestrator reviewed
`E06-B01`, `E06-T01` and `E06-T07` (security lens) directly — a disclosed
rule-5 deviation, but with the same rigor (independent re-runs,
falsification, not trusting the builder's transcript) applied throughout.
Capacity returned and normal dispatched review resumed for the rest of the
epic. The deviation was honest and effective; the one real gap it left is
`reviewed_by`'s free text not being machine-parseable (L-process-010).

**A new capability was added mid-epic and used for real, safely.** Per the
human's request, low-risk drafting work was routed to a free OpenRouter
model (one line of a T12 color fix) — the model never had file-write or
command-execution authority; the orchestrator applied its suggestion via its
own tools and independently re-verified before committing. Confirms the
shape this project should reach for again: delegate drafting, never
delegate verification.

## What went wrong

### 1. A carried-forward observation, recorded correctly, sat unread for eight tasks — twice, in one epic
E06-T03's reviewer flagged `devices_controller.dart`'s fallback
`TransportService()` on day one of the epic. Eight tasks later, the sweep
found it had been silently hijacking the app's only native-transport-event
handler the whole time (`E06-B02`, **S1** — the epic's highest-severity
finding). Independently, T12's reviewer named a *second* carried-forward
risk (the delivery-tick glyph mapping's three-way duplication) as latent,
without checking whether it had already drifted; the sweep found it had
(`E06-B03`, S3). Both entries were in the right place — the tracker's own
§Carried-forward observations — and neither had a reader before the sweep.

This is the same family as L-process-006/007 (an obligation written down
correctly, with no downstream reader), but a new variant: within one epic,
not across two, and in the tracker rather than a sibling task's prose or a
previous epic's retro.

**Promotion decision: new lesson L-process-008 at recurrence 2, promoted
to a rule immediately** — same justification as L-process-006's early
promotion: the check is cheap (read the tracker's own carry-forward section
before each new dispatch, cross-check the next task's `files:` fence) and
this is now the third documented shape of the same underlying gap in three
epics. Added to `skills/bug-sweep`.

### 2. Every bug task file in the project is missing a scope fence — `make health` found it, not a human
`make health`'s H4 check failed on `E06-B02`, `E06-B03`, `E06-B04`, and the
pre-existing `E05-B02` — not an empty §4, an **absent** one. Feature task
files in this project reliably have one; the bug-task shape this epic used
(inherited from `E06-B01`) never asked for it. Both fixes this epic shipped
without one; neither review found scope creep, which means the control held
by luck rather than by design, twice.

**Promotion decision: new lesson L-process-009 at recurrence 4 (every bug
task file so far), promoted to a rule immediately.** Added to
`skills/bug-sweep`'s "Writing a bug task that gets fixed once" section.

### 3. A real, hard-won infra gotcha cost real time via a wrong diagnosis
T01's own probe harness hung on `flutter test`, first diagnosed as "a
RenderFlex overflow makes Flutter's pump/layout cycle hang" — plausible,
partly true (the overflow was a real bug, closed as `E06-B01`), and
**not the actual cause of the hang**. The real cause — `flutter_test`'s
fake-async binding never delivering real `dart:io`/`Process.run`
completions without `tester.runAsync()` — was found only by direct
bisection after the wrong fix (bounding `pumpAndSettle`, scoping the widget
walk) didn't resolve it. `E06-B01`'s own fix stayed correct and worth
keeping; the diagnosis that motivated raising it as a bug was not.

**Promotion decision: new lesson L-infra-001, recurrence 1, kept as a
lesson** — one occurrence, but high-value and non-obvious enough to write
down explicitly in `skills/design-fidelity` (this probe is reused by every
future screen task) rather than risk a second session rediscovering it the
same expensive way.

### 4. A gate-gaming shortcut had to be manually re-warned against twice in one epic
T10's builder swapped `InkWell` for `Listener` specifically to score better
against T01's own probe-dumper limitation — a real accessibility and
gesture-arena regression, caught and fixed. The *same* dispatch prompt
warning had to be hand-typed into T11's and T12's builder instructions to
stop it recurring for real. It worked both times, but only because someone
remembered to restate it — the exact "weakest possible control" this
project's own retro skill warns against.

**Promotion decision: new lesson L-frontend-001 (the project's first),
promoted to a rule at a single real occurrence** — the two near-misses are
the evidence that the lesson was already understood and already had to be
re-taught by hand, which is the signal to write it down once instead.
Added to `skills/design-fidelity`.

### 5. Smaller, worth naming
- **The `reviewed_by` field for rate-limit-deviation reviews reads well to
  a human and not at all to `make health`'s H5 check** (`E06-B01`,
  `E06-T07`) — L-process-010, recurrence 2, kept as a lesson (a field-format
  fix, not yet worth a rule).
- **The delivery-tick glyph mapping's color tokens still diverge slightly
  across all three screens** even after `E06-B03`'s shape fix — chat and
  dashboard already disagreed with each other on the `read`-state green
  before this epic, and conversations now uses a third grey. Not a new
  defect, not blocking, logged for a future small S4 cleanup rather than
  filed as its own bug.
- **`metrics.csv` still does not exist for E06.** Sixth retro in a row to
  say this (E01 through E05 all carried the same line). It should stop
  being a retro line.

## What got promoted (🧍 `retro_promotions` — ⏳ AWAITING HUMAN)
Skill files are code; these edits are written and pending review, not
self-approved.

| Lesson | Recurrence | Decision | Where |
|---|---|---|---|
| **L-process-008** mid-epic carry-forward has no reader | **2** (new) | promote to rule at recurrence 2 — 3rd documented shape of the same family in 3 epics | `agent/skills/bug-sweep/SKILL.md` (new step, before the sweep section) |
| **L-process-009** bug tasks have no scope fence | **4** (new) | promote to rule — every bug task file in the project fails this today | `agent/skills/bug-sweep/SKILL.md` ("Writing a bug task" section) |
| **L-frontend-001** gaming the design-fidelity gate via widget choice | **1** real + 2 near-misses (new) | promote to rule at recurrence 1 — near-misses show it was already re-taught by hand twice | `agent/skills/design-fidelity/SKILL.md` (new Rule 5) |
| **L-process-010** rate-limit-deviation `reviewed_by` unparseable | 2 (new) | keep as a lesson — a format fix, not yet a rule | — |
| **L-infra-001** `flutter_test` needs `runAsync` for real I/O | 1 (new) | keep as a lesson — high-value, one occurrence | — |
| **L-infra-002** external-model routing and this session's permission classifier | 1 (new) | keep as a lesson — an operating-environment fact, not a project-code gap | — |
| **L-qa-001** reviewer falsification | 10 (of the practice paying off, 5 more this epic) | already a rule; held without exception again | `agent/skills/review/SKILL.md` §2 |
| **L-process-006** obligation-in-prose | 3 (2 more near-misses this epic, both caught proactively) | already a rule; held — both `OQ-E06-T06-4` and `OQ-E06-T08-2` are this rule working | `agent/skills/task-sharding/SKILL.md` §6 |

Nothing pruned: no existing rule has stopped firing.

## What the numbers said
- 384/384 tests, `flutter analyze` clean at close. Suite grew 250 → 266 →
  272 → 279 → 281 → 306 → 321 → 337 → 341 → 362 → 382 → 383 → 384 across the
  epic's 13 tasks + 4 bugs.
- 13 tasks + 4 bugs against a 13-task plan. Every bug was a **seam** bug
  (B01 pre-existing UI defect surfaced by new tooling; B02/B03 cross-task
  carry-forwards; B04 a protocol-level gap correctly deferred) — the fourth
  epic running with this exact signature (E03 had none logged this
  precisely, E04 3 seam bugs, E05 3 seam bugs, E06 4). The sweep remains
  where this project's defects live.
- Review rounds: T10, T11, T12 and B02's fix-round-2 review each needed a
  round 2, all for genuine defects, none for a false positive. Rule 5 held
  for every dispatched review; three reviews were the orchestrator directly
  during the rate-limit freeze (disclosed deviation, see above).
- Estimates: all tasks `S`/`M`, none `L`, none resharded. No tier
  recalibration needed.
- **`metrics.csv` still does not exist** — sixth consecutive retro to
  record this. It should stop being a retro line and become a task.

## Open follow-ups carried forward
- **`E06-B04` → E11** (human decision, recorded in the bug file with the
  owning epic named): `frame.source` is unauthenticated at the transport
  layer; the real fix is signing control frames, a protocol change spanning
  T02/T05/T07/T08 all at once — E11 already owns protocol hardening.
- **`GAP-014`/`GAP-015`/`GAP-016`/`GAP-017` and `OQ-E06-T13-1` (PTT)** —
  all 🟡, genuinely unapproved (T13 deliberately did not self-approve its
  own gaps, L-process-002's standing rule). Nothing derived from these
  contracts is shardable until the human clears `design_contract_approval`.
- **The delivery-tick color-token divergence across chat/dashboard/
  conversations** (§5 above) — small, not urgent, worth a future S4 cleanup
  task rather than being forgotten as an untracked observation (which is
  precisely what this retro's own §1 finding warns against doing).
- **The lesson hook still never injects `qa.md`** — E05's retro flagged
  this and it is still true; `index.yaml`'s `always:`/`by_layer:` maps
  never mention `qa`. Repeating rather than re-diagnosing: this is a human
  decision (it affects every dispatch), not a silent fix.
- `metrics.csv` — see above, sixth time.
