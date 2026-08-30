// features/conversations/presentation — ConversationsView vs
// design/screens/conversations.md (E06-T10). EARS-COMM-22 plus a fast
// in-suite contract-element check, in the style
// `test/features/devices/presentation/devices_view_test.dart` established
// (the real gate is `make design-verify SCREEN=conversations IMPL=flutter`,
// run and recorded separately in this task's Run log).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/conversations/presentation/conversations_controller.dart';
import 'package:nexora/features/conversations/presentation/conversations_view.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  late AppDatabase db;
  late MessagingStack stack;

  Future<MessagingStack> newStack() => MessagingStack.create(
    db: db,
    selfDeviceId: 'self-device',
    transport: TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: 'conversations-view-${suffixCounter++}',
    ),
  );

  setUp(() async {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    stack = await newStack();
  });

  tearDown(() async {
    await stack.dispose();
    Get.reset();
  });

  testWidgets('test_EARS_COMM_22_empty_state_keeps_headings_and_nav', (
    tester,
  ) async {
    final controller = ConversationsController(
      repo: ConversationRepository(db, selfDeviceId: 'self-device'),
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ConversationsView()));
    await tester.pumpAndSettle();

    // GAP-007 — empty Personal treatment, headings and nav still present.
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    // GAP-006 — Groups heading stays even with nothing under it.
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('No groups yet'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('test_conversations_view_matches_contract_elements', (
    tester,
  ) async {
    final repo = ConversationRepository(db, selfDeviceId: 'self-device');
    await RelationshipRepository(
      db,
    ).upsert('device-a', RelationshipState.trusted);
    await db
        .into(db.messages)
        .insert(
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

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ConversationsView()));
    await tester.pumpAndSettle();

    // Header — elements 1-3: hub + "NEXORA", 4-5: search action.
    expect(find.byIcon(Icons.hub), findsOneWidget);
    expect(find.text('NEXORA'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsWidgets);

    // Search field — elements 6-7.
    expect(find.text('Search conversations...'), findsOneWidget);

    // Section headings — elements 8, 21.
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('No groups yet'), findsOneWidget);

    // One populated row — the device id stands in for a name (GAP-003),
    // lock glyph present (element 14/20).
    expect(find.text('device-a'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    // Bottom nav — elements 34-45.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard), findsOneWidget);
    expect(find.byIcon(Icons.chat), findsOneWidget);
    expect(find.byIcon(Icons.router), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('search filters the loaded list client-side', (tester) async {
    final repo = ConversationRepository(db, selfDeviceId: 'self-device');
    await RelationshipRepository(
      db,
    ).upsert('device-alpha', RelationshipState.trusted);
    await RelationshipRepository(
      db,
    ).upsert('device-beta', RelationshipState.trusted);
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'm-alpha',
            conversationId: 'device-alpha',
            senderDeviceId: 'device-alpha',
            sequenceNumber: 1,
            ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
            createdAt: 1000,
            deliveryState: DeliveryState.accepted.name,
          ),
        );
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'm-beta',
            conversationId: 'device-beta',
            senderDeviceId: 'device-beta',
            sequenceNumber: 1,
            ciphertext: Uint8List.fromList(List<int>.filled(16, 2)),
            createdAt: 2000,
            deliveryState: DeliveryState.accepted.name,
          ),
        );

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ConversationsView()));
    await tester.pumpAndSettle();

    expect(find.text('device-alpha'), findsOneWidget);
    expect(find.text('device-beta'), findsOneWidget);

    controller.search('alpha');
    await tester.pumpAndSettle();

    expect(find.text('device-alpha'), findsOneWidget);
    expect(find.text('device-beta'), findsNothing);
  });

  testWidgets('test_scroll_starting_on_a_row_does_not_open_it', (tester) async {
    // Regression for the reviewer's Finding A: a `Listener`-based tap
    // handler fires on `onPointerUp` regardless of how far the pointer
    // travelled first, so a scroll/drag that starts on a row used to
    // navigate into it. `InkWell`/`GestureDetector` correctly enter the
    // gesture arena and lose the tap once a drag is recognised.
    final repo = ConversationRepository(db, selfDeviceId: 'self-device');
    final relationships = RelationshipRepository(db);
    for (var i = 0; i < 12; i++) {
      final id = 'device-$i';
      await relationships.upsert(id, RelationshipState.trusted);
      await db
          .into(db.messages)
          .insert(
            MessagesCompanion.insert(
              id: 'm-$i',
              conversationId: id,
              senderDeviceId: id,
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList(List<int>.filled(16, i)),
              createdAt: 1000 + i,
              deliveryState: DeliveryState.accepted.name,
            ),
          );
    }

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    final navigated = <String>[];
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/conversations',
        getPages: [
          GetPage(
            name: '/conversations',
            page: () => const ConversationsView(),
          ),
          GetPage(
            name: '/chat/:id',
            page: () {
              navigated.add(Get.parameters['id'] ?? '');
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // A deliberate 180px scroll starting on a row must scroll, not tap.
    final rowFinder = find.text('device-11');
    expect(rowFinder, findsOneWidget);
    await tester.dragFrom(tester.getCenter(rowFinder), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(navigated, isEmpty);
  });

  testWidgets('test_conversation_row_and_nav_item_expose_semantics', (
    tester,
  ) async {
    // Regression for the reviewer's Finding B: `Listener` contributes zero
    // semantics, so a screen-reader user could not open a conversation or
    // use the bottom nav. `InkWell` restores the `tap` action + `isButton`.
    final repo = ConversationRepository(db, selfDeviceId: 'self-device');
    await RelationshipRepository(
      db,
    ).upsert('device-a', RelationshipState.trusted);
    await db
        .into(db.messages)
        .insert(
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

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    final handle = tester.ensureSemantics();

    await tester.pumpWidget(const GetMaterialApp(home: ConversationsView()));
    await tester.pumpAndSettle();

    final rowSemantics = tester.getSemantics(find.text('device-a'));
    expect(
      rowSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    final navSemantics = tester.getSemantics(find.text('Devices'));
    expect(
      navSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    handle.dispose();
  });
}
