// EARS-VER-11/12 (FR-VER-006, FR-VER-007) — E14-T04.
//
// `EARS-VER-10` (WHEN `UPDATE_REQUIRED` at launch THE system SHALL route
// to `/version-update-required`) is NOT tested here — that wiring lives in
// `app/main.dart` and needs a REAL `InstalledBuildProvider`
// (`EvaluateVersionStateUseCase`'s own injected seam, E14-T02), itself
// blocked on a `pubspec.yaml` 🧍 `new_dependency` gate this task has no
// authority to clear (see `## Open Questions`). What IS fully testable
// without either blocked dependency is this controller's OWN behaviour:
// it starts whatever launcher it is given (EARS-VER-12), and it never
// exposes any way to navigate away on its own (EARS-VER-11's controller
// half — the view's own non-dismissibility, `PopScope(canPop: false)`, is
// a widget-tree property asserted directly against `VersionUpdateView`
// below, not something a plain `GetxController` unit test could reach).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/features/version/presentation/version_update_controller.dart';
import 'package:nexora/features/version/presentation/version_update_view.dart';

void main() {
  group('VersionUpdateController', () {
    test('test_EARS_VER_12_update_now_starts_immediate_update_flow',
        () async {
      var launcherCalled = 0;
      final controller = VersionUpdateController(
        launcher: () async => launcherCalled++,
      );

      await controller.startImmediateUpdate();

      expect(launcherCalled, 1);
    });

    test(
        'test_launcher_failure_is_swallowed_and_logged_not_rethrown '
        '(the screen has no other affordance to fall back to)', () async {
      final controller = VersionUpdateController(
        launcher: () async => throw StateError('platform call failed'),
      );

      // Must not throw -- there is nothing else for the caller (the
      // button's onPressed) to do with a rethrown error, and the contract
      // (task file §5) says the failure is logged, the screen stays.
      await controller.startImmediateUpdate();
    });

    test(
        'test_launcher_is_never_called_until_startImmediateUpdate_is_'
        'invoked (no auto-start on construction)', () async {
      var launcherCalled = 0;
      VersionUpdateController(launcher: () async => launcherCalled++);

      expect(launcherCalled, 0);
    });
  });

  group('VersionUpdateView — non-dismissible (EARS-VER-11)', () {
    testWidgets(
        'test_EARS_VER_11_back_gesture_and_button_do_not_dismiss',
        (tester) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      Get.put<VersionUpdateController>(
        VersionUpdateController(launcher: () async {}),
      );

      // A real previous route on the navigation stack, exactly the
      // scenario EARS-VER-11 guards against: if this screen were ever
      // dismissible, the back gesture/button would reveal `_Behind`.
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/behind',
          getPages: [
            GetPage<dynamic>(name: '/behind', page: () => const _Behind()),
            GetPage<dynamic>(
              name: '/version-update-required',
              page: () => const VersionUpdateView(),
            ),
          ],
        ),
      );
      Get.toNamed('/version-update-required');
      await tester.pumpAndSettle();

      expect(find.byType(VersionUpdateView), findsOneWidget);
      expect(find.byType(_Behind), findsNothing);

      // The Android hardware/software back button and the system back
      // gesture both funnel through `Navigator.maybePop` /
      // `PopScope.canPop` -- simulating the platform "pop route" system
      // channel message is the same path either one takes.
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byType(VersionUpdateView),
        findsOneWidget,
        reason: 'the back gesture/button must not pop this route',
      );
      expect(
        find.byType(_Behind),
        findsNothing,
        reason: 'no affordance on this screen may reveal a previous route',
      );

      // Structural absence, not merely "didn't navigate away": there is no
      // second button, no icon button, and no dismiss/close affordance at
      // all — exactly one tappable control on the whole screen.
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
    });
  });
}

class _Behind extends StatelessWidget {
  const _Behind();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('behind'));
}
