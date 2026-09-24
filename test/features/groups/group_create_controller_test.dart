// E07-T15 — `/groups/new` controller tests, named by EARS id.
//
// A real in-memory Drift database backs `RelationshipRepository` so the
// trusted-only filter (EARS-GROUP-17) is proved against the real query and
// the real enum<->text conversion, not against a hand-rolled fake that could
// agree with a wrong implementation.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
