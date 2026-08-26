---
status: accepted
date: 2026-08-26
proposed_by: claude-code (genesis T01)
decided_by: human, 2026-08-26
traces_to: [docs/domain/entities.md, docs/domain/flows.md, documentation/Design.md §92-96]
template: https://github.com/SHAJED99/getx_mvc
---

# ADR-0002 — Application architecture & state management

## Context
Design.md §92-96 sketches a `lib/core/design` + `features/<domain>/
{presentation,domain,data}` layout, but explicitly marks it *a suggestion,
not a contract* — the actual architecture and state-management approach are
genesis's to decide. The domain has real complexity that the architecture
must support cleanly: multiple long-lived background processes (route
engine, relay engine, sync engine per BRD §65's layered diagram), a lot of
async event-driven state (connection state, delivery state, route state all
changing independently and needing to notify UI), and a hard separation
requirement — UI must never see plaintext bypass the encryption layer, and
business logic must be testable without a device (BRD §60 requires a
testing/simulation framework).

## Options considered
1. **Clean/layered architecture + Bloc/Cubit** — pros: strict
   presentation/domain/data separation maps directly onto the "UI never
   touches plaintext directly" security boundary; Bloc's explicit event→state
   transitions are a strong fit for delivery-state/connection-state machines
   that are core to this domain; excellent testability (BRD §60's simulation
   framework can drive Blocs directly, headless). cons: more ceremony/
   boilerplate per feature; steeper learning curve.
2. **Riverpod (with a lighter layered structure)** — pros: less boilerplate
   than Bloc, compile-time-safe DI, good async support, increasingly the
   Flutter community's default. cons: state-machine modeling is less
   explicit than Bloc's (events/states aren't first-class), which matters
   more here than in a typical CRUD app given how many independent state
   machines this domain has (route, connection, delivery, sync, call).
3. **Provider + ChangeNotifier, ad-hoc layering** — pros: simplest, fastest
   to a walking skeleton, minimal ceremony. cons: ChangeNotifier's mutable-
   object model doesn't naturally express discrete state transitions;
   testability and enforcement of the plaintext/UI boundary rely on
   discipline rather than the architecture itself.

## Comparison matrix
| Criterion | Clean+Bloc | Riverpod | Provider |
|---|---|---|---|
| Fit for many independent state machines (route/connection/delivery/sync/call) | Strong | Moderate | Weak |
| Enforces "UI never touches plaintext" boundary structurally | Strong | Moderate | Weak |
| Headless testability (BRD §60 simulation framework) | Strong | Strong | Moderate |
| Dev speed to walking skeleton | Slower | Fast | Fastest |
| Long-term maintainability at this domain's complexity | Strong | Moderate | Weak |

## Agent recommendation (advisory — NOT the decision)
**Clean/layered architecture with Bloc/Cubit for state management.** This
domain has more genuinely independent, long-lived state machines (route,
connection, delivery, sync, call, version-policy) than a typical app, and
Bloc's explicit event→state model is the most natural fit for that shape —
plus it structurally supports the encryption-boundary and headless-testing
requirements the BRD states outright. The added ceremony is a real cost, but
it buys back at every one of the ~20 epics this domain implies.

*(This option wasn't on the table above — the human's pick. Recorded here
for the record, not scored against the matrix, since it arrived after the
recommendation was made.)*
4. **GetX + MVC + Clean Architecture**, per the human-supplied template
   [SHAJED99/getx_mvc](https://github.com/SHAJED99/getx_mvc) — per-feature
   folders under `controllers/screen_controllers/<feature>/` each holding
   `controller.dart` (GetX `.obs` reactive state + presentation logic),
   `repository.dart` (data access), and `use_case.dart` (business logic
   between the two); shared `core/` (http, theme, localization, environment,
   base `UseCase`), `models/`, `utils/`, and `views/screens/<feature>/` +
   `views/widgets/` for UI. DI via `Get.put()`/`Get.lazyPut()`/`Get.find()`,
   routing via `GetMaterialApp` + named routes, an auth-guard middleware
   pattern already present in the template.

## Decision
✅ **ACCEPTED** — chosen option: **GetX + MVC + Clean Architecture** (template: [SHAJED99/getx_mvc](https://github.com/SHAJED99/getx_mvc))
- decided_by: human, 2026-08-26

## Consequences
- **Folder convention locked in** for `docs/conventions.md` (T02): every
  screen/feature gets `controllers/screen_controllers/<feature>/{controller,
  repository,use_case}.dart` + `views/screens/<feature>/`. This becomes the
  binding pattern every task file's `files:` list follows — no per-task
  reinvention.
- **State machines** (route, connection, delivery, sync, call, version-
  policy) that ADR-0002's original analysis flagged as the domain's real
  complexity now live as GetX controllers with `.obs` reactive fields,
  observed via `Obx()` — the discipline of keeping each controller's
  responsibility narrow (one state machine per controller, not a god-
  controller) is a review-time concern to watch for, not something the
  framework enforces structurally the way Bloc's explicit states would have.
- **The "UI never touches plaintext" encryption boundary** (constitution
  §2) is not structurally enforced by GetX the way a stricter layered
  approach might; it becomes a convention to state explicitly in
  `docs/conventions.md` and a review checklist item, not a compiler-checked
  guarantee.
- **DI** via `Get.put()/find()` is service-locator-style rather than
  compile-time-checked — acceptable trade-off per the human's choice, worth
  noting `use_case.dart` as the seam where headless testing (BRD §60's
  simulation framework requirement) should target, since it's the layer
  between controller (UI-adjacent) and repository (data-adjacent).
- **Follow-up task**: adapt the template's `lib/src/` skeleton into this
  repo during T04 (Skeleton + maps), keeping its naming exactly (not
  reinterpreting `screen_controllers` vs `data_controllers` split).
