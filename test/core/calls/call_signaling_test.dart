// Tests for CallSignaling (E07-T09, EARS-CALL-2/3/4/5).
//
// Two harnesses, mirroring `prekey_exchange_test.dart`/
// `group_membership_service_test.dart`'s own established patterns:
//   - Direct `handleControlFrame(sourceDeviceId, plaintext)` calls against a
//     hand-seeded [CallSignaling], for scenarios where the interesting
//     behaviour is purely local (glare, blocked-peer drop, busy-while-
//     active) -- mirrors `prekey_exchange_test.dart`'s own
//     `test_unsolicited_bundle_response_is_dropped` pattern.
//   - Real two-stack `MessagingStack`s with real Signal sessions for the
//     properties that can only be falsified against a real Double Ratchet
//     session: the authentication claim (EARS-CALL-2's forged-caller-id
//     test) and the byte-containment property (the frame travels as
//     ciphertext, not cleartext).
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/calls/call_session.dart';
import 'package:nexora/core/calls/call_signaling.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/group_control.dart'
    show encodeCiphertextControlBody;
import 'package:nexora/core/messaging/messaging_stack.dart';
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
  String nextSuffix() => 'call-signaling-${suffixCounter++}';

  Future<MessagingStack> newStack(String selfDeviceId, String suffix) async {
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

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  Future<void> connectPeer(String suffix, String deviceId) async {
    pushDiscovered(suffix, deviceId);
    await settle();
    pushConnectionState(suffix, deviceId, ConnectionState.connected);
    await settle();
  }

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

  group('real two-stack signaling (EARS-CALL-2)', () {
    test(
        'test_EARS_CALL_2_invite_accept_reaches_active_on_both_ends',
        () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await wireStacks(a, aSuffix, b, bSuffix);
      await a.prekeyExchange.ensureSession('device-b');

      final session = await a.callSignaling.invite('device-b');
      expect(session.state, CallState.outgoingPending);
      final aStates = <CallState>[];
      session.states.listen(aStates.add);

      // Let the invite frame travel and B's `ringing` ack travel back.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(session.state, CallState.outgoingRinging);

      final calleeSession = b.callSignaling.currentSession;
      expect(calleeSession, isNotNull);
      expect(calleeSession!.state, CallState.incomingRinging);
      expect(calleeSession.peerDeviceId, 'device-a');
      final bStates = <CallState>[];
      calleeSession.states.listen(bStates.add);

      final acceptFailure = await b.callSignaling.accept(calleeSession.callId);
      expect(acceptFailure, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Both ends genuinely reach `active` (EARS-CALL-2), and only THEN
      // does `NullCallMediaTransport` honestly fail the call (EARS-CALL-5,
      // task file §1: "a call that rings, is answered, and then
      // truthfully reports it cannot carry audio").
      expect(aStates, contains(CallState.active));
      expect(bStates, contains(CallState.active));
      expect(aStates.last, CallState.ended);
      expect(bStates.last, CallState.ended);
      expect(session.endReason, CallEndReason.failed);
      expect(calleeSession.endReason, CallEndReason.failed);

      // Both devices are free to place/receive another call.
      expect(a.callSignaling.currentSession, isNull);
      expect(b.callSignaling.currentSession, isNull);
    });

    test(
        'test_EARS_CALL_2_signaling_is_carried_inside_a_pairwise_session',
        () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await wireStacks(a, aSuffix, b, bSuffix);
      await a.prekeyExchange.ensureSession('device-b');

      Uint8List? capturedInviteBytes;
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.send.$aSuffix',
        (ByteData? message) async {
          final List<Object?> args =
              TransportApi.pigeonChannelCodec.decodeMessage(message)!
                  as List<Object?>;
          final Uint8List bytes = args[1]! as Uint8List;
          capturedInviteBytes ??= bytes;
          final ByteData eventMessage = TransportEventsApi.pigeonChannelCodec
              .encodeMessage(<Object?>[a.selfDeviceId, bytes])!;
          messenger.handlePlatformMessage(
            'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$bSuffix',
            eventMessage,
            (ByteData? _) {},
          );
          return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
        },
      );

      final session = await a.callSignaling.invite('device-b');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(capturedInviteBytes, isNotNull);
      final callIdBytes =
          Uint8List.fromList(session.callId.codeUnits);

      bool containsSubsequence(Uint8List haystack, Uint8List needle) {
        if (needle.isEmpty || needle.length > haystack.length) return false;
        for (var i = 0; i <= haystack.length - needle.length; i++) {
          var match = true;
          for (var j = 0; j < needle.length; j++) {
            if (haystack[i + j] != needle[j]) {
              match = false;
              break;
            }
          }
          if (match) return true;
        }
        return false;
      }

      expect(
        containsSubsequence(capturedInviteBytes!, callIdBytes),
        isFalse,
        reason: 'the plaintext callId must never appear on the wire -- only '
            'pairwise-session ciphertext may travel. (The outer '
            'RelayPacketFrame header\'s own `source` field IS the sender\'s '
            'plaintext device id by design -- that field is the '
            'unauthenticated routing claim this task\'s whole point is to '
            'never trust; see this file\'s forged-caller-id test for that '
            'property instead.)',
      );
    });

    test('test_EARS_CALL_2_forged_caller_id_is_discarded', () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      // Real, mutual Signal sessions without going through PrekeyExchange
      // (this test only needs the sessions to exist) -- mirrors
      // `group_membership_service_test.dart`'s own `establishMutualSessions`.
      await a.cryptoService.establishSession(
        SignalProtocolAddress('device-b', 1),
        await b.identityService.getLocalPreKeyBundle(),
      );
      final bootstrap = await a.cryptoService.encrypt(
        SignalProtocolAddress('device-b', 1),
        Uint8List.fromList([0]),
      );
      await b.cryptoService.decrypt(
        SignalProtocolAddress('device-a', 1),
        bootstrap,
      );

      // A frame whose PLAINTEXT claims the sender is 'device-a', but which
      // is encrypted (and therefore, by construction, actually sent)
      // through 'device-b's own session -- exactly the shape E06-B04's
      // finding describes: a claimed sender that is not the session that
      // actually produced the bytes.
      final forged = CallSignalingFrame(
        kind: CallSignalKind.invite,
        callId: 'forged-call',
        fromDeviceId: 'device-a',
        createdAtMs: 1,
      ).serialize();
      final ciphertext = await b.cryptoService.encrypt(
        SignalProtocolAddress('device-a', 1),
        forged,
      );
      final body = encodeCiphertextControlBody(ciphertext);
      final wireFrame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-forged',
        destination: 'device-a',
        source: 'device-b',
        priority: 0,
        createdAtMs: 0,
        expiresAtMs: 999999999999,
        payload: body,
      );

      await a.callSignaling.handleWireFrame(wireFrame);

      expect(a.callSignaling.counters.callUnauthenticated, 1);
      expect(a.callSignaling.currentSession, isNull);
    });
  });

  void mockSendAlwaysSucceeds(String suffix) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
      (ByteData? message) async {
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
  }

  group('local business logic (EARS-CALL-3/4/5, glare)', () {
    late MessagingStack stack;
    late RelationshipRepository relationships;

    setUp(() async {
      final suffix = nextSuffix();
      stack = await newStack('device-a', suffix);
      // `invite()` always attempts a real `transport.send` -- most tests in
      // this group only exercise the RECEIVE side (`handleControlFrame`)
      // and never call `invite()`, so this only matters for the two glare
      // tests below, but is harmless (and correct -- a send with nowhere
      // real to land should still report success at the transport layer)
      // for every test in this group.
      mockSendAlwaysSucceeds(suffix);
      relationships = RelationshipRepository(stack.db);
    });

    tearDown(() => stack.dispose());

    Uint8List frame(CallSignalKind kind, String callId, String fromDeviceId) =>
        CallSignalingFrame(
          kind: kind,
          callId: callId,
          fromDeviceId: fromDeviceId,
          createdAtMs: 1,
        ).serialize();

    test('test_EARS_CALL_4_blocked_peer_invite_is_silently_dropped',
        () async {
      await relationships.upsert('device-blocked', RelationshipState.blocked);
      final signaling = stack.callSignaling;

      await signaling.handleControlFrame(
        'device-blocked',
        frame(CallSignalKind.invite, 'call-x', 'device-blocked'),
      );

      expect(signaling.counters.callInviteFromBlocked, 1);
      expect(signaling.currentSession, isNull);
      // No reply frame at all -- silence, not a decline (task file §2).
    });

    test('test_EARS_CALL_4_second_invite_while_active_gets_busy', () async {
      final signaling = stack.callSignaling;

      await signaling.handleControlFrame(
        'device-x',
        frame(CallSignalKind.invite, 'call-1', 'device-x'),
      );
      expect(signaling.currentSession, isNotNull);
      expect(signaling.currentSession!.state, CallState.incomingRinging);

      await signaling.handleControlFrame(
        'device-y',
        frame(CallSignalKind.invite, 'call-2', 'device-y'),
      );

      expect(signaling.counters.callInviteWhileBusy, 1);
      // The original call is untouched -- never queued, never replaced.
      expect(signaling.currentSession!.callId, 'call-1');
      expect(signaling.currentSession!.peerDeviceId, 'device-x');
    });

    test('test_glare_resolves_deterministically_by_call_id — incoming wins',
        () async {
      final signaling = stack.callSignaling;
      // A real second stack purely as a source of a structurally valid
      // `PreKeyBundle` so `stack.cryptoService.establishSession` has
      // something real to consume -- this test never wires the two stacks'
      // transports together and never needs `device-peer` to actually
      // decrypt anything; it only exercises `CallSignaling`'s own local
      // glare logic via direct `handleControlFrame` calls.
      final peerStack = await newStack('device-peer', nextSuffix());
      addTearDown(peerStack.dispose);
      await stack.cryptoService.establishSession(
        SignalProtocolAddress('device-peer', 1),
        await peerStack.identityService.getLocalPreKeyBundle(),
      );

      final outgoing = await signaling.invite('device-peer');
      // Choose an incoming callId guaranteed lower than the outgoing one
      // (which is minted with a numeric-looking, larger suffix) by
      // prefixing with a character that sorts first.
      final incomingCallId = '!lower-${outgoing.callId}';
      expect(incomingCallId.compareTo(outgoing.callId), lessThan(0));

      await signaling.handleControlFrame(
        'device-peer',
        frame(CallSignalKind.invite, incomingCallId, 'device-peer'),
      );

      // The incoming invite won the glare: our own outgoing attempt is
      // cancelled, and the current session is now the incoming one.
      expect(outgoing.state, CallState.ended);
      expect(outgoing.endReason, CallEndReason.cancelled);
      expect(signaling.currentSession, isNotNull);
      expect(signaling.currentSession!.callId, incomingCallId);
      expect(signaling.currentSession!.state, CallState.incomingRinging);
      expect(signaling.counters.callInviteWhileBusy, 0);
    });

    test('test_glare_resolves_deterministically_by_call_id — outgoing wins',
        () async {
      final signaling = stack.callSignaling;
      final peerStack = await newStack('device-peer', nextSuffix());
      addTearDown(peerStack.dispose);
      await stack.cryptoService.establishSession(
        SignalProtocolAddress('device-peer', 1),
        await peerStack.identityService.getLocalPreKeyBundle(),
      );

      final outgoing = await signaling.invite('device-peer');
      final incomingCallId = '~higher-${outgoing.callId}';
      expect(incomingCallId.compareTo(outgoing.callId), greaterThan(0));

      await signaling.handleControlFrame(
        'device-peer',
        frame(CallSignalKind.invite, incomingCallId, 'device-peer'),
      );

      // Our own outgoing attempt (lower callId) wins: it is untouched, and
      // the incoming invite is refused with busy, never given a session.
      expect(outgoing.state, isNot(CallState.ended));
      expect(signaling.currentSession, same(outgoing));
      expect(signaling.counters.callInviteWhileBusy, 1);
    });

    test('a stray accept for an unknown callId never creates a session',
        () async {
      final signaling = stack.callSignaling;

      await signaling.handleControlFrame(
        'device-x',
        frame(CallSignalKind.accept, 'unknown-call', 'device-x'),
      );

      expect(signaling.currentSession, isNull);
      expect(signaling.counters.callUnauthenticated, 1);
    });

    test('an actor mismatch between the plaintext and the decrypting '
        'session is discarded', () async {
      final signaling = stack.callSignaling;

      await signaling.handleControlFrame(
        'device-real-sender',
        frame(CallSignalKind.invite, 'call-1', 'device-claimed-sender'),
      );

      expect(signaling.currentSession, isNull);
      expect(signaling.counters.callUnauthenticated, 1);
    });
  });
}
