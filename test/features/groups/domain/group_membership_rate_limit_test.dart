// Tests for E13-T04: rate-limiting group-invitation spam on
// `GroupMembershipService` (`FR-ABUSE-001`, EARS-ABUSE-8/9).
//
// **Deviation disclosed here too (matches the task's own §5 doc comment on
// `createGroup`):** the task file names `_perform` as "the shared apply/send
// helper both funnel through" and asks for a single gate there. Reading
// `group_membership_service.dart` in full (the task's own required
// verification step) shows that assumption is false: `createGroup` never
// calls `_perform` at all -- it builds its own `GroupControlFrame` and fans
// out directly. So this suite exercises TWO gate call sites, not one:
// `createGroup` itself, and `_perform` (scoped to `GroupAction.addMember`,
// reached via `GroupMembershipService.addMember`) -- both sharing one bucket
// key so one device's combined create+add rate is bounded by a single
// budget.
//
// Each test constructs `GroupMembershipService` with a small, injected
// `groupInviteRateLimitMaxCount`/`groupInviteRateLimitWindow` so the "over
// limit" behaviour is provable in a handful of calls, deterministically,
// without depending on wall-clock time or the large production default.
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/domain/group_membership_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'group-membership-rl-${suffixCounter++}';

  /// Mirrors `group_membership_service_test.dart`'s own `newStack`: each
  /// simulated device gets its own `AppDatabase`, so each test's rate-limit
  /// bucket starts fresh regardless of what any other test in this suite
  /// did.
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

  group('group-invite rate limiting (EARS-ABUSE-8/9)', () {
    late MessagingStack a;
    late GroupRepository repo;

    setUp(() async {
      final suffix = nextSuffix();
      a = await newStack('device-owner', suffix);
      repo = GroupRepository(a.db);
      // E04-B05: `GroupMembershipService._sendOne`'s `ensureSession` call
      // now sends its first-contact request via `_stack.directSend`
      // (connect-then-send). This suite's members (`member-a`/`member-b`)
      // are never real, reachable devices -- deliberately unmocked before
      // this task, relying on a fast transport failure so `_sendOne`'s own
      // `catch (_) {}` swallows it quickly and the local change (this
      // suite's actual subject) still commits. `TransportApi.connect`,
      // unlike `TransportApi.send`, does not fail fast when unmocked in
      // this test harness (its own settle future has no test-side event to
      // resolve it) -- mock it to fail immediately, matching the "member
      // isn't actually reachable" reality this suite already assumes.
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.connect.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[false]),
      );
    });

    tearDown(() => a.dispose());

    test('test_EARS_ABUSE_8_create_group_over_limit_is_denied', () async {
      final service = GroupMembershipService(
        stack: a,
        repository: repo,
        relationshipRepository: RelationshipRepository(a.db),
        groupInviteRateLimitMaxCount: 1,
        groupInviteRateLimitWindow: const Duration(minutes: 10),
      );

      final firstId = await service.createGroup(
        name: 'G1',
        memberDeviceIds: [],
      );
      expect(firstId, isNotEmpty);
      expect(service.counters.groupRateLimited, 0);

      var threw = false;
      try {
        await service.createGroup(name: 'G2', memberDeviceIds: []);
      } on AppFailure catch (e) {
        threw = true;
        expect(e.code, 'group.rate_limited');
      }
      expect(threw, isTrue, reason: 'second createGroup must throw AppFailure');
      expect(service.counters.groupRateLimited, 1);
    });

    test('test_EARS_ABUSE_8_add_member_over_limit_is_denied', () async {
      final service = GroupMembershipService(
        stack: a,
        repository: repo,
        relationshipRepository: RelationshipRepository(a.db),
        groupInviteRateLimitMaxCount: 1,
        groupInviteRateLimitWindow: const Duration(minutes: 10),
      );

      // Local test setup via the repository directly (as
      // `group_membership_service_test.dart` already does) -- this does not
      // draw from the service-level rate-limit bucket at all, only real
      // `GroupMembershipService.addMember` calls below do.
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-owner',
        memberDeviceIds: [],
      );

      final allowed = await service.addMember(groupId, 'member-a');
      expect(allowed, isNull);
      expect(await repo.roleOf(groupId, 'member-a'), GroupRole.member);

      final denied = await service.addMember(groupId, 'member-b');
      expect(denied?.code, 'group.rate_limited');
      expect(service.counters.groupRateLimited, 1);
      // The denied add must never have reached the repository -- no wire
      // frame, no local mutation either.
      expect(await repo.roleOf(groupId, 'member-b'), isNull);
    });

    test('test_EARS_ABUSE_9_under_limit_behaves_unchanged', () async {
      final service = GroupMembershipService(
        stack: a,
        repository: repo,
        relationshipRepository: RelationshipRepository(a.db),
        groupInviteRateLimitMaxCount: 5,
        groupInviteRateLimitWindow: const Duration(minutes: 10),
      );

      final groupId = await service.createGroup(
        name: 'G',
        memberDeviceIds: [],
      );
      expect(groupId, isNotEmpty);

      final failure = await service.addMember(groupId, 'member-a');
      expect(failure, isNull);
      expect(await repo.roleOf(groupId, 'member-a'), GroupRole.member);
      expect(service.counters.groupRateLimited, 0);
    });

    test(
      'create and add share one bucket -- a create can exhaust the budget '
      'an add would otherwise have used',
      () async {
        final service = GroupMembershipService(
          stack: a,
          repository: repo,
          relationshipRepository: RelationshipRepository(a.db),
          groupInviteRateLimitMaxCount: 2,
          groupInviteRateLimitWindow: const Duration(minutes: 10),
        );

        final groupId = await service.createGroup(
          name: 'G',
          memberDeviceIds: [],
        );
        // Budget of 2: 1 already spent by createGroup above, 1 left.
        expect(await service.addMember(groupId, 'member-a'), isNull);
        // Budget now exhausted.
        final denied = await service.addMember(groupId, 'member-b');
        expect(denied?.code, 'group.rate_limited');
      },
    );

    test(
      'the rate-limit gate never rate-limits an unrelated _perform action '
      'like rename',
      () async {
        final service = GroupMembershipService(
          stack: a,
          repository: repo,
          relationshipRepository: RelationshipRepository(a.db),
          groupInviteRateLimitMaxCount: 1,
          groupInviteRateLimitWindow: const Duration(minutes: 10),
        );

        final groupId = await repo.createGroup(
          name: 'G',
          ownerDeviceId: 'device-owner',
          memberDeviceIds: [],
        );

        // Exhaust the group-invite budget via addMember.
        expect(await service.addMember(groupId, 'member-a'), isNull);
        expect(
          (await service.addMember(groupId, 'member-b'))?.code,
          'group.rate_limited',
        );

        // rename shares `_perform` with addMember but is NOT part of the
        // group-invitation vector this task closes -- it must still
        // succeed even though the shared bucket is exhausted.
        expect(await service.rename(groupId, 'renamed'), isNull);
      },
    );
  });
}
