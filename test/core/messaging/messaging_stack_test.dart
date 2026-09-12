// Tests for MessagingStack (E06-T03, EARS-COMM-6/7).
//
// This is the first place `SendMessageUseCase`/`ReceiveMessageUseCase`/
// `SyncCursorService`/`RelayEngine`/`RoutingEngine` are ever constructed
// outside their own epics' test suites -- so, per the task file's own §6
// risk note, this suite exists to prove the composition itself, not to
// re-prove behaviour those epics' own suites already cover.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Value;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/messaging/ciphertext_codec.dart';
import 'package:nexora/core/messaging/location_share.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/location/data/location_fix_repository.dart';
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/location/domain/location_share_service.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/receive_message_use_case.dart';
import 'package:nexora/features/messaging/domain/send_message_use_case.dart';
import 'package:nexora/features/messaging/domain/sync_cursor_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);

/// A `DriftSignalProtocolStore` whose identity bootstrap always fails --
/// used to prove EARS-COMM-7 without needing a genuinely broken database.
class _ThrowingStore extends DriftSignalProtocolStore {
  _ThrowingStore(super.db);

  @override
  Future<void> saveLocalIdentityIfAbsent(
    IdentityKeyPair identityKeyPair,
    int registrationId,
  ) async {
    throw StateError('simulated identity bootstrap failure');
  }
}

/// A second, independent simulated device ("bob") -- its own database,
/// store and `CryptoService.withStore` instance, mirroring the `_Party`
/// pattern already established in `crypto_service_test.dart`/
/// `ciphertext_codec_test.dart`. Used as the remote peer the stack under
/// test (which plays "alice") establishes a session with.
class _RemoteParty {
  _RemoteParty._(this.db, this.store, this.crypto);

  final AppDatabase db;
  final DriftSignalProtocolStore store;
  final CryptoService crypto;

  static Future<_RemoteParty> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftSignalProtocolStore(db);
    final identity = IdentityService(db, store);
    await identity.ensureLocalIdentity();
    await identity.ensureSignedPreKey();
    await identity.replenishOneTimePreKeys();
    return _RemoteParty._(db, store, CryptoService.withStore(store));
  }

  Future<PreKeyBundle> bundle() => IdentityService(db, store).getLocalPreKeyBundle();

  Future<void> close() => db.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  TransportService newTransport() => TransportService(
        binaryMessenger: messenger,
        // A distinct suffix per stack so each test's TransportEventsApi
        // registration doesn't clobber another's (transport_service_test.dart's
        // own pattern; devices_controller_test.dart relies on the same
        // isolation).
        messageChannelSuffix: 'messaging-stack-${suffixCounter++}',
      );

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  // --- E07-T14: composition-only helpers for the group send path -------
  //
  // Mirrors `send_group_message_use_case_test.dart`'s own transport-wiring
  // and `sendAndDeliver` helper shapes (task file §6) rather than
  // rediscovering them -- that file's own run log records two false-alarm
  // `group.no_chain` failures from a harness that skipped
  // `ensureOwnChain`/`distributeTo`/`processQueue`.

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
  /// documented two-channel design (this file's header, `connectPeer`).
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

  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> connectPeer(String suffix, String deviceId) async {
    final device = TransportDevice(
      id: deviceId,
      displayName: deviceId,
      type: TransportType.bluetooth,
    );
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
      TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!,
      (ByteData? _) {},
    );
    await settle();
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
      TransportEventsApi.pigeonChannelCodec
          .encodeMessage(<Object?>[deviceId, ConnectionState.connected])!,
      (ByteData? _) {},
    );
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
  /// EXACT SAME [groupId] the sender's own `GroupRepository.createGroup`
  /// minted — two independent devices' local views of the same real-world
  /// group (ADR-0005: no server, each device keeps its own copy).
  Future<void> seedGroupView(
    AppDatabase db, {
    required String groupId,
    required int membershipEpoch,
    required String ownerDeviceId,
    required List<String> memberDeviceIds,
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
    for (final deviceId in memberDeviceIds) {
      await db.into(db.groupMembers).insert(
            GroupMembersCompanion.insert(
              groupId: groupId,
              deviceId: deviceId,
              role: (deviceId == ownerDeviceId
                      ? GroupRole.owner
                      : GroupRole.member)
                  .name,
              joinedAtEpoch: 0,
            ),
          );
    }
  }

  /// Two real `MessagingStack`s ("alice"/"bob"), each `MessagingStack
  /// .create`d exactly the way the app builds one, with a real group both
  /// devices are current members of and alice's sender-key chain already
  /// distributed to bob — the state a real two-device group is in right
  /// before someone sends the first message. Returns the group id and both
  /// stacks; callers send through `alice.sendGroupMessage` — the composed
  /// object — never a locally-constructed `SendGroupMessageUseCase`.
  Future<({MessagingStack alice, MessagingStack bob, String groupId})>
      twoStacksWithGroupReady() async {
    final aSuffix = 'group-send-a-${suffixCounter++}';
    final bSuffix = 'group-send-b-${suffixCounter++}';
    mockSendAlwaysSucceeds(aSuffix);
    mockConnectAlwaysSucceeds(aSuffix);
    mockSendAlwaysSucceeds(bSuffix);
    mockConnectAlwaysSucceeds(bSuffix);

    final aliceDb = AppDatabase.forTesting(NativeDatabase.memory());
    final aliceStore = DriftSignalProtocolStore(aliceDb);
    final alice = await MessagingStack.create(
      db: aliceDb,
      selfDeviceId: 'alice',
      store: aliceStore,
      cryptoService: CryptoService.withStore(aliceStore),
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: aSuffix,
      ),
    );
    expect(alice.status, const MessagingStackStatus.ready());

    final bobDb = AppDatabase.forTesting(NativeDatabase.memory());
    final bobStore = DriftSignalProtocolStore(bobDb);
    final bob = await MessagingStack.create(
      db: bobDb,
      selfDeviceId: 'bob',
      store: bobStore,
      cryptoService: CryptoService.withStore(bobStore),
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: bSuffix,
      ),
    );
    expect(bob.status, const MessagingStackStatus.ready());

    await establishMutualSessions(alice, bob);

    final groupId = await GroupRepository(alice.db).createGroup(
      name: 'G',
      ownerDeviceId: 'alice',
      memberDeviceIds: ['bob'],
    );
    await seedGroupView(
      bob.db,
      groupId: groupId,
      membershipEpoch: 0,
      ownerDeviceId: 'alice',
      memberDeviceIds: ['alice', 'bob'],
    );

    wireSend(aSuffix, alice.selfDeviceId, bSuffix);
    bob.inbound.start();
    await connectPeer(bSuffix, alice.selfDeviceId);
    alice.routingEngine.recordLinkMeasurement(
      bob.selfDeviceId,
      latencyMs: 10,
      lossRate: 0.0,
      batteryDrain: 0.1,
    );

    // Real key distribution first (task file §6) -- otherwise bob's own
    // `group.no_chain` rejection is the false alarm E07-T06's run log
    // already documented, not a defect in this task's wiring.
    await alice.groupCryptoService.ensureOwnChain(groupId: groupId, epoch: 0);
    await alice.groupCryptoService.distributeTo(
      groupId: groupId,
      epoch: 0,
      recipientDeviceIds: [bob.selfDeviceId],
    );
    await alice.relayEngine.processQueue();
    await settle();
    await settle();

    return (alice: alice, bob: bob, groupId: groupId);
  }

  // --- E04-B05 review round 2 (F5): prove the wiring, not just the class --
  //
  // Every other test in this file (and the other 8 test files this bug
  // touched) mocks BOTH `TransportApi.connect` and `TransportApi.send` to
  // always succeed -- which means reverting `RelayEngine`/`directSend`'s
  // wiring back to a raw `resolvedTransport.send` (the exact pre-fix bug)
  // leaves every one of those tests passing identically, since a mocked-
  // to-succeed connect and a mocked-to-succeed send are indistinguishable
  // from a codepath that skips connect entirely. That is precisely the
  // defect class this bug fixes (an unwired capability with nothing ever
  // proving it's wired in) -- confirmed by review round 2 reverting the
  // wiring and getting 1335/1335 green anyway. These two tests mock
  // `connect` to FAIL and `send` to succeed-and-count, so they can only
  // pass if `send` is never reached without `connect` succeeding first --
  // exactly the one behavior distinguishing the fixed code from the bug.
  void mockConnectAlwaysFails(String suffix) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.connect.$suffix',
      (ByteData? message) async =>
          TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[false]),
    );
  }

  test(
    'test_E04_B05_relay_engine_send_never_reaches_transport_send_when_connect_fails',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final suffix = 'e04-b05-wiring-relay-${suffixCounter++}';
      var sendCalls = 0;
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
        (ByteData? message) async {
          sendCalls++;
          return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
        },
      );
      mockConnectAlwaysFails(suffix);

      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: suffix,
        ),
      );
      addTearDown(stack.dispose);
      expect(stack.status, const MessagingStackStatus.ready());

      final bob = await _RemoteParty.create();
      addTearDown(bob.close);
      await stack.cryptoService.establishSession(
        const SignalProtocolAddress('device-b', 1),
        await bob.bundle(),
      );

      // A real, direct one-hop route -- `RelayEngine._attempt` will call
      // its injected `send` (this stack's `ConnectionEnsuringSender
      // .ensureConnectedAndSend`) for this packet.
      stack.routingEngine.recordLinkMeasurement(
        'device-b',
        latencyMs: 20,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );

      await stack.sendMessage.call('conv-1', 'device-b', _plaintext('hi'));
      await stack.relayEngine.processQueue();
      await settle();

      // The whole point: connect failed, so send must NEVER have been
      // reached, whatever `RelayEngine`'s own retry/queue bookkeeping does
      // with the failure. This is the assertion that fails on the pre-fix
      // `send: resolvedTransport.send` wiring (which has no connect step
      // to fail) and passes only on the fixed `ConnectionEnsuringSender`
      // wiring.
      expect(sendCalls, 0);
    },
  );

  test(
    'test_E04_B05_prekey_exchange_first_contact_never_reaches_transport_send_when_connect_fails',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final suffix = 'e04-b05-wiring-prekey-${suffixCounter++}';
      var sendCalls = 0;
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
        (ByteData? message) async {
          sendCalls++;
          return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
        },
      );
      mockConnectAlwaysFails(suffix);

      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: suffix,
        ),
      );
      addTearDown(stack.dispose);
      expect(stack.status, const MessagingStackStatus.ready());

      // First contact with 'device-b' -- no session exists yet, so
      // `ensureSession` must call `PrekeyExchange._sendControlFrame`, which
      // now goes through `_stack.directSend` (this stack's SAME
      // `ConnectionEnsuringSender.ensureConnectedAndSend`). It must throw
      // (this task's own root-cause fix: `_sendControlFrame` throws on a
      // failed `directSend` instead of silently ignoring it and waiting
      // out the full timeout) -- and, same assertion as above, `send`
      // must never have been reached.
      await expectLater(
        stack.prekeyExchange.ensureSession(
          'device-b',
          timeout: const Duration(seconds: 2),
        ),
        throwsA(isA<AppFailure>()),
      );

      expect(sendCalls, 0);
    },
  );

  test('test_EARS_COMM_6_stack_is_a_single_instance', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'device-a',
      transport: newTransport(),
    );
    expect(stack.status, const MessagingStackStatus.ready());

    // Mirrors bindings.dart's own permanent registrations (task file §3):
    // the stack itself, plus its members, so screens can resolve either.
    Get.put(stack, permanent: true);
    Get.put(stack.db, permanent: true);
    Get.put(stack.sendMessage, permanent: true);
    Get.put(stack.receiveMessage, permanent: true);
    Get.put(stack.syncCursors, permanent: true);
    Get.put(stack.relayEngine, permanent: true);
    Get.put(stack.routingEngine, permanent: true);

    expect(identical(Get.find<MessagingStack>(), Get.find<MessagingStack>()), isTrue);
    expect(identical(Get.find<AppDatabase>(), Get.find<AppDatabase>()), isTrue);
    expect(identical(Get.find<AppDatabase>(), stack.db), isTrue);
    expect(
      identical(Get.find<SendMessageUseCase>(), Get.find<SendMessageUseCase>()),
      isTrue,
    );
    expect(
      identical(Get.find<SendMessageUseCase>(), stack.sendMessage),
      isTrue,
    );
    expect(
      identical(Get.find<ReceiveMessageUseCase>(), Get.find<ReceiveMessageUseCase>()),
      isTrue,
    );
    expect(
      identical(Get.find<SyncCursorService>(), Get.find<SyncCursorService>()),
      isTrue,
    );
    expect(
      identical(Get.find<RelayEngine>(), Get.find<RelayEngine>()),
      isTrue,
    );
    expect(
      identical(Get.find<RoutingEngine>(), Get.find<RoutingEngine>()),
      isTrue,
    );

    await stack.dispose();
  });

  test(
    'test_EARS_ABUSE_4_wired_messaging_stack_denies_over_limit_peer',
    () async {
      // E13-T07 (FR-ABUSE-001): before this task, `MessagingStack.create`'s
      // own construction of `EvaluateConnectionRequestUseCase` never passed
      // a `RateLimiter`, so `PrekeyExchange`'s inbound trust gate could
      // never actually deny a flood of `bundleRequest` frames from the same
      // claimed peer, no matter how many arrived. This proves the real
      // composition root now wires a working one: a peer with no stored
      // relationship (defaults to `unknown`, never `blocked`) still gets
      // refused once it exceeds `EvaluateConnectionRequestUseCase`'s own
      // 10-per-minute ceiling (`_maxConnectionRequestsPerWindow`).
      const suffix = 'messaging-stack-abuse-4';
      // Admitted calls (up to the rate limit) still try to answer with a
      // real bundle response, which goes out over `transport.send` -- mock
      // it so those admitted sends succeed rather than throwing a
      // `PlatformException` for an unregistered test channel (this file's
      // own `mockSendAlwaysSucceeds` helper, used the same way by every
      // other test in this suite that actually sends).
      mockSendAlwaysSucceeds(suffix);
      mockConnectAlwaysSucceeds(suffix);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: suffix,
        ),
      );
      expect(stack.status, const MessagingStackStatus.ready());

      const peerDeviceId = 'flooding-peer';
      final now = DateTime.now();

      // Raw wire bytes for a `bundleRequest` control body -- mirrors
      // `PrekeyExchange`'s own private `_ControlBody.request(...).serialize()`
      // layout exactly (that file's header): [u8 subType=1][u32
      // requestIdLen][requestId bytes], no bundle. Calling
      // `handleControlFrame` directly (as `InboundPipeline` would, after
      // already stripping its own leading `controlKind` byte) needs exactly
      // this shape.
      Uint8List bundleRequestBody(String requestId) {
        final idBytes = Uint8List.fromList(requestId.codeUnits);
        final buffer = ByteData(1 + 4 + idBytes.length);
        buffer.setUint8(0, 1); // subType 1 == bundleRequest
        buffer.setUint32(1, idBytes.length);
        buffer.buffer.asUint8List().setRange(5, 5 + idBytes.length, idBytes);
        return buffer.buffer.asUint8List();
      }

      for (var i = 0; i < 15; i++) {
        final frame = RelayPacketFrame(
          payloadType: PayloadType.control,
          packetId: 'req-$i',
          destination: 'device-a',
          source: peerDeviceId,
          priority: 0,
          createdAtMs: now.millisecondsSinceEpoch,
          expiresAtMs: now.add(const Duration(seconds: 30)).millisecondsSinceEpoch,
          payload: bundleRequestBody('req-$i'),
        );
        await stack.prekeyExchange.handleControlFrame(frame);
      }

      // Exactly 10 calls admitted (rate limiter ceiling); every call past
      // that is refused -- silence, never `requestsServed`/`bundleUnavailable`
      // for those. Without real wiring, EVERY one of the 15 calls would have
      // been evaluated as `unknown` (never `blocked`), and none would ever
      // land in `requestsRefused`.
      expect(
        stack.prekeyExchange.counters.requestsRefused,
        greaterThanOrEqualTo(5),
        reason:
            'at least the 5 over-limit requests must have been refused by '
            'a real RateLimiter -- zero here would mean the gate is still '
            'unwired',
      );

      await stack.dispose();
    },
  );

  test('test_EARS_COMM_6_send_use_case_uses_the_stack_database', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'device-a',
      transport: newTransport(),
    );
    expect(stack.status, const MessagingStackStatus.ready());

    // No session established with 'device-b' -- this will fail at the
    // encrypt step (messaging.no_session, T07's job to fix), but Phase 1 of
    // SendMessageUseCase.call still reserves the sequence number and inserts
    // a row BEFORE that failure -- proving the row landed in *this* stack's
    // AppDatabase, not some other instance the adapter built for itself.
    await expectLater(
      () => stack.sendMessage.call(
        'conv-1',
        'device-b',
        _plaintext('hello'),
      ),
      throwsA(isA<AppFailure>()),
    );

    final rows = await db.select(db.messages).get();
    expect(rows, hasLength(1));
    expect(rows.single.conversationId, 'conv-1');
    expect(rows.single.senderDeviceId, 'device-a');
    expect(rows.single.deliveryState, DeliveryState.failed.name);

    await stack.dispose();
  });

  test(
    'test_EARS_COMM_6_encrypt_adapter_produces_a_parseable_frame',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: newTransport(),
      );
      expect(stack.status, const MessagingStackStatus.ready());

      final bob = await _RemoteParty.create();
      addTearDown(bob.close);

      // Test-only: establishing the session is the test's job, not the
      // stack's (task file §4 -- MessagingStack itself never calls
      // establishSession).
      const bobAddress = SignalProtocolAddress('device-b', 1);
      await stack.cryptoService.establishSession(bobAddress, await bob.bundle());

      final message = await stack.sendMessage.call(
        'conv-1',
        'device-b',
        _plaintext('hello bob'),
      );
      expect(message.deliveryState, DeliveryState.sent);

      // The contract test between T02 and this task: run the stack's
      // MessageEncryptFn (exercised via sendMessage.call above -- its output
      // is exactly what the encrypt adapter returned, persisted verbatim as
      // `message.ciphertext`) and feed it back through RelayPacketFrame
      // .deserialize + CiphertextCodec.decode. It must fail if the wire
      // frame was dropped from the adapter.
      final frame = RelayPacketFrame.deserialize(message.ciphertext);
      expect(frame.destination, 'device-b');
      expect(frame.source, 'device-a');
      // See messaging_stack.dart's header, judgment call 2: the frame's
      // packetId is the envelope's own id, not RelayEngine's (which does
      // not exist yet at the point this frame is built).
      expect(frame.packetId, message.id);

      final ciphertextMessage = CiphertextCodec.decode(
        frame.payloadType,
        frame.payload,
      );
      expect(ciphertextMessage, isA<CiphertextMessage>());
      // First message to a fresh peer -- carries the X3DH prekey bundle.
      expect(ciphertextMessage, isA<PreKeySignalMessage>());

      // Stronger proof than byte equality (matching E06-T02's own review
      // standard): bob can actually decrypt the round-tripped message.
      final plaintext = await bob.crypto.decrypt(
        const SignalProtocolAddress('device-a', 1),
        ciphertextMessage,
      );
      expect(utf8Decode(plaintext), contains('hello bob'));

      await stack.dispose();
    },
  );

  test(
    'test_E04_B13_encrypt_adapter_resolves_learned_remoteSelfDeviceId_for_frame_destination',
    () async {
      // The actual chat-message send path (`SendMessageUseCase` ->
      // `MessagingStack`'s own `encryptAdapter`) -- E04-B12's identity
      // announce populates `remoteSelfDeviceId`, but nothing consumed it
      // for THIS frame construction site before E04-B13. `recipientDeviceId`
      // ('bt-mac-bob') here deliberately differs from bob's real
      // `selfDeviceId` ('device-b-real'), mirroring E04-B12's own live
      // finding that a Bluetooth MAC and a real `selfDeviceId` are never the
      // same string on real hardware.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: newTransport(),
      );
      expect(stack.status, const MessagingStackStatus.ready());

      final bob = await _RemoteParty.create();
      addTearDown(bob.close);

      const bobMac = 'bt-mac-bob';
      const bobRealSelfDeviceId = 'device-b-real';
      // Crypto sessions stay keyed by the app-level conversationId (the
      // Bluetooth MAC) exactly as everywhere else in this codebase --
      // unchanged and untouched by this task (task file §4: does NOT touch
      // `CryptoService`/identity-key trust logic). Only the WIRE FRAME's
      // `destination` field (asserted below) is what this task resolves.
      const bobAddress = SignalProtocolAddress(bobMac, 1);
      await stack.cryptoService.establishSession(bobAddress, await bob.bundle());

      // Simulates E04-B12's identity-announce having already landed for
      // this link -- the column this task actually consumes.
      await db.into(db.relationships).insertOnConflictUpdate(
            RelationshipsCompanion.insert(
              deviceId: bobMac,
              state: RelationshipState.unknown.name,
              updatedAt: DateTime.now(),
              remoteSelfDeviceId: const Value(bobRealSelfDeviceId),
            ),
          );

      final message = await stack.sendMessage.call(
        'conv-1',
        bobMac,
        _plaintext('hello bob'),
      );
      expect(message.deliveryState, DeliveryState.sent);

      final frame = RelayPacketFrame.deserialize(message.ciphertext);
      // The whole point: NOT the raw Bluetooth MAC any more -- the peer's
      // real, learned `selfDeviceId`, which is what the RECEIVER's
      // `isForUs` check actually compares against.
      expect(frame.destination, bobRealSelfDeviceId);
      expect(frame.source, 'device-a');

      final ciphertextMessage = CiphertextCodec.decode(
        frame.payloadType,
        frame.payload,
      );
      final plaintext = await bob.crypto.decrypt(
        const SignalProtocolAddress('device-a', 1),
        ciphertextMessage,
      );
      expect(utf8Decode(plaintext), contains('hello bob'));

      await stack.dispose();
    },
  );

  test(
    'test_E04_B13_encrypt_adapter_falls_back_to_mac_when_not_yet_announced',
    () async {
      // The pre-announce race window (task file §3 point 3): no
      // `remoteSelfDeviceId` has been learned yet for this peer -- must
      // regress nothing versus pre-E04-B13 behavior (the raw MAC is used
      // exactly as before), not crash or throw.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: newTransport(),
      );

      final bob = await _RemoteParty.create();
      addTearDown(bob.close);
      const bobAddress = SignalProtocolAddress('device-b', 1);
      await stack.cryptoService.establishSession(bobAddress, await bob.bundle());

      final message = await stack.sendMessage.call(
        'conv-1',
        'device-b',
        _plaintext('hi'),
      );
      final frame = RelayPacketFrame.deserialize(message.ciphertext);
      expect(frame.destination, 'device-b');

      await stack.dispose();
    },
  );

  test('test_EARS_COMM_7_stack_degrades_when_crypto_init_fails', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final throwingStore = _ThrowingStore(db);

    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'device-a',
      transport: newTransport(),
      store: throwingStore,
    );

    expect(stack.status, isA<MessagingStackStatusUnavailable>());
    // Every member is still non-null and safe to reference.
    expect(stack.db, same(db));
    expect(stack.identityService, isNotNull);
    expect(stack.cryptoService, isNotNull);
    expect(stack.transport, isNotNull);
    expect(stack.routingEngine, isNotNull);
    expect(stack.relayEngine, isNotNull);
    expect(stack.sendMessage, isNotNull);
    expect(stack.receiveMessage, isNotNull);
    expect(stack.syncCursors, isNotNull);

    await stack.dispose();
  });

  test('test_stack_builds_without_firebase', () async {
    // No Firebase.initializeApp() call anywhere in this test file -- proves
    // MessagingStack.create() itself never touches Firebase (ADR-0005:
    // offline-first, device identity/session fully local).
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'device-a',
      transport: newTransport(),
    );
    expect(stack.status, const MessagingStackStatus.ready());
    await stack.dispose();
  });

  test('test_no_session_send_fails_honestly', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'device-a',
      transport: newTransport(),
    );
    expect(stack.status, const MessagingStackStatus.ready());

    // T07 (prekey exchange / establishSession) has not landed yet -- this
    // documents the pre-T07 state explicitly rather than leaving it implied
    // (task file §8).
    await expectLater(
      () => stack.sendMessage.call('conv-1', 'device-b', _plaintext('hi')),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'messaging.no_session'),
      ),
    );

    await stack.dispose();
  });

  // --- E07-T14: the group send path, composed (EARS-COMM-35) -----------

  test('test_EARS_COMM_35_composed_stack_sends_a_real_group_message', () async {
    final parties = await twoStacksWithGroupReady();
    final alice = parties.alice;
    final bob = parties.bob;
    addTearDown(alice.dispose);
    addTearDown(bob.dispose);

    final deliveredFuture = bob.inbound.delivered.first;

    // Reached ONLY through the composed object -- never a locally
    // constructed SendGroupMessageUseCase (task file §6/§9).
    final result = await alice.sendGroupMessage.send(
      groupId: parties.groupId,
      body: Uint8List.fromList('hi group'.codeUnits),
    );
    expect(result, isNull);

    await alice.relayEngine.processQueue();
    await settle();
    await settle();

    final delivered = await deliveredFuture;
    expect(delivered.conversationId, parties.groupId);
    expect(delivered.senderDeviceId, 'alice');

    final rows = await bob.db.select(bob.db.messages).get();
    expect(rows, hasLength(1));
    expect(rows.single.conversationId, parties.groupId);
  });

  test(
    'test_composed_send_group_message_uses_the_stack_database_and_identity',
    () async {
      final parties = await twoStacksWithGroupReady();
      final alice = parties.alice;
      final bob = parties.bob;
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);

      final result = await alice.sendGroupMessage.send(
        groupId: parties.groupId,
        body: Uint8List.fromList('second message'.codeUnits),
      );
      expect(result, isNull);

      // The row lands in the stack's OWN db, under the stack's OWN
      // selfDeviceId -- the composition proof, not a re-proof of the
      // encryption/fan-out logic E07-T06 already covers.
      final rows = await alice.db.select(alice.db.messages).get();
      expect(rows, hasLength(1));
      expect(rows.single.senderDeviceId, alice.selfDeviceId);
      // A real, dense sequence number from the shared reserver -- the
      // first message on a fresh conversationId/senderDeviceId pair is 0
      // (same property `test_group_send_reserves_a_real_sequence_number_
      // without_a_fake_seam` asserts in E07-T06's own suite, here proven
      // through the composition root instead of a directly-constructed
      // use case).
      expect(rows.single.sequenceNumber, 0);

      await alice.relayEngine.processQueue();
      await settle();
      await settle();
    },
  );

  test(
    'test_send_group_message_is_the_same_instance_on_every_read',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: newTransport(),
      );
      expect(stack.status, const MessagingStackStatus.ready());

      expect(
        identical(stack.sendGroupMessage, stack.sendGroupMessage),
        isTrue,
      );

      await stack.dispose();
    },
  );

  // --- E09-T03: location-share registration (control kind 7) -----------

  test(
    'test_location_share_is_registered_exactly_once_on_control_kind_7',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: newTransport(),
      );
      expect(stack.status, const MessagingStackStatus.ready());

      expect(stack.locationShareService, isA<LocationShareService>());
      expect(
        identical(stack.locationShareService, stack.locationShareService),
        isTrue,
      );

      // A second registration on the SAME control kind must throw --
      // `InboundPipeline.registerControlHandler`'s own duplicate guard
      // (task file §6 risk note).
      expect(
        () => stack.inbound.registerControlHandler(
          kControlKindLocationShare,
          stack.locationShareService.handleWireFrame,
        ),
        throwsA(isA<StateError>()),
      );

      await stack.dispose();
    },
  );

  // --- E09-T05: real PlatformLocationSource wiring ----------------------

  test(
    'test_composition_root_wires_a_real_platform_location_source_not_the_retired_placeholder',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: newTransport(),
      );
      addTearDown(stack.dispose);
      expect(stack.status, const MessagingStackStatus.ready());

      await RelationshipRepository(stack.db)
          .upsert('device-b', RelationshipState.trusted);
      final settings = LocationSettingsRepository(db: stack.db);
      await settings.writeGlobalEnabled(true);
      await settings.writePeerEnabled('device-b', true);

      // Before E09-T05, `stack.locationShareService`'s source was
      // `_UnavailableLocationSource` -- an unconditional, permanent
      // no-fix that never touched a platform channel at all. This test
      // environment has no real GPS/geolocator platform channel mocked
      // either, so a genuinely wired `PlatformLocationSource` also
      // resolves to `noFix` here -- the same OUTCOME, but for a different
      // REASON (an actual acquisition attempt that fails, per
      // EARS-LOC-16, not a source that never tries). What this test
      // actually proves is the one thing a same-outcome check cannot:
      // `share()` runs to completion without throwing through a real
      // attempted permission/provider check with no platform channel
      // present -- exactly the "does not crash the caller" contract
      // `PlatformLocationSource.currentFix()` promises (task file §5),
      // now exercised through the composition root end to end, not just
      // in `platform_location_source_test.dart`'s own unit tests against
      // injected seams.
      final outcome = await stack.locationShareService.share('device-b');
      expect(outcome, const LocationShareOutcomeNoFix());
    },
  );

  // --- E09-B06: the privacy sweep is wired at composition-root startup --

  test(
    'test_EARS_LOC_5_sweep_runs_at_composition_root_startup',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Seed a stored fix for a peer this device has already blocked --
      // written DIRECTLY to `location_fixes`, deliberately WITHOUT ever
      // sending or receiving a wire frame, so `handleWireFrame`'s own
      // delete-on-not-visible branch (which only fires on a NEW inbound
      // frame) cannot possibly be what deletes it -- mirrors
      // `location_share_service_test.dart`'s own "privacy sweep" group
      // reasoning: a test that routed through a frame would prove nothing
      // about the composition-root wiring this bug is actually about.
      await RelationshipRepository(db)
          .upsert('device-b', RelationshipState.blocked);
      final fixes = LocationFixRepository(db: db);
      await fixes.upsertFix(
        peerDeviceId: 'device-b',
        latitude: 12.0,
        longitude: 34.0,
        capturedAtMs: 1000,
        receivedAtMs: 1000,
      );
      expect(await fixes.readFix('device-b'), isNotNull);

      // No message is ever received by this stack -- `create()`'s own
      // startup sweep is what must remove the row, not any inbound wire
      // frame.
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: newTransport(),
      );
      addTearDown(stack.dispose);
      expect(stack.status, const MessagingStackStatus.ready());

      expect(await fixes.readFix('device-b'), isNull);
    },
  );
}

/// Small local helper so the decrypted-plaintext assertion above reads as a
/// string without pulling in `dart:convert`'s `utf8` name into this file's
/// broader namespace (kept file-local, single use).
String utf8Decode(Uint8List bytes) => String.fromCharCodes(bytes);
