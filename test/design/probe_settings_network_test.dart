// test/design/probe_settings_network_test.dart -- E15-T08's own fenced
// probe dump for `design/screens/settings-network.md`
// (`make design-probe` / `make design-verify SCREEN=settings-network`).
//
// Deliberately its OWN file, not `test/design/design_probe_test.dart` --
// that file is `E15-T11`'s alone (task §4; E08's own recorded collision
// warning: "T09 must not be given the probe fixture… T08 now owns that
// file"). `E15-T11` consolidates every sub-screen's own probe into the
// shared runner once all eight land.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart'
    show TrafficProfile;
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart'
    show TransportEventsApi;
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/settings/network/presentation/network_settings_controller.dart';
import 'package:nexora/features/settings/network/presentation/network_settings_view.dart';

import 'flutter_probe_dumper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('screen probe — settings-network (make design-probe)', () {
    late TransportService transport;
    late RoutingEngine routing;
    late NetworkSettingsController controller;

    setUp(() async {
      Get.testMode = true;
      transport = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'settings-network-probe',
      );
      routing = RoutingEngine(selfId: 'self-device');
      controller = NetworkSettingsController(transport: transport, routing: routing);
      Get.put<NetworkSettingsController>(controller);

      // A real, non-empty `default` state (task §5): one available
      // transport, one direct route with a real measurement -- never the
      // `loading`/`empty` treatment.
      final device = TransportDevice(
        id: 'neighbor-1',
        displayName: 'neighbor-1',
        type: TransportType.bluetooth,
      );
      messenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.'
        'settings-network-probe',
        TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!,
        (ByteData? _) {},
      );
      routing.recordLinkMeasurement(
        'neighbor-1',
        latencyMs: 38,
        lossRate: 0.02,
        batteryDrain: 0.0,
      );
      final route =
          routing.computeRoute('neighbor-1', TrafficProfile.interactive)!;
      routing.setActiveRoute(route);
      messenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.TransportEventsApi.onLinkQuality.'
        'settings-network-probe',
        TransportEventsApi.pigeonChannelCodec.encodeMessage(
          <Object?>['neighbor-1', 38, 0.02],
        )!,
        (ByteData? _) {},
      );
      // Lets both pushed Pigeon events above actually land before the
      // first frame is dumped -- `dumpScreenProbe`'s own bounded
      // `pumpAndSettle` can return as soon as no FRAME is pending, which is
      // not the same as "every outstanding stream event has been
      // delivered" (same reasoning `probe_settings_privacy_test.dart`'s
      // own header documents for its Future-based reads). Awaited HERE, in
      // `setUp`, not inside `testWidgets` below -- `pumpEventQueue`'s
      // `Future.delayed(Duration.zero)` chain does not reliably resolve
      // inside a `testWidgets` body's fake-async zone (same file's own
      // documented gotcha).
      await pumpEventQueue();
    });

    // `Get.reset()` runs here, NOT inside `testWidgets` below -- mirrors
    // every other T04-T07 probe file's own documented gotcha
    // (`flutter_probe_dumper.dart`'s header) for real dart:io/native async
    // completions inside a pumped test body.
    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    testWidgets('settings-network', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings-network',
        screen: const GetMaterialApp(home: NetworkSettingsView()),
      );

      // E12-B05, F4: a real dart:io read, through `runAsync` -- without
      // this, a future regression that silently brings back
      // `renderError: true` would still say "All tests passed" here.
      final raw = await tester.runAsync(
        () => File('build/design-probe/settings-network.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}
