# Release readiness — what is verified, and what is left

> Snapshot taken on `development` = `82b803d`, 2026-09-24. Every ✅ below was
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
| `make lessons` | ✅ | `30 lessons · 16 promoted · 2 awaiting` (was crashing before 2026-09-24) |
| `flutter build apk --release` | ✅ | `app-release.apk (62.5MB)`, exit 0, 147.6s cold |
| `flutter build appbundle --release` | ✅ | `app-release.aab (60.8MB)`, exit 0, 67.5s — **first ever run, 2026-09-24** |
| Release artifact is **distributable** | ❌ **no** | `apksigner` reports `CN=Android Debug`. No keystore exists. |

R8/minification is **not** a risk here: `isMinifyEnabled` is never set, so AGP
does not shrink. That was checked because it is the usual first-release
ambush; it is not one for this project.

## The review record has a hole in it, and it is large

`skills/release` requires every task PR to have passed the review gate
(rule 5, `reviewed_by` != `executed_by`). The task files are where that is
recorded. Counted across all 230 `done`/`verified` task files on `82b803d`:

| | Count |
|---|---:|
| carry **both** `reviewed_by` and `review_outcome` | 140 |
| carry **neither** | **90** |
| carry only one of the two | 0 |

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
8. **`epic-00-done` tag** — E00 is complete, retro'd and merged; only the tag
   is absent. E01/E04's tags wait on their open P2s.

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
