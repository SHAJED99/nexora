// app/bindings.dart — DI via Get.put()/Get.lazyPut() (ADR-0002).
//
// A single global binding: one AppDatabase instance shared by every
// repository, plus per-feature controllers. Later epics likely split this
// into per-route bindings as feature count grows; kept as one binding while
// the screen count stays small.
//
// E06-T03: `AppDatabase` and `MessagingStack` are now both built in
// `lib/app/main.dart`, BEFORE `runApp`/`GetMaterialApp`/this binding ever
// runs (`MessagingStack.create` is async; `Bindings.dependencies()` is not).
// This binding's job for both is now the same: register the ALREADY-BUILT
// instance it is handed — never construct a second one of either (task file
// §2: two `AppDatabase`s, or two of anything `MessagingStack` owns, is the
// exact defect this task exists to prevent, not a style preference).
import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/notifications/notification_dispatcher.dart';
import 'package:nexora/core/notifications/notification_policy.dart';
import 'package:nexora/core/notifications/notification_service.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/notifications/sources/call_notification_source.dart';
import 'package:nexora/core/notifications/sources/connection_request_notification_source.dart';
import 'package:nexora/core/notifications/sources/message_notification_source.dart';
import 'package:nexora/core/notifications/sources/storage_notification_source.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart'
    show RetentionPlan, SmartModeThresholds;
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/features/home/presentation/home_controller.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/welcome/presentation/welcome_controller.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppBinding extends Bindings {
  AppBinding({required this.db, required this.messagingStack});

  /// The single app-wide `AppDatabase`, already constructed in `main.dart`
  /// before `runApp` — never constructed here (see file header).
  final AppDatabase db;

  /// The single app-wide messaging stack, already constructed in
  /// `main.dart` before `runApp` (E06-T03). Always non-null — see
  /// `MessagingStack.create`'s own contract: construction never throws, a
  /// degraded device is reported via `messagingStack.status` instead.
  final MessagingStack messagingStack;

  @override
  void dependencies() {
    Get.put(db, permanent: true);
    Get.put(
      DeviceIdentityRepository(Get.find<AppDatabase>()),
      permanent: true,
    );
    Get.put(SignInUseCase(Get.find<DeviceIdentityRepository>()), permanent: true);
    // E02-T01's trust domain — shared singletons; `DevicesBinding` (E02-T02)
    // finds these to build `DevicesController`.
    Get.put(RelationshipRepository(Get.find<AppDatabase>()), permanent: true);
    Get.put(
      BlockUseCase(Get.find<RelationshipRepository>()),
      permanent: true,
    );

    Get.lazyPut(WelcomeController.new);
    Get.lazyPut(() => LoginController(Get.find<SignInUseCase>()));
    Get.lazyPut(
      () => HomeController(Get.find<DeviceIdentityRepository>()),
    );

    // `SettingsController` (E02-T03) has no shared dependencies of its
    // own — it's a pure navigation menu — so it needs no permanent
    // singleton here; `SettingsBinding` registers it directly per-route,
    // same as `DevicesBinding` does for the rest of its controller.

    // E06-T03: the messaging composition root. `messagingStack` itself is
    // registered for callers that need `.status` (a degraded-device UI,
    // T10/T12) or need to reach a member not listed individually below;
    // each member is ALSO registered directly so a screen that only needs
    // (say) `SendMessageUseCase` doesn't have to thread `MessagingStack`
    // through. Every registration here is `permanent: true` and none is
    // `lazyPut` — a lazily-created second instance of any of these is
    // exactly the correctness defect task file §2 describes, not a style
    // choice.
    Get.put(messagingStack, permanent: true);
    // E06-T11 (OQ-E06-T06-4): the one lifecycle call `messaging_stack.dart`'s
    // own header names as still missing — `coordinator` is fully constructed
    // by `MessagingStack.create` but `create()` deliberately never starts it
    // (that file's own "does NOT start anything" contract). Without this,
    // EARS-MSG-1 stays true only in E06-T06's own tests, never in the app a
    // user runs. No new binding, no new singleton, no other change to this
    // file's existing registrations.
    messagingStack.coordinator.start();
    Get.put(messagingStack.sendMessage, permanent: true);
    Get.put(messagingStack.receiveMessage, permanent: true);
    Get.put(messagingStack.syncCursors, permanent: true);
    Get.put(messagingStack.relayEngine, permanent: true);
    Get.put(messagingStack.routingEngine, permanent: true);
    // E06-B02: this registration is also what `DevicesBinding` now resolves
    // via `Get.find<TransportService>()` to inject the shared instance into
    // `DevicesController` -- it MUST run (as it already does, here, at app
    // startup, before any route's `Bindings.dependencies()` can run) before
    // the user can navigate to `/devices`, or `Get.find` there throws.
    // Never remove this registration or make it lazy: `DevicesController`
    // needs a resolvable shared `TransportService` the very first time the
    // user opens the Devices screen, and a second live `TransportService`
    // (the previous, broken behaviour) silently steals every native
    // transport-channel handler this instance owns.
    Get.put(messagingStack.transport, permanent: true);

    // E06-T04: the producer/consumer wiring E04-B03 named and E05 never
    // wrote. Without this, `RoutingEngine._knownLinks` has no production
    // populator and `computeRoute()` always returns `null` on a real
    // device — every other messaging task is downstream of this being
    // true. Constructed from the already-registered singletons above
    // (never a second `TransportService`/`RoutingEngine`), started once.
    Get.put(
      LinkQualityFeed(
        transport: messagingStack.transport,
        routing: messagingStack.routingEngine,
      ),
      permanent: true,
    ).start();

    // E08-T06: the storage-retention composition root. Built AFTER `db`
    // above (StorageInventory/StorageSettingsRepository/RetentionExecutor/
    // StorageDecisionLog all depend on it). `messagingStack.coordinator
    // .start()` is actually called EARLIER in this method (line ~95,
    // above), not after this block -- but that call is fire-and-forget
    // (`start()`'s own body suspends at its first `await`, well before it
    // schedules any tick that could read `coordinator.storageManager`;
    // `MessagingCoordinator`'s own tick only ever runs from the
    // `Timer.periodic` `start()` sets up or an explicit `tick()` call, both
    // strictly later than this synchronous method returning) -- so by the
    // time a real tick can ever observe the field, it is already set here,
    // synchronously, before this method returns control to its caller.
    // Never calls `Get.find` for this wiring at all -- every dependency
    // below is the already-registered `db` or a value this method already
    // has in scope (task file §6 risk: registering too early yields a
    // `Get.find` failure at startup; this order avoids that entirely).
    //
    // `MessagingCoordinator` is already fully constructed inside
    // `MessagingStack.create()` (before this binding ever runs, E06-T03) --
    // this task's own fence excludes `messaging_stack.dart`, so the
    // coordinator's own constructor call cannot change. `storageManager` is
    // therefore set on the coordinator's public, mutable field
    // (`messaging_coordinator.dart`'s own E08-T06 header) rather than
    // passed at construction.
    // One `StorageDecisionLog` instance, shared by the manager's own
    // `planned`-outcome writes and the executor's `applied`/`skipped`
    // writes — both are the single logical writer of `storage_decisions`
    // for this app (task file §3: "the only writer"), and sharing the
    // instance keeps its in-process row-id counter (`storage_decision_log
    // .dart`'s own header) monotonic across both call paths rather than
    // resetting per instance.
    final decisionLog = StorageDecisionLog(db: db);
    final storageManager = StorageManager(
      settings: StorageSettingsRepository(db: db),
      inventory: StorageInventory(
        db: db,
        databaseFileBytes: _measureDatabaseFileBytes,
      ),
      smart: SmartModePolicy(thresholds: SmartModeThresholds.defaults()),
      executor: RetentionExecutor(db: db, log: decisionLog),
      log: decisionLog,
    );
    Get.put(storageManager, permanent: true);
    messagingStack.coordinator.storageManager = storageManager;

    // E10-T03: the notification composition root. `NotificationService`
    // itself is E10-T01's Pigeon-backed facade (never constructed a second
    // time here — same "one instance of anything a task owns" discipline
    // as `messagingStack` above); `NotificationSettingsRepository` is
    // E10-T02's settings store, built from the already-registered `db`. The
    // dispatcher is registered so a future screen/controller can reach it
    // (`Get.find<NotificationDispatcher>()`), and `register()` is the
    // extension point `E10-T04`-`E10-T07` use to add a notification class
    // without editing this block (task file §3). `start()` is
    // fire-and-forget for the same reason `messagingStack.coordinator
    // .start()` above is: it suspends at its first `await`
    // (`NotificationService.ensureReady()`), well before anything in this
    // synchronous method could observe a partial result, and every source
    // registered before that first `await` resolves is still subscribed
    // once it does (`NotificationDispatcher.start()`'s own contract).
    //
    // `stop()` has no composition-root call site here, matching the
    // standing gap already true of `messagingStack.dispose()` itself
    // (never called anywhere in this app today, `messaging_stack.dart:607`)
    // — this task does not invent app-lifecycle teardown that does not
    // exist yet (`E10-T10`'s scope).
    final notificationDispatcher = NotificationDispatcher(
      service: NotificationService(),
      policy: NotificationPolicy(
        settings: NotificationSettingsRepository(db: db),
      ),
    );
    notificationDispatcher.register(
      MessageNotificationSource(
        messagingStack.inbound.delivered,
        selfDeviceId: messagingStack.selfDeviceId,
      ),
    );
    // E10-T04: the `incomingCall` category producer. `CallSignaling.notices`
    // is this task's own addition to an E07-owned file
    // (`call_signaling.dart`) -- observation only, see that file's header.
    // `sink: notificationDispatcher.service` reuses the SAME `NotificationService`
    // instance constructed just above (never a second one, same "one
    // instance of anything a task owns" discipline as `messagingStack`) --
    // `CallNotificationSource` needs it to issue a cancel directly, bypassing
    // `NotificationPolicy` entirely (see that source's own header for why a
    // withdrawal is not a privacy/enablement decision).
    notificationDispatcher.register(
      CallNotificationSource(
        messagingStack.callSignaling.notices,
        sink: notificationDispatcher.service,
      ),
    );
    // E10-T05: the `connectionRequest` category producer.
    // `PrekeyExchange.connectionRequests` is this task's own addition to an
    // E06-owned file (`prekey_exchange.dart`) -- observation only, see that
    // file's own doc comment on `ConnectionRequestNotice`. Unlike
    // `CallNotificationSource` above, this source needs no `sink` -- it has
    // no cancel concept (a connection request is not withdrawn), so every
    // post still goes through `NotificationDispatcher`/`NotificationPolicy`
    // via `facts` alone (task file §5 signature).
    notificationDispatcher.register(
      ConnectionRequestNotificationSource(
        messagingStack.prekeyExchange.connectionRequests,
      ),
    );
    // E10-T07: the `storageWarning` category producer. Observes
    // `storageManager.latestPlan` (the SAME instance registered above at
    // line ~178, never a second `StorageManager`) -- no new E08 seam, per
    // that source's own header. `isOverThreshold` is built here, not in the
    // source file, from `RetentionPlan.groups.isNotEmpty` -- the exact same
    // "would remove something" condition `DashboardController
    // ._loadStorageUsage`'s own `warningActive: decisions.isNotEmpty`
    // (`dashboard_controller.dart:418`) uses for its warning glyph, just
    // read off the live plan (this task's required seam) instead of the
    // durable decision log (that controller's own seam, for its own
    // documented reason). No new threshold number is introduced anywhere in
    // this composition.
    final storageNotificationSource = StorageNotificationSource(
      storageManager.latestPlan,
      isOverThreshold: (RetentionPlan plan) => plan.groups.isNotEmpty,
    );
    notificationDispatcher.register(storageNotificationSource);
    // Registered so a future app-lifecycle teardown call can resolve and
    // dispose it (`storage_notification_source.dart`'s own `dispose()`
    // contract, task file §5/§6: "Rx workers leak if not disposed"). No
    // such teardown call site exists anywhere in this method today --
    // matches the identical, already-documented standing gap just below
    // for `notificationDispatcher.stop()`/`messagingStack.dispose()`
    // (neither has a caller either); inventing one here would be
    // app-lifecycle scaffolding this task's own `files:` fence does not
    // authorise, and this exact gap is `E10-T10`'s scope, not this task's
    // (task file §4: "does not add ... a second periodic timer, isolate or
    // background service" -- the same "not this task's seam" discipline
    // extends to teardown wiring that does not exist yet either).
    Get.put(storageNotificationSource, permanent: true);
    // Fire-and-forget, guarded: a real device's native `NotificationApi`
    // channel is always registered, so this never hides a production
    // failure. A test harness with no platform-channel mock for it --
    // `messaging_coordinator_test.dart` builds a full `AppBinding` to prove
    // storage-manager wiring, not notification wiring -- would otherwise
    // surface an unrelated `PlatformException` as an unhandled async error
    // well after that test has already completed. `_measureDatabaseFileBytes`
    // above guards the identical "platform channel unavailable in this
    // test's zone" shape for the same reason.
    unawaited(
      notificationDispatcher.start().catchError((Object e) {
        ObservabilityService.instance.logError(
          'notification.dispatcher_start_failed',
          cause: e,
        );
      }),
    );
    Get.put(notificationDispatcher, permanent: true);
  }

  /// The sqlite file's own on-disk size (`StorageInventory`'s own
  /// `databaseFileBytes` contract, E08-T02) -- mirrors
  /// `database.dart`'s private `_openConnection` path construction exactly
  /// (`getApplicationDocumentsDirectory()` + `nexora.sqlite`) rather than
  /// exposing a new public path getter on `AppDatabase`, since
  /// `database.dart` is not in this task's `files:` fence. Returns `0` for
  /// a fresh install where the file has not been created yet (a real zero,
  /// never a fabricated estimate — E04-B03's standing prohibition), and
  /// also `0` if the platform channel itself is unavailable (e.g. a plain
  /// `flutter_test` unit test with no `path_provider` mock registered) --
  /// this is a peripheral display measurement, never allowed to take down
  /// the whole storage pass (task file §6 risk: "An exception in the
  /// storage pass must not abort the coordinator tick" applies with equal
  /// force to a sub-measurement failing inside one). The failure direction
  /// is safe either way (undercounting never causes a false deletion), but
  /// a silent `0` forever on a device where this genuinely fails would
  /// leave no trace of why (round-1 review F4) -- logged once per failure
  /// via `ObservabilityService`, never `print()` (docs/conventions.md),
  /// and never the exception's own message content (it is a path/IO
  /// failure, not user data, so nothing here risks FR-DIAG-002).
  static Future<int> _measureDatabaseFileBytes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'nexora.sqlite'));
      if (!await file.exists()) return 0;
      return await file.length();
    } catch (e) {
      ObservabilityService.instance.logError(
        'storage.database_file_bytes_measurement_failed',
        cause: e,
      );
      return 0;
    }
  }
}
