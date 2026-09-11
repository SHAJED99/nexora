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
// `BatterySettingsController`'s `BackgroundControl` is likewise resolved via
// `Get.find` against the SAME permanent singleton `AppBinding` registers for
// `BackgroundLifecycleObserver` (E15-B03 fix) — see that registration's own
// comment below.
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
    // before sign-out is ever confirmed), so both are ready the instant
    // `SignOutUseCase.call()` invokes the `revoke` closure below — no
    // lazy `Get.find`/`db` read happens inside the closure itself.
    //
    // **Ordering fix (E15-T12, corrected during implementation — see
    // `sign_out_use_case.dart`'s own header and this task's §9 Deviations
    // for the full history):** `sign_out_use_case.dart`'s `call()` now runs
    // `revoke` BEFORE `teardown`, not after. The original contract placed
    // `revoke` strictly after `wipeService.wipe()`, but
    // `DeviceRevocationService.revoke()`
    // (`lib/core/services/device_revocation_service.dart`, outside this
    // task's `files:` fence — §4: "does NOT change `DeviceRevocationService`'s
    // own API") writes a LOCAL `device_revocations` row FIRST, before its
    // remote Firebase push — and that write needs the SAME shared `db`
    // handle this closure captured above, which the `teardown` closure
    // below closes. With the old ordering that local write threw on every
    // single sign-out (deterministically, since `teardown` always runs
    // first), so the call never reached the Firebase push at all. Now that
    // `call()` runs `revoke` first, this closure's captured `db` is still
    // live when `DeviceRevocationService.revoke()` runs — its local write
    // succeeds, and (being irrelevant here anyway, since the whole database
    // is wiped moments later) its "survives next launch" property is simply
    // not needed in this call path.
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
    // **E15-B03 fix**: resolves the SAME `BackgroundControl` singleton
    // `AppBinding` (`lib/app/bindings.dart`) registers for
    // `BackgroundLifecycleObserver`, rather than constructing a second,
    // independent `BackgroundService()`. A second real `BackgroundService()`
    // would call `BackgroundEventsApi.setUp(...)` again on the SAME default
    // (empty-suffix) platform channel `BackgroundService`'s own header
    // documents, and Pigeon's generated `setUp` unconditionally replaces
    // whatever handler was previously registered -- silently stealing
    // `BackgroundLifecycleObserver`'s own native event registration the
    // instant this screen was opened. `Get.find` here (not `Get.put`) keeps
    // this a pure consumer of `AppBinding`'s composition root, matching the
    // "shared singleton, not a fresh instance per screen" pattern this file
    // already uses for `TransportService`/`RoutingEngine`/`StorageManager`
    // above.
    Get.lazyPut(
      () => BatterySettingsController(service: Get.find<BackgroundControl>()),
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
