---
id: settings-notifications
impl_path: /settings/notifications
source: derived
derived_from: [settings-shell, settings, settings-storage, devices]
states: [default, loading, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-NOTIFY-003, FR-NOTIFY-001, FR-NOTIFY-002, FR-UI-006, FR-UI-007, FR-UI-008]
gap: GAP-032
---
# settings-notifications · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **one row** for this journey: `settings.md` elements 38-42 (`notifications` ·
> `Notifications` · `Alerts, silent modes, LED behaviors`). There is no
> notifications sub-screen anywhere in the measured set.
>
> **Built against `GAP-032`, 🟡 proposed and NOT approved** — its `approved by:`
> line in `design/gaps.md` is deliberately bare (`L-process-002`). Frame comes
> from `design/screens/settings-shell.md` (`GAP-031`, also 🟡); this file
> describes **only this screen's own content** and may not change the frame.
>
> **No golden exists and `make design-verify SCREEN=settings-notifications`
> cannot run until the build does** — a derived screen has no extractable
> source, so its golden is extracted *from the build*, per `design-fidelity`
> §3, exactly as `device-enrollment.md` records. `E15-T04`'s reviewer should
> expect that and not read it as a missing artifact.

- **Route:** `/settings/notifications`, reached by tapping `settings.md`'s
  Notifications row (elements 38-42). **Registering the route and wiring the
  row is `E15-T11`'s job, not this task's** — see §Notes.
- **Source of truth for what this screen reads and writes:**
  `NotificationSettingsRepository` (`lib/core/notifications/`, shipped by
  `E10-T02`) — `isEnabled` / `setEnabled` / `watchEnabled` per category, and
  `privacyLevel` / `setPrivacyLevel`. This screen holds **no** second copy of
  any preference and no defaulting rule of its own. If a widget and the
  repository ever disagree, the repository wins and the widget is the bug.

## The two prohibitions this screen exists to keep

**1. There is no switch widget on this screen.** This design measures no
switch, toggle or checkbox anywhere (`settings-shell.md` §1). On/off is SH12 —
`radio_button_checked` / `radio_button_unchecked` — the same treatment
`settings-storage.md` SS14-16 uses and the human already approved. Written into
the contract because "just use a Switch, it's Material 3" is the obvious wrong
move here and `FR-UI-001` does not license inventing a primitive the design
never draws.

**2. `full` privacy is offered as a value, not as a working feature.**
`NotificationPrivacyLevel.full` (sender name + message preview) **has no
supported mechanism today**: plaintext is decrypted only in the screen layer
(`E06-T09.md:64-68`), and a background notification dispatcher is exactly the
kind of caller that constraint forbids — `notification_tables.dart`'s own
header says so in as many words, and `E10-T03` is the consumer that decides
what a stored `full` means. Per `FR-UI-007`, NT21 states this plainly on the
row. **Do not hide the option, and do not make it look functional.**

## Elements — the build checklist

Frame: SH1-SH4 from `settings-shell.md`, with SH3 = `Notifications` and
SH4 = the subtitle at NT2.

| id | role | copy / label | styling source |
|---|---|---|---|
| NT1 | `heading:2` | `Notifications` | SH3 |
| NT2 | `generic` | `Choose which alerts this device shows, and how much they reveal.` | SH4 |
| NT3 | `generic` | section card | SH5 |
| NT4 | `heading:3` | `Alerts` | SH6 |
| NT5 | `generic` | `notifications` glyph, `rgb(220, 233, 255)` | SH8, `settings.md` element 39 |
| NT6-NT14 | row ×9 | one per user-facing category — see §Categories | title SH6-weight body, secondary SH7, state SH12 |
| NT15 | `generic` | section card | SH5 |
| NT16 | `heading:3` | `Privacy` | SH6 |
| NT17 | `generic` | `lock` glyph, `rgb(103, 244, 183)` | SH8, `settings.md` element 5 (`lock`), colour from element 14 |
| NT18 | `generic` | `What a notification shows on a locked screen.` | SH7 |
| NT19 | row | `Hidden` / `Neither who nor what — "New message".` | SH12 + SH7 |
| NT20 | row | `Sender only` / `Who it is from, never what it says.` | SH12 + SH7 |
| NT21 | row | `Full` / `Not available — messages are decrypted only while the app is open.` | SH12 (rendered unselectable) + SH7 |
| NT22 | `generic` | empty/error line | SH13 |

### Categories — NT6…NT14, in this order

Exactly the nine user-facing values of `NotificationCategory`. The tenth,
`backgroundService`, is **absent by contract**: Android requires that
notification whenever the foreground service runs, so it is not a user
preference and `E10-T02` seeds no row for it. A tenth row here would be a
control that cannot work.

| # | category | title | secondary line |
|---|---|---|---|
| NT6 | `message` | `Messages` | `New text messages.` |
| NT7 | `voiceMessage` | `Voice messages` | `New recorded voice messages.` |
| NT8 | `ptt` | `Push to talk` | `Live push-to-talk audio.` |
| NT9 | `incomingCall` | `Calls` | `Incoming voice calls.` |
| NT10 | `connectionRequest` | `Connection requests` | `A device wants to connect.` |
| NT11 | `trustRequest` | `Trust requests` | `A device wants to be trusted.` |
| NT12 | `groupEvent` | `Group activity` | `Members added, removed, or roles changed.` |
| NT13 | `securityEvent` | `Security events` | `Revoked devices and blocked peers.` |
| NT14 | `storageWarning` | `Storage warnings` | `When local storage needs attention.` |

## Copy — verbatim

- `Notifications`
- `Choose which alerts this device shows, and how much they reveal.`
- `Alerts`
- `Messages` · `New text messages.`
- `Voice messages` · `New recorded voice messages.`
- `Push to talk` · `Live push-to-talk audio.`
- `Calls` · `Incoming voice calls.`
- `Connection requests` · `A device wants to connect.`
- `Trust requests` · `A device wants to be trusted.`
- `Group activity` · `Members added, removed, or roles changed.`
- `Security events` · `Revoked devices and blocked peers.`
- `Storage warnings` · `When local storage needs attention.`
- `Privacy`
- `What a notification shows on a locked screen.`
- `Hidden` · `Neither who nor what — "New message".`
- `Sender only` · `Who it is from, never what it says.`
- `Full` · `Not available — messages are decrypted only while the app is open.`
- `Settings could not be read.`

## States

1. **`default`** — both cards, every row showing its current state.
2. **`loading`** — the frame and both cards render with row states
   unpopulated. No spinner (`settings-shell.md` §3).
3. **`error`** — NT22 (`Settings could not be read.`) replaces the affected
   card's rows only. The other card is unchanged.

There is no `empty` state: the nine categories and three privacy levels are
fixed sets, never a list that can be empty.

## Derivation boundary — what is NOT derived

1. **No `LED behaviors` control.** The hub row's subtitle promises it; **no
   `FR-NOTIFY-*` id requires it and no code implements it.** This is the exact
   shape of `GAP-027` (the Storage row's "export"), which the human resolved as
   (c): no control, the subtitle stays a disclosed copy artifact. `GAP-032`
   carries the fork with **no proposal**; until it is answered, this screen has
   no LED element.
2. **No "silent modes" control.** Same reasoning, same fork. Android's own
   notification channels already own per-channel sound/vibration and the
   platform exposes that UI; duplicating it is scope `spec/` does not contain.
3. **No per-conversation muting.** Nothing in `FR-NOTIFY-*` mentions it, and it
   would belong on `chat.md`, not here.
4. **No test-notification button.** Tempting, undesigned, unspecified.

## Notes for the implementing agent
- `watchEnabled` is a stream — bind to it. A read-once render will go stale the
  moment anything else writes a preference.
- `E15-T04` does **not** touch `lib/app/routes.dart`,
  `settings_controller.dart` or `test/design/design_probe_test.dart`. Its own
  probe dump comes from its own fenced probe test file; `E15-T11` consolidates.
