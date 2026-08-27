# E04 · Mesh Discovery, Relay & Dynamic Routing — Retro

**Date:** 2026-08-27 · **Epic status:** done, pending on-device Bluetooth
verification and merge to `main`

## What shipped
A deterministic, hardware-free simulator (T01) and a routing engine on top
of it (T02) — cost formula, Dijkstra route selection, make-before-break
migration policy, failure recovery. A three-stage Pigeon/Bluetooth
transport (T03a loopback plumbing → T03b real discovery/connect → T03c
real send/receive), split from an oversized single task per the epic's own
risk mitigation. A store-and-forward relay engine (T04) enforcing
FR-ROUTE-003's payload-opacity guarantee. Real device discovery wired into
the Devices screen (T05). Three cross-task bugs found by the sweep and
fixed same-day (B01 S2, B02/B03 S3) — P1/P2 = 0 at close.

## What recurred — the epic's central finding
**The same class of defect — a piece of state whose meaning changed for
some callers but not others — hit five times across E03 and E04, and this
epic's own review promoted the lesson to a rule mid-epic (L-backend-003,
`implement/SKILL.md` §6) after recurrence 4. It recurred again anyway,
inside the very fix meant to close it:**

- **E04-B01**: `RelayEngine` called `RoutingEngine.setActiveRoute()` as a
  side-channel ("this is the link I'm using") on every forward attempt;
  `RoutingEngine` read the same call as "a validated route switch
  happened" and cleared migration-tracking state. Two tasks, two correct
  local readings of one shared method, one silently broken cross-cutting
  guarantee (EARS-ROUTE-2 never fired for any relayed destination).
- **E04-B01's own fix, reviewed same-day**: the builder's first attempt
  literally followed the bug report's suggested fix and *still* failed its
  own regression test, for the same underlying reason (writing into the
  same map two different callers read two different ways). The builder
  caught this itself, diagnosed why, and built a genuinely separate
  tracking map instead of shipping the literal suggestion.
- **The reviewer, verifying that fix**: found a *third* instance in the
  same two-line shape — the new tracking map wasn't cleared on a genuine
  validated switch, so a stale entry could survive and cause
  wrong-link-blaming later. Fixed in the same review pass.

Three occurrences of one pattern, inside one bug's lifecycle, in an epic
that had already promoted the general lesson to a rule from a *different*
prior instance (E03's prekey-counter bugs). The rule didn't prevent
recurrence 5-6-7; it just made recurrence 6-7 fast to recognize and fix
once found. That's real value — every instance was caught before merge,
none shipped — but "the rule exists" is not the same as "the rule stops
new instances," and this epic is the evidence for that distinction.

A second, independent finding of the same *shape* at a different altitude:
**E04-B03** — no task's `files:` fence covered "does the transport contract
actually carry the data the routing engine needs," so the epic delivered a
fully-tested routing engine with zero production data source. Not a code
bug; a spec-completeness gap the analyze report's own "Contract sanity"
check didn't catch, because it checked whether tasks *contradicted* each
other, not whether the union of what they built was *sufficient* for what
the epic promised.

## What got promoted
- **Nothing new this retro** — L-backend-003 was already promoted to a
  rule during E04's own T04 review (before the bug sweep even ran). This
  retro's job is to record that the rule, once live, still let three more
  instances through in the very next bug's own lifecycle — worth watching
  whether a 6th/7th/8th instance appears in E05/E06 before deciding this
  needs to become an actual mechanical hook (a lint rule flagging any
  method that both writes shared mutable state AND is called from more
  than one file, prompting a "does every caller mean the same thing by
  this?" check) rather than a self-review checklist line a busy pass can
  skim past.
- **New lesson, recurrence 1**: E04-B03 — "a task's own `files:` fence can
  be individually correct and still leave a spec-level completeness gap
  the analyze report's cross-task-contradiction check doesn't catch."
  Logged to `agent/memory/lessons/process.md` this retro (see below). One
  occurrence so far; not yet promotion territory.

## What the numbers said
No `metrics.csv` — same gap as every prior epic, still not fixed
mechanically. 10 tasks/bugs against an original 7-task plan; the 3 extra
were all genuine sweep findings on cross-task seams, not a scope-estimation
miss — the epic's own analyze report flagged its 100%-`must` MoSCoW
distribution as justified precisely because this is a strict-dependency
infrastructure chain with no optional slice, and the sweep findings
confirm that reasoning (every bug was in a seam between two `must` tasks,
not in an over-scoped one).

## Open follow-ups carried forward
- **The largest open item: T03a/T03b/T03c/T05's on-device manual
  verification is still unticked.** Three independent MIUI
  install-restriction confirmations across the epic, plus a same-session
  emulator that can exercise the app end-to-end (confirmed real Google
  Sign-In works, closing an old E01-T01 gap) but has no Bluetooth radio.
  T03b/T03c's own task files state plainly that no meaningful
  hardware-free test exists for real socket I/O — their correctness rests
  entirely on code review and reasoning until a human does one physical
  tap-through with two real Bluetooth radios. Recommend this happens
  before E05/E06 build real traffic volume on top of this transport, not
  after.
- E04-B03's carry-forward: E05 must wire real RSSI/latency/loss
  measurements into the now-extended Pigeon contract (`int? rssi`,
  `onLinkQuality`) — the contract exists and is unfed by design; without
  wiring, `RoutingEngine.computeRoute()` returns `null` for every
  destination on a real device.
- `RelayDeliveryState.failed` is declared but never assigned anywhere
  (confirmed by grep during B02's review) and is excluded from
  `reclaimPayloads()`'s reclaim set. Not a live gap today, but whichever
  epic first writes `failed` inherits exactly the retention defect B02
  just closed, at the one state B02 couldn't test because nothing
  produces it yet.
- Neither `RelayEngine.processQueue()`/`sweepExpired()`/`reclaimPayloads()`
  nor `RoutingEngine` has a production scheduler/caller anywhere in
  `lib/` — confirmed cleanly deferred to E05/E06 by design (the
  `TransportService`/`RoutingEngine`/`AppDatabase` triple E05 needs is
  genuinely constructible today), but worth naming explicitly so E05's
  planning doesn't rediscover it.
- `metrics.csv` still doesn't exist — carried forward from every prior
  epic's retro, still not mechanically fixed.
