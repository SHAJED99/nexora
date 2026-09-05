// core/background — E10-T09: the power-state model Dart sees, over the
// Pigeon boundary `background_service.dart` already talks through
// (ADR-0004, ADR-0007, FR-PLAT-002, FR-PLAT-003).
//
// `PowerState` itself is Pigeon-generated (`generated/background_api.g.dart`)
// with full value equality (`==`/`hashCode`) already included by the
// codegen — re-exported here rather than wrapped, mirroring how
// `background_service.dart` re-exports `ServiceState` instead of defining a
// parallel Dart-only type. `BackgroundService.powerStates` and
// `BackgroundStub.emitPowerState` both rely on that generated equality to
// de-duplicate consecutive equal states (task §5/§6, EARS-PLAT-11) — never
// re-emitted, never null, and never a thrown exception on a signal missing
// from the running API level.
//
// This file reports facts only — nothing in the app reacts to a
// [PowerState] yet (task §2/§4); that policy decision belongs to `E10-T10`.
import 'generated/background_api.g.dart';

export 'generated/background_api.g.dart' show PowerState;

/// The all-clear reading: no restriction observed, screen unlocked, not
/// ignoring battery optimisations. Used as the initial value for
/// [BackgroundStub] before any test calls `emitPowerState` — a stub that
/// starts by claiming Doze is already active would be a lie no test
/// intends.
///
/// A function, not a `const`/`final` shared instance: [PowerState]'s
/// generated fields are mutable, so a single shared instance could be
/// mutated by one caller and silently corrupt every other caller's
/// "all clear" reading.
PowerState allClearPowerState() => PowerState(
  deviceIdle: false,
  powerSaveMode: false,
  backgroundRestricted: false,
  ignoringBatteryOptimizations: false,
  screenLocked: false,
);
