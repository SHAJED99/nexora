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
import 'package:nexora/core/services/device_revocation_service.dart';
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

    // SignOutConfirmController (E15-T07), production `teardown`/`revoke`
    // wiring (E15-T12, epic tracker carried-forward F1/F2; `Q-SEC-009`(b)/
    // `Q-FUNC-010`).
    //
    // `deviceId`/`identityFuture` are captured HERE, at controller
    // -construction time (the first time this screen is visited — well
    // before sign-out is ever confirmed), because `sign_out_use_case.dart`'s
    // own contract (task §5) places `revoke` strictly AFTER `teardown` has
    // already closed `AppDatabase`. Reading `db.latestDeviceIdentity()`
    // lazily inside the `revoke` closure itself would resolve against an
    // already-closed connection; starting the read now (while `db` is
    // definitely still open) and awaiting the already-in-flight `Future`
    // inside `revoke` avoids that for the VALUES — see the disclosed
    // limitation below for what this does not fix.
    //
    // **Disclosed limitation, not silently worked around** (task §9
    // Deviations mirrors this): `revoke`'s own contract fixes it strictly
    // after `wipeService.wipe()`, and this file's own `teardown` closure
    // (below) closes the shared `AppDatabase` before the wipe runs.
    // `DeviceRevocationService.revoke()`
    // (`lib/core/services/device_revocation_service.dart`, outside this
    // task's `files:` fence — §4: "does NOT change `DeviceRevocationService`'s
    // own API") writes a LOCAL `device_revocations` row FIRST, before its
    // remote Firebase push — against a database that, by the time `revoke`
    // actually runs here, has already been closed by `teardown`. That local
    // write throws; the throw is caught by `SignOutUseCase.call()`'s own
    // best-effort wrapper around `revoke` (never propagates, never blocks
    // sign-out, exactly as specified), but it also means the remote
    // Firebase push this task exists to add will not reliably complete in
    // production today. Not fixable inside this task's fence: a real fix
    // needs either `DeviceRevocationService`'s local write to become
    // independently best-effort (a change to a file this task may not
    // touch) or the `revoke`-after-`wipe` ordering to change (a change to
    // `call()`'s ordering §4 forbids). Flagged as a follow-up rather than
    // resolved here — see this task's Run log.
    Get.lazyPut(() {
      final db = Get.find<AppDatabase>();
      final messagingStack = Get.find<MessagingStack>();
      final deviceId = messagingStack.selfDeviceId;
      final identityFuture = db.latestDeviceIdentity();

      return SignOutConfirmController(
        signOutUseCase: SignOutUseCase(
          teardown: () async {
            // Order matters (task §6 Risks): `MessagingStack.dispose()`
            // already closes `db` internally, fully awaited
            // (`messaging_stack.dart`'s own `dispose()`: `coordinator.stop()`
            // -> `transport.dispose()` -> `db.close()`) — `messagingStack`
            // and `db` share the SAME `AppDatabase` instance
            // (`bindings.dart`'s own header: "one AppDatabase instance
            // shared by every repository"), so `db.close()` is never called
            // again separately here — a double close is not this file's to
            // risk. Every other permanent singleton `AppBinding` registers
            // (`DeviceIdentityRepository`, `RelationshipRepository`,
            // `StorageManager`, etc.) holds a reference to this SAME `db`
            // rather than a second connection of its own, so closing this
            // one connection is sufficient — there is no second database
            // handle anywhere in this app left to close.
            if (Get.isRegistered<MessagingStack>()) {
              await Get.find<MessagingStack>().dispose();
              Get.delete<MessagingStack>(force: true);
            }
            if (Get.isRegistered<AppDatabase>()) {
              Get.delete<AppDatabase>(force: true);
            }
          },
          revoke: () async {
            final identity = await identityFuture;
            final uid = identity?.accountUid;
            if (uid == null || uid.isEmpty || deviceId.isEmpty) return;
            await DeviceRevocationService(
              localDeviceId: deviceId,
              database: db,
            ).revoke(uid, deviceId);
          },
        ),
      );
    });

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
