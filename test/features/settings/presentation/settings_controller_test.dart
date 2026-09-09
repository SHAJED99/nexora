// features/settings/presentation — SettingsController's real navigation
// wiring (E15-T11, `FR-UI-006`/`FR-UI-008`, `EARS-UI-8`/`EARS-UI-10`).
//
// Pumps the REAL `SettingsView` against the REAL `appPages` routing table
// (`lib/app/routes.dart`) over a REAL `AppBinding` + `SettingsBinding` — not
// a stand-in `GetPage` list — so a copy-pasted route mapping, an
// unregistered binding, or a reverted "Coming soon" snackbar all fail here,
// exactly where this task's own §6 risk note says they are otherwise
// invisible to every other screen's own gate.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/app/bindings.dart';
import 'package:nexora/app/routes.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_view.dart';
import 'package:nexora/features/settings/account/presentation/account_view.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_view.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_view.dart';
import 'package:nexora/features/settings/network/presentation/network_settings_view.dart';
import 'package:nexora/features/settings/notifications/presentation/notification_settings_view.dart';
import 'package:nexora/features/settings/presentation/settings_binding.dart';
import 'package:nexora/features/settings/presentation/settings_view.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_view.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_view.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_view.dart';

/// One row per hub entry, in `design/screens/settings.md`'s own top-to-
/// bottom order — the exact copy `settings_view.dart` renders, and the
/// route this task's own §3 table says that row must resolve to.
const _rows = <(String title, String description, String route)>[
  (
    'Account',
    'Profile, identity keys, linked devices',
    Routes.settingsAccount,
  ),
  (
    'Privacy & Security',
    'Encryption protocols, app lock, permissions',
    Routes.settingsPrivacy,
  ),
  (
    'Security Center',
    'Threat logs, network audits, certificates',
    Routes.settingsSecurityCenter,
  ),
  ('Network', 'Data usage, mesh routing, proxy', Routes.settingsNetwork),
  (
    'Storage',
    'Local cache, message retention, export',
    Routes.settingsStorage,
  ),
  (
    'Battery',
    'Background execution, power saving modes',
    Routes.settingsBattery,
  ),
  (
    'Notifications',
    'Alerts, silent modes, LED behaviors',
    Routes.settingsNotifications,
  ),
  (
    'About / Updates',
    'Version 2.4.1, release notes, diagnostic logs',
    Routes.settingsAbout,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MessagingStack stack;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  /// Builds the REAL composition root (`AppBinding`) plus this task's own
  /// `SettingsBinding`, then pumps the REAL `SettingsView` at `/settings`
  /// through the REAL `appPages` table -- so `Get.toNamed` calls resolve
  /// exactly as they would in the shipped app.
  Future<void> pumpRealSettingsHub(WidgetTester tester) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final transport = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: 'settings-wiring-${suffixCounter++}',
    );
    stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'self-settings-wiring',
      transport: transport,
    );
    AppBinding(
      db: db,
      messagingStack: stack,
      // Never the real background/notification/link-quality starts here --
      // this test proves ROUTING, not lifecycle behaviour; blocking keeps
      // every one of those four subsystems from touching an unmocked
      // platform channel mid-test.
      blockCommunication: true,
      backgroundControl: BackgroundStub(),
    ).dependencies();
    SettingsBinding().dependencies();

    await tester.pumpWidget(
      GetMaterialApp(initialRoute: Routes.settings, getPages: appPages),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => Get.testMode = true);

  tearDown(() async {
    await stack.dispose();
    await db.close();
    Get.reset();
  });

  group('test_EARS_UI_8_each_row_navigates_to_its_own_route', () {
    for (final (title, _, expectedRoute) in _rows) {
      testWidgets('"$title" navigates to $expectedRoute', (tester) async {
        await pumpRealSettingsHub(tester);

        // The hub's row list scrolls, and the default test surface
        // (800x600) does not show every row without scrolling to it first
        // -- `ensureVisible` scrolls the enclosing `SingleChildScrollView`
        // so the tap below actually lands on the widget, not on whatever
        // (if anything) occupies that offset in the unscrolled layout.
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();

        expect(
          Get.currentRoute,
          expectedRoute,
          reason: '"$title" must navigate to its OWN route, not a '
              'copy-pasted neighbour\'s',
        );
        // Every other row's route must NOT also be current -- catches a
        // duplicate mapping (two rows sent to the same screen) that a
        // same-route check alone would miss.
        for (final (otherTitle, _, otherRoute) in _rows) {
          if (otherTitle == title) continue;
          expect(
            Get.currentRoute,
            isNot(otherRoute),
            reason: '"$title" landed on "$otherTitle"\'s route',
          );
        }

        // Pop back to the hub before the test ends. A sub-screen controller
        // whose GetX lifecycle disposes a live Drift `.watch()` stream (e.g.
        // `PrivacySettingsController`/`NotificationSettingsController`/
        // `StorageSettingsController`) schedules Drift's own zero-duration
        // cleanup Timer -- if that disposal happens only at
        // flutter_test's automatic end-of-test teardown (never popped
        // explicitly), the resulting Timer has no further `pump()` to be
        // flushed by and trips `AutomatedTestWidgetsFlutterBinding`'s
        // "Timer still pending" invariant. Popping here, followed by
        // `pumpAndSettle()`, disposes it INSIDE the test body instead, where
        // that same pump can flush it.
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
      });
    }
  });

  testWidgets('test_EARS_UI_8_no_row_shows_a_snackbar', (tester) async {
    await pumpRealSettingsHub(tester);

    for (final (title, _, expectedRoute) in _rows) {
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pump();
      // A real, falsifiable signal -- `Get.isSnackbarOpen` reads GetX's own
      // snackbar-overlay state. Reverting `openRow` to
      // `Get.snackbar(title, 'Coming soon')` flips this `true` and fails
      // this assertion (verified directly -- see this task's Run log).
      expect(
        Get.isSnackbarOpen,
        isFalse,
        reason: 'tapping "$title" opened a snackbar instead of navigating',
      );
      await tester.pumpAndSettle();
      expect(Get.currentRoute, expectedRoute);

      // Back to the hub for the next row in this same run.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, Routes.settings);
    }
  });

  group(
    'test_EARS_UI_10_back_from_each_sub_screen_returns_to_settings',
    () {
      for (final (title, _, expectedRoute) in _rows) {
        testWidgets('back from "$title" ($expectedRoute) returns to /settings',
            (tester) async {
          await pumpRealSettingsHub(tester);

          await tester.ensureVisible(find.text(title));
          await tester.pumpAndSettle();
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
          expect(Get.currentRoute, expectedRoute);

          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();

          expect(Get.currentRoute, Routes.settings);
          expect(find.byType(SettingsView), findsOneWidget);
        });
      }
    },
  );

  testWidgets(
    'test_EARS_UI_8_every_registered_route_resolves_to_a_page',
    (tester) async {
      await pumpRealSettingsHub(tester);

      // The hub itself.
      expect(find.byType(SettingsView), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The eight rows' own routes, each landing on the real screen type
      // this task's own §3 table names for it -- catching an unregistered
      // binding (a screen whose controller can't resolve a dependency
      // throws on first navigation, task §6 risk note), not merely "no
      // route error".
      const expectations = <(String route, Type viewType)>[
        (Routes.settingsAccount, AccountView),
        (Routes.settingsPrivacy, PrivacySettingsView),
        (Routes.settingsSecurityCenter, SecurityCenterView),
        (Routes.settingsNetwork, NetworkSettingsView),
        (Routes.settingsStorage, StorageSettingsView),
        (Routes.settingsBattery, BatterySettingsView),
        (Routes.settingsNotifications, NotificationSettingsView),
        (Routes.settingsAbout, AboutSettingsView),
      ];
      for (final (route, viewType) in expectations) {
        Get.toNamed(route);
        await tester.pumpAndSettle();
        expect(
          find.byType(viewType),
          findsOneWidget,
          reason: '$route did not resolve to $viewType',
        );
        expect(tester.takeException(), isNull, reason: '$route threw while building');
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(Get.currentRoute, Routes.settings);
      }

      // The ninth route -- sign-out confirmation -- is reached from Account,
      // not from a hub row (task §3), so it is exercised directly here.
      Get.toNamed(Routes.settingsSignOutConfirm);
      await tester.pumpAndSettle();
      expect(find.byType(SignOutConfirmView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'test_EARS_UI_8_settings_row_copy_is_unchanged',
    (tester) async {
      await pumpRealSettingsHub(tester);

      // §4: "does NOT change settings.md's eight row labels or subtitles."
      // Verbatim against design/screens/settings.md's own copy.
      for (final (title, description, _) in _rows) {
        expect(find.text(title), findsOneWidget, reason: 'row title "$title"');
        expect(
          find.text(description),
          findsOneWidget,
          reason: 'row description for "$title"',
        );
      }
    },
  );
}
