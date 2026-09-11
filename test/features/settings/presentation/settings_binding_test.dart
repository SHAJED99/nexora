// features/settings/presentation — E15-B03 regression.
//
// `AppBinding` (`lib/app/bindings.dart`) registers a single, permanent
// `BackgroundControl` singleton alongside `BackgroundLifecycleObserver`.
// Before this fix, `SettingsBinding`'s `BatterySettingsController`
// registration constructed a SECOND, independent `BackgroundService()` —
// and since `BackgroundService`'s constructor calls
// `BackgroundEventsApi.setUp(...)` on the same default platform channel
// every time, Pigeon's generated `setUp` would unconditionally replace
// `BackgroundLifecycleObserver`'s own handler the instant Settings ->
// Battery was opened, with no crash and no log.
//
// This test proves `BatterySettingsController`, resolved through the REAL
// `SettingsBinding` (not constructed directly, as
// `battery_settings_controller_test.dart` does for its own unit-level
// coverage), receives the EXACT SAME `BackgroundControl` instance
// `AppBinding` already registered — before AND after the lazy factory that
// backs "navigating to Settings -> Battery" actually runs.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/app/bindings.dart';
import 'package:nexora/core/background/background_service.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_controller.dart';
import 'package:nexora/features/settings/presentation/settings_binding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test(
    'test_E15_B03_battery_settings_controller_resolves_the_same_'
    'BackgroundControl_AppBinding_registered_for_the_lifecycle_observer',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final transport = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'settings-binding-b03-${suffixCounter++}',
      );
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'self-device-b03',
        transport: transport,
      );
      addTearDown(stack.dispose);
      addTearDown(stack.coordinator.stop);

      // A stub, not a real `BackgroundService` -- this test proves the
      // sharing wiring, not the platform channel itself
      // (`background_service_test.dart`'s own job).
      final backgroundControl = BackgroundStub();

      // Mirrors production `main.dart` -> `AppBinding` wiring: this is the
      // ONE place a `BackgroundControl` is constructed and registered.
      AppBinding(
        db: db,
        messagingStack: stack,
        backgroundControl: backgroundControl,
      ).dependencies();

      // Mirrors production route wiring: `SettingsBinding` is the shared
      // per-route binding for every `/settings*` route.
      SettingsBinding().dependencies();

      // BEFORE "navigating to Settings -> Battery": AppBinding's own
      // registration is the one and only `BackgroundControl` singleton.
      final beforeNavigation = Get.find<BackgroundControl>();
      expect(identical(beforeNavigation, backgroundControl), isTrue);

      // "Navigating to Settings -> Battery": `Get.lazyPut`'s factory for
      // `BatterySettingsController` runs for the first time HERE, not at
      // binding time -- this is the exact moment the pre-fix code
      // constructed a second `BackgroundService()`.
      final batteryController = Get.find<BatterySettingsController>();

      // The regression itself: `BatterySettingsController` must be handed
      // the SAME instance, not a fresh, independently-constructed one.
      expect(identical(batteryController.service, backgroundControl), isTrue);

      // AFTER "navigating": the shared singleton AppBinding registered is
      // still the one and only instance -- nothing replaced it.
      final afterNavigation = Get.find<BackgroundControl>();
      expect(identical(afterNavigation, backgroundControl), isTrue);
      expect(identical(afterNavigation, beforeNavigation), isTrue);
    },
  );
}
