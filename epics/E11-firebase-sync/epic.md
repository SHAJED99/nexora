---
id: E11
title: Firebase Metadata Sync
status: done (2026-09-05; original sweep + retroactive rule-5 re-review both clean, P1/P2=0, all priority-stamped — ready for epic→development merge)
type: feature
priority: { moscow: should, wsjf: 3.5 }
depends_on: [E01, E02]
traces_to: [FR-FB-001, FR-FB-002, FR-TRUST-007, NFR-PRIV-001]
external_services: [Firebase]
ui_surface: []
design_screens: []
---
# E11 · Firebase Metadata Sync

## Business goal
The full Firebase data-boundary implementation — everything Firebase *may*
store (auth, identity, device registry, trust/block metadata, config,
revocation, push info, version policy) and the hard boundary of what it
*must never* store (plaintext, recordings, keys, permanent location).

## Scope
**In scope:** the complete boundary-respecting Realtime-DB schema,
revocation propagation, own-account relationship-config mirroring, a public
device directory (identity key + prekey bundle + revocation, exact-id
lookup only — `ADR-0008`). E01/E02 already carved out a *minimal* slice of
this (auth + basic trust-config sync) during Wave 1 — this epic reconciles
with, and extends, that wrapper rather than replacing it.
**Deferred, not in this epic's tasks:** push-notification token registry
(`E10` owns notifications and has no task claiming this either — flagged as
`OQ-E11-2`) and application version policy (`E14`'s charter). Both are
`FR-FB-001` categories with no owner yet; reserved as `status: reserved` in
`docs/firebase-schema.md`, not built here.

## Acceptance criteria (epic-level, EARS)
- **EARS-FB-1**: Firebase SHALL NOT store message plaintext, voice/call recordings, private/session keys, or permanent private location history. (FR-FB-002) — this is the epic's non-negotiable constraint, testable by schema review.
- **EARS-FB-2**: WHEN any Firebase write is prepared, the system SHALL reject a payload containing a key outside that node's `FR-FB-001` allow-list, before the write is issued. (FR-FB-001, FR-FB-002)
- **EARS-FB-3**: The system SHALL produce every Realtime Database path from a single path registry, and those paths SHALL be identical to the paths in use before this task. (FR-FB-001)
- **EARS-FB-4**: The system's Firebase security rules SHALL reject any write to a documented node carrying a field outside that node's `FR-FB-001` allow-list. (FR-FB-002)
- **EARS-FB-5**: The system's Firebase security rules SHALL deny read and write on every path not documented in `docs/firebase-schema.md`. (FR-FB-002, NFR-PRIV-001)
- **EARS-FB-6**: The system's Firebase security rules SHALL grant read and write only to the authenticated owner of the subtree. (FR-FB-001, ADR-0005)
- **EARS-FB-7**: WHEN a device registers for the first time, the system SHALL record `createdAt` and `lastSeenAt` in the device registry. (FR-FB-001, FR-AUTH-004)
- **EARS-FB-8**: WHEN a device that is already registered registers again, the system SHALL refresh `lastSeenAt` and SHALL NOT overwrite `createdAt`. (FR-FB-001, FR-AUTH-004)
- **EARS-FB-9**: IF any Firebase operation in registration fails, times out, or the device is offline, THEN the system SHALL log the failure and complete normally without throwing. (ADR-0005)
- **EARS-FB-10**: WHEN a device is revoked, the system SHALL record the revocation locally and SHALL best-effort publish it to the account's Firebase device registry. (FR-FB-001)
- **EARS-FB-11**: WHEN local and remote revocation state for one device disagree, the system SHALL resolve to revoked. (FR-MSG-007 — REVOKED > ACTIVE)
- **EARS-FB-12**: IF the Firebase read or write fails or the device is offline, THEN the system SHALL keep the local revocation state unchanged and complete without throwing. (ADR-0005, NFR-REL-001)
- **EARS-FB-13**: The revocation node SHALL carry only `revokedAt` and `revokedByDeviceId`, and the security rules SHALL reject any other field. (FR-FB-001, FR-FB-002)
- **EARS-FB-14**: WHEN a relationship's state changes locally, the system SHALL persist it locally first and best-effort mirror it to the account's own Firebase relationship node, without blocking or reversing the local change on a Firebase failure. (FR-TRUST-007)
- **EARS-FB-15**: WHEN a remote relationship state disagrees with the local one for the same peer device, the system SHALL resolve to the more restrictive of the two via `ConflictResolver.resolveTrust`. (FR-MSG-007)
- **EARS-FB-16**: The system's Firebase security rules SHALL grant read and write on `users/$uid/relationships/*` only to the authenticated owner of `$uid`. (FR-FB-001, ADR-0005, ADR-0008)
- **EARS-FB-17**: WHEN a signed-in device's signed prekey rotates, its
  one-time prekeys are replenished, or it is revoked, and a call site with
  a Firebase-authenticated uid triggers the publish, the system SHALL
  best-effort publish the corresponding `directory/$deviceId` entry
  without exposing any private key material. (FR-FB-001, FR-FB-002)
  > **Amended 2026-09-04, per `E11-B01`** (decision authority explicitly
  > delegated to the agent for this session): the original wording implied
  > publishing is wired into every prekey-rotation event unconditionally —
  > `E11-T06` built the mechanism (`DeviceDirectoryService.publish`),
  > proven and tested, but never had a production caller, because the
  > trigger site (`MessagingStack.create`, offline-first per `ADR-0005`)
  > has no auth context to supply a uid. This amendment makes the
  > criterion describe what `E11-T06` actually ships — a **proven,
  > callable capability with no wiring yet** — the same shape `E11-T04`
  > (`isRevoked`) and `E11-T05` (`push`/`pull`) already disclosed in their
  > own `files:` fences. No requirement is dropped: `FR-FB-001` still
  > permits this data class and `ADR-0008` still authorises the
  > directory's existence and shape. **Wiring a real publish call site is
  > deferred to whichever epic builds the directory's first consumer** —
  > `E07`'s TOFU replacement or `E06-T07`'s prekey fallback — since that
  > task will need to answer the sign-in-timing question in the context of
  > its own actual usage, rather than E11 guessing at a lifecycle policy no
  > consumer yet needs. `E11-B01` closed as **won't-fix-in-E11, tracked
  > forward** rather than fixed in place; the amended criterion is now
  > testable and met by what already shipped.
- **EARS-FB-18**: The system's Firebase security rules SHALL permit reading `directory/$deviceId` by any authenticated user for an exact, known device id, and SHALL deny any read at the `directory` parent node. (NFR-PRIV-001, ADR-0008)
- **EARS-FB-19**: The system's Firebase security rules SHALL permit writing `directory/$deviceId` only to the account recorded as its `ownerUid`, and SHALL make `ownerUid` immutable after first write. (FR-FB-001, ADR-0008)

> **Added at sharding, 2026-09-04.** The epic shipped from `epic-breakdown`
> with one criterion (`EARS-FB-1`) while its scope named revocation, trust
> mirroring and a device directory. `EARS-FB-2` through `EARS-FB-19` add
> criteria for behavior this epic's own scope already claimed — no
> requirement added, changed or retired, so this is EARS authoring within
> `skills/task-sharding`, not a scope change routed through
> `skills/change-impact`. `traces_to:` gained `FR-TRUST-007` and
> `NFR-PRIV-001` to match.

## Tasks

| Task | Title | Layer | Size | MoSCoW | EARS owned | Status |
|---|---|---|---|---|---|---|
| E11-T01 | Firebase data-boundary schema, path registry and wrapper reconciliation | backend | M | must | FB-1, FB-2, FB-3 | done |
| E11-T02 | Security rules that structurally enforce the FR-FB-002 boundary | backend | M | must | FB-4, FB-5, FB-6 | done |
| E11-T03 | Device registry semantics — real `createdAt`, refreshed `lastSeenAt` | backend | S | should | FB-7, FB-8, FB-9 | done |
| E11-T04 | Device revocation records and own-account propagation | backend | M | should | FB-10, FB-11, FB-12, FB-13 | done |
| E11-T05 | Own-account relationship-config mirror (trust/block state across a user's own devices) | backend | M | should | FB-14, FB-15, FB-16 | done |
| E11-T06 | Public device directory — identity key + prekey bundle + revocation, exact-id lookup only | backend | M | should | FB-17, FB-18, FB-19 | done |

### Bug tasks (from the 2026-09-04 sweep)

| Bug | Title | Severity | Priority | Status |
|---|---|---|---|---|
| E11-B01 | `directory/$deviceId` is never published by the running app (EARS-FB-17 holds only in tests) | S2 | P2→P3 | **resolved: won't-fix-in-E11** — EARS-FB-17 amended to match what shipped; wiring deferred to the first real consumer (E07/E06-T07) |
| E11-B02 | `lookupDevice` accepts an entry whose `identityPublicKey` disagrees with its own `prekeyBundle` | S2 | P2 | **done** — fixed and cross-model reviewed (PR #57) |
| E11-B03 | `E11-T06` edited two files outside its `files:` fence with no §Deviations entry | S4 | P3 | **done** — `files:` fence corrected, deviation was already disclosed in prose |

DAG, collision matrix and the reconciliation rationale: `tracker.md`.

No `layer: frontend` task: `ui_surface: []`/`design_screens: []` in this
epic's own frontmatter are accurate — nothing here has a user-facing
surface.

## Risks
| Risk | Mitigation |
|------|-----------|
| Divergence from E01's minimal wrapper (built earlier, different task, different context) | `E11-T01` is a reconciliation pass reading E01's actual implementation (`FirebaseMetadataService`) before extending it — confirmed: paths must stay byte-identical, no field renamed |
| A rules-file mistake grants list access where only exact-id lookup was intended (`ADR-0008`) | `E11-T06` §6 names this as the single highest-value manual-verification item; its DoD requires a human-confirmed parent-level-read-denied check, not just a passing unit test |
| Enforcement of revocation (`isRevoked`) has no caller yet | Tracked as `OQ-E11-T04-1`, not silently dropped — a future E03/E12 task is the natural owner |

## Open Questions
- **OQ-E11-1 — cross-account Firebase visibility.** Resolved by `ADR-0008`
  (accepted, option 2 — public device directory) on 2026-09-04. Built by
  `E11-T06`. Option 3 (consent-scoped relationship mirror, full two-sided
  trust exchange) explicitly declined for now.
  - **Status:** 🟢 answered
  - **Answered by:** human (decision authority explicitly delegated to the
    agent for this session, 2026-09-04)
  - **Date:** 2026-09-04
- **OQ-E11-2 — push-notification token registry and application version
  policy have no owner.** Both are `FR-FB-001` categories; neither E10 nor
  E14's own sharding (E14 not yet sharded) has claimed them yet. Reserved
  in `docs/firebase-schema.md`, not built by any E11 task.
  - **Status:** 🟡 open — not blocking this epic; flagged for E14's own
    sharding pass to claim the version-policy half, and for a future E10
    bug/task to claim the push-token half if push notifications are ever
    added (E10's own sharding built local notification channels only, no
    push/FCM integration).
  - **Owner:** human, at E14's sharding or a future E10 task
- **OQ-E11-4 — mesh-only transport-frame signing (`ADR-0008` option 4) is
  not E11's charter.** Tracked as `E06-B04`'s real home (already an open
  bug there, P3 deferred). Not duplicated here.
  - **Status:** 🟢 closed — correctly out of scope, no action needed in E11
- **OQ-E11-5 — revocation enforcement has no owner.** `E11-T04` builds
  `isRevoked` with zero callers by design (§4). Enforcement spans E03's
  Signal session store and E04's transport.
  - **Status:** 🟡 open — not blocking `E11-T04`, which is complete and
    useful as a record; blocking any claim that revocation actually
    *prevents* anything until a consuming task exists
  - **Owner:** human, at E03 or E12's next sharding pass (also recorded as
    `OQ-E11-T04-1` in the task file itself)

## ANALYZE REPORT — 2026-09-04

**Gate:** 🧍 `analyze_report` — ✅ cleared by human (decision authority
explicitly delegated to the agent for this session) on 2026-09-04.

Sharded by: planner · 6 tasks (T01–T06; T05/T06 added after `ADR-0008` was
decided) · `python agent/orchestrator/scheduler.py --validate` → green.

### Step 0 — Inherited obligations (read before slicing)

Sources read in full: `retro.md` §Open follow-ups and `epic.md` §Bug sweep
for **E01**, **E02** (this epic's `depends_on:`), plus a targeted read of
`epics/E09-location-sharing/`'s `OQ-E09-T02-1` and
`epics/E06-personal-chat/tasks/E06-T07.md`'s `OQ-E06-T07-1` and the `E07`
tracker's TOFU note — all three of which name E11 explicitly as the
eventual owner, and none of which live inside E01/E02's own retro or bug
files (they were filed by later epics, against E11, as the chain unfolded).

| # | Obligation | Source | Disposition |
|---|---|---|---|
| 1 | Two-sided relationship-state exchange for `FR-TRUST-005`/`FR-TRUST-007`; `E09-T02` ships `remoteState` as a caller-supplied parameter defaulting to `unknown` | `OQ-E09-T02-1` | **Resolved by `ADR-0008`, partially covered.** Full two-sided cross-account exchange (option 3) is declined; the narrower own-account reading of `FR-TRUST-007` is **covered-by-`E11-T05`**. Recorded in `ADR-0008`'s Consequences as an accepted, permanent limitation for the cross-account half. |
| 2 | Firebase fallback for prekey-bundle acquisition when a peer is unreachable over the mesh | `OQ-E06-T07-1` (🔴 blocking on E06-T07 itself) | **covered-by-`E11-T06`** (the publisher). The consumer (E06-T07 or a bug against it actually calling `lookupDevice`) is a separate, E06-owned change — named explicitly in `ADR-0008`'s Consequences and `E11-T06` §4, not claimed here. |
| 3 | `DriftSignalProtocolStore.isTrustedIdentity` TOFU gap — a never-messaged peer can be impersonated | `E07` tracker, 2026-08-31, "owner: E11, not this epic" | **covered-by-`E11-T06`** (the publisher, the identity key). The consumer (`E07`'s own file actually checking it) is out of E11's fence — same split as #2. |
| 4 | Revocation information must be usable — a peer must learn a device it talks to was revoked | E11's own charter (`FR-FB-001`) | **covered-by-`E11-T06`** for the cross-account read half (`revokedAt` in `directory/$deviceId`); **covered-by-`E11-T04`** for the local record + own-account propagation half. |
| 5 | `ConflictResolver.resolveRevocation`/`resolveTrust`, built at E05-T05, zero production callers since | `E06`'s retro, "Owner: E11" | **covered-by-`E11-T04`** (`resolveRevocation`) and **covered-by-`E11-T05`** (`resolveTrust`) — both named explicitly as required calls in each task's §2, not re-derived. |
| 6 | `E01-T02`'s carried review note: `createdAt`/`lastSeenAt` are always equal (registration overwrites both every time) | `E01-T02` review log | **covered-by-`E11-T03`** — its whole charter is this fix. |

### Analyze gate checks

| Check | Verdict | Evidence / offending ids |
|---|---|---|
| **EARS trace** | ✅ pass | Epic EARS ↔ task coverage total both directions: FB-1→T01, FB-2→T01, FB-3→T01, FB-4→T02, FB-5→T02, FB-6→T02, FB-7→T03, FB-8→T03, FB-9→T03, FB-10→T04, FB-11→T04, FB-12→T04, FB-13→T04, FB-14→T05, FB-15→T05, FB-16→T05, FB-17→T06, FB-18→T06, FB-19→T06. No orphan. |
| **Contract sanity** | ✅ pass | No HTTP endpoints — the "API" is a Realtime Database schema + rules file, contracted per-node in each task's §5 with an explicit allowed-field set. No two tasks define the same node: `T01` owns `devices`/`sync_cursors` (live, pre-existing), `T04` owns `devices/$id/revocation`, `T05` owns `relationships/$peerDeviceId`, `T06` owns `directory/$deviceId`. `docs/firebase-schema.md` is one file, one row per node, one owner per row — `T01` reserves the `T05`/`T06` rows as placeholders their own tasks flip to `live`, which is the anti-collision mechanism for a shared doc, not just a convention. Error handling is uniform: every write is best-effort, local-first, never throws (FB-9, FB-12, and T05/T06's equivalent, all independently stated). |
| **Collision matrix** | ✅ pass — **empty** | `T02`, `T03` can run in parallel once `T01` merges (disjoint `files:` — T03 touches `firebase_metadata_service.dart` only, T02 touches `database.rules.json` + the boundary/paths files T01 created). `T04` depends on `T01`+`T02`. `T05` and `T06` both touch the same four shared files (`firebase_paths.dart`, `firebase_boundary.dart`, `database.rules.json`, `docs/firebase-schema.md`) and, if left with independent `depends_on: [T01, T02, T04]` sets, would be schedulable concurrently despite colliding — **caught in this pass and fixed by serializing**: `T06 depends_on: [E11-T01, E11-T02, E11-T04, E11-T05]` (`T05` added), so the DAG itself now forbids concurrent dispatch rather than relying on anyone remembering not to. |
| **Scope fences** | ✅ pass | All six §4 sections are populated with task-specific temptations: T01 "no shared FirebaseClient abstraction"; T02 "does not widen read access to another account"; T03 (unread here, pre-existing, confirmed populated); T04 "does not enforce revocation anywhere"; T05 "does not let one account read another account's relationships"; T06 "does not change `DriftSignalProtocolStore` or wire `lookupDevice` into E06 — publisher only". |
| **MoSCoW inflation** | ✅ pass | 2/6 `must` = 33%. T01/T02 are must (nothing else can be built without the schema and the rules that enforce it); T03–T06 are should — the epic is shippable (schema + boundary enforced) without device-registry semantics, revocation, relationship mirroring or the directory, though each closes a real, named gap. |
| **Size** | ✅ pass | XS 0 · S 1 · M 5 · **L 0**. |
| **Design** | ✅ pass | Zero `layer: frontend` tasks; `ui_surface: []`/`design_screens: []` at the epic level confirmed accurate, not aspirational — no design gap to disclose (contrast E09/E10, which had one). |
| **Obligation ownership** | ✅ pass | Every cross-reference grepped and checked: `T01` §4 says the revocation node is "declared by E11-T04" — T04 §3/§5 independently states that as its own deliverable; `T01`'s schema table says `relationships/$peerDeviceId` is "declared by E11-T05" — T05 §3/§5 independently owns it; `T04` §4 says "call `ConflictResolver` for trust state — that is E11-T05" — T05 §2/§5 independently owns that call. `T06` §4 says the TOFU fix and the E06 fallback consumer both belong outside E11 — neither is claimed by any E11 task, correctly, since both are named as future E07/E06 work in `ADR-0008` Consequences, not invented owners. |
| **Inherited obligations** | ✅ pass | Six rows above, each disposed as **covered-by-`<task-id>`** or **resolved by `ADR-0008` with the residual half named as a permanent limitation**. Nothing left in prose without a reader — three of the six (`OQ-E09-T02-1`, `OQ-E06-T07-1`, the E07 tracker note) would have been missed by a mechanical `depends_on` sweep, since none live in E01 or E02's own retro/bug files; they were filed by later epics against E11 as the chain unfolded, and are flagged as such rather than found by the standard sweep. |

### For the human, before you clear this gate

Three things worth a deliberate look — all already decided this pass by
delegated authority, listed here for visibility rather than as blockers:

1. **`ADR-0008` accepted option 2** (public device directory) over option 3
   (consent-scoped relationship mirror). This is a real privacy/security
   trade — a device id plus knowledge of it now unlocks a public-key +
   prekey-bundle + revocation-flag read for anyone authenticated, in
   exchange for closing the TOFU-impersonation gap and the prekey-fallback
   gap. Worth a second look if the product's threat model changes.
2. **`E11-T06`'s rules file is the epic's highest-stakes diff** — a
   mis-scoped `.read` at the `directory` parent instead of
   `directory/$deviceId` turns exact-id lookup into full enumeration. Its
   DoD requires a human-confirmed manual check of this, not just a passing
   unit test — worth actually doing at review time, not skimming.
3. **Push-token registry and version-policy nodes remain unowned**
   (`OQ-E11-2`). Neither blocks this epic; both should be picked up by
   E14's sharding pass (version policy) or a future notifications task
   (push tokens) rather than drifting further.

## Bug sweep — 2026-09-04

**Reviewer:** `claude-opus-5`, independent worktree, `epic_11` @ `877e8bd`
(verified byte-identical to `origin/epic_11`). **891/891 tests green**,
`flutter analyze` clean. Full evidence, probe output and the gate table live
in `tracker.md` §Bug sweep — 2026-09-04.

**Three defects found.** Severity is the reviewer's; priority was set under
decision authority explicitly delegated by the human for this session's
gate-clearing.

| id | severity | priority | what |
|---|---|---|---|
| `E11-B01` | **S2** | **P2→P3, resolved** | The public device directory is never written in production. `DeviceDirectoryService` is never constructed anywhere in `lib/`, and the sole production `IdentityService` (`messaging_stack.dart:491`) passes no publish hook. Filed `blocked`/`owner_agent: planner` since the publish-vs-auth lifecycle (offline-first per `ADR-0005`, publishing needs a Firebase uid the trigger site doesn't have) is a rule-3 design call, not a scoped fix. **Resolved 2026-09-04 by taking the bug's own named "defensible human override"**: `EARS-FB-17` amended to describe the proven-but-unwired shape `E11-T04`/`T05` already used, and wiring deferred to whichever epic builds the directory's first real consumer (`E07` TOFU / `E06-T07` fallback), which will need to answer the lifecycle question in context anyway. Closed as won't-fix-in-E11, not fixed in place. |
| `E11-B02` | **S2** | **P2** | `lookupDevice` decodes the identity key from two independent, attacker-controlled fields of the same cross-account-readable node and never checks they agree, so one entry can hand `E07`'s TOFU consumer identity A while `E06-T07`'s prekey consumer establishes a session on identity B. Proven with a reviewer probe. Scoped fix inside T06's own file. |
| `E11-B03` | S4 | P3 | `E11-T06` edited `identity_service.dart` and `device_revocation_service.dart` outside its `files:` fence, with no §Deviations entry — its own §3 mandated changes its frontmatter did not permit. Docs-only; does not block the merge. |

**Security properties re-derived independently** (not trusting the merge-time
record, per the sweep brief): the `directory` parent node is structurally
unreadable while `directory/$deviceId` is readable by exact id — re-proved
with the reviewer's own RTDB read-cascade model, including mutation controls
confirming the model detects a hoisted `.read`. No rule anywhere grants a
bare `true`. `ownerUid` is anchored to server-authenticated `auth.uid`, so
`publish`'s caller-supplied `uid` is not a trust hole. All ✅.

**On the `E09-B09` pattern (item 5 of the brief):** the write side is clean —
Firebase `auth.uid` really is server-authenticated, genuinely unlike a mesh
frame's self-asserted `source`. The pattern nonetheless recurs on the *read*
side as `E11-B02`, in the subtler form of two unvalidated identity fields
inside one payload. Worth recording as a recurrence: the failure mode is not
"which field carries the identity" but "two fields that must agree, and no
code that checks".

**Merge status: CLEAR.** `E11-B01` resolved (won't-fix-in-E11, EARS-FB-17
amended). `E11-B02` fixed and cross-model reviewed (PR #57, merged) —
byte-for-byte identity binding check added to `lookupDevice`, independently
re-derived exploit + fix verification, including a trailing-garbage-bypass
probe. `E11-B03` fixed (`files:` fence corrected). **P1 = 0, P2 = 0.** Per
`skills/release`, the epic→`development` PR may now open.

**Non-blocking observation carried forward from `E11-B02`'s round-2
review**: `identityPublicKey` is not length-canonical —
`IdentityKey.fromBytes` tolerates trailing bytes past the 33-byte key.
Unexploitable via the fixed comparison (which operates on the *decoded*
key), but a future consumer that compares the raw base64 field instead of
the decoded key could reintroduce a related gap. Flag for whoever builds
`E07`'s TOFU consumer or `E06-T07`'s fallback.

## Retro
<pending — after the epic merges to development>
