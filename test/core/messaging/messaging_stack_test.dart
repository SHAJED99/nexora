// Tests for MessagingStack (E06-T03, EARS-COMM-6/7).
//
// This is the first place `SendMessageUseCase`/`ReceiveMessageUseCase`/
// `SyncCursorService`/`RelayEngine`/`RoutingEngine` are ever constructed
// outside their own epics' test suites -- so, per the task file's own §6
// risk note, this suite exists to prove the composition itself, not to
// re-prove behaviour those epics' own suites already cover.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/messaging/ciphertext_codec.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/receive_message_use_case.dart';
import 'package:nexora/features/messaging/domain/send_message_use_case.dart';
import 'package:nexora/features/messaging/domain/sync_cursor_service.dart';

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
}

/// Small local helper so the decrypted-plaintext assertion above reads as a
/// string without pulling in `dart:convert`'s `utf8` name into this file's
/// broader namespace (kept file-local, single use).
String utf8Decode(Uint8List bytes) => String.fromCharCodes(bytes);
