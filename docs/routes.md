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
Drift write is readable back — it is superseded by `/dashboard` once a
feature epic builds the real post-auth destination.

## Wired by feature epics

| Route | Screen id | Design contract | Feature module |
|---|---|---|---|
| `/devices` | `devices` | `design/screens/devices.md` | `lib/features/devices/` (E02-T02) |
| `/settings` | `settings` | `design/screens/settings.md` | `lib/features/settings/` (E02-T03) |

## Contracted, not yet wired (owned by their feature epics)

These have a design contract in `design/screens/` but no route/screen
implementation yet.

| Route | Screen id | Design contract |
|---|---|---|
| `/dashboard` | `dashboard` | `design/screens/dashboard.md` *(not yet generated — see design/sources.yaml)* |
| `/conversations` | `conversations` | `design/screens/conversations.md` *(not yet generated)* |
| `/chat/:id` | `chat` | `design/screens/chat.md` *(not yet generated)* |

`welcome`, `login`, `devices` and `settings` have generated contracts as of
E02-T03; `dashboard`, `conversations` and `chat` remain listed in
`design/sources.yaml`'s `screens:` table but their `design/screens/<id>.md`
files are produced by `make design-contract SCREEN=<id>` when their owning
feature epic starts. `settings`'s eight rows are a pure navigation menu —
none of their sub-screens (Account, Privacy & Security, etc.) have a
design source yet; see `design/gaps.md` GAP-005.

## Route wiring

Defined in `lib/app/routes.dart` (`Routes` + `appPages`), registered via
`GetMaterialApp(getPages: appPages)` in `lib/app/main.dart`. Adding a route:
add the constant to `Routes`, add a `GetPage` to `appPages`, add a row to
the tables above.
