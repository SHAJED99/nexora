// features/groups/presentation — the group thread (E07-T18), named by EARS
// id. A real in-memory Drift database backs every repository, so the blocked
// filter, the event lines and the ordering are proved against the real
// queries rather than a fake that could agree with a wrong implementation.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/presentation/group_thread_controller.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

const _self = 'self-device';
const _groupId = 'g:team';

void main() {
  late AppDatabase db;
  late RelationshipRepository relationships;
  late GroupRepository groups;
  late ConversationRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relationships = RelationshipRepository(db);
    groups = GroupRepository(db);
    repo = ConversationRepository(db, selfDeviceId: _self);
    await db.into(db.groups).insert(
          GroupsCompanion.insert(
            id: _groupId,
            name: 'Team',
            createdByDeviceId: _self,
            membershipEpoch: const Value(1),
            createdAt: 1000,
          ),
          mode: InsertMode.insertOrReplace,
        );
  });

  tearDown(() async => db.close());

  GroupThreadController build({int sendCalls = 0}) => GroupThreadController(
        groupId: _groupId,
        repo: repo,
        groups: groups,
        relationships: relationships,
        send: ({required groupId, required body}) async => null,
      );

  Message msg({
    required String id,
    required String sender,
    required String plaintext,
    int createdAt = 2000,
  }) =>
      Message(
        id: id,
        conversationId: _groupId,
        senderDeviceId: sender,
        ciphertext: Uint8List(0),
        createdAt: createdAt,
        deliveryState: DeliveryState.accepted,
        sequenceNumber: 1,
        plaintextPayload: Uint8List.fromList(utf8.encode(plaintext)),
      );

  group('EARS-GROUP-23 — sender attribution on incoming bubbles only', () {
    test('test_EARS_GROUP_23_incoming_carries_attribution_outgoing_does_not',
        () async {
      final c = build();
      await c.render([
        msg(id: 'm1', sender: 'device-a', plaintext: 'hi', createdAt: 2000),
        msg(id: 'm2', sender: _self, plaintext: 'hello', createdAt: 2001),
      ]);

      final incoming = c.rows.firstWhere((r) => r.id == 'm1');
      final outgoing = c.rows.firstWhere((r) => r.id == 'm2');

      expect(incoming.senderDeviceId, 'device-a');
      expect(
        outgoing.senderDeviceId,
        isNull,
        reason: 'GAP-020: "outgoing bubbles do not [carry attribution] -- '
            'the design never labels the user to themselves"',
      );
      expect(outgoing.isMine, isTrue);
    });
  });

  group('EARS-GROUP-24 — a blocked member is hidden, not broken', () {
    test('test_EARS_GROUP_24_blocked_sender_body_is_withheld', () async {
      await relationships.upsert('device-b', RelationshipState.blocked);
      final c = build();
      await c.render([
        msg(id: 'm1', sender: 'device-a', plaintext: 'visible'),
        msg(id: 'm2', sender: 'device-b', plaintext: 'SECRET-BODY'),
      ]);

      final ok = c.rows.firstWhere((r) => r.id == 'm1');
      final blocked = c.rows.firstWhere((r) => r.id == 'm2');

      expect(ok.senderIsBlocked, isFalse);
      expect(ok.text, 'visible');

      expect(blocked.senderIsBlocked, isTrue);
      // BOTH halves. Asserting only the flag would pass even if the body
      // were resolved and sitting in the model one careless widget away
      // from the screen.
      expect(
        blocked.text,
        isNull,
        reason: 'a blocked sender body is never resolved AT ALL -- not '
            'decrypted and then hidden',
      );
      expect(
        c.rows.map((r) => r.text).whereType<String>(),
        isNot(contains('SECRET-BODY')),
      );
      // And it is still PRESENT -- the human's OQ-E07-13 answer forbids
      // dropping it.
      expect(c.rows.where((r) => r.id == 'm2'), hasLength(1));
      // Attribution survives: hiding WHO it was from would be a second,
      // undecided product behaviour.
      expect(blocked.senderDeviceId, 'device-b');
    });

    test('test_EARS_GROUP_24_blocked_is_not_conflated_with_decrypt_failure',
        () async {
      await relationships.upsert('device-b', RelationshipState.blocked);
      final c = build();
      await c.render([
        // A genuine decrypt failure: no persisted body, and the injected
        // decrypt throws.
        Message(
          id: 'm-fail',
          conversationId: _groupId,
          senderDeviceId: 'device-c',
          ciphertext: Uint8List.fromList([1, 2, 3]),
          createdAt: 2000,
          deliveryState: DeliveryState.accepted,
          sequenceNumber: 1,
        ),
        msg(id: 'm-blocked', sender: 'device-b', plaintext: 'x'),
      ]);

      final failed = c.rows.firstWhere((r) => r.id == 'm-fail');
      final blocked = c.rows.firstWhere((r) => r.id == 'm-blocked');

      // Both have a null body, and that is exactly why the flag has to be
      // separate: the human's instruction was "do not describe it as
      // undecryptable, failed to load, or otherwise imply a
      // cryptographic/decryption failure". One bit distinguishes the two
      // sentences the user reads.
      expect(failed.text, isNull);
      expect(blocked.text, isNull);
      expect(failed.senderIsBlocked, isFalse);
      expect(blocked.senderIsBlocked, isTrue);
    });
  });

  group('EARS-GROUP-25 — membership events render as event lines', () {
    test('test_EARS_GROUP_25_events_render_and_interleave_by_timestamp',
        () async {
      await db.into(db.groupEvents).insert(
            GroupEventsCompanion.insert(
              id: 'e1',
              groupId: _groupId,
              epoch: 1,
              kind: GroupEventKind.memberAdded.name,
              actorDeviceId: 'device-a',
              subjectDeviceId: const Value('device-d'),
              createdAt: 2500,
            ),
          );

      final c = build();
      await c.render([
        msg(id: 'm1', sender: 'device-a', plaintext: 'first', createdAt: 2000),
        msg(id: 'm2', sender: 'device-a', plaintext: 'last', createdAt: 3000),
      ]);

      expect(c.rows.map((r) => r.id), ['m1', 'e1', 'm2']);
      final event = c.rows[1];
      expect(event.isEvent, isTrue);
      expect(event.text, 'device-a added device-d');
      expect(
        event.senderDeviceId,
        isNull,
        reason: 'an event line is not a bubble and carries no attribution',
      );
    });

    test('test_E07_T18_an_unknown_event_kind_is_rendered_not_dropped',
        () async {
      await db.into(db.groupEvents).insert(
            GroupEventsCompanion.insert(
              id: 'e-weird',
              groupId: _groupId,
              epoch: 1,
              kind: 'somethingFromAFutureBuild',
              actorDeviceId: 'device-a',
              createdAt: 2500,
            ),
          );

      final c = build();
      await c.render([]);

      // Under-reporting a group's own history would be worse than a vague
      // sentence.
      expect(c.rows, hasLength(1));
      expect(c.rows.single.text, 'device-a changed the group');
    });
  });

  group('EARS-GROUP-26 — sending goes through the GROUP path', () {
    test('test_EARS_GROUP_26_send_uses_the_group_seam_with_the_group_id',
        () async {
      String? sentGroupId;
      String? sentBody;
      final c = GroupThreadController(
        groupId: _groupId,
        repo: repo,
        groups: groups,
        relationships: relationships,
        send: ({required groupId, required body}) async {
          sentGroupId = groupId;
          sentBody = utf8.decode(body);
          return null;
        },
      );
      await c.send('  hello team  ');

      expect(sentGroupId, _groupId);
      expect(sentBody, 'hello team', reason: 'trimmed before sending');
      expect(c.sendError.value, isEmpty);
      expect(c.sending.value, isFalse);
    });

    test('test_EARS_GROUP_26_a_failure_surfaces_and_does_not_wedge_the_composer',
        () async {
      var calls = 0;
      final c = GroupThreadController(
        groupId: _groupId,
        repo: repo,
        groups: groups,
        relationships: relationships,
        send: ({required groupId, required body}) async {
          calls++;
          return const AppFailure('group.send_failed');
        },
      );
      await c.send('x');

      expect(calls, 1);
      expect(c.sendError.value, isNotEmpty);
      expect(
        c.sending.value,
        isFalse,
        reason: 'E07-B05: a flag left true wedges the composer for the life '
            'of the screen',
      );
    });

    test('test_E07_T18_an_empty_message_is_never_sent', () async {
      var calls = 0;
      final c = GroupThreadController(
        groupId: _groupId,
        repo: repo,
        groups: groups,
        relationships: relationships,
        send: ({required groupId, required body}) async {
          calls++;
          return null;
        },
      );
      await c.send('   ');
      // A call counter, not fail(): a fail() inside an injected seam is
      // swallowed by the caller's catch.
      expect(calls, 0);
    });
  });

  test('test_E07_T18_load_names_the_group_and_subscribes', () async {
    final c = build();
    await c.load();
    expect(c.groupName.value, 'Team');
    // Closed explicitly: `load` subscribes to a live Drift stream, and a
    // subscription outliving its test fires `render` against a database
    // `tearDown` has already closed. That is a test-hygiene bug, not a
    // product one, but it fails the suite just as loudly.
    c.onClose();
  });

  test('test_E07_T18_a_missing_group_is_an_error_state_not_a_blank_screen',
      () async {
    final c = GroupThreadController(
      groupId: 'g:does-not-exist',
      repo: repo,
      groups: groups,
      relationships: relationships,
      send: ({required groupId, required body}) async => null,
    );
    await c.load();
    expect(c.state.value, GroupThreadState.error);
  });
}
