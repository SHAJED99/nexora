// features/dashboard/presentation — DashboardController (E06-T12, widened
// E08-T08).
//
// EARS-COMM-2 (the epic-level FR-UI-004 criterion, connectivity-reading
// half) / EARS-COMM-26 (no fabricated latency) / EARS-COMM-27 (stack
// unavailable still renders honestly), plus
// `test_recent_conversations_use_the_shared_read_model` (task §6's named
// risk: two screens must not define the delivery-state mapping twice).
//
// E08-T08 adds EARS-STORE-2 (informational warning, never a pass-triggering
// affordance) / EARS-STORE-18 (the expansion's decision list) /
// EARS-STORE-19 (percentage only with a real denominator). This file's own
// `files:` fence names `test/features/dashboard/dashboard_controller_test.dart`;
// the file actually lives at this path
// (`test/features/dashboard/presentation/dashboard_controller_test.dart`,
// matching every other `presentation` test in this project) — a small,
// disclosed path discrepancy in the task file, not a new test file.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Value;
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/conversations/presentation/conversations_controller.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_controller.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_view.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// A plain `StorageManager` over [db] — real settings/inventory/executor,
/// same as every other `core/storage` test builds (task §5's own constructor
/// contract: every dependency is injected, so a test never has to fake the
/// storage stack's own internals).
StorageManager _newStorageManager(AppDatabase db) {
  final log = StorageDecisionLog(db: db);
  return StorageManager(
    settings: StorageSettingsRepository(db: db),
    inventory: StorageInventory(db: db, databaseFileBytes: () async => 0),
    smart: SmartModePolicy(thresholds: SmartModeThresholds.defaults()),
    executor: RetentionExecutor(db: db, log: log),
    log: log,
  );
}

/// `test_EARS_STORE_2_expanding_does_not_run_a_pass`'s spy — counts
/// `runPass` calls without changing its behaviour (delegates to `super`),
/// so the test can assert the count stayed exactly zero across a tap
/// (falsifiable: a version of `toggleStorageExpansion` that called
/// `runPass` would make this assertion fail).
class _SpyStorageManager extends StorageManager {
  _SpyStorageManager({
    required super.settings,
    required super.inventory,
    required super.smart,
    required super.executor,
    required super.log,
  });

  int runPassCalls = 0;

  @override
  Future<RetentionPlan?> runPass({required int nowEpochMs, bool apply = true}) {
    runPassCalls++;
    return super.runPass(nowEpochMs: nowEpochMs, apply: apply);
  }
}

Future<void> _insertMessage(
  AppDatabase db, {
  required String id,
  required String conversationId,
  required String senderDeviceId,
  required int sequenceNumber,
  required Uint8List ciphertext,
  required int createdAt,
  DeliveryState state = DeliveryState.accepted,
}) async {
  await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: conversationId,
          senderDeviceId: senderDeviceId,
          sequenceNumber: sequenceNumber,
          ciphertext: ciphertext,
          createdAt: createdAt,
          deliveryState: state.name,
        ),
      );
}

/// Seeds a group conversation (E07-T01's tables) so a group row reaches this
/// controller through E07-T07's widened read model.
Future<void> _insertGroup(
  AppDatabase db, {
  required String id,
  required String name,
}) async {
  await db.into(db.groups).insert(
        GroupsCompanion.insert(
          id: id,
          name: name,
          createdAt: 0,
          createdByDeviceId: 'self-device',
        ),
      );
}

Future<void> _insertMember(
  AppDatabase db, {
  required String groupId,
  required String deviceId,
}) async {
  await db.into(db.groupMembers).insert(
        GroupMembersCompanion.insert(
          groupId: groupId,
          deviceId: deviceId,
          role: 'member',
          joinedAtEpoch: 0,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  late AppDatabase db;
  late MessagingStack stack;
  late ConversationRepository repo;
  late RelationshipRepository relationships;
  late StorageManager storage;
  late String suffix;

  setUp(() async {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relationships = RelationshipRepository(db);
    repo = ConversationRepository(db, selfDeviceId: 'self-device');
    storage = _newStorageManager(db);
    suffix = 'dashboard-controller-${suffixCounter++}';
    stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'self-device',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
  });

  tearDown(() async {
    await stack.dispose();
    Get.reset();
  });

  DashboardController newController({StorageManager? storageManager}) =>
      DashboardController(
        stack: stack,
        repo: repo,
        links: LinkQualityFeed(
          transport: stack.transport,
          routing: stack.routingEngine,
        ),
        crypto: stack.cryptoService,
        storage: storageManager ?? storage,
      );

  void pushDeviceDiscovered(String id) {
    final device = TransportDevice(
      id: id,
      displayName: id,
      type: TransportType.bluetooth,
    );
    final eventMessage =
        TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
      eventMessage,
      (ByteData? _) {},
    );
  }

  void pushLinkQuality(String deviceId, int latencyMs, double lossRate) {
    final eventMessage = TransportEventsApi.pigeonChannelCodec.encodeMessage(
      <Object?>[deviceId, latencyMs, lossRate],
    )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onLinkQuality.$suffix',
      eventMessage,
      (ByteData? _) {},
    );
  }

  test('test_EARS_COMM_2_default_reading_is_no_peers_with_no_peers_known', () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.reading, ConnectivityReading.noPeers);
    controller.onClose();
  });

  test(
      'test_EARS_COMM_2_reading_becomes_connected_once_a_route_exists',
      () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.networkStatus.value.reading, ConnectivityReading.noPeers);

    pushDeviceDiscovered('neighbor-1');
    pushLinkQuality('neighbor-1', 42, 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.reading, ConnectivityReading.connected);
    controller.onClose();
  });

  test(
      'test_EARS_COMM_2_reading_is_no_route_when_a_peer_is_known_but_unreachable',
      () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // A peer is discovered but never reports a link measurement, so
    // RoutingEngine has no known link to it -- computeRoute stays null.
    pushDeviceDiscovered('neighbor-unreachable');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.reading, ConnectivityReading.noRoute);
    controller.onClose();
  });

  test('test_EARS_COMM_26_no_measurement_shows_no_latency', () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.latencyMs, isNull);
    controller.onClose();
  });

  test('test_EARS_COMM_26_real_measurement_is_displayed', () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    pushDeviceDiscovered('neighbor-1');
    pushLinkQuality('neighbor-1', 77, 0.05);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.latencyMs, 77);
    controller.onClose();
  });

  test('test_EARS_COMM_27_unavailable_stack_reports_an_honest_error', () async {
    // A degraded stack (T03's own contract: never throws, `status` carries
    // the reason) -- constructed with an empty selfDeviceId, the documented
    // "no local device identity yet" unavailable case.
    final degradedDb = AppDatabase.forTesting(NativeDatabase.memory());
    final degradedStack = await MessagingStack.create(
      db: degradedDb,
      selfDeviceId: '',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'dashboard-degraded-${suffixCounter++}',
      ),
    );
    addTearDown(degradedStack.dispose);
    expect(degradedStack.status.isReady, isFalse);

    final controller = DashboardController(
      stack: degradedStack,
      repo: ConversationRepository(degradedDb, selfDeviceId: ''),
      links: LinkQualityFeed(
        transport: degradedStack.transport,
        routing: degradedStack.routingEngine,
      ),
      crypto: degradedStack.cryptoService,
      storage: _newStorageManager(degradedDb),
    );

    // Must not throw.
    expect(() => controller.onInit(), returnsNormally);
    expect(controller.errorMessage.value, isNotEmpty);
    expect(controller.loading.value, isFalse);
    controller.onClose();
  });

  test('test_recent_conversations_use_the_shared_read_model', () async {
    await relationships.upsert('device-a', RelationshipState.trusted);
    await relationships.upsert('device-blocked', RelationshipState.blocked);
    await _insertMessage(
      db,
      id: 'm-a1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 1)),
      createdAt: 1000,
    );
    await _insertMessage(
      db,
      id: 'm-blocked',
      conversationId: 'device-blocked',
      senderDeviceId: 'device-blocked',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 2)),
      createdAt: 2000,
    );
    await relationships.upsert('device-b', RelationshipState.allowed);
    await _insertMessage(
      db,
      id: 'm-b1',
      conversationId: 'device-b',
      senderDeviceId: 'device-b',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 3)),
      createdAt: 3000,
    );

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Same ordering (most recent first) and same blocked-exclusion as
    // ConversationsController's own EARS-COMM-20 tests, over identical
    // seeded data -- and the SAME `ConversationTile` type, not a
    // dashboard-only reimplementation.
    expect(controller.recent, everyElement(isA<ConversationTile>()));
    expect(
      controller.recent.map((t) => t.peerDeviceId).toList(),
      ['device-b', 'device-a'],
    );
    controller.onClose();
  });

  // E07-T07 / OQ-E07-T07-1: the widened read model also emits group rows,
  // which carry no `peerDeviceId`. Recent Conversations renders the shared
  // personal `ConversationTile` and has no group treatment yet (E07-T08), so
  // group rows are filtered out BEFORE the three-row cap — filtering after
  // it would silently shrink the section below its designed row count.
  test('test_recent_conversations_skip_groups_before_the_row_cap', () async {
    for (var i = 0; i < 3; i++) {
      await relationships.upsert('device-$i', RelationshipState.trusted);
      await _insertMessage(
        db,
        id: 'm-$i',
        conversationId: 'device-$i',
        senderDeviceId: 'device-$i',
        sequenceNumber: 1,
        ciphertext: Uint8List.fromList(List<int>.filled(16, i + 1)),
        createdAt: 1000 + i,
      );
    }
    // Newest activity of all — it would occupy a capped slot if it were not
    // filtered first.
    await _insertGroup(db, id: 'g:team', name: 'Team');
    await _insertMember(db, groupId: 'g:team', deviceId: 'self-device');
    await _insertMember(db, groupId: 'g:team', deviceId: 'device-0');
    await _insertMessage(
      db,
      id: 'm-g1',
      conversationId: 'g:team',
      senderDeviceId: 'device-0',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(16, 9)),
      createdAt: 9000,
    );

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.errorMessage.value, isEmpty);
    expect(controller.recent.length, kDashboardRecentConversationCount);
    expect(
      controller.recent.map((t) => t.peerDeviceId).toList(),
      ['device-2', 'device-1', 'device-0'],
    );
    controller.onClose();
  });

  test('test_recent_conversations_capped_at_the_designs_row_count', () async {
    for (var i = 0; i < 5; i++) {
      await relationships.upsert('device-$i', RelationshipState.trusted);
      await _insertMessage(
        db,
        id: 'm-$i',
        conversationId: 'device-$i',
        senderDeviceId: 'device-$i',
        sequenceNumber: 1,
        ciphertext: Uint8List.fromList(List<int>.filled(16, i)),
        createdAt: 1000 * (i + 1),
      );
    }

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.recent.length, kDashboardRecentConversationCount);
    controller.onClose();
  });

  test('test_encryption_secure_reflects_messaging_stack_status', () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.networkStatus.value.encryptionSecure, isTrue);
    controller.onClose();
  });

  // ── EARS-STORE-19 — percentage only with a real denominator ────────────

  test(
      'test_EARS_STORE_19_no_budget_renders_bytes_not_percent',
      () async {
    // Default install: `storage_policy_settings.budget_bytes` is NULL
    // (E08-T01's migration default, `OQ-E08-1`/`GAP-026`).
    await _insertMessage(
      db,
      id: 'm-1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(64, 1)),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.storageUsage.value.isMeasured, isTrue);
    expect(controller.storageUsage.value.percentUsed, isNull);
    expect(controller.storageUsage.value.usedBytes, greaterThan(0));
    controller.onClose();
  });

  test('test_EARS_STORE_19_real_budget_renders_percent', () async {
    await _insertMessage(
      db,
      id: 'm-1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      // 1 MiB of ciphertext, so the percentage against a 2 MiB budget is a
      // clean, real, non-degenerate 50 -- never guessed.
      ciphertext: Uint8List.fromList(List<int>.filled(1024 * 1024, 7)),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await storage.settings.setBudgetBytes(2 * 1024 * 1024);

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.storageUsage.value.isMeasured, isTrue);
    expect(controller.storageUsage.value.percentUsed, isNotNull);
    expect(controller.storageUsage.value.percentUsed, closeTo(50, 2));
    controller.onClose();
  });

  // ── EARS-STORE-2 — informational only, never a pass-triggering
  //    affordance ──────────────────────────────────────────────────────────

  test('test_EARS_STORE_2_expanding_does_not_run_a_pass', () async {
    final spy = _SpyStorageManager(
      settings: storage.settings,
      inventory: storage.inventory,
      smart: storage.smart,
      executor: storage.executor,
      log: storage.log,
    );
    final controller = newController(storageManager: spy);
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.storageExpanded.value, isFalse);
    controller.toggleStorageExpansion();
    expect(controller.storageExpanded.value, isTrue);
    controller.toggleStorageExpansion();
    expect(controller.storageExpanded.value, isFalse);

    // Falsifiable: if `toggleStorageExpansion` (or the `_loadStorageUsage`
    // read path it might trigger) ever called `StorageManager.runPass`,
    // this would be > 0.
    expect(spy.runPassCalls, 0);
    controller.onClose();
  });

  testWidgets(
      'test_EARS_STORE_2_card_has_no_action_affordance',
      (tester) async {
    // `Get.put` calls the controller's `onInit` automatically (GetX's own
    // `GetLifeCycleMixin` contract, the same one every other screen probe in
    // this project relies on, e.g. `design_probe_test.dart`'s `chat` case) —
    // never called a second time manually here.
    Get.put<DashboardController>(newController());
    await tester.pumpWidget(GetMaterialApp(home: const DashboardView()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    // Round-1 review F2: the previous version of this test only denylisted
    // four specific strings/types ("Clean Now", a delete icon, dialog
    // widgets) — falsified by the reviewer adding a live
    // `ElevatedButton(onPressed: () {}, child: Text('Free up space'))` to
    // the card and watching the test still pass. This version is
    // structural instead: the card's own `Material` subtree may contain
    // exactly ONE tap target (`InkWell` -- the expansion toggle) and
    // exactly ONE `GestureDetector` (the one `InkWell` builds internally,
    // per Flutter's own `InkResponse` implementation -- never a second,
    // additional one). Any live button type anywhere in the subtree is a
    // hard failure regardless of its label, since `EARS-STORE-2`/
    // `FR-STORE-006` forbid a forced-action affordance, not merely the
    // literal string "Clean Now".
    void assertNoActionAffordance() {
      final cardMaterial = find
          .ancestor(of: find.text('Local Storage'), matching: find.byType(Material))
          .first;

      expect(
        find.descendant(of: cardMaterial, matching: find.byType(InkWell)),
        findsOneWidget,
        reason: 'exactly one tap target: the expansion toggle',
      );
      expect(
        find.descendant(of: cardMaterial, matching: find.byType(GestureDetector)),
        findsOneWidget,
        reason: "InkWell's own internal GestureDetector, and no other",
      );
      for (final buttonType in const [
        ElevatedButton,
        TextButton,
        OutlinedButton,
        IconButton,
        FilledButton,
      ]) {
        expect(
          find.descendant(
            of: cardMaterial,
            matching: find.byWidgetPredicate((w) => w.runtimeType == buttonType),
          ),
          findsNothing,
          reason: '$buttonType would be a forced-action affordance',
        );
      }
      expect(find.descendant(of: cardMaterial, matching: find.byType(AlertDialog)),
          findsNothing);
      expect(find.descendant(of: cardMaterial, matching: find.byType(Dialog)),
          findsNothing);
    }

    assertNoActionAffordance();

    // Tapping the card only ever expands it in place -- still no such
    // affordance appears once expanded.
    await tester.tap(find.text('Local Storage'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    assertNoActionAffordance();

    // `tearDown`'s `Get.reset()` disposes the controller (calls `onClose`
    // exactly once) -- not called manually here, unlike this file's plain
    // `test()` cases, which construct the controller directly rather than
    // through `Get.put`.
  });

  // ── EARS-STORE-18 — the expansion's decision list ───────────────────────

  test(
      'test_EARS_STORE_18_expansion_is_empty_before_the_first_pass',
      () async {
    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // No pass has run (`storage.latestPlan.value` is null) -- the no-warning
    // state, not a spinner (task §2/§5).
    expect(controller.storageExplanation, isEmpty);
    expect(controller.storageUsage.value.warningActive, isFalse);
    controller.onClose();
  });

  test(
      'test_EARS_STORE_18_expansion_lists_each_category_with_its_reason',
      () async {
    // Old messages under a MANUAL policy -- the one shape this build
    // actually authorises to delete `message`-kind items (`OQ-E08-3(a)`),
    // so the category is genuinely actionable (Smart Mode's own default
    // would filter it, per `dashboard_controller.dart`'s own
    // `_actionableGroups`).
    final old = DateTime.now()
        .subtract(const Duration(days: 100))
        .millisecondsSinceEpoch;
    await _insertMessage(
      db,
      id: 'm-old-1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(128, 3)),
      createdAt: old,
    );
    await storage.settings.setMode(StorageMode.olderThanDays, olderThanDays: 30);

    // The pass a background tick would already have run by the time the
    // dashboard is opened -- the controller itself never calls this
    // (`test_EARS_STORE_2_expanding_does_not_run_a_pass` proves that side).
    await storage.runPass(
      nowEpochMs: DateTime.now().millisecondsSinceEpoch,
      apply: false,
    );

    final controller = newController();
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.storageUsage.value.warningActive, isTrue);
    expect(controller.storageExplanation, hasLength(1));
    final decision = controller.storageExplanation.first;
    expect(decision.categoryKey, 'messages');
    expect(decision.reason, RetentionReason.olderThan);
    expect(decision.reasonDetail, '30');
    expect(decision.bytes, greaterThan(0));
    controller.onClose();
  });

  // Round-1 review F1 (blocking): `latestPlan` is in-memory only and does
  // NOT survive a process relaunch, but `storage_decisions` (the durable
  // log) does. Reproduces the reviewer's own falsification exactly: seed a
  // real pass via one `StorageManager` instance, then build a FRESH
  // `StorageManager`/controller instance over the SAME db (simulating an
  // app relaunch) and confirm the explanation is populated from the
  // durable log, not silently empty just because this process never ran a
  // pass itself.
  test(
      'test_EARS_STORE_18_explanation_survives_a_relaunch_via_the_durable_log',
      () async {
    final old = DateTime.now()
        .subtract(const Duration(days: 100))
        .millisecondsSinceEpoch;
    await _insertMessage(
      db,
      id: 'm-old-relaunch-1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(256, 5)),
      createdAt: old,
    );

    // "Session 1": the pass that would have run on a previous app launch
    // (or the same launch's background tick) -- a SEPARATE StorageManager
    // instance over the same db, so nothing here can leak through
    // in-memory state to the fresh instance below.
    final sessionOneStorage = _newStorageManager(db);
    await sessionOneStorage.settings
        .setMode(StorageMode.olderThanDays, olderThanDays: 30);
    await sessionOneStorage.runPass(
      nowEpochMs: DateTime.now().millisecondsSinceEpoch,
      apply: false,
    );
    expect(sessionOneStorage.latestPlan.value, isNotNull);

    // "Session 2" (the relaunch): a genuinely FRESH `StorageManager` --
    // `latestPlan` starts `null`, exactly as it would after a real process
    // restart, since nothing ran a pass on THIS instance.
    final freshStorage = _newStorageManager(db);
    expect(freshStorage.latestPlan.value, isNull);

    final controller = newController(storageManager: freshStorage);
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // The bug (pre-fix): this stayed `isEmpty`/`false` because the
    // controller read only the in-memory `latestPlan`, never the durable
    // `storage_decisions` table the prior session actually wrote to.
    expect(controller.storageUsage.value.warningActive, isTrue);
    expect(controller.storageExplanation, hasLength(1));
    final decision = controller.storageExplanation.first;
    expect(decision.categoryKey, 'messages');
    expect(decision.reason, RetentionReason.olderThan);
    expect(decision.reasonDetail, '30');
    expect(decision.bytes, greaterThan(0));
    controller.onClose();
  });

  // A durable `applied` row (something already deleted by a prior pass)
  // must NOT be reported as something that "will" still be removed -- it
  // already was.
  test(
      'test_EARS_STORE_18_a_durable_applied_row_is_not_shown_as_still_pending',
      () async {
    final old = DateTime.now()
        .subtract(const Duration(days: 100))
        .millisecondsSinceEpoch;
    await _insertMessage(
      db,
      id: 'm-old-applied-1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(256, 6)),
      createdAt: old,
    );

    final sessionOneStorage = _newStorageManager(db);
    await sessionOneStorage.settings
        .setMode(StorageMode.olderThanDays, olderThanDays: 30);
    // apply: true (the default, and the one MessagingCoordinator's tick
    // actually calls) -- the message is genuinely deleted and logged
    // `outcome: applied` by `RetentionExecutor`.
    await sessionOneStorage.runPass(
      nowEpochMs: DateTime.now().millisecondsSinceEpoch,
    );

    final freshStorage = _newStorageManager(db);
    final controller = newController(storageManager: freshStorage);
    controller.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.storageExplanation, isEmpty);
    expect(controller.storageUsage.value.warningActive, isFalse);
    controller.onClose();
  });

  // E08-B06: the SAME pass, read two different ways, must not disagree.
  // Pre-fix, `_loadStorageUsage` preferred `StorageManager.latestPlan` (set
  // BEFORE `RetentionExecutor.apply` runs, and never cleared or replaced
  // after) whenever it was non-null -- so in the SAME process as an
  // applying pass, the in-process read still listed the just-deleted
  // category under "Will remove:", while a fresh `StorageManager`/
  // controller over the same db (the relaunch path) correctly read the
  // durable log and showed nothing. This reproduces the divergence
  // directly: one `sessionOneStorage` runs an applying manual-mode pass,
  // then its OWN controller's `storageExplanation` (`latestPlan` still
  // set, non-null, in that same instance) is compared against a second
  // controller built over a genuinely fresh `StorageManager` on the same
  // database. Both must produce the same `storageExplanation`.
  test(
      'test_E08_B06_in_process_read_matches_relaunch_read_after_an_applying_pass',
      () async {
    final old = DateTime.now()
        .subtract(const Duration(days: 100))
        .millisecondsSinceEpoch;
    await _insertMessage(
      db,
      id: 'm-old-divergence-1',
      conversationId: 'device-a',
      senderDeviceId: 'device-a',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(List<int>.filled(256, 7)),
      createdAt: old,
    );

    final sessionOneStorage = _newStorageManager(db);
    await sessionOneStorage.settings
        .setMode(StorageMode.olderThanDays, olderThanDays: 30);
    // apply: true (the default) -- the message is genuinely deleted and
    // logged `outcome: applied`, and `sessionOneStorage.latestPlan` is left
    // set to the plan as it was SCORED (pre-apply), never cleared or
    // replaced afterward (`storage_manager.dart`'s `runPass`).
    await sessionOneStorage.runPass(
      nowEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    expect(sessionOneStorage.latestPlan.value, isNotNull);

    // The in-process read: a controller built over the SAME storage
    // instance that just ran the applying pass.
    final inProcessController =
        newController(storageManager: sessionOneStorage);
    inProcessController.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // The relaunch read: a genuinely fresh `StorageManager` over the same
    // database -- `latestPlan` starts `null`, exactly as after a real
    // process restart.
    final freshStorage = _newStorageManager(db);
    expect(freshStorage.latestPlan.value, isNull);
    final relaunchController = newController(storageManager: freshStorage);
    relaunchController.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Both paths read the same underlying database and the same completed
    // pass -- they must agree. Today's code (pre-fix) fails this: the
    // in-process read lists the just-deleted "messages" category under
    // "Will remove:" (`warningActive: true`), while the relaunch read
    // correctly shows nothing.
    expect(
      inProcessController.storageExplanation.map((d) => d.categoryKey),
      relaunchController.storageExplanation.map((d) => d.categoryKey),
    );
    expect(
      inProcessController.storageUsage.value.warningActive,
      relaunchController.storageUsage.value.warningActive,
    );
    // Pin the actually-correct shape too, not just "the two agree": the
    // applied category must not appear on EITHER path.
    expect(inProcessController.storageExplanation, isEmpty);
    expect(inProcessController.storageUsage.value.warningActive, isFalse);

    inProcessController.onClose();
    relaunchController.onClose();
  });

  // E04-B25: the Dashboard's Recent Conversations preview must read the
  // payload E04-B18 already persisted, never re-decrypt `ciphertext` (a
  // second decrypt of a consumed PreKeySignalMessage throws
  // `InvalidKeyIdException` on real hardware). Ciphertext is deliberately
  // unusable, so the preview can only be correct if it comes from
  // `plaintextPayload` directly — reverting the fix yields a null preview.
  test(
      'test_E04_B25_dashboard_preview_uses_plaintextPayload_without_a_second_decrypt',
      () async {
    await relationships.upsert('bob-device', RelationshipState.trusted);
    await _insertMessage(
      db,
      id: 'm-bob-dash',
      conversationId: 'bob-device',
      senderDeviceId: 'bob-device',
      sequenceNumber: 1,
      ciphertext: Uint8List.fromList(utf8.encode('not real ciphertext')),
      createdAt: 1000,
    );
    await (db.update(db.messages)..where((t) => t.id.equals('m-bob-dash')))
        .write(
      MessagesCompanion(
        plaintextPayload: Value(
          Uint8List.fromList(utf8.encode('a persisted dashboard preview')),
        ),
      ),
    );

    final controller = newController();
    controller.onInit();
    addTearDown(controller.onClose);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.recent.single.preview, 'a persisted dashboard preview');
  });
}
