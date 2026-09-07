// core/crypto -- canonical hex encoding for a Signal identity public key's
// serialized bytes (E11-B06 finding 1, ADR-0008's 2026-09-05 addendum).
//
// Used both as this app's own Firebase Realtime Database
// `identityPublicKey` field encoding and, when a device signs in for the
// very first time with no prior local identity, as that device's own
// `deviceId` -- deliberately the SAME string, so a Realtime Database
// security rule can enforce the binding directly (a plain string
// equality, `$deviceId === newData.child('identityPublicKey').val()`) with
// no hash/signature primitive, which RTDB rules do not have. Hex (not
// base64) specifically because it never produces `/`, which the Firebase
// SDK's own `.child(path)` always treats as a path separator -- a
// standard-base64-encoded key can and does contain `/`, which would
// silently split a single device id into multiple path segments.
//
// Scope: this file only encodes/decodes bytes. It does NOT decide when a
// derived id is used instead of a random one (`login_controller.dart`'s
// own call site decides that), and does NOT touch `prekeyBundle`'s own
// encoding (still base64 -- never used as a path segment or compared
// against a deviceId, so it has no reason to change).
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// Lowercase hex, no separator, no padding. `identityKey.serialize()` is
/// libsignal's own byte representation (a type-prefix byte followed by
/// the raw Curve25519 point) -- this only changes how those bytes are
/// written as text, never what they mean cryptographically.
String hexEncodeIdentityKey(IdentityKey identityKey) =>
    hexEncodeBytes(identityKey.serialize());

/// Exposed separately from [hexEncodeIdentityKey] so a caller that only
/// has the raw serialized bytes (not yet wrapped in an [IdentityKey]) can
/// still produce the identical encoding -- e.g. deriving a fresh device id
/// from a keypair before any [IdentityKey] object is constructed from it.
String hexEncodeBytes(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Inverse of [hexEncodeIdentityKey]. Throws [FormatException] for
/// anything that isn't a well-formed, even-length hex string -- mirrors
/// `base64Decode`'s own throwing contract, so a caller already wrapping a
/// decode call in a try/catch (`DeviceDirectoryService.lookupDevice`)
/// needs no control-flow change to adopt this.
IdentityKey hexDecodeIdentityKey(String hex) =>
    IdentityKey.fromBytes(hexDecodeBytes(hex), 0);

/// Exposed separately from [hexDecodeIdentityKey] for the same reason as
/// [hexEncodeBytes] -- a caller that only needs the raw bytes (e.g.
/// comparing a claimed device id against a freshly-decoded key's own
/// re-encoding) does not need an [IdentityKey] constructed first.
// Strictly `0-9a-fA-F` only, exactly one match per byte pair. Deliberately
// NOT `int.tryParse(pair, radix: 16)` per pair -- that leniently accepts a
// leading `+`/`-` sign (e.g. `int.tryParse('+1', radix: 16) == 1`), which
// would silently decode a string like `'ab+1'` as two real bytes instead
// of rejecting it as malformed. This reads attacker-influenced remote
// data (`DeviceDirectoryService.lookupDevice`'s `identityPublicKey`
// field), so leniency here is a real correctness/security gap, not a
// style nit -- caught by this file's own test.
final RegExp _strictHexPair = RegExp(r'^[0-9a-fA-F]{2}$');

Uint8List hexDecodeBytes(String hex) {
  if (hex.isEmpty || hex.length.isOdd) {
    throw FormatException('empty or odd-length hex string', hex);
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    final byteHex = hex.substring(i * 2, i * 2 + 2);
    if (!_strictHexPair.hasMatch(byteHex)) {
      throw FormatException('invalid hex digit at position ${i * 2}', hex);
    }
    bytes[i] = int.parse(byteHex, radix: 16);
  }
  return bytes;
}
