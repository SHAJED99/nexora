---
id: settings-account
impl_path: /settings/account
source: derived
derived_from: [settings-shell, settings, devices, device-enrollment]
states: [default, loading, empty, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-AUTH-013, FR-AUTH-001, FR-AUTH-003, FR-AUTH-004, FR-AUTH-006, FR-AUTH-007, FR-UI-006, FR-UI-008]
gap: GAP-035
---
# settings-account · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **one row**: `settings.md` elements 8-12 (`account_circle` · `Account` ·
> `Profile, identity keys, linked devices`). No account screen, and **no
> sign-out affordance of any kind, exists anywhere in the measured set.**
>
> **Built against `GAP-035`, 🟡 proposed and NOT approved** (bare
> `approved by:`, `L-process-002`). `GAP-035` additionally carries an
> **unresolved fork on the destructive treatment**, inherited from `GAP-021`
> and shared with `sign-out-confirm.md` — AC14's styling below is written as
> the *neutral* option and must be revisited when that fork is answered.
> Frame from `settings-shell.md` (`GAP-031`, also 🟡). **No golden until the
> build exists.**

- **Route:** `/settings/account`. Registration and row wiring are **`E15-T11`'s**.
- **Source of truth:** `DeviceIdentities` (the signed-in `accountUid` and this
  device's own `deviceId`), the local Signal identity keypair for the
  fingerprint, and `FirebaseMetadataService.readOwnDeviceIds(uid)` for the
  linked-device list. The sign-out *action* is `E15-T01`'s use case; this
  screen never performs it.

## The prohibition this screen exists to keep

**AC14 navigates. It does not sign out.** Tapping Sign out goes to
`/settings/sign-out-confirm` (`sign-out-confirm.md`, `GAP-039`) and nothing
else happens. `FR-AUTH-007` requires an explicit confirmation naming what is
lost, and `FR-AUTH-006` destroys every key on the device — a one-tap path to
that from a settings list is the single worst affordance this product could
ship. Written into the contract, not only into the task, because the next
person to touch this screen inherits this paragraph.

**And there is no second destructive action here.** No "delete account", no
"reset keys", no "unlink device", no per-row remove on the linked-device list.
`FR-AUTH-013` names exactly one action; each of the others is either
unspecified scope or a remote operation whose security model is the open
subject of `Q-SEC-009`.

## Elements — the build checklist

Frame: SH1-SH4, with SH3 = `Account`.

| id | role | copy / label | styling source |
|---|---|---|---|
| AC1 | `heading:2` | `Account` | SH3 |
| AC2 | `generic` | `The account this app signs in with, and the device identity that is yours alone.` | SH4 |
| AC3 | `generic` | section card | SH5 |
| AC4 | `generic` | `account_circle` glyph, `rgb(137, 206, 255)` | SH8, `settings.md` element 9 |
| AC5 | `heading:3` | `Signed in as` | SH6 |
| AC6 | `generic` | the account identifier (machine value) | SH11 |
| AC7 | `generic` | `Google account. Signing in does not create your device identity — that is generated here, on this device.` | SH7 |
| AC8 | `generic` | section card | SH5 |
| AC9 | `heading:3` | `This device` | SH6 |
| AC10 | `generic` | this device's identity fingerprint (machine value) | SH11 |
| AC11 | `generic` | `Generated on this device. It has never left it, and it is not derived from your account.` | SH7 |
| AC12 | `heading:3` | `Linked devices` | SH6 |
| AC13 | row ×N | device id (SH11) + `This device` / `Linked` state label | SH11 + SH10, `devices.md` row shape |
| AC14 | `button` row | `Sign out` + `chevron_right` | SH6 title + SH9 — **neutral treatment, pending `GAP-035`'s fork** |
| AC15 | `generic` | `Erases everything on this device.` | SH7 |
| AC16 | `generic` | `No other devices are linked to this account.` | SH13 |
| AC17 | `generic` | `Account details could not be read.` | SH13 |

AC7 and AC11 are not filler. `FR-AUTH-002` (account identity ≠ device
identity) and `ADR-0005` are the least intuitive facts in this product, and
this is the one screen where both are on display at once. A user who does not
read them here will read the sign-out confirmation as "sign out of Google".

AC15 sits under AC14 deliberately: `FR-AUTH-007` requires the confirmation to
name what is lost, but a user should not have to *tap the destructive thing*
to learn it is destructive.

## Copy — verbatim

- `Account`
- `The account this app signs in with, and the device identity that is yours alone.`
- `Signed in as`
- `Google account. Signing in does not create your device identity — that is generated here, on this device.`
- `This device`
- `Generated on this device. It has never left it, and it is not derived from your account.`
- `Linked devices`
- `Linked`
- `Sign out`
- `Erases everything on this device.`
- `No other devices are linked to this account.`
- `Account details could not be read.`

## States

1. **`default`** — three cards and the sign-out row.
2. **`loading`** — frame and headings render, values unpopulated. No spinner.
3. **`empty`** — the linked-device list only: AC16, which is the ordinary state
   for a single-phone user. The other cards and **the sign-out row** are
   unchanged.
4. **`error`** — AC17 replaces the affected card's values. **The sign-out row
   is never hidden by a failed read** — a user must always be able to reach the
   confirmation screen, especially when something is wrong.

## Derivation boundary — what is NOT derived

1. **No avatar, no display name, no profile object.** The hub subtitle says
   `Profile`; this app has no profile entity and Google's display name/photo
   are not stored anywhere in `lib/`. AC6 is the account identifier and nothing
   more. Inventing a profile section from one word of a subtitle is the
   `GAP-027` mistake.
2. **No key-fingerprint comparison or QR verification.** `devices.md`'s
   `Verify` button already owns peer verification, and nothing in `FR-AUTH-*`
   asks for a self-verification flow here.
3. **No "switch account".** The human's 2026-09-08 decision explicitly rejected
   multi-identity switching. There is no such control, and `E13`'s
   carried-forward observation about two accounts on one device stays
   unreachable precisely because of that.
4. **No destructive colour asserted.** AC14 is written in the neutral row
   treatment. `GAP-035`'s fork — reuse `devices.md`'s `rgb(186, 26, 26)`, or
   carry the whole destructive weight on the confirmation screen — is
   **unanswered**, and it is the same decision `GAP-021` parked. An agent does
   not settle it by picking a colour.
