// Tests for GroupMembershipService (E07-T03, EARS-GROUP-8/9/10/11).
//
// Two harnesses, matching `prekey_exchange_test.dart`/`delivery_ack_test.dart`'s
// own established patterns:
//   - Direct `handleControlFrame(sourceDeviceId, plaintext)` calls against a
//     hand-seeded group, for scenarios where the interesting behaviour is
//     purely local (permission/epoch checks) -- mirrors
//     `prekey_exchange_test.dart`'s own
//     `test_unsolicited_bundle_response_is_dropped` pattern.
//   - Real two-stack `MessagingStack`s with real Signal sessions for
//     EARS-GROUP-10 (the security property this task exists to prove) and
//     one full round trip, since the authentication claim can only be
//     falsified against a real Double Ratchet session.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/group_control.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/domain/group_membership_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'group-membership-${suffixCounter++}';

  void mockSendAlwaysSucceeds(String suffix) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
      (ByteData? message) async {
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
  }

  /// Mirrors `prekey_exchange_test.dart`'s own `newStack`: each simulated
  /// device gets its own `AppDatabase` and a `DriftSignalProtocolStore`/
  /// `CryptoService.withStore` bound to THAT SAME database — never a store
  /// built against a different database than the stack's own `db` (a
  /// two-database mismatch surfaces as "No signed prekey generated yet",
  /// since `ensureSignedPreKey()` and `getLocalPreKeyBundle()` must read and
  /// write the same underlying storage).
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

  GroupMembershipService serviceFor(
    MessagingStack stack, {
    Duration fanOutSessionTimeout = const Duration(milliseconds: 50),
  }) =>
      GroupMembershipService(
        stack: stack,
        repository: GroupRepository(stack.db),
        relationshipRepository: RelationshipRepository(stack.db),
        fanOutSessionTimeout: fanOutSessionTimeout,
      );

  group('local permission/epoch checks (EARS-GROUP-9/11)', () {
    late MessagingStack a;
    late GroupRepository repo;
    late GroupMembershipService service;

    setUp(() async {
      a = await newStack('device-owner', nextSuffix());
      repo = GroupRepository(a.db);
      service = GroupMembershipService(
        stack: a,
        repository: repo,
        relationshipRepository: RelationshipRepository(a.db),
      );
    });

    tearDown(() => a.dispose());

    Uint8List frameBytes({
      required GroupEventKind kind,
      required String groupId,
      required int epoch,
      required String actorDeviceId,
      String? subjectDeviceId,
      String? name,
    }) =>
        GroupControlFrame(
          kind: kind,
          groupId: groupId,
          epoch: epoch,
          actorDeviceId: actorDeviceId,
          subjectDeviceId: subjectDeviceId,
          name: name,
          createdAtMs: 1,
        ).serialize();

    test('test_EARS_GROUP_9_member_removal_frame_from_a_member_is_refused',
        () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-owner',
        memberDeviceIds: ['member-a', 'member-b'],
      );

      await service.handleControlFrame(
        'member-a',
        frameBytes(
          kind: GroupEventKind.memberRemoved,
          groupId: groupId,
          epoch: 1,
          actorDeviceId: 'member-a',
          subjectDeviceId: 'member-b',
        ),
      );

      expect(service.counters.groupForbidden, 1);
      expect(await repo.roleOf(groupId, 'member-b'), GroupRole.member);
    });

    test('test_EARS_GROUP_11_replayed_frame_is_idempotent', () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-owner',
        memberDeviceIds: [],
      );
      final bytes = frameBytes(
        kind: GroupEventKind.renamed,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'device-owner',
        name: 'once',
      );

      await service.handleControlFrame('device-owner', bytes);
      await service.handleControlFrame('device-owner', bytes);

      expect(service.counters.groupReplayed, 1);
      final group = await repo.groupRow(groupId);
      expect(group!.membershipEpoch, 1);
    });

    test('test_EARS_GROUP_11_epoch_gap_is_parked_not_applied', () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-owner',
        memberDeviceIds: [],
      );

      await service.handleControlFrame(
        'device-owner',
        frameBytes(
          kind: GroupEventKind.renamed,
          groupId: groupId,
          epoch: 9,
          actorDeviceId: 'device-owner',
          name: 'skipped',
        ),
      );

      expect(service.counters.groupOutOfOrder, 1);
      final group = await repo.groupRow(groupId);
      expect(group!.membershipEpoch, 0);
      expect(group.name, 'G');
    });

    test('a malformed plaintext body is dropped, not thrown', () async {
      await service.handleControlFrame('device-owner', Uint8List(0));
      expect(service.counters.groupForbidden, 0);
      expect(service.counters.groupUnauthenticated, 0);
    });

    test('test_blocked_device_cannot_be_added_locally', () async {
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-owner',
        memberDeviceIds: [],
      );
      await RelationshipRepository(a.db).upsert(
        'blocked-device',
        RelationshipState.blocked,
      );

      final failure = await service.addMember(groupId, 'blocked-device');

      expect(failure?.code, 'group.blocked_member');
      expect(await repo.roleOf(groupId, 'blocked-device'), isNull);
    });
  });

  group('fan-out never blocks the local write (EARS-GROUP-8)', () {
    test(
      'test_EARS_GROUP_8_local_write_is_not_blocked_by_a_failing_member_send',
      () async {
        final suffix = nextSuffix();
        final a = await newStack('device-owner', suffix);
        addTearDown(a.dispose);
        mockSendAlwaysSucceeds(suffix);

        final repo = GroupRepository(a.db);
        final groupId = await repo.createGroup(
          name: 'Old Name',
          ownerDeviceId: 'device-owner',
          memberDeviceIds: ['unreachable-device'],
        );
        final service = serviceFor(a);

        final stopwatch = Stopwatch()..start();
        final failure = await service.rename(groupId, 'New Name');
        stopwatch.stop();

        expect(failure, isNull);
        // Bounded well under a real 20s prekey-exchange timeout -- the short
        // `fanOutSessionTimeout` this test injects proves the local write
        // does not ride behind the unreachable member's own network attempt
        // any longer than that bound, and definitely never blocks on it
        // indefinitely.
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));

        final group = await repo.groupRow(groupId);
        expect(group!.name, 'New Name');
        expect(group.membershipEpoch, 1);
      },
    );
  });

  group('real two-stack round trip (EARS-GROUP-8/10)', () {
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
      final ByteData message = TransportEventsApi.pigeonChannelCodec
          .encodeMessage(<Object?>[device])!;
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

    Future<void> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    Future<void> connectPeer(String suffix, String deviceId) async {
      pushDiscovered(suffix, deviceId);
      await settle();
      pushConnectionState(suffix, deviceId, ConnectionState.connected);
      await settle();
    }

    /// Bootstraps real, mutual Signal sessions between [a] and [b] without
    /// going through `PrekeyExchange` (this test only needs the sessions to
    /// exist, not to exercise first-contact bundle exchange, which is
    /// E06-T07's own suite) -- `a` initiates via X3DH against `b`'s bundle,
    /// then `b` decrypts one real ciphertext from `a`, which is exactly how
    /// the library's own responder-side session establishment works.
    Future<void> establishMutualSessions(
      MessagingStack a,
      MessagingStack b,
    ) async {
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
    }

    test('test_EARS_GROUP_10_forged_actor_id_is_discarded', () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await establishMutualSessions(a, b);

      final repoA = GroupRepository(a.db);
      final groupId = await repoA.createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-b'],
      );

      // A frame whose PLAINTEXT claims the actor is the Owner ('device-a'),
      // but which is encrypted (and therefore, by construction, actually
      // sent) through the MEMBER's ('device-b') own session.
      final forged = GroupControlFrame(
        kind: GroupEventKind.memberRemoved,
        groupId: groupId,
        epoch: 1,
        actorDeviceId: 'device-a',
        subjectDeviceId: 'device-a',
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

      await a.groupMembershipService.handleWireFrame(wireFrame);

      expect(a.groupMembershipService.counters.groupUnauthenticated, 1);
      // The table is untouched -- device-a is still Owner, still present.
      expect(await repoA.roleOf(groupId, 'device-a'), GroupRole.owner);
      final group = await repoA.groupRow(groupId);
      expect(group!.membershipEpoch, 0);
    });

    test('a genuine rename fans out and applies on the receiving device',
        () async {
      final aSuffix = nextSuffix();
      final bSuffix = nextSuffix();
      final a = await newStack('device-a', aSuffix);
      final b = await newStack('device-b', bSuffix);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await establishMutualSessions(a, b);
      wireSend(aSuffix, 'device-a', bSuffix);

      b.inbound.start();
      await connectPeer(bSuffix, 'device-a');
      // A direct one-hop link so RelayEngine.processQueue() on A has a real
      // route to device-b (mirrors messaging_coordinator_test.dart's own
      // pattern).
      a.routingEngine.recordLinkMeasurement(
        'device-b',
        latencyMs: 10,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );

      final groupId = await GroupRepository(a.db).createGroup(
        name: 'Old Name',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-b'],
      );
      // The receiving device already knows this group and its founding
      // epoch (this test isolates the `renamed` fan-out itself, not the
      // `created` bootstrap, which has its own repository-level coverage).
      final repoB = GroupRepository(b.db);
      await repoB.applyEvent(
        GroupControlFrame(
          kind: GroupEventKind.created,
          groupId: groupId,
          epoch: 0,
          actorDeviceId: 'device-a',
          name: 'Old Name',
          memberList: const ['device-a', 'device-b'],
          createdAtMs: 0,
        ),
      );

      final serviceA = serviceFor(a);
      final failure = await serviceA.rename(groupId, 'New Name');
      expect(failure, isNull);

      await a.relayEngine.processQueue();
      await settle();
      await settle();

      final groupOnB = await repoB.groupRow(groupId);
      expect(groupOnB!.name, 'New Name');
      expect(groupOnB.membershipEpoch, 1);
    });
  });
}
