// Tests for IdentityService (E03-T02, EARS-SEC-3b/3c).
//
// Exercises first-run identity/signed-prekey bootstrap, idempotency,
// one-time-prekey pool replenishment, and PreKeyBundle assembly — all
// against a real in-memory Drift database + real libsignal_protocol_dart
// record objects, per L-backend lessons and E03-T01's established pattern.
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
    // Seed the store with fewer than `minimum` one-time prekeys.
    for (var id = 1; id <= 5; id++) {
      await store.storePreKey(id, PreKeyRecord(id, Curve.generateKeyPair()));
    }

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
      for (var id = 1; id <= 5; id++) {
        await store.storePreKey(
          id,
          PreKeyRecord(id, Curve.generateKeyPair()),
        );
      }
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
