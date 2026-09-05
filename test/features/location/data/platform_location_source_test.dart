// Tests for PlatformLocationSource (E09-T05, task file §5/§8,
// EARS-LOC-15/16/17).
//
// Every platform seam (service-enabled check, permission check/request,
// current-position read, last-known-position read) is injected as a plain
// function, matching this class's own contract that nothing here calls a
// static `Geolocator.*` global directly (task file §5) -- these tests never
// touch a real platform channel and never wait a real 10 s timeout.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/location/data/location_fix_repository.dart';
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/location/data/platform_location_source.dart';
import 'package:nexora/features/location/domain/location_share_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';

Position _fakePosition({
  double latitude = 40.7128,
  double longitude = -74.0060,
  double? accuracy = 5.0,
  required DateTime timestamp,
}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      accuracy: accuracy ?? 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('EARS-LOC-15 — approved share returns a real fix', () {
    test(
      'test_EARS_LOC_15_approved_share_returns_fix_with_provider_captured_at',
      () async {
        final capturedAt = DateTime.utc(2026, 9, 4, 12, 0, 0);
        final source = PlatformLocationSource(
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.whileInUse,
          requestPermission: () async =>
              fail('must not request when already granted'),
          currentPosition: (_) async => _fakePosition(timestamp: capturedAt),
          lastKnownPosition: () async =>
              fail('must not fall back when the current fix succeeds'),
        );

        final fix = await source.currentFix();

        expect(fix, isNotNull);
        expect(fix!.latitude, 40.7128);
        expect(fix.longitude, -74.0060);
        expect(fix.accuracyM, 5.0);
        expect(fix.capturedAtMs, capturedAt.millisecondsSinceEpoch);
      },
    );

    test(
      'test_EARS_LOC_15_captured_at_is_epoch_ms_not_boot_relative',
      () async {
        // A `DateTime` far from "now" -- if this class ever accidentally
        // substituted a boot-relative/monotonic value (task file §6 risk),
        // this assertion (an exact epoch-ms match to a fixed historical
        // instant) would fail; it can only pass via the documented
        // `DateTime.millisecondsSinceEpoch` conversion.
        final historical = DateTime.utc(2000, 1, 1);
        final source = PlatformLocationSource(
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.always,
          requestPermission: () async => fail('must not be called'),
          currentPosition: (_) async => _fakePosition(timestamp: historical),
          lastKnownPosition: () async => fail('must not be called'),
        );

        final fix = await source.currentFix();

        expect(fix!.capturedAtMs, 946684800000);
      },
    );

    test(
      'requests permission exactly once when initially denied, then reads a fix',
      () async {
        var requestCalls = 0;
        final source = PlatformLocationSource(
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.denied,
          requestPermission: () async {
            requestCalls++;
            return LocationPermission.whileInUse;
          },
          currentPosition: (_) async =>
              _fakePosition(timestamp: DateTime.utc(2026)),
          lastKnownPosition: () async => fail('must not be called'),
        );

        final fix = await source.currentFix();

        expect(fix, isNotNull);
        expect(requestCalls, 1);
      },
    );

    test(
      'timeout falls back to the platform last-known position',
      () async {
        final lastKnown = DateTime.utc(2026, 1, 1);
        final source = PlatformLocationSource(
          timeout: const Duration(milliseconds: 20),
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.whileInUse,
          requestPermission: () async => fail('must not be called'),
          // Never completes -- the class's own `.timeout()` wrapper is what
          // must cut this off, not a real 10 s wait.
          currentPosition: (_) => Completer<Position>().future,
          lastKnownPosition: () async => _fakePosition(timestamp: lastKnown),
        );

        final fix = await source.currentFix();

        expect(fix, isNotNull);
        expect(fix!.capturedAtMs, lastKnown.millisecondsSinceEpoch);
      },
    );
  });

  group('EARS-LOC-16 — every no-fix path returns null, never throws', () {
    test('test_EARS_LOC_16_permission_denied_returns_null', () async {
      // Call counters, not `fail('must not be called')`: a `fail()` thrown
      // from inside one of these seams is caught by this class's own broad
      // `catch (_)` (platform_location_source.dart:129-135) and collapses to
      // the same `null` this test already expects, so the guard would never
      // actually fail the test (opus review on PR #42, finding F1). A
      // counter asserted with `expect(..., 0)` in the test body cannot be
      // swallowed that way.
      var currentPositionCalls = 0;
      var lastKnownCalls = 0;
      final source = PlatformLocationSource(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async => LocationPermission.denied,
        currentPosition: (_) async {
          currentPositionCalls++;
          return _fakePosition(timestamp: DateTime.utc(2026));
        },
        lastKnownPosition: () async {
          lastKnownCalls++;
          return null;
        },
      );

      expect(await source.currentFix(), isNull);
      expect(currentPositionCalls, 0);
      expect(lastKnownCalls, 0);
    });

    test(
      'test_EARS_LOC_16_permission_permanently_denied_returns_null',
      () async {
        var requestCalls = 0;
        var currentPositionCalls = 0;
        var lastKnownCalls = 0;
        final source = PlatformLocationSource(
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.deniedForever,
          requestPermission: () async {
            requestCalls++;
            return LocationPermission.deniedForever;
          },
          currentPosition: (_) async {
            currentPositionCalls++;
            return _fakePosition(timestamp: DateTime.utc(2026));
          },
          lastKnownPosition: () async {
            lastKnownCalls++;
            return null;
          },
        );

        expect(await source.currentFix(), isNull);
        // Permanently-denied is a distinct state (task file §6): the
        // permission is already `deniedForever`, not `denied`, so this
        // class must not even attempt the re-prompt that Android silently
        // no-ops.
        expect(requestCalls, 0);
        expect(currentPositionCalls, 0);
        expect(lastKnownCalls, 0);
      },
    );

    test('test_EARS_LOC_16_provider_disabled_returns_null', () async {
      var checkPermissionCalls = 0;
      var requestPermissionCalls = 0;
      var currentPositionCalls = 0;
      var lastKnownCalls = 0;
      final source = PlatformLocationSource(
        isLocationServiceEnabled: () async => false,
        checkPermission: () async {
          checkPermissionCalls++;
          return LocationPermission.whileInUse;
        },
        requestPermission: () async {
          requestPermissionCalls++;
          return LocationPermission.whileInUse;
        },
        currentPosition: (_) async {
          currentPositionCalls++;
          return _fakePosition(timestamp: DateTime.utc(2026));
        },
        lastKnownPosition: () async {
          lastKnownCalls++;
          return null;
        },
      );

      expect(await source.currentFix(), isNull);
      // The provider-off short-circuit (task file §2 step 1) must return
      // before touching the permission chain or either position read.
      expect(checkPermissionCalls, 0);
      expect(requestPermissionCalls, 0);
      expect(currentPositionCalls, 0);
      expect(lastKnownCalls, 0);
    });

    test(
      'test_EARS_LOC_16_timeout_returns_null_with_no_last_known_fix',
      () async {
        var requestPermissionCalls = 0;
        final source = PlatformLocationSource(
          timeout: const Duration(milliseconds: 20),
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.whileInUse,
          requestPermission: () async {
            requestPermissionCalls++;
            return LocationPermission.whileInUse;
          },
          currentPosition: (_) => Completer<Position>().future,
          lastKnownPosition: () async => null,
        );

        expect(await source.currentFix(), isNull);
        // Permission is already granted (`whileInUse`) -- the `denied`
        // branch that triggers a request must not run.
        expect(requestPermissionCalls, 0);
      },
    );

    test('test_EARS_LOC_16_platform_exception_returns_null', () async {
      var requestPermissionCalls = 0;
      var lastKnownCalls = 0;
      final source = PlatformLocationSource(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async {
          requestPermissionCalls++;
          return LocationPermission.whileInUse;
        },
        currentPosition: (_) async =>
            throw PlatformException(code: 'boom'),
        // A non-timeout platform exception must NOT fall back to
        // last-known (task file §5) -- it resolves to null directly.
        lastKnownPosition: () async {
          lastKnownCalls++;
          return null;
        },
      );

      expect(await source.currentFix(), isNull);
      expect(requestPermissionCalls, 0);
      expect(lastKnownCalls, 0);
    });

    test(
      'unableToDetermine permission returns null without a second request',
      () async {
        var requestCalls = 0;
        var currentPositionCalls = 0;
        var lastKnownCalls = 0;
        final source = PlatformLocationSource(
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.unableToDetermine,
          requestPermission: () async {
            requestCalls++;
            return LocationPermission.unableToDetermine;
          },
          currentPosition: (_) async {
            currentPositionCalls++;
            return _fakePosition(timestamp: DateTime.utc(2026));
          },
          lastKnownPosition: () async {
            lastKnownCalls++;
            return null;
          },
        );

        expect(await source.currentFix(), isNull);
        expect(requestCalls, 0);
        expect(currentPositionCalls, 0);
        expect(lastKnownCalls, 0);
      },
    );

    test(
      'isLocationServiceEnabled throwing collapses to null, never rethrows',
      () async {
        var checkPermissionCalls = 0;
        var requestPermissionCalls = 0;
        var currentPositionCalls = 0;
        var lastKnownCalls = 0;
        final source = PlatformLocationSource(
          isLocationServiceEnabled: () async =>
              throw PlatformException(code: 'service-check-failed'),
          checkPermission: () async {
            checkPermissionCalls++;
            return LocationPermission.whileInUse;
          },
          requestPermission: () async {
            requestPermissionCalls++;
            return LocationPermission.whileInUse;
          },
          currentPosition: (_) async {
            currentPositionCalls++;
            return _fakePosition(timestamp: DateTime.utc(2026));
          },
          lastKnownPosition: () async {
            lastKnownCalls++;
            return null;
          },
        );

        expect(await source.currentFix(), isNull);
        expect(checkPermissionCalls, 0);
        expect(requestPermissionCalls, 0);
        expect(currentPositionCalls, 0);
        expect(lastKnownCalls, 0);
      },
    );
  });

  group('EARS-LOC-17 — no permission is ever requested for a refused share', () {
    test(
      'test_EARS_LOC_17_policy_refusal_never_requests_permission',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final store = DriftSignalProtocolStore(db);
        final stack = await MessagingStack.create(
          db: db,
          selfDeviceId: 'device-a',
          store: store,
          cryptoService: CryptoService.withStore(store),
          transport: TransportService(
            binaryMessenger: messenger,
            messageChannelSuffix: 'platform-location-source-ears-loc-17',
          ),
        );
        addTearDown(stack.dispose);
        expect(stack.status, const MessagingStackStatus.ready());

        // Global sharing is off by default (FR-LOC-001) -- the visibility
        // gate must refuse this share before `PlatformLocationSource`'s
        // seams are ever touched.
        var serviceEnabledCalls = 0;
        var checkPermissionCalls = 0;
        var requestPermissionCalls = 0;
        final source = PlatformLocationSource(
          isLocationServiceEnabled: () async {
            serviceEnabledCalls++;
            return true;
          },
          checkPermission: () async {
            checkPermissionCalls++;
            return LocationPermission.denied;
          },
          requestPermission: () async {
            requestPermissionCalls++;
            return LocationPermission.whileInUse;
          },
          currentPosition: (_) async => fail('must not be called'),
          lastKnownPosition: () async => fail('must not be called'),
        );

        final service = LocationShareService(
          stack: stack,
          settings: LocationSettingsRepository(db: db),
          fixes: LocationFixRepository(db: db),
          relationships: RelationshipRepository(db),
          locationSource: source,
        );

        final outcome = await service.share('device-b');

        // Any policy refusal reason is fine here -- this is EARS-LOC-17's
        // own claim ("no share has been approved"), not a re-test of
        // `LocationVisibilityPolicy`'s own precedence (T02's contract). No
        // relationship exists yet for 'device-b' and global sharing is off
        // by default (FR-LOC-001), so the gate refuses before this device's
        // position -- or its permission -- is ever touched.
        expect(outcome, isA<LocationShareOutcomeBlockedByPolicy>());
        expect(serviceEnabledCalls, 0);
        expect(checkPermissionCalls, 0);
        expect(requestPermissionCalls, 0);
      },
    );
  });
}
