// features/settings/account/domain — SignOutUseCase (E15-T01, `FR-AUTH-006`,
// `FR-AUTH-008`).
//
// The one call `E15-T07`'s confirm button makes: teardown -> wipe -> auth
// clear, in that binding order (task §5). Headless-testable without a
// device or a real UI, matching every other `domain/*_use_case.dart` in this
// app (ADR-0002) — this file imports no GetX and no `MessagingStack`, the
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
  })  : _wipeService = wipeService ?? LocalDataWipeService(),
        _authService = authService ?? GoogleAuthService(),
        _teardown = teardown ?? _noopTeardown;

  final LocalDataWipeService _wipeService;
  final GoogleAuthService _authService;
  final Future<void> Function() _teardown;

  static Future<void> _noopTeardown() async {}

  /// FR-AUTH-006/008. Teardown -> wipe -> auth clear, in that order. The
  /// auth clear is best-effort and never fails this call (caught and logged
  /// here even though `GoogleAuthService.signOut()` already never throws out
  /// on its own -- belt-and-braces against any other implementation this
  /// method is ever handed); the wipe is not best-effort, and its failure
  /// (an [AppFailure]) propagates unchanged, leaving the sentinel in place
  /// for `E15-T02`'s `completePendingWipe()` to retry at next launch.
  Future<void> call() async {
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
