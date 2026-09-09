# Routes — NEXORA

> Genesis T04. Route table for the walking skeleton, plus the routes not
> yet wired (owned by their feature epics). Route names bind to
> `design/screens/<id>.md` ids per `docs/conventions.md` "Naming".

## Wired in genesis (E00-T05)

| Route | Screen id | Design contract | Feature module |
|---|---|---|---|
| `/welcome` | `welcome` | `design/screens/welcome.md` | `lib/features/welcome/` |
| `/login` | `login` | `design/screens/login.md` | `lib/features/login/` |
| `/home` | *(none — genesis placeholder)* | — | `lib/features/home/` |

`/home` is not one of the 7 design-contracted screens in
`design/sources.yaml`. It exists only so the walking skeleton has
somewhere to land after the stubbed sign-in completes and to prove the
Drift write is readable back — it is now superseded by `/dashboard`
(E06-T12) as the actual post-login destination; the `/home` route itself
stays registered (its file is untouched) but `LoginController` no longer
navigates to it.

## Wired by feature epics

| Route | Screen id | Design contract | Feature module |
|---|---|---|---|
| `/dashboard` | `dashboard` | `design/screens/dashboard.md` | `lib/features/dashboard/` (E06-T12) — the post-login destination, superseding `/home` |
| `/devices` | `devices` | `design/screens/devices.md` | `lib/features/devices/` (E02-T02) |
| `/settings` | `settings` | `design/screens/settings.md` | `lib/features/settings/` (E02-T03) |
| `/conversations` | `conversations` | `design/screens/conversations.md` | `lib/features/conversations/` (E06-T10) |
| `/chat/:id` | `chat` | `design/screens/chat.md` | `lib/features/chat/` (E06-T11) |
| `/version-update-required` | `version-update-required` | `design/screens/version-update-required.md` | `lib/features/version/` (E14-T04) |
| `/device-enrollment` | `device-enrollment` | `design/screens/device-enrollment.md` | `lib/features/recovery/` (E12-T03) |
| `/settings/account` | `settings-account` | `design/screens/settings-account.md` | `lib/features/settings/account/` (E15-T07) |
| `/settings/sign-out-confirm` | `sign-out-confirm` | `design/screens/sign-out-confirm.md` | `lib/features/settings/account/` (E15-T07) — reached from `/settings/account`'s own sign-out row, not from a hub row |
| `/settings/privacy` | `settings-privacy` | `design/screens/settings-privacy.md` | `lib/features/settings/privacy/` (E15-T05) |
| `/settings/security-center` | `settings-security-center` | `design/screens/settings-security-center.md` | `lib/features/settings/security_center/` (E15-T06) |
| `/settings/network` | `settings-network` | `design/screens/settings-network.md` | `lib/features/settings/network/` (E15-T08) |
| `/settings/storage` | `settings-storage` | `design/screens/settings-storage.md` | `lib/features/settings/storage/` (E15-T09) |
| `/settings/battery` | `settings-battery` | `design/screens/settings-battery.md` | `lib/features/settings/battery/` (E15-T08) |
| `/settings/notifications` | `settings-notifications` | `design/screens/settings-notifications.md` | `lib/features/settings/notifications/` (E15-T04) |
| `/settings/about` | `settings-about` | `design/screens/settings-about.md` | `lib/features/settings/about/` (E15-T10) |

`welcome`, `login`, `devices`, `settings`, `conversations`, `chat`,
`dashboard`, `version-update-required`, `device-enrollment` and all nine
`settings/*` sub-routes above have generated contracts and are wired.
`settings`'s eight rows now navigate to real sub-screens (E15-T11,
`FR-UI-006`/`EARS-UI-8`) — closing `design/gaps.md` GAP-005 — instead of the
"Coming soon" acknowledgement E02-T03 shipped before those sub-screens
existed. All nine sub-routes share one `SettingsBinding`
(`lib/features/settings/presentation/settings_binding.dart`), which lazily
registers all nine sub-screen controllers.

## Route wiring

Defined in `lib/app/routes.dart` (`Routes` + `appPages`), registered via
`GetMaterialApp(getPages: appPages)` in `lib/app/main.dart`. Adding a route:
add the constant to `Routes`, add a `GetPage` to `appPages`, add a row to
the tables above.
