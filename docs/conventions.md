# Conventions — NEXORA

> Genesis T02. Small decisions that cost nothing now and cost an epic later
> when two modules disagree. Amend via a PR, not silently.

## Project structure (GetX + MVC + Clean Architecture — ADR-0002)

Per [SHAJED99/getx_mvc](https://github.com/SHAJED99/getx_mvc):

```
lib/
  core/
    design/            # tokens from design/screens/*.md — colors, type, spacing
    persistence/       # Drift database, DAOs (ADR-0001)
    transport/         # Pigeon-generated bindings + Dart-side transport facade (ADR-0004)
    crypto/             # Signal-protocol session/ratchet wrappers (ADR-0003)
    auth/               # Firebase Auth wrapper + local device-session store (ADR-0005)
    routing_engine/     # cost-function + migration logic (feature epic, not genesis)
    observability/      # Sentry (or equivalent) init + scoped logger (ADR-0006)
  features/
    <domain>/
      presentation/     # Views (widgets) + Controllers (GetX)
      domain/           # use cases, entities
      data/             # repositories, data sources (wrap core/persistence, core/transport)
  app/
    routes.dart          # named routes, bound to design/screens/*.md ids
    bindings.dart
    main.dart
```

Native Android code lives under `android/` per standard Flutter layout;
Pigeon schema definitions live in `pigeons/` at repo root, generated output
goes to `lib/core/transport/generated/` (Dart) and the matching Kotlin
package (native) — never hand-edited.

## Naming

- Files: `snake_case.dart`. Classes: `PascalCase`. GetX controllers:
  `<Feature>Controller`. Views: `<Feature>View` / `<Feature>Screen`.
- Drift tables: plural snake_case (`messages`, `group_members`). Dart table
  classes: singular PascalCase (`Message`, `GroupMember`).
- Route names match `design/screens/<id>.md` ids exactly (`/welcome`,
  `/login`, `/dashboard`, `/conversations`, `/chat/:id`, `/devices`,
  `/settings`) — see `docs/routes.md` (T04).

## Error handling

One envelope for every error surfaced across a layer boundary
(data → domain → presentation):

```dart
sealed class AppFailure {
  final String code;       // stable, greppable: 'auth.session_expired'
  final String message;    // user-safe, localized key — never raw exception text
  final Object? cause;      // original exception, logged, never shown
}
```

- Never surface a raw exception message to the UI — map it to an
  `AppFailure` with a stable `code`.
- Diagnostics (ADR-0006) log `code` + `cause` type — never message content,
  keys, voice data, or location (FR-DIAG-002, non-negotiable).

## Pagination / large lists

Conversation and message lists (local Drift queries) use keyset pagination
(`WHERE created_at < :cursor ORDER BY created_at DESC LIMIT :n`) — never
offset-based, since Smart Mode storage pruning can shift offsets under a
live scroll.

## Enums

Dart `enum` for closed sets that map to Drift columns (e.g. message delivery
state — `F-032`: Queued/Sent/Accepted/Delivered/Stored/Read/Failed) are
stored as their `name` string, not an integer index — integer indices break
silently on reordering; strings are diffable in migrations.

## Logging

Structured, leveled (`debug`/`info`/`warn`/`error`), routed through
`core/observability`. Never `print()` in `lib/`. Every log call is subject
to FR-DIAG-002 — no plaintext, keys, voice/call content, or precise location.

**Vendor pick (E13-T06, PROPOSED — not yet approved):** `sentry_flutter`,
per `ADR-0006`'s own named example. `ObservabilityService` now exposes an
`ObservabilityClient` injection seam (`lib/core/observability/
observability_service.dart`) a `SentryObservabilityClient` adapter drops
into once the package clears the pubspec.yaml `new_dependency` human gate
below — `init()`/`log()`/`logError()`'s public signatures do not change
when that happens, so no existing call site is touched. Hosting
(self-hosted vs. managed) is left for that same follow-up to record,
per `ADR-0006`'s closing line. Until approved, `ObservabilityService`
defaults to the same best-effort console behaviour (debug builds only)
the genesis stub had.

## UI widget kit

Three packages are the project's standard component layer, superseding raw
Material equivalents for their respective roles (human-directed adoption,
`new_dependency` gate, 2026-08-26):

- **`on_process_button_widget`** — every tappable action that does real
  async work (network calls, sign-in, form submission) uses
  `OnProcessButtonWidget`, not a bare `ElevatedButton`/`TextButton`. Its
  built-in `running`/`success`/`error` states are the project's standard
  way to show action feedback — don't hand-roll a separate spinner-in-button
  pattern alongside it.
- **`on_popup_window_widget`** — every dialog/popup uses
  `OnPopupWindowWidget`, not a bare `AlertDialog`/`showDialog` builder with
  ad hoc content. No screen uses this yet (first real dialog need: E02's
  blocking confirmation, or an error dialog).
- **`on_text_input_widget`** — every text field uses `OnTextInputWidget`
  (or `OnTextInputWidgetUserField` for login/registration-style fields with
  password toggling), not a bare `TextField`/`TextFormField`. No screen
  uses this yet (first real text input: likely E02's device-nickname/search
  field, or wherever the first free-text entry lands).

Reference: `welcome_view.dart`'s "Continue with Google" button is the first
real usage (`OnProcessButtonWidget`, `onTap` returning `null` since the
navigation itself is synchronous — no success/error state to show yet;
revisit once the button performs a real async sign-in call).

## Localization / RTL

All user-visible strings come from ARB-based localization resources (no
inline string literals in `presentation/`), per `design/` F-069. Layout uses
logical padding/alignment (`EdgeInsetsDirectional`, `start`/`end`) — never
literal `left`/`right`.

**Deviation (E00-T05, genesis walking skeleton, 2026-08-26):** the welcome
and login screens use inline string literals, not ARB resources. Reason:
adding `intl`/ARB scaffolding is itself a `new_dependency` (human gate) and
the genesis skeleton's job was to prove the architecture wired end to end,
not stand up localization infrastructure. This must not become house style
— the first feature epic that ships a real screen should either get ARB
scaffolding approved as a `new_dependency` or explicitly re-affirm inline
strings as the convention, not inherit the skeleton's shortcut silently.

## Schema migrations

Drift migrations are additive and tested — a migration step is never
allowed to drop a table/column containing user conversation data without an
explicit, human-approved ADR-level exception (FR-VER-003).

## Third-party dependency additions

Per rule 3 / `harness.yaml` `human_gates: new_dependency` — any package
beyond what's named in the accepted ADRs (Drift, Pigeon, a Signal-protocol
library, Sentry-or-equivalent, Firebase, GetX) requires a human-approved
addition, recorded as a one-line note here with the approving human gate.

- **2026-08-26** — `on_popup_window_widget` `^0.0.14`, `on_process_button_widget`
  `^2.0.13`, `on_text_input_widget` `^0.1.0` — human-directed (explicit
  request, not agent-proposed). See "UI widget kit" above.
- **2026-08-26** — `firebase_database` `^11.1.4` (E01-T02) — same Firebase
  project already named in ADR-0005/ADR-0006's accepted scope; adds the
  Realtime Database client needed for the account-id ↔ device-id metadata
  mapping (FR-FB-001/002), not a new foundational choice. **Superseded
  `cloud_firestore` `^5.6.12`** (added and removed the same day): Firestore
  requires the project to be on the Blaze billing plan just to provision a
  database at all; the human declined enabling billing, so this task moved
  to Realtime Database instead, which has no such requirement. If a future
  epic needs Firestore's richer query model, billing will need revisiting
  then — this isn't a permanent "no Firestore" rule, just what fit this
  task without billing.
