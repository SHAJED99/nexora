// E13-T06 — real observability client (Sentry) tests.
//
// `sentry_flutter` is human-approved and wired in as
// `SentryObservabilityClient` (`lib/core/observability/
// observability_service.dart`). `EARS-DIAG-1`/`2`/`3` are all testable now:
// `EARS-DIAG-1` asserts the actual `SentryOptions` object
// `SentryObservabilityClient.init()` configures disables every
// PII-adjacent default named in the task's §6 Risks; `EARS-DIAG-2`/`3`
// exercise the `ObservabilityClient` injection seam with a fake client, as
// before.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/crypto/prekey_bundle_codec.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/device_directory_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Same test-seam pattern as `device_directory_service_test.dart`: subclass
/// `DeviceDirectoryService` and return a fixed raw `directory/$deviceId`
/// snapshot from the read seam, without touching a live `FirebaseDatabase`.
class _RespondingReadDeviceDirectoryService extends DeviceDirectoryService {
  _RespondingReadDeviceDirectoryService({
    required super.identityService,
    required super.database,
    required this.response,
  });

  final Object? response;

  @override
  Future<Object?> readDirectoryData(String deviceId) async => response;
}

class _RecordingClient implements ObservabilityClient {
  final List<(LogLevel, String, Object?)> captured = [];
  bool initCalled = false;

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  void capture(LogLevel level, String code, {Object? cause}) {
    captured.add((level, code, cause));
  }
}

class _ThrowingClient implements ObservabilityClient {
  @override
  Future<void> init() async {
    throw StateError('network error during init');
  }

  @override
  void capture(LogLevel level, String code, {Object? cause}) {
    throw StateError('network error sending event');
  }
}

void main() {
  group('EARS-DIAG-2 — error-level log forwards to the configured client', () {
    test(
        'test_EARS_DIAG_2_error_level_log_forwards_to_client',
        () async {
      final client = _RecordingClient();
      final service = ObservabilityService.withClient(client);
      await service.init();

      service.log(LogLevel.error, 'E_TEST_CODE', cause: 'some cause');

      expect(client.captured, hasLength(1));
      expect(client.captured.single.$1, LogLevel.error);
      expect(client.captured.single.$2, 'E_TEST_CODE');
      expect(client.captured.single.$3, 'some cause');
    });

    test('logError forwards as LogLevel.error to the configured client',
        () async {
      final client = _RecordingClient();
      final service = ObservabilityService.withClient(client);
      await service.init();

      service.logError('E_ANOTHER_CODE', cause: 'boom');

      expect(client.captured, hasLength(1));
      expect(client.captured.single.$1, LogLevel.error);
      expect(client.captured.single.$2, 'E_ANOTHER_CODE');
    });

    test('log() before init() completes is a no-op, never throws', () {
      final client = _RecordingClient();
      final service = ObservabilityService.withClient(client);

      expect(() => service.log(LogLevel.warn, 'E_TOO_EARLY'), returnsNormally);
      expect(client.captured, isEmpty);
    });
  });

  group('EARS-DIAG-3 — client failure never propagates to the caller', () {
    test('test_EARS_DIAG_3_client_failure_does_not_propagate', () async {
      final client = _ThrowingClient();
      final service = ObservabilityService.withClient(client);

      // init() itself must swallow a failing client's init error too —
      // every existing call site treats init()/log() as fire-and-forget.
      await expectLater(service.init(), completes);

      expect(
        () => service.log(LogLevel.error, 'E_WILL_FAIL', cause: 'x'),
        returnsNormally,
      );
      expect(() => service.logError('E_WILL_FAIL_2'), returnsNormally);
    });
  });

  group('EARS-DIAG-1 — vendor default instrumentation must not collect PII',
      () {
    test(
      'test_EARS_DIAG_1_chosen_vendor_default_instrumentation_disables_pii_collection',
      () {
        final options = SentryFlutterOptions();
        SentryObservabilityClient.configurePrivacyOptions(options);

        // §6 Risks: the chosen vendor's own default instrumentation must
        // not auto-capture PII/plaintext-adjacent data — assert every
        // setting this task's SentryObservabilityClient explicitly
        // disables, rather than trusting the SDK's shipped defaults.
        expect(options.sendDefaultPii, isFalse,
            reason: 'must not attach IP address / ambient PII by default');
        expect(options.attachScreenshot, isFalse,
            reason: 'a screenshot could capture on-screen message plaintext');
        // ignore: experimental_member_use
        expect(options.attachViewHierarchy, isFalse,
            reason: 'the view hierarchy can include widget text content');
        expect(options.enableUserInteractionBreadcrumbs, isFalse,
            reason: 'interaction breadcrumbs can include widget labels');
        expect(options.enableAutoNativeBreadcrumbs, isFalse,
            reason: 'native breadcrumbs are outside this app\'s own '
                'controlled logging surface (task §4)');
        expect(options.enablePrintBreadcrumbs, isFalse,
            reason: 'left at the SDK default of true, DebugPrintIntegration '
                'replaces global debugPrint in release/profile builds and '
                'ships every debugPrint call anywhere in the app or a '
                'dependency to Sentry as a breadcrumb');
        // No usage/behavior analytics for v1 (ADR-0006).
        expect(options.enableAutoSessionTracking, isFalse,
            reason: 'defaults to true; emits release-health session '
                'envelopes (device/OS/release + stable install id) on '
                'every foreground/background transition — usage '
                'telemetry ADR-0006 says does not ship in v1');
        // `tracesSampleRate` must stay unset: SentryOptions.isTracingEnabled()
        // treats ANY non-null value (including 0.0) as "tracing on".
        expect(options.tracesSampleRate, isNull,
            reason: 'a non-null value, even 0.0, turns tracing on per '
                'SentryOptions.isTracingEnabled()');
        expect(options.enableAutoPerformanceTracing, isFalse);
        expect(options.enableUserInteractionTracing, isFalse);
      },
    );
  });

  group('E13-B02 — device_directory_service.dart identity-mismatch cause '
      'must not leak deviceId to the vendor', () {
    // Reproduces the exact real path (`DeviceDirectoryService.lookupDevice`'s
    // E11-B02 identity-mismatch check) rather than a copy of its message
    // string, so reverting the fix in `device_directory_service.dart` makes
    // THIS test fail -- a test built from a duplicated string could stay
    // green even after a regression. Captures what the singleton would
    // actually forward to the vendor via
    // `ObservabilityService.debugOverrideInstanceClientForTesting`, since
    // production code always logs through `ObservabilityService.instance`,
    // never through `.withClient`.
    test(
      'test_E13_B02_lookupDevice_identity_mismatch_cause_excludes_device_id',
      () async {
        final dbA = AppDatabase.forTesting(NativeDatabase.memory());
        final dbB = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await dbA.close();
          await dbB.close();
        });
        final identityServiceA =
            IdentityService(dbA, DriftSignalProtocolStore(dbA));
        final identityServiceB =
            IdentityService(dbB, DriftSignalProtocolStore(dbB));
        await identityServiceA.ensureLocalIdentity();
        await identityServiceA.ensureSignedPreKey();
        await identityServiceA.replenishOneTimePreKeys();
        await identityServiceB.ensureLocalIdentity();
        await identityServiceB.ensureSignedPreKey();
        await identityServiceB.replenishOneTimePreKeys();

        final bundleA = await identityServiceA.getLocalPreKeyBundle();
        final bundleB = await identityServiceB.getLocalPreKeyBundle();

        // A forged entry: `identityPublicKey` names identity A, but the
        // identity key embedded inside `prekeyBundle` names identity B --
        // this is the exact E11-B02 mismatch `lookupDevice` detects and
        // logs.
        final forgedEntry = <String, Object?>{
          'identityPublicKey': hexEncodeBytes(bundleA.getIdentityKey().serialize()),
          'prekeyBundle': base64Encode(PreKeyBundleCodec.serialize(bundleB)),
        };

        final recordingClient = _RecordingClient();
        final restore = ObservabilityService
            .debugOverrideInstanceClientForTesting(recordingClient);
        addTearDown(restore);

        const sentinelDeviceId = 'sentinel-device-id-must-not-leak-E13-B02';
        final lookup = _RespondingReadDeviceDirectoryService(
          identityService: identityServiceA,
          database: dbA,
          response: forgedEntry,
        );

        final entry = await lookup.lookupDevice(sentinelDeviceId);

        expect(entry, isNull,
            reason: 'a mismatched entry must still be rejected');
        expect(recordingClient.captured, hasLength(1));
        final captured = recordingClient.captured.single;
        expect(captured.$2, 'firebase.device_directory_lookup_identity_mismatch');
        final capturedCause = captured.$3;
        expect(capturedCause, isNotNull);
        expect(
          capturedCause.toString(),
          isNot(contains(sentinelDeviceId)),
          reason: 'FR-DIAG-002: the cause shipped to Sentry via '
              'captureException must never interpolate the deviceId',
        );
      },
    );
  });

  group('existing call sites keep compiling unmodified', () {
    test('test_existing_logError_call_sites_still_compile_unmodified', () {
      // Compile-time proof, not a runtime assertion (per task §8): this
      // exercises the exact call shapes used across lib/ today against the
      // real singleton, unchanged signatures.
      ObservabilityService.instance.logError('E_COMPILE_CHECK');
      ObservabilityService.instance
          .logError('E_COMPILE_CHECK_2', cause: 'some cause');
      ObservabilityService.instance.log(LogLevel.info, 'E_COMPILE_CHECK_3');
      ObservabilityService.instance
          .log(LogLevel.debug, 'E_COMPILE_CHECK_4', cause: 42);
      expect(true, isTrue);
    });
  });
}
