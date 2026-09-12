// Tests for DeliveryAck / DeliveryAckService (E06-T08, EARS-MSG-7/8/9).
//
// Codec tests are pure/fast (no I/O). The EARS-MSG-7 tests drive two real
// `MessagingStack`s through the REAL `TransportService`/`TransportEventsApi`
// Pigeon boundary, mirroring `prekey_exchange_test.dart`'s own harness --
// acks travel as real control frames through T05's `InboundPipeline`, not a
// fake in-Dart callback. EARS-MSG-8/9 use direct `handleControlFrame` calls
// against hand-seeded `messages` rows, mirroring
// `prekey_exchange_test.dart`'s own `test_unsolicited_bundle_response_is_dropped`
// pattern -- the fastest way to inject a specific, otherwise-impossible-to-
// construct wire scenario (a foreign/out-of-order ack) without needing a
// second full stack for every edge case.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/delivery_ack.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/domain/relationship.dart'
    show RelationshipState;

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'delivery-ack-${suffixCounter++}';

  group('DeliveryAck codec', () {
    test('test_delivery_ack_codec_round_trips_every_state', () {
      for (final state in DeliveryAckState.values) {
        final ack = DeliveryAck(
          messageId: 'm-${state.name}',
          state: state,
          observedAtMs: 1234567890,
        );
        final decoded = DeliveryAck.deserialize(ack.serialize());
        expect(decoded.messageId, ack.messageId);
        expect(decoded.state, ack.state);
        expect(decoded.observedAtMs, ack.observedAtMs);
      }
    });

    test('test_delivery_ack_codec_rejects_malformed_matrix', () {
      // Empty buffer -- no state byte at all.
      expect(
        () => DeliveryAck.deserialize(Uint8List(0)),
        throwsFormatException,
      );

      // Unknown state tag -- never coerced to a known state.
      expect(
        () => DeliveryAck.deserialize(Uint8List.fromList([99, 0, 0, 0, 0])),
        throwsFormatException,
      );

      final valid = DeliveryAck(
        messageId: 'm-1',
        state: DeliveryAckState.delivered,
        observedAtMs: 42,
      ).serialize();

      // Truncated messageIdLength prefix (only 2 of the 4 length bytes).
      expect(
        () => DeliveryAck.deserialize(valid.sublist(0, 3)),
        throwsFormatException,
      );

      // A messageIdLength that claims more bytes than remain.
      final withBadLength = Uint8List.fromList(valid);
      withBadLength[1] = 0xff; // corrupt the length's high byte
      expect(
        () => DeliveryAck.deserialize(withBadLength),
        throwsFormatException,
      );

      // Truncated observedAtMs (whole tail cut off).
      final missingTimestamp = valid.sublist(0, valid.length - 4);
      expect(
        () => DeliveryAck.deserialize(missingTimestamp),
        throwsFormatException,
      );

      // Trailing garbage after an otherwise-complete, valid buffer.
      final withTrailingByte = Uint8List.fromList([...valid, 0]);
      expect(
        () => DeliveryAck.deserialize(withTrailingByte),
        throwsFormatException,
      );
    });
  });

  group('DeliveryAckService.handleControlFrame — ownership + monotonicity', () {
    Future<MessagingStack> newLocalStack(String selfDeviceId) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final store = DriftSignalProtocolStore(db);
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: selfDeviceId,
        store: store,
        cryptoService: CryptoService.withStore(store),
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: nextSuffix(),
        ),
      );
      expect(stack.status, const MessagingStackStatus.ready());
      return stack;
    }

    Future<void> seedMessage(
      MessagingStack stack, {
      required String id,
      required String conversationId,
      required String senderDeviceId,
      required DeliveryState deliveryState,
    }) async {
      await stack.db.into(stack.db.messages).insert(
            MessagesCompanion.insert(
              id: id,
              conversationId: conversationId,
              senderDeviceId: senderDeviceId,
              sequenceNumber: 0,
              ciphertext: Uint8List.fromList([1, 2, 3]),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              deliveryState: deliveryState.name,
            ),
          );
    }

    RelayPacketFrame ackFrame({
      required String from,
      required String to,
      required DeliveryAck ack,
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-ack-test',
        destination: to,
        source: from,
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 60000,
        payload: ack.serialize(),
      );
    }

    test(
      'test_EARS_MSG_8_foreign_ack_is_rejected_unknown_message_id',
      () async {
        final a = await newLocalStack('device-a');
        addTearDown(a.dispose);

        await a.deliveryAckService.handleControlFrame(
          ackFrame(
            from: 'device-b',
            to: 'device-a',
            ack: const DeliveryAck(
              messageId: 'no-such-message',
              state: DeliveryAckState.delivered,
              observedAtMs: 1,
            ),
          ),
        );

        expect(a.deliveryAckService.counters.rejectedUnknownMessage, 1);
        expect(a.deliveryAckService.counters.accepted, 0);
      },
    );

    test(
      'test_EARS_MSG_8_foreign_ack_is_rejected_wrong_peer_and_third_device',
      () async {
        final a = await newLocalStack('device-a');
        addTearDown(a.dispose);

        // A message A itself sent to device-b.
        await seedMessage(
          a,
          id: 'm-mine',
          conversationId: 'device-b',
          senderDeviceId: 'device-a',
          deliveryState: DeliveryState.sent,
        );
        // A message some OTHER device (device-c) sent -- A merely received
        // and stored it (senderDeviceId != this device), so A never "owns"
        // its delivery-state lifecycle as a sender.
        await seedMessage(
          a,
          id: 'm-theirs',
          conversationId: 'device-c',
          senderDeviceId: 'device-c',
          deliveryState: DeliveryState.accepted,
        );

        // An ack for A's OWN message, but claiming to be from the WRONG peer.
        await a.deliveryAckService.handleControlFrame(
          ackFrame(
            from: 'device-x',
            to: 'device-a',
            ack: const DeliveryAck(
              messageId: 'm-mine',
              state: DeliveryAckState.delivered,
              observedAtMs: 1,
            ),
          ),
        );

        // An ack claiming to be about a message a THIRD device authored.
        await a.deliveryAckService.handleControlFrame(
          ackFrame(
            from: 'device-c',
            to: 'device-a',
            ack: const DeliveryAck(
              messageId: 'm-theirs',
              state: DeliveryAckState.delivered,
              observedAtMs: 1,
            ),
          ),
        );

        expect(a.deliveryAckService.counters.rejectedForeign, 2);
        expect(a.deliveryAckService.counters.accepted, 0);

        final mine = await (a.db.select(a.db.messages)
              ..where((t) => t.id.equals('m-mine')))
            .getSingle();
        expect(mine.deliveryState, DeliveryState.sent.name);

        final theirs = await (a.db.select(a.db.messages)
              ..where((t) => t.id.equals('m-theirs')))
            .getSingle();
        expect(theirs.deliveryState, DeliveryState.accepted.name);
      },
    );

    test(
      'test_EARS_MSG_9_out_of_order_acks_do_not_regress_state',
      () async {
        final a = await newLocalStack('device-a');
        addTearDown(a.dispose);

        await seedMessage(
          a,
          id: 'm-1',
          conversationId: 'device-b',
          senderDeviceId: 'device-a',
          deliveryState: DeliveryState.sent,
        );

        // `delivered` arrives first...
        await a.deliveryAckService.handleControlFrame(
          ackFrame(
            from: 'device-b',
            to: 'device-a',
            ack: const DeliveryAck(
              messageId: 'm-1',
              state: DeliveryAckState.delivered,
              observedAtMs: 2,
            ),
          ),
        );
        // ...then the (lower, stale) `accepted` arrives late.
        await a.deliveryAckService.handleControlFrame(
          ackFrame(
            from: 'device-b',
            to: 'device-a',
            ack: const DeliveryAck(
              messageId: 'm-1',
              state: DeliveryAckState.accepted,
              observedAtMs: 1,
            ),
          ),
        );

        expect(a.deliveryAckService.counters.accepted, 1);
        expect(a.deliveryAckService.counters.staleIgnored, 1);

        final row = await (a.db.select(a.db.messages)
              ..where((t) => t.id.equals('m-1')))
            .getSingle();
        expect(row.deliveryState, DeliveryState.delivered.name);
      },
    );
  });

  group('DeliveryAckService — read receipts disabled', () {
    test('test_read_acks_are_not_emitted_while_disabled', () async {
      final suffix = nextSuffix();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final store = DriftSignalProtocolStore(db);
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        store: store,
        cryptoService: CryptoService.withStore(store),
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: suffix,
        ),
      );
      addTearDown(stack.dispose);

      var sendCallCount = 0;
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
        (ByteData? message) async {
          sendCallCount++;
          return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
        },
      );

      await stack.db.into(stack.db.messages).insert(
            MessagesCompanion.insert(
              id: 'm-read-1',
              conversationId: 'device-b',
              senderDeviceId: 'device-b',
              sequenceNumber: 0,
              ciphertext: Uint8List.fromList([9]),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              deliveryState: DeliveryState.accepted.name,
            ),
          );

      await stack.deliveryAckService.markRead('m-read-1');

      // Zero bytes on the wire -- asserted at the transport level, not the
      // UI (task file §9 self-review requirement): a disabled feature that
      // still sends a frame has leaked exactly the information it was meant
      // to withhold.
      expect(sendCallCount, 0);
      expect(kReadReceiptsEnabled, isFalse);
    });
  });

  group('EARS-MSG-7 — real two-stack ack round trip', () {
    // Deliberately NOT passing per-stack `store`/`cryptoService` overrides
    // here (unlike `prekey_exchange_test.dart`'s own harness): this file's
    // messages travel through `ReceiveMessageUseCase`, and
    // `messaging_stack.dart`'s `create()` wires `ReceiveMessageUseCase`'s
    // `decrypt` to its OWN default (`CryptoService.instance`) rather than
    // to whichever `cryptoService` a caller injects — a pre-existing gap
    // this task's `files:` fence does not include fixing. Two isolated
    // `CryptoService.withStore` instances would leave B's `decrypt`
    // silently calling the wrong (uninitialized) store. Mirrors
    // `messaging_coordinator_test.dart`'s own working
    // `test_start_calls_inbound_pipeline_start` pattern instead: both
    // stacks share the process-wide `CryptoService.instance` singleton,
    // which is safe here because `establishSession`/`encrypt`/`decrypt` are
    // only ever exercised against whichever store was bound LAST (B's,
    // constructed after A) -- correct for this single-conversation test,
    // not a general two-independent-identities simulation.
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
      // E04-B05: `DeliveryAckService`'s send now goes through
      // `_stack.directSend` (connect-then-send) -- mock `[fromSuffix]`'s own
      // `TransportApi.connect` to accept and settle immediately, mirroring
      // `TransportService.connect`'s real two-channel contract.
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

    void pushDiscovered(String suffix, String deviceId) {
      final device = TransportDevice(
        id: deviceId,
        displayName: deviceId,
        type: TransportType.bluetooth,
      );
      final ByteData message = TransportEventsApi.pigeonChannelCodec
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
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    Future<void> connectPeer(String suffix, String deviceId) async {
      pushDiscovered(suffix, deviceId);
      await settle();
      pushConnectionState(suffix, deviceId, ConnectionState.connected);
      await settle();
    }

    test(
      'test_EARS_MSG_7_sender_sees_delivered_after_receiver_stores',
      () async {
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        a.inbound.start();
        b.inbound.start();

        // Only B -> A needs real transport wiring: A's outbound message
        // "send" is never exercised here (SendMessageUseCase only enqueues
        // locally; RelayEngine.processQueue() is not driven in this test),
        // so the message itself is delivered directly onto B's incoming
        // channel below, matching messaging_coordinator_test.dart's own
        // `test_start_calls_inbound_pipeline_start` pattern. The ACKS B
        // sends back, though, are real `transport.send` calls that must
        // reach A for real.
        wireSend(bSuffix, 'device-b', aSuffix);
        await connectPeer(aSuffix, 'device-b');
        await connectPeer(bSuffix, 'device-a');

        await a.cryptoService.establishSession(
          const SignalProtocolAddress('device-b', 1),
          await b.identityService.getLocalPreKeyBundle(),
        );

        final sent = await a.sendMessage.call(
          'device-b',
          'device-b',
          _plaintext('hello bob'),
        );

        pushIncomingData(bSuffix, 'device-a', sent.ciphertext);
        await settle();
        await settle();

        final row = await (a.db.select(a.db.messages)
              ..where((t) => t.id.equals(sent.id)))
            .getSingle();
        expect(row.deliveryState, DeliveryState.delivered.name);

        final deliveryStateRows = await (a.db.select(a.db.deliveryStates)
              ..where((t) => t.messageId.equals(sent.id)))
            .get();
        expect(
          deliveryStateRows.map((r) => r.state),
          containsAll(<String>[
            DeliveryState.accepted.name,
            DeliveryState.delivered.name,
          ]),
        );
      },
    );

    test('test_EARS_MSG_7_duplicate_delivery_does_not_re_ack', () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      a.inbound.start();
      b.inbound.start();

      wireSend(bSuffix, 'device-b', aSuffix);
      await connectPeer(aSuffix, 'device-b');
      await connectPeer(bSuffix, 'device-a');

      await a.cryptoService.establishSession(
        const SignalProtocolAddress('device-b', 1),
        await b.identityService.getLocalPreKeyBundle(),
      );

      final sent = await a.sendMessage.call(
        'device-b',
        'device-b',
        _plaintext('hello again'),
      );

      // The SAME wire packet, delivered to B twice -- the ordinary mesh
      // forwarding-duplicate case (task file §8 test plan).
      pushIncomingData(bSuffix, 'device-a', sent.ciphertext);
      await settle();
      pushIncomingData(bSuffix, 'device-a', sent.ciphertext);
      await settle();
      await settle();

      expect(b.inbound.counters.duplicate, 1);
      // One ack PAIR (accepted + delivered) -- not two.
      expect(b.deliveryAckService.counters.sent, 2);
    });

    test(
      'test_E04_B15_ack_frame_destination_resolves_via_resolveOutboundDestination',
      () async {
        // Same fix pattern E04-B13 established, applied to
        // `DeliveryAckService._sendAck`'s own `RelayPacketFrame`
        // construction site. Disclosed honestly (see this task's own Open
        // Questions): `_sendAck`'s `peerDeviceId` parameter is always the
        // stored message's own `senderDeviceId` -- populated from
        // `frame.source`, i.e. already a logical `selfDeviceId`, never a
        // Bluetooth MAC -- so `resolveOutboundDestination`'s lookup here
        // can never match a real `relationships` row in production (that
        // table is keyed by MAC). This test proves the code is correctly
        // WIRED to call it and use its result for the frame's `destination`
        // field -- not a claim that this resolves against a real MAC
        // today. The deeper gap (the ack's own TRANSPORT dial has no
        // physical-link information available to it at all, the same
        // shape as the carried-forward `PrekeyExchange._handleBundleRequest`
        // finding this task also fixed) is out of this task's own `files:`
        // fence (would require plumbing link data through
        // `InboundPipeline.delivered`/`messaging_stack.dart`) and is
        // recorded as a follow-up Open Question instead.
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        a.inbound.start();
        b.inbound.start();

        wireSend(bSuffix, 'device-b', aSuffix);
        await connectPeer(aSuffix, 'device-b');
        await connectPeer(bSuffix, 'device-a');

        await a.cryptoService.establishSession(
          const SignalProtocolAddress('device-b', 1),
          await b.identityService.getLocalPreKeyBundle(),
        );

        final sent = await a.sendMessage.call(
          'device-b',
          'device-b',
          _plaintext('hello bob'),
        );

        // B has a relationship row keyed by the SAME value
        // `_sendAck`'s own `peerDeviceId` will be (the message's
        // `senderDeviceId`, 'device-a') -- see the disclosure above for
        // why this is a mechanical proof, not a real-MAC scenario.
        await b.db.into(b.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'device-a',
                state: RelationshipState.unknown.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('device-a-resolved'),
              ),
            );

        Uint8List? capturedAckFrame;
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.send.$bSuffix',
          (ByteData? message) async {
            final args = TransportApi.pigeonChannelCodec
                    .decodeMessage(message)!
                as List<Object?>;
            capturedAckFrame ??= args[1]! as Uint8List;
            return TransportApi.pigeonChannelCodec
                .encodeMessage(<Object?>[true]);
          },
        );

        pushIncomingData(bSuffix, 'device-a', sent.ciphertext);
        await settle();
        await settle();

        expect(capturedAckFrame, isNotNull);
        final frame = RelayPacketFrame.deserialize(capturedAckFrame!);
        expect(frame.destination, 'device-a-resolved');
      },
    );
  });
}
