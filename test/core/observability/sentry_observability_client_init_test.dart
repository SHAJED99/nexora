// E13-B03 — regression test for the root-cause investigation into why
// `SentryFlutter.init()` hangs indefinitely (no error, no timeout) when
// called for real inside a `flutter test` VM with no DSN configured (the
// CI/dev default -- see `SentryObservabilityClient`'s own class doc).
//
// Kept in its own file, deliberately isolated from
// `observability_service_test.dart`'s shared-singleton tests (per this
// task's own instruction: don't let an investigation into a hang risk
// introducing a new hanging test into the main suite). This file
// constructs `SentryObservabilityClient` directly -- never
// `ObservabilityService.instance` -- so it cannot mutate the shared
// singleton's state and cannot affect any other test file.
//
// Repro requires `testWidgets`, not a bare `test()` (confirmed by hand
// during this investigation): under a bare `test()` -- no
// `TestWidgetsFlutterBinding` active -- `SentryFlutter.init()` completes
// (or throws) quickly even pre-fix, because `flutter_test`'s automatic
// platform-channel mocking answers every unmocked channel call (e.g.
// `package_info_plus`'s `PackageInfo.fromPlatform()`, invoked
// unconditionally by `sentry_flutter`'s `LoadReleaseIntegration`) with a
// `MissingPluginException` right away. Under `testWidgets` -- the shape
// production code actually runs inside (a real widget app) -- the exact
// same call hangs forever with no pump ever occurring, which strongly
// points at one of `sentry_flutter`'s default integrations depending on
// a widget frame callback that only fires once the test explicitly
// pumps a frame (e.g. `NativeAppStartIntegration`'s
// `DefaultFrameCallbackHandler`, added whenever
// `PlatformChecker.hasNativeIntegration` is true -- true for every
// desktop/mobile platform including the Windows/Linux host `flutter
// test` actually runs on, per `platform_checker.dart`) -- a callback
// `ObservabilityService.instance.init()`'s caller has no reason to ever
// supply, since nothing about initializing observability is expected to
// need a rendered frame.
//
// Regardless of exactly which default integration is the one waiting on
// that callback, `sentry_flutter` 8.14.2's own `Sentry.init()` (in
// `package:sentry`) only rejects a NULL `dsn` -- an EMPTY string (this
// app's actual default with no dart-define set) passes that guard and
// falls through to running the FULL default integration list
// unconditionally, with no public option to opt out of it while DSN is
// unset. That is `sentry_flutter` behavior this app's wrapper cannot
// reach into and fix. What the wrapper CAN control is not entering that
// pipeline at all when it has no DSN to send anything to in the first
// place -- there is nothing useful for `SentryObservabilityClient` to
// initialize in that case, so `init()` now skips calling
// `SentryFlutter.init()` entirely when the DSN is empty
// (`observability_service.dart`).
//
// This test uses a bounded `.timeout()` (never a bare `await`) precisely
// because a regression here must fail fast, not hang the suite the way
// the original bug did.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/observability/observability_service.dart';

void main() {
  group('E13-B03 — SentryObservabilityClient.init() must not hang with an '
      'empty (unconfigured) DSN', () {
    testWidgets(
      'test_E13_B03_sentry_flutter_init_completes_quickly_with_empty_dsn',
      (tester) async {
        final client = SentryObservabilityClient();

        // A bounded `.timeout()`, not a bare `await`: if this regresses,
        // the test must fail loudly and quickly, never hang the suite
        // the way the original bug did. 8s is generously above how long
        // a real completion (or a skip) takes, and well below the outer
        // per-test `Timeout` below, so a genuine hang is distinguishable
        // from ordinary CI slowness.
        await client.init().timeout(
          const Duration(seconds: 8),
          onTimeout: () => fail(
            'SentryObservabilityClient.init() hung beyond 8s with an '
            'empty DSN -- see this test file\'s header comment for the '
            'root cause this guards against',
          ),
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });
}
