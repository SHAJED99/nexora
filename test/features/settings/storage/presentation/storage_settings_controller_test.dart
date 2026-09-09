// features/settings/storage/presentation -- StorageSettingsController
// (E15-T09, E08-T09 rehomed).
//
// Real in-memory `AppDatabase` + the real `StorageSettingsRepository`/
// `StorageDecisionLog`/`StorageInventory` throughout -- these tests prove
// the controller's *binding* to those repositories, not a mock's promise
// that it would. `_CountingStorageManager` below is the one seam this
// task's own risk list calls for -- a call counter on the retention-pass
// entry point, never `fail()` inside an injected seam (a broad catch in the
// SUT would swallow it, L-testing).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart';
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_controller.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_view.dart';

/// The one entry point `MessagingCoordinator`'s tick calls
/// (`storage_manager.dart`'s own header) -- the actual retention-pass
/// trigger. `StorageSettingsController` never imports `storage_manager.dart`
/// at all (task §4), so this spy is registered via `Get.put` and never
/// referenced by the controller -- its count staying `0` proves the
/// controller genuinely never reaches for it, not merely that nothing
/// currently wires it up by coincidence.
class _CountingStorageManager extends StorageManager {
  _CountingStorageManager({
    required super.settings,
    required super.inventory,
    required super.smart,
    required super.executor,
    required super.log,
  });

  int runPassCallCount = 0;

  @override
  Future<RetentionPlan?> runPass({
    required int nowEpochMs,
    bool apply = true,
  }) {
    runPassCallCount++;
    return super.runPass(nowEpochMs: nowEpochMs, apply: apply);
  }
}

/// A spy on [StorageSettingsRepository.setMode] -- the write path
/// `EARS-STORE-20`'s "rejected ... without writing" clause must prove was
/// never reached on the invalid branch. A call counter, not `fail()` inside
/// the seam (`L-testing`, this file's own header): a broad catch in the SUT
/// would swallow a thrown assertion, but never a counter that stays wrong.
class _CountingStorageSettingsRepository extends StorageSettingsRepository {
  _CountingStorageSettingsRepository({required super.db});

  int setModeCallCount = 0;

  @override
  Future<void> setMode(
    StorageMode mode, {
    int? olderThanDays,
    int? maxBytes,
  }) {
    setModeCallCount++;
    return super.setMode(
      mode,
      olderThanDays: olderThanDays,
      maxBytes: maxBytes,
    );
  }
}

RetentionCandidateGroup _group({
  required String categoryKey,
  RetentionReason reason = RetentionReason.olderThan,
  String? reasonDetail = '45',
  int bytes = 1024 * 1024,
}) {
  return RetentionCandidateGroup(
    categoryKey: categoryKey,
    kind: StorageItemKind.message,
    itemIds: const ['m1'],
    itemCount: 1,
    bytes: bytes,
    reason: reason,
    reasonDetail: reasonDetail,
  );
}

RetentionPlan _plan({
  required String mode,
  required List<RetentionCandidateGroup> groups,
}) {
  final totalBytes = groups.fold<int>(0, (sum, g) => sum + g.bytes);
  return RetentionPlan(
    mode: mode,
    groups: groups,
    totalBytes: totalBytes,
    availableFactors: const {},
    unavailableFactors: const {},
    computedAt: DateTime.fromMillisecondsSinceEpoch(2000),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StorageSettingsRepository settings;
  late StorageDecisionLog log;
  late StorageInventory inventory;
  late StorageSettingsController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = StorageSettingsRepository(db: db);
    log = StorageDecisionLog(db: db);
    inventory = StorageInventory(db: db, databaseFileBytes: () async => 2048);
    controller = StorageSettingsController(
      settings: settings,
      log: log,
      inventory: inventory,
    );
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
    return db.close();
  });

  group('EARS-STORE-20 — selecting a mode', () {
    test(
      'test_EARS_STORE_20_selecting_a_mode_persists_through_the_repository',
      () async {
        controller.onInit();
        await pumpEventQueue();

        await controller.selectMode(StorageMode.olderThanDays);
        await pumpEventQueue();

        final reread = await settings.read();
        expect(reread.mode, StorageMode.olderThanDays.name);
        expect(reread.olderThanDays, 1);
        expect(reread.maxBytes, isNull);
      },
    );

    test(
      'test_EARS_STORE_20_selecting_a_mode_runs_no_retention_pass',
      () async {
        Get.testMode = true;
        final manager = _CountingStorageManager(
          settings: settings,
          inventory: inventory,
          smart: SmartModePolicy(thresholds: SmartModeThresholds.defaults()),
          executor: RetentionExecutor(db: db, log: log),
          log: log,
        );
        Get.put<StorageManager>(manager);

        controller.onInit();
        await pumpEventQueue();

        await controller.selectMode(StorageMode.olderThanDays);
        await controller.selectMode(StorageMode.overSizeMb);
        await controller.selectMode(StorageMode.smart);
        await pumpEventQueue();

        expect(manager.runPassCallCount, 0);
      },
    );

    test(
      'test_EARS_STORE_20_invalid_older_than_days_is_rejected_without_writing',
      () async {
        final countingSettings = _CountingStorageSettingsRepository(db: db);
        final countingController = StorageSettingsController(
          settings: countingSettings,
          log: log,
          inventory: inventory,
        );
        addTearDown(countingController.onClose);

        countingController.onInit();
        await pumpEventQueue();
        await countingController.selectMode(StorageMode.olderThanDays);
        await pumpEventQueue();

        final callsBeforeInvalid = countingSettings.setModeCallCount;
        expect(callsBeforeInvalid, 1);

        final ok = await countingController.updateOlderThanDays(0);
        expect(ok, isFalse);

        // The proof `EARS-STORE-20`'s "rejected ... without writing" clause
        // needs: the invalid call never reached the repository at all --
        // not merely that it happened to write the same value the prior
        // valid call already wrote (that reread-equality check is exactly
        // what a reviewer proved defeatable by making the invalid branch
        // write the same value before returning `false`).
        expect(
          countingSettings.setModeCallCount,
          callsBeforeInvalid,
          reason: 'an invalid value must not call setMode at all',
        );

        final reread = await countingSettings.read();
        expect(reread.olderThanDays, 1);
      },
    );

    test(
      'test_EARS_STORE_20_invalid_max_bytes_mb_is_rejected_without_writing',
      () async {
        final countingSettings = _CountingStorageSettingsRepository(db: db);
        final countingController = StorageSettingsController(
          settings: countingSettings,
          log: log,
          inventory: inventory,
        );
        addTearDown(countingController.onClose);

        countingController.onInit();
        await pumpEventQueue();
        await countingController.selectMode(StorageMode.overSizeMb);
        await pumpEventQueue();

        final callsBeforeInvalid = countingSettings.setModeCallCount;
        expect(callsBeforeInvalid, 1);

        final ok = await countingController.updateMaxBytesMb(0);
        expect(ok, isFalse);

        expect(
          countingSettings.setModeCallCount,
          callsBeforeInvalid,
          reason: 'an invalid value must not call setMode at all',
        );

        final reread = await countingSettings.read();
        expect(reread.maxBytes, StorageSettingsRepository.minMaxBytes);
      },
    );

    testWidgets(
      'test_EARS_STORE_20_parameter_field_renders_only_for_its_own_mode',
      (tester) async {
        Get.testMode = true;
        Get.put<StorageSettingsController>(controller);

        await tester.pumpWidget(
          const GetMaterialApp(home: StorageSettingsView()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(TextField), findsNothing);

        await tester.tap(find.text('Delete data older than X days'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Days'), findsOneWidget);
        expect(find.text('Limit (MB)'), findsNothing);

        await tester.ensureVisible(
          find.text('Delete old data when storage exceeds X MB'),
        );
        await tester.pump();
        await tester.tap(
          find.text('Delete old data when storage exceeds X MB'),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Limit (MB)'), findsOneWidget);
        expect(find.text('Days'), findsNothing);
      },
    );

    testWidgets('test_EARS_STORE_20_first_frame_is_not_empty', (
      tester,
    ) async {
      Get.testMode = true;
      Get.put<StorageSettingsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: StorageSettingsView()),
      );

      // The very first pumped frame -- proves `watch()`'s "emits current on
      // listen" behaviour (E08-T05's own
      // `test_EARS_STORE_11_watch_emits_current_value_on_listen`) reaches
      // this screen, so Smart Mode is already marked selected rather than
      // every mode rendering unselected until a later frame.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    });
  });

  group('EARS-STORE-21 — the explanation list', () {
    testWidgets(
      'test_EARS_STORE_21_decisions_render_with_their_reason_copy',
      (tester) async {
        await settings.setMode(StorageMode.olderThanDays, olderThanDays: 45);
        await log.recordPass(
          _plan(
            mode: StorageMode.olderThanDays.name,
            groups: [
              _group(
                categoryKey: 'messages',
                reason: RetentionReason.olderThan,
                reasonDetail: '45',
                bytes: 2 * 1024 * 1024,
              ),
            ],
          ),
          outcome: DecisionOutcome.planned,
          nowEpochMs: 1000,
        );

        Get.testMode = true;
        Get.put<StorageSettingsController>(controller);

        await tester.pumpWidget(
          const GetMaterialApp(home: StorageSettingsView()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Will remove:'), findsOneWidget);
        // "Messages" renders twice by design: once as the usage-summary's
        // own class row (always present), once as this decision's category
        // label -- not a duplicate bug.
        expect(find.text('Messages'), findsNWidgets(2));
        expect(find.text('2 MB'), findsOneWidget);
        expect(find.text('Older than 45 days'), findsOneWidget);
        expect(find.text('Why:'), findsOneWidget);
      },
    );

    testWidgets(
      'test_EARS_STORE_21_empty_plan_renders_nothing_scheduled',
      (tester) async {
        Get.testMode = true;
        Get.put<StorageSettingsController>(controller);

        await tester.pumpWidget(
          const GetMaterialApp(home: StorageSettingsView()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Nothing to remove right now.'), findsOneWidget);
        expect(find.text('Will remove:'), findsNothing);
      },
    );

    testWidgets(
      'test_EARS_STORE_21_zero_candidate_sentinel_renders_nothing_scheduled',
      (tester) async {
        // A genuinely zero-candidate pass writes `StorageDecisionLog`'s own
        // sentinel row (`categoryKey: 'none'`, `reasonCode: 'none'`) rather
        // than no row at all -- unlike the sibling test above, this one
        // exercises `_filterActionable`'s real `categoryKey != 'none'`
        // filter against a real sentinel row a default install would
        // actually produce, not an empty decision log that never reaches
        // that filter line at all.
        await log.recordPass(
          _plan(mode: StorageMode.smart.name, groups: const []),
          outcome: DecisionOutcome.planned,
          nowEpochMs: 1000,
        );

        Get.testMode = true;
        Get.put<StorageSettingsController>(controller);

        await tester.pumpWidget(
          const GetMaterialApp(home: StorageSettingsView()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Nothing to remove right now.'), findsOneWidget);
        expect(find.text('Will remove:'), findsNothing);
      },
    );

    testWidgets(
      'test_EARS_STORE_21_smart_mode_message_decision_is_not_shown',
      (tester) async {
        // A Smart Mode `messages` row must never render here -- it would
        // directly contradict SS12's own promise that Smart Mode never
        // removes conversation content (`OQ-E08-3(a)`).
        await log.recordPass(
          _plan(
            mode: StorageMode.smart.name,
            groups: [_group(categoryKey: 'messages')],
          ),
          outcome: DecisionOutcome.planned,
          nowEpochMs: 1000,
        );

        Get.testMode = true;
        Get.put<StorageSettingsController>(controller);

        await tester.pumpWidget(
          const GetMaterialApp(home: StorageSettingsView()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Nothing to remove right now.'), findsOneWidget);
      },
    );
  });

  group('EARS-STORE-22 — no clean-now affordance', () {
    testWidgets('test_EARS_STORE_22_no_clean_now_affordance_exists', (
      tester,
    ) async {
      await log.recordPass(
        _plan(
          mode: StorageMode.smart.name,
          groups: [_group(categoryKey: 'databaseFile')],
        ),
        outcome: DecisionOutcome.planned,
        nowEpochMs: 1000,
      );

      Get.testMode = true;
      Get.put<StorageSettingsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: StorageSettingsView()),
      );
      await tester.pump();
      await tester.pump();

      // This screen's ONLY legitimate tap targets are the three `_ModeRow`
      // `InkWell`s plus the shared `SettingsSubScreenScaffold`'s own
      // `_BackRow` `InkWell` (`E15-T03`, out of this task's scope but
      // present in every rendered frame) -- four in total. Asserting the
      // exact count -- not merely "no button TYPE" -- means an extra
      // `InkWell`/`GestureDetector`/`Listener` added anywhere else on the
      // screen fails this test even though it is not one of the five
      // Material button classes below.
      expect(find.byType(InkWell), findsNWidgets(4));
      // A blanket "no GestureDetector"/"no GestureDetector with onTap"
      // check is not meaningful here -- Flutter's own `Scrollable` renders
      // bare `GestureDetector`s for drag handling on this legitimately
      // scrolling screen, AND `InkWell` itself is built on an internal
      // `GestureDetector` with its own `onTap` wired through -- so every
      // one of the 4 legitimate `InkWell`s above already contributes one.
      // What actually matters -- an extra tap surface with forbidden TEXT
      // content -- is caught by the `tappableFinder` text/semantics scan
      // below, which walks GestureDetector- and Listener-based tap
      // surfaces too, regardless of whether they sit inside an `InkWell`
      // or bare. A blanket "no `Listener` with a pointer callback" check
      // is, for the same reason as `GestureDetector` above, not
      // meaningful on its own: `Scrollable`'s pan/scroll-wheel handling
      // renders several bare `Listener`s with `onPointerDown`/
      // `onPointerSignal` wired for reasons that have nothing to do with
      // a clean-now affordance.

      // No button of any kind, enabled or disabled -- kept as a named,
      // narrower check alongside the count-based one above.
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      // The affordance this criterion actually forbids is a TAPPABLE
      // element whose rendered TEXT reads as an apply/clean/delete
      // action -- not merely the absence of five specific widget class
      // names. A plain `InkWell(onTap: ..., child: Text('Clean Now'))`
      // -- the exact idiom `_ModeRow` already uses legitimately elsewhere
      // in this screen -- must fail THIS check even though it is not any
      // of the five button types above.
      // Deliberately NOT a bare `delete|remove` match: this screen's own
      // approved contract copy legitimately says "Delete data older than
      // X days" (a mode NAME) and "...can remove conversation content."
      // (a mode's own consequence line) -- both inside a tappable
      // `_ModeRow`, both already covered by `test_EARS_STORE_21_*`/the
      // design gate, and NOT a clean-now affordance. What EARS-STORE-22
      // actually forbids is an action-imperative CTA -- "Clean Now" being
      // the reviewer's own proof-of-concept -- so `delete`/`remove` only
      // count here paired with `now`, exactly as they would read on a
      // real apply-now button; `clean` and `apply` alone are safe bare
      // matches because neither appears anywhere in this screen's
      // approved copy today.
      final forbidden = RegExp(
        r'clean|\bapply\b|remove\s*now|delete\s*now|free\s*up\s*now',
        caseSensitive: false,
      );
      final tappableFinder = find.byWidgetPredicate((widget) {
        if (widget is InkWell) return widget.onTap != null;
        if (widget is GestureDetector) return widget.onTap != null;
        if (widget is Listener) {
          return widget.onPointerDown != null ||
              widget.onPointerUp != null ||
              widget.onPointerSignal != null;
        }
        return widget is ElevatedButton ||
            widget is TextButton ||
            widget is OutlinedButton ||
            widget is IconButton ||
            widget is FloatingActionButton;
      });

      for (final element in tester.elementList(tappableFinder)) {
        final ofElement = find.byElementPredicate((e) => e == element);

        for (final text in tester.widgetList<Text>(
          find.descendant(of: ofElement, matching: find.byType(Text)),
        )) {
          final data = text.data ?? text.textSpan?.toPlainText() ?? '';
          expect(
            forbidden.hasMatch(data),
            isFalse,
            reason:
                'a tappable element renders forbidden text: "$data" '
                '(EARS-STORE-22 forbids any clean/apply/delete-shaped '
                'affordance, regardless of widget type)',
          );
        }

        for (final semantics in tester.widgetList<Semantics>(
          find.descendant(of: ofElement, matching: find.byType(Semantics)),
        )) {
          final label = semantics.properties.label ?? '';
          expect(
            forbidden.hasMatch(label),
            isFalse,
            reason:
                'a tappable element carries a forbidden semantics label: '
                '"$label"',
          );
        }
      }

      // No delete/clean/apply-shaped glyph anywhere on screen.
      for (final icon in const [
        Icons.delete,
        Icons.delete_outline,
        Icons.delete_forever,
        Icons.cleaning_services,
        Icons.auto_delete,
        Icons.check_circle,
        Icons.play_arrow,
      ]) {
        expect(find.byIcon(icon), findsNothing);
      }
    });
  });

  group('EARS-UI-11 — an inventory read failure', () {
    test(
      'test_EARS_UI_11_inventory_failure_leaves_the_mode_selector_intact',
      () async {
        final failingInventory = StorageInventory(
          db: db,
          databaseFileBytes: () => Future<int>.error(Exception('boom')),
        );
        final failingController = StorageSettingsController(
          settings: settings,
          log: log,
          inventory: failingInventory,
        );
        addTearDown(failingController.onClose);

        failingController.onInit();
        await pumpEventQueue();

        expect(failingController.usageError.value, isTrue);
        expect(failingController.policy.value, isNotNull);
        expect(
          failingController.policy.value!.mode,
          StorageMode.smart.name,
          reason: 'the mode selector must survive an inventory failure',
        );

        // The mode selector's own write path is unaffected by the inventory
        // failure -- it never reads `inventory` at all.
        await failingController.selectMode(StorageMode.olderThanDays);
        final reread = await settings.read();
        expect(reread.mode, StorageMode.olderThanDays.name);
      },
    );

    testWidgets(
      'test_EARS_UI_11_inventory_failure_does_not_clear_the_usage_card',
      (tester) async {
        final failingInventory = StorageInventory(
          db: db,
          databaseFileBytes: () => Future<int>.error(Exception('boom')),
        );
        final failingController = StorageSettingsController(
          settings: settings,
          log: log,
          inventory: failingInventory,
        );
        addTearDown(failingController.onClose);

        Get.testMode = true;
        Get.put<StorageSettingsController>(failingController);

        await tester.pumpWidget(
          const GetMaterialApp(home: StorageSettingsView()),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text("Couldn't read local storage. Try again."),
          findsOneWidget,
        );
        // The mode selector still renders and is still usable.
        expect(find.text('Smart Mode'), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      },
    );
  });
}
