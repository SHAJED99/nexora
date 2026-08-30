// features/chat/presentation — ChatView vs design/screens/chat.md
// (E06-T11). Fast in-suite contract-element check, in the style
// `conversations_view_test.dart` established — the real gate is
// `make design-verify SCREEN=chat IMPL=flutter`, run and recorded
// separately in this task's Run log.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/chat/presentation/chat_controller.dart';
import 'package:nexora/features/chat/presentation/chat_view.dart';
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
          messageChannelSuffix: 'chat-view-${suffixCounter++}',
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

  ChatController controllerFor(String conversationId) {
    return ChatController(
      conversationId: conversationId,
      repo: ConversationRepository(db, selfDeviceId: 'self-device'),
      send: stack.sendMessage,
      sessions: stack.prekeyExchange,
      crypto: stack.cryptoService,
      acks: stack.deliveryAckService,
    );
  }

  testWidgets('test_EARS_COMM_empty_thread_shows_gap_008_pill', (
    tester,
  ) async {
    final controller = controllerFor('peer-device');
    Get.put<ChatController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    // GAP-008 — empty thread, header/composer unchanged.
    expect(find.text('No messages yet — say hello'), findsOneWidget);
    expect(find.text('End-to-end encrypted'), findsOneWidget);
    expect(find.text('Secure message...'), findsOneWidget);
  });

  testWidgets('test_chat_view_matches_contract_elements', (tester) async {
    await RelationshipRepository(db).upsert('peer-device', RelationshipState.trusted);
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'm-1',
            conversationId: 'peer-device',
            senderDeviceId: 'peer-device',
            sequenceNumber: 0,
            ciphertext: Uint8List(0),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            deliveryState: DeliveryState.accepted.name,
          ),
        );
    final controller = controllerFor('peer-device');
    Get.put<ChatController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    // Header — elements 1-8.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('peer-device'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsWidgets);
    expect(find.text('End-to-end encrypted'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    // Day pill — element 9.
    expect(find.text('Today'), findsOneWidget);

    // Composer — elements 26-31.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Secure message...'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('test_add_and_mic_are_rendered_and_inert', (tester) async {
    final controller = controllerFor('peer-device');
    Get.put<ChatController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    // Neither tap sent anything or recorded a message row — GAP-010.
    expect(controller.messages, isEmpty);
    expect(controller.sendError.value, isEmpty);

    // Drain both snackbars' own auto-dismiss timers — see the note on
    // `test_EARS_COMM_25_blocked_peer_shows_a_reason_and_keeps_the_text`.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'test_EARS_COMM_25_blocked_peer_shows_a_reason_and_keeps_the_text',
    (tester) async {
      await RelationshipRepository(db)
          .upsert('blocked-peer', RelationshipState.blocked);
      final controller = controllerFor('blocked-peer');
      Get.put<ChatController>(controller);

      await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'are you there?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // Composed text is restored into the composer, never silently
      // dropped (EARS-COMM-25) — a specific, displayable reason surfaced
      // via the snackbar primitive GAP-004's stub already established.
      expect(find.text('are you there?'), findsOneWidget);
      expect(find.text('You have blocked this contact.'), findsOneWidget);

      // Drain the snackbar's own auto-dismiss timer before the test ends —
      // otherwise `flutter_test` fails the test on a "Timer still pending"
      // invariant check even though the assertions above already passed.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('test_scroll_starting_on_a_bubble_does_not_send', (
    tester,
  ) async {
    // Regression for T10's Finding A (Listener never entering the gesture
    // arena) — every tap target on this screen is InkWell/Material/
    // TextField, never Listener.
    await RelationshipRepository(db)
        .upsert('peer-device', RelationshipState.trusted);
    for (var i = 0; i < 8; i++) {
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'm-$i',
              conversationId: 'peer-device',
              senderDeviceId: 'peer-device',
              sequenceNumber: i,
              ciphertext: Uint8List(0),
              createdAt: 1000 + i,
              deliveryState: DeliveryState.accepted.name,
            ),
          );
    }
    final controller = controllerFor('peer-device');
    Get.put<ChatController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    await tester.dragFrom(tester.getCenter(listFinder), const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(controller.sendError.value, isEmpty);
  });

  testWidgets('test_header_and_composer_buttons_expose_semantics', (
    tester,
  ) async {
    // Regression for T10's Finding B (Listener contributes zero
    // semantics) — every InkWell tap target below carries a real `tap`
    // action for a screen reader.
    final controller = controllerFor('peer-device');
    Get.put<ChatController>(controller);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    final backSemantics = tester.getSemantics(find.byIcon(Icons.arrow_back));
    expect(backSemantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final micSemantics = tester.getSemantics(find.byIcon(Icons.mic));
    expect(micSemantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });
}
