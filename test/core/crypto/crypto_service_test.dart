// Tests for CryptoService (E03-T03, EARS-SEC-1/2/3).
//
// These five tests ARE the epic's central proof (task file §6): that this
// wrapper around `libsignal_protocol_dart`'s real SessionBuilder/
// SessionCipher genuinely delivers end-to-end confidentiality, forward
// secrecy, post-compromise recovery, and replay rejection — not a
// superficial diff-check. Two simulated devices (Alice, Bob), each with its
// own real in-memory Drift database via `CryptoService.withStore`, pass
// serialized ciphertext bytes directly in-process (task file §4 — no
// transport exists yet, that's E04's job).
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/persistence/database.dart';

/// One simulated device: its own database, store, identity, and the
/// CryptoService instance bound to that store.
class _Party {
  _Party._(this.db, this.store, this.crypto);

  final AppDatabase db;
  final DriftSignalProtocolStore store;
  final CryptoService crypto;

  static Future<_Party> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftSignalProtocolStore(db);
    final identity = IdentityService(db, store);
    await identity.ensureLocalIdentity();
    await identity.ensureSignedPreKey();
    await identity.replenishOneTimePreKeys();
    final crypto = CryptoService.withStore(store);
    return _Party._(db, store, crypto);
  }

  Future<PreKeyBundle> bundle() async {
    final identity = IdentityService(db, store);
    return identity.getLocalPreKeyBundle();
  }

  Future<void> close() => db.close();
}

/// Builds a *separate*, freshly-created store seeded only with what a
/// device-compromise attacker would actually obtain by copying [real]'s
/// storage at this instant: its identity keypair/registration id, and its
/// current session record for [peerAddress]. No prekeys, no other
/// sessions — an attacker snapshot, not a live clone.
Future<DriftSignalProtocolStore> _compromisedSnapshot(
  DriftSignalProtocolStore real,
  SignalProtocolAddress peerAddress,
) async {
  final snapshotDb = AppDatabase.forTesting(NativeDatabase.memory());
  final snapshotStore = DriftSignalProtocolStore(snapshotDb);

  final identityKeyPair = await real.getIdentityKeyPair();
  final registrationId = await real.getLocalRegistrationId();
  await snapshotStore.saveLocalIdentityIfAbsent(
    identityKeyPair,
    registrationId,
  );

  final sessionRecord = await real.loadSession(peerAddress);
  await snapshotStore.storeSession(peerAddress, sessionRecord);

  return snapshotStore;
}

/// Matches the library's `InvalidMessageException` — the failure raised
/// when the ratchet produced a message key that failed MAC verification,
/// i.e. "reached the crypto and got the wrong key", as distinct from a
/// precondition failure (`NoSessionException`) or a consumed-key failure
/// (`DuplicateMessageException`).
///
/// Matched by runtime type name rather than `isA<InvalidMessageException>()`
/// because `libsignal_protocol_dart` v0.8.2 does **not** export
/// `invalid_message_exception.dart` from its public barrel file, so the type
/// is unnameable here without an `implementation_imports` lint violation.
/// (Reviewer note, E03-T03 review — worth revisiting in E05/E06, where
/// callers will need a catchable decrypt-failure taxonomy.)
final Matcher _isInvalidMessageException = predicate<Object>(
  (e) => e.runtimeType.toString() == 'InvalidMessageException',
  'is an InvalidMessageException (MAC/key-derivation failure)',
);

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);
String _text(Uint8List bytes) => String.fromCharCodes(bytes);

void main() {
  late _Party alice;
  late _Party bob;
  const aliceAddress = SignalProtocolAddress('alice', 1);
  const bobAddress = SignalProtocolAddress('bob', 1);

  setUp(() async {
    alice = await _Party.create();
    bob = await _Party.create();
  });

  tearDown(() async {
    await alice.close();
    await bob.close();
  });

  test('test_EARS_SEC_1_two_party_roundtrip', () async {
    // Alice establishes a session with Bob from Bob's published bundle.
    await alice.crypto.establishSession(bobAddress, await bob.bundle());

    final msg1 = await alice.crypto.encrypt(
      bobAddress,
      _plaintext('hello bob'),
    );
    expect(msg1, isA<PreKeySignalMessage>());

    // Bob has no prior session — decrypt() establishes it implicitly
    // (X3DH responder side) and recovers the original plaintext.
    final bobPlaintext1 = await bob.crypto.decrypt(aliceAddress, msg1);
    expect(_text(bobPlaintext1), 'hello bob');

    // Reply in the other direction also round-trips, now steady-state.
    final msg2 = await bob.crypto.encrypt(aliceAddress, _plaintext('hi alice'));
    expect(msg2, isA<SignalMessage>());

    final alicePlaintext2 = await alice.crypto.decrypt(bobAddress, msg2);
    expect(_text(alicePlaintext2), 'hi alice');
  });

  test('test_EARS_SEC_2_relay_cannot_decrypt', () async {
    await alice.crypto.establishSession(bobAddress, await bob.bundle());
    final msg1 = await alice.crypto.encrypt(
      bobAddress,
      _plaintext('top secret'),
    );

    // A relay holds only the serialized bytes — no store, no keys.
    final wireBytes = msg1.serialize();
    final relayView = PreKeySignalMessage(wireBytes);

    // The relay can see protocol metadata (identity key, registration id,
    // prekey ids)...
    expect(relayView.getRegistrationId(), isPositive);
    // ...but the encrypted body bytes do not contain the plaintext.
    final bodyBytes = relayView.getWhisperMessage().serialize();
    expect(_bytesContain(bodyBytes, _plaintext('top secret')), isFalse);

    // Round-trip for real, so there is a steady-state message to hand the
    // relay too (not just the very first, X3DH-carrying one).
    await bob.crypto.decrypt(aliceAddress, msg1);
    final bobReply = await bob.crypto.encrypt(aliceAddress, _plaintext('ack'));
    await alice.crypto.decrypt(bobAddress, bobReply);
    final msg2 = await alice.crypto.encrypt(
      bobAddress,
      _plaintext('still secret'),
    );
    expect(msg2, isA<SignalMessage>());

    // Weakest relay model: a store with NOTHING in it. This fails at
    // `containsSession`, the library's first precondition check. Necessary
    // but NOT sufficient evidence — on its own it only proves "our API
    // requires a session", which is a weaker claim than FR-SEC-002 makes.
    // Kept as the boundary case; the real proof is the resourced relay
    // below. (Reviewer note, E03-T03 review.)
    final relayDb = AppDatabase.forTesting(NativeDatabase.memory());
    final relayStore = DriftSignalProtocolStore(relayDb);
    final relayCrypto = CryptoService.withStore(relayStore);
    await expectLater(
      relayCrypto.decrypt(aliceAddress, msg2),
      throwsA(isA<NoSessionException>()),
    );
    await relayDb.close();

    // STRONGEST relay model, and the one that actually proves FR-SEC-002:
    // Carol is a fully-resourced third party. She has her own real Signal
    // identity, her own signed prekey and one-time prekeys, AND a genuine
    // live Double Ratchet session with Alice herself. She is strictly more
    // powerful than any transport relay could be — and she still cannot
    // read a byte of Alice's traffic to Bob. Failure here is NOT a
    // precondition check: Carol passes `containsSession`, reaches the real
    // ratchet, derives a key from her OWN chain, and is stopped by MAC
    // verification against key material she does not have.
    final carol = await _Party.create();
    const carolAddress = SignalProtocolAddress('carol', 1);
    addTearDown(carol.close);

    // (a) X3DH-responder path, attempted FIRST so Carol's own one-time
    // prekey pool is still fully stocked — otherwise she would fail merely
    // at a prekey-id lookup, which would be a bookkeeping failure rather
    // than a cryptographic one and would prove much less. With her pool
    // intact she gets all the way through `SessionBuilder.processV3`,
    // actually runs `initializeSessionBob` with her own valid identity +
    // signed prekey + one-time prekey, derives a real session and a real
    // message key — and that key fails MAC verification, because it is not
    // the key Alice derived against BOB's keys. This is the substantive
    // claim: a third party running the genuine handshake path with a
    // genuine keystore still cannot read the message.
    await expectLater(
      carol.crypto.decrypt(
        aliceAddress,
        PreKeySignalMessage(msg1.serialize()),
      ),
      throwsA(_isInvalidMessageException),
    );

    // (b) Now give Carol a real, live Double Ratchet session with Alice —
    // she is a legitimate correspondent of the sender, not just a bystander.
    await alice.crypto.establishSession(carolAddress, await carol.bundle());
    final toCarol = await alice.crypto.encrypt(
      carolAddress,
      _plaintext('hello carol'),
    );
    expect(
      _text(await carol.crypto.decrypt(aliceAddress, toCarol)),
      'hello carol',
    );
    expect(await carol.store.containsSession(aliceAddress), isTrue);

    // Carol intercepts Alice's steady-state ciphertext addressed to Bob.
    // She passes `containsSession` (so this is NOT a precondition failure),
    // reaches `_getOrCreateChainKey`, derives a chain from her OWN root key,
    // and fails MAC verification. Holding a valid session with the sender
    // buys her nothing.
    await expectLater(
      carol.crypto.decrypt(
        aliceAddress,
        SignalMessage.fromSerialized(msg2.serialize()),
      ),
      throwsA(_isInvalidMessageException),
    );

    // Bob — the one legitimate recipient — is unaffected by any of it.
    expect(_text(await bob.crypto.decrypt(aliceAddress, msg2)),
        'still secret');
  });

  test('test_EARS_SEC_3_forward_secrecy', () async {
    await alice.crypto.establishSession(bobAddress, await bob.bundle());

    // Three messages, Alice -> Bob, consumed by Bob in order.
    final msg1 = await alice.crypto.encrypt(bobAddress, _plaintext('msg one'));
    await bob.crypto.decrypt(aliceAddress, msg1);
    final msg2 = await alice.crypto.encrypt(bobAddress, _plaintext('msg two'));
    await bob.crypto.decrypt(aliceAddress, msg2);
    final msg3 = await alice.crypto.encrypt(
      bobAddress,
      _plaintext('msg three'),
    );
    final bobPlaintext3 = await bob.crypto.decrypt(aliceAddress, msg3);
    expect(_text(bobPlaintext3), 'msg three');

    // Compromise Bob's session state right now, after all three messages
    // have been consumed — this is exactly what an attacker who steals
    // Bob's device storage at this instant would obtain: the *current*
    // ratchet/message key material, nothing more.
    final snapshotStore = await _compromisedSnapshot(bob.store, aliceAddress);
    final attackerCipher = SessionCipher.fromStore(snapshotStore, aliceAddress);

    // DIRECT structural proof, independent of any exception semantics:
    // the compromised state retains NO message key for msg1's or msg2's
    // counter. `hasMessageKeys` is the library's own authoritative record
    // of retained (skipped) per-message keys — the ONLY place a consumed
    // key could still be recoverable from. Both false => the key material
    // for those messages is absent from everything the attacker holds, and
    // the receive chain key is a one-way KDF ratchet, so it cannot be run
    // backwards to re-derive them. (Reviewer addition, E03-T03 review: the
    // assertions below prove the same thing via the library's exception,
    // but this states it without depending on what that exception means.)
    final snapshotState =
        (await snapshotStore.loadSession(aliceAddress)).sessionState;
    final inner1 = (msg1 as PreKeySignalMessage).getWhisperMessage();
    final inner2 = (msg2 as PreKeySignalMessage).getWhisperMessage();
    expect(
      snapshotState.hasMessageKeys(
        inner1.getSenderRatchetKey(),
        inner1.getCounter(),
      ),
      isFalse,
      reason: 'msg1 message key must not be retained post-compromise',
    );
    expect(
      snapshotState.hasMessageKeys(
        inner2.getSenderRatchetKey(),
        inner2.getCounter(),
      ),
      isFalse,
      reason: 'msg2 message key must not be retained post-compromise',
    );

    // msg1 and msg2's per-message keys were already consumed and deleted
    // from the ratchet state when Bob decrypted them in order (they were
    // never held in the "skipped keys" map, since nothing was skipped) —
    // the compromised current state cannot re-derive them. (Bob never
    // replied in this test, so Alice's session never received an
    // acknowledgement and every message she sent stayed wrapped as a
    // PreKeySignalMessage — `cipher.decrypt` is the matching call, and
    // internally takes the exact same "already-established session, fall
    // through to the inner ratchet decrypt" path as a plain SignalMessage
    // would.)
    await expectLater(
      attackerCipher.decrypt(PreKeySignalMessage(msg1.serialize())),
      throwsA(isA<DuplicateMessageException>()),
    );
    await expectLater(
      attackerCipher.decrypt(PreKeySignalMessage(msg2.serialize())),
      throwsA(isA<DuplicateMessageException>()),
    );
  });

  test('test_EARS_SEC_3_post_compromise_recovery', () async {
    await alice.crypto.establishSession(bobAddress, await bob.bundle());

    // Note: an attacker who compromises Bob's device can only ever use
    // Bob's store to decrypt messages Bob *receives* (Alice -> Bob) — a
    // device's session state has no use for decrypting the messages it
    // sent itself. So the attacker's window is proven/disproven entirely
    // against the Alice -> Bob messages below (msg1, msg3, msg5); Bob's own
    // replies (msg2, msg4) only exist to drive the ratchet forward.

    // Round 1: Alice -> Bob (X3DH establishment). Processing this already
    // turns Bob's own DH ratchet (his sender chain rotates to a
    // freshly-generated key pair the moment he sees Alice's ratchet key for
    // the first time — a library-level fact, not assumed).
    final msg1 = await alice.crypto.encrypt(bobAddress, _plaintext('one'));
    await bob.crypto.decrypt(aliceAddress, msg1);

    // Attacker compromises Bob's session state right here — this is the
    // ONLY material the attacker will ever have.
    final snapshotStore = await _compromisedSnapshot(bob.store, aliceAddress);

    // Bob replies (his existing, already-compromised ratchet key); Alice
    // decrypting it forces *her* ratchet forward to a fresh key of her own.
    final msg2 = await bob.crypto.encrypt(aliceAddress, _plaintext('two'));
    await alice.crypto.decrypt(bobAddress, msg2);

    // Alice -> Bob again, now on her fresh post-msg2 ratchet key. Deriving
    // Bob's receiving side for this still only needs the ratchet key Bob
    // already had at compromise time (his side of this particular DH step
    // hasn't changed yet) — so the attacker's stale snapshot alone can
    // still resolve it.
    final msg3 = await alice.crypto.encrypt(bobAddress, _plaintext('three'));
    final bobPlaintext3 = await bob.crypto.decrypt(aliceAddress, msg3);
    expect(_text(bobPlaintext3), 'three');

    // The attacker, using ONLY the stale snapshot, can indeed decrypt
    // msg3 — proving the compromise was real and consequential, not a test
    // that never actually exercised the vulnerable window.
    final attackerPlaintext3 = await SessionCipher.fromStore(
      snapshotStore,
      aliceAddress,
    ).decryptFromSignal(msg3 as SignalMessage);
    expect(_text(attackerPlaintext3), 'three');

    // But Bob's *live* processing of msg3 just forced his own session to
    // generate a brand new ratchet key pair he never had at compromise
    // time (the same library-level fact: `_getOrCreateChainKey` mints a
    // fresh ephemeral the moment it first sees a new incoming ratchet
    // key). Bob's next reply carries that fresh key...
    final msg4 = await bob.crypto.encrypt(aliceAddress, _plaintext('four'));
    // ...and Alice decrypting it forces her ratchet forward *again*, to a
    // second fresh key that depends on Bob's post-compromise randomness.
    await alice.crypto.decrypt(bobAddress, msg4);

    // Alice -> Bob once more, now on her second post-heal ratchet key.
    // Deriving Bob's receiving side for THIS message requires the fresh
    // key Bob generated after compromise (msg4's DH step) — material the
    // attacker's snapshot never contained and cannot derive.
    final msg5 = await alice.crypto.encrypt(bobAddress, _plaintext('five'));
    final bobPlaintext5 = await bob.crypto.decrypt(aliceAddress, msg5);
    expect(_text(bobPlaintext5), 'five');

    // Recovery: the SAME stale attacker snapshot (still only what was
    // captured before Bob ever generated his post-compromise key) cannot
    // derive msg5's key and fails to recover the plaintext.
    // Assert the SPECIFIC cryptographic failure, not merely "some
    // exception". `isException` would also have been satisfied by a broken
    // test fixture (a missing prekey, an absent identity, a StateError from
    // our own wrapper) — which would make this test pass for a reason that
    // has nothing to do with post-compromise recovery.
    // `InvalidMessageException` is what the library raises when it derived
    // a chain key and the resulting message key failed MAC verification:
    // i.e. the attacker DID reach the ratchet and computed the wrong key,
    // because Bob's post-compromise DH ratchet key was never in the
    // snapshot. (Reviewer tightening, E03-T03 review.)
    await expectLater(
      SessionCipher.fromStore(snapshotStore, aliceAddress)
          .decryptFromSignal(SignalMessage.fromSerialized(msg5.serialize())),
      throwsA(_isInvalidMessageException),
    );
  });

  test('test_EARS_SEC_3_replay_rejected', () async {
    await alice.crypto.establishSession(bobAddress, await bob.bundle());
    final msg1 = await alice.crypto.encrypt(bobAddress, _plaintext('once'));

    final firstDecrypt = await bob.crypto.decrypt(aliceAddress, msg1);
    expect(_text(firstDecrypt), 'once');

    // Decrypting the identical ciphertext a second time must not yield a
    // second usable plaintext derivation — the library rejects it outright
    // (the message key was consumed and removed from the ratchet state on
    // first use).
    //
    // Replayed from the raw serialized WIRE BYTES, re-deserialized into a
    // fresh message object, so this asserts "the same ciphertext bytes are
    // rejected on replay" — not merely "the same in-memory object is
    // rejected", which a stateful flag on the object could have satisfied
    // without any real replay protection. (Reviewer tightening, E03-T03.)
    final replayedBytes = Uint8List.fromList(msg1.serialize());
    expect(replayedBytes, equals(msg1.serialize()));
    await expectLater(
      bob.crypto.decrypt(
        aliceAddress,
        PreKeySignalMessage(replayedBytes),
      ),
      throwsA(isA<DuplicateMessageException>()),
    );
  });
}

bool _bytesContain(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var matched = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}
