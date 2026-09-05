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

  /// `E13-T07` (`OQ-E13-T01-1`): a conservative staleness bound used by the
  /// opportunistic eviction in [allow] below. Comfortably larger than the
  /// longest fixed window any caller in this codebase uses today
  /// (`DeviceIdentityRepository`'s 24h device-registration window is
  /// currently the longest) so a row is only ever evicted long after every
  /// legitimate caller's own window would already have rolled it over on
  /// its own — eviction can only ever delay tidying up a dead row, never
  /// touch one that could still matter to a live limit (task §6 risk: "An
  /// eviction policy that runs too aggressively could evict a bucket
  /// mid-window").
  ///
  /// This table has no column recording which `window` a given row's
  /// caller actually used (task §5: "no schema-visible change" is the
  /// preferred shape), so eviction cannot know a *specific* row's own
  /// window duration — it only knows this single, deliberately generous
  /// upper bound shared by every bucket kind in the table.
  static const Duration _staleRowMaxAge = Duration(days: 2);

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
      // `E13-T07` (`OQ-E13-T01-1`): opportunistic eviction, piggy-backed on
      // this existing write path rather than a new polling timer (task §3's
      // own suggested shape) -- bounds `RateLimitCounters` row growth under
      // a flood of distinct, attacker-rotated bucket keys (E13-T02's
      // reviewer probed this directly: 500 requests with a rotating,
      // attacker-chosen `deviceId` produced 500 permanent rows and zero
      // denials, because `connection_request:$deviceId` is keyed on a value
      // the remote peer controls). Every `allow()` call first deletes any
      // row whose window elapsed at least [_staleRowMaxAge] ago, regardless
      // of that row's own `bucketKey` -- so the table can never grow
      // forever, only up to "however many distinct keys were touched within
      // the trailing [_staleRowMaxAge] window". Runs inside the SAME
      // transaction as the point lookup/write below, so this sweep and this
      // call's own admission decision are atomic together.
      await (_db.delete(_db.rateLimitCounters)..where(
            (t) => t.windowStartMs.isSmallerThanValue(
              nowMs - _staleRowMaxAge.inMilliseconds,
            ),
          ))
          .go();

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
