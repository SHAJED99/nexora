# Product-completeness audit — 2026-09-24

> **Why this file exists.** The project's objective changed on 2026-09-24:
> the release track (keystore, Play App Signing, Play Console, store listing,
> data safety, `dev_to_main_merge`) is **paused**, and the critical path is now
> *"make Nexora a complete, usable product"*. Release work already done stays
> intact; it is simply no longer what we optimise for.
>
> This audit answers one question — **what does a person actually not have
> yet?** — and it deliberately does not trust `status: done`. Every claim below
> is a command run against `development` = `e85aae4` at the moment of writing.

## The headline

`233 tasks, 227 done` and `flutter analyze` clean. **Neither number measures
the product.** The repository is in good health; the *application* is missing
whole user-facing surfaces, and the task ledger cannot see it, because the
missing work was never sharded into tasks at all.

Concretely: **groups and calls have complete backends and no user interface**,
and **three of the chat screen's four approved derived contracts are
unimplemented**. A person installing this build today cannot create a group,
manage a group, place a call, send a voice note, send an attachment, or share
a location — regardless of what any task file says.

## Evidence

### 1. The application's entire reachable surface

`lib/app/routes.dart` registers **19 routes**. There is no `/groups/new`, no
`/groups/:id`, and no call route. `docs/routes.md`'s table lists the same 19.

```
$ for d in lib/features/*/; do [ -d "$d/presentation" ] && echo "UI   $(basename $d)" || echo "NOUI $(basename $d)"; done
UI   chat          UI   conversations   UI   dashboard   UI   devices
NOUI groups        UI   home            NOUI location    UI   login
NOUI messaging     UI   recovery        UI   settings    NOUI trust
UI   version       UI   welcome
```

`location`, `trust` and `messaging` are **not** gaps — each is a backend whose
surface lives in another feature (`devices`, `settings/privacy`,
`conversations`, `chat`), confirmed by grepping their importers. **`groups` is
a gap**: it has `data/` and `domain/` only — `group_repository`,
`group_membership_service`, `group_key_rotation_service`,
`send_group_message_use_case`, `group_permissions` — and nothing that renders.

### 2. Six approved design contracts that no task builds

`make trace` reports this as an orphan class (`design contract no task builds — 10`).
Four of those ten are **bookkeeping only** — `login`, `welcome`,
`sign-out-confirm` and `settings-battery` are built and routed; their task
files simply never declared `design_contract:`. The orphan class over-reports,
and that distinction matters: it is the difference between a documentation fix
and missing software.

The other six are real, and all six are **approved** in `design/gaps.md`:

| Contract | `impl_path` | Backend | UI | Blocks the journey step |
|---|---|---|---|---|
| `group-create.md` | `/groups/new` | ✅ complete | ❌ none | *use groups* |
| `group-manage.md` | `/groups/:id` | ✅ complete | ❌ none | *use groups* |
| `call.md` | *(unrouted)* | ✅ `lib/core/calls/` | ❌ none | *use voice/PTT/calls* |
| `chat-voice.md` | `/chat/[id]` | — | ❌ none | *use voice/PTT/calls* |
| `chat-attachment.md` | `/chat/[id]` | — | ❌ none | *use core messaging* |
| `chat-location.md` | `/chat/[id]` | — | ❌ none | *use location features* |

The three `chat-*` contracts are states **within** the chat screen.
`chat_view.dart` (572 lines) and `chat_controller.dart` (491 lines) contain no
recording, picker or location affordance; the only `record` matches are
`StorageAccessRecorder`, which is unrelated.

**How this happened, precisely.** `E07-T12` and `E07-T13` are `layer: docs`
tasks. They *wrote the contracts* and were correctly marked done. E07 carries
exactly **two** `layer: frontend` entries, and neither builds a new screen:
`E07-T08` (the conversations screen) and `E07-B01` (a bug — a group row's tap
landed on the 1:1 `ChatController`, fixed inside `conversations_*`). No build
task was ever created for the screens T12/T13 contracted, and E07 then closed
as `status: done`. Nothing lied; the sharding was incomplete, and a `done`
epic has no mechanism that notices.

### 3. Two baselined requirements with no implementation at all

From `make trace`'s `requirement with no test — 10`, these two are neither
blocked nor decision-bound:

- **`FR-UI-005`** — *"All visible strings shall come from localization
  resources; the UI shall support RTL layout."* There is **no `lib/l10n/`, no
  `l10n.yaml`, and no `flutter_localizations` dependency.** Every string in all
  19 views is a literal. Not partially done — absent.
- **`FR-UI-003`** — *"Navigation shall adapt by width class — NavigationBar
  (compact), NavigationRail (medium), NavigationDrawer (expanded)."*

```
$ grep -rln "BottomNavigation\|TabBar\|NavigationBar\|NavigationRail\|IndexedStack" lib --include=*.dart
(no matches)
```

There is no navigation chrome of any kind. `dashboard_view.dart` navigates by
`Get.toNamed` from tapped rows. **`FR-UI-003` also has no design source** —
all 26 contracts declare `viewports: [390x844]`, a single compact width, and
`dashboard.md` draws no nav bar, rail or drawer. This is the one finding in
this audit that is a genuine spec-vs-design conflict rather than missing work,
and it is listed as a decision below rather than as a task.

The remaining eight untested requirements are each already accounted for:
`FR-BLOCK-002/003` depend on the group surface; `FR-STORE-002/003` depend on
voice notes; `FR-ROUTE-005/008` are E04, frozen; `FR-TRUST-002` is reinstall
behaviour; `FR-TRUST-006` is `Q-FUNC-011`, the one open question on file.

### 4. What is *not* wrong

Stated plainly, because an audit that only reports faults miscalibrates:

- `flutter analyze` — **No issues found** (5.0s).
- `make validate` — `16 epics, 233 tasks — DAG OK`.
- `make health` — H1–H4 and H8 pass; H5/H6/H7 are the known human-gated checks.
- `make health-selftest` — all pass.
- Open bugs: **three**, and only three — `E01-B01` (P2, two human OQs),
  `E04-B38` (P3) and `E04-B39` (P2), the latter two frozen.
- Open questions: **one** — `Q-FUNC-011`.
- Pending ADRs: **zero** (`grep "^status:" …ADR-000[1-9]*.md | grep -v accepted`
  returns nothing).

The backends behind every missing screen are built, reviewed and merged. This
is a **presentation-layer gap**, which is the cheapest kind to be left with.

## The work, in journey order

Ordered by the user journey this unblocks, not by epic number.

| # | Work | Contract | Human decision needed first? |
|---|---|---|---|
| P1 | Group create screen | `group-create.md` | **No** — entry point deferred, see D1 |
| P2 | Group manage screen | `group-manage.md` | **No** — contract has no open items |
| P3 | Voice notes in chat | `chat-voice.md` | **No** |
| P4 | Attachments in chat | `chat-attachment.md` | **No** |
| P5 | Location sharing in chat | `chat-location.md` | **No** |
| P6 | Call screen | `call.md` | **No** — three cosmetic items, fallbacks specified |
| P7 | Localization + RTL (`FR-UI-005`) | — | **No** |
| P8 | Adaptive navigation (`FR-UI-003`) | *none exists* | **Yes — D2** |

**Seven of the eight need no decision from anyone.** `group-manage.md`,
`chat-voice.md`, `chat-attachment.md` and `chat-location.md` carry no `## Open`
section at all. `group-create.md` and `call.md` each carry one, and **both
contracts explicitly specify what ships until the human answers** — so neither
blocks a build task.

## Decisions genuinely required

Only these. Everything else above proceeds without you.

### D1 — the create-group entry point *(smallest possible)*

`group-create.md` §Open asks one question: may a `48×48` `add` icon-button be
added to `conversations.md`'s header? Until answered, **`/groups/new` is
reachable only by direct navigation** — so groups are buildable but not
*discoverable*. The contract proposes exactly one option and records the two
alternatives it rejected (a FAB — no FAB primitive exists in any of the 26
contracts; and a row inside the Groups list — it would read as a group).
Approving it makes `make design-verify SCREEN=conversations` report one extra
element, which the reviewer traces to this gaps entry. **That cost is the whole
decision.**

### D2 — `FR-UI-003`, adaptive navigation

The requirement says navigation adapts across three width classes. The design
measures one width and draws no navigation chrome. Rule 2 says the spec wins
over the design, so the requirement stands and the design is incomplete —
which means implementing it requires **inventing** navigation the design never
measured, exactly what rule 2 forbids doing silently. Two honest options:
**(a)** descope `FR-UI-003` the way `FR-TRUST-007` was descoped via `IMP-002`
(id retained, never deleted); or **(b)** commission medium/expanded contracts
and shard against them. This is a product call, not an engineering one, and
I am not making it.

### D3 — `call.md`'s three cosmetic items *(non-blocking)*

Destructive-action colour (fallback **(b)**, ships until answered), three glyph
names, two copy strings. Recorded so they are not lost; the call screen is
built against the fallbacks meanwhile.

### Unchanged from before this audit

`Q-FUNC-011` · `E01-B01`'s `OQ-E01-B01-1`/`-2` · lift or keep the **E04 freeze**
· the four `retro_promotions` candidates. All remain exactly as
`docs/pending-decisions.md` records them; this audit moved none of them.

## What this audit did not touch

- **E04 is frozen and was read only.** Its two open bugs, its four
  `done`-with-no-EARS-test orphans (`E04-B35`, `E04-B36`, `E04-T03b`,
  `E04-T03c`) and its 6 blocking orphans are inventoried, unmodified.
- **The 14 blocking-orphan count is unchanged**, and nothing here was written
  to move it. Several items above *will* move it honestly once built.
- **No requirement, EARS criterion, ADR or design contract was edited.**
- The release-track documents (`docs/release-readiness.md`,
  `docs/release-signing.md`) are left intact and simply no longer the
  critical path.

---

# Addendum — 2026-09-24, after building P1

> Written after `E07-T15` shipped `/groups/new` (PR #325). Building the first
> item taught four things the audit above could not know, and they **move four
> of the eight work items into the "needs a decision" column** — P2, P3, P4 and
> P6. Recorded here rather than silently revising the table, so the change is
> visible. One item moved the other way: P7 was over-gated in this addendum's
> own first draft and is buildable now.

## P1 is done

`/groups/new` exists: controller, view, binding, route, 11 EARS-named tests
against a real in-memory database, and a green design gate. `flutter analyze`
clean, 1605 tests pass. Reviewed on a different model (rule 5), no findings.

**It is not reachable from anywhere in the app.** That is deliberate and is
decision **D1** — see below, which now blocks more than it did.

## The four new findings

### 1. Voice, attachments and calls need **new dependencies** — rule 3

`pubspec.yaml` has `geolocator`, `cryptography`, `libsignal_protocol_dart`,
`sentry_flutter`, `in_app_update` and `package_info_plus` — and **no audio
capture/playback package and no file or image picker.**

So P3 (`chat-voice`), P4 (`chat-attachment`) and P6 (`call`) each require a
`new_dependency` decision, which rule 3 reserves to the human and
`docs/conventions.md` records a consistent procedure for. The audit's table
above said "no decision needed" for all three. **That was wrong** — it checked
the design contracts for open questions and did not check what the code would
have to import.

**The same shallow check also mis-cleared P2.** `group-manage.md` has no
`## Open` section, so the audit called it unblocked; finding 2 below shows it
is blocked for a different reason the contract could not state. So **four**
items move to the decision column, not three — P2, P3, P4 and P6 — and the
root cause is one mistake, not two: reading a contract's open questions and
treating their absence as proof that nothing else stands in the way.

**`FR-UI-005` is *not* one of them.** An earlier draft of this addendum listed
P7 as needing `intl`. That was over-gating, caught in review. FR-UI-005's text
is *"All visible strings shall come from localization resources; the UI shall
support RTL layout via logical (not literal left/right) padding"* — no
pluralization, no date or number formatting, which are the only things `intl`
adds over the SDK. A string table plus `Directionality` and
`EdgeInsetsDirectional`, both core Flutter, satisfy it with **no new package
at all**. P7 is buildable now.

Precedent for how these get decided: every dependency in `pubspec.yaml` carries
an inline comment naming the task, the question id, the human approval date,
and why it is pinned exactly rather than by caret range.

### 2. `group-manage` has no entry point — and unlike `group-create`, nobody has proposed one

`design/screens/group-manage.md` has **no `## Open` section and no
"Reached from" line.** It is fully specified and fully buildable, and building
it would produce a *second* screen reachable only by direct navigation.

`group-create` at least has a proposal on the table (D1). `group-manage` has
nothing: the natural entry — a group conversation's header in `chat.md` —
is not drawn, not derived, and not in `design/gaps.md`. It needs a new gap
entry before it has an approved way in.

**This is why P2 was not built next.** It is not blocked as *code*; it is
blocked as *product*, and building it would have converted a real gap into a
hidden one.

### 3. The rule-2 gate could not run at all

`node_modules/` existed in this checkout and was **empty**. Every
`make design-verify` invocation failed with
`Cannot find package 'yaml' imported from design/tools/lib/config.mjs` before
reaching a single comparison. Installing the already-declared `yaml` package
fixed it.

The gate that enforces rule 2 was silently unrunnable, and nothing reports
that: `make design-verify` is not in CI (the `harness` job runs `validate`,
`lessons`, `health-selftest` and `trace`), so an unrunnable design gate looks
exactly like a design gate nobody happened to run. Worth a checked-in fix —
either a CI step or a preflight in the Makefile target.

### 4. A derived screen's first design gate proves less than it appears to

For a screen with `source: derived` there is no design source to extract a
golden from, so `design-fidelity` §3's instruction is to extract the golden
**from the build**. `make design-verify` then compares the build against a
golden taken from that same build, and reports `match 100%`.

That number is a **regression baseline for future changes**, not evidence that
the first build honours its contract. On `E07-T15` the actual fidelity check
was the reviewer reading `group-create.md` against the code and grepping all
nine colour constants back to the parent contract that measures each one. Any
future derived screen should expect the same: the green is necessary and not
sufficient, and the PR should say so rather than letting the percentage speak.

## The decision table, corrected

| # | Work | Blocked by |
|---|---|---|
| ~~P1~~ | ~~Group create screen~~ | **done** — PR #325 |
| P2 | Group manage screen | a gap entry + entry-point approval (new) |
| P3 | Voice notes in chat | **`new_dependency`** — audio capture/playback |
| P4 | Attachments in chat | **`new_dependency`** — file/image picker |
| P5 | Location sharing in chat | a location message kind in the messaging layer |
| P6 | Call screen | **`new_dependency`** + D3's three cosmetic items |
| P7 | Localization + RTL (`FR-UI-005`) | **nothing — buildable now** |
| P8 | Adaptive navigation (`FR-UI-003`) | **D2** — spec vs design |

**Five of the eight need a decision from you** — P2, P3, P4, P6, and P8. Only
the first four moved here because of this addendum; **P8 was already in this
column**, placed there by the original audit as **D2**.

**Two are engineering work that needs nobody.** P5 is blocked by a missing
location message kind in the messaging layer — a real gap, but not a rule-3
call. P7 needs no dependency and no decision. P1 is done.

That correction matters more than the finding it replaces. The first draft of
this table said *every* remaining item needed a human, which is the conclusion
that costs an agent the least work — and two of the eight did not survive
review of that claim.

D1 also grew: approving the `conversations.md` header affordance is now what
makes an *already-built and merged* screen reachable, rather than what unblocks
a future one.
