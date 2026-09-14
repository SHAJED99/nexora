// Tests for the E04-B12 identity-announce protocol (Option A, part 1/2 --
// see E04-B13 for the outbound-addressing consumer half).
//
// Two shapes of test here, mirroring this codebase's own established
// patterns:
// - A full round-trip through two REAL `MessagingStack`s connected over a
//   mocked `TransportService`/`TransportEventsApi` Pigeon boundary
//   (`prekey_exchange_test.dart`'s own two-party harness), but --
//   deliberately, unlike that file -- using a Bluetooth-address-SHAPED
//   transport id that is NOT either side's own `selfDeviceId`. That
//   distinction is the entire bug this task exists to fix (task file §2):
//   `Relationship.deviceId` is keyed by the transport/Bluetooth address,
//   `RelayPacketFrame.source`/`.destination` are keyed by the real
//   `selfDeviceId`, and nothing before this task ever reconciled the two.
// - Single-pipeline tests against a fresh `InboundPipeline` (this file's
//   own `inbound_pipeline_test.dart` sibling pattern) proving the `isForUs`
//   bypass is narrowly scoped to exactly `kControlKindIdentityAnnounce` --
//   a regular control/message frame with a non-matching destination must
//   still be correctly routed to relay, never swept into the bypass.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/messaging/identity_announce.dart';
import 'package:nexora/core/messaging/inbound_pipeline.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'identity-announce-${suffixCounter++}';

  Future<MessagingStack> newStack(String selfDeviceId, String suffix) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: selfDeviceId,
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
    return stack;
  }

  void pushDiscovered(String suffix, String deviceId) {
    final device = TransportDevice(
      id: deviceId,
      displayName: deviceId,
      type: TransportType.bluetooth,
    );
    final ByteData message =
        TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!;
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
    final ByteData message = TransportEventsApi.pigeonChannelCodec
        .encodeMessage(<Object?>[deviceId, state])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
      message,
      (ByteData? _) {},
    );
  }

  void pushIncomingData(String suffix, String deviceId, Uint8List bytes) {
    final ByteData message = TransportEventsApi.pigeonChannelCodec
        .encodeMessage(<Object?>[deviceId, bytes])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$suffix',
      message,
      (ByteData? _) {},
    );
  }

  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  Future<void> connectPeer(String suffix, String deviceId) async {
    pushDiscovered(suffix, deviceId);
    await settle();
    pushConnectionState(suffix, deviceId, ConnectionState.connected);
    await settle();
  }

  /// Wires [fromSuffix]'s outbound `TransportApi.send`/`.connect` calls into
  /// [toSuffix]'s `onDataReceived`/connection-settle events, tagging every
  /// forwarded frame as arriving from [fromDeviceId] -- the loopback
  /// pattern `prekey_exchange_test.dart` already establishes, standing in
  /// for two devices that are actually connected and reachable.
  void wireSend(String fromSuffix, String fromDeviceId, String toSuffix) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.send.$fromSuffix',
      (ByteData? message) async {
        final List<Object?> args =
            TransportApi.pigeonChannelCodec.decodeMessage(message)!
                as List<Object?>;
        final Uint8List bytes = args[1]! as Uint8List;
        final ByteData eventMessage = TransportEventsApi.pigeonChannelCodec
            .encodeMessage(<Object?>[fromDeviceId, bytes])!;
        messenger.handlePlatformMessage(
          'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$toSuffix',
          eventMessage,
          (ByteData? _) {},
        );
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.connect.$fromSuffix',
      (ByteData? message) async {
        final List<Object?> args =
            TransportApi.pigeonChannelCodec.decodeMessage(message)!
                as List<Object?>;
        final String deviceId = args[0]! as String;
        scheduleMicrotask(() {
          messenger.handlePlatformMessage(
            'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$fromSuffix',
            TransportEventsApi.pigeonChannelCodec.encodeMessage(
              <Object?>[deviceId, ConnectionState.connected],
            )!,
            (ByteData? _) {},
          );
        });
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
  }

  test(
    'test_E04_B12_announce_fires_automatically_on_connect_and_populates_'
    'remoteSelfDeviceId_keyed_by_the_bluetooth_address_not_selfDeviceId',
    () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      // Deliberately NOT Bluetooth-MAC-shaped -- these are each device's
      // real `selfDeviceId`, exactly like `generateSecureDeviceId()`
      // produces in production (task file §2, point 2: random/key-derived,
      // unrelated to any transport address).
      final a = await newStack('self-device-a-9f3c1', aSuffix);
      final b = await newStack('self-device-b-7ae02', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      // The Bluetooth-address-shaped transport ids each side connects
      // through -- structurally unrelated to either `selfDeviceId` above,
      // reproducing the exact mismatch the task's root-cause analysis
      // confirmed live on real hardware.
      const aBluetoothAddress = 'AA:AA:AA:AA:AA:01';
      const bBluetoothAddress = 'BB:BB:BB:BB:BB:02';

      a.inbound.start();
      b.inbound.start();
      wireSend(aSuffix, aBluetoothAddress, bSuffix);
      wireSend(bSuffix, bBluetoothAddress, aSuffix);

      // A connects to B first. This automatically fires A's own announce
      // toward B (`messaging_stack.dart`'s `inbound.peerConnected` wiring)
      // -- but B has not yet opened its own `incomingData(aBluetoothAddress)`
      // subscription (that only happens once B's OWN connectionState for
      // that address settles, below), so this first announce is lost —
      // exactly the real, accepted "both ends must already be listening"
      // limitation a broadcast-stream-with-no-replay transport has (this
      // file's own header doc; `inbound_pipeline.dart`'s "Peer subscription
      // lifecycle" note). Not asserted on here.
      await connectPeer(aSuffix, bBluetoothAddress);

      // B connects to A. A was ALREADY listening (the line above), so B's
      // own automatic announce is received this time.
      await connectPeer(bSuffix, aBluetoothAddress);
      await settle();

      final aSideRelationship = await (a.db.select(a.db.relationships)
            ..where((t) => t.deviceId.equals(bBluetoothAddress)))
          .getSingleOrNull();
      expect(aSideRelationship, isNotNull);
      expect(aSideRelationship!.remoteSelfDeviceId, 'self-device-b-7ae02');
      // The row is keyed by the Bluetooth address, NOT re-keyed to the
      // peer's real selfDeviceId (task file §2a's scope-refinement note --
      // zero re-keying of Relationship.deviceId).
      expect(aSideRelationship.deviceId, bBluetoothAddress);

      // Force a second automatic fire on A's side (a reconnect -- entirely
      // realistic; this codebase's own `_onConnectionStateChanged` already
      // treats a fresh `connected` transition after a disconnect as a new
      // event), now that B IS listening, to prove the mechanism is genuinely
      // symmetric ("from both sides", task file §3 point 5) rather than
      // asserting only the one direction the connect ordering above happens
      // to favor.
      pushConnectionState(aSuffix, bBluetoothAddress, ConnectionState.disconnected);
      await settle();
      pushConnectionState(aSuffix, bBluetoothAddress, ConnectionState.connected);
      await settle();
      await settle();

      final bSideRelationship = await (b.db.select(b.db.relationships)
            ..where((t) => t.deviceId.equals(aBluetoothAddress)))
          .getSingleOrNull();
      expect(bSideRelationship, isNotNull);
      expect(bSideRelationship!.remoteSelfDeviceId, 'self-device-a-9f3c1');
      expect(bSideRelationship.deviceId, aBluetoothAddress);

      // Never relayed (task file §3 point 4): neither side ever queued an
      // identity-announce frame for forwarding.
      expect(await a.db.select(a.db.relayPackets).get(), isEmpty);
      expect(await b.db.select(b.db.relayPackets).get(), isEmpty);

      expect(a.identityAnnounce.counters.sent, greaterThanOrEqualTo(1));
      expect(b.identityAnnounce.counters.received, 1);
      expect(a.identityAnnounce.counters.received, 1);
    },
  );

  test(
    'test_E04_B12_announce_to_an_already_known_relationship_updates_'
    'remoteSelfDeviceId_without_touching_state',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('self-device-receiver', suffix);
      addTearDown(receiver.dispose);

      const senderBluetoothAddress = 'CC:CC:CC:CC:CC:03';
      // Seed a pre-existing, already-evaluated relationship (e.g. the user
      // explicitly trusted this Bluetooth address before this peer ever
      // announced) -- the announce must never downgrade/overwrite `state`.
      await receiver.db.into(receiver.db.relationships).insertOnConflictUpdate(
            RelationshipsCompanion.insert(
              deviceId: senderBluetoothAddress,
              state: 'trusted',
              updatedAt: DateTime.now(),
            ),
          );

      receiver.inbound.start();
      await connectPeer(suffix, senderBluetoothAddress);

      final now = DateTime.now().millisecondsSinceEpoch;
      final bodyBytes = <int>[
        kControlKindIdentityAnnounce,
        ...'self-device-sender-real-id'.codeUnits,
      ];
      final frame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-announce-1',
        destination: senderBluetoothAddress,
        source: 'self-device-sender-real-id',
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 30000,
        payload: Uint8List.fromList(bodyBytes),
      );
      pushIncomingData(suffix, senderBluetoothAddress, frame.serialize());
      await settle();
      await settle();

      final row = await (receiver.db.select(receiver.db.relationships)
            ..where((t) => t.deviceId.equals(senderBluetoothAddress)))
          .getSingle();
      expect(row.remoteSelfDeviceId, 'self-device-sender-real-id');
      // `state` untouched -- this announce carries no trust information.
      expect(row.state, 'trusted');
      expect(receiver.identityAnnounce.counters.relationshipsCreated, 0);
    },
  );

  test(
    'test_E04_B12_isForUs_bypass_applies_ONLY_to_kControlKindIdentityAnnounce',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('self-device-b', suffix);
      addTearDown(receiver.dispose);

      // A FRESH InboundPipeline with NO identity-announce handler
      // registered at all (mirrors inbound_pipeline_test.dart's own
      // pattern of constructing a bare pipeline to isolate dispatch
      // behaviour from `MessagingStack.create`'s full composition root).
      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await connectPeer(suffix, 'AA:AA:AA:AA:AA:99');

      final now = DateTime.now().millisecondsSinceEpoch;

      // Case 1: a genuine identity-announce frame, addressed (as it always
      // must be) to something that is NOT this device's own selfDeviceId.
      // With no handler registered, this must be counted as
      // `unhandledControl` -- proving the bypass is real (it does not fall
      // through to the relay branch, which would have counted `forwarded`
      // instead) -- and, critically, must NOT be relayed.
      final announceFrame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-announce-bypass-1',
        destination: 'AA:AA:AA:AA:AA:99', // the Bluetooth address, never == selfDeviceId
        source: 'peer-real-self-device-id',
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 30000,
        payload: Uint8List.fromList(<int>[
          kControlKindIdentityAnnounce,
          ...'peer-real-self-device-id'.codeUnits,
        ]),
      );
      pushIncomingData(suffix, 'AA:AA:AA:AA:AA:99', announceFrame.serialize());
      await settle();
      await settle();

      expect(pipeline.counters.unhandledControl, 1);
      expect(pipeline.counters.forwarded, 0);
      expect(await receiver.db.select(receiver.db.relayPackets).get(), isEmpty);

      // Case 2: the FALSIFICATION -- a regular control frame with a
      // DIFFERENT (non-identity-announce) controlKind byte and a
      // non-matching destination must still be correctly routed to relay,
      // never swept into the bypass, even though it superficially looks
      // just like case 1 (PayloadType.control, destination != selfDeviceId).
      const otherControlKind = 2; // DeliveryAckService's own reserved value
      final otherFrame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-other-control-1',
        destination: 'some-other-device-not-us',
        source: 'AA:AA:AA:AA:AA:99',
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 30000,
        payload: Uint8List.fromList(<int>[otherControlKind, 1, 2, 3]),
      );
      pushIncomingData(suffix, 'AA:AA:AA:AA:AA:99', otherFrame.serialize());
      await settle();
      await settle();

      expect(pipeline.counters.forwarded, 1);
      final relayRows = await receiver.db.select(receiver.db.relayPackets).get();
      expect(relayRows, hasLength(1));
      expect(relayRows.single.destinationId, 'some-other-device-not-us');
      // Byte-preserving forward, unaffected by the new bypass logic.
      expect(relayRows.single.payload, otherFrame.serialize());
    },
  );

  test(
    'test_E04_B12_bypassed_announce_is_never_forwarded_even_with_a_'
    'handler_registered',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('self-device-b', suffix);
      addTearDown(receiver.dispose);

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      var handlerCalls = 0;
      String? seenLinkDeviceId;
      pipeline.registerIdentityAnnounceHandler((linkDeviceId, frame) async {
        handlerCalls++;
        seenLinkDeviceId = linkDeviceId;
      });
      pipeline.start();
      await connectPeer(suffix, 'DD:DD:DD:DD:DD:04');

      final now = DateTime.now().millisecondsSinceEpoch;
      final frame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-announce-2',
        destination: 'DD:DD:DD:DD:DD:04',
        source: 'peer-real-id-2',
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 30000,
        payload: Uint8List.fromList(<int>[
          kControlKindIdentityAnnounce,
          ...'peer-real-id-2'.codeUnits,
        ]),
      );
      pushIncomingData(suffix, 'DD:DD:DD:DD:DD:04', frame.serialize());
      await settle();
      await settle();

      expect(handlerCalls, 1);
      // The link device id (the Bluetooth address the frame physically
      // arrived on), not `frame.destination` or anything else the frame
      // claims -- this is the value `identity_announce.dart`'s own
      // `handleAnnounce` keys the Relationship row by.
      expect(seenLinkDeviceId, 'DD:DD:DD:DD:DD:04');
      expect(pipeline.counters.forwarded, 0);
      expect(pipeline.counters.unhandledControl, 0);
      expect(await receiver.db.select(receiver.db.relayPackets).get(), isEmpty);
    },
  );

  group('E04-B16 — announce feeds routing aliases only for trusted peers', () {
    RelayPacketFrame announceFrame(String announcedId) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-b16-$announcedId',
        destination: 'LINK-B16',
        source: announcedId,
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 30000,
        payload: Uint8List.fromList(<int>[
          kControlKindIdentityAnnounce,
          ...announcedId.codeUnits,
        ]),
      );
    }

    Future<MessagingStack> stackWithRelationship(String state) async {
      final stack = await newStack('self-b16-$state', nextSuffix());
      await stack.db.into(stack.db.relationships).insert(
            RelationshipsCompanion.insert(
              deviceId: 'LINK-B16',
              state: state,
              updatedAt: DateTime.now(),
            ),
          );
      stack.routingEngine.recordLinkMeasurement(
        'LINK-B16',
        latencyMs: 10,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );
      return stack;
    }

    test('test_E04_B16_trusted_peer_announce_creates_a_routing_alias',
        () async {
      final stack = await stackWithRelationship('trusted');
      addTearDown(stack.dispose);

      await stack.identityAnnounce
          .handleAnnounce('LINK-B16', announceFrame('peer-identity-b16'));

      final route = stack.routingEngine
          .computeRoute('peer-identity-b16', TrafficProfile.interactive);
      expect(route?.hops, ['LINK-B16']);
    });

    test('test_E04_B16_unknown_peer_announce_creates_no_routing_alias',
        () async {
      final stack = await stackWithRelationship('unknown');
      addTearDown(stack.dispose);

      await stack.identityAnnounce
          .handleAnnounce('LINK-B16', announceFrame('peer-identity-b16'));

      expect(
        stack.routingEngine
            .computeRoute('peer-identity-b16', TrafficProfile.interactive),
        isNull,
      );
    });
  });
}
