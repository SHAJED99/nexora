// features/dashboard/presentation — DashboardView vs
// design/screens/dashboard.md (E06-T12, widened E08-T08). EARS-COMM-2/26/27
// plus a fast in-suite contract-element check, in the style
// `test/features/devices/presentation/devices_view_test.dart` established
// (the real gate is `make design-verify SCREEN=dashboard IMPL=flutter`, run
// and recorded separately in this task's Run log).
//
// NOT in E08-T08's own `files:` fence, but this file's `DashboardController`
// construction sites break at compile time the moment that controller's
// constructor gains a required `storage` parameter (task §5's own
// contract) — a fence gap the task file left, not new scope this file is
// choosing for itself. Fixed here to the minimum needed to keep this suite
// compiling and its EARS coverage accurate: a real `StorageManager` per
// construction site (mirrors `dashboard_controller_test.dart`'s own
// `_newStorageManager`), and `test_dashboard_view_matches_contract_elements`'s
// Local Storage assertions updated from the retired static placeholder to
// the real, now-measured collapsed-card content (E08-T08's own Deviations
// record this explicitly).
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart' show SmartModeThresholds;
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_controller.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_view.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// Mirrors `dashboard_controller_test.dart`'s own `_newStorageManager` — a
/// plain, real `StorageManager` over [db].
StorageManager _newStorageManager(AppDatabase db) {
  final log = StorageDecisionLog(db: db);
  return StorageManager(
    settings: StorageSettingsRepository(db: db),
    inventory: StorageInventory(db: db, databaseFileBytes: () async => 0),
    smart: SmartModePolicy(thresholds: SmartModeThresholds.defaults()),
    executor: RetentionExecutor(db: db, log: log),
    log: log,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  late AppDatabase db;
  late MessagingStack stack;
  late String suffix;

  Future<MessagingStack> newStack() async {
    suffix = 'dashboard-view-${suffixCounter++}';
    return MessagingStack.create(
      db: db,
      selfDeviceId: 'self-device',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      ),
    );
  }

  setUp(() async {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    stack = await newStack();
  });

  tearDown(() async {
    await stack.dispose();
    Get.reset();
  });

  DashboardController putController() {
    final controller = DashboardController(
      stack: stack,
      repo: ConversationRepository(db, selfDeviceId: 'self-device'),
      links: LinkQualityFeed(
        transport: stack.transport,
        routing: stack.routingEngine,
      ),
      crypto: stack.cryptoService,
      storage: _newStorageManager(db),
    );
    Get.put<DashboardController>(controller);
    return controller;
  }

  void pushDeviceDiscovered(String id) {
    final device = TransportDevice(
      id: id,
      displayName: id,
      type: TransportType.bluetooth,
    );
    final eventMessage =
        TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
      eventMessage,
      (ByteData? _) {},
    );
  }

  void pushLinkQuality(String deviceId, int latencyMs, double lossRate) {
    final eventMessage = TransportEventsApi.pigeonChannelCodec.encodeMessage(
      <Object?>[deviceId, latencyMs, lossRate],
    )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onLinkQuality.$suffix',
      eventMessage,
      (ByteData? _) {},
    );
  }

  testWidgets(
      'test_EARS_COMM_2_status_card_shows_a_simple_reading', (tester) async {
    putController();
    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pumpAndSettle();

    // No peers known yet -- GAP-013's "No peers nearby" reading, one line,
    // with no route/transport/hop detail anywhere on this screen.
    expect(find.text('No peers nearby'), findsOneWidget);
    expect(find.textContaining('hop'), findsNothing);
    expect(find.textContaining('route:'), findsNothing);
  });

  testWidgets(
      'test_EARS_COMM_2_status_card_taps_through_to_devices', (tester) async {
    putController();
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/dashboard',
        getPages: [
          GetPage<dynamic>(name: '/dashboard', page: () => const DashboardView()),
          GetPage<dynamic>(
            name: '/devices',
            page: () => const Scaffold(body: Text('devices screen stub')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Network Status'));
    await tester.pumpAndSettle();

    expect(find.text('devices screen stub'), findsOneWidget);
  });

  testWidgets(
      'test_EARS_COMM_26_no_measurement_shows_no_latency', (tester) async {
    putController();
    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pumpAndSettle();

    // The absence of ANY digit-bearing latency string, not just of the
    // literal "24ms" (task §8's own instruction).
    expect(find.text('Not measured yet'), findsOneWidget);
    final digitBearingLatency = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      final text = widget.data ?? '';
      return RegExp(r'\dms\b').hasMatch(text);
    });
    expect(digitBearingLatency, findsNothing);
  });

  testWidgets(
      'test_EARS_COMM_26_real_measurement_is_displayed', (tester) async {
    putController();
    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pumpAndSettle();

    pushDeviceDiscovered('neighbor-1');
    pushLinkQuality('neighbor-1', 88, 0.0);
    await tester.pumpAndSettle();

    expect(find.text('88ms'), findsOneWidget);
  });

  testWidgets(
      'test_EARS_COMM_27_unavailable_stack_still_renders', (tester) async {
    final degradedDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(degradedDb.close);
    final degradedStack = await MessagingStack.create(
      db: degradedDb,
      selfDeviceId: '',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'dashboard-view-degraded-${suffixCounter++}',
      ),
    );
    addTearDown(degradedStack.dispose);

    final controller = DashboardController(
      stack: degradedStack,
      repo: ConversationRepository(degradedDb, selfDeviceId: ''),
      links: LinkQualityFeed(
        transport: degradedStack.transport,
        routing: degradedStack.routingEngine,
      ),
      crypto: degradedStack.cryptoService,
      storage: _newStorageManager(degradedDb),
    );
    Get.put<DashboardController>(controller);

    // Must not throw while pumping.
    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Messaging is unavailable'), findsOneWidget);
  });

  testWidgets('test_dashboard_view_matches_contract_elements', (tester) async {
    final repository = RelationshipRepository(db);
    await repository.upsert('device-a', RelationshipState.trusted);
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'm-a1',
            conversationId: 'device-a',
            senderDeviceId: 'device-a',
            sequenceNumber: 1,
            ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            deliveryState: DeliveryState.accepted.name,
          ),
        );

    putController();
    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pumpAndSettle();

    // Header — elements 1-4.
    expect(find.byIcon(Icons.hub), findsOneWidget);
    expect(find.text('NEXORA'), findsOneWidget);

    // Network Status card — elements 5-14.
    expect(find.text('Network Status'), findsOneWidget);
    expect(find.text('Primary Node Connection'), findsOneWidget);
    expect(find.text('Encryption'), findsOneWidget);
    expect(find.text('Secure'), findsOneWidget);
    expect(find.text('Latency'), findsOneWidget);

    // Local Storage card — elements 15-18 (E08-T08: real figures, not the
    // retired static placeholder). Default Smart Mode, no aged data seeded
    // -- nothing actionable, so the warning glyph is absent (element 17's
    // own conditional rendering) and the summary line names the real
    // threshold (`SmartModeThresholds.defaults().ageThresholdDays`), never
    // the old fabricated "10 days".
    expect(find.text('Local Storage'), findsOneWidget);
    expect(find.text('Smart Mode - Older than 45 days'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsNothing);

    // Recent Conversations — element 19 + at least one real row.
    expect(find.text('Recent Conversations'), findsOneWidget);
    expect(find.text('device-a'), findsOneWidget);

    // Bottom nav — elements 35-46.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets(
      'test_recent_conversations_row_tap_opens_the_chat', (tester) async {
    final repository = RelationshipRepository(db);
    await repository.upsert('device-a', RelationshipState.trusted);
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'm-a1',
            conversationId: 'device-a',
            senderDeviceId: 'device-a',
            sequenceNumber: 1,
            ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            deliveryState: DeliveryState.accepted.name,
          ),
        );
    putController();

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/dashboard',
        getPages: [
          GetPage<dynamic>(name: '/dashboard', page: () => const DashboardView()),
          GetPage<dynamic>(
            name: '/chat/:id',
            page: () => Text('chat with ${Get.parameters['id']}'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('device-a'));
    await tester.pumpAndSettle();

    expect(find.text('chat with device-a'), findsOneWidget);
  });

  testWidgets(
      'test_queued_own_message_shows_the_exact_queued_copy', (tester) async {
    final repository = RelationshipRepository(db);
    await repository.upsert('device-queued', RelationshipState.trusted);
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'm-queued',
            conversationId: 'device-queued',
            senderDeviceId: 'self-device',
            sequenceNumber: 1,
            ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            deliveryState: DeliveryState.queued.name,
          ),
        );
    putController();

    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pumpAndSettle();

    expect(
      find.text('Message queued — will send when connected.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });
}
