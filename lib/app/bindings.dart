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
import 'dart:io';

import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart' show SmartModeThresholds;
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
