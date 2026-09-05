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
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
        // No usage/behavior analytics for v1 (ADR-0006) — performance
        // tracing is unrelated to crash/error reporting.
        expect(options.tracesSampleRate, 0.0);
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
