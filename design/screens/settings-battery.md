---
id: settings-battery
impl_path: /settings/battery
source: derived
derived_from: [settings-shell, settings, devices]
states: [default, loading, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-PLAT-004, FR-PLAT-001, FR-PLAT-002, NFR-BATT-001, FR-UI-006, FR-UI-007, FR-UI-008]
gap: GAP-037
---
# settings-battery · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **one row**: `settings.md` elements 33-37 (`battery_full_alt` · `Battery` ·
> `Background execution, power saving modes`).
>
> **Built against `GAP-037`, 🟡 proposed and NOT approved** (bare
> `approved by:`, `L-process-002`). `GAP-037` carries an **unresolved fork on
> the OS deep link** — BT12 below is contingent on it. Frame from
> `settings-shell.md` (`GAP-031`, also 🟡). **No golden until the build
> exists.**

- **Route:** `/settings/battery`. Registration and row wiring are **`E15-T11`'s**.
- **Source of truth:** `PowerState` and `BackgroundPolicy`/`BackgroundPlan`
  (`lib/core/background/`, shipped `E10`) and the background service's own
  running state. Read-only.

## The prohibition this screen exists to keep

**This screen does not reimplement Android's battery settings, and it does not
pretend to override them.** `FR-PLAT-004` says so explicitly. Doze, Battery
Saver and background-execution restrictions are **the operating system's
state**, reported here and changed only in the OS's own settings. A control on
this screen that appeared to turn Doze off would be a lie the platform will
win. The most this screen may offer is a way to *get to* the OS settings —
and even that is `GAP-037`'s open fork, because it needs a platform call the
Pigeon boundary does not have today (`ADR-0004`).

**And there is no user-facing power profile here.** `FR-STORE-003` fixes the
default voice profile as low-CPU/low-battery and gives the user no choice;
`NFR-BATT-001` is a system property, not a preference. A "battery saver mode"
switch would be inventing a setting the spec deliberately does not have.

## Elements — the build checklist

Frame: SH1-SH4, with SH3 = `Battery`.

| id | role | copy / label | styling source |
|---|---|---|---|
| BT1 | `heading:2` | `Battery` | SH3 |
| BT2 | `generic` | `What this device is allowed to do in the background, and what the system is restricting.` | SH4 |
| BT3 | `generic` | section card | SH5 |
| BT4 | `generic` | `battery_full_alt` glyph, `rgb(220, 233, 255)` | SH8, `settings.md` element 34 |
| BT5 | `heading:3` | `Background operation` | SH6 |
| BT6 | `generic` | `Running` / `Not running` | SH10 |
| BT7 | `generic` | `Discovery, message sync and calls continue while the app is closed — only while this is running.` | SH7 |
| BT8 | `generic` | section card | SH5 |
| BT9 | `heading:3` | `Restrictions in effect` | SH6 |
| BT10 | row ×3 | `Doze` / `Battery Saver` / `Background restricted`, each + `On` / `Off` / `Unknown` | SH7 + SH10 |
| BT11 | `heading:3` | `Current plan` | SH6 |
| BT12 | row | `Open system battery settings` + `chevron_right` — **contingent on `GAP-037`'s fork** | SH7 + SH9 |
| BT13 | `generic` | `Background state could not be read.` | SH13 |

BT10's three names are exactly `FR-PLAT-002`'s own three — Doze, Battery Saver,
background execution restrictions — not a longer list and not a shorter one.
`Unknown` is a real value, not a failure: a platform that does not report a
restriction is not the same as a restriction being off, and
`settings-network.md`'s "unavailable is not a value" rule applies here too.

BT11's plan is `BackgroundPlan`'s own rendering — one line stating what the
policy has decided to do under the current restrictions. It is the "why is the
app doing less right now" answer, which is the only question this screen is
really for.

## Copy — verbatim

- `Battery`
- `What this device is allowed to do in the background, and what the system is restricting.`
- `Background operation`
- `Running` · `Not running`
- `Discovery, message sync and calls continue while the app is closed — only while this is running.`
- `Restrictions in effect`
- `Doze` · `Battery Saver` · `Background restricted`
- `On` · `Off` · `Unknown`
- `Current plan`
- `Open system battery settings`
- `Background state could not be read.`

## States

1. **`default`** — two cards populated.
2. **`loading`** — frame and headings render, values unpopulated. No spinner.
3. **`error`** — BT13 replaces the affected card's values only.

No `empty` state: both cards render fixed sets, never a list that can be empty.

## Derivation boundary — what is NOT derived

1. **No battery percentage, no charge state, no "time remaining".** None is in
   any `FR-*`, none is drawn anywhere in the design, and every one of them
   duplicates a system UI the user already has. A battery screen that shows a
   battery percentage is the obvious wrong move here.
2. **No per-feature battery attribution** ("discovery used 4%"). Nothing in
   `lib/` measures it, and `NFR-BATT-001` is explicitly unnumbered
   (`[NEEDS NUMBER]`) — publishing a figure would be inventing the target the
   SRS says it does not have.
3. **No power-saving mode switch.** See §Prohibition.
4. **BT12 is not asserted.** `GAP-037`'s fork — add the platform call to the
   existing background Pigeon API, or ship read-only with no deep link — is
   **unanswered**. If it resolves as "no deep link", BT12 is simply absent and
   the contract's element list is BT1-BT11 plus BT13. An agent does not add a
   native-boundary call to satisfy a row.
5. **No graph of past restriction changes.** No history is stored, and storing
   one to display it would be new scope.
