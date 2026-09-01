// features/conversations/presentation — ConversationsController (E06-T10).
//
// EARS-COMM-20/21/22 plus the two hard confidentiality/graceful-degrade
// contracts this task's own §2 names: preview decryption is best-effort and
// display-only, and it never persists anything back to the database.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/conversations/presentation/conversations_controller.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message_envelope.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// A simulated remote party — its own database, store, and `CryptoService`
/// bound to it — mirroring `crypto_service_test.dart`'s `_Party` pattern.
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

  Future<void> close() => db.close();
}

/// Scans every table/column in the database for a marker string, the way
/// the reviewer's own probe did -- a byte-identity check on one column of
/// one row (the previous version of this test) would still pass even if
/// the marker leaked into some other table or column, so this genuinely
/// falsifies "never persisted, logged, or written back" (task §2) instead
/// of only checking the one column the implementation happens to touch.
Future<bool> _markerPresentAnywhere(AppDatabase db, String marker) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  for (final tableRow in tables) {
    final tableName = tableRow.data['name'] as String;
    final columns = await db
        .customSelect('PRAGMA table_info($tableName)')
        .get();
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
  await db
      .into(db.messages)
      .insert(
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

/// Seeds a group conversation (E07-T01's tables) so a group row reaches this
/// controller through E07-T07's widened read model — the case the Personal
/// list must skip until E07-T08 gives Groups its own row treatment.
Future<void> _insertGroup(
  AppDatabase db, {
  required String id,
  required String name,
}) async {
  await db.into(db.groups).insert(
        GroupsCompanion.insert(
          id: id,
          name: name,
          createdAt: 0,
          createdByDeviceId: 'self-device',
        ),
      );
}

Future<void> _insertMember(
  AppDatabase db, {
  required String groupId,
  required String deviceId,
}) async {
  await db.into(db.groupMembers).insert(
        GroupMembersCompanion.insert(
          groupId: groupId,
          deviceId: deviceId,
          role: 'member',
          joinedAtEpoch: 0,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  late AppDatabase db;
  late MessagingStack stack;
  late ConversationRepository repo;
  late RelationshipRepository relationships;

  setUp(() async {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relationships = RelationshipRepository(db);
    repo = ConversationRepository(db, selfDeviceId: 'self-device');
    stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'self-device',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'conversations-controller-${suffixCounter++}',
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
  });

  tearDown(() async {
    await stack.dispose();
    Get.reset();
  });

  test('test_EARS_COMM_20_lists_conversations_most_recent_first', () async {
    await relationships.upsert('device-a', RelationshipState.trusted);
    await relationships.upsert('device-b', RelationshipState.allowed);
    await _insertMessage(
      db,
      id: 'm-a1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );
    await _insertMessage(
      db,
      id: 'm-b1',
      conversationId: 'device-b',
      senderDeviceId: 'device-b',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 2)),
      createdAt: 2000,
    );

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.loading.value, isFalse);
    expect(controller.conversations.map((t) => t.peerDeviceId).toList(), [
      'device-b',
      'device-a',
    ]);
    controller.onClose();
  });

  // E07-T07 / OQ-E07-T07-1: `watchConversations()` now also emits group rows,
  // whose `peerDeviceId`/`relationshipState` are null. Until E07-T08 renders
  // the Groups section, this screen's Personal list skips them — it must not
  // crash, and it must not render a group as if it were a peer.
  test('test_group_conversations_are_skipped_by_the_personal_list', () async {
    await relationships.upsert('device-a', RelationshipState.trusted);
    await _insertMessage(
      db,
      id: 'm-a1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );
    await _insertGroup(db, id: 'g:team', name: 'Team');
    await _insertMember(db, groupId: 'g:team', deviceId: 'self-device');
    await _insertMember(db, groupId: 'g:team', deviceId: 'device-a');
    await _insertMessage(
      db,
      id: 'm-g1',
      conversationId: 'g:team',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 3)),
      createdAt: 3000,
    );

    // The read model really does surface the group (otherwise this test
    // would pass for the wrong reason).
    final summaries = await repo.listConversations();
    expect(summaries.map((s) => s.conversationId), ['g:team', 'device-a']);

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.errorMessage.value, isEmpty);
    expect(controller.conversations.map((t) => t.conversationId).toList(), [
      'device-a',
    ]);
    controller.onClose();
  });

  test('test_EARS_COMM_20_blocked_conversation_absent', () async {
    await relationships.upsert('device-ok', RelationshipState.trusted);
    await relationships.upsert('device-blocked', RelationshipState.blocked);
    await _insertMessage(
      db,
      id: 'm-ok',
      conversationId: 'device-ok',
      senderDeviceId: 'device-ok',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );
    await _insertMessage(
      db,
      id: 'm-blocked',
      conversationId: 'device-blocked',
      senderDeviceId: 'device-blocked',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 2)),
      createdAt: 2000,
    );

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.conversations.map((t) => t.peerDeviceId).toList(), [
      'device-ok',
    ]);
    controller.onClose();
  });

  test('test_EARS_COMM_21_list_updates_on_new_message', () async {
    await relationships.upsert('device-a', RelationshipState.trusted);
    await _insertMessage(
      db,
      id: 'm-a1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(controller.conversations.length, 1);

    await relationships.upsert('device-b', RelationshipState.trusted);
    await _insertMessage(
      db,
      id: 'm-b1',
      conversationId: 'device-b',
      senderDeviceId: 'device-b',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 2)),
      createdAt: 2000,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.conversations.length, 2);
    expect(controller.conversations.first.peerDeviceId, 'device-b');
    controller.onClose();
  });

  test('test_preview_decryption_failure_degrades_gracefully', () async {
    // No session ever established with this peer, and the ciphertext bytes
    // do not even parse as a Signal message type -- both a decrypt failure
    // and (independently) a reconstruction failure, either of which must
    // degrade to "no preview", never an error row.
    await relationships.upsert('device-garbage', RelationshipState.trusted);
    await _insertMessage(
      db,
      id: 'm-garbage',
      conversationId: 'device-garbage',
      senderDeviceId: 'device-garbage',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(8, 0xFF)),
      createdAt: 1000,
    );

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.conversations.length, 1);
    final tile = controller.conversations.single;
    expect(tile.peerDeviceId, 'device-garbage');
    expect(tile.preview, isNull);
    controller.onClose();
  });

  test('test_preview_decrypts_a_real_incoming_message', () async {
    // Bob is the INITIATOR against self's published bundle -- mirrors a
    // real first-contact message arriving (crypto_service_test.dart's own
    // pattern: the responder side, here "self", never calls
    // establishSession itself; ReceiveMessageUseCase/CryptoService.decrypt
    // establishes it implicitly).
    final bob = await _RemoteParty.create();
    addTearDown(bob.close);
    const selfAddress = SignalProtocolAddress('self-device', 1);

    final selfBundle = await stack.identityService.getLocalPreKeyBundle();
    await bob.crypto.establishSession(selfAddress, selfBundle);

    final envelope = MessageEnvelope(
      id: 'm-bob-1',
      conversationId: 'bob-device',
      sequenceNumber: 1,
      payload: Uint8List.fromList(utf8.encode('Hello there')),
    );
    final ciphertextMessage = await bob.crypto.encrypt(
      selfAddress,
      envelope.serialize(),
    );

    await relationships.upsert('bob-device', RelationshipState.trusted);
    await _insertMessage(
      db,
      id: 'm-bob-1',
      conversationId: 'bob-device',
      senderDeviceId: 'bob-device',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(ciphertextMessage.serialize()),
      createdAt: 1000,
    );

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final tile = controller.conversations.single;
    expect(tile.preview, 'Hello there');
    controller.onClose();
  });

  test('test_no_plaintext_is_persisted', () async {
    final bob = await _RemoteParty.create();
    addTearDown(bob.close);
    const selfAddress = SignalProtocolAddress('self-device', 1);

    final selfBundle = await stack.identityService.getLocalPreKeyBundle();
    await bob.crypto.establishSession(selfAddress, selfBundle);
    final envelope = MessageEnvelope(
      id: 'm-bob-1',
      conversationId: 'bob-device',
      sequenceNumber: 1,
      payload: Uint8List.fromList(utf8.encode('top secret preview')),
    );
    final ciphertextMessage = await bob.crypto.encrypt(
      selfAddress,
      envelope.serialize(),
    );
    final originalBytes = Uint8List.fromList(ciphertextMessage.serialize());

    await relationships.upsert('bob-device', RelationshipState.trusted);
    await _insertMessage(
      db,
      id: 'm-bob-1',
      conversationId: 'bob-device',
      senderDeviceId: 'bob-device',
      sequenceNumber: 1,
      ciphertext: originalBytes,
      createdAt: 1000,
    );

    final controller = ConversationsController(
      repo: repo,
      crypto: stack.cryptoService,
      stack: stack,
    );
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(controller.conversations.single.preview, 'top secret preview');

    // The row on disk is byte-identical to what was stored -- the preview
    // decrypt step never wrote back to `messages` (task §2: "never
    // persisted, logged, or written back").
    final row = await (db.select(
      db.messages,
    )..where((t) => t.id.equals('m-bob-1'))).getSingle();
    expect(row.ciphertext, originalBytes);

    // Scan every table/column in the database, not just the one row/column
    // above -- the plaintext preview must not have leaked anywhere.
    expect(await _markerPresentAnywhere(db, 'top secret preview'), isFalse);
    controller.onClose();
  });
}
