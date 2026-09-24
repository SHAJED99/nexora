# Pending decisions — the register of everything waiting on a human

> **What this file is.** One place that names every decision, gate and manual
> action this project cannot move past without the human, with its owning gate
> key and the authoritative file that actually holds it. It is a *pointer*
> document: it decides nothing and duplicates nothing. Where it and the source
> disagree, **the source wins** and this file is stale.
>
> **What this file is not.** Not a plan, not a recommendation, and not a
> substitute for `spec/questions.md`, the ADRs or the task files — each item
> below links to the one place its answer belongs.
>
> Last reconciled against the tree on `development` = `da4459b`, 2026-09-24.
> Reconcile it again after any merge that closes one of these.

## Why it exists

Before this file, answering *"what is actually waiting on me?"* meant reading
`spec/questions.md`, both open-question blocks inside `E01-B01`, the
`human_gates` list in `harness.yaml`, the ADR headers, `CHANGELOG.md` §Known
gaps and `docs/release-readiness.md`, and then knowing which of them had gone
stale. Two ADR headers had: `ADR-0007` and `ADR-0008` both still read
"the **Decision** line stays `⏳ AWAITING HUMAN`" on 2026-09-24, long after
both decisions were taken and built. A reader — or a grep for that phrase —
came away with two pending decisions that were not pending at all. Both
headers were rewritten into the past tense in the same change that added this
file.

**That rewrite fixed the prose, not the grep.** Both headers still quote the
original wording once, because the record of how a decision was framed is
worth keeping — so the phrase count did not move, and could not have been
made to move without deleting the record:

```
$ grep -c "AWAITING HUMAN" agent/memory/decisions/ADR-0007-background-execution.md
1      # and 1 before the rewrite, too
```

**That grep was never a sound check.** It reads prose, and prose about a
decision is not the decision. The clearest evidence is that three of its five
hits across this directory are permanent boilerplate — `ADR-0000-template.md`
twice and `README.md` once — which no decision will ever clear, because they
are describing the convention rather than using it.

The sound check is the frontmatter, and it is the one in the recipe at the
bottom of this file:

```
$ grep -n "^status:" agent/memory/decisions/ADR-000[1-9]*.md | grep -v accepted
$ echo $?
1
```

No output means no ADR is pending, which is the state today: all eight are
`status: accepted`.

## The register

| # | Waiting on | Gate (`harness.yaml`) | Authoritative source | Blocks |
|---|---|---|---|---|
| 1 | Generate the release keystore, write `android/key.properties` | `secrets_or_env_change` | `docs/release-signing.md` §1–3; `OQ-E00-B01-1` in `epics/E00-genesis/tasks/E00-B01.md` | Every distributable artifact |
| 2 | Decide Play App Signing enrolment | `secrets_or_env_change` | `docs/release-signing.md` | Irreversible after the first upload |
| 3 | `OQ-E01-B01-1` — what *is* the pairing code? | rule 1 (spec silent) | `epics/E01-identity-access/tasks/E01-B01.md` | `E01-B01`, a **P2/must/S2** bug |
| 4 | `OQ-E01-B01-2` — how does the app notice identity arriving mid-session? | rule 3 (ADR-0005 area) | `epics/E01-identity-access/tasks/E01-B01.md` | `E01-B01`, the same bug |
| 5 | `Q-FUNC-011` — scope of "allow/disable communication" in `FR-TRUST-006` | rule 3 | `spec/questions.md` §Open questions | `PV28` on `design/screens/settings-privacy.md` only |
| 6 | Lift or keep the **E04 freeze** | — *(see the note below)* | a standing human instruction, not a repository state | 6 of 14 blocking orphans; 2 of 3 open bugs |
| 7 | Clear `dev_to_main_merge`, or descope the unmet preconditions | `dev_to_main_merge` | `harness.yaml` `human_gates`; `docs/release-readiness.md` | The release itself |
| 8 | Approve the three lesson promotions | `retro_promotions` | `make lessons`; `agent/memory/lessons/process.md` | `L-process-011`, `L-process-012`, `L-process-014` |

Items 1, 2 and 7 are the release path. Items 3 and 4 are one bug. Item 5 is
narrow. Item 6 is an epic. Item 8 is process, and is the only one of the eight
that does not stand between this project and a release.

### Manual actions that need no decision, only a human and hardware

| # | Action | Why an agent cannot do it |
|---|---|---|
| M1 | Walking-skeleton smoke check | `skills/release` step 4; needs two physical Android devices |
| M2 | Play Console setup, store listing, privacy policy, data-safety declaration | Account-bound, and none of them exist yet |
| M3 | Create and push `epic-00-done` | Computed and ready — the exact command is in `docs/release-readiness.md`. It is a shared ref whose anchor moved during the very session that computed it |

## Item detail, where the one-liner is not enough

### 1–2 · Signing and Play App Signing

`E00-B01` (PR #308) wired `android/app/build.gradle.kts` to read
`key.properties` when it exists and to fall back to the debug config when it
does not, so the build does not break before the key arrives. That fallback
also means **every artifact this project can currently build is debug-signed**:

```
$ apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
```

That output is the correct, expected result of having no keystore — it is not
a defect. `docs/release-signing.md` is the runbook, and it is written to be
executed by the human rather than by an agent: **no agent in this project may
generate, commit or invent a production key, a password or a
`key.properties`.** Play App Signing is listed separately because it is the one
choice here that cannot be revisited after the first upload.

### 3–4 · `E01-B01`'s two open questions

Both are documented in the task file with full evidence and the exact
architecture they touch; that file is the source and is worth reading rather
than summarising. In brief:

- **`OQ-E01-B01-1`** is a **spec gap**. `device_enrollment_view.dart` renders
  the string `'Code: [pairing code]'` literally, and
  `design/screens/device-enrollment.md` §Copy specifies exactly that string,
  under a heading that calls it "proposed copy". The implementation copied the
  contract faithfully; the contract never decided what the code *is*. There is
  no generator and no code field anywhere in `lib/features/recovery/`. Rule 1
  stops here.
- **`OQ-E01-B01-2`** is an **architecture call inside ADR-0005's area**.
  `lib/app/main.dart` reads `db.latestDeviceIdentity()` once at launch and
  collapses a missing identity to `selfDeviceId = ''`; `MessagingStack.create`
  then stamps `unavailable('no local device identity yet (sign in required)')`.
  `MessagingStackStatus` is a sealed immutable value with no stream and no
  notifier, and the stack is registered `permanent: true`. Fixing it means
  either rebuilding a permanent singleton graph mid-session or changing a
  sealed value class's contract. Rule 3 stops here.

### 6 · The E04 freeze is a session instruction, not a repository state

**This is worth knowing.** The freeze is honoured throughout this repository's
documentation — `CHANGELOG.md` §Known gaps and `docs/release-readiness.md`
both reason from it — but it is **not declared anywhere in the repository**.
`epics/E04-mesh-routing/epic.md` reads `status: in-progress`, and
`harness.yaml` has no gate key for it. It exists as a standing human
instruction given in session.

Nothing about that is wrong, and this file does **not** propose changing it:
declaring a freeze is the human's call, not an agent's. It is recorded here so
that a future reader who greps the repository for the freeze, finds nothing,
and concludes it was lifted, is instead pointed at this paragraph.

What the freeze currently holds, all read-only:

| Inside E04 | Count | Detail |
|---|---:|---|
| Blocking orphans | **6** | `E04-T03b`, `E04-T03c`, `E04-B35`, `E04-B36` (`done` tasks with no EARS test) plus `FR-ROUTE-005` and `FR-ROUTE-008` (requirements with no test) |
| Open bugs | 2 of 3 | `E04-B39` (**P2/must/S2**) and `E04-B38` (P3/should/S3) |
| `done` task files with no review recorded | 10 of 90 | see `docs/release-readiness.md` §The review record |
| `make health` H8 ⚠️ sites | 0 of 2 remain | both were E04-authored, and both were **false positives**; H8 itself was fixed rather than either file — see the note below |
| `EARS-ROUTE-004` test-name mismatch | 1 | the `make trace` "test matching no declared EARS id" orphan |

> **Correction, 2026-09-24 — and a correction of the correction.** This entry
> first said both H8 warnings were E04-owned and therefore frozen. It was then
> "corrected" to say `receive_message_use_case.dart:241` is *not* E04's. **That
> second claim was the wrong one**, and an independent review caught it:
>
> ```
> $ git blame -L 241,241 lib/features/messaging/domain/receive_message_use_case.dart
> dc0f05a  fix(E04-B26): file inbound 1:1 messages under this device's own
>          conversation id for an already-trusted sender (#259)
> ```
>
> and `grep -n receive_message_use_case epics/E04-mesh-routing/tasks/E04-B18.md`
> returns eight hits, of which the two that establish ownership are line 23
> (`required_context:`) and line 38 (`files.update:`); the other six are the
> test file and prose. *(That sentence replaced a `$`-prefixed transcript which
> had been trimmed to those two lines and annotated with comments the command
> never printed. A trimmed transcript presented as raw output is the same
> failure as a recalled count — if it is framed as command output it has to be
> the command's output.)*
>
> Both lines are E04-authored. The original ownership claim was right; the
> correction was an overreach — a file's directory is not its owner, and I read
> `lib/features/messaging/` and stopped there.
>
> What *was* genuinely wrong in the original is the part that mattered:
> **neither site is an unbounded id list.** `relay_engine.dart:488` feeds a
> `const` list of three enum values declared seven lines above it, and
> `receive_message_use_case.dart:241` feeds the literal
> `const ['trusted', 'allowed']` on the same line. Both were H8 false
> positives — H8 is explicitly a heuristic ("cannot prove a list is unbounded,
> only that no recognized chunking marker is nearby") and neither site carried
> a marker its regex knew.
>
> Because both are false positives, the fix was to **H8 itself**, not to either
> E04 file: no E04 implementation was touched and the freeze was not crossed.
> H8 now reads the `isIn` argument rather than the surrounding line.
>
> It was untracked when this register was written, and is now closed by that
> harness change. Kept here rather than deleted because the reasoning is the
> only record of *why* two warnings a reader might have acted on were safe to
> quiet — and because the ownership mistake above is worth leaving visible.

`E04-B35` is the one worth flagging: it was closed by **supersession** rather
than by delivering `EARS-TRANSPORT-4`, because it claims a behaviour the
platform appears to prevent. That is a real technical question sitting inside a
frozen epic, not a bookkeeping artefact.

## What is deliberately **not** on this list

Listed so that a reader does not go looking for a decision that was already
made, or add one that does not belong:

| Not pending | Why |
|---|---|
| `ADR-0007` (background execution) | **Decided** — option 1, foreground service. `status: accepted`; `E10-T08`, `E10-T09` and `E10-T10` are all `done`. Its own header said otherwise until 2026-09-24 |
| `ADR-0008` (cross-account visibility) | **Decided** — option 2, public device directory. `OQ-E11-1` reads 🟢 answered; built by `E11-T06`. Same stale header, same correction |
| `Q-SEC-009`, `Q-FUNC-010` | 🟢 answered on 2026-09-08 and fed into `E15-T01` |
| The 90 unrecorded reviews | Real debt, but **not a decision** — it is a forensic pass against 300+ PRs that nobody has been assigned. Backfilling it without evidence would manufacture the very record the gate exists to check |
| `EARS-SET-1`'s missing requirement citation | Not safely fixable: the only plausible link is `FR-TRUST-006`, which is itself decision-bound (item 5), so citing it would inflate that requirement's coverage on the strength of a guess |
| The `sentry_flutter` KGP build warning | A dependency upgrade — rule 6 forbids it inside a task and rule 3 gates it. Not a blocker today |
| CI release signing | Would put a keystore into repository secrets: its own `secrets_or_env_change` decision, worth making deliberately rather than by drift |

## Keeping this file honest

It is a register, so it is worth exactly what its last reconciliation is worth.
Re-derive it — do not edit it from memory:

```bash
grep -n "^status:" agent/memory/decisions/ADR-000[1-9]*.md | grep -v accepted
grep -n "Status:.*🟡" spec/questions.md          # open questions
grep -rn "Status:.*🟡" epics/*/tasks/*.md        # open questions inside tasks
make trace CHECK=1                              # blocking orphans
make lessons                                    # promotion candidates
sed -n '69,115p' harness.yaml                   # the declared gates
```

An item leaves this file when its source says it is answered — never before,
and never because the release would read better without it.
