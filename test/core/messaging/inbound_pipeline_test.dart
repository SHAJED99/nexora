// Tests for InboundPipeline (E06-T05, EARS-COMM-8/9/10).
//
// Every test drives packets through the REAL `TransportService` /
// `TransportEventsApi` Pigeon boundary (mirrors
// `transport_service_test.dart`'s own mock-native-side pattern), not a fake
// stream, since the pipeline's own peer-subscription lifecycle
// (discoveredDevices -> connectionState -> incomingData) is part of what
// this task's Risks (§6) require to be proven, not assumed.
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
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
  String deviceId, {
  String? displayName,
  bool bonded = false,
}) {
  final device = TransportDevice(
    id: deviceId,
    displayName: displayName ?? deviceId,
    type: TransportType.bluetooth,
    bonded: bonded,
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

    test(
      'test_E04_B07_stop_racing_ahead_of_the_seed_leaves_no_subscription_behind',
      () async {
        final receiver = await newStack('device-b', nextSuffix());
        addTearDown(receiver.dispose);
        await RelationshipRepository(
          receiver.db,
        ).upsert('device-a', RelationshipState.trusted);

        final pipeline = InboundPipeline(stack: receiver);
        pipeline.start();
        // `stop()` races ahead of `_seedKnownDevices()`'s own
        // `await listAll()` -- no intervening await between `start()` and
        // `stop()`, so `_started` flips to `false` before that DB read has
        // a real chance to resolve (review finding, E04-B07: without the
        // `if (!_started) return;` guard, the seed would repopulate
        // `_connectionSubscriptions` on an already-stopped pipeline once
        // the DB read finally completed).
        await pipeline.stop();
        // Give the DB read (and, absent the guard, the seed loop) a real
        // chance to run before asserting.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          pipeline.debugConnectionSubscriptionCountForTest,
          0,
          reason: 'a seed that resolves AFTER stop() must not repopulate '
              '_connectionSubscriptions on an already-stopped pipeline',
        );
      },
    );
  });

  group('E04-B17 — _reconcileStaleRelationship', () {
    test(
      'test_E04_B17_reconciles_a_bonded_peer_name_match_to_a_stale_relationship',
      () async {
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        // A relationship this device already trusted, under an address
        // that has since drifted (the exact real-world shape this task's
        // own root-causing found).
        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'stale-address',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                peerName: const Value('Bob Phone'),
              ),
            );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();

        _pushDiscovered(
          messenger,
          suffix,
          'fresh-address',
          displayName: 'Bob Phone',
          bonded: true,
        );
        await _settle();

        final reconciled = await (stack.db.select(stack.db.relationships)
              ..where((t) => t.deviceId.equals('fresh-address')))
            .getSingleOrNull();
        expect(
          reconciled,
          isNotNull,
          reason: 'a bonded peer whose name matches exactly one existing '
              'relationship must inherit that relationship\'s trust state',
        );
        expect(reconciled!.state, RelationshipState.allowed.name);
        expect(reconciled.peerName, 'Bob Phone');
      },
    );

    test(
      'test_E04_B17_does_NOT_reconcile_an_unbonded_device_even_with_a_name_match',
      () async {
        // Review round 1, F1/F2: this is the exact adversarial scenario the
        // review found -- an unbonded device (a passing stranger during an
        // ordinary discovery scan, or an attacker broadcasting a spoofed
        // name) must never inherit another peer's already-evaluated trust,
        // no matter how exact the name match is.
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'alices-real-address',
                state: RelationshipState.trusted.name,
                updatedAt: DateTime.now(),
                peerName: const Value("Alice's Pixel"),
              ),
            );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();

        _pushDiscovered(
          messenger,
          suffix,
          'imposter-address',
          displayName: "Alice's Pixel", // exact name match, NOT bonded.
          bonded: false,
        );
        await _settle();

        final imposterRow = await (stack.db.select(stack.db.relationships)
              ..where((t) => t.deviceId.equals('imposter-address')))
            .getSingleOrNull();
        expect(
          imposterRow,
          isNull,
          reason: 'an unbonded device must never inherit a trust decision '
              'from a name match alone -- a Bluetooth name is '
              'attacker-settable and is not an authentication factor',
        );
      },
    );

    test(
      'test_E04_B17_does_NOT_reconcile_an_ambiguous_name_match',
      () async {
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        // Two different, already-known peers happen to share a
        // Bluetooth-visible name.
        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'first-address',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                peerName: const Value('Shared Name'),
              ),
            );
        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'second-address',
                state: RelationshipState.trusted.name,
                updatedAt: DateTime.now(),
                peerName: const Value('Shared Name'),
              ),
            );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();

        _pushDiscovered(
          messenger,
          suffix,
          'third-address',
          displayName: 'Shared Name',
          bonded: true,
        );
        await _settle();

        final ambiguousRow = await (stack.db.select(stack.db.relationships)
              ..where((t) => t.deviceId.equals('third-address')))
            .getSingleOrNull();
        expect(
          ambiguousRow,
          isNull,
          reason: 'an ambiguous name match (two existing peers share it) '
              'must be left as a new, unknown contact rather than guessed at',
        );
      },
    );

    test(
      'test_E04_B17_does_NOT_reconcile_when_no_relationship_name_matches',
      () async {
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'unrelated-address',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                peerName: const Value('Someone Else'),
              ),
            );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();

        _pushDiscovered(
          messenger,
          suffix,
          'genuinely-new-address',
          displayName: 'Nobody Recognizes This Name',
          bonded: true,
        );
        await _settle();

        final newRow = await (stack.db.select(stack.db.relationships)
              ..where((t) => t.deviceId.equals('genuinely-new-address')))
            .getSingleOrNull();
        expect(
          newRow,
          isNull,
          reason: 'a genuinely new peer with no matching stored name must '
              'not gain a relationship row from this method at all -- that '
              'is the normal discovery/trust flow\'s job, not '
              'reconciliation\'s',
        );
      },
    );

    test(
      'test_E04_B17_does_NOT_reconcile_a_device_that_already_has_its_own_relationship',
      () async {
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'already-known-address',
                state: RelationshipState.blocked.name,
                updatedAt: DateTime.now(),
                peerName: const Value('Original Name'),
              ),
            );
        // Review round 2 (N3): a second, real row whose peerName matches the
        // NEW display name -- so the guard is genuinely exercised (without
        // it, this device id would otherwise be a live reconciliation
        // candidate against this row), not just vacuously true because
        // nothing else happens to match.
        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'someone-elses-address',
                state: RelationshipState.trusted.name,
                updatedAt: DateTime.now(),
                peerName: const Value('A Different Name Now'),
              ),
            );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();

        // A discovery result for a device id that ALREADY has its own row
        // must never have that row's state overwritten via reconciliation,
        // even if the reported name now differs (e.g. the user renamed
        // their phone) and even if some OTHER row would otherwise match.
        _pushDiscovered(
          messenger,
          suffix,
          'already-known-address',
          displayName: 'A Different Name Now',
          bonded: true,
        );
        await _settle();

        final unchanged = await (stack.db.select(stack.db.relationships)
              ..where((t) => t.deviceId.equals('already-known-address')))
            .getSingleOrNull();
        expect(unchanged!.state, RelationshipState.blocked.name);
        expect(unchanged.peerName, 'Original Name');
      },
    );

    test(
      'test_E04_B17_does_NOT_reconcile_on_an_empty_peer_name',
      () async {
        // Review round 2 (N1): unlike NULL, an empty string is a valid SQL
        // equality correlator, so a stored empty-`peerName` row and an
        // incoming device that also reports an empty name would otherwise
        // "match exactly" -- reachable in practice since native falls back
        // to the raw address only when the name is genuinely absent
        // (Kotlin's `?:`), not when it is an empty string.
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'stale-empty-name-address',
                state: RelationshipState.trusted.name,
                updatedAt: DateTime.now(),
                peerName: const Value(''),
              ),
            );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();

        _pushDiscovered(
          messenger,
          suffix,
          'fresh-empty-name-address',
          displayName: '',
          bonded: true,
        );
        await _settle();

        final row = await (stack.db.select(stack.db.relationships)
              ..where((t) => t.deviceId.equals('fresh-empty-name-address')))
            .getSingleOrNull();
        expect(
          row,
          isNull,
          reason: 'an empty peer name must never be treated as a valid '
              'correlator for trust inheritance',
        );
      },
    );
  });

  group('E04-B24 — _reconcileOrphanedMessagesByIdentity', () {
    Future<void> insertMessage(
      MessagingStack stack, {
      required String id,
      required String conversationId,
      required String senderDeviceId,
    }) {
      return stack.db.into(stack.db.messages).insert(
            MessagesCompanion.insert(
              id: id,
              conversationId: conversationId,
              senderDeviceId: senderDeviceId,
              sequenceNumber: 0,
              ciphertext: Uint8List.fromList([1, 2, 3]),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              deliveryState: 'accepted',
            ),
          );
    }

    test(
      'test_E04_B24_orphaned_conversation_migrates_to_the_known_peer_it_matches',
      () async {
        // The exact real-world shape found live, 2026-09-14: a peer this
        // device already trusts under its REAL address ('real-address')
        // also has messages sitting under a DIFFERENT, orphaned id
        // ('orphaned-address', no relationship row of its own at all) --
        // e.g. from a since-fixed accept-path mis-resolution. Both
        // messages' senderDeviceId carry the SAME cryptographic identity,
        // which is also this peer's already-known `remoteSelfDeviceId`.
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'real-address',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('peer-identity-hash'),
              ),
            );
        await insertMessage(
          stack,
          id: 'm1',
          conversationId: 'orphaned-address',
          senderDeviceId: 'peer-identity-hash',
        );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();
        await _settle();

        final row = await (stack.db.select(stack.db.messages)
              ..where((t) => t.id.equals('m1')))
            .getSingle();
        expect(
          row.conversationId,
          'real-address',
          reason: 'a message whose sender is already a known peer under a '
              'DIFFERENT id must migrate to that peer\'s real conversation',
        );
      },
    );

    test(
      'test_E04_B24_does_NOT_migrate_when_the_orphan_already_has_a_relationship',
      () async {
        // An ordinary, correctly-resolved conversation (has its own
        // relationship row) must never be touched, even if some other
        // known relationship happens to share a sender id (shouldn't be
        // possible in practice, but the guard is the relationship-row
        // check itself, not identity uniqueness).
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'not-orphaned-address',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('peer-identity-hash'),
              ),
            );
        await insertMessage(
          stack,
          id: 'm1',
          conversationId: 'not-orphaned-address',
          senderDeviceId: 'peer-identity-hash',
        );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();
        await _settle();

        final row = await (stack.db.select(stack.db.messages)
              ..where((t) => t.id.equals('m1')))
            .getSingle();
        expect(row.conversationId, 'not-orphaned-address');
      },
    );

    test(
      'test_E04_B24_does_NOT_migrate_when_no_known_relationship_matches',
      () async {
        // A genuinely new/unknown sender's orphaned messages must be left
        // alone -- this is not the reconciliation's job to invent a new
        // relationship, only to correct the key for an ALREADY-trusted one.
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await insertMessage(
          stack,
          id: 'm1',
          conversationId: 'orphaned-address',
          senderDeviceId: 'nobody-we-know',
        );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();
        await _settle();

        final row = await (stack.db.select(stack.db.messages)
              ..where((t) => t.id.equals('m1')))
            .getSingle();
        expect(row.conversationId, 'orphaned-address');
      },
    );

    test(
      'test_E04_B24_does_NOT_migrate_on_ambiguous_sender_identity',
      () async {
        // Two DIFFERENT senders' messages both sitting under the same
        // orphaned id -- can't safely say which one it "really" belongs
        // to, so leave it alone rather than guess.
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'real-address-a',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('identity-a'),
              ),
            );
        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'real-address-b',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('identity-b'),
              ),
            );
        await insertMessage(
          stack,
          id: 'm1',
          conversationId: 'orphaned-address',
          senderDeviceId: 'identity-a',
        );
        await insertMessage(
          stack,
          id: 'm2',
          conversationId: 'orphaned-address',
          senderDeviceId: 'identity-b',
        );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();
        await _settle();

        final rows = await (stack.db.select(stack.db.messages)
              ..where((t) => t.conversationId.equals('orphaned-address')))
            .get();
        expect(rows, hasLength(2), reason: 'ambiguous sender -> left alone');
      },
    );

    test(
      'test_E04_B24_does_NOT_migrate_a_group_conversation_id',
      () async {
        // A group's own id lives in a completely different id space
        // (`groups.id`, not a Bluetooth address/relationship device_id) --
        // must never be treated as an orphaned 1:1 conversation, even if
        // (implausibly) its id string happened to equal some peer's
        // identity hash.
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.groups).insertOnConflictUpdate(
              GroupsCompanion.insert(
                id: 'a-group-id',
                name: 'Test Group',
                createdAt: DateTime.now().millisecondsSinceEpoch,
                createdByDeviceId: 'self-device',
              ),
            );
        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'real-address',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('peer-identity-hash'),
              ),
            );
        await insertMessage(
          stack,
          id: 'm1',
          conversationId: 'a-group-id',
          senderDeviceId: 'peer-identity-hash',
        );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();
        await _settle();

        final row = await (stack.db.select(stack.db.messages)
              ..where((t) => t.id.equals('m1')))
            .getSingle();
        expect(row.conversationId, 'a-group-id');
      },
    );

    test(
      'test_E04_B24_never_treats_this_devices_own_sent_messages_as_the_signal',
      () async {
        // A message THIS device sent (senderDeviceId == its own
        // selfDeviceId) must never be used as the reconciliation signal --
        // it says nothing about who the conversation's remote peer is.
        final suffix = nextSuffix();
        final stack = await newStack('self-device', suffix);
        addTearDown(stack.dispose);

        await stack.db.into(stack.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: 'real-address',
                state: RelationshipState.allowed.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('self-device'),
              ),
            );
        await insertMessage(
          stack,
          id: 'm1',
          conversationId: 'orphaned-address',
          senderDeviceId: 'self-device', // this device's OWN id.
        );

        final pipeline = InboundPipeline(stack: stack);
        addTearDown(pipeline.stop);
        pipeline.start();
        await _settle();

        final row = await (stack.db.select(stack.db.messages)
              ..where((t) => t.id.equals('m1')))
            .getSingle();
        expect(
          row.conversationId,
          'orphaned-address',
          reason: 'a self-sent message must never drive reconciliation, '
              'even if some relationship happens to share this device\'s '
              'own id as its remoteSelfDeviceId (a malformed/adversarial '
              'row, not a real case, but must still fail closed)',
        );
      },
    );
  });
}
