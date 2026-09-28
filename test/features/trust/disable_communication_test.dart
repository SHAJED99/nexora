// `Q-FUNC-011` (E02-T04, FR-TRUST-006) — "disable communication" refuses
// ONLY a genuinely new connection request; every established conversation
// is completely unaffected.
//
// Human answer, 2026-09-27, verbatim: "'Disable communication' blocks only
// new connection requests. It does not suppress inbound delivery, hide
// existing conversations, alter notifications, or otherwise silence
// established conversations." Both halves are tested here: the refusal
// half (unit-level, against `EvaluateConnectionRequestUseCase` directly)
// and the does-not-touch-existing half, including the two REQUIRED
// real-path tests that drive a genuine `MessagingStack`/`PrekeyExchange`
// end to end -- `#332`/`#336`/`#337` were each a defect an injected-seam
// test alone would have passed.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/data/trust_settings_repository.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  group('unit — EvaluateConnectionRequestUseCase gate', () {
    late AppDatabase db;
    late RelationshipRepository relationships;
    late TrustSettingsRepository trustSettings;
    late EvaluateConnectionRequestUseCase useCase;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      relationships = RelationshipRepository(db);
      trustSettings = TrustSettingsRepository(db: db);
      useCase = EvaluateConnectionRequestUseCase(
        relationships,
        trustSettings: trustSettings,
      );
    });

    tearDown(() => db.close());

    // ── the refusal half ──────────────────────────────────────────────

    test(
      'test_Q_FUNC_011_disabled_refuses_a_device_with_no_relationship_row',
      () async {
        await trustSettings.writeAllowNewConnectionRequests(false);

        final result = await useCase.call('device-never-seen');

        expect(result, RelationshipState.blocked);
      },
    );

    test(
      'test_Q_FUNC_011_disabled_writes_no_relationships_row',
      () async {
        await trustSettings.writeAllowNewConnectionRequests(false);

        await useCase.call('device-never-seen');

        expect(await relationships.get('device-never-seen'), isNull);
      },
    );

    test(
      'test_Q_FUNC_011_enabled_still_returns_unknown_for_a_new_device',
      () async {
        // Default is `true` -- unchanged behaviour for a device with no
        // stored row when the setting has never been touched.
        final result = await useCase.call('device-never-seen');

        expect(result, RelationshipState.unknown);
      },
    );

    test(
      'test_Q_FUNC_011_omitted_repository_leaves_behaviour_unchanged',
      () async {
        // The same optional/nullable shape `_rateLimiter` already uses --
        // omitted, the gate is skipped entirely, byte-for-byte unchanged
        // from before this task.
        final bareUseCase = EvaluateConnectionRequestUseCase(relationships);

        final result = await bareUseCase.call('device-never-seen');

        expect(result, RelationshipState.unknown);
      },
    );

    // ── the does-not-touch-existing half ─────────────────────────────

    test(
      'test_Q_FUNC_011_disabled_still_returns_trusted_for_an_established_peer',
      () async {
        await relationships.upsert('device-a', RelationshipState.trusted);
        await trustSettings.writeAllowNewConnectionRequests(false);

        final result = await useCase.call('device-a');

        expect(result, RelationshipState.trusted);
      },
    );

    test(
      'test_Q_FUNC_011_disabled_still_returns_allowed_for_an_established_peer',
      () async {
        await relationships.upsert('device-a', RelationshipState.allowed);
        await trustSettings.writeAllowNewConnectionRequests(false);

        final result = await useCase.call('device-a');

        expect(result, RelationshipState.allowed);
      },
    );

    test(
      'test_Q_FUNC_011_disabled_still_returns_blocked_for_a_blocked_peer',
      () async {
        await relationships.upsert('device-a', RelationshipState.blocked);
        await trustSettings.writeAllowNewConnectionRequests(false);

        final result = await useCase.call('device-a');

        expect(result, RelationshipState.blocked);
      },
    );
  });

  group('real path — MessagingStack/PrekeyExchange end to end', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    var suffixCounter = 0;
    String nextSuffix() => 'disable-communication-${suffixCounter++}';

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
          final args = TransportApi.pigeonChannelCodec.decodeMessage(message)!
              as List<Object?>;
          final bytes = args[1]! as Uint8List;
          messenger.handlePlatformMessage(
            'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$toSuffix',
            TransportEventsApi.pigeonChannelCodec
                .encodeMessage(<Object?>[fromDeviceId, bytes]),
            (ByteData? _) {},
          );
          return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
        },
      );
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.connect.$fromSuffix',
        (ByteData? message) async {
          final args = TransportApi.pigeonChannelCodec.decodeMessage(message)!
              as List<Object?>;
          final deviceId = args[0]! as String;
          scheduleMicrotask(() {
            messenger.handlePlatformMessage(
              'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$fromSuffix',
              TransportEventsApi.pigeonChannelCodec.encodeMessage(
                <Object?>[deviceId, ConnectionState.connected],
              ),
              (ByteData? _) {},
            );
          });
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
        TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device]),
        (ByteData? _) {},
      );
      await settle();
      messenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
        TransportEventsApi.pigeonChannelCodec
            .encodeMessage(<Object?>[deviceId, ConnectionState.connected]),
        (ByteData? _) {},
      );
      await settle();
    }

    test(
      'test_Q_FUNC_011_real_path_disabled_refuses_first_contact',
      () async {
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        // B has turned off new connection requests -- and has NO stored
        // relationship for A, the genuine first-contact case this setting
        // exists to gate.
        await TrustSettingsRepository(
          db: b.db,
        ).writeAllowNewConnectionRequests(false);

        a.inbound.start();
        b.inbound.start();
        wireSend(aSuffix, a.selfDeviceId, bSuffix);
        wireSend(bSuffix, b.selfDeviceId, aSuffix);
        await connectPeer(aSuffix, b.selfDeviceId);
        await connectPeer(bSuffix, a.selfDeviceId);

        final beforeCount = await b.signalStore.countIssuableOneTimePreKeys();

        await expectLater(
          a.prekeyExchange.ensureSession(
            'device-b',
            timeout: const Duration(milliseconds: 500),
          ),
          throwsA(isA<TimeoutException>()),
        );

        // Refused exactly like a blocked peer (task §2 "Return value when
        // disabled") -- silence, not a refusal frame, no bundle handed out.
        expect(b.prekeyExchange.counters.requestsRefused, 1);
        expect(b.prekeyExchange.counters.requestsServed, 0);
        final afterCount = await b.signalStore.countIssuableOneTimePreKeys();
        expect(afterCount, beforeCount);

        // Never writes a `relationships` row -- turning the setting back
        // on later leaves no persisted false "blocked" verdict (task §2).
        expect(await RelationshipRepository(b.db).get('device-a'), isNull);
      },
    );

    test(
      'test_Q_FUNC_011_real_path_established_peer_still_delivers',
      () async {
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final a = await newStack('device-a', aSuffix);
        final b = await newStack('device-b', bSuffix);
        addTearDown(a.dispose);
        addTearDown(b.dispose);

        // A real, already-established Signal session between A and B --
        // exactly the "existing session" precondition task §5's real-path
        // test names, built directly through the crypto layer (mirrors
        // `messaging_stack_test.dart`'s own `establishMutualSessions`)
        // rather than through a first-contact handshake this test is not
        // about.
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

        // B has ALREADY evaluated A and stored the result -- the
        // established-conversation case this setting must never touch.
        await RelationshipRepository(
          b.db,
        ).upsert('device-a', RelationshipState.trusted);

        // B has ALSO turned off new connection requests -- the whole
        // point of this test: that must make no difference here.
        await TrustSettingsRepository(
          db: b.db,
        ).writeAllowNewConnectionRequests(false);

        // `ReceiveMessageUseCase` (unlike `SendMessageUseCase`, which uses
        // each stack's own injected `cryptoService`) always decrypts
        // through the process-wide `CryptoService.instance` singleton
        // (`messaging_stack.dart`'s own documented reason). This test only
        // needs B's own side of the singleton wired for the one delivery
        // it drives.
        await CryptoService.instance.init(b.signalStore);

        wireSend(aSuffix, a.selfDeviceId, bSuffix);
        b.inbound.start();
        await connectPeer(bSuffix, a.selfDeviceId);
        a.routingEngine.recordLinkMeasurement(
          b.selfDeviceId,
          latencyMs: 10,
          lossRate: 0.0,
          batteryDrain: 0.1,
        );

        final deliveredFuture = b.inbound.delivered.first;

        await a.sendMessage.call(
          'conv-a-b',
          b.selfDeviceId,
          _plaintext('still working'),
        );
        await a.relayEngine.processQueue();
        await settle();
        await settle();

        final delivered = await deliveredFuture;
        expect(delivered.senderDeviceId, 'device-a');

        final rows = await b.db.select(b.db.messages).get();
        expect(rows, hasLength(1));
        expect(rows.single.conversationId, 'conv-a-b');
      },
    );
  });
}
