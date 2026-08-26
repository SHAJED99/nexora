// core/observability — genesis structural stub (ADR-0006).
//
// Real crash/error reporting (Sentry-or-equivalent) is out of scope for
// genesis. This gives every layer one place to log through — never
// `print()` in lib/, per docs/conventions.md — so later epics swap the
// no-op body for a real client without touching call sites.
//
// FR-DIAG-002 (non-negotiable): never log message plaintext, keys,
// voice/call content, or precise location — not even here, not even later.
enum LogLevel { debug, info, warn, error }

class ObservabilityService {
  ObservabilityService._();
  static final ObservabilityService instance = ObservabilityService._();

  bool _initialized = false;

  /// Wires up the real crash/error client in a later epic. No-op for now.
  Future<void> init() async {
    _initialized = true;
  }

  void log(LogLevel level, String code, {Object? cause}) {
    if (!_initialized) return;
    // ignore: avoid_print
    print('[${level.name}] $code${cause != null ? ' ($cause)' : ''}');
  }

  void logError(String code, {Object? cause}) => log(
        LogLevel.error,
        code,
        cause: cause,
      );
}
