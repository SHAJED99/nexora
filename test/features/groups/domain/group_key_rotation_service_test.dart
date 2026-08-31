// Tests for GroupKeyRotationService (E07-T05, EARS-GROUP-1/2/15/16).
//
// Mirrors `group_crypto_service_test.dart`'s (E07-T04) own two harnesses:
//   - A single-stack harness for scenarios that only need one device's own
//     store and repository (order, invariant, "empty recipient set is a
//     no-op", "delete discards every epoch").
//   - Real two-stack `MessagingStack`s with real Signal sessions and genuine
//     wire delivery for the security properties this task exists to prove
//     (EARS-GROUP-2's new-member exclusion, EARS-GROUP-15's removed-member
//     exclusion) — falsifiable only against a real Double Ratchet session
//     and a real received distribution, never against an in-memory fake.
//
// This file constructs `GroupKeyRotationService` directly and drives it via
// `onEpochApplied`/`onRemoteEpochApplied` — it does NOT go through
// `GroupMembershipService`'s eight actions. `GroupRepository.applyEvent` is
// called directly to bump `membership_epoch` for each scenario, exactly
// mirroring how `group_repository_test.dart`/`group_crypto_service_test.dart`
// already build scenarios one layer below the full action surface. The
// wiring into `GroupMembershipService` itself (both the local-action path
// and `handleControlFrame`'s remote-apply path) is proven separately by
// `group_membership_service_test.dart`'s own existing suite, which this
// task's wiring change kept green (see this task's Run log).
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/group_crypto_service.dart';
import 'package:nexora/core/messaging/group_control.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/domain/group_key_rotation_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart' as trust;

/// A thin recording wrapper over the real [GroupCryptoService] (E07-T04) --
/// delegates every call to `super`, so all behaviour is the genuine
/// libsignal-backed implementation, but also appends a tag to [callOrder]
/// so the mint -> distribute -> discard sequence (task file §2/§6) can be
/// falsified directly rather than only inferred from final state. A buggy
/// re-ordering (e.g. discard before distribute) would still often produce
/// the same final DB state in this schema (discard's threshold never
/// touches the just-minted epoch either way) -- this is the only way to
/// prove the SEQUENCE, not merely the outcome.
class _OrderRecordingGroupCryptoService extends GroupCryptoService {
  _OrderRecordingGroupCryptoService({required super.stack});

  final List<String> callOrder = [];

  @override
  Future<Uint8List> ensureOwnChain({
    required String groupId,
    required int epoch,
  }) async {
    callOrder.add('mint:$epoch');
    return super.ensureOwnChain(groupId: groupId, epoch: epoch);
  }

  @override
  Future<Map<String, AppFailure?>> distributeTo({
    required String groupId,
    required int epoch,
    required List<String> recipientDeviceIds,
  }) async {
    callOrder.add('distribute:$epoch');
    return super.distributeTo(
      groupId: groupId,
      epoch: epoch,
      recipientDeviceIds: recipientDeviceIds,
    );
  }

  @override
  Future<int> discardChains({
    required String groupId,
    required int belowEpoch,
  }) async {
    callOrder.add('discard:$belowEpoch');
    return super.discardChains(groupId: groupId, belowEpoch: belowEpoch);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'group-rotation-${suffixCounter++}';

  void mockSendAlwaysSucceeds(String suffix) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
      (ByteData? message) async {
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );
  }

  /// Mirrors `group_crypto_service_test.dart`'s own `newStack`.
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

  /// Bumps `membership_epoch` for [groupId] on [stack]'s own database via
  /// `GroupRepository.applyEvent` -- the same single writer of the epoch
  /// column this task's own §2 relies on (E07-T03) -- without going through
  /// `GroupMembershipService`'s permission-checked action surface, exactly
  /// mirroring `group_repository_test.dart`/`group_crypto_service_test.dart`'s
  /// own established pattern of driving `GroupRepository` directly.
  Future<void> bumpEpoch(
    MessagingStack stack, {
    required String groupId,
    required GroupEventKind kind,
    required int epoch,
    String? subjectDeviceId,
    String? name,
  }) async {
    final frame = GroupControlFrame(
      kind: kind,
      groupId: groupId,
      epoch: epoch,
      actorDeviceId: stack.selfDeviceId,
      subjectDeviceId: subjectDeviceId,
      name: name,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final failure = await GroupRepository(stack.db).applyEvent(frame);
    expect(
      failure,
      isNull,
      reason: 'test setup: applyEvent must succeed (got $failure)',
    );
  }

  /// The §3 invariant this whole task exists to hold: `group_sender_keys`
  /// must contain no row below the group's own current `membership_epoch`.
  /// Asserted after EVERY rotation in this file's tests, not once (task
  /// file §6's own instruction).
  Future<void> assertNoStaleChains(MessagingStack stack, String groupId) async {
    final group = await GroupRepository(stack.db).groupRow(groupId);
    expect(group, isNotNull);
    final currentEpoch = group!.membershipEpoch;
    final staleRows = await (stack.db.select(stack.db.groupSenderKeys)
          ..where(
            (t) =>
                t.groupId.equals(groupId) &
                t.membershipEpoch.isSmallerThanValue(currentEpoch),
          ))
        .get();
    expect(
      staleRows,
      isEmpty,
      reason: 'group_sender_keys must hold no row below the group\'s '
          'current membership_epoch ($currentEpoch)',
    );
  }

  group('single-device: order, invariant, empty-set, delete (E07-T05)', () {
    late MessagingStack a;
    late GroupRepository repo;
    late _OrderRecordingGroupCryptoService crypto;
    late GroupKeyRotationService rotation;
    late String groupId;

    setUp(() async {
      final suffix = nextSuffix();
      mockSendAlwaysSucceeds(suffix);
      a = await newStack('device-a', suffix);
      repo = GroupRepository(a.db);
      crypto = _OrderRecordingGroupCryptoService(stack: a);
      rotation = GroupKeyRotationService(
        groups: repo,
        crypto: crypto,
        selfDeviceId: 'device-a',
      );
      groupId = await repo.createGroup(
        name: 'Solo',
        ownerDeviceId: 'device-a',
        memberDeviceIds: [],
      );
    });

    tearDown(() => a.dispose());

    test(
        'test_EARS_GROUP_1_epoch_change_mints_a_new_chain_and_discards_the_old',
        () async {
      // Seed an epoch-0 chain directly (creation itself does not mint one --
      // that is E07-T06's job) so there is something for the rotation's
      // own discard step to actually remove.
      await crypto.ensureOwnChain(groupId: groupId, epoch: 0);
      crypto.callOrder.clear();

      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.adminGranted,
        epoch: 1,
        subjectDeviceId: 'device-a',
      );
      final results = await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 1,
        kind: GroupEventKind.adminGranted,
      );
      expect(results, isEmpty); // no members besides self

      // mint -> distribute -> discard, in that order (task file §2/§6).
      // The second `mint:1` is `GroupCryptoService.distributeTo`'s OWN
      // internal `ensureOwnChain` call (E07-T04) -- idempotent, the same
      // chain, never a re-mint -- not a second rotation step; what matters
      // is that no `discard` entry appears before either `mint` or the
      // `distribute` entry.
      expect(
        crypto.callOrder,
        ['mint:1', 'distribute:1', 'mint:1', 'discard:1'],
      );

      final rows =
          await (a.db.select(a.db.groupSenderKeys)
                ..where((t) => t.groupId.equals(groupId)))
              .get();
      expect(rows, hasLength(1));
      expect(rows.single.membershipEpoch, 1);

      await assertNoStaleChains(a, groupId);
    });

    test('test_EARS_GROUP_1_rename_also_rotates', () async {
      // The documented §2 consequence: a rename bumps the epoch exactly
      // like any membership action, and this file has no per-action list
      // that could skip it.
      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.renamed,
        epoch: 1,
        name: 'New Name',
      );
      await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 1,
        kind: GroupEventKind.renamed,
      );

      final rows =
          await (a.db.select(a.db.groupSenderKeys)
                ..where((t) => t.groupId.equals(groupId)))
              .get();
      expect(
        rows,
        hasLength(1),
        reason: 'a rename must mint a chain at the new epoch just like any '
            'other membership action',
      );
      expect(rows.single.membershipEpoch, 1);
      await assertNoStaleChains(a, groupId);
    });

    test('test_distribute_to_empty_member_set_is_a_no_op_success', () async {
      // The last-member-leaves / single-member-group case: recipients is
      // empty, and this must be a no-op success, never an error or crash.
      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.renamed,
        epoch: 1,
        name: 'Still Solo',
      );
      final results = await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 1,
        kind: GroupEventKind.renamed,
      );
      expect(results, isEmpty);
    });

    test('test_EARS_GROUP_16_delete_discards_every_epoch', () async {
      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.renamed,
        epoch: 1,
        name: 'About to be deleted',
      );
      await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 1,
        kind: GroupEventKind.renamed,
      );
      var rows =
          await (a.db.select(a.db.groupSenderKeys)
                ..where((t) => t.groupId.equals(groupId)))
              .get();
      expect(rows, hasLength(1)); // epoch 1's chain exists before delete

      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.deleted,
        epoch: 2,
      );
      crypto.callOrder.clear();
      final results = await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 2,
        kind: GroupEventKind.deleted,
      );
      expect(results, isEmpty);

      // discard runs twice: once for step 3 (belowEpoch: 2), once more via
      // discardAllFor for step 4's "deleted -> everything" (belowEpoch: 3)
      // -- not an optimization to skip 1-3, exactly as the task file says.
      // The second `mint:2` is `distributeTo`'s own internal
      // `ensureOwnChain` call, same as above.
      expect(
        crypto.callOrder,
        ['mint:2', 'distribute:2', 'mint:2', 'discard:2', 'discard:3'],
      );

      rows =
          await (a.db.select(a.db.groupSenderKeys)
                ..where((t) => t.groupId.equals(groupId)))
              .get();
      expect(
        rows,
        isEmpty,
        reason: 'a deleted group must retain NO chain, including the one '
            'just minted for the delete epoch itself',
      );
    });

    test(
        'test_EARS_GROUP_2_no_api_exists_to_grant_historical_access',
        () async {
      // OQ-E07-1's decision (v1 has no exception path) made mechanically
      // checkable: no CODE line (comments excluded -- this very file's own
      // header prose necessarily discusses "history" at length) in
      // group_key_rotation_service.dart names a history/since/include-style
      // parameter or identifier.
      final file = File(
        'lib/features/groups/domain/group_key_rotation_service.dart',
      );
      final source = file.readAsStringSync();
      final codeOnly = source
          .split('\n')
          .where((line) => !line.trim().startsWith('//'))
          .join('\n');
      final forbidden = RegExp(
        r'[Hh]istory|since[A-Z][A-Za-z]*|include[A-Z][A-Za-z]*|shareHistory',
      );
      expect(
        forbidden.hasMatch(codeOnly),
        isFalse,
        reason: 'no history-sharing parameter or identifier may exist in '
            'the rotation service\'s actual code (OQ-E07-1)',
      );

      // Belt and braces: the three real public methods take exactly the
      // documented named parameters -- calling any of them with an extra
      // named argument is a compile error, which is itself part of the
      // mechanical proof (this call only compiles because the signature is
      // exactly {groupId, newEpoch, kind}).
      final result = await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 0,
        kind: GroupEventKind.created,
      );
      expect(result, isA<Map<String, AppFailure?>>());
    });
  });

  group('two-device: EARS-GROUP-2 / EARS-GROUP-15 (real crypto)', () {
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

    /// Delivers whatever A has enqueued for B for real: wires the mock
    /// transport, starts B's inbound pipeline, connects the peer so B's
    /// pipeline actually subscribes, gives A a real one-hop route, and
    /// drains A's queue. Mirrors `group_crypto_service_test.dart`'s own
    /// EARS-GROUP-13 test end to end.
    Future<void> deliver(
      MessagingStack a,
      String aSuffix,
      MessagingStack b,
      String bSuffix,
    ) async {
      wireSend(aSuffix, a.selfDeviceId, bSuffix);
      b.inbound.start();
      await connectPeer(bSuffix, a.selfDeviceId);
      a.routingEngine.recordLinkMeasurement(
        b.selfDeviceId,
        latencyMs: 10,
        lossRate: 0.0,
        batteryDrain: 0.1,
      );
      await a.relayEngine.processQueue();
      await settle();
      await settle();
    }

    test(
        'test_EARS_GROUP_2_member_added_at_epoch_n_cannot_decrypt_epoch_n_minus_1',
        () async {
      final aSuffix = nextSuffix();
      final cSuffix = nextSuffix();
      mockSendAlwaysSucceeds(aSuffix);
      mockSendAlwaysSucceeds(cSuffix);
      final a = await newStack('device-a', aSuffix);
      final c = await newStack('device-c', cSuffix);
      addTearDown(a.dispose);
      addTearDown(c.dispose);

      final repo = GroupRepository(a.db);
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: [],
      );

      // A's epoch-0 chain and a message encrypted under it -- the
      // "historical" message a later joiner must never be able to read.
      await a.groupCryptoService.ensureOwnChain(groupId: groupId, epoch: 0);
      final historicalCiphertext = await a.groupCryptoService.encryptForGroup(
        groupId: groupId,
        epoch: 0,
        plaintext: Uint8List.fromList('before you joined'.codeUnits),
      );

      // C joins at epoch 1.
      await establishMutualSessions(a, c);
      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.memberAdded,
        epoch: 1,
        subjectDeviceId: 'device-c',
      );
      final rotation = GroupKeyRotationService(
        groups: repo,
        crypto: a.groupCryptoService,
        selfDeviceId: 'device-a',
      );
      final results = await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 1,
        kind: GroupEventKind.memberAdded,
      );
      expect(results['device-c'], isNull);

      await deliver(a, aSuffix, c, cSuffix);

      final cChains = await c.db.select(c.db.groupSenderKeys).get();
      expect(
        cChains,
        hasLength(1),
        reason: 'C must have received epoch 1\'s distribution',
      );
      expect(cChains.single.membershipEpoch, 1);

      // C can decrypt a fresh epoch-1 message...
      final freshCiphertext = await a.groupCryptoService.encryptForGroup(
        groupId: groupId,
        epoch: 1,
        plaintext: Uint8List.fromList('after you joined'.codeUnits),
      );
      final freshPlaintext = await c.groupCryptoService.decryptFromGroup(
        groupId: groupId,
        epoch: 1,
        senderDeviceId: 'device-a',
        bytes: freshCiphertext,
      );
      expect(String.fromCharCodes(freshPlaintext), 'after you joined');

      // ...but the pre-join, epoch-0 message fails explicitly, never
      // silently, and never as corrupted/empty plaintext (EARS-GROUP-2).
      await expectLater(
        c.groupCryptoService.decryptFromGroup(
          groupId: groupId,
          epoch: 0,
          senderDeviceId: 'device-a',
          bytes: historicalCiphertext,
        ),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'group.no_chain'),
        ),
      );

      await assertNoStaleChains(a, groupId);
    });

    test(
        'test_EARS_GROUP_15_removed_member_is_not_a_distribution_recipient',
        () async {
      final aSuffix = nextSuffix();
      final cSuffix = nextSuffix();
      mockSendAlwaysSucceeds(aSuffix);
      mockSendAlwaysSucceeds(cSuffix);
      final a = await newStack('device-a', aSuffix);
      final c = await newStack('device-c', cSuffix);
      addTearDown(a.dispose);
      addTearDown(c.dispose);

      final repo = GroupRepository(a.db);
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-c'],
      );

      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.memberRemoved,
        epoch: 1,
        subjectDeviceId: 'device-c',
      );

      final rotation = GroupKeyRotationService(
        groups: repo,
        crypto: a.groupCryptoService,
        selfDeviceId: 'device-a',
      );
      final results = await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 1,
        kind: GroupEventKind.memberRemoved,
      );

      expect(
        results.containsKey('device-c'),
        isFalse,
        reason: 'a removed member must never even be offered as a '
            'distribution recipient -- GroupRepository.currentMembers '
            'already excludes them',
      );
      expect(results, isEmpty); // A is now the only member, minus self

      final packets = await a.db.select(a.db.relayPackets).get();
      expect(
        packets,
        isEmpty,
        reason: 'no key-distribution frame may ever be enqueued for a '
            'removed member',
      );

      await assertNoStaleChains(a, groupId);
    });

    test(
        'test_EARS_GROUP_15_removed_member_retaining_its_old_chain_still_fails',
        () async {
      final aSuffix = nextSuffix();
      final cSuffix = nextSuffix();
      mockSendAlwaysSucceeds(aSuffix);
      mockSendAlwaysSucceeds(cSuffix);
      final a = await newStack('device-a', aSuffix);
      final c = await newStack('device-c', cSuffix);
      addTearDown(a.dispose);
      addTearDown(c.dispose);

      final repo = GroupRepository(a.db);
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-c'],
      );

      // C genuinely receives (and retains) the epoch-0 chain, BEFORE being
      // removed -- the "retaining its old chain" premise this test proves
      // is not sufficient to decrypt a later epoch's message.
      await establishMutualSessions(a, c);
      await a.groupCryptoService.distributeTo(
        groupId: groupId,
        epoch: 0,
        recipientDeviceIds: ['device-c'],
      );
      await deliver(a, aSuffix, c, cSuffix);
      final cChainsBefore = await c.db.select(c.db.groupSenderKeys).get();
      expect(cChainsBefore, hasLength(1));
      expect(cChainsBefore.single.membershipEpoch, 0);

      // C is removed at epoch 1.
      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.memberRemoved,
        epoch: 1,
        subjectDeviceId: 'device-c',
      );
      final rotation = GroupKeyRotationService(
        groups: repo,
        crypto: a.groupCryptoService,
        selfDeviceId: 'device-a',
      );
      final results = await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 1,
        kind: GroupEventKind.memberRemoved,
      );
      expect(results, isEmpty); // C excluded; A is now alone

      // A can now send at epoch 1 (its own chain rotated)...
      final epoch1Ciphertext = await a.groupCryptoService.encryptForGroup(
        groupId: groupId,
        epoch: 1,
        plaintext: Uint8List.fromList('after removal'.codeUnits),
      );

      // ...but C, still holding only its retained EPOCH-0 chain, can never
      // decrypt it -- the chain-per-epoch isolation (E07-T04) that makes
      // FR-GROUP-005 structural, not just a matter of who got mailed a
      // distribution frame.
      await expectLater(
        c.groupCryptoService.decryptFromGroup(
          groupId: groupId,
          epoch: 1,
          senderDeviceId: 'device-a',
          bytes: epoch1Ciphertext,
        ),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'group.no_chain'),
        ),
      );

      // C's retained epoch-0 chain is untouched and still exists on C's own
      // device (this task never reaches into a peer's store) -- it is
      // simply the wrong chain for the wrong epoch.
      final cChainsAfter = await c.db.select(c.db.groupSenderKeys).get();
      expect(cChainsAfter, hasLength(1));
      expect(cChainsAfter.single.membershipEpoch, 0);

      await assertNoStaleChains(a, groupId);
    });

    test(
        'test_offline_member_missing_a_rotation_fails_loudly_not_silently',
        () async {
      final aSuffix = nextSuffix();
      final cSuffix = nextSuffix();
      mockSendAlwaysSucceeds(aSuffix);
      mockSendAlwaysSucceeds(cSuffix);
      final a = await newStack('device-a', aSuffix);
      final c = await newStack('device-c', cSuffix);
      addTearDown(a.dispose);
      addTearDown(c.dispose);

      final repo = GroupRepository(a.db);
      final groupId = await repo.createGroup(
        name: 'G',
        ownerDeviceId: 'device-a',
        memberDeviceIds: ['device-c'],
      );

      // 'device-c' is simulated as unreachable: NO session established, and
      // blocked so `PrekeyExchange.ensureSession` fails FAST (an immediate
      // `messaging.peer_blocked`) rather than this test having to wait out
      // the real, non-configurable ~20s bundle-request timeout
      // (`GroupCryptoService`/`PrekeyExchange`, E07-T04/E06-T07) to prove
      // the same point: a per-recipient failure is REPORTED, never
      // swallowed into a false "success".
      await RelationshipRepository(a.db).upsert(
        'device-c',
        trust.RelationshipState.blocked,
      );

      final rotation = GroupKeyRotationService(
        groups: repo,
        crypto: a.groupCryptoService,
        selfDeviceId: 'device-a',
      );

      await bumpEpoch(
        a,
        groupId: groupId,
        kind: GroupEventKind.renamed,
        epoch: 1,
        name: 'renamed while C is unreachable',
      );

      // Must complete (never throw) and must report the failure, not hide
      // it inside a generically-successful-looking return.
      final results = await rotation.onEpochApplied(
        groupId: groupId,
        newEpoch: 1,
        kind: GroupEventKind.renamed,
      );

      expect(results.containsKey('device-c'), isTrue);
      expect(
        results['device-c'],
        isNotNull,
        reason: 'an unreachable recipient\'s failure must be reported in '
            'the returned map, not swallowed into a null (success)',
      );

      // A's own rotation still completed correctly despite the one failed
      // recipient (task file §6: "one failed member send must not abort
      // the others" -- there IS no other recipient here, but A's own mint
      // + discard steps must still have run to completion).
      final aChains = await a.db.select(a.db.groupSenderKeys).get();
      expect(aChains, hasLength(1));
      expect(aChains.single.membershipEpoch, 1);
      await assertNoStaleChains(a, groupId);
    });
  });
}
