// core/observability (ADR-0006, E13-T06).
//
// PARTIAL / BLOCKED (E13-T06): the task's own contract picks a real
// crash/error vendor (Sentry-or-equivalent, via `sentry_flutter`) and wires
// it in here, but adding that package to pubspec.yaml is a 🧍 rule-3
// `new_dependency` human gate (docs/conventions.md "Third-party dependency
// additions") that this agent cannot clear itself. See E13-T06's
// `## Open Questions` / `## Handoff` for the full account.
//
// What this task DID complete without the vendor SDK: `ObservabilityClient`
// is the injection seam a real vendor adapter drops into later, with zero
// changes to either public method's signature — so no other file's call
// site changes when the vendor is wired in. `_ConsoleObservabilityClient`
// is the same best-effort console behaviour the genesis stub had (debug
// builds only), now expressed as one concrete `ObservabilityClient`
// instead of being hardcoded into `log()` directly.
//
// FR-DIAG-002 (non-negotiable): never log message plaintext, keys,
// voice/call content, or precise location — not even here, not even later.
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;

enum LogLevel { debug, info, warn, error }

/// The seam a real vendor adapter (Sentry-or-equivalent) implements once
/// `sentry_flutter` clears the pubspec.yaml `new_dependency` human gate.
/// Every method here must itself be best-effort from the caller's point of
/// view: `ObservabilityService` treats any exception from these methods as
/// non-fatal (EARS-DIAG-3), but an implementation should still avoid doing
/// anything that can hang indefinitely (L-backend-002's lesson applies here
/// too, once a real network-backed client exists).
abstract class ObservabilityClient {
  Future<void> init();
  void capture(LogLevel level, String code, {Object? cause});
}

/// Best-effort console client — debug builds only, never in production.
/// This is the genesis stub's original behaviour, now the *default*
/// `ObservabilityClient` rather than being hardcoded into `log()`.
class _ConsoleObservabilityClient implements ObservabilityClient {
  @override
  Future<void> init() async {}

  @override
  void capture(LogLevel level, String code, {Object? cause}) {
    if (!kDebugMode) return;
    // ignore: avoid_print
    print('[${level.name}] $code${cause != null ? ' ($cause)' : ''}');
  }
}

class ObservabilityService {
  ObservabilityService._({ObservabilityClient? client})
      : _client = client ?? _ConsoleObservabilityClient();

  static final ObservabilityService instance = ObservabilityService._();

  /// Test-only seam: inject a fake/recording `ObservabilityClient` instead
  /// of the real one, without touching `init()`/`log()`/`logError()`'s
  /// public signatures. Not used by any production call site.
  @visibleForTesting
  factory ObservabilityService.withClient(ObservabilityClient client) =>
      ObservabilityService._(client: client);

  final ObservabilityClient _client;
  bool _initialized = false;

  /// Initializes the configured `ObservabilityClient`. Real client wiring
  /// (DSN, vendor SDK bootstrap) lands once the pubspec.yaml gate above is
  /// cleared; until then this initializes `_ConsoleObservabilityClient`,
  /// which matches the prior genesis stub's behaviour.
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
