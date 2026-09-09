// features/settings/presentation — SettingsView vs design/screens/settings.md
// (E02-T03, rewired E15-T11). Verifies the eight menu rows render exactly
// per the design contract's elements table, and — since E15-T11 replaced
// E02-T03's "Coming soon" acknowledgement with real navigation
// (`FR-UI-006`/`EARS-UI-8`) — that tapping a row navigates rather than
// showing one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/features/settings/presentation/settings_binding.dart';
import 'package:nexora/features/settings/presentation/settings_view.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    SettingsBinding().dependencies();
  });

  tearDown(() => Get.reset());

  testWidgets('test_EARS_SET_1_renders_all_eight_rows', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: const SettingsView()));
    await tester.pumpAndSettle();

    // Header — elements 4-8: hub icon, NEXORA, lock icon, "Settings" heading.
    expect(find.byIcon(Icons.hub), findsOneWidget);
    expect(find.text('NEXORA'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(
      find.text(
        'Manage your secure connection preferences and device configurations.',
      ),
      findsOneWidget,
    );

    // Eight rows — icon, title, description, per the elements table.
    const rows = <(IconData, String, String)>[
      (Icons.account_circle, 'Account', 'Profile, identity keys, linked devices'),
      (
        Icons.security,
        'Privacy & Security',
        'Encryption protocols, app lock, permissions',
      ),
      (
        Icons.policy,
        'Security Center',
        'Threat logs, network audits, certificates',
      ),
      (Icons.wifi_tethering, 'Network', 'Data usage, mesh routing, proxy'),
      (
        Icons.sd_storage,
        'Storage',
        'Local cache, message retention, export',
      ),
      (
        Icons.battery_full,
        'Battery',
        'Background execution, power saving modes',
      ),
      (
        Icons.notifications,
        'Notifications',
        'Alerts, silent modes, LED behaviors',
      ),
      (
        Icons.info,
        'About / Updates',
        'Version 2.4.1, release notes, diagnostic logs',
      ),
    ];

    for (final (icon, title, description) in rows) {
      expect(find.byIcon(icon), findsOneWidget, reason: 'icon for $title');
      expect(find.text(title), findsOneWidget);
      expect(find.text(description), findsOneWidget);
    }

    // Eight chevron_right affordances, one per row.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(8));

    // Bottom nav — Dashboard/Conversations/Devices/Settings, Settings active.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    // "Settings" appears twice: the page heading (element 8) and the nav
    // label (element 74).
    expect(find.text('Settings'), findsNWidgets(2));
  });

  testWidgets(
    'test_EARS_UI_8_tap_navigates_not_coming_soon',
    (tester) async {
      // E15-T11 superseded E02-T03's "Coming soon" acknowledgement with
      // real navigation once all eight sub-screens existed — this screen's
      // own test updates alongside its production file (`settings_view.dart`,
      // this task's `files:` fence) rather than staying asserted against
      // behaviour the task explicitly requires gone. The exhaustive,
      // real-route version of this proof (all eight rows, the real
      // `appPages` table, `Get.isSnackbarOpen` as the falsifiable "no
      // snackbar" signal) lives in
      // `test/features/settings/presentation/settings_controller_test.dart`;
      // this one just proves `SettingsView` itself no longer shows one, with
      // a minimal stub destination standing in for the real sub-screen.
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/settings',
          getPages: [
            GetPage(name: '/settings', page: () => const SettingsView()),
            GetPage(
              name: '/settings/account',
              page: () => const Text('ACCOUNT STUB'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      // Real navigation happened — not the old acknowledgement.
      expect(find.text('ACCOUNT STUB'), findsOneWidget);
      expect(find.byType(SettingsView), findsNothing);
      expect(find.text('Coming soon'), findsNothing);
      expect(Get.isSnackbarOpen, isFalse);
    },
  );

  group('test_E06_B05_bottom_nav_actually_navigates', () {
    // Regression for E06-B05: every non-active _NavItem on this screen was
    // wired to `onTap: () {}` (copied from `devices_view.dart`'s own
    // identical bug) -- present, tappable, and a real dead end. Found via
    // live two-device on-hardware testing: landing on Settings via the
    // bottom nav left no way to reach any other tab without the system
    // back gesture. `GetPage`s below stand in for the three real
    // destinations so a tap can be proven to actually navigate, not merely
    // exist.
    Future<void> pumpSettingsViewWithRoutes(WidgetTester tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/settings',
          getPages: [
            GetPage(name: '/settings', page: () => const SettingsView()),
            GetPage(name: '/dashboard', page: () => const Text('DASHBOARD')),
            GetPage(
              name: '/conversations',
              page: () => const Text('CONVERSATIONS'),
            ),
            GetPage(name: '/devices', page: () => const Text('DEVICES')),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping Dashboard navigates to /dashboard', (tester) async {
      await pumpSettingsViewWithRoutes(tester);
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('tapping Conversations navigates to /conversations',
        (tester) async {
      await pumpSettingsViewWithRoutes(tester);
      await tester.tap(find.text('Conversations'));
      await tester.pumpAndSettle();
      expect(find.text('CONVERSATIONS'), findsOneWidget);
    });

    testWidgets('tapping Devices navigates to /devices', (tester) async {
      await pumpSettingsViewWithRoutes(tester);
      await tester.tap(find.text('Devices'));
      await tester.pumpAndSettle();
      expect(find.text('DEVICES'), findsOneWidget);
    });

    testWidgets(
        'tapping the already-active Settings tab stays on /settings '
        '(no-op by convention, not a regression target)', (tester) async {
      await pumpSettingsViewWithRoutes(tester);
      // "Settings" is ambiguous here (page heading + nav label) -- the nav
      // label is the LAST match on screen.
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsView), findsOneWidget);
    });
  });
}
