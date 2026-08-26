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

## Localization / RTL

All user-visible strings come from ARB-based localization resources (no
inline string literals in `presentation/`), per `design/` F-069. Layout uses
logical padding/alignment (`EdgeInsetsDirectional`, `start`/`end`) — never
literal `left`/`right`.

## Schema migrations

Drift migrations are additive and tested — a migration step is never
allowed to drop a table/column containing user conversation data without an
explicit, human-approved ADR-level exception (FR-VER-003).

## Third-party dependency additions

Per rule 3 / `harness.yaml` `human_gates: new_dependency` — any package
beyond what's named in the accepted ADRs (Drift, Pigeon, a Signal-protocol
library, Sentry-or-equivalent, Firebase, GetX) requires a human-approved
addition, recorded as a one-line note here with the approving human gate.
