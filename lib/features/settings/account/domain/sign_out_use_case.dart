// features/settings/account/domain — SignOutUseCase (E15-T01, `FR-AUTH-006`,
// `FR-AUTH-008`; ordering fix E15-T12).
//
// The one call `E15-T07`'s confirm button makes: best-effort revoke ->
// teardown -> wipe -> best-effort auth clear, in that binding order. This
// ordering was corrected during `E15-T12`'s own implementation (see that
// task's §9 Deviations for the full history) from the task's original
// contract ("teardown -> wipe -> best-effort revoke -> auth clear"), because
// `revoke`'s production implementation (`DeviceRevocationService.revoke()`)
// performs an unconditional LOCAL database write as its very first
// statement, before its remote Firebase push -- it needs a LIVE `AppDatabase`
// connection. Running `revoke` after `teardown` (which closes that
// connection) made the local write throw on every single sign-out,
// deterministically, which meant the call never reached the Firebase push at
// all -- silently defeating `Q-SEC-009`(b)'s whole point. `teardown` must
// still run before `wipe` (E15-T01's own reasoning: other singletons must
// release their handle on the database file before the file itself is
// deleted), so `revoke` moves to the front instead. `revoke`'s own local
// write surviving is irrelevant here regardless -- the whole database gets
// wiped moments later by `wipeService.wipe()`, so there is no "next launch"
// for that local row to matter to. Headless-testable without a device or a
// real UI, matching every other `domain/*_use_case.dart` in this app
// (ADR-0002) — this file imports no GetX and no `MessagingStack`, the
// same "no framework dependency in the domain layer" discipline
// `sign_in_use_case.dart` already holds to.
//
// [teardown] is this use case's own injection point for "close and
// unregister every in-memory singleton holding a handle to the database
// file" (task §2 item 3, §5 ordering) — `AppDatabase`, `MessagingStack` and
// every repository singleton are all registered via GetX in
// `lib/app/bindings.dart`, which is **not** in this task's `files:` fence
// (§4: "does NOT change ... bindings.dart"). Defaults to a no-op here;
// wiring the real GetX-aware teardown closure is the job of whichever
// presentation-layer file actually constructs a production `SignOutUseCase`
// (`E15-T07`'s `AccountController`/`SignOutConfirmController`, which -- as
// GetX controllers -- may import GetX/`MessagingStack` where this domain
// file must not). See this task's self-review Deviations.
//
// [revoke] (E15-T12, `Q-SEC-009`(b)) is the same shape of seam for
// "best-effort remote device-registry revoke" -- `DeviceRevocationService`
// needs a `uid`/`deviceId` and an `AppDatabase` handle, none of which this
// domain file may import (same "no framework/service dependency in the
// domain layer" discipline as [teardown] above). Defaults to a no-op;
// `settings_binding.dart` wires the real closure. Called BEFORE `teardown`
// (see the corrected ordering above) -- `revoke`'s own production
// implementation needs the database connection `teardown` is about to close.
//
// [call] performs no navigation (task §4) -- `E15-T07`'s confirm screen
// decides what comes next.
import 'package:nexora/core/auth/google_auth_service.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/session/local_data_wipe_service.dart';

class SignOutUseCase {
  SignOutUseCase({
    LocalDataWipeService? wipeService,
    GoogleAuthService? authService,
    Future<void> Function()? teardown,
    Future<void> Function()? revoke,
  })  : _wipeService = wipeService ?? LocalDataWipeService(),
        _authService = authService ?? GoogleAuthService(),
        _teardown = teardown ?? _noopTeardown,
        _revoke = revoke ?? _noopRevoke;

  final LocalDataWipeService _wipeService;
  final GoogleAuthService _authService;
  final Future<void> Function() _teardown;
  final Future<void> Function() _revoke;

  static Future<void> _noopTeardown() async {}
  static Future<void> _noopRevoke() async {}

  /// FR-AUTH-006/008, `Q-SEC-009`(b). Best-effort revoke -> teardown -> wipe
  /// -> best-effort auth clear, in that order (corrected during `E15-T12`'s
  /// own implementation -- see this file's header and that task's §9
  /// Deviations for why: `revoke`'s production implementation needs a LIVE
  /// `AppDatabase` connection for its own local-first write, so it must run
  /// before `teardown` closes that connection; `teardown` must still run
  /// before `wipe` deletes the database file out from under any singleton
  /// that has not yet released its handle). Both the revoke and the auth
  /// clear are best-effort and never fail this call (each caught and logged
  /// independently, even though neither's default production implementation
  /// throws out on its own today -- belt-and-braces against any other
  /// implementation either is ever handed); the wipe is not best-effort, and
  /// its failure (an [AppFailure]) propagates unchanged, leaving the
  /// sentinel in place for `E15-T02`'s `completePendingWipe()` to retry at
  /// next launch.
  Future<void> call() async {
    try {
      await _revoke();
    } catch (e) {
      ObservabilityService.instance.logError(
        'session.sign_out_revoke_failed',
        cause: e,
      );
    }
    await _teardown();
    await _wipeService.wipe();
    try {
      await _authService.signOut();
    } catch (e) {
      ObservabilityService.instance.logError(
        'session.sign_out_auth_clear_failed',
        cause: e,
      );
    }
  }
}
