// features/devices/presentation — DevicesView vs design/screens/devices.md
// (E02-T02). Verifies the four RelationshipState visuals match the
// contract's elements 13-14, 21-22, 29-30, 37-38: icon + label + color per
// state, and that "Verify" (element 31) appears only on the Unknown row.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/core/persistence/database.dart';
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

  // E06-B02: `DevicesBinding` now resolves its `TransportService` via
  // `Get.find` (the same shared-instance registration `app/bindings.dart`
  // does in production) instead of letting `DevicesController`'s
  // constructor fall back to building its own — so this test double must be
  // registered before `DevicesBinding().dependencies()` runs, same pattern
  // as `devices_controller_test.dart`'s `buildDiscoveringController`. A
  // distinct `messageChannelSuffix` per test keeps each test's platform
  // channel registration from clobbering another's, same as
  // `messaging_stack_test.dart`.
  TransportService newTransportService() => TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'devices-view-test-${suffixCounter++}',
      );

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
}
