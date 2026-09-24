# Release readiness — what is verified, and what is left

> Snapshot first taken on `development` = `82b803d`, 2026-09-24; the counts
> marked **re-verified** below were re-run on `da4459b` the same day. The
> six merges in between (`b9206b2`, `533ed09`, `f689ebf`, `4dd1fe2`,
> `b5fc966`, `da4459b`) touched documentation, task/epic metadata and one
> harness check (`agent/orchestrator/health.py`) — `git diff --name-only
> 82b803d da4459b` lists no file under `lib/` or `test/`, so the build and
> test evidence below still describes this tree. Every ✅ below was
> executed, not reasoned about; the command and its output are quoted. Every ❌
> names the gate that owns it. Nothing here is a plan — it is the current
> state of `skills/release`'s own preconditions.
>
> Re-run the checks rather than trusting this file: a readiness snapshot is
> stale the moment anything merges.

## `skills/release` preconditions, item by item

| Precondition | State | Evidence |
|---|---|---|
| Target epics merged to `development` | ⚠️ partial | 14 of 16 epics fully closed. E01 and E04 each carry one open `P2 must` bug. |
| P1/P2 bugs at **zero** | ❌ **no** | Two open: `E01-B01` (P2, Rule-3 blocked) and `E04-B39` (P2, E04 freeze). |
| *(all open bugs, for completeness)* | — | Three, not two: the two P2s above plus `E04-B38` (P3 / should / S3, E04 freeze). `E04-B38` does not affect this gate, which counts P1/P2 only — listed so the snapshot is a complete statement of open work rather than only of blocking work. |
| Each epic has its sweep + retro | ✅ yes | All 16 retros exist (`make health` H3 passes). |
| Each epic has an `epic-<n>-done` tag | ❌ **no** | 13 of 16. Missing: `epic-00-done`, `epic-01-done`, `epic-04-done`. |
| `make trace` blocking orphan classes **empty** | ❌ **no** | 14 blocking orphans. All decision- or freeze-bound — see `CHANGELOG.md` §Known gaps. |
| CI green on `development` | ✅ yes | `analyze, test, build (Android debug)` passing. |
| 🧍 `dev_to_main_merge` | ❌ **human-only** | Never delegated. `harness.yaml` `human_gates`. |

**Read this honestly:** four of the seven preconditions are not met, and every
one of them is blocked behind a gate an agent may not clear. Shipping over them
is a deliberate human descope — exactly the decision `v0.1.0` recorded on
2026-09-06 for its own seven open bugs. That is a legitimate, precedented
option. It is not the same as being ready.

## Build and artifact checks

| Check | State | Evidence |
|---|---|---|
| `flutter analyze` | ✅ | `No issues found!` (53.2s) |
| `flutter test` | ✅ | `1593/1593`, 153 test files |
| `make validate` | ✅ | `16 epics, 233 tasks — DAG OK` |
| `make lessons` | ✅ | `30 lessons · 16 promoted · 3 awaiting promotion` (was crashing before 2026-09-24) **re-verified on `da4459b`** — the third candidate is `L-process-014`, written later the same day |
| `flutter build apk --release` | ✅ | `app-release.apk (62.5MB)`, exit 0, 147.6s cold |
| `flutter build appbundle --release` | ✅ | `app-release.aab (60.8MB)`, exit 0, 67.5s — **first ever run, 2026-09-24** |
| Release artifact is **distributable** | ❌ **no** | `apksigner` reports `CN=Android Debug`. No keystore exists. |

R8/minification is **not** a risk here: `isMinifyEnabled` is never set, so AGP
does not shrink. That was checked because it is the usual first-release
ambush; it is not one for this project.

## The review record has a hole in it, and it is large

`skills/release` requires every task PR to have passed the review gate
(rule 5, `reviewed_by` != `executed_by`). The task files are where that is
recorded. Counted across all 230 `done`/`verified` task files, **re-verified**
on `da4459b`:

| | Count |
|---|---:|
| both `reviewed_by` and `review_outcome` carry a **value** | 140 |
| **neither carries a value** | **90** |
| — of those, the two keys are **absent entirely** | 67 |
| — of those, the two keys are **present but empty** | 23 |
| only one of the two carries a value | 0 |

Count the *values*, not the keys: a bare `reviewed_by:` with nothing after
it records nothing, and 23 files are in exactly that state. A scan that
tests only for key presence reports 163/67 and understates the hole by 23.

Of the 90, ten are inside E04 (frozen) and eighty are not. The split is clean —
there is no task with a reviewer recorded but no outcome, or vice versa — which
says this is a *template* gap rather than sloppy filling-in: the bug file shape
that `skills/bug-sweep` produces has no review fields at all, so a sweep-authored
bug can reach `done` without any slot to record a review in.

**This has deliberately not been "fixed".** Writing `review_outcome: APPROVE`
into 90 files would manufacture evidence for reviews that may never have
happened. Spot-checking says the risk is real: `E09-B02` records a
`## Self-review` section and "Merged into `epic_09` via PR #48" — a self-review
is not rule 5's independent review, and stamping it APPROVE would convert an
honest gap into a false record. `make health`'s H5 and H7 already report every
one of these; that report is the truth and should stay legible.

What it means for the release: **the project cannot currently demonstrate, from
its own records, that 90 of its 230 completed tasks passed an independent
review.** They may well have — PR history exists for most — but the task files
do not say so, and reconstructing it means a per-file forensic pass against 300+
PRs. That is real work, it is not blocked on any human decision, and it is the
largest single piece of unowned release-gate debt in the repository.

The durable fix is upstream: `skills/bug-sweep`'s bug template needs the three
review fields, which is a skill edit and therefore the 🧍 `retro_promotions`
gate. Compare `L-process-011` and `L-process-012`, both of which are already
promotion candidates for template gaps in exactly this file.

## What stands between here and a signed, distributable release

> Every item below that needs a human is also listed, with its owning gate
> and its authoritative source, in **`docs/pending-decisions.md`**. That file
> is the register; this section is the release-shaped view of it.

Ordered by who owns it.

### Owned by the human — nothing can proceed without these

1. **Generate the release keystore** and write `android/key.properties`.
   `secrets_or_env_change` gate, `OQ-E00-B01-1`. Procedure:
   `docs/release-signing.md`. **Until this exists every artifact this project
   can build is debug-signed and cannot be uploaded.**
2. **Decide Play App Signing enrolment** — it determines whether a lost upload
   key is recoverable at all, and it is irreversible after the first upload.
3. **Clear `dev_to_main_merge`**, or explicitly descope the four unmet
   preconditions above into Known gaps the way `v0.1.0` did.
4. **`E01-B01`'s two open questions** — `OQ-E01-B01-1` (the pairing-code
   scheme is a spec gap, rule 1) and `OQ-E01-B01-2` (mid-session identity
   recovery is an ADR-0005 architecture call, rule 3).
5. **Lift or keep the E04 freeze** — it owns 6 of the 14 blocking orphans and
   one of the two open P2s.

### Not owned by anyone yet — real work, no decision needed first

6. **Play Console setup, store listing, privacy policy, data-safety
   declaration.** None exist. For an app requesting Bluetooth scanning,
   background location and running its own E2E crypto, the data-safety form is
   substantive and its review latency is outside anyone's control.
7. **Walking-skeleton smoke check on hardware**, per `skills/release` step 4.
   Requires two physical Android devices. Cannot be done in CI.
8. **`epic-00-done` tag — computed, ready to create, deliberately not created
   by an agent.** The other thirteen `epic-<n>-done` tags were **back-filled on
   2026-09-22** under a documented rule, quoted from `epic-02-done`'s own
   annotation: *"the commit from which every task in the epic is `done` and
   stays done through to `development` HEAD (computed, not asserted) … The
   epic's original merge predates this commit where a later bug re-opened work;
   this anchor is the honest 'complete and stayed complete' point."*

   Applying that rule to E00 gives an answer that is **not** the 2026-08-26
   close-out (`84535cb`). E00 acquired a bug after that date — `E00-B01`, the
   debug-signing defect — and the rule anchors on when the epic became and
   stayed complete. `E00-B01` reached `done` when PR #308 merged, so:

   ```bash
   git tag -a epic-00-done 82b803d -m "E00 Genesis complete -- 7 tasks + 1 bug, all done, P1/P2=0.

   Back-filled 2026-09-24 under the same computed rule as epic-02..15-done:
   the commit from which every task in the epic is done and stays done through
   to development HEAD. E00's original close-out (84535cb, 2026-08-26) predates
   E00-B01, a later bug that re-opened work; 82b803d is the honest
   'complete and stayed complete' point. Retro: epics/E00-genesis/retro.md."
   git push origin epic-00-done
   ```

   The "7 tasks + 1 bug" in that annotation is **not** countable from
   `epics/E00-genesis/tasks/`, which holds only `E00-B01.md` — E00 predates
   the per-task-file convention, so its seven tasks live only as rows in
   `epics/E00-genesis/epic.md` (`E00-T00` … `E00-T06`, all ✅ done) and in
   `epics/E00-genesis/tracker.md`. Verify there, not in `tasks/`. A reviewer
   flagged this as unverifiable, which it was — hence this note.

   Left for the human to run: tags are shared refs and part of the release
   ceremony, and this one's anchor moved because of a task filed during the
   same session that computed it. That is exactly the situation where an agent
   should show its work rather than push the ref.

   `epic-01-done` and `epic-04-done` cannot be computed yet — both epics have
   an open bug, so neither has a "stayed complete" point.

### Deliberately out of scope

9. **CI release signing.** Would mean putting a keystore into repository
   secrets — its own `secrets_or_env_change` decision, worth making
   deliberately rather than by drift. CI builds `--debug` only today.
10. **The `sentry_flutter` KGP warning.** Every release build prints *"Future
    versions of Flutter will fail to build if your app uses plugins that apply
    KGP."* Not a blocker now; fixing it means a dependency upgrade, which rule 6
    forbids inside a task and rule 3 gates.

## The shortest honest path

If the keystore appears, the sequence is: write `key.properties` → `flutter
build appbundle --release` → `apksigner verify --print-certs` and confirm the
DN is yours → smoke the walking skeleton on hardware → clear
`dev_to_main_merge` → merge → annotated tag → upload.

Steps 1 and 3 of that list are the only ones that have never been executed
end to end. Everything else in it has been run and is green.
