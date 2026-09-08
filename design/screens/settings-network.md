---
id: settings-network
impl_path: /settings/network
source: derived
derived_from: [settings-shell, settings, devices, dashboard]
states: [default, loading, empty, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-ROUTE-010, FR-DISC-001, FR-ROUTE-005, FR-ROUTE-007, FR-UI-004, FR-UI-006, FR-UI-007, FR-UI-008]
gap: GAP-036
---
# settings-network · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **one row**: `settings.md` elements 23-27 (`wifi_tethering` · `Network` ·
> `Data usage, mesh routing, proxy`).
>
> **Built against `GAP-036`, 🟡 proposed and NOT approved** (bare
> `approved by:`, `L-process-002`). Frame from `settings-shell.md`
> (`GAP-031`, also 🟡). **No golden until the build exists.**

- **Route:** `/settings/network`. Registration and row wiring are **`E15-T11`'s**.
- **Source of truth:** `TransportService` (which transports the platform
  reports) and `RoutingEngine` (`activeRouteFor`, and the `LinkQuality`
  measurements `recordLinkMeasurement` feeds). Read-only throughout.
- **Why this screen exists at all:** `FR-UI-004` requires that the default view
  says "You're connected" and that advanced technical detail — route,
  transport, latency — be **one tap away, not shown by default**. This is that
  one tap. The dashboard keeps its simple statement; the detail lives here.

## The two prohibitions this screen exists to keep

**1. Read-only. There is no routing knob on this screen.** No transport
enable/disable, no "prefer Wi-Fi", no relay toggle, no manual route pin. `FR-DISC-003`
explicitly forbids permanently restricting a transport to one feature, and
nothing in `spec/` gives the user a routing control. A settings screen invites
settings; this one reports.

**2. An unavailable signal renders as unavailable, never as a value.**
`FR-ROUTE-010` says so, and it matters because `FR-ROUTE-007`'s cost formula is
still `[NEEDS FORMULA]` (`Q-ARCH-004`) and `RouteCostCalculator` already
reports some factors as unavailable rather than defaulting them — the same
discipline `E08-T04` established for the eight storage factors. **A zero on
this screen means measured zero.** A missing measurement says `Not measured`.
Rendering `0 ms` for "we never measured latency" is the one bug this screen
exists to not have.

## Elements — the build checklist

Frame: SH1-SH4, with SH3 = `Network`.

| id | role | copy / label | styling source |
|---|---|---|---|
| NW1 | `heading:2` | `Network` | SH3 |
| NW2 | `generic` | `How this device is reaching the mesh right now.` | SH4 |
| NW3 | `generic` | section card | SH5 |
| NW4 | `generic` | `wifi_tethering` glyph, `rgb(195, 192, 255)` | SH8, `settings.md` element 24 |
| NW5 | `heading:3` | `Transports` | SH6 |
| NW6 | row ×N | transport name + `Available` / `Unavailable` state label | SH7 + SH10 |
| NW7 | `generic` | `No transport is available.` | SH13 |
| NW8 | `generic` | section card | SH5 |
| NW9 | `generic` | `router` glyph, `rgb(199, 196, 216)` | SH8, `settings.md` element 55 |
| NW10 | `heading:3` | `Active routes` | SH6 |
| NW11 | row ×N | destination device id (SH11) + hop summary + link quality | SH11 + SH7 + SH10 |
| NW12 | `generic` | `Direct` / `N hops` | SH10 |
| NW13 | `generic` | latency + loss, or `Not measured` | SH7 |
| NW14 | `generic` | `No route to anywhere yet.` | SH13 |
| NW15 | `generic` | `Network state could not be read.` | SH13 |

NW12's `Direct` string exists because a one-hop route is the common case and
`1 hops` reads as a bug. Both forms are fixed copy, compared character for
character.

## Copy — verbatim

- `Network`
- `How this device is reaching the mesh right now.`
- `Transports`
- `Available` · `Unavailable`
- `No transport is available.`
- `Active routes`
- `Direct`
- `Not measured`
- `No route to anywhere yet.`
- `Network state could not be read.`

## States

1. **`default`** — both cards populated.
2. **`loading`** — frame and headings render, lists unpopulated. No spinner.
3. **`empty`** — **the ordinary state on a device that is alone.** NW7 and/or
   NW14, each independently. A user in a room with no peers sees an empty
   Active routes list and that is correct, not an error — the same "empty is
   normal" reasoning `settings-security-center.md` and `settings-storage.md`
   both record.
4. **`error`** — NW15 replaces the affected card's list only.

## Derivation boundary — what is NOT derived

1. **No data usage.** The hub row's subtitle promises it; **nothing in `lib/`
   meters bytes**, and no `FR-*` id requires it. `GAP-036` carries the fork with
   **no proposal**. A byte counter is not a display problem — it is a metering
   feature, i.e. new scope with a new FR.
2. **No proxy.** Same subtitle, same fork. This app has **no proxy concept at
   all**; there is nothing to display and nothing to configure.
3. **No graph, chart or sparkline.** No measured contract in this design draws
   one, and `dashboard.md`'s connectivity treatment is textual. Inventing a
   chart primitive for latency history would invent a visual language.
4. **No cost breakdown per factor.** `FR-ROUTE-007`'s nine factors are real, but
   the formula that weighs them is unresolved (`Q-ARCH-004`), so a per-factor
   display would be publishing an unfinished decision as a fact. NW13 shows the
   two measurements that genuinely exist (latency, loss) and nothing else.
5. **No live-refreshing counter.** Bind to the engine's own updates; do not add
   a polling timer, and do not animate a number. `NFR-BATT-001` is not served by
   a settings screen that spins the radio.
6. **No relay statistics.** `FR-ROUTE-004`'s relay-held data is deliberately
   temporary and about *other people's* packets; surfacing it here would be a
   diagnostics feature with a privacy question attached, and nothing asks for it.
