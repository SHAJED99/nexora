// features/settings/account/presentation -- SignOutConfirmController
// (E15-T07). SO6's whole reason to exist: exactly one call to
// `SignOutUseCase.call()`, then a stack-replacing navigation to
// `/welcome` -- never a push, never a pop, never a swallowed failure, and
// never a second concurrent call (F3, the epic tracker's own carried-
// forward observation on `LocalDataWipeService.wipe()`'s non-reentrancy).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/app/routes.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/features/settings/account/domain/sign_out_use_case.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_controller.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<void> pumpAt(WidgetTester tester, SignOutConfirmController c) {
    Get.put<SignOutConfirmController>(c);
    return tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/settings/sign-out-confirm',
        getPages: [
          GetPage(
            name: '/settings/sign-out-confirm',
            page: () => const SizedBox.shrink(),
          ),
          GetPage(name: Routes.welcome, page: () => const SizedBox.shrink()),
        ],
      ),
    );
  }

  testWidgets(
    'test_EARS_AUTH_7_confirm_screen_lists_every_loss_category',
    (tester) async {
      // The whole reason `sign-out-confirm.md` exists: every loss category,
      // the unrecoverable line, and the "brand-new identity" line must all
      // be readable BEFORE any destructive action is possible (task §8,
      // `FR-AUTH-007`/`FR-RECOVER-002`). Falsified: dropping any one of the
      // seven `find.text(...)` lines below from `_LossList`/
      // `SignOutConfirmView` (verified during implementation by literally
      // deleting the "Every group this device belongs to" line and
      // re-running) leaves that specific expectation failing with
      // `findsNothing`, not a false pass.
      Get.put<SignOutConfirmController>(
        SignOutConfirmController(signOutUseCase: _CountingSignOutUseCase()),
      );
      await tester.pumpWidget(
        const GetMaterialApp(home: SignOutConfirmView()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Sign out and erase this device?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Signing out permanently deletes everything this app keeps '
          'on this device:',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Your device identity and all of its encryption keys'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Every message, voice message and call recording, and all '
          'history',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Every trusted device and every block you have set'),
        findsOneWidget,
      );
      expect(
        find.text('Every group this device belongs to'),
        findsOneWidget,
      );
      expect(find.text('All of your settings'), findsOneWidget);
      expect(
        find.text(
          'This cannot be undone. Anything encrypted with these keys '
          'can never be read again, on this device or any other.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Signing back in creates a brand-new identity, as if the app '
          'had just been installed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sign out and erase'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  testWidgets(
    'test_EARS_AUTH_7_confirm_invokes_the_use_case_exactly_once',
    (tester) async {
      final useCase = _CountingSignOutUseCase();
      final controller = SignOutConfirmController(signOutUseCase: useCase);
      await pumpAt(tester, controller);

      await controller.confirm();
      await tester.pumpAndSettle();

      expect(useCase.calls, 1);
    },
  );

  testWidgets(
    'test_EARS_AUTH_7_confirm_replaces_the_whole_stack',
    (tester) async {
      final useCase = _CountingSignOutUseCase();
      final controller = SignOutConfirmController(signOutUseCase: useCase);
      await pumpAt(tester, controller);

      await controller.confirm();
      await tester.pumpAndSettle();

      // `Get.offAllNamed` clears the whole navigation history -- proven
      // structurally, not just by the final route name, by asserting no
      // route to pop back to survives (a `push` would leave one; a plain
      // `back()` never gets here at all since this is the confirm path).
      expect(Get.currentRoute, Routes.welcome);
      final context = Get.context!;
      expect(Navigator.of(context).canPop(), isFalse);
    },
  );

  testWidgets('test_EARS_AUTH_7_cancel_does_not_sign_out', (tester) async {
    final useCase = _CountingSignOutUseCase();
    final controller = SignOutConfirmController(signOutUseCase: useCase);
    await pumpAt(tester, controller);

    controller.cancel();
    await tester.pumpAndSettle();

    expect(useCase.calls, 0);
  });

  testWidgets(
    'test_EARS_AUTH_7_wipe_failure_keeps_the_user_on_the_confirm_screen',
    (tester) async {
      final useCase = _FailingSignOutUseCase();
      final controller = SignOutConfirmController(signOutUseCase: useCase);
      await pumpAt(tester, controller);

      await controller.confirm();
      await tester.pumpAndSettle();

      // Never navigated to `/welcome` "as if it had worked" (task §6
      // Risks item 2).
      expect(Get.currentRoute, '/settings/sign-out-confirm');
      expect(controller.failed.value, isTrue);
      // The guard resets so the user can retry or cancel -- a failure must
      // not permanently strand the button.
      expect(controller.inProgress.value, isFalse);
    },
  );

  testWidgets(
    'test_F3_a_concurrent_second_confirm_call_is_refused_not_run',
    (tester) async {
      // The falsification for F3's structural guard: without the
      // `if (inProgress.value) return;` line in `confirm()`, BOTH calls
      // below would run concurrently and `calls` would end at 2 -- this is
      // proven by literally deleting that guard line and re-running this
      // test during implementation (see task's Run log); restored here.
      //
      // No real delay/timer is used here (deliberately -- a `Future
      // .delayed` timer never fires under `flutter_test`'s virtualized
      // clock unless the test explicitly pumps time forward, which would
      // hang this test outright). `confirm()`'s own synchronous prefix
      // (the `inProgress` check + flip) runs to completion, INCLUDING the
      // use case's own `calls++`, before `confirm()` suspends at its own
      // `await` -- so calling it twice back-to-back with neither call
      // awaited yet already exercises the guard: `second`'s synchronous
      // prefix runs only after `first`'s has already flipped `inProgress`.
      final useCase = _CountingSignOutUseCase();
      final controller = SignOutConfirmController(signOutUseCase: useCase);
      await pumpAt(tester, controller);

      final first = controller.confirm();
      final second = controller.confirm();
      await Future.wait([first, second]);
      await tester.pumpAndSettle();

      expect(useCase.calls, 1);
    },
  );

  testWidgets(
    'test_F3_the_view_would_see_inProgress_true_while_a_call_is_in_flight',
    (tester) async {
      final useCase = _CountingSignOutUseCase();
      final controller = SignOutConfirmController(signOutUseCase: useCase);
      await pumpAt(tester, controller);

      expect(controller.inProgress.value, isFalse);
      final pending = controller.confirm();
      // Not yet awaited -- the guard's own flag must already be `true`
      // synchronously after the call starts, before the underlying
      // use-case's async work has had a chance to complete, so the view's
      // `onPressed: inProgress.value ? null : confirm` would already
      // refuse a second tap at this exact instant.
      expect(controller.inProgress.value, isTrue);
      await pending;
      await tester.pumpAndSettle();
      // Deliberately NOT reset to `false` on a SUCCESSFUL confirm --
      // `confirm()` navigates away via `Get.offAllNamed` on success, and
      // this controller's screen is gone from the stack from that point
      // on, so leaving the guard flag set keeps the button inert through
      // the transition rather than briefly re-enabling it. The `false`
      // reset only happens on a FAILED confirm (see
      // `test_EARS_AUTH_7_wipe_failure_keeps_the_user_on_the_confirm_screen`
      // above), where the user is still looking at this same screen and
      // must be able to retry.
      expect(controller.inProgress.value, isTrue);
    },
  );
}

class _CountingSignOutUseCase extends SignOutUseCase {
  int calls = 0;

  @override
  Future<void> call() async {
    calls++;
  }
}

class _FailingSignOutUseCase extends SignOutUseCase {
  @override
  Future<void> call() async {
    throw const AppFailure('session.local_wipe_failed');
  }
}
