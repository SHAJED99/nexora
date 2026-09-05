// core/persistence -- generic rate-limiter primitive table (ADR-0001,
// E13-T01).
//
// One table gives every later E13 task (connection requests, device
// registration, message/relay flooding, group invites, storage-exhausting
// inbound data, battery/network-draining request floods) a single shared
// "is this bucket over its limit right now" counter, instead of five ad hoc
// reimplementations of the same fixed-window counting logic (task §1).
//
// This file only defines the fixed-window counter's shape: no limit number,
// no window duration, no bucket-key naming scheme is decided here (task §2,
// §4) -- those are each consuming task's own policy decision.
import 'package:drift/drift.dart';

/// One row per rate-limited bucket. `bucketKey` is a caller-chosen string
/// identifying both what is being limited AND who it's being limited
/// against (e.g. `"connection_request:<deviceId>"`, task §2) -- this task
/// assigns no naming scheme, only documents that one is expected.
///
/// `windowStartMs`/`count` together implement a **fixed window** counter
/// (not sliding window, not token bucket, task §2): `count` resets to
/// `increment` (not to 1 -- callers limiting a cumulative quantity like
/// bytes must roll over to the size of the admitting call, not to 1) once
/// `window` has elapsed since `windowStartMs`.
///
/// The primary key is `bucketKey` itself, the same reasoning
/// `device_revocations`/`sync_cursors` already document (task §5): the only
/// local access pattern is a point lookup by `bucketKey`, which the PK's
/// own implicit index already serves.
///
/// **E13-B01 correction**: the claim above ("no secondary index needed")
/// stopped being true the moment `E13-T07` added the opportunistic stale-row
/// eviction in `RateLimiter.allow` (`rate_limiter.dart`), which range-filters
/// on `windowStartMs` on every single admission decision. That access
/// pattern is not a point lookup by `bucketKey` and the PK's index does not
/// serve it -- left unindexed, the eviction was an O(table-size) scan on
/// every `allow()` call, with the table's size directly attacker-controlled
/// (E13-B01). `idx_rate_limit_counters_window_start` below exists
/// specifically to serve that range-delete.
@DataClassName('RateLimitCounterRow')
@TableIndex(
  name: 'idx_rate_limit_counters_window_start',
  columns: {#windowStartMs},
)
class RateLimitCounters extends Table {
  TextColumn get bucketKey => text()();

  /// Epoch-ms, this device's clock, when the current window started.
  IntColumn get windowStartMs => integer()();

  /// Cumulative count (or cumulative quantity, e.g. bytes) admitted so far
  /// within the current window.
  IntColumn get count => integer()();

  @override
  Set<Column> get primaryKey => {bucketKey};
}
