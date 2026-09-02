// features/dashboard/presentation — DashboardController (E06-T12).
//
// EARS-COMM-2 (the epic-level FR-UI-004 criterion, connectivity-reading
// half) / EARS-COMM-26 (no fabricated latency) / EARS-COMM-27 (stack
// unavailable still renders honestly), plus
// `test_recent_conversations_use_the_shared_read_model` (task §6's named
// risk: two screens must not define the delivery-state mapping twice).
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/conversations/presentation/conversations_controller.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_controller.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

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

/// Seeds a group conversation (E07-T01's tables) so a group row reaches this
/// controller through E07-T07's widened read model.
Future<void> _insertGroup(
  AppDatabase db, {
  required String id,
  required String name,
}) async {
  await db.into(db.groups).insert(
        GroupsCompanion.insert(
          id: id,
          name: name,
          createdAt: 0,
          createdByDeviceId: 'self-device',
        ),
      );
}

Future<void> _insertMember(
  AppDatabase db, {
  required String groupId,
  required String deviceId,
}) async {
  await db.into(db.groupMembers).insert(
        GroupMembersCompanion.insert(
          groupId: groupId,
          deviceId: deviceId,
          role: 'member',
          joinedAtEpoch: 0,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  late AppDatabase db;
  late MessagingStack stack;
  late ConversationRepository repo;
  late RelationshipRepository relationships;
  late String suffix;

  setUp(() async {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relationships = RelationshipRepository(db);
    repo = ConversationRepository(db, selfDeviceId: 'self-device');
    suffix = 'dashboard-controller-${suffixCounter++}';
    stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'self-device',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
  });

  tearDown(() async {
    await stack.dispose();
    Get.reset();
  });

  DashboardController newController() => DashboardController(
        stack: stack,
        repo: repo,
        links: LinkQualityFeed(
          transport: stack.transport,
          routing: stack.routingEngine,
        ),
        crypto: stack.cryptoService,
      );

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

  test('test_EARS_COMM_2_default_reading_is_no_peers_with_no_peers_known', () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.reading, ConnectivityReading.noPeers);
    controller.onClose();
  });

  test(
      'test_EARS_COMM_2_reading_becomes_connected_once_a_route_exists',
      () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.networkStatus.value.reading, ConnectivityReading.noPeers);

    pushDeviceDiscovered('neighbor-1');
    pushLinkQuality('neighbor-1', 42, 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.reading, ConnectivityReading.connected);
    controller.onClose();
  });

  test(
      'test_EARS_COMM_2_reading_is_no_route_when_a_peer_is_known_but_unreachable',
      () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // A peer is discovered but never reports a link measurement, so
    // RoutingEngine has no known link to it -- computeRoute stays null.
    pushDeviceDiscovered('neighbor-unreachable');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.reading, ConnectivityReading.noRoute);
    controller.onClose();
  });

  test('test_EARS_COMM_26_no_measurement_shows_no_latency', () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.latencyMs, isNull);
    controller.onClose();
  });

  test('test_EARS_COMM_26_real_measurement_is_displayed', () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    pushDeviceDiscovered('neighbor-1');
    pushLinkQuality('neighbor-1', 77, 0.05);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.latencyMs, 77);
    controller.onClose();
  });

  test('test_EARS_COMM_27_unavailable_stack_reports_an_honest_error', () async {
    // A degraded stack (T03's own contract: never throws, `status` carries
    // the reason) -- constructed with an empty selfDeviceId, the documented
    // "no local device identity yet" unavailable case.
    final degradedDb = AppDatabase.forTesting(NativeDatabase.memory());
    final degradedStack = await MessagingStack.create(
      db: degradedDb,
      selfDeviceId: '',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'dashboard-degraded-${suffixCounter++}',
      ),
    );
    addTearDown(degradedStack.dispose);
    expect(degradedStack.status.isReady, isFalse);

    final controller = DashboardController(
      stack: degradedStack,
      repo: ConversationRepository(degradedDb, selfDeviceId: ''),
      links: LinkQualityFeed(
        transport: degradedStack.transport,
        routing: degradedStack.routingEngine,
      ),
      crypto: degradedStack.cryptoService,
    );

    // Must not throw.
    expect(() => controller.onInit(), returnsNormally);
    expect(controller.errorMessage.value, isNotEmpty);
    expect(controller.loading.value, isFalse);
    controller.onClose();
  });

  test('test_recent_conversations_use_the_shared_read_model', () async {
    await relationships.upsert('device-a', RelationshipState.trusted);
    await relationships.upsert('device-blocked', RelationshipState.blocked);
    await _insertMessage(
      db,
      id: 'm-a1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );
    await _insertMessage(
      db,
      id: 'm-blocked',
      conversationId: 'device-blocked',
      senderDeviceId: 'device-blocked',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 2)),
      createdAt: 2000,
    );
    await relationships.upsert('device-b', RelationshipState.allowed);
    await _insertMessage(
      db,
      id: 'm-b1',
      conversationId: 'device-b',
      senderDeviceId: 'device-b',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 3)),
      createdAt: 3000,
    );

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Same ordering (most recent first) and same blocked-exclusion as
    // ConversationsController's own EARS-COMM-20 tests, over identical
    // seeded data -- and the SAME `ConversationTile` type, not a
    // dashboard-only reimplementation.
    expect(controller.recent, everyElement(isA<ConversationTile>()));
    expect(
      controller.recent.map((t) => t.peerDeviceId).toList(),
      ['device-b', 'device-a'],
    );
    controller.onClose();
  });

  // E07-T07 / OQ-E07-T07-1: the widened read model also emits group rows,
  // which carry no `peerDeviceId`. Recent Conversations renders the shared
  // personal `ConversationTile` and has no group treatment yet (E07-T08), so
  // group rows are filtered out BEFORE the three-row cap — filtering after
  // it would silently shrink the section below its designed row count.
  test('test_recent_conversations_skip_groups_before_the_row_cap', () async {
    for (var i = 0; i < 3; i++) {
      await relationships.upsert('device-$i', RelationshipState.trusted);
      await _insertMessage(
        db,
        id: 'm-$i',
        conversationId: 'device-$i',
        senderDeviceId: 'device-$i',
        sequenceNumber: 1,
        ciphertext: Uint8List.fromList(List<int>.filled(16, i + 1)),
        createdAt: 1000 + i,
      );
    }
    // Newest activity of all — it would occupy a capped slot if it were not
    // filtered first.
    await _insertGroup(db, id: 'g:team', name: 'Team');
    await _insertMember(db, groupId: 'g:team', deviceId: 'self-device');
    await _insertMember(db, groupId: 'g:team', deviceId: 'device-0');
    await _insertMessage(
      db,
      id: 'm-g1',
      conversationId: 'g:team',
      senderDeviceId: 'device-0',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 9)),
      createdAt: 9000,
    );

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.errorMessage.value, isEmpty);
    expect(controller.recent.length, kDashboardRecentConversationCount);
    expect(
      controller.recent.map((t) => t.peerDeviceId).toList(),
      ['device-2', 'device-1', 'device-0'],
    );
    controller.onClose();
  });

  test('test_recent_conversations_capped_at_the_designs_row_count', () async {
    for (var i = 0; i < 5; i++) {
      await relationships.upsert('device-$i', RelationshipState.trusted);
      await _insertMessage(
        db,
        id: 'm-$i',
        conversationId: 'device-$i',
        senderDeviceId: 'device-$i',
        sequenceNumber: 1,
        ciphertext: Uint8List.fromList(List<int>.filled(16, i)),
        createdAt: 1000 * (i + 1),
      );
    }

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.recent.length, kDashboardRecentConversationCount);
    controller.onClose();
  });

  test(
      'test_storage_usage_is_the_disclosed_placeholder_never_a_fabricated_percentage',
      () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.storageUsage.value.isMeasured, isFalse);
    expect(controller.storageUsage.value.percentUsed, isNull);
    controller.onClose();
  });

  test('test_encryption_secure_reflects_messaging_stack_status', () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.encryptionSecure, isTrue);
    controller.onClose();
  });
}
