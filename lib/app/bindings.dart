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
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/features/home/presentation/home_controller.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/welcome/presentation/welcome_controller.dart';

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
    Get.put(messagingStack.sendMessage, permanent: true);
    Get.put(messagingStack.receiveMessage, permanent: true);
    Get.put(messagingStack.syncCursors, permanent: true);
    Get.put(messagingStack.relayEngine, permanent: true);
    Get.put(messagingStack.routingEngine, permanent: true);
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
  }
}
