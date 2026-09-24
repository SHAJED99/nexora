// E07-T15 — `/groups/new` controller tests, named by EARS id.
//
// A real in-memory Drift database backs `RelationshipRepository` so the
// trusted-only filter (EARS-GROUP-17) is proved against the real query and
// the real enum<->text conversion, not against a hand-rolled fake that could
// agree with a wrong implementation.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/groups/presentation/group_create_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late RelationshipRepository relationships;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relationships = RelationshipRepository(db);
  });

  tearDown(() async => db.close());

  /// A controller with every collaborator injected. [onCreate] defaults to a
  /// call counter that fails the test if creation was not expected.
  GroupCreateController build({
    CreateGroup? onCreate,
    List<String>? openedThreads,
  }) {
    return GroupCreateController(
      relationships: relationships,
      createGroup: onCreate ??
          ({required name, required memberDeviceIds}) async => 'unused',
      openThread: (id) async => openedThreads?.add(id),
    );
  }

  group('EARS-GROUP-17 — only trusted relationships become member rows', () {
    test(
      'test_EARS_GROUP_17_only_trusted_relationships_become_member_rows',
      () async {
        await relationships.upsert('aa:trusted', RelationshipState.trusted);
        await relationships.upsert('bb:allowed', RelationshipState.allowed);
        await relationships.upsert('cc:unknown', RelationshipState.unknown);
        await relationships.upsert('dd:blocked', RelationshipState.blocked);
        await relationships.upsert('ee:trusted', RelationshipState.trusted);

        final c = build();
        await c.load();

        expect(
          c.members.map((m) => m.deviceId).toSet(),
          {'aa:trusted', 'ee:trusted'},
          reason: 'the contract renders devices.md\'s TRUSTED state-label pair '
              '(GC10/GC11, copy "Trusted Node"); showing an allowed, unknown '
              'or blocked peer in it would assert a trust this side has not '
              'given',
        );
        expect(c.state.value, GroupCreateState.data);
      },
    );

    test('test_EARS_GROUP_17_no_trusted_contacts_is_the_empty_state', () async {
      await relationships.upsert('bb:allowed', RelationshipState.allowed);

      final c = build();
      await c.load();

      expect(c.members, isEmpty);
      expect(c.state.value, GroupCreateState.empty);
    });

    test('test_EARS_GROUP_17_initials_derive_from_the_device_id', () async {
      await relationships.upsert('ms:1', RelationshipState.trusted);

      final c = build();
      await c.load();

      // GAP-003: no display-name source exists, so the device id is the
      // honest stand-in and the initials derive from it.
      expect(c.members.single.displayName, 'ms:1');
      expect(c.members.single.initials, 'MS');
    });
  });

  group('EARS-GROUP-18 — create disabled until name AND member', () {
    test('test_EARS_GROUP_18_create_disabled_until_name_and_member', () async {
      await relationships.upsert('aa:trusted', RelationshipState.trusted);
      final c = build();
      await c.load();

      // All four combinations of (name) x (selection).
      expect(c.canCreate, isFalse, reason: 'no name, no member');

      c.setName('Team');
      expect(c.canCreate, isFalse, reason: 'name but no member');

      c.setName('');
      c.toggle('aa:trusted');
      expect(c.canCreate, isFalse, reason: 'member but no name');

      c.setName('Team');
      expect(c.canCreate, isTrue, reason: 'name and member');
    });

    test('test_EARS_GROUP_18_whitespace_only_name_does_not_enable', () async {
      await relationships.upsert('aa:trusted', RelationshipState.trusted);
      final c = build();
      await c.load();
      c.toggle('aa:trusted');

      c.setName('   ');
      expect(c.canCreate, isFalse);
    });

    test('test_EARS_GROUP_18_toggle_is_symmetric', () async {
      await relationships.upsert('aa:trusted', RelationshipState.trusted);
      final c = build();
      await c.load();

      c.toggle('aa:trusted');
      expect(c.selected, {'aa:trusted'});
      c.toggle('aa:trusted');
      expect(c.selected, isEmpty);
    });
  });

  group('EARS-GROUP-19 — create passes the selection and navigates', () {
    test(
      'test_EARS_GROUP_19_create_passes_selected_members_and_navigates',
      () async {
        await relationships.upsert('aa:trusted', RelationshipState.trusted);
        await relationships.upsert('bb:trusted', RelationshipState.trusted);
        await relationships.upsert('cc:trusted', RelationshipState.trusted);

        String? sentName;
        List<String>? sentMembers;
        final opened = <String>[];

        final c = build(
          openedThreads: opened,
          onCreate: ({required name, required memberDeviceIds}) async {
            sentName = name;
            sentMembers = memberDeviceIds;
            return 'group-42';
          },
        );
        await c.load();
        c.setName('  Team  ');
        c.toggle('aa:trusted');
        c.toggle('cc:trusted');

        await c.create();

        expect(sentName, 'Team', reason: 'the name is trimmed');
        expect(
          sentMembers!.toSet(),
          {'aa:trusted', 'cc:trusted'},
          reason: 'exactly the selection — never every trusted contact',
        );
        expect(sentMembers, hasLength(2));
        expect(opened, ['group-42'], reason: 'lands in the new group thread');
      },
    );

    test('test_EARS_GROUP_19_create_is_a_no_op_while_disabled', () async {
      await relationships.upsert('aa:trusted', RelationshipState.trusted);
      var calls = 0;
      final c = build(
        onCreate: ({required name, required memberDeviceIds}) async {
          calls++;
          return 'g';
        },
      );
      await c.load();

      // No name, no selection — the guard must hold even if the view somehow
      // dispatches. A call counter, not `fail()`: a `fail()` inside an
      // injected seam is swallowed by a broad catch in the caller.
      await c.create();
      expect(calls, 0);
    });
  });

  group('EARS-GROUP-20 — failure preserves the name and the selection', () {
    test('test_EARS_GROUP_20_failure_preserves_name_and_selection', () async {
      await relationships.upsert('aa:trusted', RelationshipState.trusted);
      final opened = <String>[];

      final c = build(
        openedThreads: opened,
        onCreate: ({required name, required memberDeviceIds}) async {
          throw const AppFailure('group.rate_limited');
        },
      );
      await c.load();
      c.setName('Team');
      c.toggle('aa:trusted');

      await c.create();

      expect(c.state.value, GroupCreateState.error);
      expect(c.name.value, 'Team', reason: 'contract §States 4: not cleared');
      expect(c.selected, {'aa:trusted'},
          reason: 'contract §States 4: not cleared');
      expect(opened, isEmpty, reason: 'a failed create navigates nowhere');
      expect(c.submitting.value, isFalse, reason: 'the action re-enables');
      expect(c.canCreate, isTrue, reason: 'the person can retry immediately');
    });

    test('test_EARS_GROUP_20_createGroup_throws_it_does_not_return', () async {
      // Guards this task's §6 risk 2. `createGroup` is the ONE method on
      // GroupMembershipService that throws instead of returning
      // Future<AppFailure?>. If a later refactor makes the controller read a
      // returned failure instead of catching, this test fails.
      await relationships.upsert('aa:trusted', RelationshipState.trusted);
      final c = build(
        onCreate: ({required name, required memberDeviceIds}) async {
          throw const AppFailure('group.send_failed');
        },
      );
      await c.load();
      c.setName('Team');
      c.toggle('aa:trusted');

      await expectLater(c.create(), completes);
      expect(c.state.value, GroupCreateState.error);
    });
  });

  test('test_E07_T15_reload_drops_a_selection_that_lost_trust', () async {
    await relationships.upsert('aa:trusted', RelationshipState.trusted);
    final c = build();
    await c.load();
    c.toggle('aa:trusted');
    expect(c.selected, {'aa:trusted'});

    await relationships.upsert('aa:trusted', RelationshipState.blocked);
    await c.load();

    expect(
      c.selected,
      isEmpty,
      reason: 'a selection may not outlive the trust that justified the row',
    );
  });

  group('EARS-GROUP-19b — the DEFAULT destination is not the 1:1 chat', () {
    // E07-B05. Every other test in this file injects `openThread` and then
    // asserts against the spy, so the route a real user reaches was never
    // exercised — which is exactly how `/groups/new` shipped navigating to
    // `/chat/<groupId>`, the destination the human closed to group ids at
    // E07-B01's `bug_priorities` gate (2026-09-02, P1, direction (a)).
    // This test omits the seam on purpose.
    testWidgets(
      'test_EARS_GROUP_19b_successful_create_does_not_open_the_1to1_chat',
      (tester) async {
        await relationships.upsert('aa:trusted', RelationshipState.trusted);

        final c = GroupCreateController(
          relationships: relationships,
          createGroup: ({required name, required memberDeviceIds}) async =>
              'g:team',
          // `openThread` deliberately NOT injected — the default is the SUT.
        );

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/groups/new',
            getPages: <GetPage<dynamic>>[
              GetPage<dynamic>(
                name: '/groups/new',
                page: () => const Scaffold(body: Text('create')),
              ),
              GetPage<dynamic>(
                name: '/conversations',
                page: () => const Scaffold(body: Text('conversations')),
              ),
              GetPage<dynamic>(
                name: '/chat/:id',
                page: () => const Scaffold(body: Text('chat')),
              ),
            ],
          ),
        );

        await c.load();
        c.setName('Team');
        c.toggle('aa:trusted');
        await c.create();
        await tester.pumpAndSettle();

        expect(
          c.submitting.value,
          isFalse,
          reason: 'E07-B05 second finding: Get.offNamed/toNamed complete only '
              'when the pushed route is POPPED. Awaiting one suspends '
              'create() forever, so its finally never runs and the button '
              'stays disabled for the life of the screen.',
        );

        expect(
          Get.currentRoute,
          isNot(startsWith('/chat/')),
          reason: 'ChatController treats its id as a Signal PEER DEVICE id '
              'and runs X3DH against it; a group id there gives '
              'undecryptable bubbles in and a non-retryable send failure '
              'out (E07-B01, measured). Creating a group must not end there.',
        );
        expect(
          Get.currentRoute,
          GroupCreateController.successRoute,
          reason: 'the group exists, so the honest landing is the screen that '
              'renders it — the Groups section of Conversations. The real group '
              'thread is GAP-020, gated on OQ-E07-13.',
        );
      },
    );
  });
}
