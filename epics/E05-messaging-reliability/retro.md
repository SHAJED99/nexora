# E05 · Messaging Reliability & Multi-Device Sync — Retro

**Date:** 2026-08-29 · **Epic status:** 5/5 tasks + 3/3 bugs closed
(B01 fixed P2, B02 deferred to E06 by human decision, B03 fixed P3),
P1/P2 = 0, `epic_05` @ `47748bd`, pending the 🧍 human merge gate into
`development`.

## What shipped
The semantics layer over E03's crypto and E04's routing: a message domain
model + Queued/Sent/Accepted/Delivered/Stored/Read/Failed state machine with
its tables (T01), an offline outgoing queue with in-transaction sequence
reservation (T02), an incoming path with dedup and logical ordering under
out-of-order arrival (T03), per-device-pair sync cursors for missing-data-only
multi-device catch-up (T04), and the security-restrictive conflict-resolution
precedence — BLOCK>TRUST, LOCATION-OFF>LOCATION-ON, REVOKED>ACTIVE,
REMOVED>MEMBER (T05). 249/249 tests green, `flutter analyze` clean.

Two rounds each on T01, T04 and B01 — every one of them a real defect the
suite was green over.

## What went well

**The reviewers falsified instead of trusting green — five times, and it
paid every time.** This is the epic's best pattern and it is now a rule
(`skills/review` §2, L-qa-001):
- T04: green at 232/232; the reviewer wrote `Future.wait([record(…,10),
  record(…,4)])` anyway and got a cursor of **4** — a real lost update.
- T02: rather than accept the passing sequence-number test, a 60-way
  concurrent probe *plus* a read of drift's own `NativeDatabase` locking
  source. The claim held — and holding *for a cited reason* is what later let
  B01's fix safely move encryption outside that transaction.
- T03: the same class re-checked and cleared on evidence (drift's lock plus
  `messages.id`'s PRIMARY KEY as a second line of defence), written down so it
  is not re-litigated.
- T01: the reviewer checked what drift's `createTable()` does on *upgrade*
  versus `createAll()` on a fresh install — upgraded installs would have
  silently had no index on the keyset-paginated query. **No test could have
  failed for this**; only reading the library could.
- B01 round 2: the reviewer found the new regression test did not
  discriminate (the crafted buffer threw pre-fix too, for the wrong reason).
  The re-fix deleted the version-byte check, watched the test fail with
  `Actual: <Instance of 'MessageEnvelope'>` — the garbage envelope parsing
  cleanly, exactly the bug — and restored it byte-for-byte.

**Honesty under pressure held.** B01's builder disclosed that one of its four
sub-tests passed pre-fix rather than quietly claiming four reds; disclosed a
*new* crash-window hazard its own reorder introduced; and refused to invent an
untested `CiphertextMessage` re-typing heuristic, naming OQ-E05-B01-1 instead.
The sweep listed five candidate seams as **confirmed non-issues with
reasoning** so they are not re-litigated. Rule 3 was respected on both
judgement calls that needed a human (B02's trigger model, B03's Option A).

**L-process-005 worked as a lesson.** E05's analyze report explicitly ran
E04's union-sufficiency check and found two genuine gaps (no prekey-bundle
exchange, no gap-fill protocol), recorded as Open Questions rather than left
undiscoverable. A lesson written one epic earlier changed this epic's gate
output. Not incremented — no new occurrence of the miss.

## What went wrong

### 1. The counter/cursor race class hit a fifth time (T04) — and the rule missed it because it names the wrong half
`recordLocalProgress` read the cursor, `await`ed, then wrote — a lost update
under two overlapping calls. L-backend-003 was promoted to a rule in
`implement/SKILL.md` §6 after recurrence 4 in E03/E04, and the rule was live.

**Did the rule help? Honest assessment: not at authoring altitude, yes at
review altitude, and its wording is the reason.** The §6 rule says: introducing
a counter → audit every other **reader**. T04's defect is not a stale sibling
reader; it is the counter's **own writer** updating non-atomically. The rule
could be followed to the letter and still permit this code, so calling it
"ignored" would be wrong — it did not cover the shape. What the accumulated
lesson *did* buy was recognition speed: the reviewer reached for a concurrency
probe unprompted on both T03 and T04, cleared T03 on cited evidence, and
demonstrated T04's lost update concretely before writing the finding. One
round, one guarded upsert statement, one falsified regression test, merged
same day.

**Promotion decision: extend the rule, do not escalate to a hook.** §6 now has
two numbered checks — audit other readers, *and* make the write a single
atomic statement plus write the two-concurrent-call falsification test. A hook
would have to detect "a read and a write of the same durable counter separated
by a suspension point", which is dataflow analysis, not a grep; noted as a
recommendation for the human rather than built. Recurrence is now 5 — if a
sixth arrives in E06/E07 *after* this extension, that is the evidence that
rules cannot carry this class and a real analyzer is warranted.

### 2. Cross-task authorship of an obligation with no owner (E05-B01) — a new failure shape
T03's own file stated who serializes the wire envelope — "the sending side
(T02)" — and `receive_message_use_case.dart:40-42` repeated it in source as
settled fact. **T02's file never mentions an envelope.** Both tasks were built
and APPROVEd correctly inside their own fences; the obligation lived in
neither `files:` list. Result: a wire format with a consumer and no producer.
The reviewer's probe fed T02's real output to T03's deserializer and got
`FormatException`; the worse mode was a *silent* mis-parse into a garbage row
whose garbage id could evict a legitimate message through dedup. Every
EARS-MSG-2/3 test in the epic proved dedup and ordering only against
test-fabricated envelopes — neither task's suite ever put T02's output into
T03's input.

This is **not** L-process-005. There, the union of tasks was insufficient for
the epic's scope. Here the union *describes* the work correctly and no binding
contract carries it — two tasks silently agreeing that someone else does it
contradicts nothing, so the Analyze gate's Contract-sanity check passes.

**Promotion decision: new lesson L-process-006, promoted to a rule at
recurrence 1.** Justification for skipping a rung: the check is mechanical and
cheap at sharding time (grep each task file for other task ids, then read the
named task's own contract), and it is the third member in two epics of one
family — the Analyze gate verifying non-contradiction while nobody verifies
ownership or sufficiency (E04-B03, E05-B01, E05-B02). Added as the
**Obligation ownership** row in `skills/task-sharding` §6.

### 3. Inter-epic handoff loss (E05-B02) — and it happened twice, not once
E04's close wrote down two obligations for E05, in exactly the places the
harness says to write them. **Both were dropped.**

1. **The relay scheduler.** `E04-B02.md`'s approved review advisory said the
   retention guarantee "only becomes real once E05 wires both onto a
   scheduler", and E04's retro repeated it. No E05 task mentions a scheduler;
   `processQueue`/`sweepExpired`/`reclaimPayloads` ended the epic with zero
   call sites, so EARS-MSG-1's "and send once a route is available" half had
   no mechanism at all. Rediscovered only because the sweep reviewer chose,
   unprompted, to re-read E04's bug files.
2. **The link-quality wiring — found by *this retro*, still open.** E04's
   retro §Open follow-ups: "E05 must wire real RSSI/latency/loss measurements
   into the now-extended Pigeon contract … without wiring,
   `RoutingEngine.computeRoute()` returns `null` for every destination on a
   real device." Nothing in `epics/E05-messaging-reliability/` mentions
   `rssi`, `onLinkQuality` or `recordLinkMeasurement`;
   `transport_service.dart:182` and `transport_api.g.dart:362` still carry
   comments saying this "is E05's job". **The bug sweep did not catch this
   one either.** E05 closes with it unwired — see §Open follow-ups.

Two written handoffs, two drops: a 100% loss rate for this carrier. The root
cause is structural, and B02's own file already named it: the analyze gate's
inputs are this epic's `epic.md`, its tasks and `spec/`. Nothing reads the
*previous* epic's retro, bug advisories or merge-gate notes. Rule 8 ("memory
before work") is hook-enforced for lessons; nothing equivalent existed for
carry-forwards. An advisory in a closed bug file is the weakest possible
carrier — correct, dated, attributed, and orphaned.

**Promotion decision: new lesson L-process-007 at recurrence 2, promoted to a
rule.** `skills/task-sharding` gains a **step 0** ("read what the previous
epics handed you", an input to slicing) and an **Inherited obligations** row in
the Analyze gate: every obligation addressed to this epic must appear in the
report as covered-by-`<task-id>` or as an explicit Open Question with an owner.
**Hook: recommended, not built.** `make validate` could fail an epic whose
`depends_on:` epics' retros contain "must" language naming it unless that epic
cites the source — but the parsing is heuristic English in a retro, so the
human should set the false-positive tolerance before it becomes blocking.

### 4. Smaller, worth naming
- **B03**: `Sent` was applied on a bare INSERT that cannot fail, so the
  `Failed` branch was unreachable in production and the epic's §Scope and the
  task's §2 disagreed about what `Sent` means. Resolved by the human as Option
  A (`Sent` = durably enqueued locally; docs corrected, no new state). The
  lesson underneath is small but real: a state name whose definition lives in
  two documents will drift, and the first reader to notice is a bug sweep.
- **`delivery_states` and `sync_cursors` have no product writer.** Correctly
  scoped out (T01 §3 conditional, T04's fence), but
  `sync_cursor_service.dart:113-114` *claims* T02/T03 call it — the same
  false-comment shape as B01's root cause, in a second file. Comments that
  assert a wiring nobody built are how B01 happened.

## What got promoted (🧍 `retro_promotions` — ⏳ AWAITING HUMAN)
Skill files are code; these edits are written and pending review, not
self-approved.

| Lesson | Recurrence | Decision | Where |
|---|---|---|---|
| **L-backend-003** counter/cursor authority | 4 → **5** | rule **extended** (writer-side atomicity + required concurrency falsification test). Not a hook — needs dataflow analysis, recommended to the human | `agent/skills/implement/SKILL.md` §6 |
| **L-process-006** cross-task obligation with no owner | **1** (new) | promote to rule at recurrence 1 — mechanical, cheap, 3rd member of one family in two epics | `agent/skills/task-sharding/SKILL.md` §6 (Obligation ownership) |
| **L-process-007** inter-epic handoff loss | **2** (new) | promote to rule; hook recommended for the human, not built | `agent/skills/task-sharding/SKILL.md` §0 + §6 (Inherited obligations) |
| **L-qa-001** ✅ reinforcing — reviewer falsification | 5 (of the practice paying off) | promote to rule so it stops depending on individual diligence | `agent/skills/review/SKILL.md` §2 (Falsify the evidence) |
| **L-process-005** union sufficiency | 1 (unchanged) | keep as a lesson — it fired correctly at E05's analyze gate; no new occurrence of the miss | — |

Nothing pruned: no existing rule has stopped firing.

## What the numbers said
- 249/249 tests, `flutter analyze` clean at close. Task suite grew
  180 → 232 → 245 → 249 across the epic.
- 5 tasks + 3 bugs against a 5-task plan. All three bugs were **seam** bugs
  between two correct `must` tasks — none was an over-scoped or mis-estimated
  task. Same signature as E04 (3 sweep bugs, all seams). Two epics running,
  the sweep is where this project's defects live, and every one of them was
  invisible to task-level tests by construction.
- Review rounds: 3 of 8 work items needed a round 2 (T01, T04, B01), each for
  a genuine defect. Rule 5 held throughout — sonnet built, opus reviewed.
- Estimates: all tasks `M`/`S`, none `L`, none resharded. No tier recalibration
  needed.
- **`metrics.csv` still does not exist** — carried forward from every prior
  epic's retro, still not mechanically fixed. Five retros have now recorded
  this; it should stop being a retro line and become a task.

## Open follow-ups carried forward
- 🔴 **E04-B03's link-quality wiring is still unwired and now twice-dropped.**
  `RoutingEngine.recordLinkMeasurement` has no production caller;
  `TransportService.onLinkQuality` is an empty method. Until it is wired,
  `computeRoute()` returns `null` for every destination on a real device.
  **This must enter E06's sharding as a named dependency, not a retro line** —
  a retro line is exactly the carrier that failed twice. The new §0 +
  Inherited-obligations rule will force E06's analyze gate to surface it;
  confirm it does.
- **E05-B02 → E06** (human decision, recorded in the bug file with the owning
  epic named): the relay-queue driver, the `SyncCursorService.recordLocalProgress`
  wiring at the store point, and the correction of its false doc comment.
- **E05-B01's send↔receive wiring and OQ-E05-B01-1** — who reconstructs a
  `CiphertextMessage` from relayed wire bytes. Reviewer's cheapest suggested
  fix: carry `CiphertextMessage.getType()`'s tag in E04's relay-packet
  framing rather than a try-both heuristic. E06 needs this closed before any
  live transport receive path.
- **OQ-E05-T02-1** (no prekey-bundle exchange exists anywhere) and
  **OQ-E05-T04-1** (no gap-fill protocol) — both honest, both still open,
  both likely E06's.
- **The lesson hook never injects `qa.md`.** `index.yaml` maps no layer to the
  `qa` area, so L-qa-001 would reach no agent through the hook. It reaches
  reviewers via the `skills/review` rule instead, which is why this retro
  promoted it there — but the injection gap itself is a harness bug worth a
  human decision (adding `qa` to `always:` affects every dispatch, so it is
  not a change to make silently).
- `metrics.csv` — see above.
