// Tests for InboundPipeline (E06-T05, EARS-COMM-8/9/10).
//
// Every test drives packets through the REAL `TransportService` /
// `TransportEventsApi` Pigeon boundary (mirrors
// `transport_service_test.dart`'s own mock-native-side pattern), not a fake
// stream, since the pipeline's own peer-subscription lifecycle
// (discoveredDevices -> connectionState -> incomingData) is part of what
// this task's Risks (§6) require to be proven, not assumed.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/messaging/inbound_pipeline.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/messaging/domain/message.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);

/// Pushes a simulated `TransportEventsApi.onDeviceDiscovered` event on
/// [suffix]'s channel -- mirrors `transport_service_test.dart`'s own
/// `handlePlatformMessage` pattern for the native-to-Dart event boundary.
void _pushDiscovered(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
) {
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

void _pushConnectionState(
  TestDefaultBinaryMessenger messenger,
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

void _pushIncomingData(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
  Uint8List bytes,
) {
  final ByteData message = TransportEventsApi.pigeonChannelCodec
      .encodeMessage(<Object?>[deviceId, bytes])!;
  messenger.handlePlatformMessage(
    'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$suffix',
    message,
    (ByteData? _) {},
  );
}

/// Lets the microtask/timer chain triggered by a mocked platform message
/// (codec decode -> stream controller `.add` -> this pipeline's own
/// discoveredDevices -> connectionState -> incomingData subscription chain)
/// actually run before the next event is pushed or an assertion is made.
Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 5));
}

/// Connects a peer (discovered + connected) on [suffix]'s channel and lets
/// the pipeline's subscription chain settle before returning.
Future<void> _connectPeer(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
) async {
  _pushDiscovered(messenger, suffix, deviceId);
  await _settle();
  _pushConnectionState(messenger, suffix, deviceId, ConnectionState.connected);
  await _settle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'inbound-pipeline-${suffixCounter++}';

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

  test('test_EARS_COMM_8_addressed_packet_is_delivered', () async {
    final senderSuffix = nextSuffix();
    final receiverSuffix = nextSuffix();
    final sender = await newStack('device-a', senderSuffix);
    final receiver = await newStack('device-b', receiverSuffix);
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);

    // Session established out-of-band, as messaging_stack_test.dart's own
    // pattern does -- MessagingStack itself never calls establishSession.
    await sender.cryptoService.establishSession(
      const SignalProtocolAddress('device-b', 1),
      await receiver.identityService.getLocalPreKeyBundle(),
    );

    final sent = await sender.sendMessage.call(
      'conv-1',
      'device-b',
      _plaintext('hello bob'),
    );

    final pipeline = InboundPipeline(stack: receiver);
    addTearDown(pipeline.stop);
    pipeline.start();

    await _connectPeer(messenger, receiverSuffix, 'device-a');

    final deliveredFuture = pipeline.delivered.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('no message delivered'),
    );
    // `sent.ciphertext` IS the wire frame `_encryptAdapter` produced
    // (messaging_stack_test.dart already proves this) -- exactly what would
    // have arrived over the wire from device-a.
    _pushIncomingData(messenger, receiverSuffix, 'device-a', sent.ciphertext);

    final delivered = await deliveredFuture;
    expect(delivered.conversationId, 'conv-1');
    expect(delivered.senderDeviceId, 'device-a');
    expect(delivered.sequenceNumber, sent.sequenceNumber);

    final rows = await receiver.db.select(receiver.db.messages).get();
    expect(rows, hasLength(1));
    expect(pipeline.counters.delivered, 1);
    expect(pipeline.counters.duplicate, 0);
  });

  test('test_EARS_COMM_8_duplicate_packet_persists_once', () async {
    final senderSuffix = nextSuffix();
    final receiverSuffix = nextSuffix();
    final sender = await newStack('device-a', senderSuffix);
    final receiver = await newStack('device-b', receiverSuffix);
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);

    await sender.cryptoService.establishSession(
      const SignalProtocolAddress('device-b', 1),
      await receiver.identityService.getLocalPreKeyBundle(),
    );
    final sent = await sender.sendMessage.call(
      'conv-1',
      'device-b',
      _plaintext('hi twice'),
    );

    final pipeline = InboundPipeline(stack: receiver);
    addTearDown(pipeline.stop);
    pipeline.start();
    await _connectPeer(messenger, receiverSuffix, 'device-a');

    final delivered = <Message>[];
    final sub = pipeline.delivered.listen(delivered.add);
    addTearDown(sub.cancel);

    _pushIncomingData(messenger, receiverSuffix, 'device-a', sent.ciphertext);
    await _settle();
    _pushIncomingData(messenger, receiverSuffix, 'device-a', sent.ciphertext);
    await _settle();

    final rows = await receiver.db.select(receiver.db.messages).get();
    expect(rows, hasLength(1));
    expect(delivered, hasLength(1));
    expect(pipeline.counters.duplicate, 1);
    expect(pipeline.counters.delivered, 1);
  });

  test('test_EARS_COMM_9_foreign_packet_is_forwarded_unread', () async {
    final suffix = nextSuffix();
    final receiver = await newStack('device-b', suffix);
    addTearDown(receiver.dispose);

    final pipeline = InboundPipeline(stack: receiver);
    addTearDown(pipeline.stop);
    pipeline.start();
    await _connectPeer(messenger, suffix, 'device-a');

    final now = DateTime.now().millisecondsSinceEpoch;
    // Deliberately garbage payload bytes for `signalMessage` -- a 4-byte
    // buffer with a version nibble the library rejects immediately, so if
    // this pipeline's forward branch EVER called `CiphertextCodec.decode` on
    // it, it would throw synchronously (E06-T02's own
    // `unparseable_bytes_as_invalidMessage` fixture uses the same shape).
    // Since the forward branch's only try/catch is scoped to the
    // addressed-to-self branch (see inbound_pipeline.dart), an accidental
    // decode call here would surface as an UNCAUGHT test failure, not a
    // silently-swallowed counter -- this is the FR-ROUTE-003 falsification
    // asset the task file's §6 risk note asks for.
    final garbagePayload = Uint8List.fromList(<int>[0x40, 0x00, 0x00, 0x00]);
    final frame = RelayPacketFrame(
      payloadType: PayloadType.signalMessage,
      packetId: 'pkt-foreign-1',
      destination: 'device-c',
      source: 'device-a',
      priority: 5,
      createdAtMs: now,
      expiresAtMs: now + 60000,
      payload: garbagePayload,
    );
    final wireBytes = frame.serialize();

    _pushIncomingData(messenger, suffix, 'device-a', wireBytes);
    await _settle();
    await _settle();

    final relayRows = await receiver.db.select(receiver.db.relayPackets).get();
    expect(relayRows, hasLength(1));
    expect(relayRows.single.destinationId, 'device-c');
    // Byte-preserving: the ORIGINAL wire bytes, not frame.payload and not a
    // re-serialized frame.
    expect(relayRows.single.payload, wireBytes);

    final messageRows = await receiver.db.select(receiver.db.messages).get();
    expect(messageRows, isEmpty);

    expect(pipeline.counters.forwarded, 1);
    expect(pipeline.counters.delivered, 0);
    expect(pipeline.counters.undecryptable, 0);
  });

  test(
    'test_EARS_COMM_9_expired_foreign_packet_is_dropped_not_forwarded',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('device-b', suffix);
      addTearDown(receiver.dispose);

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, suffix, 'device-a');

      final past = DateTime.now().millisecondsSinceEpoch - 60000;
      final frame = RelayPacketFrame(
        payloadType: PayloadType.signalMessage,
        packetId: 'pkt-expired-1',
        destination: 'device-c',
        source: 'device-a',
        priority: 0,
        createdAtMs: past - 1000,
        expiresAtMs: past,
        payload: Uint8List.fromList(<int>[1, 2, 3]),
      );

      _pushIncomingData(messenger, suffix, 'device-a', frame.serialize());
      await _settle();
      await _settle();

      final relayRows =
          await receiver.db.select(receiver.db.relayPackets).get();
      expect(relayRows, isEmpty);
      expect(pipeline.counters.expired, 1);
      expect(pipeline.counters.forwarded, 0);
    },
  );

  test(
    'test_EARS_COMM_10_malformed_packet_does_not_stop_the_loop',
    () async {
      final senderSuffix = nextSuffix();
      final receiverSuffix = nextSuffix();
      final sender = await newStack('device-a', senderSuffix);
      final receiver = await newStack('device-b', receiverSuffix);
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);

      await sender.cryptoService.establishSession(
        const SignalProtocolAddress('device-b', 1),
        await receiver.identityService.getLocalPreKeyBundle(),
      );
      final sent = await sender.sendMessage.call(
        'conv-1',
        'device-b',
        _plaintext('after garbage'),
      );

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, receiverSuffix, 'device-a');

      final deliveredFuture = pipeline.delivered.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('good packet never delivered'),
      );

      // A bad buffer FIRST -- not a valid frame at all (empty).
      _pushIncomingData(
        messenger,
        receiverSuffix,
        'device-a',
        Uint8List(0),
      );
      await _settle();
      // The good packet SECOND -- the loop must still be alive.
      _pushIncomingData(
        messenger,
        receiverSuffix,
        'device-a',
        sent.ciphertext,
      );

      await deliveredFuture;
      expect(pipeline.counters.malformed, 1);
      expect(pipeline.counters.delivered, 1);
    },
  );

  test('test_EARS_COMM_10_undecryptable_packet_is_dropped_typed', () async {
    final suffix = nextSuffix();
    final receiver = await newStack('device-b', suffix);
    addTearDown(receiver.dispose);

    final pipeline = InboundPipeline(stack: receiver);
    addTearDown(pipeline.stop);
    pipeline.start();
    await _connectPeer(messenger, suffix, 'device-a');

    final now = DateTime.now().millisecondsSinceEpoch;
    // Addressed to device-b (self), but no session exists with device-a at
    // all -- `CiphertextCodec.decode` throws on this unparseable buffer
    // before `decrypt` is even reached (mirrors E06-T02's own
    // ciphertext_codec_test.dart fixture: version nibble 4 > library's
    // currentVersion 3).
    final frame = RelayPacketFrame(
      payloadType: PayloadType.signalMessage,
      packetId: 'pkt-undecryptable-1',
      destination: 'device-b',
      source: 'device-a',
      priority: 0,
      createdAtMs: now,
      expiresAtMs: now + 60000,
      payload: Uint8List.fromList(<int>[0x40, 0, 0, 0, 0, 0, 0, 0, 0]),
    );

    _pushIncomingData(messenger, suffix, 'device-a', frame.serialize());
    await _settle();
    await _settle();

    final messageRows = await receiver.db.select(receiver.db.messages).get();
    expect(messageRows, isEmpty);
    expect(pipeline.counters.undecryptable, 1);
    expect(pipeline.counters.delivered, 0);
  });

  test(
    'test_control_frame_without_a_handler_is_counted_not_guessed',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('device-b', suffix);
      addTearDown(receiver.dispose);

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, suffix, 'device-a');

      final now = DateTime.now().millisecondsSinceEpoch;
      final frame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-control-1',
        destination: 'device-b',
        source: 'device-a',
        priority: 0,
        createdAtMs: now,
        expiresAtMs: now + 60000,
        payload: Uint8List.fromList(<int>[9, 9, 9]),
      );

      _pushIncomingData(messenger, suffix, 'device-a', frame.serialize());
      await _settle();
      await _settle();

      final messageRows = await receiver.db.select(receiver.db.messages).get();
      expect(messageRows, isEmpty);
      expect(pipeline.counters.unhandledControl, 1);
      expect(pipeline.counters.delivered, 0);
    },
  );

  test('test_start_is_idempotent', () async {
    final senderSuffix = nextSuffix();
    final receiverSuffix = nextSuffix();
    final sender = await newStack('device-a', senderSuffix);
    final receiver = await newStack('device-b', receiverSuffix);
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);

    await sender.cryptoService.establishSession(
      const SignalProtocolAddress('device-b', 1),
      await receiver.identityService.getLocalPreKeyBundle(),
    );
    final sent = await sender.sendMessage.call(
      'conv-1',
      'device-b',
      _plaintext('idempotent'),
    );

    final pipeline = InboundPipeline(stack: receiver);
    addTearDown(pipeline.stop);
    pipeline.start();
    pipeline.start(); // second call -- must be a no-op

    await _connectPeer(messenger, receiverSuffix, 'device-a');

    final deliveredFuture = pipeline.delivered.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('never delivered'),
    );
    _pushIncomingData(
      messenger,
      receiverSuffix,
      'device-a',
      sent.ciphertext,
    );
    await deliveredFuture;

    // A double subscription would deliver the SAME packet twice: the first
    // delivery succeeds, the second is caught by dedup as a duplicate. Both
    // counters together prove there was only ever one attempt.
    await _settle();
    expect(pipeline.counters.delivered, 1);
    expect(pipeline.counters.duplicate, 0);
  });

  test('test_peer_connected_after_start_is_subscribed', () async {
    final senderSuffix = nextSuffix();
    final receiverSuffix = nextSuffix();
    final sender = await newStack('device-a', senderSuffix);
    final receiver = await newStack('device-b', receiverSuffix);
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);

    final pipeline = InboundPipeline(stack: receiver);
    addTearDown(pipeline.stop);

    // start() called BEFORE any peer is known at all -- the lifecycle case
    // that silently loses messages if the pipeline only snapshots
    // already-connected peers at start() time (task file §6 risk).
    pipeline.start();

    await sender.cryptoService.establishSession(
      const SignalProtocolAddress('device-b', 1),
      await receiver.identityService.getLocalPreKeyBundle(),
    );
    final sent = await sender.sendMessage.call(
      'conv-1',
      'device-b',
      _plaintext('late peer'),
    );

    // The peer connects only NOW, well after start().
    await _connectPeer(messenger, receiverSuffix, 'device-a');

    final deliveredFuture = pipeline.delivered.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('late-connecting peer never subscribed'),
    );
    _pushIncomingData(
      messenger,
      receiverSuffix,
      'device-a',
      sent.ciphertext,
    );

    final delivered = await deliveredFuture;
    expect(delivered.senderDeviceId, 'device-a');
    expect(pipeline.counters.delivered, 1);
  });

  group('E04-B07 — an accepted connection from an already-known peer is '
      'not dropped just because this process never discovered it', () {
    test(
      'test_E04_B07_trusted_peer_connected_with_no_prior_discovery_still_delivers',
      () async {
        final senderSuffix = nextSuffix();
        final receiverSuffix = nextSuffix();
        final sender = await newStack('device-a', senderSuffix);
        final receiver = await newStack('device-b', receiverSuffix);
        addTearDown(sender.dispose);
        addTearDown(receiver.dispose);

        await sender.cryptoService.establishSession(
          const SignalProtocolAddress('device-b', 1),
          await receiver.identityService.getLocalPreKeyBundle(),
        );
        final sent = await sender.sendMessage.call(
          'conv-1',
          'device-b',
          _plaintext('hello via an accepted, not dialled, connection'),
        );

        // The receiver already trusts device-a -- e.g. from a previous
        // process run -- but THIS run never calls _pushDiscovered for it.
        // This is exactly E04-B06's own accept-loop scenario: the OTHER
        // device dialled in, this device never ran a discovery scan that
        // found it.
        await RelationshipRepository(
          receiver.db,
        ).upsert('device-a', RelationshipState.trusted);

        final pipeline = InboundPipeline(stack: receiver);
        addTearDown(pipeline.stop);
        pipeline.start();
        // _seedKnownDevices() is fire-and-forget from start() -- let its
        // own async DB read complete before the connection event fires.
        await _settle();

        // Simulate an ACCEPTED connection: onConnectionStateChanged fires
        // directly, with no onDeviceDiscovered for this device id at all
        // in this process run.
        _pushConnectionState(
          messenger,
          receiverSuffix,
          'device-a',
          ConnectionState.connected,
        );
        await _settle();

        final deliveredFuture = pipeline.delivered.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError(
            'E04-B07 regression: an accepted connection from an '
            'already-trusted, non-freshly-discovered peer was silently '
            'dropped',
          ),
        );
        _pushIncomingData(
          messenger,
          receiverSuffix,
          'device-a',
          sent.ciphertext,
        );

        final delivered = await deliveredFuture;
        expect(delivered.senderDeviceId, 'device-a');
        expect(pipeline.counters.delivered, 1);
      },
    );

    test(
      'test_E04_B07_unknown_peer_is_not_seeded_-- still requires a real '
      'discovery event',
      () async {
        final receiver = await newStack('device-b', nextSuffix());
        addTearDown(receiver.dispose);

        // No relationship row at all for device-a -- an `unknown` peer
        // must still go through the existing discovery-triggered path,
        // not be silently pre-subscribed by _seedKnownDevices.
        final pipeline = InboundPipeline(stack: receiver);
        addTearDown(pipeline.stop);
        pipeline.start();
        await _settle();

        expect(
          pipeline.debugConnectionSubscriptionCountForTest,
          0,
          reason:
              'an unknown/never-related device must not get a seeded '
              'connectionState subscription',
        );
      },
    );
  });
}
