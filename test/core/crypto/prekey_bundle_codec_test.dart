// Tests for PreKeyBundleCodec (E06-T07).
//
// Round-trips a real `PreKeyBundle` assembled by `IdentityService` against
// a real in-memory Drift store — same fixture pattern as
// `identity_service_test.dart` — plus a malformed-bytes matrix mirroring
// `relay_packet_frame_test.dart`'s own discipline (every truncation/garbage
// shape throws `FormatException`, never a partially-built bundle).
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/crypto/prekey_bundle_codec.dart';
import 'package:nexora/core/persistence/database.dart';

void main() {
  late AppDatabase db;
  late DriftSignalProtocolStore store;
  late IdentityService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftSignalProtocolStore(db);
    service = IdentityService(db, store);
    await service.ensureLocalIdentity();
    await service.ensureSignedPreKey();
    await service.replenishOneTimePreKeys();
  });

  tearDown(() => db.close());

  test('test_bundle_codec_round_trips_a_real_bundle', () async {
    final bundle = await service.getLocalPreKeyBundle();

    final bytes = PreKeyBundleCodec.serialize(bundle);
    final decoded = PreKeyBundleCodec.deserialize(bytes);

    expect(decoded.getRegistrationId(), bundle.getRegistrationId());
    expect(decoded.getDeviceId(), bundle.getDeviceId());
    expect(decoded.getPreKeyId(), bundle.getPreKeyId());
    expect(decoded.getPreKey()!.serialize(), bundle.getPreKey()!.serialize());
    expect(decoded.getSignedPreKeyId(), bundle.getSignedPreKeyId());
    expect(
      decoded.getSignedPreKey()!.serialize(),
      bundle.getSignedPreKey()!.serialize(),
    );
    expect(
      decoded.getSignedPreKeySignature(),
      bundle.getSignedPreKeySignature(),
    );
    expect(
      decoded.getIdentityKey().serialize(),
      bundle.getIdentityKey().serialize(),
    );
  });

  test('test_bundle_codec_carries_no_private_material', () async {
    // The falsification asset the task file's §3/§6 require: serialize a
    // bundle from a store that ALSO holds private key material, and prove
    // by a byte-level search (not a field-by-field check) that none of
    // that private material ever appears in the wire output. A
    // field-by-field assertion could pass while still leaking bytes the
    // test never thought to check.
    final identityKeyPair = await store.getIdentityKeyPair();
    final bundle = await service.getLocalPreKeyBundle();
    final bytes = PreKeyBundleCodec.serialize(bundle);

    final privateIdentityBytes =
        identityKeyPair.getPrivateKey().serialize();
    expect(_containsSubsequence(bytes, privateIdentityBytes), isFalse);

    // The signed prekey's private half, and the one-time prekey's private
    // half, read straight back from the same store that produced the
    // bundle -- both must be absent from the wire bytes too.
    final signedPreKeyRows = await db.select(db.signalSignedPrekeys).get();
    final signedPreKeyRecord =
        SignedPreKeyRecord.fromSerialized(signedPreKeyRows.first.record);
    final signedPreKeyPrivateBytes =
        signedPreKeyRecord.getKeyPair().privateKey.serialize();
    expect(_containsSubsequence(bytes, signedPreKeyPrivateBytes), isFalse);

    final oneTimeRows = await db.select(db.signalOneTimePrekeys).get();
    for (final row in oneTimeRows) {
      final record = PreKeyRecord.fromBuffer(row.record);
      final onceKeyPrivateBytes = record.getKeyPair().privateKey.serialize();
      expect(_containsSubsequence(bytes, onceKeyPrivateBytes), isFalse);
    }
  });

  test('test_bundle_codec_rejects_empty_buffer', () {
    expect(
      () => PreKeyBundleCodec.deserialize(Uint8List(0)),
      throwsFormatException,
    );
  });

  test('test_bundle_codec_rejects_unknown_version', () async {
    final bundle = await service.getLocalPreKeyBundle();
    final bytes = PreKeyBundleCodec.serialize(bundle);
    bytes[0] = 0xFF;
    expect(
      () => PreKeyBundleCodec.deserialize(bytes),
      throwsFormatException,
    );
  });

  test('test_bundle_codec_rejects_truncated_buffer', () async {
    final bundle = await service.getLocalPreKeyBundle();
    final bytes = PreKeyBundleCodec.serialize(bundle);
    final truncated = bytes.sublist(0, bytes.length - 5);
    expect(
      () => PreKeyBundleCodec.deserialize(truncated),
      throwsFormatException,
    );
  });

  test('test_bundle_codec_rejects_a_length_prefix_past_the_buffer', () async {
    final bundle = await service.getLocalPreKeyBundle();
    final bytes = PreKeyBundleCodec.serialize(bundle);
    // registrationId(4) + deviceId(4) + hasOneTimePreKey(1) + preKeyId(4)
    // = offset 14 is the start of preKeyPublic's own u32 length prefix.
    final tampered = Uint8List.fromList(bytes);
    final view = ByteData.sublistView(tampered);
    view.setUint32(14, 0xFFFFFFFF);
    expect(
      () => PreKeyBundleCodec.deserialize(tampered),
      throwsFormatException,
    );
  });

  test('test_bundle_codec_rejects_trailing_bytes', () async {
    final bundle = await service.getLocalPreKeyBundle();
    final bytes = PreKeyBundleCodec.serialize(bundle);
    final withTrailer = Uint8List.fromList(<int>[...bytes, 0, 1, 2]);
    expect(
      () => PreKeyBundleCodec.deserialize(withTrailer),
      throwsFormatException,
    );
  });

  test('test_bundle_codec_rejects_an_undecodable_ec_public_key', () async {
    final bundle = await service.getLocalPreKeyBundle();
    final bytes = PreKeyBundleCodec.serialize(bundle);
    // Corrupt the signed prekey public's type byte (the first byte of its
    // 33-byte payload) so Curve.decodePoint rejects it.
    final tampered = Uint8List.fromList(bytes);
    // Walk to the signedPreKeyPublic payload the same way deserialize does:
    // version(1)+registrationId(4)+deviceId(4)+hasOneTimePreKey(1)+preKeyId(4)
    // + preKeyPublicLen(4) + preKeyPublic(33) + signedPreKeyId(4)
    // + signedPreKeyPublicLen(4) = 59, then the payload starts at 59.
    final offsetOfSignedPreKeyPublicPayload = 59;
    tampered[offsetOfSignedPreKeyPublicPayload] = 0x00; // not djbType (0x05)
    expect(
      () => PreKeyBundleCodec.deserialize(tampered),
      throwsFormatException,
    );
  });
}

/// True if [needle] appears anywhere inside [haystack] as a contiguous
/// subsequence -- the byte-level search the task file's own test name
/// (`test_bundle_codec_carries_no_private_material`) requires, rather than
/// a field-by-field equality check.
bool _containsSubsequence(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  for (var start = 0; start <= haystack.length - needle.length; start++) {
    var matched = true;
    for (var i = 0; i < needle.length; i++) {
      if (haystack[start + i] != needle[i]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}
