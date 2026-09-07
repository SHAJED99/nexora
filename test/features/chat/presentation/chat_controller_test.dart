// features/chat/presentation — ChatController (E06-T11, "the wedge").
//
// EARS-COMM-1/23/24/25 plus the hard confidentiality contract (task §2/§9):
// decrypted plaintext lives ONLY in this controller's ephemeral view-model,
// never persisted, logged, or written back.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Value;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/prekey_exchange.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/storage_access_recorder.dart';
import 'package:nexora/core/storage/storage_item.dart' show StorageItemKind;
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/chat/presentation/chat_controller.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message_envelope.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// A simulated remote party — mirrors
/// `conversations_controller_test.dart`'s own `_RemoteParty` pattern:
/// its own database, store, and `CryptoService` bound to it, so a REAL
/// X3DH handshake + encrypt can happen without going through
/// `InboundPipeline`/`ReceiveMessageUseCase`'s process-wide singleton gap
/// (see this file's notes above).
class _RemoteParty {
  _RemoteParty._(this.db, this.crypto);

  final AppDatabase db;
  final CryptoService crypto;

  static Future<_RemoteParty> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftSignalProtocolStore(db);
    final identity = IdentityService(db, store);
    await identity.ensureLocalIdentity();
    await identity.ensureSignedPreKey();
    await identity.replenishOneTimePreKeys();
    return _RemoteParty._(db, CryptoService.withStore(store));
  }

  Future<void> close() => db.close();
}

Future<void> _insertMessage(
  AppDatabase db, {
  required String id,
  required String conversationId,
  required String senderDeviceId,
  required int sequenceNumber,
  required Uint8List ciphertext,
  required int createdAt,
  DeliveryState state = DeliveryState.accepted,
}) async {
  await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: conversationId,
          senderDeviceId: senderDeviceId,
          sequenceNumber: sequenceNumber,
          ciphertext: ciphertext,
          createdAt: createdAt,
          deliveryState: state.name,
        ),
      );
}

/// Same falsification helper `conversations_controller_test.dart` already
/// established — scans every table/column, not just the one the
/// implementation happens to touch.
Future<bool> _markerPresentAnywhere(AppDatabase db, String marker) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  for (final tableRow in tables) {
    final tableName = tableRow.data['name'] as String;
    final columns =
        await db.customSelect('PRAGMA table_info($tableName)').get();
    for (final columnRow in columns) {
      final columnName = columnRow.data['name'] as String;
      final hit = await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM $tableName '
            "WHERE CAST(`$columnName` AS TEXT) LIKE '%' || ? || '%'",
            variables: [Variable<String>(marker)],
          )
          .getSingle();
      if ((hit.data['c'] as int) > 0) return true;
    }
  }
  return false;
}

/// Delays [ensureSession] by [_delay] before delegating to [_real] (the
/// stack's own, properly-registered `PrekeyExchange` instance) — used ONLY
/// by `test_EARS_COMM_23_queued_bubble_renders_before_ensureSession_resolves`
/// below to make the `ensureSession` round trip (task §6 Risks: "can block
/// for seconds") observably slow without faking the handshake itself. The
/// super constructor's `stack`/`evaluateConnectionRequest` are never used by
/// the overridden method below — they exist only to satisfy `PrekeyExchange`'s
/// own required constructor parameters, since a second instance cannot
/// receive the peer's bundle response (only the ORIGINAL, registered
/// instance's `handleControlFrame` is wired to `stack.inbound`) and must not
/// attempt the handshake itself.
class _SlowPrekeyExchange extends PrekeyExchange {
  _SlowPrekeyExchange({
    required super.stack,
    required super.evaluateConnectionRequest,
    required PrekeyExchange real,
    required Duration delay,
  })  : _real = real, // ignore: prefer_initializing_formals
        _delay = delay; // ignore: prefer_initializing_formals

  final PrekeyExchange _real;
  final Duration _delay;

  @override
  Future<void> ensureSession(
    String peerDeviceId, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await Future<void>.delayed(_delay);
    return _real.ensureSession(peerDeviceId, timeout: timeout);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;
  String nextSuffix() => 'chat-controller-${suffixCounter++}';

  Future<MessagingStack> newStack(String selfDeviceId, String suffix) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftSignalProtocolStore(db);
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: selfDeviceId,
      store: store,
      cryptoService: CryptoService.withStore(store),
      transport: TransportService(binaryMessenger: messenger, messageChannelSuffix: suffix),
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
    // E04-B05: `PrekeyExchange`/`SendMessageUseCase`'s send paths now go
    // through `_stack.directSend`/`RelayEngine`'s own `ConnectionEnsuringSender`
    // (both connect-then-send) -- mock `[fromSuffix]`'s own `TransportApi.connect`
    // to accept and settle immediately, mirroring `TransportService.connect`'s
    // real two-channel contract.
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
            )!,
            (ByteData? _) {},
          );
        });
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

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

  /// Full two-device wiring (mirrors `prekey_exchange_test.dart`'s
  /// `wireStacks`) — needed because [ChatController.send] drives the REAL
  /// stack end to end: `ensureSession` -> `SendMessageUseCase` -> the
  /// coordinator's own forwarding, once `coordinator.start()` is called.
  Future<void> wireStacks(
    MessagingStack a,
    String aSuffix,
    MessagingStack b,
    String bSuffix,
  ) async {
    // Both sides' `inbound` must be running for `PrekeyExchange`'s
    // request/response round trip to work (EARS-COMM-23's `ensureSession`
    // path) — but note that this deliberately does NOT record any
    // `RoutingEngine` link and no test in this file calls
    // `coordinator.tick()`: doing so would forward an actual chat message
    // to `b`, whose `InboundPipeline` would then hit the pre-existing
    // `ReceiveMessageUseCase`/`CryptoService.instance` singleton gap this
    // file's own `test_EARS_COMM_1_send_persists_and_renders` note
    // documents. `ensureSession`'s own control frames go straight through
    // `TransportService.send` (never through the relay/routing layer at
    // all — `prekey_exchange.dart`'s own header), so no route is needed for
    // THAT to work.
    await a.coordinator.start();
    await b.coordinator.start();
    wireSend(aSuffix, a.selfDeviceId, bSuffix);
    wireSend(bSuffix, b.selfDeviceId, aSuffix);
    await connectPeer(aSuffix, b.selfDeviceId);
    await connectPeer(bSuffix, a.selfDeviceId);
  }

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  test('test_EARS_COMM_1_send_persists_and_renders', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await wireStacks(a, aSuffix, b, bSuffix);

    final controller = ChatController(
      conversationId: 'device-b',
      repo: ConversationRepository(a.db, selfDeviceId: 'device-a'),
      send: a.sendMessage,
      sessions: a.prekeyExchange,
      crypto: a.cryptoService,
      acks: a.deliveryAckService,
    );
    controller.onInit();
    addTearDown(controller.onClose);

    // `Queued -> Sent` happens synchronously inside `SendMessageUseCase
    // .call` itself (a local, successful `relayEngine.enqueue()`), never
    // gated on an actual wire forward -- so this test deliberately does NOT
    // call `coordinator.tick()`: doing so would forward the ciphertext to
    // `device-b`, whose `InboundPipeline` would then attempt to decrypt it
    // through `ReceiveMessageUseCase`'s own default
    // `CryptoService.instance.decrypt` -- the PROCESS-WIDE singleton, never
    // initialized for either simulated device in this two-stack-in-one-
    // process test (`messaging_stack.dart`'s own `receiveMessage =
    // ReceiveMessageUseCase(database: db)` construction never overrides
    // this). That is a real, pre-existing gap in `MessagingStack`/
    // `ReceiveMessageUseCase`'s wiring for this exact test shape --
    // `messaging_stack.dart` and `receive_message_use_case.dart` are both
    // outside this task's `files:` fence, so it is not fixed here. Actual
    // receipt (crypto + display, the part THIS controller owns) is
    // exercised separately in `test_no_plaintext_is_persisted_or_logged`
    // below via the same manual-remote-party pattern
    // `conversations_controller_test.dart` already established, which
    // sidesteps `InboundPipeline` entirely.
    await controller.send('Are you free tomorrow?');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.sendError.value, isEmpty);
    expect(controller.messages.length, 1);
    final bubble = controller.messages.single;
    expect(bubble.isMine, isTrue);
    expect(bubble.text, 'Are you free tomorrow?');
    expect(bubble.deliveryState, isNot(DeliveryState.failed));
  });

  test(
    'test_EARS_COMM_1_incoming_message_renders_in_sequence_order',
    () async {
      final stack = await newStack('self-device', nextSuffix());
      addTearDown(stack.dispose);
      // Direct-DB insert path (not through wireStacks) so `createdAt` can be
      // set to simulate out-of-order arrival independently of
      // `sequenceNumber` -- the exact hazard this file's own header
      // describes for same-sender messages.
      await _insertMessage(
        stack.db,
        id: 'peer-seq-2',
        conversationId: 'peer-device',
        senderDeviceId: 'peer-device',
        sequenceNumber: 2,
        ciphertext: Uint8List(0),
        createdAt: 1000, // arrived FIRST (lower createdAt)
      );
      await _insertMessage(
        stack.db,
        id: 'peer-seq-1',
        conversationId: 'peer-device',
        senderDeviceId: 'peer-device',
        sequenceNumber: 1,
        ciphertext: Uint8List(0),
        createdAt: 2000, // arrived SECOND (higher createdAt)
      );
      await _insertMessage(
        stack.db,
        id: 'peer-seq-0',
        conversationId: 'peer-device',
        senderDeviceId: 'peer-device',
        sequenceNumber: 0,
        ciphertext: Uint8List(0),
        createdAt: 3000, // arrived THIRD (highest createdAt)
      );

      final controller = ChatController(
        conversationId: 'peer-device',
        repo: ConversationRepository(stack.db, selfDeviceId: 'self-device'),
        send: stack.sendMessage,
        sessions: stack.prekeyExchange,
        crypto: stack.cryptoService,
        acks: stack.deliveryAckService,
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Arrival order was seq-2, seq-1, seq-0 -- display order must be the
      // reverse: seq-0, seq-1, seq-2 (sequence, never arrival/wall-clock).
      expect(
        controller.messages.map((b) => b.sequenceNumber).toList(),
        [0, 1, 2],
      );
      expect(
        controller.messages.map((b) => b.id).toList(),
        ['peer-seq-0', 'peer-seq-1', 'peer-seq-2'],
      );
    },
  );

  test('test_EARS_COMM_23_first_send_establishes_a_session', () async {
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await wireStacks(a, aSuffix, b, bSuffix);

    const address = SignalProtocolAddress('device-b', 1);
    expect(await a.signalStore.containsSession(address), isFalse);

    final controller = ChatController(
      conversationId: 'device-b',
      repo: ConversationRepository(a.db, selfDeviceId: 'device-a'),
      send: a.sendMessage,
      sessions: a.prekeyExchange,
      crypto: a.cryptoService,
      acks: a.deliveryAckService,
    );
    controller.onInit();
    addTearDown(controller.onClose);

    // Deliberately no `coordinator.tick()` here either -- see this file's
    // note in `test_EARS_COMM_1_send_persists_and_renders` above.
    await controller.send('hello bob');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // ensureSession was actually exercised (not skipped) -- the session now
    // exists and the message was persisted (not dropped).
    expect(await a.signalStore.containsSession(address), isTrue);
    expect(a.prekeyExchange.counters.requestsSent, 1);
    expect(controller.sendError.value, isEmpty);
    expect(controller.messages.length, 1);
  });

  test(
    'test_EARS_COMM_23_queued_bubble_renders_before_ensureSession_resolves',
    () async {
      // Regression for the review finding on E06-T11: task file §6 Risks
      // says twice, in unambiguous language, that `send()` must "show the
      // message as `Queued` immediately" and "not block the composer" while
      // `ensureSession` is still in flight (up to seconds, on exactly the
      // first-contact scenario this test constructs). Before this fix,
      // `messages` stayed empty for the ENTIRE duration `ensureSession` was
      // pending, because the optimistic bubble did not exist yet -- only
      // `SendMessageUseCase.call`, which ran AFTER `ensureSession` resolved,
      // ever populated `messages` (via the DB stream). This test asserts the
      // state WHILE `ensureSession` is still pending, not just after `send()`
      // settles -- `test_EARS_COMM_23_first_send_establishes_a_session`
      // above already covers the end state and would not have caught this.
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await wireStacks(a, aSuffix, b, bSuffix);

      final slowSessions = _SlowPrekeyExchange(
        stack: a,
        evaluateConnectionRequest:
            EvaluateConnectionRequestUseCase(RelationshipRepository(a.db)),
        real: a.prekeyExchange,
        delay: const Duration(seconds: 5),
      );

      final controller = ChatController(
        conversationId: 'device-b',
        repo: ConversationRepository(a.db, selfDeviceId: 'device-a'),
        send: a.sendMessage,
        sessions: slowSessions,
        crypto: a.cryptoService,
        acks: a.deliveryAckService,
      );
      controller.onInit();
      addTearDown(controller.onClose);

      // Deliberately not awaited -- this is exactly the "do not block the
      // composer" contract: the caller (the view) does not wait for `send`
      // to finish before the row is expected to exist.
      final sendFuture = controller.send('are you free tomorrow?');

      // `ensureSession` is still pending (its artificial 5s delay has not
      // elapsed) -- but the message must ALREADY be visible, `Queued`, with
      // the text the user typed. This is the assertion that fails on the
      // pre-fix code: `messages` was empty here.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.messages.length, 1);
      final queuedBubble = controller.messages.single;
      expect(queuedBubble.isMine, isTrue);
      expect(queuedBubble.text, 'are you free tomorrow?');
      expect(queuedBubble.deliveryState, DeliveryState.queued);

      // Let `ensureSession` (and the real send it gates) resolve, and
      // confirm the optimistic bubble reconciles cleanly to the one real,
      // persisted row -- never a duplicate, never a gap.
      await sendFuture;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(controller.sendError.value, isEmpty);
      expect(controller.messages.length, 1);
      final settledBubble = controller.messages.single;
      expect(settledBubble.isMine, isTrue);
      expect(settledBubble.text, 'are you free tomorrow?');
      expect(settledBubble.deliveryState, isNot(DeliveryState.failed));
      // The real, persisted row replaced the synthetic one -- its id is a
      // real message id, never the `local-N` placeholder.
      expect(settledBubble.id, isNot(startsWith('local-')));
    },
  );

  test('test_EARS_COMM_24_tick_updates_on_state_change', () async {
    final stack = await newStack('self-device', nextSuffix());
    addTearDown(stack.dispose);
    await _insertMessage(
      stack.db,
      id: 'm-1',
      conversationId: 'peer-device',
      senderDeviceId: 'self-device',
      sequenceNumber: 0,
      ciphertext: Uint8List(0),
      createdAt: 1000,
      state: DeliveryState.sent,
    );

    final controller = ChatController(
      conversationId: 'peer-device',
      repo: ConversationRepository(stack.db, selfDeviceId: 'self-device'),
      send: stack.sendMessage,
      sessions: stack.prekeyExchange,
      crypto: stack.cryptoService,
      acks: stack.deliveryAckService,
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.messages.single.deliveryState, DeliveryState.sent);

    // Flip the row's state with no user action -- the live stream must
    // reflect it (EARS-COMM-24).
    await (stack.db.update(stack.db.messages)
          ..where((t) => t.id.equals('m-1')))
        .write(
      const MessagesCompanion(deliveryState: Value('delivered')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.messages.single.deliveryState, DeliveryState.delivered);
  });

  test(
    'test_EARS_COMM_25_blocked_peer_shows_a_reason_and_keeps_the_text',
    () async {
      final stack = await newStack('self-device', nextSuffix());
      addTearDown(stack.dispose);
      await RelationshipRepository(stack.db)
          .upsert('blocked-peer', RelationshipState.blocked);

      final controller = ChatController(
        conversationId: 'blocked-peer',
        repo: ConversationRepository(stack.db, selfDeviceId: 'self-device'),
        send: stack.sendMessage,
        sessions: stack.prekeyExchange,
        crypto: stack.cryptoService,
        acks: stack.deliveryAckService,
      );
      controller.onInit();
      addTearDown(controller.onClose);

      await controller.send('are you there?');

      // A specific, named, non-fatal reason -- never a crash, never a
      // generic message that hides WHICH honest failure state fired.
      expect(controller.sendError.value, 'You have blocked this contact.');
      // No row was ever persisted for a peer refused at the trust gate --
      // `send` never throws to the view (task §5), and the composed text
      // is the VIEW's own responsibility to retain (chat_view_test.dart
      // covers the widget-level "keeps the text" assertion; this test
      // establishes the controller-level contract the view relies on: a
      // failure is always a named [sendError], never a silent success).
      expect(controller.messages, isEmpty);
    },
  );

  test('test_no_plaintext_is_persisted_or_logged', () async {
    // Outgoing half: a real send through the full stack (ensureSession ->
    // SendMessageUseCase -> encrypt), same as
    // `test_EARS_COMM_1_send_persists_and_renders`.
    final aSuffix = nextSuffix();
    final bSuffix = nextSuffix();
    final a = await newStack('device-a', aSuffix);
    final b = await newStack('device-b', bSuffix);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await wireStacks(a, aSuffix, b, bSuffix);

    final aController = ChatController(
      conversationId: 'device-b',
      repo: ConversationRepository(a.db, selfDeviceId: 'device-a'),
      send: a.sendMessage,
      sessions: a.prekeyExchange,
      crypto: a.cryptoService,
      acks: a.deliveryAckService,
    );
    aController.onInit();
    addTearDown(aController.onClose);

    const outgoingText = 'top secret wedge payload';
    await aController.send(outgoingText);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(aController.sendError.value, isEmpty);
    expect(aController.messages.single.text, outgoingText);

    // Incoming half: a real message decrypted for display on the
    // RECEIVING side. Constructed the same way
    // `conversations_controller_test.dart`'s own
    // `test_preview_decrypts_a_real_incoming_message`/
    // `test_no_plaintext_is_persisted` do -- Bob is a standalone remote
    // party (its own store/crypto, `CryptoService.withStore`) that
    // initiates a REAL X3DH handshake against B's own published bundle and
    // encrypts directly, with the resulting row inserted straight into B's
    // db. This deliberately bypasses `InboundPipeline`/
    // `ReceiveMessageUseCase` (whose default decrypt path binds to the
    // process-wide `CryptoService.instance` singleton, never initialized
    // for either simulated device here -- see the note on
    // `test_EARS_COMM_1_send_persists_and_renders` above) while still
    // exercising the REAL crypto + REAL `ChatController` decrypt-for-
    // display path this task owns.
    final bob = await _RemoteParty.create();
    addTearDown(bob.close);
    final bAddress = SignalProtocolAddress(b.selfDeviceId, 1);
    final bBundle = await b.identityService.getLocalPreKeyBundle();
    await bob.crypto.establishSession(bAddress, bBundle);

    const incomingText = 'top secret incoming reply';
    final envelope = MessageEnvelope(
      id: 'm-bob-incoming-1',
      conversationId: 'bob-device',
      sequenceNumber: 0,
      payload: Uint8List.fromList(utf8.encode(incomingText)),
    );
    final ciphertextMessage =
        await bob.crypto.encrypt(bAddress, envelope.serialize());
    await b.db.into(b.db.messages).insert(
          MessagesCompanion.insert(
            id: 'm-bob-incoming-1',
            conversationId: 'bob-device',
            senderDeviceId: 'bob-device',
            sequenceNumber: 0,
            ciphertext: Uint8List.fromList(ciphertextMessage.serialize()),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            deliveryState: DeliveryState.accepted.name,
          ),
        );

    final bController = ChatController(
      conversationId: 'bob-device',
      repo: ConversationRepository(b.db, selfDeviceId: b.selfDeviceId),
      send: b.sendMessage,
      sessions: b.prekeyExchange,
      crypto: b.cryptoService,
      acks: b.deliveryAckService,
    );
    bController.onInit();
    addTearDown(bController.onClose);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(bController.messages.single.text, incomingText);

    // Neither device's database -- ANY table, ANY column -- ever contains
    // either plaintext (NFR-SEC-001, task §9).
    expect(await _markerPresentAnywhere(a.db, outgoingText), isFalse);
    expect(await _markerPresentAnywhere(b.db, outgoingText), isFalse);
    expect(await _markerPresentAnywhere(a.db, incomingText), isFalse);
    expect(await _markerPresentAnywhere(b.db, incomingText), isFalse);
  });

  // E08-T03: access-frequency signals (FR-STORE-005). The recorder itself is
  // unit-tested in `test/core/storage/storage_access_recorder_test.dart`;
  // these tests prove the two `ChatController` call sites are actually
  // wired (task §3) and that a recorder failure never disturbs the display
  // path it rides along with (task §4).

  test(
    'test_EARS_STORE_7_opening_a_conversation_records_an_access',
    () async {
      final stack = await newStack('self-device', nextSuffix());
      addTearDown(stack.dispose);
      final recorder = StorageAccessRecorder(
        db: stack.db,
        flushInterval: const Duration(milliseconds: 20),
      );
      addTearDown(recorder.dispose);

      final controller = ChatController(
        conversationId: 'peer-device',
        repo: ConversationRepository(stack.db, selfDeviceId: 'self-device'),
        send: stack.sendMessage,
        sessions: stack.prekeyExchange,
        crypto: stack.cryptoService,
        acks: stack.deliveryAckService,
        recorder: recorder,
      );
      // No message was ever displayed -- opening the conversation alone
      // (onInit) must still record the access (task §5 contract:
      // `recordConversationOpened`).
      controller.onInit();
      addTearDown(controller.onClose);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      final row = await (stack.db.select(stack.db.storageItemStats)
            ..where((t) => t.itemId.equals('peer-device')))
          .getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.itemKind, StorageItemKind.message.name);
      expect(row.accessCount, 1);
      expect(row.lastAccessedAt, isNotNull);
    },
  );

  test(
    'test_EARS_STORE_7_displaying_a_message_records_an_access_via_controller',
    () async {
      final stack = await newStack('self-device', nextSuffix());
      addTearDown(stack.dispose);
      await _insertMessage(
        stack.db,
        id: 'm-displayed',
        conversationId: 'peer-device',
        senderDeviceId: 'peer-device',
        sequenceNumber: 0,
        ciphertext: Uint8List(0),
        createdAt: 1000,
      );
      final recorder = StorageAccessRecorder(
        db: stack.db,
        flushInterval: const Duration(milliseconds: 20),
      );
      addTearDown(recorder.dispose);

      final controller = ChatController(
        conversationId: 'peer-device',
        repo: ConversationRepository(stack.db, selfDeviceId: 'self-device'),
        send: stack.sendMessage,
        sessions: stack.prekeyExchange,
        crypto: stack.cryptoService,
        acks: stack.deliveryAckService,
        recorder: recorder,
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      controller.onMessageDisplayed('m-displayed');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final row = await (stack.db.select(stack.db.storageItemStats)
            ..where((t) => t.itemId.equals('m-displayed')))
          .getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.accessCount, 1);
      expect(row.lastAccessedAt, isNotNull);
    },
  );

  test(
    'test_EARS_STORE_8_recorder_failure_does_not_break_markRead',
    () async {
      final stack = await newStack('self-device', nextSuffix());
      addTearDown(stack.dispose);
      await _insertMessage(
        stack.db,
        id: 'm-broken-recorder',
        conversationId: 'peer-device',
        senderDeviceId: 'peer-device',
        sequenceNumber: 0,
        ciphertext: Uint8List(0),
        createdAt: 1000,
      );

      // Break the recorder's own write target -- a real write failure, the
      // same "failing write seam" convention this codebase already uses
      // (`agent/memory/lessons/backend.md` L-backend-002), not a mock.
      await stack.db.customStatement('DROP TABLE storage_item_stats');
      final recorder = StorageAccessRecorder(db: stack.db);
      addTearDown(recorder.dispose);

      final controller = ChatController(
        conversationId: 'peer-device',
        repo: ConversationRepository(stack.db, selfDeviceId: 'self-device'),
        send: stack.sendMessage,
        sessions: stack.prekeyExchange,
        crypto: stack.cryptoService,
        acks: stack.deliveryAckService,
        recorder: recorder,
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // The ack call (`_acks.markRead`, a no-op today while
      // `kReadReceiptsEnabled == false`, but never throwing regardless --
      // `delivery_ack.dart`) and the recorder call are both invoked from
      // the same line (task §4: "additive and independent"). Neither may
      // throw even though the recorder's underlying write is broken.
      expect(
        () => controller.onMessageDisplayed('m-broken-recorder'),
        returnsNormally,
      );
      // The deferred write itself must not surface as an unhandled Future
      // error either.
      await expectLater(recorder.flush(), completes);

      // The display path (message row, controller state) is completely
      // unaffected by the recorder's failure.
      expect(controller.messages.single.id, 'm-broken-recorder');
      expect(controller.errorMessage.value, isEmpty);
    },
  );
}
