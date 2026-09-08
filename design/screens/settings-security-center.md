---
id: settings-security-center
impl_path: /settings/security-center
source: derived
derived_from: [settings-shell, settings, devices, settings-storage]
states: [default, loading, empty, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-DIAG-003, FR-DIAG-001, FR-DIAG-002, FR-SEC-003, FR-ABUSE-001, FR-UI-006, FR-UI-007, FR-UI-008]
gap: GAP-034
---
# settings-security-center · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **one row**: `settings.md` elements 18-22 (`policy` · `Security Center` ·
> `Threat logs, network audits, certificates`).
>
> **Built against `GAP-034`, 🟡 proposed and NOT approved** (bare
> `approved by:`, `L-process-002`). Frame from `settings-shell.md`
> (`GAP-031`, also 🟡). **No golden until the build exists.**

- **Route:** `/settings/security-center`. Registration and row wiring are
  **`E15-T11`'s**.
- **Source of truth:** four tables the app already holds —
  `DeviceRevocations` (`E12`), `SignalTrustedIdentities` (`E03`),
  `Relationships` where the state is blocked (`E02`), and `RateLimitCounters`
  (`E13-T02`). Nothing on this screen computes a new security opinion; it
  renders records that already exist.

## The prohibition this screen exists to keep

**`FR-DIAG-002` is absolute here, and this is the single most likely screen in
the product to violate it.** A record renders as *what happened, to which
device id, and when* — never as *what was in it*. No key material, no session
material, no message plaintext, no location, not truncated, not
fingerprint-of-a-session, not "for debugging". The one identifier that may
appear is a **device id**, which is already public: `E11-B06` made it the hex
of the device's own identity **public** key, and `devices.md` already displays
device identifiers on a shipped screen.

**And this screen takes no action.** No unblock, no re-trust, no revoke, no
clear-log. It reports. Blocking and trust decisions have exactly one home
(`devices.md`) and must not gain a second; a "security log" that can also
change security state is how a read-only audit surface quietly becomes an
unreviewed control panel.

## Elements — the build checklist

Frame: SH1-SH4, with SH3 = `Security Center`.

| id | role | copy / label | styling source |
|---|---|---|---|
| SC1 | `heading:2` | `Security Center` | SH3 |
| SC2 | `generic` | `What this device has recorded about its own security. Nothing here can be changed from this screen.` | SH4 |
| SC3 | `generic` | section card | SH5 |
| SC4 | `generic` | `policy` glyph, `rgb(103, 244, 183)` | SH8, `settings.md` element 19 |
| SC5 | `heading:3` | `Revoked devices` | SH6 |
| SC6 | row ×N | device id (SH11) + `Revoked` state label + when | SH11 + SH10 + SH7 |
| SC7 | `generic` | `No device has been revoked.` | SH13 |
| SC8 | `generic` | section card | SH5 |
| SC9 | `heading:3` | `Trusted identities` | SH6 |
| SC10 | row ×N | device id (SH11) + `Trusted` state label + when first seen | SH11 + SH10 + SH7 |
| SC11 | `generic` | `No identities recorded yet.` | SH13 |
| SC12 | `generic` | section card | SH5 |
| SC13 | `heading:3` | `Blocked` | SH6 |
| SC14 | row ×N | device id (SH11) + `Blocked` state label | SH11 + SH10 |
| SC15 | `generic` | `You have not blocked anyone.` | SH13 |
| SC16 | `generic` | `Manage in Devices` + `chevron_right` | SH7 + SH9 |
| SC17 | `generic` | section card | SH5 |
| SC18 | `heading:3` | `Rate limits` | SH6 |
| SC19 | row ×N | limit name + count in the current window | SH7 + SH10 |
| SC20 | `generic` | `Nothing has been rate limited.` | SH13 |
| SC21 | `generic` | `Records could not be read.` | SH13 |

## Copy — verbatim

- `Security Center`
- `What this device has recorded about its own security. Nothing here can be changed from this screen.`
- `Revoked devices` · `Revoked` · `No device has been revoked.`
- `Trusted identities` · `Trusted` · `No identities recorded yet.`
- `Blocked` · `You have not blocked anyone.` · `Manage in Devices`
- `Rate limits` · `Nothing has been rate limited.`
- `Records could not be read.`

## States

1. **`default`** — four cards with records.
2. **`loading`** — frame and card headings render, lists unpopulated.
3. **`empty` — the expected state, not an edge case.** On a healthy install
   **all four lists are empty**, and that is the good outcome. Each section
   shows its own SH13 line independently; an all-empty screen is correct and
   must not read as broken. This is the same "empty is normal" reasoning
   `settings-storage.md` §States 3 already records for its plan list.
4. **`error`** — SC21 replaces the affected section's list only.

## Derivation boundary — what is NOT derived

1. **No certificates.** The hub row's subtitle promises them; **this app has no
   certificate concept at all** — `ADR-0003` is a Signal-protocol design with
   identity keys, not X.509. `GAP-034` carries the fork with **no proposal**.
   Renaming identity-key fingerprints to "certificates" to satisfy a subtitle
   was considered and rejected in that entry: it makes the copy true by making
   the concept false.
2. **No "network audits".** Same subtitle, same fork. Nothing in `lib/` audits a
   network, and `settings-network.md` already owns everything this app actually
   knows about its network.
3. **No severity colour, no badge, no count-in-the-hub.** `settings.md`
   measures no red and no badge, and `devices.md`'s `rgb(186, 26, 26)` carries
   destructive/blocked semantics a *record* does not have. Every row here is
   the ordinary row treatment; the state label carries the meaning.
4. **No export, no share, no copy-to-clipboard.** Each is an obvious addition
   to a log screen and each is a route by which `FR-DIAG-002`-protected content
   leaves the device. None is specified; none is drawn.
5. **No filtering, sorting or search.** `conversations.md` measures a search
   field, so a primitive exists — but nothing in `FR-DIAG-*` asks for one, and
   these lists are bounded by the size of a personal device's history.
