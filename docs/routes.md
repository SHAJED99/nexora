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

`welcome`, `login`, `devices`, `settings`, `conversations`, `chat` and
`dashboard` all have generated contracts and are wired.
`settings`'s eight rows are a pure navigation menu — none of their
sub-screens (Account, Privacy & Security, etc.) have a design source yet;
see `design/gaps.md` GAP-005.

## Route wiring

Defined in `lib/app/routes.dart` (`Routes` + `appPages`), registered via
`GetMaterialApp(getPages: appPages)` in `lib/app/main.dart`. Adding a route:
add the constant to `Routes`, add a `GetPage` to `appPages`, add a row to
the tables above.
