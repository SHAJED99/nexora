---
status: accepted
date: 2026-09-04
proposed_by: planner (E10 task-sharding)
decided_by: human (decision authority explicitly delegated to the agent for this session, 2026-09-04)
traces_to: [FR-PLAT-001, FR-PLAT-002, FR-PLAT-003, NFR-BATT-001, NFR-SEC-001, E05-B02, E06-T06, E10]
---

# ADR-0007 — Background execution architecture (Android)

> DECISION OWNERSHIP: this document presents options, trade-offs and an
> advisory recommendation. The **Decision** line stays `⏳ AWAITING HUMAN`
> until the human picks. `E10-T08` (and transitively `E10-T09`/`E10-T10`)
> is `blocked` until then — this is the gate `E06-T06.md:128-133` demanded
> in writing ("that answer names a new dependency and a new manifest
> permission, which is itself a 🧍 gate … must be re-presented before code").

## Context

The chain that ends here is three epics long and every link deferred the
same question:

- `E05-B02.md:140-145` — 🧍 "Choosing *when* the queue runs is an
  application-architecture question (… a foreground service? … what happens
  in the background, on Android, with the app killed?) — that is rule 3
  territory." Deferred to E06.
- `E06-T06.md:375-381` — the human chose option **(c)**: a 60 s
  `Timer.periodic` floor plus event triggers, **foreground-only**, with
  option (d) (background execution) "shaped as an E10 task".
- `E06-T06.md:382-384` — the honest cost, stated at the time: "with the app
  closed, nothing forwards and nothing reclaims."

So today NEXORA is a mesh that only meshes while someone is looking at it.
E10 is where that is decided, not re-deferred.

What is already true and constrains every option:

1. **There is exactly one periodic driver** — `MessagingCoordinator.tick()`
   (`processQueue → sweepExpired → reclaimPayloads`, plus E08's throttled
   storage pass appended). `E08-T06.md:119-120` refused to add a second
   timer *because E10 owns background operation*. Whatever this ADR picks
   must extend that one driver, never fork it.
2. **`reclaimPayloads()` is NFR-SEC-001's retention guarantee** — third-party
   ciphertext TTL nulling. It currently runs only while the app is
   foregrounded, which makes a security guarantee conditional on user
   attention.
3. **FR-PLAT-003 already fixes the shape**: system-sensitive functionality
   (foreground services, background networking, notifications) lives in
   Android-native components, with Flutter talking to them through a defined
   interface — Pigeon, per ADR-0004.
4. **OEM reality**: this project has already hit three separate MIUI
   restrictions on one physical device (`E04-mesh-routing/retro.md:86-90`).
   Any answer that assumes stock-Android behaviour is wrong on the only
   hardware we have.
5. **NFR-BATT-001 has never been measured by anyone** (`E06-T06.md:528-534`).
   The 60 s floor is an endorsed guess, not a measurement. Always-on
   execution is exactly the change that makes an unmeasured battery claim
   expensive.

## Options considered

### 1. Foreground service holding a retained `FlutterEngine`
A Kotlin `Service` with `startForeground()` and a persistent notification;
the `FlutterEngine` is cached (`FlutterEngineCache`) and held by the service,
so the **existing Dart `Timer.periodic` keeps running** with the Activity
destroyed. Dart-side code is unchanged in shape; the service's only job is
to keep the process alive and legal.

- **pros:** honours constraint 1 exactly — one tick, one code path,
  foreground and background identical, so there is no "background variant"
  of the messaging loop to keep in sync and no second re-entrancy story. No
  new Dart package. Bluetooth sockets opened by `BluetoothTransport` stay
  open because the process stays alive. `reclaimPayloads()` keeps running,
  closing constraint 2 with no new code. Directly matches FR-PLAT-003's
  shape and ADR-0004's Pigeon boundary.
- **cons:** a permanent, user-visible notification the design has no contract
  for. Requires `FOREGROUND_SERVICE` + a typed permission
  (`FOREGROUND_SERVICE_CONNECTED_DEVICE`) and Play Store justification for
  the service type. Highest steady-state battery cost of the four — the
  process never sleeps unless we make it. OEM killers (constraint 4) still
  terminate it; `START_STICKY` mitigates but does not solve.

### 2. `WorkManager` periodic job waking a headless Dart isolate
A Kotlin `Worker` scheduled by `WorkManager` (15-minute minimum period)
spins up a background `FlutterEngine`, calls a Dart entrypoint that runs one
`tick()`, then tears down.

- **pros:** the OS-blessed path; survives reboot and Doze by design (jobs are
  batched into maintenance windows rather than killed). Far lower battery
  cost. No persistent notification.
- **cons:** **15 minutes is the floor** — a mesh relay that forwards at most
  four times an hour is not a mesh, it is a mailbox. Every tick pays engine
  startup and a fresh Drift/transport initialisation. Bluetooth connections
  cannot survive between runs, so E04's whole connection model is
  re-established each time (and `BluetoothSocket.connect()` is blocking and
  slow). Creates a second driver in practice — a background entrypoint with
  its own composition root — which is precisely what constraint 1 forbids.

### 3. Hybrid: foreground service while connected, `WorkManager` when idle
Option 1 while at least one peer is connected or the queue is non-empty;
drop to option 2's periodic job when there is nothing to do.

- **pros:** the best battery/reliability curve on paper — pays the persistent
  notification only when it is buying something.
- **cons:** two lifecycles, two failure modes, and a hand-off between them
  that is exactly where a queue-drop bug lives. Doubles the surface E10 must
  test on hardware we currently cannot even install on
  (`E04-T03b.md` §Run log: three independent `INSTALL_FAILED_USER_RESTRICTED`
  confirmations). Reasonable as a *later* optimisation of option 1; poor as
  a first implementation.

### 4. Status quo — foreground-only, and say so
Keep E06-T06's option (c). Ship copy that states plainly that the mesh runs
only while the app is open, per `E06-T06.md:382-384`.

- **pros:** zero new permissions, zero new battery cost, zero OEM exposure,
  nothing to measure. Honest, if disappointing.
- **cons:** `FR-PLAT-001` ("shall support background operation — peer
  discovery, message synchronization, network maintenance … where permitted
  by Android") is then **unimplemented, not deferred** — E10 would close
  having built notifications and nothing else. NFR-SEC-001's retention pass
  stays conditional on user attention (constraint 2).

## Comparison matrix

| Criterion | 1 · Foreground service | 2 · WorkManager | 3 · Hybrid | 4 · Status quo |
|---|---|---|---|---|
| FR-PLAT-001 satisfied | ✅ fully | ⚠️ ≥15 min granularity only | ✅ fully | ❌ not at all |
| Constraint 1 (one tick) | ✅ same tick | ❌ second driver | ⚠️ two lifecycles | ✅ |
| NFR-SEC-001 retention while closed | ✅ | ⚠️ every ≥15 min | ✅ | ❌ |
| Bluetooth sockets survive | ✅ | ❌ | ⚠️ only in the service half | n/a |
| Battery cost (NFR-BATT-001, **unmeasured**) | highest | lowest | middle | none |
| New manifest permissions | `FOREGROUND_SERVICE`, typed | none (or minimal) | both sets | none |
| Persistent notification | required | none | conditional | none |
| OEM-killer exposure | high (mitigated by START_STICKY) | low | high | none |
| Implementation size in E10 | M (T08) | M + a second composition root | L | XS |
| Play Store review burden | service-type justification | none | service-type justification | none |

## Agent recommendation (advisory — NOT the decision)

**Option 1, with option 3 named as a follow-up, not built now.**

The deciding factor is constraint 1, not battery. Option 2 looks cheaper
until you notice it needs a second composition root and a second entrypoint
for the same tick — which is the exact duplication `E08-T06` refused to
create and `E06-T06`'s reviewer already falsified assumptions about once.
Option 1 buys background operation with *no new Dart code path at all*: the
service keeps the process alive, and the loop that has been running and
tested since E06 simply keeps running. That is the cheapest thing to review
and the cheapest thing to be wrong about.

Option 1 also makes the battery question answerable rather than theoretical:
with the process alive continuously, `E10-T10`'s adaptive policy (cadence and
discovery backing off under Doze/Battery-Saver) is a real lever with a real
measurement, which is the first honest shot anyone has had at NFR-BATT-001
(constraint 5).

Two things this recommendation deliberately does **not** include, because
they are separable rule-3 calls of their own (see the sub-decisions below):
requesting a battery-optimisation exemption, and background location.

**Final call is yours.**

## Sub-decisions the human should settle in the same sitting

These ride on the main choice and each is separately consequential:

**S1 · Foreground service type.** `connectedDevice` (accurate — the service
exists to maintain peer connections) vs `dataSync` (broader, easier to
justify to Play but less accurate). Advisory: `connectedDevice`, matching
what the app actually does. Affects the manifest and Play Store review.

**S2 · Battery-optimisation exemption.**
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` + a user prompt is the only real
mitigation for constraint 4 (`E06-T06.md:373` names OEM battery-killers
explicitly; three MIUI restrictions are already on record). It is also a
permission Google scrutinises and users distrust. **`E10-T08` does not build
it** and fences it out; it is carried as `OQ-E10-4`. Advisory: defer to a
later task with real on-device evidence that the service is being killed —
asking for an exemption we cannot yet show we need is the wrong order.

**S3 · Restart after reboot.** `RECEIVE_BOOT_COMPLETED` + a boot receiver, so
the mesh resumes without the user opening the app. Not built by `E10-T08`
(`START_STICKY` covers process death, not reboot). Carried as `OQ-E10-5`.

**S4 · The persistent notification's copy and icon.** Required by Android,
and **no design contract covers it** — `design/screens/settings.md` draws a
`Notifications` row and nothing behind it. Carried as `OQ-E10-1`. Rule 2
means this needs a `design/gaps.md` entry and human approval, or `E10-T08`
ships copy nobody approved.

## Decision
✅ **Chosen option: 1 — foreground service holding a retained `FlutterEngine`.**
Constraint 1 (one tick, no second driver) is decisive; option 2/3's second
composition root is exactly the duplication `E08-T06` already refused to
create. Option 3 (hybrid) is recorded as a legitimate follow-up optimisation
once option 1 is proven on real hardware — not built now.

**Sub-decisions:**
- **S1 — service type: `connectedDevice`.** Accurate to what the service
  does; declare it as such in the manifest and Play Store listing.
- **S2 — battery-optimisation exemption: deferred.** `E10-T08` does not
  request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. Revisit only once there is
  on-device evidence (e.g. a MIUI-style kill observed in the field or in
  manual testing) that `START_STICKY` + the foreground service alone isn't
  enough — asking Google/the user for a scrutinised permission before we can
  show we need it is the wrong order.
- **S3 — restart after reboot: build it now, in `E10-T08`.** A
  `RECEIVE_BOOT_COMPLETED` receiver that restarts the foreground service
  after reboot **if and only if** the mesh/location-independent "messaging
  active" state was on at last shutdown (reuse whatever persisted flag
  already gates starting the service in the foreground case — do not invent
  a new one). This closes a real, silent reliability gap (FR-PLAT-001) at
  low marginal cost over shipping T08 without it. Builder note: on API 26+ a
  manifest-registered `BOOT_COMPLETED` receiver calling
  `startForegroundService()` is an explicitly permitted exemption to the
  background-start restrictions (it is not a generic background start) —
  confirm this still holds on the project's target API range and test on a
  real device per T08's existing on-device verification requirement; if a
  real device shows the receiver is unreliable on a specific OEM, document
  it as a known limitation rather than silently dropping the feature.
- **S4 — persistent notification copy/icon: ship provisional copy, tracked,
  not blocking.** Android requires this notification to exist; there is no
  approved design contract for it (`OQ-E10-1`). `E10-T08` ships the
  plainest possible provisional string (e.g. "Nexora is running — relaying
  messages") and the existing app icon, explicitly marked in the task's own
  checklist as **provisional, pending a design gap pass on
  `design/screens/settings.md`'s `Notifications`/`Battery` rows** — this is
  a rule-2 exception for a system-mandated string with no screen behind it,
  not a licence to invent app-chrome copy elsewhere.

## Consequences
- `E10-T08`, `E10-T09`, `E10-T10` unblock — `status: blocked` → `todo` in
  each task file (T09/T10 were only transitively blocked on this ADR).
- The mesh now runs continuously while "messaging active" is on, closing
  NFR-SEC-001's retention-while-backgrounded gap (`reclaimPayloads()` now
  runs off the same tick regardless of foreground/background) and giving
  `E10-T10`'s adaptive cadence policy a real, continuously-running process
  to throttle — the first actual lever against NFR-BATT-001, which remains
  otherwise unmeasured.
- New user-visible surface with no design owner yet: the persistent
  notification. Tracked as `OQ-E10-1`; a design gap pass on `settings.md`
  should happen before this ships to real users, even though it does not
  block building T08.
- New manifest surface: `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_CONNECTED_DEVICE`
  + `RECEIVE_BOOT_COMPLETED`. No `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` yet
  (S2) — a follow-up task, not this ADR's scope, should own requesting it if
  on-device evidence later justifies it.
