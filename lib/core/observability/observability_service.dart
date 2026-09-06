// core/observability (ADR-0006, E13-T06).
//
// Real crash/error vendor: `sentry_flutter`, human-approved 2026-09-05
// (rule-3 `new_dependency` gate, see docs/conventions.md "Third-party
// dependency additions"). `ObservabilityClient` is the injection seam a
// vendor adapter drops into with zero changes to either public method's
// signature — so no other file's call site is touched by this task.
// `SentryObservabilityClient` is the real implementation, wired in as
// `ObservabilityService`'s default below; it also mirrors every event to
// the console in debug builds only, matching the original genesis stub's
// behaviour (kept "in addition to", not instead of, per task §3).
//
// FR-DIAG-002 (non-negotiable): never log message plaintext, keys,
// voice/call content, or precise location — not even here, not even later.
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

enum LogLevel { debug, info, warn, error }

/// The seam a real vendor adapter (`SentryObservabilityClient` below)
/// implements, so a fake/recording client can stand in for tests without
/// touching either public method's signature. Every method here must
/// itself be best-effort from the caller's point of view:
/// `ObservabilityService` treats any exception from these methods as
/// non-fatal (EARS-DIAG-3), but an implementation should still avoid doing
/// anything that can hang indefinitely (L-backend-002's lesson).
abstract class ObservabilityClient {
  Future<void> init();
  void capture(LogLevel level, String code, {Object? cause});
}

/// Real vendor adapter — Sentry (ADR-0006, human-approved `sentry_flutter`
/// dependency, E13-T06). DSN is read from a build-time `--dart-define`,
/// never hardcoded/committed as a literal string (task §5 "External
/// services & flags"): run with
/// `flutter run --dart-define=SENTRY_DSN=<your dsn>`. An empty DSN (the
/// default, e.g. in CI/dev without one configured) leaves the Sentry SDK
/// disabled — `SentryFlutter.init` treats an empty `dsn` as "do not send
/// events", so this never throws or silently phones home without one.
class SentryObservabilityClient implements ObservabilityClient {
  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  /// Applies this app's privacy-conscious `SentryFlutterOptions`, factored
  /// out of `init()` so `test_EARS_DIAG_1_*` can assert on the exact
  /// options object this class configures without going through
  /// `SentryFlutter.init`'s native platform-channel bootstrap (which
  /// `flutter_test`'s VM environment cannot exercise). Not part of the
  /// public `ObservabilityClient` seam.
  @visibleForTesting
  static void configurePrivacyOptions(SentryFlutterOptions options) {
    options.dsn = _dsn;

    // FR-DIAG-002 (non-negotiable) — explicitly disable every Sentry
    // default that could capture more than this app ever intends to send,
    // rather than trusting the SDK's own defaults to stay that way across
    // upgrades:
    // - `sendDefaultPii`: OFF. Sentry's own docs describe this flag as
    //   attaching the user's IP address and other ambient PII to every
    //   event by default when enabled; NEXORA never wants that.
    options.sendDefaultPii = false;
    // - `attachScreenshot`: OFF. A screenshot of the app at crash time
    //   could capture message plaintext or other on-screen content
    //   FR-DIAG-002 forbids.
    options.attachScreenshot = false;
    // - `attachViewHierarchy`: OFF. The view hierarchy dump can include
    //   widget text/label values (e.g. a message bubble's rendered text),
    //   which is exactly the plaintext FR-DIAG-002 forbids logging.
    // ignore: experimental_member_use
    options.attachViewHierarchy = false;
    // - `enableUserInteractionBreadcrumbs`: OFF. Tap/interaction
    //   breadcrumbs can include widget labels/descriptions; this app's
    //   own `log()`/`logError()` call sites are the only intended source
    //   of breadcrumbs, not automatic UI instrumentation.
    options.enableUserInteractionBreadcrumbs = false;
    // - `enableAutoNativeBreadcrumbs`: OFF. Native-side automatic
    //   breadcrumbs (e.g. platform-channel calls) are outside this task's
    //   scope (§4 — no native wiring) and outside this app's own
    //   controlled logging surface.
    options.enableAutoNativeBreadcrumbs = false;
    // - `enablePrintBreadcrumbs`: OFF. Left at the SDK default of `true`,
    //   `DebugPrintIntegration` is added unconditionally by
    //   `SentryFlutter.init` and, specifically in release/profile builds
    //   (the only builds that actually send to Sentry — it early-returns
    //   in debug), replaces Flutter's global `debugPrint` so that every
    //   `debugPrint` call anywhere in the app or in any dependency becomes
    //   a Sentry breadcrumb attached to every subsequent event. That is
    //   uncontrolled arbitrary text egressing to a third-party vendor in
    //   production — exactly what FR-DIAG-002 and this task's own §6 Risks
    //   ("disable it explicitly rather than assume it's off") forbid.
    options.enablePrintBreadcrumbs = false;
    // No analytics/usage tracking for v1 (ADR-0006). Session tracking and
    // performance tracing default to ON in the SDK, not off, so both are
    // explicitly disabled here rather than left untouched:
    // - `enableAutoSessionTracking`: OFF. Left at its SDK default of
    //   `true`, this emits release-health session envelopes on every
    //   app foreground/background transition — carrying device/OS/release
    //   context plus a stable installation id, i.e. usage telemetry, which
    //   ADR-0006 says does not ship in v1.
    options.enableAutoSessionTracking = false;
    // - Tracing: NOT enabled. `SentryOptions.isTracingEnabled()` treats
    //   any non-null `tracesSampleRate` — including `0.0` — as "tracing
    //   on" (it only checks `tracesSampleRate != null || tracesSampler !=
    //   null`), which would activate `enableAutoPerformanceTracing` /
    //   `enableUserInteractionTracing` (both default `true`) and
    //   `sentry-trace`/`baggage` header propagation on instrumented HTTP
    //   requests. So `tracesSampleRate` is deliberately left unset (its
    //   natural `null` default actually disables tracing), and the two
    //   auto-tracing flags are also explicitly turned off as a
    //   belt-and-braces statement of intent independent of that field.
    options.enableAutoPerformanceTracing = false;
    options.enableUserInteractionTracing = false;
  }

  @override
  Future<void> init() async {
    // E13-B03: an empty DSN (this app's default whenever
    // `--dart-define=SENTRY_DSN=...` is not passed, e.g. CI/dev) means
    // there is nothing for this client to send anywhere -- so skip
    // `SentryFlutter.init()` entirely rather than attempting it. This is
    // not merely a test workaround: `SentryFlutter.init()`'s own
    // `Sentry.init()` (in `package:sentry`) only rejects a NULL `dsn`,
    // not an empty one, so an empty-DSN call still unconditionally runs
    // every default integration (platform-channel calls included, e.g.
    // `package_info_plus` via `LoadReleaseIntegration`) with no public
    // option to opt out -- work that is always wasted when there is no
    // DSN, and that this investigation confirmed can hang indefinitely
    // (no error, no timeout) rather than complete when a real widget
    // frame/engine binding never pumps a frame for it to wait on (see
    // `test/core/observability/sentry_observability_client_init_test.dart`
    // for the full investigation and the regression test proving this).
    if (_dsn.isEmpty) {
      return;
    }
    await SentryFlutter.init(configurePrivacyOptions);
  }

  @override
  void capture(LogLevel level, String code, {Object? cause}) {
    if (kDebugMode) {
      // Mirrored "in addition to" the real vendor send (task §3), matching
      // the original genesis stub's debug-only console behaviour.
      // ignore: avoid_print
      print('[${level.name}] $code${cause != null ? ' ($cause)' : ''}');
    }
    final sentryLevel = switch (level) {
      LogLevel.debug => SentryLevel.debug,
      LogLevel.info => SentryLevel.info,
      LogLevel.warn => SentryLevel.warning,
      LogLevel.error => SentryLevel.error,
    };
    if (cause is Object && cause is! String) {
      Sentry.captureException(cause, hint: Hint.withMap({'code': code}));
    } else {
      Sentry.captureMessage(code, level: sentryLevel);
    }
  }
}

class ObservabilityService {
  ObservabilityService._({ObservabilityClient? client})
      : _client = client ?? SentryObservabilityClient();

  static final ObservabilityService instance = ObservabilityService._();

  /// Test-only seam: inject a fake/recording `ObservabilityClient` instead
  /// of the real one, without touching `init()`/`log()`/`logError()`'s
  /// public signatures. Not used by any production call site.
  @visibleForTesting
  factory ObservabilityService.withClient(ObservabilityClient client) =>
      ObservabilityService._(client: client);

  ObservabilityClient _client;
  bool _initialized = false;

  /// Test-only seam (E13-B02): temporarily swap the singleton `instance`'s
  /// own client and mark it initialized, so a test can observe exactly
  /// what a REAL production call site -- which always logs through
  /// `ObservabilityService.instance`, never through `.withClient` -- would
  /// actually send to the vendor. Returns a restore callback the caller
  /// MUST invoke (e.g. via `addTearDown`) to put the singleton back
  /// exactly as it was; this mutates process-wide state and is never used
  /// by any production call site.
  @visibleForTesting
  static void Function() debugOverrideInstanceClientForTesting(
    ObservabilityClient client,
  ) {
    final previousClient = instance._client;
    final previousInitialized = instance._initialized;
    instance._client = client;
    instance._initialized = true;
    return () {
      instance._client = previousClient;
      instance._initialized = previousInitialized;
    };
  }

  /// Initializes the configured `ObservabilityClient` — `SentryObservabilityClient`
  /// by default, bootstrapping the real Sentry SDK with the disabled-PII
  /// options documented on that class.
  Future<void> init() async {
    try {
      await _client.init();
    } catch (_) {
      // EARS-DIAG-3: a failing client must never stop the app from
      // finishing startup — every existing call site treats init() as
      // fire-and-forget.
    }
    _initialized = true;
  }

  void log(LogLevel level, String code, {Object? cause}) {
    if (!_initialized) return;
    try {
      _client.capture(level, code, cause: cause);
    } catch (_) {
      // EARS-DIAG-3: the observability client itself must never throw to
      // a caller that assumes fire-and-forget semantics (e.g. a network
      // failure sending the event to a real vendor).
    }
  }

  void logError(String code, {Object? cause}) => log(
        LogLevel.error,
        code,
        cause: cause,
      );
}
