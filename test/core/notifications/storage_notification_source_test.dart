// Tests for StorageNotificationSource (E10-T07, EARS-NOTIFY-14/15).
//
// Unit-level: builds a real `Rx<RetentionPlan?>` (the exact type
// `StorageManager.latestPlan` is, `storage_manager.dart:82`) and mutates
// `.value` directly, rather than driving a real `StorageManager` — proving
// the rising-edge/latch/null-handling logic in isolation, mirroring every
// other source's own unit-level split in this directory.
//
// `isOverThreshold` is injected as a trivial predicate over `totalBytes`
// rather than `groups.isNotEmpty` (the real predicate `bindings.dart`
// wires) — this file's job is to prove the EDGE-DETECTION logic works for
// ANY predicate the composition root supplies, not to re-prove what
// `bindings.dart`'s own predicate means (nothing in the source itself reads
// `totalBytes` or `groups`; both are equally opaque `RetentionPlan` fields
// from this class's own point of view).
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_policy.dart';
import 'package:nexora/core/notifications/sources/storage_notification_source.dart';
import 'package:nexora/core/storage/retention_plan.dart';

void main() {
  // A broadcast stream drops an event added with no subscriber yet
  // (`connection_request_notification_source_test.dart`'s own header) —
  // every test below awaits one microtask after subscribing and before
  // mutating `latestPlan`.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  RetentionPlan planWithBytes(int totalBytes) => RetentionPlan(
        mode: 'smart',
        groups: const <RetentionCandidateGroup>[],
        totalBytes: totalBytes,
        availableFactors: const <SmartModeFactor, FactorScore>{},
        unavailableFactors: const <SmartModeFactor, FactorScore>{},
        computedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool overHundred(RetentionPlan plan) => plan.totalBytes > 100;

  test('test_EARS_NOTIFY_14_rising_edge_posts_once', () async {
    final latestPlan = Rx<RetentionPlan?>(null);
    final source = StorageNotificationSource(
      latestPlan,
      isOverThreshold: overHundred,
    );

    final facts = <NotificationFacts>[];
    final subscription = source.facts.listen(facts.add);
    await settle();

    latestPlan.value = planWithBytes(50); // under threshold, no post
    await settle();
    expect(facts, isEmpty);

    latestPlan.value = planWithBytes(200); // rising edge
    await settle();

    expect(facts, hasLength(1));
    expect(facts.single.category, NotificationCategory.storageWarning);
    expect(facts.single.peerDeviceId, isNull);
    expect(facts.single.peerDisplayName, isNull);

    await subscription.cancel();
    source.dispose();
  });

  test(
    'test_EARS_NOTIFY_14_first_reading_over_threshold_posts_once',
    () async {
      // No prior state (task file §6 risk: a persistently full device must
      // still be warned once, not never) — the very first non-null plan,
      // already over threshold, must itself count as the crossing.
      final latestPlan = Rx<RetentionPlan?>(null);
      final source = StorageNotificationSource(
        latestPlan,
        isOverThreshold: overHundred,
      );

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      latestPlan.value = planWithBytes(200);
      await settle();

      expect(facts, hasLength(1));

      await subscription.cancel();
      source.dispose();
    },
  );

  test(
    'test_EARS_NOTIFY_15_repeated_over_threshold_passes_post_nothing',
    () async {
      final latestPlan = Rx<RetentionPlan?>(null);
      final source = StorageNotificationSource(
        latestPlan,
        isOverThreshold: overHundred,
      );

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      latestPlan.value = planWithBytes(200); // crossing #1
      await settle();
      latestPlan.value = planWithBytes(300); // still over -- no re-notify
      await settle();
      latestPlan.value = planWithBytes(400); // still over -- no re-notify
      await settle();

      expect(facts, hasLength(1));

      await subscription.cancel();
      source.dispose();
    },
  );

  test('test_EARS_NOTIFY_15_falling_then_rising_rearms', () async {
    final latestPlan = Rx<RetentionPlan?>(null);
    final source = StorageNotificationSource(
      latestPlan,
      isOverThreshold: overHundred,
    );

    final facts = <NotificationFacts>[];
    final subscription = source.facts.listen(facts.add);
    await settle();

    latestPlan.value = planWithBytes(200); // crossing #1
    await settle();
    latestPlan.value = planWithBytes(50); // falls below -- disarms
    await settle();
    latestPlan.value = planWithBytes(200); // crossing #2 -- re-armed
    await settle();

    expect(facts, hasLength(2));

    await subscription.cancel();
    source.dispose();
  });

  test(
    'test_EARS_NOTIFY_15_over_then_null_then_over_posts_once',
    () async {
      // F1 (E10-B07): a null reading between two over-threshold readings
      // must NOT be read as a fall below threshold. The guard at
      // `storage_notification_source.dart:100` (`if (plan == null) return;`)
      // is what keeps the latch armed across the null -- if that guard were
      // replaced with `{ _wasOverThreshold = false; return; }` the null
      // would disarm the latch and the second `over` reading would
      // re-notify, violating EARS-NOTIFY-15 ("stays over -- no further
      // notification until it falls and rises again"). A null plan is not a
      // fall: only a genuinely-under reading disarms.
      final latestPlan = Rx<RetentionPlan?>(null);
      final source = StorageNotificationSource(
        latestPlan,
        isOverThreshold: overHundred,
      );

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      latestPlan.value = planWithBytes(200); // crossing #1 -- posts
      await settle();
      latestPlan.value = null; // must not disarm the latch
      await settle();
      latestPlan.value = planWithBytes(300); // still over -- no re-notify
      await settle();

      expect(facts, hasLength(1));

      await subscription.cancel();
      source.dispose();
    },
  );

  test('test_EARS_NOTIFY_14_null_plan_posts_nothing', () async {
    final latestPlan = Rx<RetentionPlan?>(null);
    final source = StorageNotificationSource(
      latestPlan,
      isOverThreshold: overHundred,
    );

    final facts = <NotificationFacts>[];
    final subscription = source.facts.listen(facts.add);
    await settle();

    // `latestPlan` starts null and stays null -- no pass has run yet. Must
    // not be read as "under threshold" and must not itself trigger a
    // spurious edge when a real value later arrives from a genuinely-under
    // reading (proven separately by the rising-edge test above).
    expect(facts, isEmpty);

    await subscription.cancel();
    source.dispose();
  });

  test('dispose() is safe to call twice', () async {
    final latestPlan = Rx<RetentionPlan?>(null);
    final source = StorageNotificationSource(
      latestPlan,
      isOverThreshold: overHundred,
    );

    final subscription = source.facts.listen((_) {});
    await settle();

    source.dispose();
    expect(source.dispose, returnsNormally);

    await subscription.cancel();
  });
}
