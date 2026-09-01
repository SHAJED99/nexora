// E06-T09 — ConversationRepository: the pure read model over `messages` +
// `relationships`. Tests are named by the EARS id they prove (task §8).
// Widened by E07-T07 to also cover `groups` + `group_members`
// (EARS-COMM-33/34 and the group-related contract tests below) — E06-T09's
// own tests above the E07-T07 marker are UNMODIFIED.
//
// `AppDatabase.forTesting(NativeDatabase.memory())` is the established
// pattern across this repo's data-layer tests (e.g.
// test/features/devices/presentation/devices_view_test.dart,
// test/core/persistence/message_migration_test.dart).
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/conversation_summary.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// Counts every `runSelect` the underlying executor performs, and keeps the
/// raw SQL text so a test can isolate the repository's own grouped query
/// (unique CTE name `last_msg`) from any incidental query drift/sqlite3
/// issue for bookkeeping.
class _QueryCounter extends QueryInterceptor {
  final List<String> selectStatements = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selectStatements.add(statement);
    return super.runSelect(executor, statement, args);
  }

  int get listConversationsQueryCount =>
      selectStatements.where((s) => s.contains('last_msg')).length;
}

Future<void> _insertMessage(
  AppDatabase db, {
  required String id,
  required String conversationId,
  required String senderDeviceId,
  required int createdAt,
  int sequenceNumber = 0,
  DeliveryState deliveryState = DeliveryState.delivered,
}) {
  return db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: conversationId,
          senderDeviceId: senderDeviceId,
          sequenceNumber: sequenceNumber,
          ciphertext: Uint8List.fromList([1, 2, 3]),
          createdAt: createdAt,
          deliveryState: deliveryState.name,
        ),
      );
}

Future<void> _insertGroup(
  AppDatabase db, {
  required String id,
  required String name,
  String createdByDeviceId = 'owner-device',
  int createdAt = 0,
  bool isDeleted = false,
}) {
  return db.into(db.groups).insert(
        GroupsCompanion.insert(
          id: id,
          name: name,
          createdAt: createdAt,
          createdByDeviceId: createdByDeviceId,
          isDeleted: Value(isDeleted),
        ),
      );
}

Future<void> _insertMember(
  AppDatabase db, {
  required String groupId,
  required String deviceId,
  GroupRole role = GroupRole.member,
  int joinedAtEpoch = 0,
  int? removedAtEpoch,
}) {
  return db.into(db.groupMembers).insert(
        GroupMembersCompanion.insert(
          groupId: groupId,
          deviceId: deviceId,
          role: role.name,
          joinedAtEpoch: joinedAtEpoch,
          removedAtEpoch: Value(removedAtEpoch),
        ),
      );
}

void main() {
  const selfDeviceId = 'self-device';

  late AppDatabase db;
  late ConversationRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ConversationRepository(db, selfDeviceId: selfDeviceId);
  });

  tearDown(() => db.close());

  test('test_EARS_COMM_17_one_entry_per_conversation_ordered_by_recency',
      () async {
    // conv-A: two messages, newest at t=200.
    await _insertMessage(db,
        id: 'a-1', conversationId: 'conv-A', senderDeviceId: selfDeviceId, createdAt: 100);
    await _insertMessage(db,
        id: 'a-2', conversationId: 'conv-A', senderDeviceId: 'peer-A', createdAt: 200);
    // conv-B: one message at t=150.
    await _insertMessage(db,
        id: 'b-1', conversationId: 'conv-B', senderDeviceId: 'peer-B', createdAt: 150);
    // conv-C: three messages, newest at t=300.
    await _insertMessage(db,
        id: 'c-1', conversationId: 'conv-C', senderDeviceId: 'peer-C', createdAt: 50);
    await _insertMessage(db,
        id: 'c-2', conversationId: 'conv-C', senderDeviceId: selfDeviceId, createdAt: 250);
    await _insertMessage(db,
        id: 'c-3', conversationId: 'conv-C', senderDeviceId: 'peer-C', createdAt: 300);

    final list = await repository.listConversations();

    expect(list, hasLength(3));
    expect(list.map((c) => c.conversationId), ['conv-C', 'conv-A', 'conv-B']);
    expect(list[0].lastMessageId, 'c-3');
    expect(list[0].lastMessageAt, 300);
    expect(list[0].lastMessageIsMine, isFalse);
    expect(list[1].lastMessageId, 'a-2');
    expect(list[1].lastMessageIsMine, isFalse);
    expect(list[2].lastMessageId, 'b-1');
  });

  test('test_EARS_COMM_17_blocked_peer_is_excluded', () async {
    await _insertMessage(db,
        id: 'blocked-1',
        conversationId: 'peer-blocked',
        senderDeviceId: 'peer-blocked',
        createdAt: 100);
    await _insertMessage(db,
        id: 'allowed-1',
        conversationId: 'peer-allowed',
        senderDeviceId: 'peer-allowed',
        createdAt: 50);

    final relationships = RelationshipRepository(db);
    await relationships.upsert('peer-blocked', RelationshipState.blocked);
    await relationships.upsert('peer-allowed', RelationshipState.allowed);

    final list = await repository.listConversations();

    expect(list, hasLength(1));
    expect(list.single.conversationId, 'peer-allowed');

    // Excluded from the view, never deleted.
    final blockedMessages = await (db.select(db.messages)
          ..where((t) => t.conversationId.equals('peer-blocked')))
        .get();
    expect(blockedMessages, hasLength(1));
  });

  test('test_EARS_COMM_17_list_is_a_single_query', () async {
    final counter = _QueryCounter();
    final countedDb = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(counter),
    );
    addTearDown(countedDb.close);
    final countedRepo =
        ConversationRepository(countedDb, selfDeviceId: selfDeviceId);

    for (var i = 0; i < 2; i++) {
      await _insertMessage(countedDb,
          id: 'warm-$i',
          conversationId: 'conv-warm-$i',
          senderDeviceId: 'peer-$i',
          createdAt: i);
    }
    await countedRepo.listConversations();
    final countAtTwoConversations = counter.listConversationsQueryCount;
    expect(countAtTwoConversations, 1);

    for (var i = 2; i < 10; i++) {
      await _insertMessage(countedDb,
          id: 'warm-$i',
          conversationId: 'conv-warm-$i',
          senderDeviceId: 'peer-$i',
          createdAt: i);
    }
    await countedRepo.listConversations();
    final countAtTenConversations =
        counter.listConversationsQueryCount - countAtTwoConversations;

    // The SECOND call to listConversations() (10 conversations) must issue
    // exactly as many grouped queries as the FIRST call did (2
    // conversations) -- one. An N+1 implementation would issue 10.
    expect(countAtTenConversations, countAtTwoConversations);
  });

  test('test_EARS_COMM_18_keyset_paging_walks_the_whole_thread', () async {
    const total = 120;
    for (var i = 0; i < total; i++) {
      await _insertMessage(db,
          id: 'msg-${i.toString().padLeft(3, '0')}',
          conversationId: 'conv-long',
          senderDeviceId: i.isEven ? selfDeviceId : 'peer-long',
          createdAt: i);
    }

    final seen = <String>{};
    int? cursor;
    var pages = 0;
    while (true) {
      final page = await repository.messagesPage(
        'conv-long',
        before: cursor,
        limit: 50,
      );
      if (page.isEmpty) break;
      for (final message in page) {
        // No duplicates.
        expect(seen.add(message.id), isTrue,
            reason: '${message.id} returned on more than one page');
      }
      cursor = page.last.createdAt;
      pages++;
      expect(pages, lessThan(10), reason: 'paging did not terminate');
      if (page.length < 50) break; // end of thread
    }

    // No gaps: every inserted message was walked exactly once.
    expect(seen, hasLength(total));
    expect(pages, 3); // 50 + 50 + 20
  });

  test('test_EARS_COMM_18_equal_timestamps_have_a_stable_order', () async {
    await _insertMessage(db,
        id: 'msg-b',
        conversationId: 'conv-tie',
        senderDeviceId: 'peer-tie',
        createdAt: 1000);
    await _insertMessage(db,
        id: 'msg-a',
        conversationId: 'conv-tie',
        senderDeviceId: 'peer-tie',
        createdAt: 1000);
    await _insertMessage(db,
        id: 'msg-c',
        conversationId: 'conv-tie',
        senderDeviceId: 'peer-tie',
        createdAt: 1000);

    final firstRead = await repository.messagesPage('conv-tie');
    final secondRead = await repository.messagesPage('conv-tie');

    final firstOrder = firstRead.map((m) => m.id).toList();
    final secondOrder = secondRead.map((m) => m.id).toList();

    expect(firstOrder, hasLength(3));
    // Deterministic tie-break on `id` (descending, alongside `created_at`).
    expect(firstOrder, ['msg-c', 'msg-b', 'msg-a']);
    expect(secondOrder, firstOrder);
  });

  test('test_EARS_COMM_19_stream_emits_on_insert', () async {
    final events = <List<dynamic>>[];
    final subscription = repository
        .watchConversations(coalesceWindow: const Duration(milliseconds: 5))
        .listen(events.add);
    addTearDown(subscription.cancel);

    // Initial emission -- empty, nothing inserted yet.
    await Future.delayed(const Duration(milliseconds: 50));
    expect(events, hasLength(1));
    expect(events.single, isEmpty);

    await _insertMessage(db,
        id: 'live-1',
        conversationId: 'conv-live',
        senderDeviceId: 'peer-live',
        createdAt: 42);

    await Future.delayed(const Duration(milliseconds: 50));
    expect(events, hasLength(2));
    final latest = events.last;
    expect(latest, hasLength(1));
    expect((latest.single as dynamic).conversationId, 'conv-live');
  });

  test(
      'test_EARS_COMM_19_burst_of_ten_inserts_is_coalesced_not_ten_re_reads',
      () async {
    final counter = _QueryCounter();
    final countedDb = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(counter),
    );
    addTearDown(countedDb.close);
    final countedRepo =
        ConversationRepository(countedDb, selfDeviceId: selfDeviceId);

    final events = <List<dynamic>>[];
    final subscription = countedRepo
        .watchConversations(coalesceWindow: const Duration(milliseconds: 30))
        .listen(events.add);
    addTearDown(subscription.cancel);

    // Let the initial (empty) emission settle and its query land, so the
    // burst below is isolated in the count.
    await Future.delayed(const Duration(milliseconds: 80));
    final countBeforeBurst = counter.listConversationsQueryCount;

    for (var i = 0; i < 10; i++) {
      await _insertMessage(countedDb,
          id: 'burst-$i',
          conversationId: 'conv-burst-$i',
          senderDeviceId: 'peer-burst-$i',
          createdAt: i);
    }

    // Well past the coalesce window, so the debounced re-read has fired.
    await Future.delayed(const Duration(milliseconds: 150));

    final burstQueries = counter.listConversationsQueryCount - countBeforeBurst;
    expect(burstQueries, lessThan(10));
    expect(burstQueries, greaterThanOrEqualTo(1));
    expect(events.last, hasLength(10));
  });

  test('test_unread_count_counts_only_unread_peer_messages', () async {
    await _insertMessage(db,
        id: 'u-1',
        conversationId: 'conv-unread',
        senderDeviceId: 'peer-unread',
        createdAt: 1,
        deliveryState: DeliveryState.delivered);
    await _insertMessage(db,
        id: 'u-2',
        conversationId: 'conv-unread',
        senderDeviceId: 'peer-unread',
        createdAt: 2,
        deliveryState: DeliveryState.read);
    await _insertMessage(db,
        id: 'u-3',
        conversationId: 'conv-unread',
        senderDeviceId: selfDeviceId,
        createdAt: 3,
        deliveryState: DeliveryState.sent);

    expect(await repository.unreadCount('conv-unread'), 1);
    expect(await repository.unreadCount('conv-with-no-messages'), 0);
  });

  test('test_no_ciphertext_is_decrypted_by_the_repository', () {
    // The assertion per E06-T09 §8: the repository file does not even
    // IMPORT CryptoService -- decryption for display belongs in the
    // screen layer. Doc comments are allowed to name it (as this file's
    // own header does, explaining why it must not); only actual `import`
    // statements are checked.
    final source = File(
      'lib/features/messaging/data/conversation_repository.dart',
    ).readAsStringSync();
    final importLines = source
        .split('\n')
        .where((line) => line.trim().startsWith('import '));

    expect(
      importLines.any((line) => line.contains('crypto')),
      isFalse,
      reason: 'ConversationRepository must never import CryptoService or '
          'anything from core/crypto -- decryption for display belongs in '
          'the screen layer (E06-T09 §2/§4).',
    );
  });

  // --- E07-T07: widened to groups ---------------------------------------

  test('test_EARS_COMM_33_personal_and_group_interleave_by_recency',
      () async {
    // Personal conversation, last activity at t=100.
    await _insertMessage(db,
        id: 'p-1', conversationId: 'peer-x', senderDeviceId: 'peer-x', createdAt: 100);

    // Group conversation, last activity at t=300 (most recent overall).
    await _insertGroup(db, id: 'g:team', name: 'Team');
    await _insertMember(db, groupId: 'g:team', deviceId: selfDeviceId);
    await _insertMember(db, groupId: 'g:team', deviceId: 'peer-y');
    await _insertMessage(db,
        id: 'g-1', conversationId: 'g:team', senderDeviceId: 'peer-y', createdAt: 300);

    // Another personal conversation, last activity at t=200 (between the two).
    await _insertMessage(db,
        id: 'p-2', conversationId: 'peer-z', senderDeviceId: 'peer-z', createdAt: 200);

    final list = await repository.listConversations();

    expect(list, hasLength(3));
    expect(list.map((c) => c.conversationId),
        ['g:team', 'peer-z', 'peer-x']);

    final group = list.first;
    expect(group.kind, ConversationKind.group);
    expect(group.groupName, 'Team');
    expect(group.memberCount, 2);
    expect(group.peerDeviceId, isNull);
    expect(group.relationshipState, isNull);
    expect(group.lastMessageId, 'g-1');
    expect(group.lastMessageSenderDeviceId, 'peer-y');
    expect(group.lastMessageIsMine, isFalse);

    final personalNewer = list[1];
    expect(personalNewer.kind, ConversationKind.personal);
    expect(personalNewer.peerDeviceId, 'peer-z');
    expect(personalNewer.groupName, isNull);
    expect(personalNewer.memberCount, isNull);
  });

  test('test_EARS_COMM_33_deleted_group_is_absent_and_its_rows_are_retained',
      () async {
    await _insertGroup(db, id: 'g:gone', name: 'Gone', isDeleted: true);
    await _insertMember(db, groupId: 'g:gone', deviceId: selfDeviceId);
    await _insertMessage(db,
        id: 'g-gone-1',
        conversationId: 'g:gone',
        senderDeviceId: 'peer-a',
        createdAt: 100);

    final list = await repository.listConversations();

    expect(list, isEmpty);

    // Excluded from the view, never deleted.
    final rows = await (db.select(db.messages)
          ..where((t) => t.conversationId.equals('g:gone')))
        .get();
    expect(rows, hasLength(1));
  });

  test('test_EARS_COMM_33_group_containing_a_blocked_peer_is_still_listed',
      () async {
    await _insertGroup(db, id: 'g:mixed', name: 'Mixed');
    await _insertMember(db, groupId: 'g:mixed', deviceId: selfDeviceId);
    await _insertMember(db, groupId: 'g:mixed', deviceId: 'peer-blocked');
    await _insertMessage(db,
        id: 'g-mixed-1',
        conversationId: 'g:mixed',
        senderDeviceId: 'peer-blocked',
        createdAt: 100);

    final relationships = RelationshipRepository(db);
    await relationships.upsert('peer-blocked', RelationshipState.blocked);

    final list = await repository.listConversations();

    // The group is still listed even though one of its members is blocked
    // on this device (E07-T07 §2 — blocking is asymmetric by design; the
    // 1:1 exclusion in test_EARS_COMM_17_blocked_peer_is_excluded is
    // unrelated and unaffected).
    expect(list, hasLength(1));
    expect(list.single.conversationId, 'g:mixed');
    expect(list.single.kind, ConversationKind.group);
  });

  test('test_EARS_COMM_33_list_is_still_a_single_query', () async {
    final counter = _QueryCounter();
    final countedDb = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(counter),
    );
    addTearDown(countedDb.close);
    final countedRepo =
        ConversationRepository(countedDb, selfDeviceId: selfDeviceId);

    Future<void> seed(int groupIndex) async {
      final groupId = 'g:union-$groupIndex';
      await _insertGroup(countedDb, id: groupId, name: 'Group $groupIndex');
      await _insertMember(countedDb, groupId: groupId, deviceId: selfDeviceId);
      await _insertMessage(countedDb,
          id: 'union-msg-$groupIndex',
          conversationId: groupId,
          senderDeviceId: selfDeviceId,
          createdAt: groupIndex);
    }

    // 2 personal + 2 group conversations.
    for (var i = 0; i < 2; i++) {
      await _insertMessage(countedDb,
          id: 'union-personal-$i',
          conversationId: 'conv-union-$i',
          senderDeviceId: 'peer-$i',
          createdAt: i);
    }
    for (var i = 0; i < 2; i++) {
      await seed(i);
    }
    await countedRepo.listConversations();
    final countAtFour = counter.listConversationsQueryCount;
    expect(countAtFour, 1);

    // Grow to 10 personal + 10 groups.
    for (var i = 2; i < 10; i++) {
      await _insertMessage(countedDb,
          id: 'union-personal-$i',
          conversationId: 'conv-union-$i',
          senderDeviceId: 'peer-$i',
          createdAt: i);
    }
    for (var i = 2; i < 10; i++) {
      await seed(i);
    }
    await countedRepo.listConversations();
    final countAtTwenty = counter.listConversationsQueryCount - countAtFour;

    // The SECOND call (10 personal + 10 groups) must issue exactly as many
    // grouped queries as the FIRST call (2 personal + 2 groups) did -- one.
    // Widening the projection to a UNION over groups must not turn into a
    // second round trip, let alone an N+1 (E07-T07 §6).
    expect(countAtTwenty, countAtFour);
  });

  test('test_EARS_COMM_34_rename_emits_without_a_new_message', () async {
    await _insertGroup(db, id: 'g:rename', name: 'Original Name');
    await _insertMember(db, groupId: 'g:rename', deviceId: selfDeviceId);
    await _insertMessage(db,
        id: 'g-rename-1',
        conversationId: 'g:rename',
        senderDeviceId: selfDeviceId,
        createdAt: 10);

    final events = <List<dynamic>>[];
    final subscription = repository
        .watchConversations(coalesceWindow: const Duration(milliseconds: 5))
        .listen(events.add);
    addTearDown(subscription.cancel);

    await Future.delayed(const Duration(milliseconds: 50));
    expect(events, hasLength(1));
    expect((events.single.single as dynamic).groupName, 'Original Name');

    // Rename -- no new message.
    await (db.update(db.groups)..where((t) => t.id.equals('g:rename')))
        .write(const GroupsCompanion(name: Value('Renamed')));

    await Future.delayed(const Duration(milliseconds: 50));
    expect(events, hasLength(2));
    expect((events.last.single as dynamic).groupName, 'Renamed');

    // Membership change -- also no new message.
    await _insertMember(db, groupId: 'g:rename', deviceId: 'peer-new');

    await Future.delayed(const Duration(milliseconds: 50));
    expect(events, hasLength(3));
    expect((events.last.single as dynamic).memberCount, 2);
  });

  test('test_messages_page_works_unchanged_on_a_group_conversation_id',
      () async {
    const groupId = 'g:thread';
    await _insertMessage(db,
        id: 'gm-1',
        conversationId: groupId,
        senderDeviceId: 'peer-a',
        createdAt: 10);
    await _insertMessage(db,
        id: 'gm-2',
        conversationId: groupId,
        senderDeviceId: selfDeviceId,
        createdAt: 20);

    final page = await repository.messagesPage(groupId);
    expect(page.map((m) => m.id), ['gm-2', 'gm-1']);

    final unread = await repository.unreadCount(groupId);
    expect(unread, 1);

    final events = <List<dynamic>>[];
    final subscription =
        repository.watchConversation(groupId).listen(events.add);
    addTearDown(subscription.cancel);
    await Future.delayed(const Duration(milliseconds: 20));
    expect(events.last.map((m) => m.id), ['gm-2', 'gm-1']);
  });

  test('test_summary_has_no_preview_text_field_and_no_crypto_import', () {
    final source = File(
      'lib/features/messaging/domain/conversation_summary.dart',
    ).readAsStringSync();
    final codeLines = source
        .split('\n')
        .where((line) => !line.trim().startsWith('//'));

    expect(
      codeLines.any((line) => line.contains('previewText')),
      isFalse,
      reason: 'ConversationSummary must never grow a previewText field '
          '(E06-T09 §2, E07-T07 §4) -- decryption for display belongs in '
          'the screen layer. (Doc comments are allowed to name it while '
          'explaining why it must not exist; only actual code is checked.)',
    );

    final importLines = source
        .split('\n')
        .where((line) => line.trim().startsWith('import '));
    expect(
      importLines.any((line) => line.contains('crypto')),
      isFalse,
      reason: 'ConversationSummary must never import anything from '
          'core/crypto.',
    );
  });
}
