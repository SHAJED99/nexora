// test/design/probe_settings_battery_test.dart -- E15-T08's own fenced
// probe dump for `design/screens/settings-battery.md`
// (`make design-probe` / `make design-verify SCREEN=settings-battery`).
//
// Deliberately its OWN file, not `test/design/design_probe_test.dart` --
// that file is `E15-T11`'s alone (task §4; E08's own recorded collision
// warning: "T09 must not be given the probe fixture… T08 now owns that
// file"). `E15-T11` consolidates every sub-screen's own probe into the
// shared runner once all eight land.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/background/power_state.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_controller.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_view.dart';

import 'flutter_probe_dumper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen probe — settings-battery (make design-probe)', () {
    late BackgroundStub service;
    late BatterySettingsController controller;

    setUp(() async {
      Get.testMode = true;
      service = BackgroundStub();
      // A real, non-empty `default` state (task §5): service running, one
      // restriction on (Doze), the other two off -- never the
      // `loading`/`empty` treatment.
      await service.start();
      service.emitPowerState(
        PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: true,
          screenLocked: false,
        ),
      );
      controller = BatterySettingsController(service: service);
      Get.put<BatterySettingsController>(controller);
      // Same reasoning `probe_settings_network_test.dart`'s header
      // documents: awaited HERE, in `setUp`, not inside `testWidgets`
      // below, since `pumpEventQueue` does not reliably resolve inside a
      // `testWidgets` body's fake-async zone.
      await pumpEventQueue();
    });

    // `Get.reset()` runs here, NOT inside `testWidgets` below -- same
    // documented gotcha every other E15 probe file's header notes.
    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    testWidgets('settings-battery', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings-battery',
        screen: const GetMaterialApp(home: BatterySettingsView()),
      );

      // E12-B05, F4: a real dart:io read, through `runAsync`.
      final raw = await tester.runAsync(
        () => File('build/design-probe/settings-battery.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}
