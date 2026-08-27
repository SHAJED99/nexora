// Tests for IdentityService (E03-T02, EARS-SEC-3b/3c).
//
// Exercises first-run identity/signed-prekey bootstrap, idempotency,
// one-time-prekey pool replenishment, and PreKeyBundle assembly — all
// against a real in-memory Drift database + real libsignal_protocol_dart
// record objects, per L-backend lessons and E03-T01's established pattern.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/persistence/database.dart';

void main() {
  late AppDatabase db;
  late DriftSignalProtocolStore store;
  late IdentityService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftSignalProtocolStore(db);
    service = IdentityService(db, store);
  });

  tearDown(() => db.close());

  test('test_EARS_SEC_3b_first_run_generates_identity', () async {
    // Fresh store: no identity yet.
    expect(store.getIdentityKeyPair(), throwsStateError);

    await service.ensureLocalIdentity();

    final identityKeyPair = await store.getIdentityKeyPair();
    final registrationId = await store.getLocalRegistrationId();
    expect(identityKeyPair, isNotNull);
    expect(registrationId, isPositive);
  });

  test('test_EARS_SEC_3b_second_call_is_idempotent', () async {
    await service.ensureLocalIdentity();
    final firstPair = await store.getIdentityKeyPair();
    final firstRegistrationId = await store.getLocalRegistrationId();

    // Re-running app startup must not regenerate (task file §2).
    await service.ensureLocalIdentity();
    final secondPair = await store.getIdentityKeyPair();
    final secondRegistrationId = await store.getLocalRegistrationId();

    expect(secondPair.getPublicKey(), firstPair.getPublicKey());
    expect(
      secondPair.getPrivateKey().serialize(),
      firstPair.getPrivateKey().serialize(),
    );
    expect(secondRegistrationId, firstRegistrationId);

    final rows = await db.select(db.signalIdentity).get();
    expect(rows, hasLength(1));
  });

  test('test_EARS_SEC_3b_signed_prekey_generated_once', () async {
    await service.ensureLocalIdentity();

    await service.ensureSignedPreKey();
    final firstRecord = await store.loadSignedPreKey(1);

    // A second call must be a no-op: the existing signed prekey survives
    // untouched (task file §3 "no rotation policy yet for v1").
    await service.ensureSignedPreKey();
    final secondRecord = await store.loadSignedPreKey(1);

    expect(secondRecord.id, firstRecord.id);
    expect(secondRecord.signature, firstRecord.signature);
    expect(
      secondRecord.getKeyPair().publicKey.serialize(),
      firstRecord.getKeyPair().publicKey.serialize(),
    );

    final all = await store.loadSignedPreKeys();
    expect(all, hasLength(1));
  });

  test('test_EARS_SEC_3c_replenishes_below_minimum', () async {
    // Seed the store with fewer than `minimum` one-time prekeys, through
    // the real issuance path (E03-B01: ids are only ever legitimately
    // allocated via replenishOneTimePreKeys/allocateOneTimePreKeyIds, never
    // by writing a chosen id directly — that bypasses the monotonic
    // counter this fix relies on).
    await service.replenishOneTimePreKeys(minimum: 5, batch: 5);

    final generated = await service.replenishOneTimePreKeys(
      minimum: 20,
      batch: 20,
    );

    expect(generated, 20);
    final rows = await db.select(db.signalOneTimePrekeys).get();
    expect(rows, hasLength(25));

    // No id collides with an existing one — the new ids start above the
    // highest existing id (task file §6 risk: never reuse a gap).
    final ids = rows.map((r) => r.id).toSet();
    expect(ids, hasLength(25));
    expect(ids.contains(1), isTrue);
    expect(ids.contains(5), isTrue);
    for (var id = 6; id <= 25; id++) {
      expect(ids.contains(id), isTrue);
    }
  });

  test(
    'test_EARS_SEC_3c_replenish_never_reuses_a_consumed_gap',
    () async {
      await service.replenishOneTimePreKeys(minimum: 5, batch: 5);
      // Consume (remove) an id in the middle of the range, leaving a gap.
      await store.removePreKey(3);

      final generated = await service.replenishOneTimePreKeys(
        minimum: 20,
        batch: 5,
      );

      expect(generated, 5);
      final rows = await db.select(db.signalOneTimePrekeys).get();
      final ids = rows.map((r) => r.id).toSet();
      // The gap left by the consumed id=3 must never be reused.
      expect(ids.contains(3), isFalse);
      // New ids must start above the highest existing id (5), not fill 3.
      expect(ids.containsAll([1, 2, 4, 5, 6, 7, 8, 9, 10]), isTrue);
    },
  );

  test(
    'test_EARS_SEC_3c_replenish_never_reuses_a_drained_pools_ids',
    () async {
      // E03-B01 repro: replenish, record the id->key map, drain the pool
      // completely (as T03's decryptPreKeyMessage does on consumption),
      // then replenish again. The old `max(existing ids) + 1` logic
      // restarted at 1 once existingIds was empty, reissuing ids already
      // handed to peers with different key material.
      final generated1 = await service.replenishOneTimePreKeys(
        minimum: 20,
        batch: 5,
      );
      expect(generated1, 5);

      final firstBatchRows = await db.select(db.signalOneTimePrekeys).get();
      final firstBatchIds = firstBatchRows.map((r) => r.id).toSet();
      expect(firstBatchIds, {1, 2, 3, 4, 5});
      final firstKeyById = {
        for (final row in firstBatchRows)
          row.id: PreKeyRecord.fromBuffer(row.record)
              .getKeyPair()
              .publicKey
              .serialize(),
      };

      // Simulate every prekey being consumed by a peer (drains the pool to
      // empty).
      for (final id in firstBatchIds) {
        await store.removePreKey(id);
      }
      expect(await db.select(db.signalOneTimePrekeys).get(), isEmpty);

      final generated2 = await service.replenishOneTimePreKeys(
        minimum: 20,
        batch: 5,
      );
      expect(generated2, 5);

      final secondBatchRows = await db.select(db.signalOneTimePrekeys).get();
      final secondBatchIds = secondBatchRows.map((r) => r.id).toSet();

      // New ids must be strictly above every id this device has ever
      // issued — none of the drained ids may reappear.
      expect(secondBatchIds.intersection(firstBatchIds), isEmpty);
      for (final id in secondBatchIds) {
        expect(id, greaterThan(5));
      }
      expect(secondBatchIds, {6, 7, 8, 9, 10});

      // Even if an id were to reappear, the key material must never
      // silently differ under an id a peer already X3DH'd against — this
      // assertion documents that guarantee for any id that does collide.
      for (final row in secondBatchRows) {
        final oldKey = firstKeyById[row.id];
        if (oldKey != null) {
          final newKey = PreKeyRecord.fromBuffer(row.record)
              .getKeyPair()
              .publicKey
              .serialize();
          expect(newKey, oldKey);
        }
      }
    },
  );

  test(
    'test_EARS_SEC_3c_high_water_mark_survives_restart',
    () async {
      // App-restart case: a fresh service/store pair reopened against the
      // SAME database connection must continue allocating above every id
      // the previous instance issued — the high-water mark must be
      // persisted, not held only in memory.
      await service.replenishOneTimePreKeys(minimum: 20, batch: 5);
      final firstIds = (await db.select(db.signalOneTimePrekeys).get())
          .map((r) => r.id)
          .toSet();
      expect(firstIds, {1, 2, 3, 4, 5});

      // Drain the pool, as a consuming peer would.
      for (final id in firstIds) {
        await store.removePreKey(id);
      }

      // New instances over the same connection — simulates an app restart
      // without closing/reopening the underlying database.
      final restartedStore = DriftSignalProtocolStore(db);
      final restartedService = IdentityService(db, restartedStore);

      final generated = await restartedService.replenishOneTimePreKeys(
        minimum: 20,
        batch: 5,
      );
      expect(generated, 5);

      final secondIds = (await db.select(db.signalOneTimePrekeys).get())
          .map((r) => r.id)
          .toSet();
      expect(secondIds.intersection(firstIds), isEmpty);
      for (final id in secondIds) {
        expect(id, greaterThan(5));
      }
    },
  );

  test(
    'test_EARS_SEC_3c_allocated_ids_are_always_the_ids_libsignal_mints',
    () async {
      // E03-B01 review finding. The whole fix rests on one invariant: the
      // id allocateOneTimePreKeyIds hands out is the id that ends up in
      // signal_one_time_prekeys. libsignal's generatePreKeys can only mint
      // 1..Medium.MAX_VALUE - 1 (key_helper.dart:37), so an allocator
      // ranging over 1..Medium.MAX_VALUE broke that invariant at exactly
      // one point: allocating Medium.MAX_VALUE made libsignal mint id 1
      // instead, reusing an ancient id, and a batch straddling the
      // boundary minted the same id twice.
      //
      // Seeded at the top of the space so the boundary is reachable
      // without issuing ~16M ids.
      await db.into(db.cryptoCounters).insertOnConflictUpdate(
            CryptoCountersCompanion.insert(
              id: const Value(0),
              nextOneTimePreKeyId: const Value(0xFFFFFF - 1),
            ),
          );

      final allocated = await store.allocateOneTimePreKeyIds(3);

      // Every allocated id round-trips through libsignal unchanged.
      for (final id in allocated) {
        expect(generatePreKeys(id, 1).single.id, id);
      }
      // ...and the batch contains no duplicate, even across the wrap.
      expect(allocated.toSet(), hasLength(allocated.length));
      // Wraps rather than overflowing or throwing.
      expect(allocated, [0xFFFFFF - 1, 1, 2]);
    },
  );

  test('test_EARS_SEC_3c_no_op_above_minimum', () async {
    for (var id = 1; id <= 20; id++) {
      await store.storePreKey(id, PreKeyRecord(id, Curve.generateKeyPair()));
    }

    final generated = await service.replenishOneTimePreKeys(
      minimum: 20,
      batch: 20,
    );

    expect(generated, 0);
    final rows = await db.select(db.signalOneTimePrekeys).get();
    expect(rows, hasLength(20));
  });

  test('test_bundle_shape_contains_current_material', () async {
    await service.ensureLocalIdentity();
    await service.ensureSignedPreKey();
    await service.replenishOneTimePreKeys();

    final bundle = await service.getLocalPreKeyBundle();

    final identityKeyPair = await store.getIdentityKeyPair();
    final registrationId = await store.getLocalRegistrationId();
    final signedPreKeyRecord = await store.loadSignedPreKey(1);

    expect(bundle.getIdentityKey(), identityKeyPair.getPublicKey());
    expect(bundle.getRegistrationId(), registrationId);
    expect(bundle.getSignedPreKeyId(), signedPreKeyRecord.id);
    expect(
      bundle.getSignedPreKey()!.serialize(),
      signedPreKeyRecord.getKeyPair().publicKey.serialize(),
    );
    expect(bundle.getSignedPreKeySignature(), signedPreKeyRecord.signature);
    expect(bundle.getPreKeyId(), isNotNull);
    expect(bundle.getPreKey(), isNotNull);

    // Not marked consumed — the one-time prekey is still present in the
    // store after assembling the bundle (task file §3: the receiving side
    // of establishment, T03, removes it when actually used).
    expect(await store.containsPreKey(bundle.getPreKeyId()!), isTrue);
  });

  test(
    'test_bundle_throws_state_error_before_identity_generated',
    () async {
      expect(service.getLocalPreKeyBundle(), throwsStateError);
    },
  );

  test(
    'test_bundle_throws_state_error_before_signed_prekey_generated',
    () async {
      await service.ensureLocalIdentity();
      expect(service.getLocalPreKeyBundle(), throwsStateError);
    },
  );

  // Added in review (E03-T02, Opus): the §9 deviation-2 branch — an empty
  // one-time prekey pool — was NOT actually covered. The two throw tests
  // above both short-circuit on the *signed prekey* check, which runs
  // first, so `identity_service.dart`'s pool-empty branch never executed.
  // This reaches it: identity AND signed prekey present, pool empty.
  test('test_bundle_throws_state_error_when_one_time_prekey_pool_empty',
      () async {
    await service.ensureLocalIdentity();
    await service.ensureSignedPreKey();
    // Deliberately no replenishOneTimePreKeys() call — pool is empty.
    expect(await db.select(db.signalOneTimePrekeys).get(), isEmpty);

    await expectLater(
      service.getLocalPreKeyBundle(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('one-time prekeys'),
        ),
      ),
    );
  });
}
