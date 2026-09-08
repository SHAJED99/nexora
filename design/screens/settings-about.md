---
id: settings-about
impl_path: /settings/about
source: derived
derived_from: [settings-shell, settings, version-update-required, settings-storage]
states: [default, loading, empty, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-VER-012, FR-VER-005, FR-VER-008, FR-DIAG-001, FR-DIAG-002, FR-UI-006, FR-UI-007, FR-UI-008]
gap: GAP-038
---
# settings-about · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **one row**: `settings.md` elements 43-47 (`info` · `About / Updates` ·
> `Version 2.4.1, release notes, diagnostic logs`).
>
> **Built against `GAP-038`, 🟡 proposed and NOT approved** (bare
> `approved by:`, `L-process-002`). Frame from `settings-shell.md`
> (`GAP-031`, also 🟡). **No golden until the build exists.**

- **Route:** `/settings/about`. Registration and row wiring are **`E15-T11`'s**.
- **Source of truth:** `PackageInfo` via `readInstalledBuildNumber`
  (`lib/app/main.dart`), `VersionPolicyService.cached()`, and
  `EvaluateVersionStateUseCase` — all shipped by `E14`, none re-implemented
  here. The diagnostic log comes from `ObservabilityService`.

## The two prohibitions this screen exists to keep

**1. `Version 2.4.1` is a disclosed copy artifact on the HUB row, and must stay
there.** `settings.md` element 46 measures the literal string
`Version 2.4.1, release notes, diagnostic logs`, and the design gate compares
it character for character. **The real build number is not 2.4.1 and never will
be.** `E02-T03` already built that row and it already passes its gate. Do not
"fix" it into a dynamic value — that reds the `settings` gate for a screen this
epic is not otherwise touching. **This sub-screen shows the real version**;
the hub row keeps the design's literal copy. Same class of artifact as
`GAP-027`'s "export", recorded so the next agent does not rediscover it as a
bug.

**2. `FR-DIAG-002` binds the log section absolutely.** No plaintext, no keys, no
session material, no location. `ObservabilityService` already logs **codes**
(`version.installed_build_read_failed`, `recovery.device_identity_read_failed`,
…) rather than content, and this screen renders those codes and their
timestamps — nothing else. It does not "expand" an entry into its cause object,
because a cause object is exactly where a stack trace carrying real data would
be.

## Elements — the build checklist

Frame: SH1-SH4, with SH3 = `About`.

| id | role | copy / label | styling source |
|---|---|---|---|
| AB1 | `heading:2` | `About` | SH3 |
| AB2 | `generic` | `This build, the version policy it is checked against, and what has gone wrong recently.` | SH4 |
| AB3 | `generic` | section card | SH5 |
| AB4 | `generic` | `info` glyph, `rgb(220, 233, 255)` | SH8, `settings.md` element 44 |
| AB5 | `heading:3` | `This build` | SH6 |
| AB6 | `generic` | `Version` + version string (machine value) | SH7 + SH11 |
| AB7 | `generic` | `Build` + build number (machine value) | SH7 + SH11 |
| AB8 | `generic` | `Status` + one of `Up to date` / `Update available` / `Update required` | SH7 + SH10 |
| AB9 | `generic` | section card | SH5 |
| AB10 | `heading:3` | `Version policy` | SH6 |
| AB11 | `generic` | `Minimum supported build` + value (machine value) | SH7 + SH11 |
| AB12 | `generic` | `Last checked` + timestamp | SH7 + SH11 |
| AB13 | `generic` | `No policy has been fetched yet. This build is treated as supported until one is.` | SH13 |
| AB14 | `generic` | section card | SH5 |
| AB15 | `heading:3` | `Diagnostics` | SH6 |
| AB16 | row ×N | log code (machine value) + timestamp | SH11 + SH7 |
| AB17 | `generic` | `Nothing has been logged.` | SH13 |
| AB18 | `generic` | `Version information could not be read.` | SH13 |

AB8's three strings are `VersionState`'s three values, rendered in this app's
own words. They are fixed copy.

AB13 is not an error line — it states the **fail-open default** that
`EvaluateVersionStateUseCase` actually applies when no policy is cached
(`E14-B01`'s whole subject). A user looking at an empty policy card deserves to
know which way the app fails, rather than guessing.

## Copy — verbatim

- `About`
- `This build, the version policy it is checked against, and what has gone wrong recently.`
- `This build`
- `Version` · `Build` · `Status`
- `Up to date` · `Update available` · `Update required`
- `Version policy`
- `Minimum supported build`
- `Last checked`
- `No policy has been fetched yet. This build is treated as supported until one is.`
- `Diagnostics`
- `Nothing has been logged.`
- `Version information could not be read.`

## States

1. **`default`** — three cards populated.
2. **`loading`** — frame and headings render, values unpopulated. No spinner.
3. **`empty`** — AB13 (no cached policy) and/or AB17 (empty log), each
   independently. **Both are ordinary**: a device that has never had network
   has no policy, and a healthy device has nothing logged.
4. **`error`** — AB18 replaces the affected card's values only.

## Derivation boundary — what is NOT derived

1. **No release notes.** The hub row's subtitle promises them; **there is no
   release-note source, local or remote, and no FR requires one.** `GAP-038`
   carries the fork with **no proposal** — its option (b), a link out to the
   Play listing, is a dependency on a page this app does not control and is not
   assumed here.
2. **No "check for updates" button.** `FR-VER-008` already re-evaluates on
   reconnect (`VersionReconnectWatcher`, `E14-B06`) and `E14-T04` already
   evaluates at launch. A manual button would be a second trigger for a policy
   already checked twice, and it would need its own in-flight state — which
   this design has no spinner for.
3. **No update *action*.** `FR-VER-006`/`FR-VER-007`'s Play in-app update flow
   belongs to `version-update-required.md` and only to it. `Update available`
   at AB8 is a status word, not a button; an `UPDATE_AVAILABLE` nudge is
   explicitly out of scope per `GAP-029`'s own "out of scope" clause.
4. **No log export, share or copy.** Same reasoning as
   `settings-security-center.md` §4 — each is a route by which
   `FR-DIAG-002`-protected content leaves the device.
5. **No licences, credits, privacy-policy or terms links.** All four are
   conventional on an About screen; none is in `spec/`, and three of them point
   at documents this project does not have.
6. **No log level filter or clear-log control.** Unspecified, and clearing a
   diagnostic log from the UI is a state change on an audit surface.
