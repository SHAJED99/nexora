# E04 freeze-exemption request — WITHDRAWN

> **Status: ❌ WITHDRAWN, 2026-09-29, by the author.** No exemption is
> needed. The defect is real, but it is **not in E04** — it is in
> `lib/app/bindings.dart`. `BluetoothTransport.kt` was never modified.

## What was asked for, and why it was wrong

This document originally asked for permission to change where
`BluetoothTransport.ensureListening()` is called from, on the grounds that
*"there is no call on app start, on transport start, or on entering a
conversation"* and *"no Dart-side code can open one"*.

**The second claim was false, and the first was misleading.** Review caught
it, and the author verified the correction first-hand before withdrawing.

`BackgroundLifecycleObserver` in `lib/app/bindings.dart` **already calls
`transport.startDiscovery()` automatically**, with no user tap:

- `_applyPlan()` calls
  `unawaited(transport.startDiscovery().catchError((Object _) {}))` whenever
  the computed plan allows discovery;
- `BackgroundPolicy.plan` returns `discoveryAllowed: true` for the ordinary
  foreground case;
- `_discoveryAllowed` is declared `bool?`, so it starts `null` and the first
  plan genuinely differs — the early-return guard does not suppress the
  first call.

And `startDiscovery()` → `doStartDiscovery()` → `ensureListening()`.

So the wiring this document asked to add **already exists**, and E04 already
anticipates exactly this. `startDiscovery()` (`BluetoothTransport.kt:477`)
handles the permission race on purpose, stashing
`pendingPermissionAction = { doStartDiscovery() }`, and `ensureListening()`'s
own doc comment states the design intent the request was going to propose:

> *"Deliberately NOT gated behind discovery or an active outbound `connect`
> attempt — a peer can only ever reach this device if something is
> listening, symmetrically, on BOTH sides, all the time this device's
> Bluetooth is on."*

Asking E04 to adopt an intent it already documents, and already wires, was
the wrong request.

## Where the defect actually is

`lib/app/bindings.dart`, in the path that is supposed to make that intent
true at cold start:

1. `BackgroundLifecycleObserver.start()` **deliberately does not** call
   `_applyPlan()` synchronously. That is correct and intentional — it avoids
   acting on the optimistic default `PowerState` before a real reading
   arrives.
2. So the first `_applyPlan()` depends entirely on
   `_refreshPowerStateOnResume()`, whose body is wrapped in
   `try { … } catch (_) { }`. If `_service.powerState()` throws,
   `_onPowerStateChanged` is never called, `_applyPlan()` never runs, and
   `startDiscovery()` is never called — so **nothing ever listens**.
3. The catch block's comment asserts *"the stream subscription remains the
   fallback source of truth"*. **That premise is wrong**, and the same file
   says so twenty lines earlier: the power-state stream is *"fed by
   broadcast receivers that fire on TRANSITIONS only"*. With no transition,
   nothing arrives. There is no fallback.
4. `_applyPlan()` then latches:
   `if (_discoveryAllowed == plan.discoveryAllowed) return;`. Nothing retries
   a `startDiscovery()` that failed.

That is a single un-retried, exception-swallowing path to the app's only
automatic listener startup, with a fallback that cannot fire.

## Evidence

Reproduced cleanly after force-stopping and relaunching **both** apps, with
all Bluetooth permissions already granted, and **no Discover tapped**:

```
=== B (sender) ===            === A (recipient) ===
sent  NODISCOVER-B-0231       (absent)
```

Tapping Discover on A delivered a previously stuck message immediately,
which is consistent with `ensureListening()` simply never having run on A.

**One honest limit on this evidence:** it proves `_applyPlan()` did not
result in a listener on A. It does **not** independently prove *which* of
the two failure modes above occurred (a thrown `powerState()` vs. some other
reason the plan never applied). The structural fragility is proven from the
code regardless, and the fix should address the path, not one symptom.

## What happens next

A bug task against `lib/app/bindings.dart` — **outside the freeze**, so it
needs no exemption and no decision from the human. It must not swallow a
failed one-shot power read without either retrying or applying a plan, and
must not latch `_discoveryAllowed` on a `startDiscovery()` that failed.

## Lesson

The original request asserted *"I looked for one"* about a non-E04 fix and
did not name the mechanism that already existed. An argument for opening a
frozen file has to enumerate what it ruled out, by name — otherwise
"I found none" is an assertion, not a finding. The freeze did its job here:
it forced the argument to be written down, and writing it down is what
exposed that it was wrong.
