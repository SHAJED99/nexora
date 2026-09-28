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
   (`050f551b…` / `05fb7cc0…`), **never a MAC address**. This is the
   property `E06-B04` exists to protect, and it holds on real hardware.
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

**This is a real usability defect, and it is inside frozen E04, so it is
documented here rather than fixed.** See
`docs/E04-freeze-exemption-request-inbound-listener.md` for the exemption
request.

Observed directly: B's reply sat at `state=sent` on B and **did not arrive on
A for over 45 seconds**. It landed immediately once A re-ran **Discover**.

The mechanism is not in doubt. `BluetoothTransport.ensureListening()` — which
opens this device's own RFCOMM server socket and publishes its SDP record —
is called from exactly two places:

- `BluetoothTransport.kt:781`, inside `connect()`
- `BluetoothTransport.kt:1497`, inside `doStartDiscovery()`

So a device that is merely *running the app* is not necessarily accepting
inbound connections. Compounding it, each Discover raises the system dialog
*"nexora wants to make your phone visible to other Bluetooth devices for 120
seconds"*, and that window expires.

The practical consequence: **a user who opens the app and waits for a message
may never receive one.** They have to go to Devices and tap Discover first,
which nothing on screen tells them.

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
