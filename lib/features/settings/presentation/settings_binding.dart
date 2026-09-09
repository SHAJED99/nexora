// features/settings/presentation — per-route GetX binding (E02-T03,
// widened E15-T11).
//
// Shared by `/settings` and all nine of its sub-routes (E15-T11 §3): it
// lazily registers `SettingsController` plus the eight sub-screen
// controllers and `SignOutConfirmController`, so whichever of the ten
// `settings*` routes is visited first resolves every dependency the same
// way. `Get.lazyPut` means none of the nine sub-controllers is actually
// constructed until its own screen is first opened (task §6 risk: "a screen
// whose controller needs a dependency AppBinding never registered will
// throw on first navigation, not at startup — and only for that one row") —
// every dependency each constructor needs below is either already a
// permanent `AppBinding` singleton (`Get.find`), or a lightweight repository
// this file constructs fresh over the shared `AppDatabase`, mirroring how
// every other per-screen repository in this app is already constructed
// (e.g. `LocationShareService`'s own `LocationSettingsRepository(db: db)`,
// `lib/core/messaging/messaging_stack.dart`) — never a second `AppDatabase`,
// `MessagingStack`, `TransportService` or `RoutingEngine`.
//
// **Disclosed limitation — `BatterySettingsController`'s `BackgroundControl`
// (see below).** Not silently worked around; see that registration's own
// comment.
import 'package:get/get.dart';
import 'package:nexora/core/background/background_service.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_controller.dart';
import 'package:nexora/features/settings/account/domain/sign_out_use_case.dart';
import 'package:nexora/features/settings/account/presentation/account_controller.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_controller.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_controller.dart';
import 'package:nexora/features/settings/network/presentation/network_settings_controller.dart';
import 'package:nexora/features/settings/notifications/presentation/notification_settings_controller.dart';
import 'package:nexora/features/settings/presentation/settings_controller.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_controller.dart';
import 'package:nexora/features/settings/security_center/data/security_records_repository.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_controller.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(SettingsController.new);

    // AccountController (E15-T07). `readIdentityKeyPair` is the same
    // `MessagingStack.signalStore.getIdentityKeyPair()` call
    // `login_controller.dart`'s own `_deriveDeviceIdFromLocalIdentity`
    // already uses (that controller's own header names this exact call as
    // the production wiring for this seam).
    Get.lazyPut(
      () => AccountController(
        deviceIdentityRepository: Get.find<DeviceIdentityRepository>(),
        readIdentityKeyPair: () =>
            Get.find<MessagingStack>().signalStore.getIdentityKeyPair(),
      ),
    );

    // SignOutConfirmController (E15-T07). `SignOutUseCase()`'s own default
    // constructor is exactly right here — its `teardown` parameter (closing
    // GetX-registered singletons before the wipe deletes the database file)
    // is explicitly out of this task's scope (epic tracker's carried-forward
    // F2, `sign_out_use_case.dart`'s own header) and stays the default
    // no-op until a separate task wires it.
    Get.lazyPut(
      () => SignOutConfirmController(signOutUseCase: SignOutUseCase()),
    );

    // PrivacySettingsController (E15-T05). Fresh repositories over the
    // shared `db` — the same "construct a lightweight repository per call
    // site, never a shared singleton" pattern `LocationShareService`
    // already uses for its own `LocationSettingsRepository`.
    Get.lazyPut(() {
      final db = Get.find<AppDatabase>();
      return PrivacySettingsController(
        locationRepository: LocationSettingsRepository(db: db),
        notificationRepository: NotificationSettingsRepository(db: db),
      );
    });

    // SecurityCenterController (E15-T06).
    Get.lazyPut(
      () => SecurityCenterController(
        repository: SecurityRecordsRepository(db: Get.find<AppDatabase>()),
      ),
    );

    // NetworkSettingsController (E15-T08). `transport`/`routing` are the
    // SAME permanent singletons `AppBinding` already registers
    // (`messagingStack.transport`/`messagingStack.routingEngine`) — never a
    // second `TransportService`/`RoutingEngine` (task §6 risk: a second
    // `TransportService` would steal the native transport-channel handler
    // the app-wide one owns).
    Get.lazyPut(
      () => NetworkSettingsController(
        transport: Get.find<TransportService>(),
        routing: Get.find<RoutingEngine>(),
      ),
    );

    // StorageSettingsController (E15-T09). Reuses the SAME
    // `settings`/`log`/`inventory` the app-wide `StorageManager` singleton
    // already holds (public fields on `StorageManager`) rather than
    // constructing a second `StorageInventory` — that would need its own
    // `databaseFileBytes` callback (`AppBinding._measureDatabaseFileBytes`,
    // private to a file outside this task's `files:` fence) and would give
    // this screen a second, independent view of the same on-disk state the
    // dashboard's storage card already reads through the shared instance.
    Get.lazyPut(() {
      final manager = Get.find<StorageManager>();
      return StorageSettingsController(
        settings: manager.settings,
        log: manager.log,
        inventory: manager.inventory,
      );
    });

    // BatterySettingsController (E15-T08).
    //
    // **Disclosed limitation, not silently worked around**: `AppBinding`
    // (`lib/app/bindings.dart`, outside this task's `files:` fence)
    // constructs its own `BackgroundService()` internally for
    // `BackgroundLifecycleObserver` and never registers it as a findable
    // singleton, so this binding cannot reuse that exact instance. A real
    // `BackgroundService()` constructed here calls
    // `BackgroundEventsApi.setUp(...)` a second time on the SAME default
    // (empty-suffix) platform channel `BackgroundService`'s own header
    // documents (`background_service.dart`: distinct suffixes are what let
    // multiple instances coexist without one clobbering another's registered
    // handler) — on a real device, opening this screen would silently steal
    // `BackgroundLifecycleObserver`'s own native event registration. Fixing
    // this properly means `AppBinding` registering its single
    // `BackgroundControl` as a findable permanent singleton, which is a
    // one-line change to a file this task may not touch (task §4: "does NOT
    // touch main.dart, bindings.dart"). Filed as `E15-B03` (S2) rather than
    // fixed by this task — see this task's own §9 Deviations/Open Questions —
    // constructing a fresh instance here is otherwise the same pattern every
    // other registration in this method already uses (fresh
    // repository/service per screen over shared state), and does not affect
    // any test in this suite (tests use `BackgroundStub` or a mocked
    // messenger with a distinct channel suffix, so the collision never
    // materializes there).
    Get.lazyPut(
      () => BatterySettingsController(service: BackgroundService()),
    );

    // NotificationSettingsController (E15-T04).
    Get.lazyPut(
      () => NotificationSettingsController(
        repository: NotificationSettingsRepository(db: Get.find<AppDatabase>()),
      ),
    );

    // AboutSettingsController (E15-T10). `versionPolicyService` mirrors
    // `main.dart`'s own `VersionPolicyService(database: db)` construction —
    // that instance is not registered as findable either, so this
    // constructs its own over the SAME shared `db` (never a second
    // `AppDatabase`). Every other parameter stays the controller's own
    // production default (`_readInstalledVersion`/`readInstalledBuildNumber`/
    // `_readDiagnosticLog`) — never overridden here.
    Get.lazyPut(
      () => AboutSettingsController(
        versionPolicyService: VersionPolicyService(
          database: Get.find<AppDatabase>(),
        ),
      ),
    );
  }
}
