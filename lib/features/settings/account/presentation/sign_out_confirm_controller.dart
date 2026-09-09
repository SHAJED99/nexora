// features/settings/account/presentation -- SignOutConfirmController
// (E15-T07, `FR-AUTH-006`/`FR-AUTH-007`/`FR-AUTH-008`). The one call this
// screen makes: `SignOutUseCase.call()`, then a stack-replacing navigation
// to `/welcome` -- and nothing else (task §2 "SO6 calls `E15-T01`'s
// `SignOutUseCase.call()` and nothing else. This task contains no
// persistence logic, no `AppDatabase` handle, no file deletion and no auth
// call of its own.").
//
// **F3 (epic tracker's carried-forward observation, S4) -- the required
// double-tap guard.** `LocalDataWipeService.wipe()` is not re-entrant: two
// concurrent calls leave correct final state but the LOSING call throws
// `AppFailure` despite the wipe having actually succeeded -- an unguarded
// double-tap on [confirm] would show a spurious failure after a successful
// sign-out. [confirm] guards against this by simply refusing a second
// invocation while one is already in flight ([inProgress]); the view's own
// button additionally goes inert while [inProgress] is true (belt-and-braces,
// same two-layer shape `PrivacySettingsController`/`_GlobalLocationRow`
// already uses for its own "unknown state never writes" guard).
//
// **A failed sign-out keeps the user on this screen (task §6 Risks item 2).**
// `SignOutUseCase.call()` propagates a wipe failure (an `AppFailure`) rather
// than swallowing it, and this controller does not swallow it either --
// caught here (never rethrown, since there is no test/reviewer harness
// above a GetX controller to catch it) and logged via `ObservabilityService`
// so the failure is never silently discarded, then [inProgress] is reset so
// the user can retry or cancel. Navigation to `/welcome` happens ONLY after
// [call] completes without throwing -- never navigating "as if it had
// worked".
//
// **F1/F2 (epic tracker's carried-forward observations, both S2) are NOT
// wired here.** F1 is the remote device-registry revoke
// (`DeviceRevocationService.revoke(uid, deviceId)`, `Q-SEC-009`(b)); F2 is
// the real GetX-aware singleton teardown closure (closing/unregistering
// `AppDatabase`/`MessagingStack` before the wipe deletes the database file).
// Both were flagged in the epic tracker as needing an owner once
// `SignOutUseCase` is wired for real -- but THIS task's own `files:`/§5
// contract names neither: §5's own signature for [confirm] is "calls
// `SignOutUseCase.call()`, then `Get.offAllNamed(Routes.welcome)`" and
// nothing else, and §4 explicitly forbids an `AppDatabase` handle in this
// task's own code. Per rule 6 (the task file is the contract), this is not
// this task's own API surface to invent -- it is the epic tracker's own
// carried-forward F1/F2 (remote-revoke-and-teardown ownership), still
// unresolved and being decided separately by planning rather than guessed
// at here. Not restated as a new Open Question in THIS task file: doing so
// would pre-empt that separate routing rather than defer to it.
import 'package:get/get.dart';
import 'package:nexora/app/routes.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/features/settings/account/domain/sign_out_use_case.dart';

class SignOutConfirmController extends GetxController {
  SignOutConfirmController({required SignOutUseCase signOutUseCase})
    : _signOutUseCase = signOutUseCase; // ignore: prefer_initializing_formals

  final SignOutUseCase _signOutUseCase;

  /// `true` while a [confirm] call is in flight -- the view's own button
  /// goes inert while this is `true` (F3's structural guard).
  final RxBool inProgress = false.obs;

  /// `true` once a [confirm] attempt has failed -- task §6 Risks item 2:
  /// the user must not be silently returned to a screen that looks
  /// unchanged with no indication anything happened. This screen draws no
  /// new error copy of its own (the design contract's only state is
  /// `default`, and `sign-out-confirm.md` names no failure element to
  /// build against without inventing one outside `GAP-039`'s own scope);
  /// what this flag actually gates is [confirm] becoming tappable again
  /// for a retry, and the failure itself is never silently discarded --
  /// see [confirm]'s own `catch` clause.
  final RxBool failed = false.obs;

  /// FR-AUTH-006's single entry point from the UI (task §5 contract).
  /// Refuses a second concurrent call outright (F3) -- returns immediately,
  /// performing nothing, if a call is already in flight.
  Future<void> confirm() async {
    if (inProgress.value) return;
    inProgress.value = true;
    failed.value = false;
    try {
      await _signOutUseCase.call();
      Get.offAllNamed(Routes.welcome);
    } catch (e) {
      ObservabilityService.instance.logError(
        'session.sign_out_confirm_failed',
        cause: e,
      );
      failed.value = true;
      inProgress.value = false;
    }
  }

  /// SO7. The cancel path is the default outcome, not the exceptional one
  /// (task §5 contract) -- pops back to `/settings/account`.
  void cancel() {
    Get.back<void>();
  }
}
