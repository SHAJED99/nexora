// Round-trip tests for DriftSignalProtocolStore (E03-T01, EARS-SEC-3a).
//
// Each test serializes a real libsignal_protocol_dart record object (not
// raw bytes), writes it through the store, reads it back, and asserts on
// the deserialized object — this is what actually catches a
// library-version serialization quirk (task file §6 "Risks").
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/persistence/database.dart';

void main() {
  late AppDatabase db;
  late DriftSignalProtocolStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftSignalProtocolStore(db);
  });

  tearDown(() => db.close());

  test('test_EARS_SEC_3a_identity_roundtrips', () async {
    final identityKeyPair = generateIdentityKeyPair();
    const registrationId = 12345;

    await store.saveLocalIdentityIfAbsent(identityKeyPair, registrationId);

    final loadedPair = await store.getIdentityKeyPair();
    final loadedRegistrationId = await store.getLocalRegistrationId();

    expect(loadedPair.getPublicKey(), identityKeyPair.getPublicKey());
    expect(
      loadedPair.getPrivateKey().serialize(),
      identityKeyPair.getPrivateKey().serialize(),
    );
    expect(loadedRegistrationId, registrationId);
  });

  test('test_EARS_SEC_3a_identity_generation_is_singleton', () async {
    final first = generateIdentityKeyPair();
    await store.saveLocalIdentityIfAbsent(first, 111);

    // A second attempt to establish an identity must be a no-op: the
    // originally-persisted identity survives untouched, never silently
    // replaced by a second one.
    final second = generateIdentityKeyPair();
    await store.saveLocalIdentityIfAbsent(second, 222);

    final loadedPair = await store.getIdentityKeyPair();
    final loadedRegistrationId = await store.getLocalRegistrationId();

    expect(loadedPair.getPublicKey(), first.getPublicKey());
    expect(loadedRegistrationId, 111);

    // Only one row was ever written for the singleton identity.
    final rows = await db.select(db.signalIdentity).get();
    expect(rows, hasLength(1));
  });

  test('test_EARS_SEC_3a_identity_missing_throws', () async {
    expect(store.getIdentityKeyPair(), throwsStateError);
    expect(store.getLocalRegistrationId(), throwsStateError);
  });

  test('test_EARS_SEC_3a_prekey_roundtrips', () async {
    final record = PreKeyRecord(7, Curve.generateKeyPair());

    await store.storePreKey(7, record);
    expect(await store.containsPreKey(7), isTrue);

    final loaded = await store.loadPreKey(7);
    expect(loaded.id, record.id);
    expect(
      loaded.getKeyPair().publicKey.serialize(),
      record.getKeyPair().publicKey.serialize(),
    );
    expect(
      loaded.getKeyPair().privateKey.serialize(),
      record.getKeyPair().privateKey.serialize(),
    );

    // A one-time prekey is consumed exactly once, per X3DH.
    await store.removePreKey(7);
    expect(await store.containsPreKey(7), isFalse);
    expect(() => store.loadPreKey(7), throwsA(isA<InvalidKeyIdException>()));
  });

  test('test_EARS_SEC_3a_signed_prekey_roundtrips', () async {
    final identityKeyPair = generateIdentityKeyPair();
    final record = generateSignedPreKey(identityKeyPair, 3);

    await store.storeSignedPreKey(3, record);
    expect(await store.containsSignedPreKey(3), isTrue);

    final loaded = await store.loadSignedPreKey(3);
    expect(loaded.id, record.id);
    expect(loaded.signature, record.signature);
    expect(
      loaded.getKeyPair().publicKey.serialize(),
      record.getKeyPair().publicKey.serialize(),
    );

    final all = await store.loadSignedPreKeys();
    expect(all, hasLength(1));

    await store.removeSignedPreKey(3);
    expect(await store.containsSignedPreKey(3), isFalse);
    expect(
      () => store.loadSignedPreKey(3),
      throwsA(isA<InvalidKeyIdException>()),
    );
  });

  test('test_EARS_SEC_3a_session_roundtrips', () async {
    final address = SignalProtocolAddress('+15551234567', 1);

    // No session yet: the library's documented contract is a fresh, empty
    // record, not an exception.
    final fresh = await store.loadSession(address);
    expect(fresh.isFresh(), isTrue);
    expect(await store.containsSession(address), isFalse);

    final sessionRecord = SessionRecord();
    await store.storeSession(address, sessionRecord);

    expect(await store.containsSession(address), isTrue);
    final loaded = await store.loadSession(address);
    expect(loaded.serialize(), sessionRecord.serialize());

    expect(await store.getSubDeviceSessions('+15551234567'), contains(1));

    await store.deleteSession(address);
    expect(await store.containsSession(address), isFalse);
  });

  test(
      'test_EARS_SEC_3a_session_delete_all_removes_every_device_for_name',
      () async {
    final address1 = SignalProtocolAddress('+15551234567', 1);
    final address2 = SignalProtocolAddress('+15551234567', 2);
    await store.storeSession(address1, SessionRecord());
    await store.storeSession(address2, SessionRecord());

    await store.deleteAllSessions('+15551234567');

    expect(await store.containsSession(address1), isFalse);
    expect(await store.containsSession(address2), isFalse);
  });
}
