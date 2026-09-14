// Tests for SendGroupMessageUseCase (E07-T06, EARS-COMM-29/30/31/32,
// FR-ROUTE-003).
//
// `_CountingGroupCryptoService` mirrors
// `group_key_rotation_service_test.dart`'s own `_OrderRecordingGroupCryptoService`
// pattern: a thin subclass delegating every call to the real, libsignal-
// backed `super`, just counting invocations -- so "exactly one
// `encryptForGroup` call" is asserted against the REAL crypto path, not a
// mock standing in for it.
//
// `reserveSequenceFake` implements `ReserveGroupSequenceFn` with the same
// atomic "read MAX, insert Queued placeholder" shape, and is supplied
// explicitly by the tests that predate OQ-E07-T06-1's resolution. It is now a
// test *observation* seam, not a stand-in for missing production code: since
// that question was resolved the parameter is optional and defaults to
// `MessageSequenceReserver` -- the one shared transaction
// `SendMessageUseCase` also uses. The two tests at the bottom of this file
// construct the use case WITHOUT it, which is what proves the production path
// actually reserves.
//
// This file also covers `InboundPipeline`'s group-message RECEIVE branch
// (EARS-COMM-30/31/32, the wrong-epoch/no-fallback case, and the
// FR-ROUTE-003 forward-branch assertion) rather than a separate
// `inbound_pipeline_*_test.dart` file, since this task's own `files:` fence
// authorizes exactly two new test files (this one and
// `group_message_envelope_test.dart`) and no new or updated test file for
// `inbound_pipeline.dart` — logged as a Deviation in the task file's §9.
// The real two-stack harness (real transport wiring, real relay queue, real
// `MessagingStack`s) mirrors `group_crypto_service_test.dart`'s own
// EARS-GROUP-13 section, since that is exactly the seam this task's receive
// branch rides: group frames travel the identical mocked-transport ->
// `RelayEngine` -> `InboundPipeline` path E07-T04's key distribution already
// proved works, just on a new `controlKind` (6 — originally 5, renumbered
// after E07-T09's `kControlKindCallSignaling` claimed 5 first) instead of 4.
import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/group_crypto_service.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/domain/group_message_envelope.dart';
import 'package:nexora/features/groups/domain/send_group_message_use_case.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/domain/relationship.dart'
    show RelationshipState;

class _CountingGroupCryptoService extends GroupCryptoService {
  _CountingGroupCryptoService({required super.stack});

  int encryptCalls = 0;

  @override
  Future<Uint8List> encryptForGroup({
    required String groupId,
    required int epoch,
    required Uint8List plaintext,
  }) {
    encryptCalls++;
    return super.encryptForGroup(
      groupId: groupId,
      epoch: epoch,
      plaintext: plaintext,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'send-group-message-${suffixCounter++}';

  Future<MessagingStack> newStack(String selfDeviceId, [String? suffixOverride]) async {
    final suffix = suffixOverride ?? nextSuffix();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftSignalProtocolStore(db);
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: selfDeviceId,
      store: store,
      cryptoService: CryptoService.withStore(store),
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
    return stack;
  }

  /// The BLOCKED seam's test-only fake -- see this file's header.
  Future<int> Function(String groupId, String messageId, int createdAtMs)
      reserveSequenceFake(AppDatabase db, String selfDeviceId) {
    return (groupId, messageId, createdAtMs) {
      return db.transaction(() async {
        final maxRow = await (db.selectOnly(db.messages)
              ..addColumns([db.messages.sequenceNumber.max()])
              ..where(
                db.messages.conversationId.equals(groupId) &
                    db.messages.senderDeviceId.equals(selfDeviceId),
              ))
            .getSingleOrNull();
        final currentMax = maxRow?.read(db.messages.sequenceNumber.max());
        final next = (currentMax ?? -1) + 1;
        await db.into(db.messages).insert(
              MessagesCompanion.insert(
                id: messageId,
                conversationId: groupId,
                senderDeviceId: selfDeviceId,
                sequenceNumber: next,
                ciphertext: Uint8List(0),
                createdAt: createdAtMs,
                deliveryState: DeliveryState.queued.name,
              ),
            );
        return next;
      });
    };
  }

  test('test_EARS_COMM_29_one_ciphertext_and_n_frames', () async {
    final stack = await newStack('device-a');
    addTearDown(stack.dispose);

    final groups = GroupRepository(stack.db);
    final groupId = await groups.createGroup(
      name: 'Squad',
      ownerDeviceId: 'device-a',
      memberDeviceIds: ['device-b', 'device-c', 'device-d'],
    );

    final crypto = _CountingGroupCryptoService(stack: stack);
    await crypto.ensureOwnChain(groupId: groupId, epoch: 0);

    final enqueued = <(String destination, Uint8List payload)>[];
    Future<String> fakeEnqueue(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async {
      enqueued.add((destination, payload));
      return 'relay-${enqueued.length}';
    }

    final useCase = SendGroupMessageUseCase(
      db: stack.db,
      selfDeviceId: 'device-a',
      groups: groups,
      crypto: crypto,
      enqueue: fakeEnqueue,
      reserveSequence: reserveSequenceFake(stack.db, 'device-a'),
    );

    final result = await useCase.send(
      groupId: groupId,
      body: Uint8List.fromList('hi squad'.codeUnits),
    );

    expect(result, isNull);
    expect(crypto.encryptCalls, 1);
    expect(enqueued, hasLength(3));

    final destinations = enqueued.map((e) => e.$1).toSet();
    expect(destinations, {'device-b', 'device-c', 'device-d'});

    // Byte-identical inner ciphertext across every recipient's frame --
    // only `destination` differs (task file §6: one payload, N frames).
    final innerCiphertexts = enqueued.map((e) {
      final frame = RelayPacketFrame.deserialize(e.$2);
      expect(frame.payloadType, PayloadType.control);
      final controlKind = frame.payload[0];
      expect(controlKind, kControlKindGroupMessage);
      final header =
          GroupMessageRoutingHeader.deserialize(frame.payload.sublist(1));
      expect(header.groupId, groupId);
      expect(header.epoch, 0);
      return header.ciphertext;
    }).toList();
    for (final c in innerCiphertexts.skip(1)) {
      expect(c, innerCiphertexts.first);
    }

    final rows = await stack.db.select(stack.db.messages).get();
    expect(rows, hasLength(1));
    expect(rows.single.conversationId, groupId);
    expect(rows.single.senderDeviceId, 'device-a');
    expect(rows.single.deliveryState, DeliveryState.sent.name);
  });

  test('test_EARS_COMM_29_non_member_cannot_send', () async {
    final stack = await newStack('device-a');
    addTearDown(stack.dispose);

    final groups = GroupRepository(stack.db);
    // A group device-a is NOT a member of.
    final groupId = await groups.createGroup(
      name: 'Not mine',
      ownerDeviceId: 'device-x',
      memberDeviceIds: ['device-y'],
    );

    final crypto = _CountingGroupCryptoService(stack: stack);
    final useCase = SendGroupMessageUseCase(
      db: stack.db,
      selfDeviceId: 'device-a',
      groups: groups,
      crypto: crypto,
      enqueue: (destination, payload, priority, ttl) async => 'unused',
      reserveSequence: reserveSequenceFake(stack.db, 'device-a'),
    );

    final result = await useCase.send(
      groupId: groupId,
      body: Uint8List.fromList('sneaky'.codeUnits),
    );

    expect(result, const AppFailure('group.not_a_member'));
    expect(crypto.encryptCalls, 0);

    final rows = await stack.db.select(stack.db.messages).get();
    expect(rows, isEmpty);
  });

  test('test_send_to_unknown_group_fails_honestly', () async {
    final stack = await newStack('device-a');
    addTearDown(stack.dispose);

    final groups = GroupRepository(stack.db);
    final crypto = _CountingGroupCryptoService(stack: stack);
    final useCase = SendGroupMessageUseCase(
      db: stack.db,
      selfDeviceId: 'device-a',
      groups: groups,
      crypto: crypto,
      enqueue: (destination, payload, priority, ttl) async => 'unused',
      reserveSequence: reserveSequenceFake(stack.db, 'device-a'),
    );

    final result = await useCase.send(
      groupId: 'g:does-not-exist',
      body: Uint8List.fromList('x'.codeUnits),
    );

    expect(result, const AppFailure('group.not_a_member'));
  });

  test(
    'test_send_without_a_chain_fails_with_group_no_chain_and_row_is_failed',
    () async {
      final stack = await newStack('device-a');
      addTearDown(stack.dispose);

      final groups = GroupRepository(stack.db);
      final groupId = await groups.createGroup(
        name: 'No chain yet',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-b'],
      );

      // Deliberately never call ensureOwnChain -- this device has no chain
      // for its own epoch yet.
      final crypto = _CountingGroupCryptoService(stack: stack);
      final useCase = SendGroupMessageUseCase(
        db: stack.db,
        selfDeviceId: 'device-a',
        groups: groups,
        crypto: crypto,
        enqueue: (destination, payload, priority, ttl) async => 'unused',
        reserveSequence: reserveSequenceFake(stack.db, 'device-a'),
      );

      final result = await useCase.send(
        groupId: groupId,
        body: Uint8List.fromList('x'.codeUnits),
      );

      expect(result, isA<AppFailure>());
      expect(result!.code, 'group.no_chain');

      final rows = await stack.db.select(stack.db.messages).get();
      expect(rows, hasLength(1));
      expect(rows.single.deliveryState, DeliveryState.failed.name);
    },
  );

  // --- InboundPipeline's group-message receive branch (see file header) --

  void mockSendAlwaysSucceeds(String suffix) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
      (ByteData? message) async {
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
  }

  /// E04-B05: `RelayEngine`'s `send` is now `ConnectionEnsuringSender.
  /// ensureConnectedAndSend`, which calls `TransportApi.connect` before
  /// ever calling `TransportApi.send` -- every test below that mocks
  /// `send` for a real destination now also needs a `connect` mock, or
  /// the connect step (never previously exercised here) fails and the
  /// send is never attempted at all. Mirrors the native connect's own
  /// two-part contract (`_api.connect` returns "accepted", the real
  /// settle arrives later via `onConnectionStateChanged`) by firing the
  /// connected event asynchronously rather than synchronously replying
  /// "connected" inline -- matching `TransportService.connect`'s own
  /// documented two-channel design.
  void mockConnectAlwaysSucceeds(String suffix) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.connect.$suffix',
      (ByteData? message) async {
        final args = TransportApi.pigeonChannelCodec.decodeMessage(message)!
            as List<Object?>;
        final deviceId = args[0]! as String;
        scheduleMicrotask(() {
          messenger.handlePlatformMessage(
            'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
            TransportEventsApi.pigeonChannelCodec
                .encodeMessage(<Object?>[deviceId, ConnectionState.connected])!,
            (ByteData? _) {},
          );
        });
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
  }

  void wireSend(String fromSuffix, String fromDeviceId, String toSuffix) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.send.$fromSuffix',
      (ByteData? message) async {
        final args = TransportApi.pigeonChannelCodec.decodeMessage(message)!
            as List<Object?>;
        final bytes = args[1]! as Uint8List;
        final eventMessage = TransportEventsApi.pigeonChannelCodec
            .encodeMessage(<Object?>[fromDeviceId, bytes])!;
        messenger.handlePlatformMessage(
          'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$toSuffix',
          eventMessage,
          (ByteData? _) {},
        );
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
  }

  void pushDiscovered(String suffix, String deviceId) {
    final device = TransportDevice(
      id: deviceId,
      displayName: deviceId,
      type: TransportType.bluetooth,
    );
    final message = TransportEventsApi.pigeonChannelCodec
        .encodeMessage(<Object?>[device])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
      message,
      (ByteData? _) {},
    );
  }

  void pushConnectionState(
    String suffix,
    String deviceId,
    ConnectionState state,
  ) {
    final message = TransportEventsApi.pigeonChannelCodec
        .encodeMessage(<Object?>[deviceId, state])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
      message,
      (ByteData? _) {},
    );
  }

  void pushIncomingData(String suffix, String deviceId, Uint8List bytes) {
    final message = TransportEventsApi.pigeonChannelCodec
        .encodeMessage(<Object?>[deviceId, bytes])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$suffix',
      message,
      (ByteData? _) {},
    );
  }

  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> connectPeer(String suffix, String deviceId) async {
    pushDiscovered(suffix, deviceId);
    await settle();
    pushConnectionState(suffix, deviceId, ConnectionState.connected);
    await settle();
  }

  Future<void> establishMutualSessions(
    MessagingStack a,
    MessagingStack b,
  ) async {
    await a.cryptoService.establishSession(
      SignalProtocolAddress(b.selfDeviceId, 1),
      await b.identityService.getLocalPreKeyBundle(),
    );
    final bootstrap = await a.cryptoService.encrypt(
      SignalProtocolAddress(b.selfDeviceId, 1),
      Uint8List.fromList([0]),
    );
    await b.cryptoService.decrypt(
      SignalProtocolAddress(a.selfDeviceId, 1),
      bootstrap,
    );
  }

  /// Seeds a `groups`/`group_members` row pair directly on [db] with the
  /// EXACT SAME [groupId] `GroupRepository.createGroup` minted on the
  /// sender's own database — two independent devices' local views of the
  /// same real-world group, exactly as this app's no-server design
  /// (ADR-0005) requires each device to keep its own copy.
  Future<void> seedGroupView(
    AppDatabase db, {
    required String groupId,
    required int membershipEpoch,
    required String ownerDeviceId,
    required List<({String deviceId, int joinedAtEpoch, int? removedAtEpoch})>
        members,
  }) async {
    await db.into(db.groups).insert(
          GroupsCompanion.insert(
            id: groupId,
            name: 'G',
            createdAt: 0,
            createdByDeviceId: ownerDeviceId,
            membershipEpoch: Value(membershipEpoch),
          ),
        );
    for (final m in members) {
      await db.into(db.groupMembers).insert(
            GroupMembersCompanion.insert(
              groupId: groupId,
              deviceId: m.deviceId,
              role: (m.deviceId == ownerDeviceId
                      ? GroupRole.owner
                      : GroupRole.member)
                  .name,
              joinedAtEpoch: m.joinedAtEpoch,
              removedAtEpoch: Value(m.removedAtEpoch),
            ),
          );
    }
  }

  /// Sends one real, encrypted group message from [a] to [b] over the wire
  /// (mocked transport, real relay queue), first distributing [a]'s chain
  /// for real so [b] genuinely holds it, and lets everything settle.
  Future<void> sendAndDeliver({
    required MessagingStack a,
    required MessagingStack b,
    required String aSuffix,
    required String bSuffix,
    required String groupId,
    required Uint8List body,
  }) async {
    final groups = GroupRepository(a.db);

    final group = await groups.groupRow(groupId);
    final epoch = group!.membershipEpoch;
    await a.groupCryptoService.ensureOwnChain(groupId: groupId, epoch: epoch);

    wireSend(aSuffix, a.selfDeviceId, bSuffix);
    b.inbound.start();
    await connectPeer(bSuffix, a.selfDeviceId);
    a.routingEngine.recordLinkMeasurement(
      b.selfDeviceId,
      latencyMs: 10,
      lossRate: 0.0,
      batteryDrain: 0.1,
    );

    // A real app rotates/mints this device's own chain AND distributes it
    // to current members in response to membership changes (E07-T05, out
    // of this task's scope) -- done directly here so B genuinely holds
    // device-a's chain before the message is sent, exactly the real-world
    // precondition (task file §6: a member who never received the
    // distribution fails every inbound message with `group.no_chain`,
    // which `test_wrong_epoch_fails_explicitly_and_never_falls_back`
    // deliberately exercises on its own, without this helper).
    await a.groupCryptoService.distributeTo(
      groupId: groupId,
      epoch: epoch,
      recipientDeviceIds: [b.selfDeviceId],
    );
    await a.relayEngine.processQueue();
    await settle();
    await settle();

    final useCase = SendGroupMessageUseCase(
      db: a.db,
      selfDeviceId: a.selfDeviceId,
      groups: groups,
      crypto: a.groupCryptoService,
      enqueue: a.relayEngine.enqueue,
      reserveSequence: reserveSequenceFake(a.db, a.selfDeviceId),
    );

    final result = await useCase.send(groupId: groupId, body: body);
    expect(result, isNull);

    await a.relayEngine.processQueue();
    await settle();
    await settle();
  }

  test('test_EARS_COMM_30_round_trip_two_devices_one_group', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    mockSendAlwaysSucceeds(aSuffix);
    mockConnectAlwaysSucceeds(aSuffix);
    mockSendAlwaysSucceeds(bSuffix);
    mockConnectAlwaysSucceeds(bSuffix);
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await establishMutualSessions(a, b);

    final groupId = await GroupRepository(a.db).createGroup(
      name: 'G',
      ownerDeviceId: 'device-a',
      memberDeviceIds: ['device-b'],
    );
    await seedGroupView(
      b.db,
      groupId: groupId,
      membershipEpoch: 0,
      ownerDeviceId: 'device-a',
      members: [
        (deviceId: 'device-a', joinedAtEpoch: 0, removedAtEpoch: null),
        (deviceId: 'device-b', joinedAtEpoch: 0, removedAtEpoch: null),
      ],
    );

    final deliveredFuture = b.inbound.delivered.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('never delivered'),
    );

    await sendAndDeliver(
      a: a,
      b: b,
      aSuffix: aSuffix,
      bSuffix: bSuffix,
      groupId: groupId,
      body: Uint8List.fromList('hi group'.codeUnits),
    );

    final delivered = await deliveredFuture;
    expect(delivered.conversationId, groupId);
    expect(delivered.senderDeviceId, 'device-a');
    expect(delivered.sequenceNumber, 0);

    final rows = await b.db.select(b.db.messages).get();
    expect(rows, hasLength(1));
    expect(b.inbound.counters.delivered, 1);
    expect(b.inbound.counters.groupNotAMember, 0);
    expect(b.inbound.counters.groupNoChain, 0);
    expect(b.inbound.counters.groupEpochUnknown, 0);
  });

  test(
    'test_E04_B15_group_message_frame_destination_uses_learned_remoteSelfDeviceId',
    () async {
      // Same defect class E04-B13 fixed for 1:1 chat, applied to this
      // use case's own `RelayPacketFrame` construction site (`send`'s
      // per-recipient loop): before this fix, the frame's `destination`
      // was the raw Bluetooth MAC of the member, which can never equal
      // that member's real `selfDeviceId` -- `isForUs` always false on
      // the receiving device, so the group message is mistaken for a
      // relay packet and never reaches `InboundPipeline`'s group-message
      // handler at all.
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      mockSendAlwaysSucceeds(aSuffix);
      mockConnectAlwaysSucceeds(aSuffix);
      mockSendAlwaysSucceeds(bSuffix);
      mockConnectAlwaysSucceeds(bSuffix);
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b-real-id', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      const bMac = 'AA:BB:CC:DD:EE:50';

      // Mirrors `establishMutualSessions`'s own bootstrap, except A's
      // local session with B is keyed by `bMac` (the raw MAC
      // `SendGroupMessageUseCase`/`GroupCryptoService` actually address B
      // by), not by `b.selfDeviceId`.
      await a.cryptoService.establishSession(
        const SignalProtocolAddress(bMac, 1),
        await b.identityService.getLocalPreKeyBundle(),
      );
      final bootstrap = await a.cryptoService.encrypt(
        const SignalProtocolAddress(bMac, 1),
        Uint8List.fromList([0]),
      );
      await b.cryptoService.decrypt(
        const SignalProtocolAddress('device-a', 1),
        bootstrap,
      );

      // A already learned (E04-B12's identity-announce, simulated as its
      // already-landed effect) that the member on `bMac` is really
      // `device-b-real-id`.
      await a.db.into(a.db.relationships).insertOnConflictUpdate(
            RelationshipsCompanion.insert(
              deviceId: bMac,
              state: RelationshipState.unknown.name,
              updatedAt: DateTime.now(),
              remoteSelfDeviceId: const Value('device-b-real-id'),
            ),
          );

      final groupId = await GroupRepository(a.db).createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: [bMac],
      );
      await seedGroupView(
        b.db,
        groupId: groupId,
        membershipEpoch: 0,
        ownerDeviceId: 'device-a',
        members: [
          (deviceId: 'device-a', joinedAtEpoch: 0, removedAtEpoch: null),
          (deviceId: bMac, joinedAtEpoch: 0, removedAtEpoch: null),
        ],
      );

      final deliveredFuture = b.inbound.delivered.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('never delivered'),
      );

      final groups = GroupRepository(a.db);
      final group = await groups.groupRow(groupId);
      final epoch = group!.membershipEpoch;
      await a.groupCryptoService.ensureOwnChain(groupId: groupId, epoch: epoch);

      wireSend(aSuffix, 'device-a', bSuffix);
      b.inbound.start();
      await connectPeer(bSuffix, 'device-a');
      a.routingEngine.recordLinkMeasurement(
        bMac,
        latencyMs: 10,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );

      await a.groupCryptoService.distributeTo(
        groupId: groupId,
        epoch: epoch,
        recipientDeviceIds: [bMac],
      );
      await a.relayEngine.processQueue();
      await settle();
      await settle();

      final useCase = SendGroupMessageUseCase(
        db: a.db,
        selfDeviceId: a.selfDeviceId,
        groups: groups,
        crypto: a.groupCryptoService,
        enqueue: a.relayEngine.enqueue,
        reserveSequence: reserveSequenceFake(a.db, a.selfDeviceId),
      );

      final result = await useCase.send(
        groupId: groupId,
        body: Uint8List.fromList('hi group'.codeUnits),
      );
      expect(result, isNull);

      await a.relayEngine.processQueue();
      await settle();
      await settle();

      final delivered = await deliveredFuture;
      expect(delivered.conversationId, groupId);
      expect(delivered.senderDeviceId, 'device-a');
      expect(b.inbound.counters.delivered, 1);
    },
  );

  test(
    'test_EARS_COMM_30_message_is_stored_under_the_group_conversation_id',
    () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      mockSendAlwaysSucceeds(aSuffix);
      mockConnectAlwaysSucceeds(aSuffix);
      mockSendAlwaysSucceeds(bSuffix);
      mockConnectAlwaysSucceeds(bSuffix);
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await establishMutualSessions(a, b);
      final groupId = await GroupRepository(a.db).createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-b'],
      );
      await seedGroupView(
        b.db,
        groupId: groupId,
        membershipEpoch: 0,
        ownerDeviceId: 'device-a',
        members: [
          (deviceId: 'device-a', joinedAtEpoch: 0, removedAtEpoch: null),
          (deviceId: 'device-b', joinedAtEpoch: 0, removedAtEpoch: null),
        ],
      );

      final deliveredFuture = b.inbound.delivered.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('never delivered'),
      );
      await sendAndDeliver(
        a: a,
        b: b,
        aSuffix: aSuffix,
        bSuffix: bSuffix,
        groupId: groupId,
        body: Uint8List.fromList('via conversation repository'.codeUnits),
      );
      await deliveredFuture;

      // Read back through the EXISTING, unmodified query shape
      // `ConversationRepository.messagesPage` uses (keyset pagination by
      // `conversationId`) -- proving a group message needs no repository
      // change to be visible as an ordinary conversation's messages.
      final page = await (b.db.select(b.db.messages)
            ..where((t) => t.conversationId.equals(groupId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      expect(page, hasLength(1));
      expect(page.single.conversationId, groupId);
    },
  );

  test(
    'test_EARS_COMM_31_message_from_a_removed_member_is_discarded',
    () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      mockSendAlwaysSucceeds(aSuffix);
      mockConnectAlwaysSucceeds(aSuffix);
      mockSendAlwaysSucceeds(bSuffix);
      mockConnectAlwaysSucceeds(bSuffix);
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await establishMutualSessions(a, b);
      final groupId = await GroupRepository(a.db).createGroup(
        name: 'G',
        ownerDeviceId: 'device-b',
        memberDeviceIds: ['device-a'],
      );
      // B's OWN local view says device-a was removed at epoch 1 -- even
      // though device-a still genuinely holds and uses its epoch-0 chain,
      // B must refuse to store the message (task file §2/§5: "regardless
      // of what the envelope claims").
      await seedGroupView(
        b.db,
        groupId: groupId,
        membershipEpoch: 1,
        ownerDeviceId: 'device-b',
        members: [
          (deviceId: 'device-b', joinedAtEpoch: 0, removedAtEpoch: null),
          (deviceId: 'device-a', joinedAtEpoch: 0, removedAtEpoch: 1),
        ],
      );

      await sendAndDeliver(
        a: a,
        b: b,
        aSuffix: aSuffix,
        bSuffix: bSuffix,
        groupId: groupId,
        body: Uint8List.fromList('i was removed'.codeUnits),
      );

      final rows = await b.db.select(b.db.messages).get();
      expect(rows, isEmpty);
      expect(b.inbound.counters.groupNotAMember, 1);
      expect(b.inbound.counters.delivered, 0);
    },
  );

  test('test_EARS_COMM_32_duplicate_delivery_stores_once', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    mockSendAlwaysSucceeds(aSuffix);
    mockConnectAlwaysSucceeds(aSuffix);
    mockSendAlwaysSucceeds(bSuffix);
    mockConnectAlwaysSucceeds(bSuffix);
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await establishMutualSessions(a, b);
    final groupId = await GroupRepository(a.db).createGroup(
      name: 'G',
      ownerDeviceId: 'device-a',
      memberDeviceIds: ['device-b'],
    );
    await seedGroupView(
      b.db,
      groupId: groupId,
      membershipEpoch: 0,
      ownerDeviceId: 'device-a',
      members: [
        (deviceId: 'device-a', joinedAtEpoch: 0, removedAtEpoch: null),
        (deviceId: 'device-b', joinedAtEpoch: 0, removedAtEpoch: null),
      ],
    );

    final delivered = <Object>[];
    final sub = b.inbound.delivered.listen(delivered.add);
    addTearDown(sub.cancel);

    await sendAndDeliver(
      a: a,
      b: b,
      aSuffix: aSuffix,
      bSuffix: bSuffix,
      groupId: groupId,
      body: Uint8List.fromList('once please'.codeUnits),
    );
    // Re-deliver the SAME already-relayed packet a second time -- a real
    // mesh can forward the same frame down two routes (task file §6).
    // `sendAndDeliver` also performs a key-distribution frame first (its
    // own relay row), so the actual group-message frame is the LAST row.
    final relayRows = await a.db.select(a.db.relayPackets).get();
    expect(relayRows, hasLength(2));
    pushIncomingData(bSuffix, 'device-a', relayRows.last.payload!);
    await settle();
    await settle();

    final rows = await b.db.select(b.db.messages).get();
    expect(rows, hasLength(1));
    expect(delivered, hasLength(1));
    expect(b.inbound.counters.duplicate, 1);
    expect(b.inbound.counters.delivered, 1);
  });

  test(
    'test_EARS_COMM_32_messageId_dedupe_branch_is_reached_directly',
    () async {
      // The test above (`test_EARS_COMM_32_duplicate_delivery_stores_once`)
      // re-pushes byte-identical wire bytes, so libsignal's `GroupCipher`
      // throws `DuplicateMessageException` at `inbound_pipeline.dart:530`
      // before `handleGroupMessage` is ever entered a second time -- it
      // proves E07-T04's spent-key discard, not this task's own
      // `messageId` dedupe branch (`inbound_pipeline.dart:576-582`). That
      // branch is the SOLE guard against a frame that decrypts
      // successfully a second time (an epoch re-distribution or same-epoch
      // chain reset, E07-T05's territory) -- reached here directly, since
      // `handleGroupMessage` is public per the task file's §5 contract,
      // bypassing the need to construct two genuinely-different
      // ciphertexts that both decrypt successfully.
      final stack = await newStack('device-b');
      addTearDown(stack.dispose);

      final groups = GroupRepository(stack.db);
      final groupId = await groups.createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-b'],
      );

      final delivered = <Object>[];
      final sub = stack.inbound.delivered.listen(delivered.add);
      addTearDown(sub.cancel);

      final envelope = GroupMessageEnvelope(
        groupId: groupId,
        epoch: 0,
        senderDeviceId: 'device-a',
        messageId: 'direct-dedupe-message',
        sequenceNumber: 0,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        body: Uint8List.fromList('direct dedupe'.codeUnits),
      );
      final senderKeyMessageBytes = Uint8List.fromList([7, 7, 7]);

      // Same envelope, decrypted "successfully" twice -- exactly what an
      // epoch re-distribution or chain reset can produce, and exactly what
      // `DuplicateMessageException` does NOT guard against.
      await stack.inbound.handleGroupMessage(
        'device-a',
        envelope,
        senderKeyMessageBytes,
      );
      await stack.inbound.handleGroupMessage(
        'device-a',
        envelope,
        senderKeyMessageBytes,
      );

      final rows = await stack.db.select(stack.db.messages).get();
      expect(rows, hasLength(1));
      expect(delivered, hasLength(1));
      expect(stack.inbound.counters.duplicate, 1);
      expect(stack.inbound.counters.delivered, 1);
    },
  );

  test(
    'test_wrong_epoch_fails_explicitly_and_never_falls_back',
    () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      mockSendAlwaysSucceeds(aSuffix);
      mockConnectAlwaysSucceeds(aSuffix);
      mockSendAlwaysSucceeds(bSuffix);
      mockConnectAlwaysSucceeds(bSuffix);
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await establishMutualSessions(a, b);
      final groupId = await GroupRepository(a.db).createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-b'],
      );
      await seedGroupView(
        b.db,
        groupId: groupId,
        membershipEpoch: 0,
        ownerDeviceId: 'device-a',
        members: [
          (deviceId: 'device-a', joinedAtEpoch: 0, removedAtEpoch: null),
          (deviceId: 'device-b', joinedAtEpoch: 0, removedAtEpoch: null),
        ],
      );

      // A mints and uses an epoch-0 chain (this is what B will hold).
      await a.groupCryptoService.ensureOwnChain(groupId: groupId, epoch: 0);
      final epoch0Message = await a.groupCryptoService.encryptForGroup(
        groupId: groupId,
        epoch: 0,
        plaintext: Uint8List.fromList([1, 2, 3]),
      );
      // Deliver epoch 0 for real so B genuinely holds device-a's epoch-0
      // chain (not merely a fabricated row) -- via a real distribution.
      wireSend(aSuffix, 'device-a', bSuffix);
      b.inbound.start();
      await connectPeer(bSuffix, 'device-a');
      a.routingEngine.recordLinkMeasurement(
        'device-b',
        latencyMs: 10,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );
      await a.groupCryptoService.distributeTo(
        groupId: groupId,
        epoch: 0,
        recipientDeviceIds: ['device-b'],
      );
      await a.relayEngine.processQueue();
      await settle();
      await settle();
      final bChains = await b.db.select(b.db.groupSenderKeys).get();
      expect(bChains, hasLength(1));

      // Now bump the group to epoch 1 on BOTH sides' local views (B
      // "recognizes" epoch 1 -- e.g. it separately received a rename
      // control frame -- but never got epoch 1's key distribution).
      await a.db.update(a.db.groups).write(
            const GroupsCompanion(membershipEpoch: Value(1)),
          );
      await b.db.update(b.db.groups).write(
            const GroupsCompanion(membershipEpoch: Value(1)),
          );

      final epoch1Message = Uint8List.fromList(epoch0Message);
      // Craft a wire frame CLAIMING epoch 1 but carrying epoch 0's real
      // ciphertext bytes -- B recognizes epoch 1 (membershipEpoch == 1) so
      // this is NOT `groupEpochUnknown`; it must fail explicitly as
      // `groupNoChain` (no epoch-1 chain held for device-a), never fall
      // back to decrypting it with the epoch-0 chain it DOES hold.
      final header = GroupMessageRoutingHeader(
        groupId: groupId,
        epoch: 1,
        ciphertext: epoch1Message,
      ).serialize();
      final controlPayload = Uint8List(1 + header.length);
      controlPayload[0] = kControlKindGroupMessage;
      controlPayload.setRange(1, controlPayload.length, header);
      final now = DateTime.now().millisecondsSinceEpoch;
      final frame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'wrong-epoch-1',
        destination: 'device-b',
        source: 'device-a',
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 60000,
        payload: controlPayload,
      );

      pushIncomingData(bSuffix, 'device-a', frame.serialize());
      await settle();
      await settle();

      final rows = await b.db.select(b.db.messages).get();
      expect(rows, isEmpty);
      expect(b.inbound.counters.groupNoChain, 1);
      expect(b.inbound.counters.groupEpochUnknown, 0);
      expect(b.inbound.counters.delivered, 0);
    },
  );

  test(
    'test_forward_branch_never_decrypts_a_group_payload',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('device-b', suffix);
      addTearDown(receiver.dispose);

      receiver.inbound.start();
      await connectPeer(suffix, 'device-a');

      // Garbage group-shaped control payload addressed to SOMEONE ELSE
      // (`device-c`, not `device-b`/self) -- if the forward branch ever
      // attempted to route this to `_handleGroupMessageWireFrame` or
      // otherwise inspect/decrypt it, this would throw synchronously
      // (mirrors `inbound_pipeline_test.dart`'s own
      // `test_EARS_COMM_9_foreign_packet_is_forwarded_unread` fixture).
      final garbageHeader = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
      final controlPayload = Uint8List(1 + garbageHeader.length);
      controlPayload[0] = kControlKindGroupMessage;
      controlPayload.setRange(1, controlPayload.length, garbageHeader);
      final now = DateTime.now().millisecondsSinceEpoch;
      final frame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-foreign-group-1',
        destination: 'device-c',
        source: 'device-a',
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 60000,
        payload: controlPayload,
      );
      final wireBytes = frame.serialize();

      pushIncomingData(suffix, 'device-a', wireBytes);
      await settle();
      await settle();

      final relayRows =
          await receiver.db.select(receiver.db.relayPackets).get();
      expect(relayRows, hasLength(1));
      expect(relayRows.single.destinationId, 'device-c');
      expect(relayRows.single.payload, wireBytes);

      final messageRows =
          await receiver.db.select(receiver.db.messages).get();
      expect(messageRows, isEmpty);
      expect(receiver.inbound.counters.forwarded, 1);
      expect(receiver.inbound.counters.groupNotAMember, 0);
      expect(receiver.inbound.counters.groupNoChain, 0);
      expect(receiver.inbound.counters.groupEpochUnknown, 0);
      expect(receiver.inbound.counters.malformed, 0);
    },
  );

  // --- OQ-E07-T06-1's resolution: the seam is bound in production ---------
  //
  // Every test above supplies `reserveSequenceFake` explicitly. These two
  // construct `SendGroupMessageUseCase` WITHOUT it -- the production shape --
  // so what runs is `MessageSequenceReserver`, the same transaction
  // `SendMessageUseCase.call` uses. Without these, "group send works" would
  // only ever have been proven against a fake.

  test('test_group_send_reserves_a_real_sequence_number_without_a_fake_seam',
      () async {
    final stack = await newStack('device-a');
    addTearDown(stack.dispose);

    final groups = GroupRepository(stack.db);
    final groupId = await groups.createGroup(
      name: 'Squad',
      ownerDeviceId: 'device-a',
      memberDeviceIds: ['device-b'],
    );
    final crypto = GroupCryptoService(stack: stack);
    await crypto.ensureOwnChain(groupId: groupId, epoch: 0);

    Future<String> fakeEnqueue(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async =>
        'relay-id';

    // No `reserveSequence:` argument at all.
    final useCase = SendGroupMessageUseCase(
      db: stack.db,
      selfDeviceId: 'device-a',
      groups: groups,
      crypto: crypto,
      enqueue: fakeEnqueue,
    );

    expect(
      await useCase.send(
          groupId: groupId, body: Uint8List.fromList('one'.codeUnits)),
      isNull,
    );
    expect(
      await useCase.send(
          groupId: groupId, body: Uint8List.fromList('two'.codeUnits)),
      isNull,
    );

    final rows = await (stack.db.select(stack.db.messages)
          ..where((t) => t.conversationId.equals(groupId)))
        .get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.sequenceNumber).toList()..sort(), [0, 1]);
    for (final row in rows) {
      expect(row.senderDeviceId, 'device-a');
      expect(row.deliveryState, DeliveryState.sent.name);
      expect(row.ciphertext, isNotEmpty,
          reason: 'the placeholder must have been overwritten by phase 3');
    }
  });

  test(
      'test_concurrent_group_sends_never_collide_on_one_sequence_counter',
      () async {
    // L-backend-003, on the group path: the mirror of
    // `send_message_use_case_test.dart`'s
    // `test_sequence_numbers_distinct_under_concurrent_sends_same_conversation`,
    // now meaningful for groups because the reservation is a real
    // transaction rather than an unbound seam.
    final stack = await newStack('device-a');
    addTearDown(stack.dispose);

    final groups = GroupRepository(stack.db);
    final groupId = await groups.createGroup(
      name: 'Squad',
      ownerDeviceId: 'device-a',
      memberDeviceIds: ['device-b', 'device-c'],
    );
    final crypto = GroupCryptoService(stack: stack);
    await crypto.ensureOwnChain(groupId: groupId, epoch: 0);

    Future<String> fakeEnqueue(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async =>
        'relay-id';

    final useCase = SendGroupMessageUseCase(
      db: stack.db,
      selfDeviceId: 'device-a',
      groups: groups,
      crypto: crypto,
      enqueue: fakeEnqueue,
    );

    final results = await Future.wait([
      for (var i = 0; i < 5; i++)
        useCase.send(
          groupId: groupId,
          body: Uint8List.fromList('msg-$i'.codeUnits),
        ),
    ]);
    expect(results.every((r) => r == null), isTrue);

    final rows = await (stack.db.select(stack.db.messages)
          ..where((t) => t.conversationId.equals(groupId)))
        .get();
    expect(rows, hasLength(5));
    expect(
      rows.map((r) => r.sequenceNumber).toSet(),
      {0, 1, 2, 3, 4},
      reason: 'five concurrent group sends must get five distinct, dense '
          'sequence numbers -- one counter, one transaction',
    );
  });

  test(
    'test_E04_B27_a_message_finishing_after_stop_does_not_throw',
    () async {
      // E04-B27 (audit finding 2): `stop()` closes the delivered stream while
      // an in-flight handler can still be past its last await. Adding to a
      // closed controller used to throw `StateError`; the row is still
      // persisted, only the event is skipped.
      final stack = await newStack('device-b');
      addTearDown(stack.dispose);

      final groupId = await GroupRepository(stack.db).createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-b'],
      );
      await stack.inbound.stop();

      await expectLater(
        stack.inbound.handleGroupMessage(
          'device-a',
          GroupMessageEnvelope(
            groupId: groupId,
            epoch: 0,
            senderDeviceId: 'device-a',
            messageId: 'after-stop',
            sequenceNumber: 0,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
            body: Uint8List.fromList('late'.codeUnits),
          ),
          Uint8List.fromList([1, 2, 3]),
        ),
        completes,
      );
      expect(await stack.db.select(stack.db.messages).get(), hasLength(1));
    },
  );
}
