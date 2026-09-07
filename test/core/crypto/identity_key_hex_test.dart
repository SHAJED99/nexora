// E11-B06 finding 1 -- identity_key_hex.dart tests.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';

void main() {
  late IdentityKeyPair keyPair;

  setUpAll(() {
    keyPair = generateIdentityKeyPair();
  });

  group('test_hexEncodeBytes_and_hexDecodeBytes_round_trip', () {
    test('encoding then decoding returns the identical bytes', () {
      final original = Uint8List.fromList([0, 1, 2, 254, 255, 16, 17]);
      final encoded = hexEncodeBytes(original);
      final decoded = hexDecodeBytes(encoded);
      expect(decoded, equals(original));
    });

    test('encoding is lowercase, no separator, two chars per byte', () {
      final encoded = hexEncodeBytes([0xAB, 0x01, 0xFF]);
      expect(encoded, 'ab01ff');
    });

    test('never produces a "/" or "+" or "=" -- the whole reason this '
        'exists instead of base64 (Firebase\'s .child(path) always splits '
        'on "/")', () {
      // Every possible byte value, all 256 of them -- if any byte's hex
      // pair could ever contain a path-unsafe character, this would catch
      // it (it can't: hex digits are only 0-9a-f).
      final allBytes = List.generate(256, (i) => i);
      final encoded = hexEncodeBytes(allBytes);
      expect(encoded.contains('/'), isFalse);
      expect(encoded.contains('+'), isFalse);
      expect(encoded.contains('='), isFalse);
    });
  });

  group('test_hexEncodeIdentityKey_and_hexDecodeIdentityKey_round_trip', () {
    test('encoding a real identity key then decoding it back produces an '
        'identity key with identical serialized bytes', () {
      final publicKey = keyPair.getPublicKey();
      final encoded = hexEncodeIdentityKey(publicKey);
      final decoded = hexDecodeIdentityKey(encoded);
      expect(decoded.serialize(), equals(publicKey.serialize()));
    });

    test('two different identity keys encode to different hex strings',
        () {
      final otherKeyPair = generateIdentityKeyPair();
      final encodedA = hexEncodeIdentityKey(keyPair.getPublicKey());
      final encodedB = hexEncodeIdentityKey(otherKeyPair.getPublicKey());
      expect(encodedA, isNot(equals(encodedB)));
    });
  });

  group('test_hexDecodeBytes_rejects_malformed_input', () {
    test('an empty string throws FormatException', () {
      expect(() => hexDecodeBytes(''), throwsFormatException);
    });

    test('an odd-length string throws FormatException', () {
      expect(() => hexDecodeBytes('abc'), throwsFormatException);
    });

    test('a non-hex character throws FormatException', () {
      expect(() => hexDecodeBytes('zz'), throwsFormatException);
    });

    test('a standard-base64-shaped string (containing "/" or "+") throws '
        'FormatException, not silently misdecoded', () {
      expect(() => hexDecodeBytes('ab/1'), throwsFormatException);
      expect(() => hexDecodeBytes('ab+1'), throwsFormatException);
    });
  });

  group('test_hexDecodeIdentityKey_rejects_malformed_input', () {
    test('a malformed hex string throws FormatException before ever '
        'reaching IdentityKey.fromBytes', () {
      expect(() => hexDecodeIdentityKey('not-hex!!'), throwsFormatException);
    });
  });
}
