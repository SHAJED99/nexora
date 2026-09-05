// E14-T01 -- VersionPolicyService tests (EARS-VER-3, EARS-VER-4, EARS-VER-5).
//
// Local read/write tests use a real in-memory AppDatabase (fast, no mocking
// needed for Drift). Firebase read tests use the same test-seam pattern as
// device_revocation_service_test.dart / firebase_metadata_service_test.dart
// -- subclass the service and override the seam method
// (`readVersionPolicyData`) instead of touching a real
// `FirebaseDatabase`/platform channel.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/version_policy_service.dart';

/// Returns a fixed payload from the read seam, so [refresh] never touches a
/// real `FirebaseDatabase`.
class _FixedReadVersionPolicyService extends VersionPolicyService {
  _FixedReadVersionPolicyService({
    required super.database,
    required this.payload,
  });

  final Object? payload;

  @override
  Future<Object?> readVersionPolicyData() async => payload;
}

/// Always throws from the read seam, to prove [refresh] swallows and logs
/// rather than propagating (EARS-VER-4).
class _ThrowingReadVersionPolicyService extends VersionPolicyService {
  _ThrowingReadVersionPolicyService({required super.database});

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
  });

  @override
  Future<Object?> readVersionPolicyData() => Completer<Object?>().future;
}

Map<String, Object?> _validPayload({
  int minimumSupportedBuild = 100,
  int currentBuild = 120,
  int updateAvailableBuild = 130,
  String signature = 'sig-v1',
  int updatedAt = 1700000000000,
}) => {
  'minimumSupportedBuild': minimumSupportedBuild,
  'currentBuild': currentBuild,
  'updateAvailableBuild': updateAvailableBuild,
  'signature': signature,
  'updatedAt': updatedAt,
};

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('test_EARS_VER_5_cached_returns_null_before_first_refresh', () {
    test('cached() returns null when no refresh has ever succeeded',
        () async {
      final service = VersionPolicyService(database: database);
      expect(await service.cached(), isNull);
    });
  });

  group('test_EARS_VER_3_refresh_success_overwrites_cache', () {
    test('a successful refresh caches the fetched policy, readable via '
        'cached()', () async {
      final service = _FixedReadVersionPolicyService(
        database: database,
        payload: _validPayload(),
      );

      await service.refresh();
      final cached = await service.cached();

      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
      expect(cached.currentBuild, 120);
      expect(cached.updateAvailableBuild, 130);
      expect(cached.signature, 'sig-v1');
      expect(cached.updatedAt, 1700000000000);
    });

    test('a second successful refresh overwrites the first cached policy',
        () async {
      final firstService = _FixedReadVersionPolicyService(
        database: database,
        payload: _validPayload(minimumSupportedBuild: 100),
      );
      await firstService.refresh();

      final secondService = _FixedReadVersionPolicyService(
        database: database,
        payload: _validPayload(minimumSupportedBuild: 200),
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
        payload: _validPayload(minimumSupportedBuild: 100),
      );
      await seedingService.refresh();

      final failingService = _ThrowingReadVersionPolicyService(
        database: database,
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
        payload: _validPayload(minimumSupportedBuild: 100),
      );
      await seedingService.refresh();

      final hangingService = _HangingReadVersionPolicyService(
        database: database,
        timeout: const Duration(milliseconds: 10),
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
        payload: _validPayload(minimumSupportedBuild: 100),
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
        payload: _validPayload(minimumSupportedBuild: 100),
      );
      await seedingService.refresh();

      final violatingPayload = _validPayload()..addAll({'extra': 'nope'});
      final violatingService = _FixedReadVersionPolicyService(
        database: database,
        payload: violatingPayload,
      );

      await expectLater(violatingService.refresh(), completes);

      final cached = await violatingService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });

    test('an absent (null) payload leaves the cache untouched and '
        'refresh() never throws', () async {
      final seedingService = _FixedReadVersionPolicyService(
        database: database,
        payload: _validPayload(minimumSupportedBuild: 100),
      );
      await seedingService.refresh();

      final absentService = _FixedReadVersionPolicyService(
        database: database,
        payload: null,
      );

      await expectLater(absentService.refresh(), completes);

      final cached = await absentService.cached();
      expect(cached, isNotNull);
      expect(cached!.minimumSupportedBuild, 100);
    });
  });
}
