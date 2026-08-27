// Regression test for E03-B02 (EARS-SEC-1, EARS-SEC-3c).
//
// `getLocalPreKeyBundle()` must return a distinct, not-previously-issued
// one-time prekey on every call, durably across app restart — otherwise the
// second (and every subsequent) peer to open a session against a device is
// handed a one-time prekey id already in flight to an earlier peer, and
// their first inbound message is permanently undecryptable once that id is
// consumed by whoever got there first (task file repro, steps 1-7).
//
// Reviewer-verified red against pre-fix `epic_03`:
//   test_EARS_SEC_3c_distinct_prekey_per_peer: `Expected: not <1> / Actual: <1>`
//   test_EARS_SEC_1_second_peer_can_open_a_session:
//     `InvalidKeyIdException - No such one-time prekey: 1`
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/persistence/database.dart';

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);
String _text(Uint8List bytes) => String.fromCharCodes(bytes);

void main() {
  late AppDatabase aliceDb;
  late DriftSignalProtocolStore aliceStore;
  late IdentityService aliceIdentity;

  setUp(() async {
    aliceDb = AppDatabase.forTesting(NativeDatabase.memory());
    aliceStore = DriftSignalProtocolStore(aliceDb);
    aliceIdentity = IdentityService(aliceDb, aliceStore);
    await aliceIdentity.ensureLocalIdentity();
    await aliceIdentity.ensureSignedPreKey();
    // Pool = 20 prekeys, per the task file's exact repro setup.
    await aliceIdentity.replenishOneTimePreKeys();
  });

  tearDown(() => aliceDb.close());

  test('test_EARS_SEC_3c_distinct_prekey_per_peer', () async {
    // Repro steps 2-4: two consecutive getLocalPreKeyBundle() calls on one
    // device, neither prekey ever consumed in between.
    final forBob = await aliceIdentity.getLocalPreKeyBundle();
    final forCarol = await aliceIdentity.getLocalPreKeyBundle();

    expect(forCarol.getPreKeyId(), isNot(forBob.getPreKeyId()));
  });

  test('test_EARS_SEC_1_second_peer_can_open_a_session', () async {
    // Repro steps 1-7, end to end, through the public API only.
    final bobDb = AppDatabase.forTesting(NativeDatabase.memory());
    final bobStore = DriftSignalProtocolStore(bobDb);
    final bobIdentity = IdentityService(bobDb, bobStore);
    final bobCrypto = CryptoService.withStore(bobStore);
    await bobIdentity.ensureLocalIdentity();
    await bobIdentity.ensureSignedPreKey();
    await bobIdentity.replenishOneTimePreKeys();
    addTearDown(bobDb.close);

    final carolDb = AppDatabase.forTesting(NativeDatabase.memory());
    final carolStore = DriftSignalProtocolStore(carolDb);
    final carolIdentity = IdentityService(carolDb, carolStore);
    final carolCrypto = CryptoService.withStore(carolStore);
    await carolIdentity.ensureLocalIdentity();
    await carolIdentity.ensureSignedPreKey();
    await carolIdentity.replenishOneTimePreKeys();
    addTearDown(carolDb.close);

    final aliceCrypto = CryptoService.withStore(aliceStore);
    const aliceAddress = SignalProtocolAddress('alice', 1);
    const bobAddress = SignalProtocolAddress('bob', 1);
    const carolAddress = SignalProtocolAddress('carol', 1);

    // Step 2-3: Alice hands out two bundles before either is consumed.
    final forBob = await aliceIdentity.getLocalPreKeyBundle();
    final forCarol = await aliceIdentity.getLocalPreKeyBundle();
    expect(forCarol.getPreKeyId(), isNot(forBob.getPreKeyId()));

    // Step 5: both peers establish sessions against Alice from their own
    // bundles.
    await bobCrypto.establishSession(aliceAddress, forBob);
    await carolCrypto.establishSession(aliceAddress, forCarol);

    // Step 6: Bob's first message reaches Alice and consumes Bob's prekey.
    final bobMsg = await bobCrypto.encrypt(aliceAddress, _plaintext('hi from bob'));
    final alicePlaintextFromBob = await aliceCrypto.decrypt(bobAddress, bobMsg);
    expect(_text(alicePlaintextFromBob), 'hi from bob');

    // Step 7: Carol's first message must still decrypt — her prekey id was
    // never Bob's, so it is still live in Alice's store.
    final carolMsg =
        await carolCrypto.encrypt(aliceAddress, _plaintext('hi from carol'));
    final alicePlaintextFromCarol =
        await aliceCrypto.decrypt(carolAddress, carolMsg);
    expect(_text(alicePlaintextFromCarol), 'hi from carol');
  });

  test(
    'test_EARS_SEC_3c_issue_cursor_survives_restart',
    () async {
      // App-restart case, mirroring
      // test_EARS_SEC_3c_high_water_mark_survives_restart (E03-B01): a
      // fresh store/service pair reopened against the SAME database
      // connection must not reissue a prekey id already issued by the
      // previous instance. This is the boundary where an in-memory-only
      // cursor (rejected Option 3) would silently reintroduce the bug.
      final firstBundle = await aliceIdentity.getLocalPreKeyBundle();

      // New instances over the same connection — simulates an app restart
      // without closing/reopening the underlying database.
      final restartedStore = DriftSignalProtocolStore(aliceDb);
      final restartedIdentity = IdentityService(aliceDb, restartedStore);

      final secondBundle = await restartedIdentity.getLocalPreKeyBundle();

      expect(secondBundle.getPreKeyId(), isNot(firstBundle.getPreKeyId()));
    },
  );

  // Added in review (E03-B02, Opus). The fix changes what "pool exhausted"
  // MEANS: from "signal_one_time_prekeys has zero rows" to "the issue
  // cursor has passed every live id". The existing test at
  // identity_service_test.dart:334 only covers the old, table-empty
  // condition, so the new — and, per the Run log, much sooner-reachable —
  // exhaustion mode had no coverage at all. It matters that this stays a
  // StateError with the same message: it is the one signal a caller (E05/
  // E06) gets that it must call replenishOneTimePreKeys(), and the task
  // file makes keeping that contract non-negotiable.
  test('test_EARS_SEC_3c_exhaustion_when_every_prekey_already_issued',
      () async {
    final poolSize = (await aliceDb.select(aliceDb.signalOneTimePrekeys).get())
        .length;
    expect(poolSize, greaterThan(1));

    // Issue every prekey in the pool. None is ever consumed, so every row
    // is still live in the store — this is NOT the table-empty case.
    final issuedIds = <int>[];
    for (var i = 0; i < poolSize; i++) {
      issuedIds
          .add((await aliceIdentity.getLocalPreKeyBundle()).getPreKeyId()!);
    }
    // Every call handed out a different prekey (the core B02 invariant, at
    // full pool scale rather than just two calls).
    expect(issuedIds.toSet(), hasLength(poolSize));

    // The rows are all still there — exhaustion here is purely "nothing
    // un-issued left", which is exactly the distinction this test pins.
    expect(
      await aliceDb.select(aliceDb.signalOneTimePrekeys).get(),
      hasLength(poolSize),
    );

    // One more request must fail as a StateError with the unchanged
    // message — not return a duplicate, not throw something else, not hang.
    await expectLater(
      aliceIdentity.getLocalPreKeyBundle(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('one-time prekeys'),
        ),
      ),
    );

    // And it stays recoverable: replenishing mints ids above the cursor, so
    // issuance resumes rather than being permanently wedged.
    await aliceIdentity.replenishOneTimePreKeys();
    final afterReplenish = await aliceIdentity.getLocalPreKeyBundle();
    expect(issuedIds, isNot(contains(afterReplenish.getPreKeyId())));
  });
}
