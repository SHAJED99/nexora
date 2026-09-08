// features/settings/presentation/widgets — SettingsSubScreenScaffold vs
// design/screens/settings-shell.md (E15-T03). Proves the SH1-SH4 frame
// renders every element the contract names, that no bottom navigation bar
// appears (the specific wrong move settings-shell.md §6 names and this
// task's §4 forbids), and that both back affordances — SH1's tap and the
// platform back gesture — pop the route (EARS-UI-10, FR-UI-008).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<void> pumpScaffoldOnTopOfAPriorRoute(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/settings',
        getPages: [
          GetPage(name: '/settings', page: () => const Text('SETTINGS HUB')),
          GetPage(
            name: '/settings/sub',
            page: () => const SettingsSubScreenScaffold(
              title: 'Test Sub-Screen',
              subtitle: 'A one-line subtitle.',
              children: [Text('content')],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    Get.toNamed<void>('/settings/sub');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders the SH1-SH4 frame: back glyph, heading, subtitle, content',
    (tester) async {
      await pumpScaffoldOnTopOfAPriorRoute(tester);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Test Sub-Screen'), findsOneWidget);
      expect(find.text('A one-line subtitle.'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
    },
  );

  testWidgets(
    'no bottom navigation bar is present (settings-shell.md §6)',
    (tester) async {
      await pumpScaffoldOnTopOfAPriorRoute(tester);

      expect(find.byType(BottomNavigationBar), findsNothing);
      // The hub's own bottom-nav labels must not leak into a sub-screen.
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Conversations'), findsNothing);
      expect(find.text('Devices'), findsNothing);
    },
  );

  testWidgets(
    'test_EARS_UI_10_scaffold_back_affordance_pops_the_route',
    (tester) async {
      await pumpScaffoldOnTopOfAPriorRoute(tester);
      expect(find.text('SETTINGS HUB'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS HUB'), findsOneWidget);
      expect(find.byType(SettingsSubScreenScaffold), findsNothing);
    },
  );

  testWidgets(
    'test_EARS_UI_10_system_back_pops_the_route',
    (tester) async {
      await pumpScaffoldOnTopOfAPriorRoute(tester);
      expect(find.text('SETTINGS HUB'), findsNothing);

      // The Android hardware/software back button and the system back
      // gesture both funnel through `Navigator.maybePop` -- simulating the
      // platform "pop route" system channel message is the same path either
      // one takes (same pattern as
      // test/features/version/presentation/version_update_controller_test.dart).
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS HUB'), findsOneWidget);
      expect(find.byType(SettingsSubScreenScaffold), findsNothing);
    },
  );
}
