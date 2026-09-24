# Changelog

All notable changes to Nexora are recorded here.

`skills/release` names this file as where **Known gaps** live: orphans and
defects that are knowingly shipped belong here, in the open, rather than being
quietly cleared to make a gate look green. Until now that list existed only
inside annotated tag messages (`git tag -n v0.1.0`), where nothing links to it.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions are the annotated tags on `main`.

---

## [Unreleased]

Everything below is merged into `development` and has **not** been released.
`development` is 200 commits ahead of `main` as of `cc87871` (2026-09-24).

### Added
- **Session lifecycle and settings sub-screens (E15, whole epic).** Sign-out
  with a full local data wipe and an explicit destructive confirmation
  (`FR-AUTH-006`–`FR-AUTH-009`); session-aware launch routing that sends a
  returning device straight to the dashboard, subordinate to the mandatory
  update gate (`FR-AUTH-010`–`FR-AUTH-012`); and eight settings screens —
  Account, Privacy & Security, Security Center, Notifications, Network,
  Battery, Storage, About/Updates — behind a Settings hub.
- **Message button on Devices rows** — start a conversation with an
  already-trusted device (`E06-T14`, GAP-030).
- **Version-policy signature verification** — the cached version policy is
  checked against a build-time-embedded Ed25519 public key before it is
  trusted, fail-closed (`E14-T03`). This closes the one task `v0.1.0` shipped
  as explicitly unbuilt.
- **Nexora-specific Bluetooth SDP UUID**, advertised and filtered on, so
  Discover lists only devices actually running Nexora (`E04-T06`, `E04-T07`).
- **`make trace`** — the requirement → task → test traceability generator and
  its orphan report (`docs/traceability.md`).
- **Release signing configuration** — release builds read
  `android/key.properties` when present instead of signing with the Android
  debug key, falling back to the debug key when absent so CI and fresh clones
  are unaffected (`E00-B01`, PR #308). See **Known gaps** below: the keystore
  itself does not exist, so every build this project can currently produce is
  still debug-signed.

### Fixed
53 fixes, the substantial ones being in Bluetooth transport and link lifecycle
(E04), version management (E14) and personal chat (E06). Notable:
- Connections are established before sending, rather than sending into a
  socket nothing ever opened (`E04-B05`).
- A message's plaintext is resolved once and never decrypted twice
  (`E06-T10`/`E06-T11`, `NFR-PERF-001`).

### Changed
- Traceability and documentation hygiene: stale epic-table status cells synced
  with their task files, invalid traceability records repaired, and previously
  untested criteria made visible to the gate (PRs #303–#307).
- Three stale project-state fields corrected (PR #310): `lifecycle_stage` read
  `pre-genesis`, which was both false and absent from its own schema enum; E10
  advertised a merge that had already happened; E15 claimed a retro that
  existed. All three are mirror fields the validator never checked.
- Five epic `status:` values made machine-readable (PR #313). E10–E14 carried
  their summary as a parenthetical, so `yaml.safe_load` returned the whole
  string and `scheduler.py:235`'s membership test read them as **not done** —
  silently blocking any future task that depended on them. Moved behind a `#`,
  as E15 already did. No summary text lost.
- `spec/questions.md`'s summary table recounted (PR #311): it reported four open
  important questions against eleven on file, totalling ten. One is open.

### Added (tooling)
- **`docs/pending-decisions.md`** — one register naming every decision, gate
  and manual action waiting on the human, each with the authoritative file that
  holds it and, where one applies, its `harness.yaml` gate key. Four of the
  eight items are held by a declared gate; three by a rule; and the E04
  freeze by a standing instruction that the repository does not declare at
  all. It decides nothing and duplicates nothing; where it and a source
  disagree, the source wins (PR #315).
- **`make health-selftest`** — 20 executable fixtures proving H8 still rejects
  every shape it has ever wrongly exempted, plus both directions on each
  allowlist entry. Stdlib-only, so no new dependency (PR #318).

### Fixed (tooling)
- **`make lessons` ran on nothing** — it crashed on every invocation, because
  `lessons.py:49` calls `int()` on `recurrence:` and three lessons carried
  `**2**` or `3+` (PR #309). Fixed in the data; all other lessons already used a
  bare integer.
- **`make health` H4 reported a false negative** — its regex accepted a scope
  fence numbered `4.` or unnumbered, but five task files number theirs `3.`, so
  a present, properly filled fence read as absent (PR #312).
- **`make health` H8 exempted unbounded lists while repairing its own false
  positives** — two provably bounded `const` call sites warned permanently, and
  three successive attempts to exempt them each silenced a genuinely unbounded
  one: a per-line exemption, then the raw-SQL branch, then a `const` literal
  *head* with an unbounded tail. Escalated to the planner per
  `skills/review:120` and fixed by closing the exemption's input space rather
  than widening it (PR #316). The episode is `L-infra-004`.
- **Three lessons were written and never committed** — `L-backend-006`,
  `L-infra-003` and `L-qa-002` sat uncommitted in a retro worktree from
  2026-09-04 while the same session's process lessons landed. Recovered
  verbatim (PR #317).
- **Two ADR headers still read `AWAITING HUMAN`** — `ADR-0007` and `ADR-0008`
  were both `status: accepted` with a chosen option and shipped tasks, but
  their proposal-time blockquotes had never been rewritten (PR #315).
- **Release signing is wired but unkeyed** — see Known gaps.

---

## Known gaps

Carried knowingly, per `skills/release`. Nothing here has been descoped,
reworded or deleted to make a gate pass.

### Requirements with no test — 10 (blocking orphans)

`make trace` reports **113 requirements, 102 reaching a test (90.3%), and 14
blocking orphans** (verified on `82b803d`, 2026-09-24). Ten of the fourteen are
requirements that own no EARS criterion and therefore no test. Each is blocked
on a decision that has not been made, not on engineering effort:

| Requirement | What is undecided |
|---|---|
| `FR-BLOCK-002`, `FR-BLOCK-003` | how a blocked group member is denied the group crypto material while remaining a member — a Sender-Keys rotation design (rule 3) |
| `FR-STORE-002`, `FR-STORE-003` | voice/PTT/call recordings and the default voice profile; needs an audio dependency, itself a rule-3 `new_dependency` gate |
| `FR-TRUST-002` | what survives reinstall, given `FR-AUTH-008` says a new install is indistinguishable from a first-ever one |
| `FR-TRUST-006` | four of its six configurable rules have no surface; `GAP-044` scopes them, `Q-FUNC-011` blocks one element |
| `FR-UI-003` | the three responsive navigation width-class breakpoints |
| `FR-UI-005` | whether v1 commits to localization and RTL, and to which locales |
| `FR-ROUTE-005`, `FR-ROUTE-008` | inside the E04 freeze (below) |

### `done` tasks with no EARS test — 4 (blocking orphans)

`E04-T03b`, `E04-T03c`, `E04-B35`, `E04-B36` — all inside the E04 freeze.
`E04-B35` was closed by **supersession** rather than by delivering
`EARS-TRANSPORT-4`: it claims a behaviour the platform appears to prevent.

### Open defects — 3

| Bug | Priority | Status |
|---|---|---|
| `E01-B01` | **P2 / must / S2** | Cold-start onboarding shows a literal `[pairing code]` placeholder, and "Continue without history" lands on a stale error that only a restart clears. Root-caused to `lib/app/main.dart:98-110` — the identity is read once at launch and the whole `MessagingStack` is then built with an empty `selfDeviceId`. Fixing it means rebuilding the permanent singleton graph mid-session or changing a sealed value class's contract: an ADR-0005 architecture decision (rule 3), open as `OQ-E01-B01-2`. The pairing-code scheme itself is a spec gap (rule 1), open as `OQ-E01-B01-1`. |
| `E04-B39` | **P2 / must / S2** | Unverified whether `E04-B36`'s teardown leaves a healthy idle link alone; the 3-minute idle check has never been run. Inside the E04 freeze. |
| `E04-B38` | P3 / should / S3 | A peer going out of range produces no platform signal, so the link is never declared dead. Not yet reproduced on hardware. Inside the E04 freeze. |

> `skills/release` lists **P1/P2 bugs at zero** among its preconditions. Two P2
> bugs are open, and both are behind gates no agent may clear — one a rule-3
> architecture decision, one the E04 freeze. Releasing over them is therefore
> an explicit human descope decision, the same one `v0.1.0` made on 2026-09-06
> for its seven open bugs. It is recorded here rather than resolved quietly.

### Release infrastructure

- **No keystore exists.** `E00-B01` wired the build to read
  `android/key.properties`, but generating the signing key is a
  `secrets_or_env_change` human gate (`OQ-E00-B01-1`). Until it exists, every
  release build is signed with the Android debug key and is **not
  distributable**. See `docs/release-signing.md`.
- **No Play Console setup, store listing, privacy policy or data-safety
  declaration.** For an app that requests Bluetooth scanning, background
  location and runs its own E2E crypto, the data-safety declaration is not a
  formality.
- **CI builds `--debug` only** and has no release job.
- **Three `epic-<n>-done` tags are missing** — `epic-00-done`,
  `epic-01-done` and `epic-04-done`. E01 and E04 are genuinely not closed
  (one open P2 bug each); E00 is complete and its tag is simply absent.
  `skills/release` lists an `epic-<n>-done` tag per included epic among its
  preconditions.

### Open questions

One question is open and deliberately undecided: **`Q-FUNC-011`** —
whether `FR-TRUST-006`'s "allow/disable communication" governs only new
connection requests or existing conversations too. It blocks exactly one design
element (`PV28` on `design/screens/settings-privacy.md`) and nothing else.

Two questions are closed by recorded assumption rather than by answer:
`Q-BIZ-007` → `A-001` (no monetization model), `Q-SCOPE-008` → `A-002` (no
numeric ceiling on group size or relay hop count).

### Not covered by tests

- 24 EARS criteria are asserted but have no test, including all nine
  `EARS-TRANSPORT-*` and `EARS-PLAT-1`–`4`. These are not release blockers
  under `skills/release`, which gates on the four blocking orphan classes only.
- 10 design contracts have no task that builds them, including `call.md`,
  `chat-voice.md`, `group-create.md` and `group-manage.md`. Two of the ten —
  `welcome.md` and `login.md` — *are* built; those two are a `design_contract:`
  declaration gap rather than unbuilt screens.
- There is no integration or end-to-end suite. `flutter test` covers 1593 unit
  and widget tests across 153 files; the walking-skeleton check is manual, on
  hardware.

---

## [0.1.0] — 2026-09-06

First release. Tagged on `main` at `2198c4e`. This was a repository milestone
tag, not a distributed build: no signed artifact was produced and nothing was
published to any store.

### Added
Core feature work across E00–E14: genesis and the walking skeleton (E00);
identity and access (E01); relationships, trust and blocking (E02); E2E
encryption (E03); mesh discovery, relay and dynamic routing (E04); messaging
reliability and multi-device sync (E05); personal chat (E06); groups and voice
calls (E07); local storage and management (E08); location sharing (E09);
notifications and background operation (E10); Firebase metadata sync (E11);
account recovery and device enrollment (E12); abuse prevention and diagnostics
(E13); version and update management (E14).

1281/1281 tests passing at the tag.

### Known gaps at 0.1.0
- `E12-B06`, `E12-B10`, `E12-B13`, `E13-B02`, `E14-B03`, `E14-B04`, `E14-B05`
  — open P2–P4 bugs.
- `E14-T03` (signed version-policy verification) unbuilt, blocked on the
  signing-key infrastructure decision. **Since closed** — see Unreleased.
- No epic retros and no `epic-<n>-done` tags except `epic-06-done`, skipped for
  that release by explicit human decision. **Since closed** — all 16 retros now
  exist, and 13 of the 16 epics carry their tag.

[Unreleased]: https://github.com/SHAJED99/nexora/compare/v0.1.0...development
[0.1.0]: https://github.com/SHAJED99/nexora/releases/tag/v0.1.0
