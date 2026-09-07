// Tests for PrekeyExchange (E06-T07, EARS-COMM-14/15/16, closes
// OQ-E05-T02-1).
//
// Every request/response test drives real control frames through the
// REAL `TransportService`/`TransportEventsApi` Pigeon boundary AND through
// each stack's own `inbound` `InboundPipeline` (the canonical instance
// `MessagingStack.create` builds and registers `PrekeyExchange` onto) --
// mirrors `inbound_pipeline_test.dart`'s own mock-native-side pattern, plus
// a loopback wiring on `TransportApi.send` so an outbound send from one
// stack's suffix actually arrives as `onDataReceived` on the other's,
// simulating two devices that are genuinely reachable (task file §8: "the
// request and response travel as real control frames through T05's
// pipeline", not a fake in-Dart callback).
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/crypto/crypto_failures.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/prekey_bundle_codec.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/prekey_exchange.dart'
    show ConnectionRequestNotice;
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'prekey-exchange-${suffixCounter++}';

  Future<MessagingStack> newStack(String selfDeviceId, String suffix) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    // Each simulated device gets its OWN `DriftSignalProtocolStore` AND its
    // own `CryptoService.withStore(...)` bound to that SAME store --
    // `CryptoService.instance` is a process-wide singleton (correct in
    // production, where `create()` runs exactly once per process, but a
    // real collision the moment a single test process constructs two
    // `MessagingStack`s: whichever stack calls `create()` last would
    // silently rebind the singleton's store out from under the other).
    // Mirrors `messaging_stack_test.dart`'s own `_RemoteParty` pattern and
    // `crypto_stub.dart`'s own documented reason `CryptoService.withStore`
    // exists.
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

  /// Wires [fromSuffix]'s outbound `TransportApi.send` calls directly into
  /// [toSuffix]'s `onDataReceived` event channel, tagged as coming from
  /// [fromDeviceId] -- the loopback pattern `transport_service_test.dart`
  /// already establishes for a single device; here it stands in for two
  /// devices that are actually connected and reachable (this exchange's
  /// whole premise, `OQ-E06-T07-1`). One-directional; call twice (with
  /// suffixes/ids swapped) for a bidirectional link.
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
    // E04-B05: `PrekeyExchange._sendControlFrame` now goes through
    // `_stack.directSend` (connect-then-send), not a raw `transport.send` --
    // mock `[fromSuffix]`'s own `TransportApi.connect` to accept and settle
    // immediately, mirroring `TransportService.connect`'s real two-channel
    // contract (accepted reply + a separate `onConnectionStateChanged`
    // settle event).
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

  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  Future<void> connectPeer(String suffix, String deviceId) async {
    pushDiscovered(suffix, deviceId);
    await settle();
    pushConnectionState(suffix, deviceId, ConnectionState.connected);
    await settle();
  }

  /// Starts both stacks' own `inbound` pipelines, wires a bidirectional
  /// transport loopback between them, and connects each as the other's
  /// peer -- the common setup every request/response test needs.
  Future<void> wireStacks(
    MessagingStack a,
    String aSuffix,
    MessagingStack b,
    String bSuffix,
  ) async {
    a.inbound.start();
    b.inbound.start();
    wireSend(aSuffix, a.selfDeviceId, bSuffix);
    wireSend(bSuffix, b.selfDeviceId, aSuffix);
    await connectPeer(aSuffix, b.selfDeviceId);
    await connectPeer(bSuffix, a.selfDeviceId);
  }

  test('test_EARS_COMM_14_first_message_establishes_a_session', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await wireStacks(a, aSuffix, b, bSuffix);

    const address = SignalProtocolAddress('device-b', 1);
    expect(await a.signalStore.containsSession(address), isFalse);

    await a.prekeyExchange.ensureSession('device-b');

    expect(await a.signalStore.containsSession(address), isTrue);
    expect(a.prekeyExchange.counters.requestsSent, 1);
    expect(a.prekeyExchange.counters.responsesAccepted, 1);
    expect(b.prekeyExchange.counters.requestsServed, 1);

    // The whole point of X3DH's initiator/responder asymmetry (task file
    // §6 risk): the first message from the side that just ran the initial
    // handshake IS a PreKeySignalMessage, not a steady-state SignalMessage
    // -- tested through the real CryptoService seam, not assumed.
    final ciphertext = await a.cryptoService.encrypt(
      address,
      Uint8List.fromList('hello bob'.codeUnits),
    );
    expect(ciphertext, isA<PreKeySignalMessage>());
  });

  test(
    'test_EARS_COMM_14_concurrent_ensure_session_uses_one_bundle',
    () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await wireStacks(a, aSuffix, b, bSuffix);

      final issuableBefore = await b.identityService.replenishOneTimePreKeys();
      // replenishOneTimePreKeys() above is a no-op (pool already full from
      // MessagingStack.create's own bootstrap) -- read the real depth via
      // the store directly, mirroring identity_service.dart's own
      // documented health check.
      final beforeCount =
          await b.signalStore.countIssuableOneTimePreKeys();

      // THE FALSIFICATION TEST: two concurrent calls for the SAME peer.
      // Coalescing must reduce this to exactly one request/one bundle --
      // two would burn two one-time prekeys and race two SessionBuilders
      // (task file §6, L-backend-003's shape).
      await Future.wait(<Future<void>>[
        a.prekeyExchange.ensureSession('device-b'),
        a.prekeyExchange.ensureSession('device-b'),
      ]);

      final afterCount = await b.signalStore.countIssuableOneTimePreKeys();

      expect(a.prekeyExchange.counters.requestsSent, 1);
      expect(b.prekeyExchange.counters.requestsServed, 1);
      expect(beforeCount - afterCount, 1);
      expect(issuableBefore, 0); // sanity: pool was already full, not just replenished
      expect(
        await a.signalStore
            .containsSession(const SignalProtocolAddress('device-b', 1)),
        isTrue,
      );
    },
  );

  test('test_EARS_COMM_15_blocked_peer_gets_no_bundle', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    // B has independently evaluated A as blocked (FR-TRUST-003/005: each
    // side's own stored relationship, never derived from the other side).
    await RelationshipRepository(b.db)
        .upsert('device-a', RelationshipState.blocked);

    await wireStacks(a, aSuffix, b, bSuffix);

    final beforeCount = await b.signalStore.countIssuableOneTimePreKeys();

    await expectLater(
      a.prekeyExchange.ensureSession(
        'device-b',
        timeout: const Duration(milliseconds: 500),
      ),
      throwsA(isA<TimeoutException>()),
    );

    // Silence, not a refusal frame (task file §5) -- B counts the refusal
    // internally but A never learns anything beyond "no reply came",
    // exactly like an unreachable peer, so blocking is not remotely
    // probeable.
    expect(b.prekeyExchange.counters.requestsRefused, 1);
    expect(b.prekeyExchange.counters.requestsServed, 0);
    final afterCount = await b.signalStore.countIssuableOneTimePreKeys();
    expect(afterCount, beforeCount);
    expect(
      await a.signalStore
          .containsSession(const SignalProtocolAddress('device-b', 1)),
      isFalse,
    );
  });

  test(
    'test_EARS_COMM_15_ensure_session_rejects_a_peer_this_side_has_blocked',
    () async {
      // The OTHER half of EARS-COMM-15: the REQUESTING side's own
      // trust check, evaluated locally before any frame is even sent --
      // FR-TRUST-005 is bidirectional, and this side's own block must be
      // just as absolute as the peer's.
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await RelationshipRepository(a.db)
          .upsert('device-b', RelationshipState.blocked);

      await wireStacks(a, aSuffix, b, bSuffix);

      await expectLater(
        a.prekeyExchange.ensureSession('device-b'),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.code,
            'code',
            'messaging.peer_blocked',
          ),
        ),
      );
      expect(a.prekeyExchange.counters.requestsSent, 0);
    },
  );

  test('test_EARS_COMM_16_changed_identity_key_fails_loudly', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    // A already trusts SOME identity key for device-b, from a prior
    // encounter -- simulated by pre-seeding A's trusted-identity store
    // with a freshly generated, deliberately-wrong key before B's real
    // bundle ever arrives.
    const address = SignalProtocolAddress('device-b', 1);
    final impostorIdentityKeyPair = generateIdentityKeyPair();
    await a.signalStore.saveIdentity(
      address,
      impostorIdentityKeyPair.getPublicKey(),
    );

    await wireStacks(a, aSuffix, b, bSuffix);

    await expectLater(
      a.prekeyExchange.ensureSession('device-b'),
      throwsA(
        isA<CryptoDecryptFailure>().having(
          (f) => f.reason,
          'reason',
          CryptoDecryptFailureReason.untrustedIdentity,
        ),
      ),
    );

    // Never silently trusted: no session was written for the real bundle
    // that arrived either.
    expect(await a.signalStore.containsSession(address), isFalse);
  });

  test('test_unsolicited_bundle_response_is_dropped', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await wireStacks(a, aSuffix, b, bSuffix);

    // B answers a bundleRequest A never made (a stale/duplicate/forged
    // response) -- A must drop it, count it, and never establish a
    // session from it. Delivered directly through A's own control seam,
    // mirroring how it would have arrived over the wire.
    final bundle = await b.identityService.getLocalPreKeyBundle();
    await a.prekeyExchange.handleControlFrame(
      _controlResponseFrame(
        from: 'device-b',
        to: 'device-a',
        requestId: 'not-a-real-request-id',
        bundle: bundle,
      ),
    );

    expect(a.prekeyExchange.counters.responsesUnsolicited, greaterThanOrEqualTo(1));
    expect(
      await a.signalStore
          .containsSession(const SignalProtocolAddress('device-b', 1)),
      isFalse,
    );
  });

  test('test_bundle_request_times_out_honestly', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    // A can send (loopback wired one-direction only), but B's replies
    // never arrive back -- simulates a peer that received the request but
    // whose response never made it (or a peer that silently vanished).
    a.inbound.start();
    b.inbound.start();
    wireSend(aSuffix, 'device-a', bSuffix);
    // Deliberately NOT wiring device-b's send back to device-a.
    await connectPeer(aSuffix, 'device-b');
    await connectPeer(bSuffix, 'device-a');

    await expectLater(
      a.prekeyExchange.ensureSession(
        'device-b',
        timeout: const Duration(milliseconds: 300),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(a.prekeyExchange.counters.timeouts, 1);
    expect(
      await a.signalStore
          .containsSession(const SignalProtocolAddress('device-b', 1)),
      isFalse,
    );

    // Does NOT retry forever (task file §4) -- a second explicit call is
    // free to try again; nothing here launches a hidden retry loop for the
    // first call.
  });

  group('E10-T05: PrekeyExchange.connectionRequests', () {
    // Proves the emission side (both evaluation sites) against the real
    // control-frame path -- `connection_request_notification_source_test
    // .dart` proves the filter/de-dup/mapping side against a hand-built
    // stream in isolation, mirroring `call_signaling_test.dart`/
    // `call_notification_source_test.dart`'s own split (E10-T04).

    test(
      'test_EARS_NOTIFY_10_ensure_session_emits_unknown_for_first_contact',
      () async {
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        await wireStacks(a, aSuffix, b, bSuffix);

        final notices = <ConnectionRequestNotice>[];
        final subscription =
            a.prekeyExchange.connectionRequests.listen(notices.add);
        addTearDown(subscription.cancel);

        // A has no stored relationship for device-b -- the ordinary
        // first-contact case, evaluated `unknown`
        // (`evaluate_connection_request_use_case.dart`).
        await a.prekeyExchange.ensureSession('device-b');

        expect(notices, hasLength(1));
        expect(notices.single.peerDeviceId, 'device-b');
        expect(notices.single.state, RelationshipState.unknown);
      },
    );

    test(
      'test_EARS_NOTIFY_11_inbound_bundle_request_emits_blocked_for_a_'
      'blocked_peer',
      () async {
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        // B has independently evaluated A as blocked (mirrors
        // `test_EARS_COMM_15_blocked_peer_gets_no_bundle` above).
        await RelationshipRepository(b.db)
            .upsert('device-a', RelationshipState.blocked);

        await wireStacks(a, aSuffix, b, bSuffix);

        final notices = <ConnectionRequestNotice>[];
        final subscription =
            b.prekeyExchange.connectionRequests.listen(notices.add);
        addTearDown(subscription.cancel);

        await expectLater(
          a.prekeyExchange.ensureSession(
            'device-b',
            timeout: const Duration(milliseconds: 500),
          ),
          throwsA(isA<TimeoutException>()),
        );

        // The stream itself emits for EVERY state -- including `blocked` --
        // so the "never notify a blocked peer" rule is asserted on
        // `ConnectionRequestNotificationSource`, not by silently never
        // producing the event at all (task file §6 risk).
        expect(notices, hasLength(1));
        expect(notices.single.peerDeviceId, 'device-a');
        expect(notices.single.state, RelationshipState.blocked);
      },
    );

    test(
      'connectionRequests is closed by PrekeyExchange.dispose()',
      () async {
        final aSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);

        var closed = false;
        a.prekeyExchange.connectionRequests.listen(
          null,
          onDone: () => closed = true,
        );

        await a.prekeyExchange.dispose();
        await a.dispose();

        expect(closed, isTrue);
      },
    );
  });
}

/// Hand-builds a `bundleResponse` control [RelayPacketFrame] the way
/// `PrekeyExchange._sendControlFrame`/`_ControlBody.response` would, for
/// the one test (`test_unsolicited_bundle_response_is_dropped`) that needs
/// to deliver a response with a `requestId` this device never issued --
/// something no real `PrekeyExchange` call path would ever construct.
RelayPacketFrame _controlResponseFrame({
  required String from,
  required String to,
  required String requestId,
  required PreKeyBundle bundle,
}) {
  final bundleBytes = PreKeyBundleCodec.serialize(bundle);
  final requestIdBytes = Uint8List.fromList(requestId.codeUnits);
  final body = BytesBuilder();
  body.addByte(2); // bundleResponse subType tag
  final requestIdLen = ByteData(4)..setUint32(0, requestIdBytes.length);
  body.add(requestIdLen.buffer.asUint8List());
  body.add(requestIdBytes);
  final bundleLen = ByteData(4)..setUint32(0, bundleBytes.length);
  body.add(bundleLen.buffer.asUint8List());
  body.add(bundleBytes);

  final now = DateTime.now().millisecondsSinceEpoch;
  return RelayPacketFrame(
    payloadType: PayloadType.control,
    packetId: 'pkt-unsolicited-1',
    destination: to,
    source: from,
    priority: 0,
    createdAtMs: now,
    expiresAtMs: now + 60000,
    payload: body.toBytes(),
  );
}
