// features/settings/presentation — SettingsView vs design/screens/settings.md
// (E02-T03). Verifies the eight menu rows render exactly per the design
// contract's elements table, and that tapping a row (no sub-screen built
// yet, per §4) only acknowledges the tap rather than navigating anywhere.
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
    'test_EARS_SET_2_tap_shows_coming_soon_not_fake_navigation',
    (tester) async {
      await tester.pumpWidget(GetMaterialApp(home: const SettingsView()));
      await tester.pumpAndSettle();

      final currentRoute = Get.currentRoute;

      await tester.tap(find.text('Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // let the GetX snackbar overlay animate in.

      // No navigation happened — still on the same (settings) screen.
      expect(Get.currentRoute, currentRoute);
      expect(find.byType(SettingsView), findsOneWidget);

      // A snackbar acknowledges the tap instead of navigating anywhere.
      expect(find.text('Coming soon'), findsOneWidget);

      // Let the snackbar's own auto-dismiss timer finish before the test
      // ends, so no pending timer trips the framework's teardown check.
      await tester.pumpAndSettle(const Duration(seconds: 4));
    },
  );
}
