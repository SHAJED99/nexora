// features/settings/storage/presentation -- E15-T09 (E08-T09, rehomed).
//
// `FR-STORE-004` is half-owned and that is deliberate (task §2): `E08-T05`'s
// `StorageSettingsRepository` owns the persistence and the validation; this
// controller owns only the selection UI. `E08-T06`'s `StorageManager` owns
// execution alone -- this file never imports it, never calls it, and never
// references `RetentionExecutor` (task §4). Changing a mode writes a
// setting; it runs nothing, applies nothing, deletes nothing.
//
// This screen observes `E08-T04`'s `RetentionPlan`, via
// `StorageDecisionLog.latestPass()`, and holds no second policy rule of its
// own (task §2/§5) -- if a widget and the plan ever disagree, the plan wins
// and the widget is the bug.
import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart'
    show StorageDecisionRow, StoragePolicySettingRow;
import 'package:nexora/core/storage/retention_plan.dart' show DecisionOutcome;
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart' show StorageClassTotal;
import 'package:nexora/core/storage/storage_settings_repository.dart';

/// `settings-storage.md`'s screen controller. Every value this controller
/// exposes is read from [settings]/[log]/[inventory] -- no local defaulting,
/// no second copy, no re-implementation of the eight-factor scoring (task
/// §4).
class StorageSettingsController extends GetxController {
  StorageSettingsController({
    required this.settings,
    required this.log,
    required this.inventory,
  });

  final StorageSettingsRepository settings;
  final StorageDecisionLog log;
  final StorageInventory inventory;

  /// FR-STORE-004's read side -- bound to [StorageSettingsRepository.watch],
  /// which emits its current value on listen
  /// (`test_EARS_STORE_11_watch_emits_current_value_on_listen`, E08-T05's own
  /// proof). `null` only for the brief window before that first emission
  /// arrives -- never a fabricated placeholder row (the carried-forward
  /// `toggle()` guard: "never invent a local 'assume X' default"). The mode
  /// selector renders unselected, not wrong, during that window, and
  /// [selectMode] never needs to read this value first -- it writes an
  /// absolute choice, so the selector stays usable even before the first
  /// emission (design contract's own `loading` state: "the mode selector
  /// still renders and is still usable").
  final Rx<StoragePolicySettingRow?> policy = Rx<StoragePolicySettingRow?>(
    null,
  );

  /// `true` once [settings]'s `watch()` stream has emitted an error. Kept
  /// independent of [usageError]/[decisionsError] (EARS-UI-11: a failed read
  /// in one section leaves every other section, and every user-chosen
  /// setting, unchanged) -- this screen's own contract carves out no
  /// dedicated error line for the mode-selector section, so a failure here
  /// simply leaves [policy] at its last-known value rather than clearing it.
  final RxBool policyError = false.obs;

  /// The parameter draft for `StorageMode.olderThanDays`, editable via
  /// [updateOlderThanDays]. Seeded from the persisted row when it carries a
  /// value for that mode; otherwise defaults to `1` -- `StorageSettingsRepository`'s
  /// own stated validation floor (`>= 1`), never an invented business
  /// default (task §2: "this screen holds no second policy rule of its
  /// own").
  final RxInt olderThanDaysDraft = 1.obs;

  /// The parameter draft for `StorageMode.overSizeMb`, in whole MB --
  /// [StorageSettingsRepository.minMaxBytes] is the one and only MiB/MB
  /// conversion point this file uses, applied here exactly once (task §6
  /// risk note: "convert once, here, and state it in a comment").
  final RxInt maxBytesMbDraft = 1.obs;

  /// The per-class usage totals (`FR-STORE-007`'s usage-summary context),
  /// empty until [_loadUsage] completes. `null`-vs-empty is not meaningful
  /// here: an empty list before the first load IS this screen's `loading`
  /// state (design contract: "unpopulated", never a spinner).
  final RxList<StorageClassTotal> usageClassTotals = <StorageClassTotal>[]
      .obs;

  /// The sqlite file's own on-disk size, reported separately from
  /// [usageClassTotals] and never summed into [usageTotalBytes]
  /// (`StorageInventory`'s own header: summing them would misrepresent
  /// both).
  final Rx<int?> usageDatabaseFileBytes = Rx<int?>(null);

  /// The real measured total (`StorageInventory.totalBytes`) -- SS7's own
  /// "N MB used" figure. `null` until [_loadUsage] completes; never a
  /// fabricated percentage (`GAP-026`'s already-approved deviation).
  final Rx<int?> usageTotalBytes = Rx<int?>(null);

  /// `true` once the one-time [inventory] read has failed. Independent of
  /// [decisionsError]/[policyError] (EARS-UI-11).
  final RxBool usageError = false.obs;

  /// `true` once the initial usage load has settled (success or failure) --
  /// distinguishes the `loading` state (this is still `false`) from the
  /// `empty`/`error` states (design contract §5), since an empty
  /// [usageClassTotals] list is ambiguous between "hasn't loaded yet" and
  /// "loaded, and every class is genuinely zero".
  final RxBool usageLoaded = false.obs;

  /// `FR-STORE-007`. The latest pass's *actionable, still-forecast* decisions
  /// -- see [_filterActionable] for exactly which rows this excludes and
  /// why. Never a second scoring of the plan (task §4): every row here is a
  /// `StorageDecisionLog.latestPass()` row, verbatim except for the filter.
  final RxList<StorageDecisionRow> decisions = <StorageDecisionRow>[].obs;

  /// `true` once the initial `latestPass()` read has failed. Independent of
  /// [usageError]/[policyError] (EARS-UI-11).
  final RxBool decisionsError = false.obs;

  /// `true` once the initial decisions load has settled -- same
  /// loading-vs-empty distinction [usageLoaded] makes, for the `empty`
  /// state ("nothing scheduled" — design contract §5, required, not an
  /// edge case).
  final RxBool decisionsLoaded = false.obs;

  StreamSubscription<StoragePolicySettingRow>? _policySubscription;

  @override
  void onInit() {
    super.onInit();
    _policySubscription = settings.watch().listen(
      _onPolicy,
      onError: (Object _, StackTrace _) {
        policyError.value = true;
      },
    );
    unawaited(_loadUsage());
    unawaited(_loadDecisions());
  }

  void _onPolicy(StoragePolicySettingRow row) {
    policy.value = row;
    final mode = StorageMode.values.byName(row.mode);
    if (mode == StorageMode.olderThanDays && row.olderThanDays != null) {
      olderThanDaysDraft.value = row.olderThanDays!;
    }
    if (mode == StorageMode.overSizeMb && row.maxBytes != null) {
      maxBytesMbDraft.value =
          row.maxBytes! ~/ StorageSettingsRepository.minMaxBytes;
    }
  }

  Future<void> _loadUsage() async {
    try {
      final snapshot = await inventory.snapshot();
      usageClassTotals
        ..clear()
        ..addAll(snapshot.classTotals);
      usageDatabaseFileBytes.value = snapshot.databaseFileBytes;
      usageTotalBytes.value = inventory.totalBytes(snapshot);
      usageError.value = false;
    } catch (_) {
      usageError.value = true;
    } finally {
      usageLoaded.value = true;
    }
  }

  Future<void> _loadDecisions() async {
    try {
      final rows = await log.latestPass();
      decisions
        ..clear()
        ..addAll(_filterActionable(rows));
      decisionsError.value = false;
    } catch (_) {
      decisionsError.value = true;
    } finally {
      decisionsLoaded.value = true;
    }
  }

  /// `EARS-STORE-21` requires "a plan with no candidates" to read as nothing
  /// scheduled, and SS12 promises Smart Mode never removes conversation
  /// content -- satisfying both means this screen cannot render
  /// `latestPass()`'s rows verbatim. Mirrors
  /// `dashboard_controller.dart`'s own `_decisionsFromLog` filter exactly
  /// (task §2's "one plan shape" -- the two explanation surfaces must
  /// agree), never re-derived independently:
  /// - the zero-candidate sentinel row (`categoryKey: 'none'`) is never a
  ///   category;
  /// - an already-`applied` row describes the past, not a forecast --
  ///   SS20's "Will remove:" is future tense;
  /// - `categoryKey: 'relayCache'` is always `RelayEngine`'s own reclaim,
  ///   never a policy choice this screen's mode selector makes
  ///   (`RetentionExecutor`'s invariant 1);
  /// - `categoryKey: 'messages'` logged under a Smart Mode pass is never
  ///   actionable (`OQ-E08-3(a)`) -- showing it would directly contradict
  ///   SS12.
  List<StorageDecisionRow> _filterActionable(List<StorageDecisionRow> rows) {
    return [
      for (final row in rows)
        if (row.categoryKey != 'none' &&
            row.outcome != DecisionOutcome.applied.name &&
            row.categoryKey != 'relayCache' &&
            !(row.categoryKey == 'messages' &&
                row.mode == StorageMode.smart.name))
          row,
    ];
  }

  /// FR-STORE-004's write path (task §5 contract). Writes an absolute
  /// choice through [settings] and nothing else -- no execution, no
  /// scheduling (`EARS-STORE-20`). Smart Mode carries no parameter; the two
  /// manual modes carry their own current draft, so re-selecting an
  /// already-active manual mode is a harmless no-op write of the same
  /// value.
  Future<void> selectMode(StorageMode mode) async {
    switch (mode) {
      case StorageMode.smart:
        await settings.setMode(StorageMode.smart);
      case StorageMode.olderThanDays:
        await settings.setMode(
          StorageMode.olderThanDays,
          olderThanDays: olderThanDaysDraft.value,
        );
      case StorageMode.overSizeMb:
        await settings.setMode(
          StorageMode.overSizeMb,
          maxBytes: maxBytesMbDraft.value * StorageSettingsRepository.minMaxBytes,
        );
    }
  }

  /// Edits `olderThanDays`'s own draft (SS17). Still "writes the mode and
  /// nothing else" (task §5 contract): the active mode does not change here,
  /// only its own parameter does, and only when that mode is already the
  /// active one -- editing the field for a mode that is not selected updates
  /// the draft only, so tapping the row afterwards writes the edited value
  /// (task §6 risk note: "the UI validates before ever calling this; the
  /// repository is the backstop, not the only guard"). Returns `false`
  /// without writing anything when [days] is below the repository's own
  /// floor (`>= 1`) -- the caller renders SS18/SS19 in that case.
  Future<bool> updateOlderThanDays(int days) async {
    if (days < 1) return false;
    olderThanDaysDraft.value = days;
    final current = policy.value;
    if (current != null &&
        StorageMode.values.byName(current.mode) == StorageMode.olderThanDays) {
      await settings.setMode(StorageMode.olderThanDays, olderThanDays: days);
    }
    return true;
  }

  /// Same contract as [updateOlderThanDays], for `overSizeMb`'s own draft.
  /// [mb] is whole MB as the user types it; the MiB conversion happens here,
  /// once (task §6 risk note).
  Future<bool> updateMaxBytesMb(int mb) async {
    if (mb < 1) return false;
    maxBytesMbDraft.value = mb;
    final current = policy.value;
    if (current != null &&
        StorageMode.values.byName(current.mode) == StorageMode.overSizeMb) {
      await settings.setMode(
        StorageMode.overSizeMb,
        maxBytes: mb * StorageSettingsRepository.minMaxBytes,
      );
    }
    return true;
  }

  @override
  void onClose() {
    unawaited(_policySubscription?.cancel());
    super.onClose();
  }
}
