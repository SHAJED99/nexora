// core/services -- VersionPolicySignatureVerifier (E14-T03, FR-VER-011).
//
// Verifies `config/version_policy`'s `signature` field before
// `VersionPolicyService.refresh()` ever trusts a fetched payload. Per
// `OQ-E14-T03-1`'s resolved answer:
//   - Asymmetric signing: an ops/release process (outside this repo) holds
//     the Ed25519 PRIVATE key and signs each policy payload. This app ships
//     only the corresponding PUBLIC key, embedded at build time via
//     `--dart-define=VERSION_POLICY_PUBLIC_KEY=<base64>` -- never a shared
//     secret, never the private key.
//   - Fail-CLOSED at the signature check itself: a missing/invalid/
//     unverifiable signature is never trusted as a valid policy. This
//     composes with `VersionPolicyService`'s EXISTING fail-open default
//     (no valid cached policy -> `EvaluateVersionStateUseCase` falls back
//     to `UP_TO_DATE`) rather than inventing a new, stricter failure mode --
//     the net effect is: a bad signature is treated exactly like "no
//     policy fetched yet," not like "force everyone to update."
//
// Canonical signed message (this app's own definition -- the ops process
// that signs a policy payload must reproduce this exact string): the four
// numeric fields, pipe-joined in this fixed order, UTF-8 encoded:
//   "$minimumSupportedBuild|$currentBuild|$updateAvailableBuild|$updatedAt"
// `signature` itself is never part of the signed message (it IS the
// signature). Documented here because there is no other reader for it --
// the signing side lives entirely outside this repo.
//
// Scope fence (task §4): this does NOT choose or build the ops-side
// signing process, key custody, or rotation procedure -- those are an
// operational runbook, not code this task builds. It does NOT change what
// happens on a valid signature (the existing cache-write behavior is
// unchanged); it only gates whether a fetched payload is treated as valid
// input to that existing behavior at all.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:nexora/core/observability/observability_service.dart';

/// The build-time-embedded Ed25519 PUBLIC key, base64-encoded. Empty by
/// default (e.g. local dev/CI builds with no `--dart-define` passed) --
/// per the fail-closed decision, an unconfigured key means every fetched
/// policy fails verification, never that verification is skipped. There
/// is no "trust anything" fallback mode for this field.
const String _publicKeyBase64 = String.fromEnvironment(
  'VERSION_POLICY_PUBLIC_KEY',
);

class VersionPolicySignatureVerifier {
  // Public param name (`publicKeyBytesOverride`) can't match the private
  // field below, so `prefer_initializing_formals` doesn't apply -- same
  // reasoning as `VersionPolicyService`'s own `_database = database`.
  VersionPolicySignatureVerifier({List<int>? publicKeyBytesOverride})
      : _publicKeyBytesOverride = publicKeyBytesOverride; // ignore: prefer_initializing_formals

  /// Test seam: lets a test inject a known keypair's public key instead of
  /// relying on a `--dart-define` being present at test-run time. `null` in
  /// production, where [_publicKeyBase64] (or its absence) is the only
  /// source of truth.
  final List<int>? _publicKeyBytesOverride;

  static final Ed25519 _algorithm = Ed25519();

  /// Builds this app's own canonical signed message for a policy's four
  /// numeric fields -- see file header. Exposed so a test (or, in
  /// principle, a future signing tool) can construct the exact bytes an
  /// ops process must sign.
  static List<int> canonicalMessage({
    required int minimumSupportedBuild,
    required int currentBuild,
    required int updateAvailableBuild,
    required int updatedAt,
  }) {
    return utf8.encode(
      '$minimumSupportedBuild|$currentBuild|$updateAvailableBuild|$updatedAt',
    );
  }

  /// Verifies [signatureBase64] over the canonical message built from the
  /// four numeric fields. Returns `true` only if a public key is
  /// configured (build-time or test override) AND the signature is a
  /// genuine Ed25519 signature over that exact message under that exact
  /// key. Never throws -- any malformed input (bad base64, wrong-length
  /// key/signature) is itself a verification failure, not a crash, since
  /// this reads attacker-influenced remote data.
  Future<bool> verify({
    required int minimumSupportedBuild,
    required int currentBuild,
    required int updateAvailableBuild,
    required int updatedAt,
    required String signatureBase64,
  }) async {
    final publicKeyBytes = _publicKeyBytesOverride ??
        (_publicKeyBase64.isEmpty ? null : base64.decode(_publicKeyBase64));
    if (publicKeyBytes == null) {
      // No key configured -- fail closed, not "skip verification". This is
      // the expected state for a build that never embedded one; it is not
      // itself an error worth logging on every single refresh.
      return false;
    }

    final Uint8List signatureBytes;
    try {
      signatureBytes = base64.decode(signatureBase64);
    } on FormatException catch (e) {
      ObservabilityService.instance.logError(
        'version_policy.signature_not_base64',
        cause: e,
      );
      return false;
    }

    final message = canonicalMessage(
      minimumSupportedBuild: minimumSupportedBuild,
      currentBuild: currentBuild,
      updateAvailableBuild: updateAvailableBuild,
      updatedAt: updatedAt,
    );

    try {
      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );
      final signature = Signature(signatureBytes, publicKey: publicKey);
      return await _algorithm.verify(message, signature: signature);
    } catch (e) {
      // A malformed key/signature (wrong length, wrong curve point, etc.)
      // throws from the underlying crypto library rather than returning
      // false -- fold it into the same "not verified" outcome rather than
      // letting a hostile/corrupt payload crash `refresh()`.
      ObservabilityService.instance.logError(
        'version_policy.signature_verification_error',
        cause: e,
      );
      return false;
    }
  }
}
