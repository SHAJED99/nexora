// E13-T01 -- generic rate-limiter primitive: fixed-window counter,
// Drift-backed. Policy-free (task §2): no real limit number, window, or
// bucket-key scheme is asserted here beyond what each test needs to prove
// the mechanism.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/core/persistence/database.dart';

void main() {
  late AppDatabase db;
  late RateLimiter limiter;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    limiter = RateLimiter(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'test_EARS_ABUSE_1_allow_under_limit_increments_and_returns_true',
    () async {
      final result = await limiter.allow(
        'bucket-a',
        maxCount: 3,
        window: const Duration(minutes: 1),
      );
      expect(result, isTrue);

      final row = await (db.select(
        db.rateLimitCounters,
      )..where((t) => t.bucketKey.equals('bucket-a'))).getSingle();
      expect(row.count, 1);
    },
  );

  test(
    'test_EARS_ABUSE_2_allow_at_limit_denies_without_incrementing',
    () async {
      const bucketKey = 'bucket-b';
      for (var i = 0; i < 3; i++) {
        final ok = await limiter.allow(
          bucketKey,
          maxCount: 3,
          window: const Duration(minutes: 1),
        );
        expect(ok, isTrue);
      }

      // 4th call at the max must be denied without incrementing further.
      final denied = await limiter.allow(
        bucketKey,
        maxCount: 3,
        window: const Duration(minutes: 1),
      );
      expect(denied, isFalse);

      final row = await (db.select(
        db.rateLimitCounters,
      )..where((t) => t.bucketKey.equals(bucketKey))).getSingle();
      expect(row.count, 3, reason: 'a denied call must not itself increment');
    },
  );

  test('test_EARS_ABUSE_3_window_rollover_resets_counter', () async {
    const bucketKey = 'bucket-c';

    // Manually seed a bucket whose window started far enough in the past
    // that it has elapsed, sitting AT the max -- if rollover didn't reset,
    // the next call would be denied.
    final longAgo = DateTime.now().millisecondsSinceEpoch - 120000;
    await db
        .into(db.rateLimitCounters)
        .insert(
          RateLimitCountersCompanion.insert(
            bucketKey: bucketKey,
            windowStartMs: longAgo,
            count: 3,
          ),
        );

    final result = await limiter.allow(
      bucketKey,
      maxCount: 3,
      window: const Duration(minutes: 1),
    );
    expect(result, isTrue, reason: 'an elapsed window must roll over');

    final row = await (db.select(
      db.rateLimitCounters,
    )..where((t) => t.bucketKey.equals(bucketKey))).getSingle();
    expect(
      row.count,
      1,
      reason: 'rollover resets to `increment` (default 1), not to the old count',
    );
    expect(
      row.windowStartMs,
      greaterThan(longAgo),
      reason: 'rollover must start a new window',
    );
  });

  test(
    'test_EARS_ABUSE_3b_increment_larger_than_one_denies_without_partial_increment',
    () async {
      const bucketKey = 'bucket-d';

      // Admit 8 out of a max of 10 first.
      final first = await limiter.allow(
        bucketKey,
        maxCount: 10,
        window: const Duration(minutes: 1),
        increment: 8,
      );
      expect(first, isTrue);

      // A further increment of 5 would take the total to 13 > 10: must
      // deny, and must NOT partially increment (e.g. to 10).
      final denied = await limiter.allow(
        bucketKey,
        maxCount: 10,
        window: const Duration(minutes: 1),
        increment: 5,
      );
      expect(denied, isFalse);

      final row = await (db.select(
        db.rateLimitCounters,
      )..where((t) => t.bucketKey.equals(bucketKey))).getSingle();
      expect(
        row.count,
        8,
        reason: 'a denied over-limit increment must not partially apply',
      );
    },
  );

  test(
    'test_rate_limiter_concurrent_calls_do_not_lose_an_update',
    () async {
      // Two overlapping admission checks on the same bucket must not both
      // read the same stale count and stomp each other's write -- the
      // write path must be atomic (implement/SKILL.md §6: "introducing a
      // durable counter" falsification test), not a read-then-write with
      // a suspension point in between.
      const bucketKey = 'bucket-race';
      final results = await Future.wait([
        limiter.allow(
          bucketKey,
          maxCount: 100,
          window: const Duration(minutes: 1),
          increment: 10,
        ),
        limiter.allow(
          bucketKey,
          maxCount: 100,
          window: const Duration(minutes: 1),
          increment: 4,
        ),
      ]);
      expect(results, everyElement(isTrue));

      final row = await (db.select(
        db.rateLimitCounters,
      )..where((t) => t.bucketKey.equals(bucketKey))).getSingle();
      expect(
        row.count,
        14,
        reason: 'both concurrent increments must be reflected, not lost',
      );
    },
  );

  test('test_rate_limiter_two_bucket_keys_are_independent', () async {
    await limiter.allow(
      'bucket-e-1',
      maxCount: 1,
      window: const Duration(minutes: 1),
    );
    // bucket-e-1 is now at its max (1); a second call on it must deny.
    final deniedSameBucket = await limiter.allow(
      'bucket-e-1',
      maxCount: 1,
      window: const Duration(minutes: 1),
    );
    expect(deniedSameBucket, isFalse);

    // A different bucket key must be entirely unaffected.
    final allowedOtherBucket = await limiter.allow(
      'bucket-e-2',
      maxCount: 1,
      window: const Duration(minutes: 1),
    );
    expect(allowedOtherBucket, isTrue);
  });
}
