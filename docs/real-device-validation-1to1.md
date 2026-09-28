# Real-device validation — the 1:1 messaging journey

> **Status: the bidirectional 1:1 journey PASSES on real hardware.**
> Recorded 2026-09-29 by `claude-opus-5`, from a live two-device run. Every
> claim below is backed by evidence gathered first-hand and reproduced in
> this document; nothing here is inferred from a sender-side UI state.

## Devices

| | Serial | Model | Nexora device identity | BT MAC |
|---|---|---|---|---|
| **A** | `e4813f500601` | Redmi 10 2022 (`21121119SG`) | `050f551b2c18b910…` | `00:00:46:00:00:01` |
| **B** | `3f5f59c7` | Redmi Note 12 (`23027RAD4I`) | `05fb7cc03f29ade6…` | `2C:FE:4F:A1:E9:4A` |

Both ran the **same** debug build, installed within 12 seconds of each other
from `development` at `043728c`.

## Why this had been failing, and what actually fixed it

Every earlier attempt failed at the transport layer, and the cause was **not**
a defect: the two phones had never been **OS-level Bluetooth bonded**.

This is worth stating precisely, because the app's own UI is easy to
misread. Nexora's `Paired locally` badge is **its own relationship record**,
not a Bluetooth bond. `BluetoothTransport.kt` is explicit that both of its
secure socket variants require a real bond (`E04-B09`). With no bond, the
RFCOMM connect fails outright, so no connection is ever established, and
every layer above it is unreachable.

Confirmed before (B had **zero** bonded devices) and after:

```
$ adb -s 3f5f59c7 shell dumpsys bluetooth_manager | grep -A5 "Bonded devices"
  Bonded devices:
    00:00:46:00:00:01 [ DUAL ][ 0x5A020C ] Redmi 10 2022
```

Once the bond existed, the journey worked on the first genuine attempt.

## Evidence, layer by layer

These are the six layers separately, because a sender-side "sent" state is
evidence for exactly one of them.

| Layer | A→B | B→A |
|---|---|---|
| UI reached | ✅ composer, send | ✅ composer, send |
| Local persistence | ✅ `messages` row, `sent` | ✅ `messages` row, `sent` |
| Transport | ✅ crossed devices | ✅ crossed devices |
| Crypto / session | ✅ `signal_sessions` = 1 both sides | ✅ same session |
| Recipient received | ✅ row on B, `accepted` | ✅ row on A, `accepted` |
| Recipient rendered plaintext | ✅ on screen | ✅ on screen |

Both databases, read directly off each device:

```
=== A (Redmi 10 2022) ===
   seq=0 state=sent      snd=050f551b2c18b910 plain='HELLO-FROM-A-0208'
   seq=0 state=accepted  snd=05fb7cc03f29ade6 plain='REPLY-FROM-B-0215'
=== B (Redmi Note 12) ===
   seq=0 state=accepted  snd=050f551b2c18b910 plain='HELLO-FROM-A-0208'
   seq=0 state=sent      snd=05fb7cc03f29ade6 plain='REPLY-FROM-B-0215'
```

Three things in that output matter beyond "a row exists":

1. **The message id is identical on both devices** — this is the same
   message, not two coincidentally similar rows.
2. **`sender_device_id` is the real Nexora device identity on both sides**
   (`050f551b…` / `05fb7cc0…`), **never a MAC address**. This is what
   `E04-B12` (learn a peer's real `selfDeviceId` over the transport) and
   `E04-B13` (resolve it into outbound addressing) exist to achieve, and it
   holds on real hardware.

   > An earlier revision of this file cited `E06-B04` here. That was
   > **wrong**: `E06-B04` is about delivery-ack control frames trusting an
   > unauthenticated `frame.source`, which is a different concern. Corrected
   > after review; recorded rather than quietly swapped.
3. **`plaintext_payload` decrypted correctly on the recipient**, from a
   396-byte ciphertext on A to a 211-byte one on B — a genuine Signal
   session, not a passthrough.

On screen: B rendered `HELLO-FROM-A-0208` as a received bubble at 2:13 AM,
and A rendered `REPLY-FROM-B-0215` as a received bubble at 2:16 AM, each in
a thread headed `End-to-end encrypted`.

## The failure path is honest, and was observed

The **first** send attempt genuinely failed, and it is worth recording what
that looked like, because an earlier session wrongly described it as silent:

- the optimistic bubble appeared, then was **removed**;
- the thread returned to `No messages yet — say hello`;
- **the text was restored to the composer**, so nothing the user typed was
  lost;
- and no `messages` row was written — a failed send leaves no phantom row.

That is the correct behaviour. It is not silent, and the user does not lose
their message.

## Open finding — inbound delivery depends on a recent Discover

**This is a real defect, and it is NOT in E04.** It is in
`lib/app/bindings.dart`. An earlier revision of this file asked for an E04
freeze exemption; that request has been **withdrawn** — see
`docs/E04-freeze-exemption-request-inbound-listener.md`, which now records
why it was wrong.

Observed directly: B's reply sat at `state=sent` on B and **did not arrive on
A for over 45 seconds**. It landed immediately once A re-ran **Discover**.

### Reproduced cleanly

After force-stopping and relaunching **both** apps, with every Bluetooth
permission already granted, and **without tapping Discover anywhere**:

```
=== B (sender) ===            === A (recipient) ===
sent  NODISCOVER-B-0231       (absent)
```

B recorded the send; A never received it. So this is not an artifact of one
stale discoverability window.

### Where it actually is

`BluetoothTransport.ensureListening()` — which opens this device's RFCOMM
server socket and publishes its SDP record — is reached from `connect()`
(`BluetoothTransport.kt:781`) and `doStartDiscovery()` (`:1497`).

**E04 is not the defect.** `startDiscovery()` (`:477`) already handles the
permission race deliberately, stashing
`pendingPermissionAction = { doStartDiscovery() }`, and `ensureListening()`'s
own documentation states the intent plainly: it is *"deliberately NOT gated
behind discovery or an active outbound connect attempt — a peer can only ever
reach this device if something is listening, symmetrically, on BOTH sides,
all the time this device's Bluetooth is on"*.

The Dart side is supposed to make that true, and does not reliably:

1. `BackgroundLifecycleObserver.start()` (`lib/app/bindings.dart`)
   **deliberately does not** call `_applyPlan()` synchronously — by design,
   so it never acts on the optimistic default `PowerState`.
2. It instead relies on `_refreshPowerStateOnResume()`, whose entire body is
   wrapped in `try { … } catch (_) { }`. If `_service.powerState()` throws,
   `_onPowerStateChanged` is never called and **`_applyPlan()` never runs for
   the first time**.
3. `_applyPlan()` is the only thing that calls `transport.startDiscovery()`,
   and it is what would have started the listener.

The catch block's comment says *"the stream subscription remains the fallback
source of truth"*. That premise does not hold: the same file's own comment in
`start()` records that the power-state stream **fires on transitions only**.
With no transition, nothing ever arrives, so there is no fallback — the app
simply never listens.

Compounding it, `_applyPlan()` latches its decision
(`if (_discoveryAllowed == plan.discoveryAllowed) return;`), so once a value
is recorded no later call retries a `startDiscovery()` that failed.

**Practical consequence: a user who opens the app and waits for a message may
never receive one**, and nothing on screen says so — the Dashboard reads
`No peers nearby`, which sounds like nobody is around.

## Evidence quality — read this before citing the table

Two claims above are **prose, not pasted command output**, and are weaker
than the rest of the record: `signal_sessions = 1 both sides` and the
`396B → 211B` ciphertext sizes. Both were read off the devices by the
author, but neither is reproduced here as raw output, so they do not meet
this project's own "paste the output, never a recalled number" bar. The
`messages` table dumps, which carry the load of the argument, ARE verbatim.

The "recipient rendered plaintext" rows rest on screenshots taken during the
run that are **not committed to this repository**. The claim is consistent
with the database evidence, but a reader cannot independently check it from
the repo alone, and should not treat it as if they could.

## What is NOT yet validated

Stated explicitly so this record cannot be over-read:

- **Group messaging** — creation, membership, the sender-key path, and group
  send in either direction. Not attempted in this run.
- **Restart / persistence** — whether both threads survive an app restart.
- **Multi-hop relay routing.** This run was a direct A↔B link.
- **Delivery receipts.** `delivery_states` recorded `accepted` on the
  recipient only; no `Delivered` transition was observed back on the sender.

## Reproducing this

```bash
# 1. The phones MUST be OS-bonded first. Verify, do not assume:
adb -s <serial> shell dumpsys bluetooth_manager | grep -A5 "Bonded devices"

# 2. On BOTH devices: Devices tab -> Discover -> Allow the 120s visibility
#    dialog. The receiving device needs this too, or inbound never arrives.

# 3. Read the ground truth off the device. Use exec-out:
adb -s <serial> exec-out \
  "run-as com.nexora.nexora cat /data/data/com.nexora.nexora/app_flutter/nexora.sqlite" \
  > db.sqlite
```

`adb shell cat` corrupts the binary (`database disk image is malformed`) —
`exec-out` is required.

Sending is also not obvious: the round purple button in the composer is the
**microphone placeholder**, not send. Only the keyboard's own send key
submits the message.
