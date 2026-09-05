// core/abuse -- generic rate-limiter primitive (ADR-0001, E13-T01, task
// §2/§3).
//
// A single fixed-window counter mechanism, shared by every later E13 task
// (connection requests, device registration, message/relay flooding, group
// invites, storage-exhausting inbound data, battery/network-draining
// request floods) instead of five ad hoc reimplementations of the same
// counting logic. Deliberately policy-free: no real limit number, window
// duration, or bucket-key naming scheme is decided here -- those are each
// consuming task's own decision (task §4).
import 'package:drift/drift.dart';

import '../persistence/database.dart';

/// One shared admission check every E13 subsystem task calls once per
/// admission decision (task §3).
class RateLimiter {
  RateLimiter(this._db);

  final AppDatabase _db;

  /// Fixed-window admission check for [bucketKey] (task §2):
  /// - if no window has started yet, or the current window has elapsed
  ///   since it started, the window resets and the counter is set to
  ///   [increment] -- always allowed (a rollover call can never itself
  ///   exceed a freshly-reset window).
  /// - otherwise, allows only while `count + increment <= maxCount`, then
  ///   increments the stored count by [increment] and returns `true`.
  /// - denies (returns `false`, without incrementing) if admitting
  ///   [increment] would exceed [maxCount] within the current window. A
  ///   denied call must never itself count toward ever un-denying (task
  ///   §2, EARS-ABUSE-2/3b).
  Future<bool> allow(
    String bucketKey, {
    required int maxCount,
    required Duration window,
    int increment = 1,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return _db.transaction<bool>(() async {
      final existing = await (_db.select(
        _db.rateLimitCounters,
      )..where((t) => t.bucketKey.equals(bucketKey))).getSingleOrNull();

      if (existing == null ||
          nowMs - existing.windowStartMs >= window.inMilliseconds) {
        // No bucket yet, or the window has elapsed: roll over to a fresh
        // window, seeded with `increment` (not 1) -- task §2's explicit
        // generalization for cumulative-quantity callers (e.g. E13-T05's
        // byte-volume check).
        await _db
            .into(_db.rateLimitCounters)
            .insertOnConflictUpdate(
              RateLimitCountersCompanion.insert(
                bucketKey: bucketKey,
                windowStartMs: nowMs,
                count: increment,
              ),
            );
        return true;
      }

      final newCount = existing.count + increment;
      if (newCount > maxCount) {
        // Deny without incrementing further (EARS-ABUSE-2/3b) -- the
        // stored row is left exactly as it was.
        return false;
      }

      await (_db.update(
        _db.rateLimitCounters,
      )..where((t) => t.bucketKey.equals(bucketKey))).write(
        RateLimitCountersCompanion(count: Value(newCount)),
      );
      return true;
    });
  }
}
