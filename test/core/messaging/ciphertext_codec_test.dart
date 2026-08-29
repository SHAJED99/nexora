// Tests for CiphertextCodec + crypto_failures.dart's mapSignalException
// (E06-T02, EARS-COMM-5).
//
// The ciphertext round-trip tests build REAL PreKeySignalMessage/
// SignalMessage instances through CryptoService against a real in-memory
// Drift-backed store -- not fabricated messages -- per the task file's own
// instruction: this is "the test E05-B01 could not write".
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_failures.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/messaging/ciphertext_codec.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';

/// One simulated device -- mirrors `crypto_service_test.dart`'s `_Party`, so
/// this test builds real Signal messages through the same real path E03-T03
/// already proved, rather than a second, independently-guessed fixture.
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

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);

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

  test('test_EARS_COMM_5_ciphertext_tag_round_trip', () async {
    await alice.crypto.establishSession(bobAddress, await bob.bundle());

    // A real PreKeySignalMessage -- the X3DH-carrying first message.
    final preKeyMessage = await alice.crypto.encrypt(
      bobAddress,
      _plaintext('hello bob'),
    );
    expect(preKeyMessage, isA<PreKeySignalMessage>());

    final (preKeyTag, preKeyBytes) = CiphertextCodec.encode(preKeyMessage);
    expect(preKeyTag, PayloadType.preKeySignalMessage);

    final decodedPreKey = CiphertextCodec.decode(preKeyTag, preKeyBytes);
    expect(decodedPreKey.runtimeType, preKeyMessage.runtimeType);
    expect(decodedPreKey.serialize(), equals(preKeyMessage.serialize()));

    // Drive the session to steady-state so the next message is a real
    // SignalMessage, not another PreKeySignalMessage.
    await bob.crypto.decrypt(aliceAddress, preKeyMessage);
    final steadyStateMessage = await bob.crypto.encrypt(
      aliceAddress,
      _plaintext('hi alice'),
    );
    expect(steadyStateMessage, isA<SignalMessage>());

    final (steadyTag, steadyBytes) = CiphertextCodec.encode(steadyStateMessage);
    expect(steadyTag, PayloadType.signalMessage);

    final decodedSteady = CiphertextCodec.decode(steadyTag, steadyBytes);
    expect(decodedSteady.runtimeType, steadyStateMessage.runtimeType);
    expect(decodedSteady.serialize(), equals(steadyStateMessage.serialize()));

    // The decoded messages must still actually decrypt correctly through
    // CryptoService -- proof the round-trip preserved everything the
    // ratchet needs, not just that `serialize()` bytes happen to match.
    final aliceRoundTrip = await alice.crypto.decrypt(
      bobAddress,
      decodedSteady,
    );
    expect(String.fromCharCodes(aliceRoundTrip), 'hi alice');
  });

  test('test_ciphertext_codec_rejects_control_tag', () {
    expect(
      () => CiphertextCodec.decode(
        PayloadType.control,
        Uint8List.fromList([1, 2, 3]),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
    'test_ciphertext_codec_decode_rejects_unparseable_bytes_as_invalidMessage',
    () {
      // A 9-byte buffer tagged as a steady-state SignalMessage whose
      // leading byte's high nibble (0x4) encodes a message version (4)
      // greater than the library's own `CiphertextMessage.currentVersion`
      // (3) -- `SignalMessage.fromSerialized` rejects this with its own
      // `InvalidMessageException('Unknown version: ...')` before ever
      // touching the protobuf body, mapped here to
      // CryptoDecryptFailure(invalidMessage). The buffer is exactly
      // `1 (version) + SignalMessage.macLength (8)` bytes long so the
      // library's own length split (`serialized.length - 1 - macLength`)
      // doesn't itself fail first with an unrelated RangeError -- this test
      // must fail for the version-rejection reason, not a buffer-too-short
      // one.
      expect(
        () => CiphertextCodec.decode(
          PayloadType.signalMessage,
          Uint8List.fromList([0x40, 0, 0, 0, 0, 0, 0, 0, 0]),
        ),
        throwsA(
          isA<CryptoDecryptFailure>().having(
            (f) => f.reason,
            'reason',
            CryptoDecryptFailureReason.invalidMessage,
          ),
        ),
      );
    },
  );

  test('test_map_signal_exception_covers_the_documented_reasons', () async {
    final noSession = NoSessionException('no session for address');
    expect(
      mapSignalException(noSession).reason,
      CryptoDecryptFailureReason.noSession,
    );
    expect(mapSignalException(noSession).cause, same(noSession));

    final duplicate = DuplicateMessageException('already consumed');
    expect(
      mapSignalException(duplicate).reason,
      CryptoDecryptFailureReason.duplicateMessage,
    );
    expect(mapSignalException(duplicate).cause, same(duplicate));

    final untrusted = UntrustedIdentityException('bob', null);
    expect(
      mapSignalException(untrusted).reason,
      CryptoDecryptFailureReason.untrustedIdentity,
    );
    expect(mapSignalException(untrusted).cause, same(untrusted));

    // Unrecognised errors map to `unknown`, with the original attached --
    // never swallowed.
    final somethingElse = StateError('unrelated failure');
    final mapped = mapSignalException(somethingElse);
    expect(mapped.reason, CryptoDecryptFailureReason.unknown);
    expect(mapped.cause, same(somethingElse));

    // `invalidMessage` is proven via a REAL InvalidMessageException reached
    // through CryptoService.decrypt() -- the library does not export this
    // exception type (E03-B03), so it cannot be constructed directly here;
    // it must be triggered for real. A third party with her own live
    // session derives a key from her own chain and fails MAC verification,
    // exactly as `crypto_service_test.dart`'s own strongest security proof
    // does.
    await alice.crypto.establishSession(bobAddress, await bob.bundle());
    final msg = await alice.crypto.encrypt(bobAddress, _plaintext('secret'));

    final carol = await _Party.create();
    addTearDown(carol.close);
    const carolAddress = SignalProtocolAddress('carol', 1);
    await alice.crypto.establishSession(carolAddress, await carol.bundle());

    await expectLater(
      carol.crypto.decrypt(
        aliceAddress,
        PreKeySignalMessage(msg.serialize()),
      ),
      throwsA(
        isA<CryptoDecryptFailure>().having(
          (f) => f.reason,
          'reason',
          CryptoDecryptFailureReason.invalidMessage,
        ),
      ),
    );
  });
}
