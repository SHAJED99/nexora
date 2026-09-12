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

import 'package:drift/drift.dart' show Value;
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

  group('E04-B13: outbound addressing resolution', () {
    // These tests deliberately use a Bluetooth-MAC-shaped id (`bMac`/`aMac`)
    // that is DIFFERENT from each stack's own real `selfDeviceId` --
    // `wireStacks`'s own convention above (MAC == selfDeviceId) can never
    // exercise this task's actual fix, since the two would always already
    // match. This mirrors the real-hardware shape E04-B12 confirmed live
    // (`B8:DB:38:7C:D4:BF` vs. `aecdcd6f9b32dc0f`).

    test(
      'test_E04_B13_outbound_control_frame_uses_learned_remoteSelfDeviceId',
      () async {
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b-real-id', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        const bMac = 'AA:BB:CC:DD:EE:01';
        const aMac = 'AA:BB:CC:DD:EE:02';

        a.inbound.start();
        b.inbound.start();
        wireSend(aSuffix, aMac, bSuffix);
        wireSend(bSuffix, bMac, aSuffix);
        await connectPeer(aSuffix, bMac);
        await connectPeer(bSuffix, aMac);

        // A has already learned (via E04-B12's identity-announce -- the
        // announce mechanism itself is `identity_announce_test.dart`'s job,
        // not this file's; simulated directly here as its already-landed
        // effect) that the peer on `bMac` is really `device-b-real-id`.
        await a.db.into(a.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: bMac,
                state: RelationshipState.unknown.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('device-b-real-id'),
              ),
            );

        // Before E04-B13: the outbound bundleRequest's `destination` would
        // be `bMac`, which can never equal B's real `selfDeviceId`
        // (`device-b-real-id`) -- `isForUs` always false on B, this always
        // times out (E04-B12 §2, confirmed live). After E04-B13: the frame
        // resolves to `device-b-real-id`, `isForUs` succeeds on B, and the
        // session establishes for real -- the actual bug, closed.
        await a.prekeyExchange.ensureSession(bMac);

        expect(
          await a.signalStore
              .containsSession(const SignalProtocolAddress('AA:BB:CC:DD:EE:01', 1)),
          isTrue,
        );
        expect(b.prekeyExchange.counters.requestsServed, 1);
        expect(a.prekeyExchange.counters.responsesAccepted, 1);
      },
    );

    test(
      'test_E04_B13_spoofed_remoteSelfDeviceId_cannot_misdirect_a_message',
      () async {
        // §1a's own required falsification: a spoofed/incorrect
        // `remoteSelfDeviceId` must not cause a message to be misdirected
        // to the wrong physical device.
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final cSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b-real-id', bSuffix);
        // An uninvolved third real device -- if a spoofed
        // `remoteSelfDeviceId` could ever redirect physical delivery, THIS
        // is who it would leak the message to.
        final c = await newStack('device-c-real-id', cSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        addTearDown(c.dispose);

        const bMac = 'AA:BB:CC:DD:EE:03';
        const aMac = 'AA:BB:CC:DD:EE:04';

        a.inbound.start();
        b.inbound.start();
        c.inbound.start();
        // A's outbound bytes are wired ONLY to B's suffix -- C is never
        // wired to A at all, so there is no transport-level path by which
        // a frame could ever physically reach C.
        wireSend(aSuffix, aMac, bSuffix);
        wireSend(bSuffix, bMac, aSuffix);
        await connectPeer(aSuffix, bMac);
        await connectPeer(bSuffix, aMac);

        // Attacker/compromised-peer scenario: the relationship row for the
        // Bluetooth address A is physically connected to (`bMac` -- really
        // B) has been spoofed to claim the peer is actually C. This is
        // exactly the unauthenticated-announce hijack E04-B12's own
        // reviewer flagged as the reason a bare reverse lookup would be
        // unsafe (§1a).
        await a.db.into(a.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: bMac,
                state: RelationshipState.unknown.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: Value(c.selfDeviceId),
              ),
            );

        await expectLater(
          a.prekeyExchange.ensureSession(
            bMac,
            timeout: const Duration(milliseconds: 300),
          ),
          throwsA(isA<TimeoutException>()),
        );

        // The falsification: the spoof did NOT redirect the message to C --
        // C never received anything at all (proving the PHYSICAL transport
        // target is governed exclusively by `bMac`, i.e. which
        // `TransportApi.connect`/`.send` call was actually made, never by
        // the spoofed `remoteSelfDeviceId`).
        expect(c.prekeyExchange.counters.requestsServed, 0);
        // Nor did it succeed against B -- B physically received the bytes
        // (same wiring every other test in this file uses) but its own
        // `isForUs` correctly rejects a frame stamped with someone else's
        // real `selfDeviceId`, so B never recognizes it as its own
        // bundleRequest to answer.
        expect(b.prekeyExchange.counters.requestsServed, 0);
        // The ONLY observable effect of the spoof is a safe, honest
        // timeout -- the identical failure mode as an unresolved
        // (never-announced) peer, never a security breach or a message
        // delivered to/decrypted by the wrong device.
        expect(a.prekeyExchange.counters.timeouts, 1);
        expect(
          await a.signalStore
              .containsSession(const SignalProtocolAddress('AA:BB:CC:DD:EE:03', 1)),
          isFalse,
        );
      },
    );

    test(
      'test_E04_B13_pre_announce_race_falls_back_safely_without_crashing',
      () async {
        // Task file §3 point 3: does NOT assume E04-B12's own
        // announce-before-any-application-code ordering is airtight --
        // E04-B12's own review (carried-forward #4) found it is NOT: the
        // announce is `unawaited`, with no barrier. This proves the race is
        // handled SAFELY (an honest `TimeoutException`, never a crash,
        // never a session established against the wrong address) when
        // `ensureSession` is invoked immediately once the connection reaches
        // `connected` -- mirroring `ChatController.send()`'s own real call
        // shape (nothing forces `IdentityAnnounceService.sendAnnounce`,
        // itself `unawaited` from `MessagingStack`'s own
        // `inbound.peerConnected` listener, to land before the caller's own
        // next line runs).
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b-real-id', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        const bMac = 'AA:BB:CC:DD:EE:05';
        const aMac = 'AA:BB:CC:DD:EE:06';

        a.inbound.start();
        b.inbound.start();
        wireSend(aSuffix, aMac, bSuffix);
        wireSend(bSuffix, bMac, aSuffix);

        // `connectPeer` itself needs its own two-phase settle (discovery,
        // THEN connected -- `TransportService`'s per-device connection-state
        // stream is only wired up once the discovery event has actually been
        // processed) -- this part is not what this test is racing. What
        // IS raced: `ensureSession` is called on the very next line after
        // `connectPeer` resolves, with no further settle -- exactly the gap
        // between "connection reached `connected`" and
        // "`IdentityAnnounceService.sendAnnounce`'s own further async hops
        // (connect-then-send) have actually completed" that task file §3
        // point 3 asks to prove is handled safely, not assumed away.
        await connectPeer(aSuffix, bMac);
        await connectPeer(bSuffix, aMac);

        Object? caught;
        try {
          await a.prekeyExchange.ensureSession(
            bMac,
            timeout: const Duration(milliseconds: 300),
          );
        } catch (e) {
          caught = e;
        }

        // Whichever way the real race actually resolves, the result must be
        // ONE of these two safe outcomes -- never a crash, never a session
        // established against the wrong address.
        if (caught == null) {
          // The announce won the race: resolution succeeded first try.
          expect(
            await a.signalStore.containsSession(
              const SignalProtocolAddress('AA:BB:CC:DD:EE:05', 1),
            ),
            isTrue,
          );
        } else {
          // ensureSession lost the race (E04-B12's carried-forward #4: the
          // ordering is not airtight) -- an honest, bounded
          // TimeoutException, exactly today's already-accepted fallback
          // behavior for this one narrow window, never a crash or a hang.
          expect(caught, isA<TimeoutException>());
          expect(
            await a.signalStore.containsSession(
              const SignalProtocolAddress('AA:BB:CC:DD:EE:05', 1),
            ),
            isFalse,
          );
          // And the peer eventually DOES resolve correctly once the
          // announce lands (proving the window is narrow and self-healing,
          // not a permanent failure) -- a second attempt after settling
          // succeeds.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await a.prekeyExchange.ensureSession(bMac);
          expect(
            await a.signalStore.containsSession(
              const SignalProtocolAddress('AA:BB:CC:DD:EE:05', 1),
            ),
            isTrue,
          );
        }
      },
    );
  });

  group('E04-B14: link-bound bundle-response provenance', () {
    test(
      'test_E04_B14_forged_bundle_response_on_wrong_link_is_rejected',
      () async {
        // The falsification this task's own DoD requires: right
        // `requestId` (the real, cryptographically-random one this device
        // actually issued), right CLAIMED `frame.source` (exactly what the
        // pre-existing E04-B13 check alone requires) -- but delivered on a
        // DIFFERENT physical link than the one the real request went out
        // on. Before this task, `_takeMatchingCompleter` had no way to
        // reject this; after it, the link mismatch alone must reject it.
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b-real-id', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        const bMac = 'AA:BB:CC:DD:EE:07'; // the REAL link to B
        const xMac = 'AA:BB:CC:DD:EE:08'; // a different device, also
        // physically connected to A -- the attacker's own link.

        a.inbound.start();
        b.inbound.start();

        // A already learned (E04-B12's identity-announce, simulated
        // directly as its already-landed effect, mirroring E04-B13's own
        // tests above) that the peer on `bMac` is really
        // `device-b-real-id` -- so the ALREADY-EXISTING `frame.source`/
        // `peerDeviceId` check (E04-B13) will PASS for a forged response
        // that correctly claims this identity. This isolates the NEW
        // link-binding check as the only thing standing between the
        // forgery and acceptance.
        await a.db.into(a.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: bMac,
                state: RelationshipState.unknown.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('device-b-real-id'),
              ),
            );

        // A's own outbound sends are captured, not forwarded anywhere --
        // this test needs the REAL, unguessable `requestId` this task's own
        // fix generates, and the only honest way to learn it is to observe
        // the real wire bytes A actually transmits, exactly as a physical
        // peer would receive them (mirrors `wireSend`'s own mock shape,
        // minus the forwarding half).
        String? capturedRequestId;
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.send.$aSuffix',
          (ByteData? message) async {
            final List<Object?> args =
                TransportApi.pigeonChannelCodec.decodeMessage(message)!
                    as List<Object?>;
            final Uint8List bytes = args[1]! as Uint8List;
            capturedRequestId ??= _tryExtractBundleRequestId(bytes);
            return TransportApi.pigeonChannelCodec
                .encodeMessage(<Object?>[true]);
          },
        );
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.connect.$aSuffix',
          (ByteData? message) async {
            final List<Object?> args =
                TransportApi.pigeonChannelCodec.decodeMessage(message)!
                    as List<Object?>;
            final String deviceId = args[0]! as String;
            scheduleMicrotask(() {
              messenger.handlePlatformMessage(
                'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$aSuffix',
                TransportEventsApi.pigeonChannelCodec.encodeMessage(
                  <Object?>[deviceId, ConnectionState.connected],
                )!,
                (ByteData? _) {},
              );
            });
            return TransportApi.pigeonChannelCodec
                .encodeMessage(<Object?>[true]);
          },
        );

        await connectPeer(aSuffix, bMac);
        await connectPeer(aSuffix, xMac);

        final ensureFuture = a.prekeyExchange.ensureSession(
          bMac,
          timeout: const Duration(milliseconds: 500),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(
          capturedRequestId,
          isNotNull,
          reason: 'A must have sent its real bundleRequest by now',
        );

        final PreKeyBundle forgedBundle =
            await b.identityService.getLocalPreKeyBundle();
        final Uint8List forgedBytes = _forgedBundleResponseWireBytes(
          from: 'device-b-real-id',
          to: a.selfDeviceId,
          requestId: capturedRequestId!,
          bundle: forgedBundle,
        );
        messenger.handlePlatformMessage(
          'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$aSuffix',
          TransportEventsApi.pigeonChannelCodec
              .encodeMessage(<Object?>[xMac, forgedBytes]),
          (ByteData? _) {},
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Rejected: no session established from the forged response.
        expect(
          await a.signalStore
              .containsSession(const SignalProtocolAddress(bMac, 1)),
          isFalse,
        );
        expect(a.prekeyExchange.counters.responsesAccepted, 0);
        expect(
          a.prekeyExchange.counters.responsesUnsolicited,
          greaterThanOrEqualTo(1),
        );

        // The real outstanding request is untouched by the forgery -- it
        // still times out honestly rather than silently "succeeding" via
        // the forged path.
        await expectLater(ensureFuture, throwsA(isA<TimeoutException>()));
      },
    );
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

/// E04-B14: parses a real `bundleRequest` control frame's own `requestId`
/// back out of the exact wire bytes `PrekeyExchange._sendControlFrame`
/// actually transmits (`prekey_exchange.dart`'s own header documents this
/// layout) -- the only honest way for a test to learn the real,
/// cryptographically-random `requestId` this task's own fix generates,
/// short of reaching into `PrekeyExchange`'s private state. Returns `null`
/// for any frame that is not a prekey-exchange `bundleRequest` (this
/// device's own identity-announce and any other outbound control traffic
/// sent on the same channel).
String? _tryExtractBundleRequestId(Uint8List wireBytes) {
  final RelayPacketFrame frame;
  try {
    frame = RelayPacketFrame.deserialize(wireBytes);
  } on FormatException {
    return null;
  }
  final Uint8List payload = frame.payload;
  if (payload.length < 6) return null;
  if (payload[0] != 1) return null; // kControlKindPrekeyExchange
  if (payload[1] != 1) return null; // bundleRequest subType tag
  final requestIdLen = ByteData.sublistView(payload).getUint32(2);
  if (payload.length < 6 + requestIdLen) return null;
  return String.fromCharCodes(payload.sublist(6, 6 + requestIdLen));
}

/// E04-B14: hand-builds a `bundleResponse` control frame's REAL wire bytes
/// (including the `kControlKindPrekeyExchange` prefix byte
/// `InboundPipeline._handleBuffer` strips before dispatch) -- unlike
/// [_controlResponseFrame] above (which is delivered by calling
/// `handleControlFrame` directly, bypassing `InboundPipeline` entirely),
/// this is delivered through the REAL `TransportEventsApi.onDataReceived`
/// channel so `InboundPipeline` itself observes the physical
/// `linkDeviceId` it actually arrived on -- exactly what this task's own
/// falsification test needs to exercise.
Uint8List _forgedBundleResponseWireBytes({
  required String from,
  required String to,
  required String requestId,
  required PreKeyBundle bundle,
}) {
  final bundleBytes = PreKeyBundleCodec.serialize(bundle);
  final requestIdBytes = Uint8List.fromList(requestId.codeUnits);
  final body = BytesBuilder();
  body.addByte(1); // kControlKindPrekeyExchange
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
    packetId: 'pkt-forged-1',
    destination: to,
    source: from,
    priority: 0,
    createdAtMs: now,
    expiresAtMs: now + 60000,
    payload: body.toBytes(),
  ).serialize();
}
