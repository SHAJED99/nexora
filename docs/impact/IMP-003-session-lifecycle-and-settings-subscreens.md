# IMP-003 — Session lifecycle (logout + launch-skip) and the eight Settings sub-screens

**Gate:** 🧍 `change_impact_approval` — ✅ cleared by human, 2026-09-08
(`AskUserQuestion` — "Yes, approve and start dispatching tasks")

**Class:** **new scope** (three distinct pieces, one human decision session).
Nothing here is a *changed* requirement — no existing FR is reversed, no ADR is
superseded, no accepted design contract is edited. Every id below is **new**.

**Raised by:** the human, 2026-09-08, after an investigation into three
complaints. The three product decisions were made by the human in that session
and are recorded verbatim below; this report is the blast-radius walk performed
before any re-planning, per `skills/change-impact` §1–3.

---

## The three decisions (human, 2026-09-08 — verbatim intent)

1. **Logout wipes everything.** "Logout deletes the local identity, keys, and
   all local data. Next login creates a brand-new local identity." Explicitly
   chosen over the two alternatives offered — *keep identity, just sign out*
   and *multi-identity switching*.
2. **Skip welcome/login on launch.** When a local identity/session already
   exists (a returning device), launch routes straight to the dashboard,
   skipping the welcome screen and the "Continue with Google" tap.
3. **Build all eight Settings sub-screens.** Every row that currently shows a
   "Coming soon" snackbar gets a real screen. Priority order stated by the
   human: Notifications first, then Privacy & Security / Security Center, then
   Account, then Network / Storage / Battery / About — "but all".

---

## What "everything" means for decision 1 — enumerated, not guessed

`ADR-0005` (independent sessions) and `ADR-0001` (Drift/SQLite) between them
fix exactly what local persistence this app has. Walked file by file rather
than assumed:

| Surface | Where it actually lives | Wiped? | Why |
|---|---|---|---|
| Drift database — all 28 tables at `schemaVersion: 20` | `<app documents>/nexora.sqlite` (`database.dart:672` `_openConnection`) | **Yes — the file is deleted, not the rows** | Deleting rows leaves the SQLite file, its WAL and its page cache carrying recoverable ciphertext and key material. Deleting the file is the only honest reading of "wipe everything" |
| Signal Protocol identity, signed pre-keys, one-time pre-keys, sessions, trusted identities, counters | `SignalIdentity`, `SignalSignedPrekeys`, `SignalOneTimePrekeys`, `SignalSessions`, `SignalTrustedIdentities`, `CryptoCounters` — all inside that same file | Yes (with the file) | `FR-RECOVER-002` already states this is irreversible and intentional |
| Device cryptographic identity | `DeviceIdentities` — same file | Yes | Decision 1's own words |
| Conversation history, delivery states, group state, relay packets, routes, sync cursors, location fixes, storage stats/decisions, notification prefs, revocations, rate-limit counters, version policy cache | same file | Yes | all 28 tables go with the file |
| Google credential cache | `google_sign_in` plugin's own platform storage | **Yes** — `GoogleAuthService` must gain a `signOut()`; it has only `signIn()`/`signInAndGetAccountUid()` today | Otherwise the "brand-new local identity" claim is false the moment the next sign-in silently reuses the cached Google account without a chooser |
| Firebase Auth session | `firebase_auth`'s own storage | **Yes** — `FirebaseAuth.instance.signOut()` | Same reason; `ADR-0005` makes this a thin account pointer, so dropping it is cheap and correct |
| Firebase RTDB account↔device registry rows (`users/$uid/devices/*`) | **remote** | **No — deliberately not deleted** | See "The one thing logout does NOT wipe" below. Raised as `Q-SEC-009`, blocking `E15-T01` |
| `SharedPreferences` / `flutter_secure_storage` / on-disk media directories | **do not exist** — grepped: `pubspec.yaml` and all of `lib/` carry no `shared_preferences`, no `flutter_secure_storage`, and no `getApplicationDocumentsDirectory()` use other than the Drift file itself and `bindings.dart:431` (the same file) | n/a | Recorded so a later agent does not "helpfully" add a clear-prefs call to a surface this app has never had |
| In-memory GetX singletons (`AppDatabase`, `MessagingStack`, repositories, controllers) | `AppBinding` | **Yes — torn down** | A live `AppDatabase` handle onto a deleted file is the single most likely way this feature ships a crash |

### The one thing logout does NOT wipe, and why it is a blocking question
Deleting the local device row does **not** remove `users/$uid/devices/<deviceId>`
from the Realtime Database. The next sign-in mints a *new* device id
(`E11-B06`: derived from the freshly-generated Signal identity public key), so
the account's remote registry accumulates one orphan entry per logout. Two
consequences, neither of which an agent may decide alone:

- `E12-T03`'s enrollment gate (`login_controller.dart`) routes to
  `/device-enrollment` when `readOwnDeviceIds(uid)` reports *any* id other than
  this device's. After one logout+login cycle on a single physical phone, that
  is exactly what it will report — so **the user is sent to a device-enrollment
  approval flow with no other device able to approve it.** This is a real,
  reachable dead end introduced by decision 2's own success.
- `DeviceIdentityRepository`'s per-account registration rate limit is 5 per 24h.
  Each logout+login is a genuine new registration, so the sixth cycle in a day
  is denied.

Both are raised as **blocking** questions (`Q-SEC-009`, `Q-FUNC-010`) rather
than resolved by an agent — the options are "revoke/remove the remote row on
logout", "keep it and relax the enrollment gate", or "keep it and accept the
enrollment flow". The choice is a security-model decision (rule 3).

### The E13 carried-forward observation, checked against this design
`epics/E13-abuse-diagnostics/tracker.md` carries T07's reviewer note:
`SignInUseCase.call` matches on `deviceId` only, never on account, so a second
account signing in on the same device would silently reuse and rewrite the
first account's device-identity row. **Wipe-based logout satisfies this note
for the logout path**: after the wipe there is no `DeviceIdentities` row at all,
`existingDeviceId()` returns `null`, `_deriveDeviceIdFromLocalIdentity()`
returns a *new* key-derived id (the old keypair is gone with the file), and
`call()`'s `existing != null && existing.deviceId == deviceId` branch is not
taken — so the second account registers as a genuinely new device and **is**
counted by the rate limiter. Verified by reading
`sign_in_use_case.dart:call` and `login_controller.dart:_signIn`, not assumed.
The note's *other* half — account switching **without** logout — remains
unreachable and stays a carried-forward note; E15 introduces no such path.

---

## Blast radius

| Artifact | id | Impact | Action |
|---|---|---|---|
| `spec/srs.md` | `FR-AUTH-006` … `FR-AUTH-013` | 8 new ids: wipe scope, destructive confirmation, post-wipe identity, interrupted-wipe resume, launch routing (3), Account screen | **new ids** — no existing FR edited |
| `spec/srs.md` | `FR-UI-006/007/008` | Settings rows navigate; sub-screens never fabricate a control the app lacks; back returns to the hub | new ids |
| `spec/srs.md` | `FR-NOTIFY-003`, `FR-SEC-005`, `FR-DIAG-003`, `FR-ROUTE-010`, `FR-PLAT-004`, `FR-VER-012` | one new id per sub-screen, in that screen's own domain area rather than piled into `FR-UI` | new ids |
| `spec/srs.md` | `FR-AUTH-005` | **Unchanged and still true.** "Google Sign-In is the sole authentication method" is about *which* method, not *when the screen is shown*. Decision 2 skips the screen for a returning device; it adds no alternate login path | no edit — checked explicitly, because this is the id a careless walk would have retired |
| `spec/srs.md` | `FR-VER-006` | **Unchanged.** `FR-AUTH-011` is written to be subordinate to it | no edit |
| `spec/srs.md` | `FR-STORE-004/005/007` | Already exist; E15 finally builds their UI | no edit |
| `spec/srs.md` | `FR-RECOVER-002` | Already states permanent key loss is intentional — `FR-AUTH-007`'s confirmation copy cites it | no edit |
| `agent/memory/decisions/ADR-0005` | `ADR-0005` | **Not superseded.** Wipe-logout is the *most* ADR-0005-consistent logout available: it destroys local device identity and drops the Firebase pointer as two independent acts, and never derives one from the other | no edit; cited by `FR-AUTH-006` |
| `agent/memory/decisions/ADR-0001` | `ADR-0001` | Fixes the wipe target (one SQLite file) | no edit |
| `design/screens/settings.md` | — | **No visual change.** All eight rows are already `button` elements with their copy fixed by the contract; only their *behaviour* changes | no edit — a behaviour change is not a contract change |
| `design/screens/welcome.md`, `login.md` | — | **No visual change.** Decision 2 changes when they are reached, not what they render | no edit |
| `design/gaps.md` | `GAP-031` … `GAP-039` | 9 new entries: the shared sub-screen shell, 7 sub-screens, and the sign-out confirmation | new entries; gate reopened ⏳ |
| `design/screens/settings-storage.md` | — | Already written (`E08-T07`), `GAP-024` ✅ approved 2026-09-02, never built | **reused unchanged** — `E15-T09` is the build task E08 deferred |
| `design/screens/*` (8 new) | — | 7 derived sub-screen contracts + `sign-out-confirm.md` | written in this pass |
| `epics/E08-local-storage/` | `E08-T09` | Prospective task, explicitly deferred "shard it the moment T07 lands and the human clears GAP-024". Both happened | **rehomed to `E15-T09`** — E08 is closed; a new task in a closed epic would be a bug id, not a feature id. Recorded in E15's Inherited-obligations row |
| `epics/E08-local-storage/epic.md` §Analyze | `EARS-STORE-20…22` | Reserved for T09, never minted | **minted by `E15-T09`** as `EARS-STORE-20/21/22` — the reservation is honoured, not renumbered |
| `epics/E08-local-storage/epic.md` §Analyze | collision note | "T09 must not be given the probe fixture when it is sharded, since T08 now owns that file" | **honoured**: no E15 screen task touches `test/design/design_probe_test.dart`; `E15-T11` alone does |
| `epics/E13-abuse-diagnostics/tracker.md` | carried-forward observation | Needs a reader before any logout feature lands | **read and answered** above; `E15-T01` §2 carries the finding |
| `lib/app/main.dart` | — | Launch routing composes after the existing version gate | `E15-T02` |
| `lib/app/routes.dart`, `lib/features/settings/presentation/settings_controller.dart` | — | 8 routes + 8 row wirings | `E15-T11` alone (single-owner, per E08's own reservation of these paths) |
| `lib/core/auth/google_auth_service.dart` | — | Needs `signOut()` | `E15-T01` |
| `test/widget_test.dart` | F1 regression test | **Asserts the behaviour decision 2 changes**: a returning device reaching the dashboard *through welcome → login*. Its subject (a returning device is never rate-limit-denied) stays valid; its *route* does not | **flagged stale, not rewritten** (`skills/change-impact` §5.5). `E15-T02` updates it and must keep the rate-limiter assertion intact — the test proved an S1 fix and must keep proving it |
| `docs/routes.md` | — | 8 new routes | `E15-T11` |
| `spec/knowledge-map.yaml` | requirements, features, edges | 19 new FR pointers, feature `E15`, edges FR→E15→task | after this gate clears |
| `docs/traceability.md` | — | regenerate as the last step of executing the re-plan | after this gate clears |

**Tests asserting behaviour that changes:** exactly one —
`test/widget_test.dart`'s F1 regression test. Grepped `test/` for other
`welcome`→`login` journey assertions; the rest are per-screen widget tests that
never traverse the launch route.

---

## Effort / risk

- **Effort:** one epic, 11 tasks — 2 backend (S/M), 9 frontend (S/M). No `L`.
- **Highest risk:** the live-`AppDatabase`-handle-onto-a-deleted-file crash in
  `E15-T01`, and the logout↔enrollment-gate dead end above (blocking question).
- **Lowest risk:** the six read-mostly sub-screens (Network, Battery, About,
  Security Center, Privacy, Notifications) — each renders state a shipped
  repository already exposes.

## Proposed re-plan

New epic **E15 · Session Lifecycle & Settings Sub-Screens**, sharded into 11
tasks. No existing task is edited, reopened, or renumbered. `E08-T09`'s
prospective slot is retired into `E15-T09` with its reserved EARS ids intact.

Execution order once this gate clears (each its own commit):
1. `spec/srs.md` amendments — **new ids only**.
2. `design/gaps.md` + the 8 derived contracts → 🧍 `design_contract_approval`.
3. `epics/E15-*/` epic, tasks, tracker → 🧍 `analyze_report`.
4. `spec/knowledge-map.yaml` (`docs(knowledge): IMP-003 executed`).
5. Regenerate `docs/traceability.md` and read it (§5b — verification, not
   bookkeeping).
