// E13-T06 — real observability client (Sentry-or-equivalent) tests.
//
// BLOCKED at the pubspec.yaml 🧍 new_dependency gate (rule 3, docs/
// conventions.md "Third-party dependency additions"): `sentry_flutter` is
// NOT yet in pubspec.yaml/pubspec.lock, and adding it is a human call, not
// this agent's. See the task file's `## Open Questions` and `## Handoff` for
// the full account.
//
// What IS in scope and tested here without the vendor SDK: the internal
// client-injection seam this task adds inside `ObservabilityService` so a
// real vendor adapter can be dropped in later without touching either
// public method's signature or any of the dozens of existing `logError`/
// `log` call sites across `lib/`. `EARS-DIAG-2` and `EARS-DIAG-3` are fully
// testable against that seam using a fake client. `EARS-DIAG-1` (the chosen
// vendor's own default instrumentation not collecting PII) cannot be tested
// until a vendor is actually wired in — that test is written but skipped,
// with the reason stated inline, rather than silently omitted.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/observability/observability_service.dart';

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
      () {},
      skip: 'BLOCKED on the pubspec.yaml new_dependency human gate (rule 3) — '
          'no vendor SDK is wired in yet to assert default-instrumentation '
          'settings against. See E13-T06 ## Open Questions / ## Handoff.',
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
