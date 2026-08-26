# Data flow — walking skeleton (E00-T04/T05)

> How one tap becomes one real local write. Proportional on purpose — this
> is genesis's proof the architecture wires top to bottom, not a feature.

```mermaid
sequenceDiagram
    participant U as User
    participant WV as WelcomeView
    participant WC as WelcomeController
    participant LV as LoginView
    participant LC as LoginController
    participant UC as SignInUseCase
    participant R as DeviceIdentityRepository
    participant DB as AppDatabase (Drift/SQLite)
    participant HV as HomeView

    U->>WV: tap "Continue with Google"
    WV->>WC: continueWithGoogle()
    WC->>LV: Get.toNamed('/login')
    LV->>LC: onInit() -> _signIn()
    LC->>LC: signingIn = true (renders "Signing in with Google...")
    LC->>UC: call(deviceId)
    UC->>R: createDeviceIdentity(deviceId)
    R->>DB: INSERT INTO device_identities
    UC->>UC: await delay (stubbed OAuth round trip, 1-2s)
    UC->>R: markSignedIn(id)
    R->>DB: UPDATE device_identities SET signed_in = true
    LC->>LC: signingIn = false
    LC->>HV: Get.offNamed('/home')
    HV->>R: latestDeviceIdentity()
    R->>DB: SELECT ... ORDER BY id DESC LIMIT 1
    DB-->>HV: DeviceIdentity row
    HV->>U: "Signed in — device <id>"
```

## Narrative

Welcome (`lib/features/welcome/`) is purely navigational — its controller
has no domain/data layer because it makes no decisions and holds no state;
tapping the button hands off to `/login`. Login
(`lib/features/login/`) is where the real wiring lives: its
`LoginController` (presentation) calls `SignInUseCase` (domain), which is
a stand-in for the real Google OAuth round trip — a fixed delay instead of
a network call, per the task's explicit "do NOT implement real
Firebase/Google auth" boundary. The use case writes through
`DeviceIdentityRepository` (data) into `AppDatabase` (`core/persistence`,
Drift/SQLite — ADR-0001): one `INSERT`, then one `UPDATE` marking the row
signed in. On completion the controller navigates to `/home`
(`lib/features/home/`), a genesis-only placeholder that reads the same row
back through the same repository — proving the write is real, not just
fire-and-forget.

Nothing here touches `core/crypto`, `core/transport`, or `core/auth` — per
the task brief those stay structural stubs. `core/observability` is
initialized once in `main()` (a console no-op today) and is the only
`core/` service actually exercised end to end.
