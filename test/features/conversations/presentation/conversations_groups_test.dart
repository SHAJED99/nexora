// features/conversations/presentation — the Groups section renders real
// groups (E07-T08, closes GAP-006). EARS-UI-3/4 plus the task's own
// mechanically-checked self-review items (§9): the shared delivery-glyph
// mapping is reused (not re-derived), no "create group" affordance is
// rendered, and no raw `Listener` widget is used anywhere on this screen.
//
// Mirrors `conversations_controller_test.dart`'s `_insertGroup`/
// `_insertMember` helpers for the simple (no-crypto) cases, and
// `send_group_message_use_case_test.dart`'s two-stack wiring helpers
// (`wireSend`/`connectPeer`/`sendAndDeliver`-style) for the one test that
// proves a REAL group-message decrypt drives the sender-prefix + preview —
// exactly the division `conversations_controller.dart`'s own header
// documents E06-T10 already established for Personal, reused rather than
// invented a second way for Groups.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Value;
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/conversations/presentation/conversations_controller.dart';
import 'package:nexora/features/conversations/presentation/conversations_view.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/domain/group_message_envelope.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

Future<void> _insertGroup(
  AppDatabase db, {
  required String id,
  required String name,
  required String ownerDeviceId,
}) async {
  await db.into(db.groups).insert(
        GroupsCompanion.insert(
          id: id,
          name: name,
          createdAt: 0,
          createdByDeviceId: ownerDeviceId,
        ),
      );
}

Future<void> _insertMember(
  AppDatabase db, {
  required String groupId,
  required String deviceId,
  String role = 'member',
}) async {
  await db.into(db.groupMembers).insert(
        GroupMembersCompanion.insert(
          groupId: groupId,
          deviceId: deviceId,
          role: role,
          joinedAtEpoch: 0,
        ),
      );
}

Future<void> _insertMessage(
  AppDatabase db, {
  required String id,
  required String conversationId,
  required String senderDeviceId,
  required int sequenceNumber,
  required Uint8List ciphertext,
  required int createdAt,
  DeliveryState state = DeliveryState.accepted,
}) async {
  await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: conversationId,
          senderDeviceId: senderDeviceId,
          sequenceNumber: sequenceNumber,
          ciphertext: ciphertext,
          createdAt: createdAt,
          deliveryState: state.name,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;
  String nextSuffix() => 'conversations-groups-${suffixCounter++}';

  late AppDatabase db;
  late MessagingStack stack;

  setUp(() async {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'self-device',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: nextSuffix(),
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
  });

  tearDown(() async {
    await stack.dispose();
    Get.reset();
  });

  // --- EARS-UI-4: the heading survives an empty Groups list --------------

  testWidgets(
      'test_EARS_UI_4_groups_heading_is_present_when_the_list_is_empty',
      (tester) async {
    final controller = ConversationsController(
      repo: ConversationRepository(db, selfDeviceId: 'self-device'),
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ConversationsView()));
    await tester.pumpAndSettle();

    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('No groups yet'), findsOneWidget);
    // The heading is not merged into one conditional with the rows (task
    // §6's own named risk) -- it is present alongside the Personal section's
    // own independent empty treatment too.
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  // --- EARS-UI-3: blocking is asymmetric (E07-T07 §2) ---------------------

  testWidgets(
      'test_EARS_UI_3_group_containing_a_blocked_contact_is_still_listed',
      (tester) async {
    final relationships = RelationshipRepository(db);
    await relationships.upsert('device-blocked', RelationshipState.blocked);
    await _insertGroup(
      db,
      id: 'g:team',
      name: 'Team',
      ownerDeviceId: 'self-device',
    );
    await _insertMember(db, groupId: 'g:team', deviceId: 'self-device');
    await _insertMember(db, groupId: 'g:team', deviceId: 'device-blocked');
    await _insertMessage(
      db,
      id: 'm-g1',
      conversationId: 'g:team',
      senderDeviceId: 'device-blocked',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );

    final controller = ConversationsController(
      repo: ConversationRepository(db, selfDeviceId: 'self-device'),
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ConversationsView()));
    await tester.pumpAndSettle();

    // The group itself is not hidden -- a blocked contact being a member
    // does not hide the group (E07-T07 §2, restated by this task's §2).
    expect(find.text('Team'), findsOneWidget);
    expect(controller.groups.map((g) => g.conversationId), ['g:team']);
  });

  // --- E07-B01: tap must NOT navigate to the 1:1-only /chat/:id route -----
  //
  // Before this fix, this exact scenario asserted `navigated == ['g:team']`
  // -- the group row routed straight into `ChatController`, which is built
  // exclusively for a 1:1 peer id (`_peerDeviceId => conversationId`) and
  // cannot render or send a group conversation (E07-B01's repro: an
  // undecryptable-bubble thread and a non-retryable "Could not send this
  // message. Try again." on send). The human's fix direction (a) -- gate
  // the tap until the real group thread (GAP-020) ships, still blocked on
  // `OQ-E07-13` -- means the row must stay on `/conversations` and
  // acknowledge the tap honestly instead of silently misrouting.

  testWidgets(
      'test_EARS_UI_3_group_row_tap_does_not_navigate_to_the_1to1_chat_screen',
      (tester) async {
    await _insertGroup(
      db,
      id: 'g:team',
      name: 'Team',
      ownerDeviceId: 'self-device',
    );
    await _insertMember(db, groupId: 'g:team', deviceId: 'self-device');
    await _insertMember(db, groupId: 'g:team', deviceId: 'device-a');
    await _insertMessage(
      db,
      id: 'm-g1',
      conversationId: 'g:team',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );

    final controller = ConversationsController(
      repo: ConversationRepository(db, selfDeviceId: 'self-device'),
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

    expect(find.text('Team'), findsOneWidget);
    await tester.tap(find.text('Team'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // let the GetX snackbar overlay animate in.

    // Still on /conversations -- `ChatController` (1:1-only) was never
    // reached with a group id.
    expect(navigated, isEmpty);
    expect(Get.currentRoute, '/conversations');
    expect(find.byType(ConversationsView), findsOneWidget);

    // The tap is acknowledged honestly (the same "not built yet" SnackBar
    // primitive `SettingsController.openRow` already uses), not silently
    // swallowed.
    expect(find.text('Team'), findsWidgets);
    expect(find.text('Coming soon'), findsOneWidget);

    // Let the snackbar's own auto-dismiss timer finish before the test
    // ends, so no pending timer trips the framework's teardown check.
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  // --- The shared delivery-glyph mapping (GAP-009), not a local switch ----

  testWidgets(
      'test_delivery_glyphs_are_the_shared_mapping_not_a_local_switch',
      (tester) async {
    // Byte-identical to `chat_view.dart`'s/`dashboard_view.dart`'s
    // `_tickIconFor` and to this screen's own Personal-row mapping (E06-B03)
    // -- one group per `DeliveryState`, asserted against GAP-009's mapping,
    // proving `GroupRowViewModel.deliveryIcon` was built from
    // `tickIconFor` (`conversations_controller.dart`) and not a second,
    // independently-written `switch`.
    const expectedIcons = <DeliveryState, IconData>{
      DeliveryState.queued: Icons.radio_button_unchecked,
      DeliveryState.sent: Icons.check,
      DeliveryState.accepted: Icons.check,
      DeliveryState.stored: Icons.check,
      DeliveryState.delivered: Icons.done_all,
      DeliveryState.read: Icons.done_all,
      DeliveryState.failed: Icons.error_outline,
    };

    var seq = 0;
    for (final state in expectedIcons.keys) {
      final groupId = 'g:${state.name}';
      await _insertGroup(
        db,
        id: groupId,
        name: 'Group ${state.name}',
        ownerDeviceId: 'self-device',
      );
      await _insertMember(db, groupId: groupId, deviceId: 'self-device');
      await _insertMember(db, groupId: groupId, deviceId: 'device-a');
      await _insertMessage(
        db,
        id: 'm-${state.name}',
        conversationId: groupId,
        senderDeviceId: 'device-a',
        sequenceNumber: 1,
        ciphertext: Uint8List.fromList(List<int>.filled(16, seq++)),
        createdAt: 1000 + seq,
        state: state,
      );
    }

    final controller = ConversationsController(
      repo: ConversationRepository(db, selfDeviceId: 'self-device'),
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ConversationsView()));
    await tester.pumpAndSettle();

    expect(controller.groups, hasLength(expectedIcons.length));
    for (final row in controller.groups) {
      final stateName = row.conversationId.substring(2); // 'g:<name>'
      final state = DeliveryState.values.byName(stateName);
      expect(
        row.deliveryIcon,
        expectedIcons[state],
        reason:
            'DeliveryState.$stateName should render ${expectedIcons[state]} '
            'per GAP-009, via the shared tickIconFor mapping',
      );
    }
  });

  // --- §4: never a "create group" affordance ------------------------------

  testWidgets('test_no_create_group_affordance_is_rendered', (tester) async {
    await _insertGroup(
      db,
      id: 'g:team',
      name: 'Team',
      ownerDeviceId: 'self-device',
    );
    await _insertMember(db, groupId: 'g:team', deviceId: 'self-device');
    await _insertMember(db, groupId: 'g:team', deviceId: 'device-a');
    await _insertMessage(
      db,
      id: 'm-g1',
      conversationId: 'g:team',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );

    final controller = ConversationsController(
      repo: ConversationRepository(db, selfDeviceId: 'self-device'),
      crypto: stack.cryptoService,
      stack: stack,
    );
    Get.put<ConversationsController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: ConversationsView()));
    await tester.pumpAndSettle();

    // No icon or copy anywhere on this screen implies a create/new-group
    // affordance -- the design draws none on `conversations.md` (GAP-018's
    // entry point is still unapproved, task §4).
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.add_circle), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    expect(find.byIcon(Icons.group_add), findsNothing);
    expect(find.textContaining('New group'), findsNothing);
    expect(find.textContaining('Create group'), findsNothing);
  });

  // --- design-fidelity Rule 5 / L-frontend-001 ----------------------------

  test('test_no_raw_listener_widgets', () {
    // A SOURCE check, not a widget-tree one: `InkWell`/`GestureDetector`/
    // `Scrollable` legitimately build their OWN internal `Listener`s as an
    // implementation detail (a real `pumpWidget` of this screen finds over
    // a dozen of them, none authored by this file) -- so `find.byType
    // (Listener)` can never distinguish "the app wrote a raw Listener tap
    // handler" from "Flutter's own gesture machinery exists", and asserting
    // on it would be exactly the same category of tool-limitation-chasing
    // design-fidelity Rule 5 forbids in the other direction. The actual
    // regression this guards (E06-T10 swapping `InkWell` for `Listener` to
    // score better against the design-fidelity probe) is a SOURCE-level
    // fact — this task's own §9 self-review item is phrased the same way
    // ("Zero `Listener(` in the diff") — so check the source directly,
    // mirroring how the task's own self-review is written and verified.
    final source = File(
      'lib/features/conversations/presentation/conversations_view.dart',
    ).readAsStringSync();
    expect(
      source.contains('Listener('),
      isFalse,
      reason: 'conversations_view.dart must never construct a raw Listener '
          'as a tap handler (design-fidelity Rule 5 / L-frontend-001)',
    );
    expect(
      source.contains('InkWell('),
      isTrue,
      reason: 'the correct tap primitive must still be used',
    );
  });

  // --- The real division: decrypt happens here, prefix assembled here -----

  group('real group-message round trip', () {
    // Deliberately NOT the full mocked-transport/relay/distribution pipeline
    // `send_group_message_use_case_test.dart` uses for ITS OWN concern (that
    // the transport/relay/distribution wiring works) -- this screen's own
    // concern is narrower: given a message this device genuinely holds the
    // sender's chain for, does the controller decrypt it and assemble the
    // sender prefix correctly? So a second, independent `MessagingStack`
    // ('device-a') is used ONLY as a real `GroupCryptoService` to produce a
    // real chain + a real ciphertext, and that chain's raw record bytes are
    // copied directly into the receiver's `groupSenderKeys` table -- the
    // same end state E07-T04's real distribution produces, without this
    // task depending on E07-T04's/T06's own already-tested transport
    // mechanics to prove ITS behaviour.
    testWidgets(
        'test_EARS_UI_3_group_rows_render_name_time_preview_and_sender_prefix',
        (tester) async {
      final senderStack = await MessagingStack.create(
        db: AppDatabase.forTesting(NativeDatabase.memory()),
        selfDeviceId: 'device-a',
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: nextSuffix(),
        ),
      );
      addTearDown(senderStack.dispose);

      final groupId = await GroupRepository(senderStack.db).createGroup(
        name: 'Family',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['self-device'],
      );
      await senderStack.groupCryptoService.ensureOwnChain(
        groupId: groupId,
        epoch: 0,
      );

      // Copy the chain state to the receiver's own database RIGHT HERE --
      // at the exact point a real key-distribution (E07-T04) would hand it
      // over, i.e. BEFORE any message is encrypted. Copying it any later
      // (after `encryptForGroup` below has advanced the sender's own chain
      // past message 0's iteration) would hand the receiver a chain that
      // can no longer derive message 0's key at all -- the same forward-
      // security property that makes Signal's ratchet a ratchet. Each
      // side's copy then evolves independently from here, exactly like two
      // real devices' independent local state (ADR-0005's no-server
      // design; `send_group_message_use_case_test.dart`'s own
      // `seedGroupView` precedent).
      final aChainRow = await (senderStack.db.select(
        senderStack.db.groupSenderKeys,
      )..where(
              (t) =>
                  t.groupId.equals(groupId) & t.senderDeviceId.equals('device-a'),
            ))
          .getSingle();
      await db.into(db.groupSenderKeys).insert(
            GroupSenderKeysCompanion.insert(
              groupId: groupId,
              senderDeviceId: 'device-a',
              membershipEpoch: 0,
              record: aChainRow.record,
              updatedAt: aChainRow.updatedAt,
            ),
          );

      // The plaintext `encryptForGroup` encrypts is the SERIALIZED
      // envelope, not the raw text -- exactly what `SendGroupMessageUseCase`
      // does on the real send path and what `handleGroupMessage`/this
      // controller's own `_resolveGroupPreview` expects to
      // `GroupMessageEnvelope.deserialize` after decrypting.
      final envelope = GroupMessageEnvelope(
        groupId: groupId,
        epoch: 0,
        senderDeviceId: 'device-a',
        messageId: 'm-1',
        sequenceNumber: 0,
        createdAtMs: 1000,
        body: Uint8List.fromList(utf8.encode("Don't forget dinner at 7!")),
      );
      final ciphertext = await senderStack.groupCryptoService.encryptForGroup(
        groupId: groupId,
        epoch: 0,
        plaintext: envelope.serialize(),
      );

      // The receiver's ('self-device') own view of the same real-world
      // group.
      await _insertGroup(
        db,
        id: groupId,
        name: 'Family',
        ownerDeviceId: 'device-a',
      );
      await _insertMember(db, groupId: groupId, deviceId: 'device-a', role: 'owner');
      await _insertMember(db, groupId: groupId, deviceId: 'self-device');

      await _insertMessage(
        db,
        id: 'm-1',
        conversationId: groupId,
        senderDeviceId: 'device-a',
        sequenceNumber: 0,
        ciphertext: ciphertext,
        createdAt: 1000,
      );

      // 'self-device' (the outer `stack`/`db`) is the receiver -- decrypts
      // the real message (it genuinely holds device-a's chain, copied
      // above) and prefixes the sender's name (GAP-003 -- the raw device id
      // stands in for a display name, same treatment as every other row on
      // this screen).
      final controller = ConversationsController(
        repo: ConversationRepository(db, selfDeviceId: 'self-device'),
        crypto: stack.cryptoService,
        stack: stack,
      );
      Get.put<ConversationsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: ConversationsView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Family'), findsOneWidget);
      expect(
        find.textContaining("Don't forget dinner at 7!"),
        findsOneWidget,
      );
      expect(find.textContaining('device-a:'), findsOneWidget);

      expect(controller.groups, hasLength(1));
      final row = controller.groups.single;
      expect(row.name, 'Family');
      expect(row.preview, "Don't forget dinner at 7!");
      expect(row.senderPrefix, 'device-a:');
    });

    testWidgets(
        'test_E04_B20_group_preview_uses_persisted_body_without_a_second_decrypt',
        (tester) async {
      // E04-B20: the stored ciphertext is deliberately unusable, so the
      // preview can only be right if it comes from `plaintextPayload`.
      // Reverting the controller change makes `decryptFromGroup` throw on
      // these bytes and the preview degrade to empty.
      final groupId = await GroupRepository(stack.db).createGroup(
        name: 'Persisted',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['self-device'],
      );
      await _insertMessage(
        db,
        id: 'm-b20',
        conversationId: groupId,
        senderDeviceId: 'device-a',
        sequenceNumber: 0,
        ciphertext: Uint8List.fromList(utf8.encode('not a sender key message')),
        createdAt: 1000,
      );
      await (db.update(db.messages)..where((t) => t.id.equals('m-b20'))).write(
        MessagesCompanion(
          plaintextPayload: Value(
            Uint8List.fromList(utf8.encode('persisted group body')),
          ),
        ),
      );

      final controller = ConversationsController(
        repo: ConversationRepository(db, selfDeviceId: 'self-device'),
        crypto: stack.cryptoService,
        stack: stack,
      );
      Get.put<ConversationsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: ConversationsView()),
      );
      await tester.pumpAndSettle();

      expect(controller.groups, hasLength(1));
      expect(controller.groups.single.preview, 'persisted group body');
    });

    testWidgets(
        'test_own_outgoing_group_message_preview_degrades_gracefully',
        (tester) async {
      // A single device is never both the sender AND a receiver of its own
      // sender-key chain (group_crypto_service_test.dart's own documented
      // asymmetry, mirroring the 1:1 Double Ratchet case E06-T10 already
      // handles for Personal) -- so this device's OWN last message in a
      // group it belongs to must degrade to an empty preview, never an
      // error row, exactly like `_resolvePreview`'s existing contract.
      final groupId = await GroupRepository(stack.db).createGroup(
        name: 'Solo',
        ownerDeviceId: 'self-device',
        memberDeviceIds: ['device-a'],
      );
      await stack.groupCryptoService.ensureOwnChain(
        groupId: groupId,
        epoch: 0,
      );
      final ciphertext = await stack.groupCryptoService.encryptForGroup(
        groupId: groupId,
        epoch: 0,
        plaintext: Uint8List.fromList('hi there'.codeUnits),
      );
      await _insertMessage(
        db,
        id: 'm-self-1',
        conversationId: groupId,
        senderDeviceId: 'self-device',
        sequenceNumber: 1,
        ciphertext: ciphertext,
        createdAt: 1000,
      );

      final controller = ConversationsController(
        repo: ConversationRepository(db, selfDeviceId: 'self-device'),
        crypto: stack.cryptoService,
        stack: stack,
      );
      Get.put<ConversationsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: ConversationsView()),
      );
      await tester.pumpAndSettle();

      expect(controller.groups, hasLength(1));
      final row = controller.groups.single;
      expect(row.name, 'Solo');
      expect(row.preview, isEmpty);
      // Outgoing -- no self-attribution (GAP-020's rule, reused here).
      expect(row.senderPrefix, isNull);
    });
  });
}
