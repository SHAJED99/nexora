// E14-T01/T03 -- VersionPolicyService tests (EARS-VER-3, EARS-VER-4,
// EARS-VER-5, EARS-VER-17).
//
// Local read/write tests use a real in-memory AppDatabase (fast, no mocking
// needed for Drift). Firebase read tests use the same test-seam pattern as
// device_revocation_service_test.dart / firebase_metadata_service_test.dart
// -- subclass the service and override the seam method
// (`readVersionPolicyData`) instead of touching a real
// `FirebaseDatabase`/platform channel.
//
// E14-T03: every "successful refresh" fixture below now carries a REAL
// Ed25519 signature from a fixed-seed test keypair (`_signedPayload`), with
// the matching public key injected into `VersionPolicyService` via its own
// `signatureVerifier` test seam
// (`VersionPolicySignatureVerifier(publicKeyBytesOverride: ...)`) -- the
// literal string `'sig-v1'` this file used before E14-T03 never verifies
// against any key, so every test that expects a cached policy needed a
// genuine signature to keep passing. Every test's actual pass/fail
// assertion is unchanged; the one exception is `cached.signature`'s exact
// value, dropped from the first assertion below since it's now a real
// computed signature rather than a fixed literal worth pinning verbatim.
// `VersionPolicySignatureVerifier` has its own dedicated, more exhaustive
// test file (`version_policy_signature_verifier_test.dart`); the tests
// here only prove `VersionPolicyService.refresh()` is wired to it
// correctly, plus the new EARS-VER-17 group below.
import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/core/services/version_policy_signature_verifier.dart';

/// E14-B06 round 2 (F2 regression fixture): intercepts every write
/// statement Drift issues and throws instead of running it, while leaving
/// reads (`ensureOpen`, `runSelect`) untouched -- simulates a locked/full/
/// corrupt local SQLite database specifically on the write path, the exact
/// shape `refresh()`'s own `insertOnConflictUpdate` exercises.
class _ThrowingWriteInterceptor extends QueryInterceptor {
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    throw Exception('simulated locked/full/corrupt local database');
  }
}

/// Returns a fixed payload from the read seam, so [refresh] never touches a
/// real `FirebaseDatabase`.
class _FixedReadVersionPolicyService extends VersionPolicyService {
  _FixedReadVersionPolicyService({
    required super.database,
    required this.payload,
    super.signatureVerifier,
  });

  final Object? payload;

  @override
  Future<Object?> readVersionPolicyData() async => payload;
}

/// Always throws from the read seam, to prove [refresh] swallows and logs
/// rather than propagating (EARS-VER-4).
class _ThrowingReadVersionPolicyService extends VersionPolicyService {
  _ThrowingReadVersionPolicyService({
    required super.database,
    super.signatureVerifier,
  });

  @override
  Future<Object?> readVersionPolicyData() {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the read seam -- simulates a Realtime Database
/// read queued offline that never gets a server response. Proves the read
/// is bounded by `timeout`, not an indefinite hang (EARS-VER-4).
class _HangingReadVersionPolicyService extends VersionPolicyService {
  _HangingReadVersionPolicyService({
    required super.database,
    required super.timeout,
    super.signatureVerifier,
  });

  @override
  Future<Object?> readVersionPolicyData() => Completer<Object?>().future;
}

void main() {
  final algorithm = Ed25519();
  late SimpleKeyPair keyPair;
  late List<int> publicKeyBytes;
  late VersionPolicySignatureVerifier verifier;

  late AppDatabase database;

  Future<Map<String, Object?>> signedPayload({
    int minimumSupportedBuild = 100,
    int currentBuild = 120,
    int updateAvailableBuild = 130,
    int updatedAt = 1700000000000,
  }) async {
    final message = VersionPolicySignatureVerifier.canonicalMessage(
      minimumSupportedBuild: minimumSupportedBuild,
      currentBuild: currentBuild,
      updateAvailableBuild: updateAvailableBuild,
      updatedAt: updatedAt,
    );
    final signature = await algorithm.sign(message, keyPair: keyPair);
    return {
      'minimumSupportedBuild': minimumSupportedBuild,
      'currentBuild': currentBuild,
      'updateAvailableBuild': updateAvailableBuild,
      'signature': base64.encode(signature.bytes),
      'updatedAt': updatedAt,
    };
  }

  setUpAll(() async {
    keyPair = await algorithm.newKeyPairFromSeed(List.filled(32, 3));
    publicKeyBytes = (await keyPair.extractPublicKey()).bytes;
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    verifier = VersionPolicySignatureVerifier(
      publicKeyBytesOverride: publicKeyBytes,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('test_EARS_VER_5_cached_returns_null_before_first_refresh', () {
    test('cached() returns null when no refresh has ever succeeded',
        () async {
      final service = VersionPolicyService(
        database: database,
        signatureVerifier: verifier,
      );
      expect(await service.cached(), isNull);
    });
  });

  group('test_EARS_VER_3_refresh_success_overwrites_cache', () {
    test('a successful refresh caches the fetched policy, readable via '
        'cached()', () async {
      final service = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(),
        signatureVerifier: verifier,
      );

      await service.refresh();
      final cached = await service.cached();

      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
      expect(cached.currentBuild, 120);
      expect(cached.updateAvailableBuild, 130);
      expect(cached.updatedAt, 1700000000000);
    });

    test('a second successful refresh overwrites the first cached policy',
        () async {
      final firstService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );
      await firstService.refresh();

      final secondService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 200),
        signatureVerifier: verifier,
      );
      await secondService.refresh();

      final cached = await secondService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 200);
    });
  });

  group('test_EARS_VER_4_refresh_failure_leaves_cache_untouched', () {
    test('an exception from the read seam leaves the cache untouched and '
        'refresh() never throws', () async {
      // Seed a cache row via one successful refresh first, so this test
      // proves the failure leaves the PRE-EXISTING cache untouched, not
      // merely that it also stays absent.
      final seedingService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );
      await seedingService.refresh();

      final failingService = _ThrowingReadVersionPolicyService(
        database: database,
        signatureVerifier: verifier,
      );

      await expectLater(failingService.refresh(), completes);

      final cached = await failingService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });

    test('a timed-out read leaves the cache untouched and refresh() never '
        'throws', () async {
      final seedingService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );
      await seedingService.refresh();

      final hangingService = _HangingReadVersionPolicyService(
        database: database,
        timeout: const Duration(milliseconds: 10),
        signatureVerifier: verifier,
      );

      await expectLater(hangingService.refresh(), completes);

      final cached = await hangingService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });

    test('a malformed payload (wrong field types) leaves the cache '
        'untouched and refresh() never throws', () async {
      final seedingService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );
      await seedingService.refresh();

      final malformedService = _FixedReadVersionPolicyService(
        database: database,
        payload: {
          'minimumSupportedBuild': 'not-a-number',
          'currentBuild': 120,
          'updateAvailableBuild': 130,
          'signature': 'sig-v1',
          'updatedAt': 1700000000000,
        },
        signatureVerifier: verifier,
      );

      await expectLater(malformedService.refresh(), completes);

      final cached = await malformedService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });

    test('a payload carrying a key outside the FR-FB-001 allow-list leaves '
        'the cache untouched and refresh() never throws', () async {
      final seedingService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );
      await seedingService.refresh();

      final violatingPayload = await signedPayload(
        minimumSupportedBuild: 999,
      )..addAll({'extra': 'nope'});
      final violatingService = _FixedReadVersionPolicyService(
        database: database,
        payload: violatingPayload,
        signatureVerifier: verifier,
      );

      await expectLater(violatingService.refresh(), completes);

      final cached = await violatingService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });

    test(
        'a thrown error from the local Drift write is caught and '
        'refresh() never throws (E14-B06 round 2 F2 regression)', () async {
      // The original fix's `insertOnConflictUpdate` write sat OUTSIDE the
      // surrounding try/catch -- a locked/full/corrupt local database threw
      // straight out of `refresh()`, breaking `EARS-VER-4`'s "never
      // throws" contract for real. `_ThrowingWriteInterceptor` makes the
      // write throw deterministically without faking a whole Drift
      // executor.
      final throwingWriteDatabase = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(_ThrowingWriteInterceptor()),
      );
      addTearDown(throwingWriteDatabase.close);

      final service = _FixedReadVersionPolicyService(
        database: throwingWriteDatabase,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );

      await expectLater(service.refresh(), completes);
    });

    test('an absent (null) payload leaves the cache untouched and '
        'refresh() never throws', () async {
      final seedingService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );
      await seedingService.refresh();

      final absentService = _FixedReadVersionPolicyService(
        database: database,
        payload: null,
        signatureVerifier: verifier,
      );

      await expectLater(absentService.refresh(), completes);

      final cached = await absentService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });
  });

  group('test_EARS_VER_17_valid_signature_is_cached', () {
    test('a genuinely signed payload is cached (covered above too -- this '
        'group documents the EARS id explicitly)', () async {
      final service = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(),
        signatureVerifier: verifier,
      );

      await service.refresh();

      expect(await service.cached(), isNotNull);
    });
  });

  group('test_EARS_VER_17_invalid_signature_leaves_cache_untouched', () {
    test('a payload signed with a DIFFERENT keypair leaves the cache '
        'untouched and refresh() never throws', () async {
      final seedingService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );
      await seedingService.refresh();

      final otherKeyPair = await algorithm.newKeyPairFromSeed(
        List.filled(32, 5),
      );
      final message = VersionPolicySignatureVerifier.canonicalMessage(
        minimumSupportedBuild: 999,
        currentBuild: 120,
        updateAvailableBuild: 130,
        updatedAt: 1700000000000,
      );
      final wrongSignature = await algorithm.sign(
        message,
        keyPair: otherKeyPair,
      );
      final forgedPayload = {
        'minimumSupportedBuild': 999,
        'currentBuild': 120,
        'updateAvailableBuild': 130,
        'signature': base64.encode(wrongSignature.bytes),
        'updatedAt': 1700000000000,
      };

      final forgedService = _FixedReadVersionPolicyService(
        database: database,
        payload: forgedPayload,
        signatureVerifier: verifier,
      );

      await expectLater(forgedService.refresh(), completes);

      final cached = await forgedService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });

    test('a genuinely signed payload whose fields were then TAMPERED '
        '(signature no longer matches) leaves the cache untouched',
        () async {
      final seedingService = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(minimumSupportedBuild: 100),
        signatureVerifier: verifier,
      );
      await seedingService.refresh();

      final validPayload = await signedPayload(minimumSupportedBuild: 100);
      final tamperedPayload = Map<String, Object?>.from(validPayload)
        ..['minimumSupportedBuild'] = 777; // tampered post-signing

      final tamperedService = _FixedReadVersionPolicyService(
        database: database,
        payload: tamperedPayload,
        signatureVerifier: verifier,
      );

      await expectLater(tamperedService.refresh(), completes);

      final cached = await tamperedService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });
  });

  group('test_EARS_VER_17_unconfigured_public_key_fails_closed', () {
    test('with no signature verifier public key configured, even a '
        'genuinely well-formed payload is never cached -- fail CLOSED, '
        'not skip-verification', () async {
      final service = _FixedReadVersionPolicyService(
        database: database,
        payload: await signedPayload(),
        signatureVerifier: VersionPolicySignatureVerifier(),
      );

      await expectLater(service.refresh(), completes);

      expect(await service.cached(), isNull);
    });
  });
}
