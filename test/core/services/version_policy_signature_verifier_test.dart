// E14-T03 -- VersionPolicySignatureVerifier tests (EARS-VER-17, FR-VER-011).
//
// A fixed-seed Ed25519 keypair makes every test deterministic without
// touching `--dart-define` at test-run time -- `publicKeyBytesOverride`
// is exactly the seam `VersionPolicyService`'s own test seams (e.g.
// `readVersionPolicyData`) already established the pattern for.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/services/version_policy_signature_verifier.dart';

void main() {
  final algorithm = Ed25519();
  late SimpleKeyPair keyPair;
  late List<int> publicKeyBytes;
  late List<int> otherPublicKeyBytes;

  const minimumSupportedBuild = 100;
  const currentBuild = 120;
  const updateAvailableBuild = 130;
  const updatedAt = 1700000000000;

  Future<String> sign(
    SimpleKeyPair signingKeyPair, {
    int minimumSupportedBuild = minimumSupportedBuild,
    int currentBuild = currentBuild,
    int updateAvailableBuild = updateAvailableBuild,
    int updatedAt = updatedAt,
  }) async {
    final message = VersionPolicySignatureVerifier.canonicalMessage(
      minimumSupportedBuild: minimumSupportedBuild,
      currentBuild: currentBuild,
      updateAvailableBuild: updateAvailableBuild,
      updatedAt: updatedAt,
    );
    final signature = await algorithm.sign(message, keyPair: signingKeyPair);
    return base64.encode(signature.bytes);
  }

  setUpAll(() async {
    keyPair = await algorithm.newKeyPairFromSeed(List.filled(32, 7));
    publicKeyBytes =
        (await keyPair.extractPublicKey()).bytes;

    final otherKeyPair = await algorithm.newKeyPairFromSeed(List.filled(32, 9));
    otherPublicKeyBytes = (await otherKeyPair.extractPublicKey()).bytes;
  });

  group('test_EARS_VER_17_valid_signature_verifies', () {
    test('a genuine signature over the exact fields, under the matching '
        'public key, verifies true', () async {
      final verifier = VersionPolicySignatureVerifier(
        publicKeyBytesOverride: publicKeyBytes,
      );
      final signatureBase64 = await sign(keyPair);

      final result = await verifier.verify(
        minimumSupportedBuild: minimumSupportedBuild,
        currentBuild: currentBuild,
        updateAvailableBuild: updateAvailableBuild,
        updatedAt: updatedAt,
        signatureBase64: signatureBase64,
      );

      expect(result, isTrue);
    });
  });

  group('test_EARS_VER_17_invalid_signature_fails_closed', () {
    test('a signature from a DIFFERENT keypair fails verification',
        () async {
      final otherKeyPair = await algorithm.newKeyPairFromSeed(
        List.filled(32, 9),
      );
      final verifier = VersionPolicySignatureVerifier(
        publicKeyBytesOverride: publicKeyBytes,
      );
      final wrongSignatureBase64 = await sign(otherKeyPair);

      final result = await verifier.verify(
        minimumSupportedBuild: minimumSupportedBuild,
        currentBuild: currentBuild,
        updateAvailableBuild: updateAvailableBuild,
        updatedAt: updatedAt,
        signatureBase64: wrongSignatureBase64,
      );

      expect(result, isFalse);
    });

    test('a genuine signature but TAMPERED numeric fields fails '
        'verification (proves the signature is bound to the fields, not '
        'just present)', () async {
      final verifier = VersionPolicySignatureVerifier(
        publicKeyBytesOverride: publicKeyBytes,
      );
      final signatureBase64 = await sign(keyPair);

      final result = await verifier.verify(
        minimumSupportedBuild: minimumSupportedBuild,
        currentBuild: currentBuild,
        updateAvailableBuild: 999, // tampered
        updatedAt: updatedAt,
        signatureBase64: signatureBase64,
      );

      expect(result, isFalse);
    });

    test('a well-formed but non-matching public key fails verification',
        () async {
      final verifier = VersionPolicySignatureVerifier(
        publicKeyBytesOverride: otherPublicKeyBytes,
      );
      final signatureBase64 = await sign(keyPair);

      final result = await verifier.verify(
        minimumSupportedBuild: minimumSupportedBuild,
        currentBuild: currentBuild,
        updateAvailableBuild: updateAvailableBuild,
        updatedAt: updatedAt,
        signatureBase64: signatureBase64,
      );

      expect(result, isFalse);
    });

    test('non-base64 signature text fails verification without throwing',
        () async {
      final verifier = VersionPolicySignatureVerifier(
        publicKeyBytesOverride: publicKeyBytes,
      );

      final result = await verifier.verify(
        minimumSupportedBuild: minimumSupportedBuild,
        currentBuild: currentBuild,
        updateAvailableBuild: updateAvailableBuild,
        updatedAt: updatedAt,
        signatureBase64: 'not-valid-base64!!!',
      );

      expect(result, isFalse);
    });

    test('a garbage (but valid-base64) signature of the wrong length '
        'fails verification without throwing', () async {
      final verifier = VersionPolicySignatureVerifier(
        publicKeyBytesOverride: publicKeyBytes,
      );

      final result = await verifier.verify(
        minimumSupportedBuild: minimumSupportedBuild,
        currentBuild: currentBuild,
        updateAvailableBuild: updateAvailableBuild,
        updatedAt: updatedAt,
        signatureBase64: base64.encode([1, 2, 3]),
      );

      expect(result, isFalse);
    });
  });

  group('test_EARS_VER_17_unconfigured_public_key_fails_closed', () {
    test('with no public key override (and no --dart-define at test run '
        'time), even a genuine signature fails verification -- fail '
        'CLOSED, not skip-verification', () async {
      final verifier = VersionPolicySignatureVerifier();
      final signatureBase64 = await sign(keyPair);

      final result = await verifier.verify(
        minimumSupportedBuild: minimumSupportedBuild,
        currentBuild: currentBuild,
        updateAvailableBuild: updateAvailableBuild,
        updatedAt: updatedAt,
        signatureBase64: signatureBase64,
      );

      expect(result, isFalse);
    });
  });

  group('test_review_F1_malformed_configured_public_key_fails_closed', () {
    test('a malformed (non-base64) public key injected via the SAME base64 '
        'decode path production uses (--dart-define) fails verification '
        'WITHOUT THROWING -- reviewer finding F1: this exact base64.decode '
        'call used to sit outside every try/catch, so a bad '
        '`VERSION_POLICY_PUBLIC_KEY` value crashed straight out of '
        'refresh(), breaking EARS-VER-4 at exactly the moment an ops '
        'paste error would ship one', () async {
      final verifier = VersionPolicySignatureVerifier(
        publicKeyBase64Override: 'not!!valid!!base64',
      );
      final signatureBase64 = await sign(keyPair);

      await expectLater(
        verifier.verify(
          minimumSupportedBuild: minimumSupportedBuild,
          currentBuild: currentBuild,
          updateAvailableBuild: updateAvailableBuild,
          updatedAt: updatedAt,
          signatureBase64: signatureBase64,
        ),
        completion(isFalse),
      );
    });
  });

  group('test_canonicalMessage_is_stable_and_field_order_sensitive', () {
    test('the same fields always produce the same message bytes', () {
      final a = VersionPolicySignatureVerifier.canonicalMessage(
        minimumSupportedBuild: 1,
        currentBuild: 2,
        updateAvailableBuild: 3,
        updatedAt: 4,
      );
      final b = VersionPolicySignatureVerifier.canonicalMessage(
        minimumSupportedBuild: 1,
        currentBuild: 2,
        updateAvailableBuild: 3,
        updatedAt: 4,
      );
      expect(a, equals(b));
    });

    test('different fields produce different message bytes', () {
      final a = VersionPolicySignatureVerifier.canonicalMessage(
        minimumSupportedBuild: 1,
        currentBuild: 2,
        updateAvailableBuild: 3,
        updatedAt: 4,
      );
      final b = VersionPolicySignatureVerifier.canonicalMessage(
        minimumSupportedBuild: 1,
        currentBuild: 2,
        updateAvailableBuild: 3,
        updatedAt: 5,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
