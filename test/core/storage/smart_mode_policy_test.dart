// test/core/storage — E08-T04, SmartModePolicy's eight-factor scorer.
//
// SmartModePolicy.plan() is a pure function (no I/O, no AppDatabase) so
// every test here builds its inputs as plain Dart values -- no in-memory
// database needed, unlike storage_inventory_test.dart / T03's recorder
// tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart';

const _dayMs = 24 * 60 * 60 * 1000;

StorageItem _message({
  required String id,
  required int createdAt,
  int bytes = 100,
  String conversationId = 'conv-default',
}) {
  return StorageItem(
    kind: StorageItemKind.message,
    id: id,
    conversationId: conversationId,
    bytes: bytes,
    createdAt: createdAt,
    isTemporary: false,
  );
}

StorageItem _relayPayload({
  required String id,
  required int createdAt,
  int bytes = 500,
}) {
  return StorageItem(
    kind: StorageItemKind.relayPayload,
    id: id,
    conversationId: null,
    bytes: bytes,
    createdAt: createdAt,
    isTemporary: true,
  );
}

StorageInventorySnapshot _snapshot({
  List<StorageClassTotal> classTotals = const [],
  int databaseFileBytes = 0,
  DateTime? measuredAt,
}) {
  return StorageInventorySnapshot(
    classTotals: classTotals,
    databaseFileBytes: databaseFileBytes,
    measuredAt: measuredAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

void main() {
  final thresholds = SmartModeThresholds.defaults();
  final policy = SmartModePolicy(thresholds: thresholds);
  const nowEpochMs = 1000 * _dayMs; // day 1000, well clear of any threshold

  group('statsKeyFor', () {
    test('canonical key is "kind.name:id", never "id:kind" or bare id', () {
      final key = statsKeyFor(StorageItemKind.message, 'msg-1');
      expect(key, 'message:msg-1');
      expect(key, isNot('msg-1:message'));
      expect(key, isNot('msg-1'));
    });
  });

  group('SmartModeThresholds.defaults', () {
    test('ships the documented placeholder values', () {
      expect(thresholds.ageThresholdDays, 45);
      expect(thresholds.rarelyAccessedDays, 30);
      expect(thresholds.rarelyAccessedMinAgeDays, 7);
      expect(thresholds.sizeThresholdBytes, 10 * 1024 * 1024);
      expect(thresholds.storagePressureRatio, 0.9);
      expect(thresholds.activeConversationWindowDays, 14);
    });
  });

  test('test_EARS_STORE_1_all_eight_factors_are_addressed', () {
    final plan = policy.plan(
      snapshot: _snapshot(),
      items: const [],
      stats: const {},
      nowEpochMs: nowEpochMs,
    );

    expect(plan.availableFactors.length, 8);
    expect(
      plan.availableFactors.keys.toSet(),
      SmartModeFactor.values.toSet(),
    );
    // Every factor is named and present -- no silent omission
    // (`EARS-STORE-1`).
    for (final factor in SmartModeFactor.values) {
      expect(plan.availableFactors.containsKey(factor), isTrue,
          reason: '$factor missing from availableFactors');
    }
    // The unavailable subset is a strict, non-overlapping split of the same
    // eight entries.
    final unavailableKeys = plan.unavailableFactors.keys.toSet();
    final availableOnlyKeys = plan.availableFactors.entries
        .where((e) => e.value is Scored)
        .map((e) => e.key)
        .toSet();
    expect(unavailableKeys.intersection(availableOnlyKeys), isEmpty);
    expect(unavailableKeys.length + availableOnlyKeys.length, 8);
  });

  test('test_EARS_STORE_1_age_and_size_select_expected_candidates', () {
    final oldSmall = _message(
      id: 'old-small',
      createdAt: nowEpochMs - 50 * _dayMs, // older than 45-day threshold
      bytes: 1000, // well under the size threshold
      conversationId: 'conv-old-small',
    );
    final youngLarge = _message(
      id: 'young-large',
      // 20 days: older than the 14-day active-conversation window (so not
      // shielded), younger than the 45-day age threshold (so not "old").
      createdAt: nowEpochMs - 20 * _dayMs,
      bytes: 20 * 1024 * 1024, // over the 10 MB size threshold
      conversationId: 'conv-young-large',
    );

    final plan = policy.plan(
      snapshot: _snapshot(),
      items: [oldSmall, youngLarge],
      stats: {
        // Recently accessed, so the rarely-accessed branch does not fire
        // before the size check gets a chance to.
        statsKeyFor(StorageItemKind.message, 'young-large'): ItemAccessStat(
          accessCount: 5,
          lastAccessedAtEpochMs: nowEpochMs - 1 * _dayMs,
        ),
      },
      nowEpochMs: nowEpochMs,
    );

    final byReason = {for (final g in plan.groups) g.reason: g};
    expect(byReason.keys.toSet(),
        {RetentionReason.olderThan, RetentionReason.overSizeLimit});

    final olderThanGroup = byReason[RetentionReason.olderThan]!;
    expect(olderThanGroup.itemIds, ['old-small']);
    expect(olderThanGroup.bytes, 1000);
    expect(olderThanGroup.categoryKey, 'messages');

    final overSizeGroup = byReason[RetentionReason.overSizeLimit]!;
    expect(overSizeGroup.itemIds, ['young-large']);
    expect(overSizeGroup.bytes, 20 * 1024 * 1024);
  });

  test('test_EARS_STORE_1_rarely_accessed_items_rank_above_recently_used',
      () {
    // Identical age and size; only the access stats differ.
    final rarelyAccessed = _message(
      id: 'rarely-accessed',
      createdAt: nowEpochMs - 20 * _dayMs,
      bytes: 100,
      conversationId: 'conv-rarely',
    );
    final recentlyUsed = _message(
      id: 'recently-used',
      createdAt: nowEpochMs - 20 * _dayMs,
      bytes: 100,
      conversationId: 'conv-recent',
    );

    final plan = policy.plan(
      snapshot: _snapshot(),
      items: [rarelyAccessed, recentlyUsed],
      stats: {
        // No entry for 'rarely-accessed' -- never observed (T03 semantics).
        statsKeyFor(StorageItemKind.message, 'recently-used'):
            ItemAccessStat(
          accessCount: 10,
          lastAccessedAtEpochMs: nowEpochMs - 1 * _dayMs,
        ),
      },
      nowEpochMs: nowEpochMs,
    );

    final allItemIds = plan.groups.expand((g) => g.itemIds).toSet();
    expect(allItemIds, contains('rarely-accessed'));
    expect(allItemIds, isNot(contains('recently-used')));

    final group = plan.groups
        .singleWhere((g) => g.itemIds.contains('rarely-accessed'));
    expect(group.reason, RetentionReason.rarelyAccessed);
  });

  test('test_EARS_STORE_1_active_conversation_items_are_not_candidates', () {
    // An old message in a conversation that also has very recent activity
    // -- the conversation-activity factor shields it regardless of age.
    final oldMessage = _message(
      id: 'old-in-active-conv',
      createdAt: nowEpochMs - 50 * _dayMs,
      conversationId: 'conv-active',
    );
    final recentMessage = _message(
      id: 'recent-in-active-conv',
      createdAt: nowEpochMs - 1 * _dayMs,
      conversationId: 'conv-active',
    );

    final plan = policy.plan(
      snapshot: _snapshot(),
      items: [oldMessage, recentMessage],
      stats: const {},
      nowEpochMs: nowEpochMs,
    );

    expect(plan.groups, isEmpty);
    expect(
      (plan.availableFactors[SmartModeFactor.conversationActivity]
              as Scored)
          .value,
      greaterThan(0),
    );
  });

  test('test_EARS_STORE_9_every_group_has_a_reason_and_real_bytes', () {
    final oldMessage = _message(
      id: 'old-1',
      createdAt: nowEpochMs - 60 * _dayMs,
      bytes: 4096,
      conversationId: 'conv-1',
    );
    final relay = _relayPayload(id: 'relay-1', createdAt: nowEpochMs - _dayMs);

    final plan = policy.plan(
      snapshot: _snapshot(),
      items: [oldMessage, relay],
      stats: const {},
      nowEpochMs: nowEpochMs,
    );

    expect(plan.groups, isNotEmpty);
    for (final group in plan.groups) {
      expect(group.bytes, greaterThan(0));
      expect(group.itemIds, isNotEmpty);
      expect(group.itemCount, group.itemIds.length);
      expect(group.categoryKey, isNotEmpty);
    }
    expect(plan.totalBytes, plan.groups.fold<int>(0, (s, g) => s + g.bytes));
  });

  test('test_EARS_STORE_10_null_budget_makes_pressure_unavailable', () {
    final plan = policy.plan(
      snapshot: _snapshot(),
      items: const [],
      stats: const {},
      nowEpochMs: nowEpochMs,
      budgetBytes: null,
    );

    final pressure = plan.availableFactors[SmartModeFactor.storagePressure];
    expect(pressure, isA<Unavailable>());
    expect(pressure, isNot(const FactorScore.scored(0.0)));
    expect(plan.unavailableFactors[SmartModeFactor.storagePressure],
        isA<Unavailable>());
  });

  test('test_EARS_STORE_10_zero_budget_makes_pressure_unavailable', () {
    // E08-B05: a zero denominator is undefined, not "100% full". The old
    // `budgetBytes == 0 -> ratio 1.0` shortcut fabricated a maximal
    // pressure measurement out of no measurement at all.
    final plan = policy.plan(
      snapshot: _snapshot(),
      items: const [],
      stats: const {},
      nowEpochMs: nowEpochMs,
      budgetBytes: 0,
    );

    final pressure = plan.availableFactors[SmartModeFactor.storagePressure];
    expect(pressure, isA<Unavailable>());
    expect(pressure, isNot(const FactorScore.scored(1.0)));
    expect((pressure as Unavailable).reason, contains('OQ-E08-1'));
    expect(plan.unavailableFactors[SmartModeFactor.storagePressure],
        isA<Unavailable>());
  });

  test('test_EARS_STORE_10_zero_budget_does_not_force_pressure_reason', () {
    // The reason-override branch must not fire off a fabricated 1.0 ratio:
    // with budgetBytes 0 the candidate keeps its own age/access/size reason.
    final plan = policy.plan(
      snapshot: _snapshot(),
      items: [
        _message(
          id: 'old-1',
          createdAt: nowEpochMs - 400 * _dayMs,
          conversationId: 'conv-old',
        ),
      ],
      stats: const {},
      nowEpochMs: nowEpochMs,
      budgetBytes: 0,
    );

    expect(plan.groups, isNotEmpty);
    for (final group in plan.groups) {
      expect(group.reason, isNot(RetentionReason.storagePressure));
    }
  });

  test('test_EARS_STORE_10_importance_is_unavailable_until_defined', () {
    final plan = policy.plan(
      snapshot: _snapshot(),
      items: const [],
      stats: const {},
      nowEpochMs: nowEpochMs,
      budgetBytes: 1000,
    );

    final importance = plan.availableFactors[SmartModeFactor.importance];
    expect(importance, isA<Unavailable>());
    expect((importance as Unavailable).reason, contains('OQ-E08-4'));
    expect(plan.unavailableFactors[SmartModeFactor.importance],
        isA<Unavailable>());
  });

  test('test_EARS_STORE_1_plan_is_deterministic', () {
    final items = [
      _message(
        id: 'z-old',
        createdAt: nowEpochMs - 90 * _dayMs,
        conversationId: 'conv-z',
      ),
      _message(
        id: 'a-old',
        createdAt: nowEpochMs - 90 * _dayMs,
        conversationId: 'conv-a',
      ),
      _relayPayload(id: 'relay-b', createdAt: nowEpochMs - _dayMs),
      _relayPayload(id: 'relay-a', createdAt: nowEpochMs - _dayMs),
    ];
    final stats = <String, ItemAccessStat>{};

    List<Map<String, Object?>> summarize(RetentionPlan plan) => [
          for (final g in plan.groups)
            {
              'categoryKey': g.categoryKey,
              'reason': g.reason.name,
              'itemIds': g.itemIds,
              'bytes': g.bytes,
            },
        ];

    final plan1 = policy.plan(
      snapshot: _snapshot(),
      items: items,
      stats: stats,
      nowEpochMs: nowEpochMs,
    );
    // Same data, different input order -- the output must not depend on
    // scan order (task §2 determinism requirement, explicit tie-break).
    final plan2 = policy.plan(
      snapshot: _snapshot(),
      items: items.reversed.toList(),
      stats: Map.of(stats),
      nowEpochMs: nowEpochMs,
    );

    expect(summarize(plan1), summarize(plan2));
  });
}
