// core/notifications/sources — the `storageWarning` category producer
// (E10-T07, EARS-NOTIFY-14/15).
//
// Observes `StorageManager.latestPlan` (`storage_manager.dart:82`, an
// `Rx<RetentionPlan?>` E08-T06 already exposes and already updates from
// `MessagingCoordinator`'s own tick) rather than adding any new seam — this
// task's own `files:` fence touches zero E08 files, the rarest and best
// case for a notification source (task file §2).
//
// **"Over threshold" reuses the dashboard's own condition, never a new
// number (task file §2).** `DashboardController._loadStorageUsage`
// (`dashboard_controller.dart:409-419`) shows its warning glyph exactly
// when `decisions.isNotEmpty` — i.e. Smart Mode identified at least one
// candidate group to remove — not against any percentage-of-budget
// literal. There is no numeric threshold anywhere in `core/storage` that
// gates that glyph (`SmartModeThresholds.storagePressureRatio` is an
// internal Smart Mode *factor* input, scored inside `smart_mode_policy
// .dart`, not a warning gate — it never appears in
// `dashboard_controller.dart`). So there is no shared numeric symbol to
// import, and none to duplicate — the "existing threshold" this task must
// reuse is structural: does the plan carry any candidate group at all.
// `bindings.dart` wires `isOverThreshold` as `(plan) => plan.groups
// .isNotEmpty`, the exact same condition applied to `RetentionPlan`
// directly (the seam this task is required to observe) instead of to the
// durable decision log (`dashboard_controller.dart`'s own seam, chosen
// there for a different reason — see that file's header on why it never
// reads `latestPlan` as its source of truth). No literal of any kind is
// written in THIS file — the predicate is built entirely at the
// composition root, per this class's own constructor contract (task file
// §5: "never a literal written in this file").
//
// **Rising edge only, latched, re-arms on falling then rising again (task
// file §3/§6).** `_wasOverThreshold` starts `false` with no persisted
// state — so a device that is ALREADY over threshold the first time this
// source ever observes a plan still counts as one crossing (task file §6
// risk: "an initial over-threshold reading" must notify once, not never).
// A `null` plan (before the first pass this process has run) is never
// evaluated at all — it neither arms nor disarms the latch (task file §6
// risk: "null must not be read as under threshold").
//
// Uses `ever()` (`package:get`), the same "Rx worker" idiom
// `DashboardController._storagePlanWorker` already uses for this exact
// `Rx` (`dashboard_controller.dart:281-284`) — never a raw
// `StreamSubscription` on `.stream`, and never `async*`/`await for`
// (`call_notification_source.dart`'s own header documents why that idiom
// was tried and abandoned elsewhere in this file's siblings).
library;

import 'dart:async';

import 'package:get/get.dart';

import '../../storage/retention_plan.dart' show RetentionPlan;
import '../generated/notification_api.g.dart' show NotificationCategory;
import '../notification_dispatcher.dart' show NotificationSource;
import '../notification_policy.dart';

/// Posts one `storageWarning` [NotificationFacts] per crossing of the
/// dashboard's own "would remove something" condition (task file §3/§5) —
/// never once per six-hourly pass while the condition persists.
class StorageNotificationSource implements NotificationSource {
  StorageNotificationSource(
    Rx<RetentionPlan?> latestPlan, {
    required this.isOverThreshold,
  }) : _latestPlan = latestPlan {
    _worker = ever<RetentionPlan?>(_latestPlan, _handle);
  }

  final Rx<RetentionPlan?> _latestPlan;

  /// Injected predicate built from E08's existing threshold symbol — never
  /// a literal written in this file (task file §5 contract).
  final bool Function(RetentionPlan) isOverThreshold;

  final StreamController<NotificationFacts> _controller =
      StreamController<NotificationFacts>.broadcast();

  Worker? _worker;

  /// `false` with no persisted state (task file §3: "re-arms on process
  /// start" is a deliberate simplification, not a bug) — so the very first
  /// observed plan, if already over threshold, still reads as a rising
  /// edge from this baseline.
  bool _wasOverThreshold = false;

  /// The one stable id every posted storage warning shares (task file §5:
  /// this category has no conversation or peer to key off, unlike every
  /// other source in this directory) — a second post while the latch is
  /// still armed would replace rather than stack, exactly like every other
  /// category's own `stableId`, even though the latch already prevents a
  /// second post from ever being emitted.
  static const String _conversationId = 'storage-warning';

  @override
  Stream<NotificationFacts> get facts => _controller.stream;

  void _handle(RetentionPlan? plan) {
    // Null is never evaluated — it must neither arm nor disarm the latch
    // (task file §6 risk).
    if (plan == null) return;

    final bool over = isOverThreshold(plan);
    if (over && !_wasOverThreshold) {
      _controller.add(
        NotificationFacts(
          category: NotificationCategory.storageWarning,
          conversationId: _conversationId,
          peerDeviceId: null,
          peerDisplayName: null,
          stableId: stableNotificationId(_conversationId),
        ),
      );
    }
    _wasOverThreshold = over;
  }

  /// Drops the `ever` worker and closes the internal stream — safe to call
  /// twice (task file §5 contract; `Worker.dispose()` is itself idempotent,
  /// `rx_workers.dart`'s own guard, and the second half of this method
  /// mirrors that same idempotence for `_controller`).
  void dispose() {
    _worker?.dispose();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
