// core/crypto — the missing `PreKeyBundle` wire codec (E06-T07, closes
// OQ-E05-T02-1's "how does a device obtain a peer's PreKeyBundle" question
// on the wire-format half; `PrekeyExchange` in `core/messaging/` owns the
// channel it travels over).
//
// `IdentityService.getLocalPreKeyBundle()` (`identity_service.dart:120`)
// has produced an in-process `PreKeyBundle` since E03-T02, and nothing has
// ever turned it into bytes. This is that serializer/deserializer pair.
//
// Framing follows the same big-endian, explicit-version,
// length-prefixed-and-bounds-checked idiom as `RelayPacketFrame`
// (`relay_packet_frame.dart`) and `MessageEnvelope` — one idiom in this
// codebase for "bytes that must survive a hostile or malformed peer."
//
//   [u8  codecVersion=1]
//   [u32 registrationId]
//   [u32 deviceId]
//   [u8  hasOneTimePreKey]                          // 0 or 1
//   [u32 preKeyId]                                  // meaningless if hasOneTimePreKey==0
//   [u32 preKeyPublicLen][preKeyPublic bytes]        // empty if hasOneTimePreKey==0
//   [u32 signedPreKeyId]
//   [u32 signedPreKeyPublicLen][signedPreKeyPublic bytes]
//   [u32 signedPreKeySignatureLen][signedPreKeySignature bytes]
//   [u32 identityKeyLen][identityKey bytes]
//
// Every field is PUBLIC material — a registration id, a device id, two
// EC public keys (`ECPublicKey.serialize()`'s own 33-byte
// type-byte-plus-coordinate wire form), a signature, and an identity
// public key (`IdentityKey.serialize()`, the same 33-byte EC public-key
// wire form). Nothing here ever reads a private key: [serialize] takes the
// `PreKeyBundle` the caller already assembled (never the store), and every
// getter this file calls (`getRegistrationId`/`getDeviceId`/`getPreKeyId`/
// `getPreKey`/`getSignedPreKeyId`/`getSignedPreKey`/
// `getSignedPreKeySignature`/`getIdentityKey`) is one of `PreKeyBundle`'s
// own public-material accessors — there is no private-key accessor on this
// class for this file to reach even by mistake
// (`test_bundle_codec_carries_no_private_material` is the falsification
// asset: it builds the bundle from a store that also holds private keys and
// asserts none of those private bytes appear anywhere in the output).
//
// `hasOneTimePreKey` exists because `PreKeyBundle.getPreKeyId()`/
// `getPreKey()` are declared nullable by the library itself — this codec
// preserves that possibility rather than assuming a one-time prekey is
// always present, even though every bundle this app actually assembles
// today (`IdentityService.getLocalPreKeyBundle()`) always has one; a pool
// too exhausted to issue one is handled by `PrekeyExchange` sending
// `bundleUnavailable` instead of calling this serializer at all (task file
// §3), never by serializing a bundle with no one-time key.
//
// Does NOT do key generation, session establishment, or transport — pure
// codec, no I/O (mirrors `relay_packet_frame.dart`'s own "no I/O" line).
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// Current, and so far only, codec layout version. Bump this — and add a
/// new `deserialize` branch, never silently reinterpret the old one — if
/// the layout ever changes incompatibly.
const int preKeyBundleCodecVersion = 1;

/// Serializes/deserializes a `PreKeyBundle` to/from the wire layout
/// documented above. Public material only (see this file's header).
class PreKeyBundleCodec {
  /// Encodes [bundle] into the wire layout above.
  ///
  /// Throws [ArgumentError] if [bundle] has no signed prekey — every bundle
  /// [IdentityService.getLocalPreKeyBundle] assembles always has one; a
  /// bundle missing one is not a shape this codec is ever asked to carry.
  static Uint8List serialize(PreKeyBundle bundle) {
    final Uint8List identityKeyBytes = bundle.getIdentityKey().serialize();

    final ECPublicKey? signedPreKeyPublic = bundle.getSignedPreKey();
    final Uint8List? signedPreKeySignature = bundle.getSignedPreKeySignature();
    if (signedPreKeyPublic == null || signedPreKeySignature == null) {
      throw ArgumentError(
        'PreKeyBundleCodec.serialize: bundle has no signed prekey '
        '(getSignedPreKey()/getSignedPreKeySignature() returned null)',
      );
    }
    final Uint8List signedPreKeyPublicBytes = signedPreKeyPublic.serialize();

    final int? preKeyId = bundle.getPreKeyId();
    final ECPublicKey? preKeyPublic = bundle.getPreKey();
    final bool hasOneTimePreKey = preKeyId != null && preKeyPublic != null;
    final Uint8List oneTimePreKeyPublicBytes =
        hasOneTimePreKey ? preKeyPublic.serialize() : Uint8List(0);

    final int totalLength = 1 + // codecVersion
        4 + // registrationId
        4 + // deviceId
        1 + // hasOneTimePreKey
        4 + // preKeyId
        4 + oneTimePreKeyPublicBytes.length +
        4 + // signedPreKeyId
        4 + signedPreKeyPublicBytes.length +
        4 + signedPreKeySignature.length +
        4 + identityKeyBytes.length;

    final ByteData buffer = ByteData(totalLength);
    var offset = 0;

    buffer.setUint8(offset, preKeyBundleCodecVersion);
    offset += 1;

    buffer.setUint32(offset, bundle.getRegistrationId());
    offset += 4;

    buffer.setUint32(offset, bundle.getDeviceId());
    offset += 4;

    buffer.setUint8(offset, hasOneTimePreKey ? 1 : 0);
    offset += 1;

    buffer.setUint32(offset, hasOneTimePreKey ? preKeyId : 0);
    offset += 4;

    offset = _putLengthPrefixed(buffer, offset, oneTimePreKeyPublicBytes);

    buffer.setUint32(offset, bundle.getSignedPreKeyId());
    offset += 4;

    offset = _putLengthPrefixed(buffer, offset, signedPreKeyPublicBytes);
    offset = _putLengthPrefixed(buffer, offset, signedPreKeySignature);
    offset = _putLengthPrefixed(buffer, offset, identityKeyBytes);

    return buffer.buffer.asUint8List();
  }

  static int _putLengthPrefixed(ByteData buffer, int offset, Uint8List bytes) {
    buffer.setUint32(offset, bytes.length);
    offset += 4;
    final target = buffer.buffer.asUint8List();
    target.setRange(offset, offset + bytes.length, bytes);
    return offset + bytes.length;
  }

  /// Decodes bytes produced by [serialize]. Every `u32` length prefix is
  /// validated against the *remaining* buffer before it is used to slice
  /// (the same E05-B01 discipline `RelayPacketFrame.deserialize` follows).
  /// Throws [FormatException] naming the failing field on: an empty
  /// buffer, a truncated header, an unknown [preKeyBundleCodecVersion], a
  /// length prefix that would read past the end of the buffer, an
  /// undecodable EC public key, or trailing/missing bytes. Never returns a
  /// partially-built bundle.
  static PreKeyBundle deserialize(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException(
        'PreKeyBundleCodec: empty buffer, missing codecVersion byte',
      );
    }
    final ByteData view = ByteData.sublistView(bytes);
    var offset = 0;

    final int version = view.getUint8(offset);
    if (version != preKeyBundleCodecVersion) {
      throw FormatException(
        'PreKeyBundleCodec: unknown codecVersion '
        '(got $version, expected $preKeyBundleCodecVersion)',
      );
    }
    offset += 1;

    _requireRemaining(bytes, offset, 4, 'registrationId');
    final int registrationId = view.getUint32(offset);
    offset += 4;

    _requireRemaining(bytes, offset, 4, 'deviceId');
    final int deviceId = view.getUint32(offset);
    offset += 4;

    _requireRemaining(bytes, offset, 1, 'hasOneTimePreKey');
    final bool hasOneTimePreKey = view.getUint8(offset) == 1;
    offset += 1;

    _requireRemaining(bytes, offset, 4, 'preKeyId');
    final int preKeyIdRaw = view.getUint32(offset);
    offset += 4;

    final (Uint8List oneTimePreKeyPublicBytes, int afterOneTime) =
        _readLengthPrefixedBytes(view, bytes, offset, 'preKeyPublic');
    offset = afterOneTime;

    _requireRemaining(bytes, offset, 4, 'signedPreKeyId');
    final int signedPreKeyId = view.getUint32(offset);
    offset += 4;

    final (Uint8List signedPreKeyPublicBytes, int afterSignedPublic) =
        _readLengthPrefixedBytes(view, bytes, offset, 'signedPreKeyPublic');
    offset = afterSignedPublic;

    final (Uint8List signedPreKeySignature, int afterSignature) =
        _readLengthPrefixedBytes(
      view,
      bytes,
      offset,
      'signedPreKeySignature',
    );
    offset = afterSignature;

    final (Uint8List identityKeyBytes, int afterIdentity) =
        _readLengthPrefixedBytes(view, bytes, offset, 'identityKey');
    offset = afterIdentity;

    if (offset != bytes.length) {
      throw const FormatException(
        'PreKeyBundleCodec: declared fields do not account for the buffer '
        'exactly (trailing or missing bytes)',
      );
    }

    if (hasOneTimePreKey && oneTimePreKeyPublicBytes.isEmpty) {
      throw const FormatException(
        'PreKeyBundleCodec: hasOneTimePreKey set but preKeyPublic is empty',
      );
    }

    final int? preKeyId = hasOneTimePreKey ? preKeyIdRaw : null;
    final ECPublicKey? preKeyPublic = hasOneTimePreKey
        ? _decodePoint(oneTimePreKeyPublicBytes, 'preKeyPublic')
        : null;
    final ECPublicKey signedPreKeyPublic =
        _decodePoint(signedPreKeyPublicBytes, 'signedPreKeyPublic');
    final IdentityKey identityKey =
        _decodeIdentityKey(identityKeyBytes, 'identityKey');

    return PreKeyBundle(
      registrationId,
      deviceId,
      preKeyId,
      preKeyPublic,
      signedPreKeyId,
      signedPreKeyPublic,
      signedPreKeySignature,
      identityKey,
    );
  }

  static ECPublicKey _decodePoint(Uint8List bytes, String field) {
    try {
      return Curve.decodePoint(bytes, 0);
    } on InvalidKeyException catch (e) {
      throw FormatException(
        'PreKeyBundleCodec: undecodable EC public key in $field '
        '(${e.detailMessage})',
      );
    }
  }

  static IdentityKey _decodeIdentityKey(Uint8List bytes, String field) {
    try {
      return IdentityKey.fromBytes(bytes, 0);
    } on InvalidKeyException catch (e) {
      throw FormatException(
        'PreKeyBundleCodec: undecodable identity key in $field '
        '(${e.detailMessage})',
      );
    }
  }

  /// Throws [FormatException] naming [field] if fewer than [needed] bytes
  /// remain at [offset].
  static void _requireRemaining(
    Uint8List bytes,
    int offset,
    int needed,
    String field,
  ) {
    if (bytes.length < offset + needed) {
      throw FormatException(
        'PreKeyBundleCodec: truncated, missing $field '
        '(need $needed byte(s) at offset $offset, only '
        '${bytes.length - offset} remain)',
      );
    }
  }

  static (Uint8List, int) _readLengthPrefixedBytes(
    ByteData view,
    Uint8List bytes,
    int offset,
    String field,
  ) {
    _requireRemaining(bytes, offset, 4, '${field}Length');
    final int length = view.getUint32(offset);
    offset += 4;
    _requireRemaining(bytes, offset, length, field);
    final Uint8List value =
        Uint8List.fromList(bytes.sublist(offset, offset + length));
    offset += length;
    return (value, offset);
  }
}
