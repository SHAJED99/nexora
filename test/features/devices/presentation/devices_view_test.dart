// features/devices/presentation — DevicesView vs design/screens/devices.md
// (E02-T02). Verifies the four RelationshipState visuals match the
// contract's elements 13-14, 21-22, 29-30, 37-38: icon + label + color per
// state, and that "Verify" (element 31) appears only on the Unknown row.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/devices/presentation/devices_binding.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/devices/presentation/devices_view.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;
  // E04-B19: captures whichever suffix `setUp`'s own `newTransportService()`
  // call used, so a test can register a mock handler (e.g. for
  // `getLocalDeviceName`) against the SAME channel `DevicesBinding` already
  // wired up, without needing its own separate TransportService/suffix.
  late String currentSuffix;

  // E06-B02: `DevicesBinding` now resolves its `TransportService` via
  // `Get.find` (the same shared-instance registration `app/bindings.dart`
  // does in production) instead of letting `DevicesController`'s
  // constructor fall back to building its own — so this test double must be
  // registered before `DevicesBinding().dependencies()` runs, same pattern
  // as `devices_controller_test.dart`'s `buildDiscoveringController`. A
  // distinct `messageChannelSuffix` per test keeps each test's platform
  // channel registration from clobbering another's, same as
  // `messaging_stack_test.dart`.
  TransportService newTransportService() {
    currentSuffix = 'devices-view-test-${suffixCounter++}';
    return TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: currentSuffix,
    );
  }

  setUp(() async {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = RelationshipRepository(db);
    await repository.upsert('device-trusted', RelationshipState.trusted);
    await repository.upsert('device-allowed', RelationshipState.allowed);
    await repository.upsert('device-unknown', RelationshipState.unknown);
    await repository.upsert('device-blocked', RelationshipState.blocked);

    Get.put<RelationshipRepository>(repository, permanent: true);
    Get.put<BlockUseCase>(BlockUseCase(repository), permanent: true);
    Get.put<TransportService>(newTransportService(), permanent: true);
    DevicesBinding().dependencies();
  });

  tearDown(() async {
    await db.close();
    Get.reset();
  });

  testWidgets('test_EARS_DEV_1_renders_relationship_states', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const DevicesView()),
    );
    await tester.pumpAndSettle();

    // Trusted — element 13-14: check_circle, "Trusted Node", green.
    expect(find.text('Trusted Node'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.check_circle)).color,
      NexoraColors.devicesTrustedGreen,
    );

    // Allowed — element 21-22: radio_button_checked, "Allowed", blue.
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.radio_button_checked)).color,
      NexoraColors.devicesAllowedBlue,
    );

    // Unknown — element 29-31: warning, "Unknown", amber, and the "Verify" button.
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.warning)).color,
      NexoraColors.devicesUnknownAmber,
    );
    expect(find.text('Verify'), findsOneWidget);

    // Blocked — element 37-38: block, "Blocked", red.
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.block)).color,
      NexoraColors.devicesBlockedRed,
    );

    // "Verify" is Unknown-only (§2) — exactly one on screen, not one per row.
    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets('empty state shown when no relationships are stored',
      (tester) async {
    Get.reset();
    final emptyDb = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = RelationshipRepository(emptyDb);
    Get.put<RelationshipRepository>(repository, permanent: true);
    Get.put<BlockUseCase>(BlockUseCase(repository), permanent: true);
    Get.put<TransportService>(newTransportService(), permanent: true);
    DevicesBinding().dependencies();

    await tester.pumpWidget(GetMaterialApp(home: const DevicesView()));
    await tester.pumpAndSettle();

    expect(find.text('No devices yet'), findsOneWidget);
    await emptyDb.close();
  });

  testWidgets(
      'test_devices_view_renders_all_four_states_with_no_overflow',
      (tester) async {
    // Regression test for E06-B01: two RenderFlex overflows (badge row
    // trailing content, and _BottomNav's four unflexed _NavItems) hung the
    // Flutter test harness itself for its full 10-minute default timeout
    // when pumped at the design contract's 390x844 viewport. This must
    // complete quickly on its own — an unbounded pumpAndSettle() (no
    // timeout argument) IS the proof; bounding it would only hide a hang.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(GetMaterialApp(home: const DevicesView()));
    await tester.pumpAndSettle();

    expect(find.text('Trusted Node'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kebab menu Block action calls BlockUseCase and updates row',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: const DevicesView()));
    await tester.pumpAndSettle();

    // Open the kebab menu on the Trusted row and tap Block. Locate the
    // kebab by its own row (the Row ancestor of the 'device-trusted' label
    // that also contains its PopupMenuButton) rather than by screen
    // position: E12-B14 gave `listAll` a deterministic secondary sort key
    // (deviceId ascending on an updatedAt tie), so the on-screen row order
    // for this fixture's four same-tick upserts is no longer
    // trusted/allowed/unknown/blocked -- it is alphabetical by deviceId.
    // Selecting `kebabs.first` here would now open a different row's menu.
    final trustedRow = find.ancestor(
      of: find.text('device-trusted'),
      matching: find.byType(Row),
    );
    final trustedKebab = find.descendant(
      of: trustedRow.first,
      matching: find.byIcon(Icons.more_vert),
    );
    await tester.tap(trustedKebab);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();

    final controller = Get.find<DevicesController>();
    final blocked = controller.relationships
        .where((r) => r.deviceId == 'device-trusted')
        .single;
    expect(blocked.state, RelationshipState.blocked);
  });

  // E04-B19: the Devices screen shows this device's own Bluetooth name so
  // a user pairing two phones can tell what name to look for in the OTHER
  // phone's OS Bluetooth settings.
  testWidgets(
      'test_E04_B19_shows_this_devices_own_bluetooth_name_when_available',
      (tester) async {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.getLocalDeviceName.$currentSuffix',
      (ByteData? message) async => TransportApi.pigeonChannelCodec
          .encodeMessage(<Object?>["Ahmed's Phone"]),
    );

    await tester.pumpWidget(GetMaterialApp(home: const DevicesView()));
    await tester.pumpAndSettle();

    expect(find.text('Visible to nearby devices as: Ahmed\'s Phone'),
        findsOneWidget);
  });

  testWidgets(
      'test_E04_B19_shows_nothing_when_the_native_name_call_fails',
      (tester) async {
    // No mock handler registered for getLocalDeviceName -- the call fails,
    // and the screen must render nothing for it rather than crash or show
    // a placeholder.
    await tester.pumpWidget(GetMaterialApp(home: const DevicesView()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Visible to nearby devices'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // E02-B01, review round 1 finding 1: the controller-level test proved
  // `unblock()` itself works, but not that the VIEW ever offers it -- the
  // actual reported defect ("no button for unblock") is purely at this
  // layer (`itemBuilder` unconditionally emitting "Block"). This test
  // fails against the pre-fix `itemBuilder` (no "Unblock" item exists to
  // tap) and passes with it.
  testWidgets('kebab menu on a blocked row offers Unblock, not Block',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: const DevicesView()));
    await tester.pumpAndSettle();

    final blockedRow = find.ancestor(
      of: find.text('device-blocked'),
      matching: find.byType(Row),
    );
    final blockedKebab = find.descendant(
      of: blockedRow.first,
      matching: find.byIcon(Icons.more_vert),
    );
    await tester.tap(blockedKebab);
    await tester.pumpAndSettle();

    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Block'), findsNothing);

    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();

    final controller = Get.find<DevicesController>();
    final unblocked = controller.relationships
        .where((r) => r.deviceId == 'device-blocked')
        .single;
    expect(unblocked.state, RelationshipState.allowed);
  });

  group('test_E06_B05_bottom_nav_actually_navigates', () {
    // Regression for E06-B05: every non-active _NavItem on this screen was
    // wired to `onTap: () {}` -- present, tappable, and a real dead end.
    // Found via live two-device on-hardware testing: landing on Devices via
    // the bottom nav left no way to reach any other tab without the
    // system back gesture. `GetPage`s below stand in for the three real
    // destinations so a tap can be proven to actually navigate, not merely
    // exist.
    Future<void> pumpDevicesViewWithRoutes(WidgetTester tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/devices',
          getPages: [
            GetPage(name: '/devices', page: () => const DevicesView()),
            GetPage(name: '/dashboard', page: () => const Text('DASHBOARD')),
            GetPage(
              name: '/conversations',
              page: () => const Text('CONVERSATIONS'),
            ),
            GetPage(name: '/settings', page: () => const Text('SETTINGS')),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping Dashboard navigates to /dashboard', (tester) async {
      await pumpDevicesViewWithRoutes(tester);
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('tapping Conversations navigates to /conversations',
        (tester) async {
      await pumpDevicesViewWithRoutes(tester);
      await tester.tap(find.text('Conversations'));
      await tester.pumpAndSettle();
      expect(find.text('CONVERSATIONS'), findsOneWidget);
    });

    testWidgets('tapping Settings navigates to /settings', (tester) async {
      await pumpDevicesViewWithRoutes(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets(
        'tapping the already-active Devices tab stays on /devices (no-op '
        'by convention, not a regression target)', (tester) async {
      await pumpDevicesViewWithRoutes(tester);
      await tester.tap(find.text('Devices'));
      await tester.pumpAndSettle();
      expect(find.byType(DevicesView), findsOneWidget);
    });
  });

  group('test_E06_T14_message_button_GAP_030', () {
    // GAP-030 — a Message icon-button on Trusted/Allowed rows only,
    // navigating to Routes.chat with that row's own deviceId. Found
    // missing entirely during live two-device on-hardware testing
    // (E06-B05's own Run log): mutual Bluetooth trust was established
    // between two real phones, with no way afterward to actually reach
    // a conversation with the newly-trusted peer.
    Finder messageButtonFor(String deviceId) {
      final row = find.ancestor(
        of: find.text(deviceId),
        matching: find.byType(Row),
      );
      return find.descendant(
        of: row.first,
        matching: find.byIcon(Icons.chat),
      );
    }

    testWidgets('appears on a Trusted row and navigates to /chat/<id>',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/devices',
          getPages: [
            GetPage(name: '/devices', page: () => const DevicesView()),
            GetPage(
              name: '/chat/:id',
              page: () => Text('CHAT_${Get.parameters['id']}'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(messageButtonFor('device-trusted'), findsOneWidget);
      await tester.tap(messageButtonFor('device-trusted'));
      await tester.pumpAndSettle();

      expect(find.text('CHAT_device-trusted'), findsOneWidget);
    });

    testWidgets('appears on an Allowed row and navigates to /chat/<id>',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/devices',
          getPages: [
            GetPage(name: '/devices', page: () => const DevicesView()),
            GetPage(
              name: '/chat/:id',
              page: () => Text('CHAT_${Get.parameters['id']}'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(messageButtonFor('device-allowed'), findsOneWidget);
      await tester.tap(messageButtonFor('device-allowed'));
      await tester.pumpAndSettle();

      expect(find.text('CHAT_device-allowed'), findsOneWidget);
    });

    testWidgets(
        'does NOT appear on an Unknown row (no session to message yet)',
        (tester) async {
      await tester.pumpWidget(GetMaterialApp(home: const DevicesView()));
      await tester.pumpAndSettle();

      expect(messageButtonFor('device-unknown'), findsNothing);
    });

    testWidgets(
        'does NOT appear on a Blocked row (must not gain a new way to '
        'reach a blocked peer)', (tester) async {
      await tester.pumpWidget(GetMaterialApp(home: const DevicesView()));
      await tester.pumpAndSettle();

      expect(messageButtonFor('device-blocked'), findsNothing);
    });
  });
}
