# E04 freeze-exemption request — inbound delivery depends on a recent Discover

> **Status: 🧍 AWAITING HUMAN.** E04 is frozen. Nothing in this document has
> been implemented, and `BluetoothTransport.kt` has not been modified.
> Raised 2026-09-29 by `claude-opus-5` from direct hardware observation.

## The ask, in one line

Permission to change **where `ensureListening()` is called from** in
`android/app/src/main/kotlin/com/nexora/nexora/transport/BluetoothTransport.kt`
— and nothing else in E04.

## The exact code

`ensureListening()` opens this device's own RFCOMM server socket
(`listenUsingRfcommWithServiceRecord`) and publishes its SDP record. It is
defined at `BluetoothTransport.kt:503` and called from **exactly two
places**:

| Call site | Method |
|---|---|
| `BluetoothTransport.kt:781` | `connect()` |
| `BluetoothTransport.kt:1497` | `doStartDiscovery()` |

Both are commented `// E04-B06 -- see that method's own doc comment.`

There is **no** call on app start, on transport start, or on entering a
conversation.

## The observed defect

During the 1:1 validation run (`docs/real-device-validation-1to1.md`):

- A→B succeeded, because **A initiated**, so A's own `connect()` ran and B
  had previously run Discover.
- B→A then sat at `state=sent` in B's database and **did not arrive on A for
  over 45 seconds**, across two separate checks.
- It landed **immediately** once A re-ran Discover from the Devices tab.

So a device that has the app open, is bonded, and is sitting in the
conversation is **not necessarily accepting inbound connections**.

Two things make this worse in ordinary use:

1. Each Discover raises the system dialog *"nexora wants to make your phone
   visible to other Bluetooth devices for 120 seconds"*. That window
   **expires**, and nothing re-arms it.
2. Nothing on screen tells the user any of this. The Dashboard says
   `No peers nearby`, which reads as "nobody is around", not "tap Discover
   or you will not receive anything".

**User-visible consequence: someone who opens Nexora and waits for a message
may simply never receive one.** That is not a corner case; it is the normal
way a person uses a messaging app.

## Why no fix outside E04 is valid

I looked for one, because the freeze is real and I would rather not ask.

- **The listener is native.** The server socket and its SDP record exist only
  in `BluetoothTransport.kt`. No Dart-side code can open one.
- **Calling `startDiscovery()` from Dart on a timer is not the same fix, and
  is worse.** It would re-trigger the 120-second visibility **system dialog**
  repeatedly, which is user-hostile, and it would run a full BT scan purely
  as a side effect of wanting to listen. It also does not fix the underlying
  fact that listening is coupled to discovering.
- **Calling `connect()` speculatively is not valid either** — it changes
  outbound behaviour and bond-retry backoff (`E04-B29`) to achieve an
  inbound effect.

The honest fix is to call `ensureListening()` when the transport starts, so
that listening is a property of *the app running* rather than a side effect
of two unrelated actions. That is a one-line-scope change, in E04.

## What I would change, precisely

Add a call to `ensureListening()` at transport start, leaving both existing
call sites untouched (they are idempotent by construction — the method
already distinguishes "listening already in progress", per its own doc at
`BluetoothTransport.kt:439`).

Explicitly **not** proposed:

- no change to `connect()`'s own logic, the bond checks (`E04-B09`), or the
  bond-retry backoff (`E04-B29`);
- no change to discovery, SDP filtering (`E04-T07`) or the accept loop's
  threading model (`BluetoothTransport.kt:431–456`, which is delicate and
  documented as such);
- no change to the visibility/discoverability request;
- no change to any Dart-side routing, addressing or the destination gate.

## If you would rather not open E04 at all

That is a legitimate call, and the honest consequence should be recorded
rather than hidden: **1:1 messaging works, but only when the receiving user
has recently tapped Discover.** If the freeze holds, this belongs in
`CHANGELOG.md` §Known gaps and should block any claim that the app is
generally usable for receiving messages.

## Decision

- [ ] 🧍 Exemption **granted** — scope limited to the above.
- [ ] 🧍 Exemption **refused** — record the gap instead.
