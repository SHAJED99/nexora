// features/settings/network/presentation -- NetworkSettingsController
// (E15-T08). Real `TransportService` + real `RoutingEngine` throughout,
// driven the same way `dashboard_controller_test.dart` already drives
// `TransportService` -- injecting real Pigeon events through the test
// binary messenger, never a mocked promise of one (task §8's own falsifying
// test list). `_ErroringDiscoveryTransportService`, `_ThrowingRoutingEngine`
// and `_CountingRoutingEngine` below are the seams `EARS-UI-11`'s
// independence claim (and `EARS-ROUTE-13`'s no-polling claim) need -- an
// overridden getter/method or a call counter, never `fail()` inside an
// injected seam (a broad catch in the controller would swallow it,
// L-testing).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Route;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  late TransportService transport;
  late RoutingEngine routing;
  late String suffix;
  late NetworkSettingsController controller;

  setUp(() {
    suffix = 'network-settings-${suffixCounter++}';
    transport = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    routing = RoutingEngine(selfId: 'self-device');
    controller = NetworkSettingsController(transport: transport, routing: routing);
  });

  tearDown(() {
    controller.onClose();
  });

  void pushDeviceDiscovered(
    String id, {
    TransportType type = TransportType.bluetooth,
    String? channelSuffix,
  }) {
    final device = TransportDevice(id: id, displayName: id, type: type);
    final eventMessage =
        TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.'
      '${channelSuffix ?? suffix}',
      eventMessage,
      (ByteData? _) {},
    );
  }

  void pushDeviceLost(String id, {String? channelSuffix}) {
    final eventMessage =
        TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[id])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceLost.'
      '${channelSuffix ?? suffix}',
      eventMessage,
      (ByteData? _) {},
    );
  }

  void pushLinkQuality(
    String deviceId,
    int latencyMs,
    double lossRate, {
    String? channelSuffix,
  }) {
    final eventMessage = TransportEventsApi.pigeonChannelCodec.encodeMessage(
      <Object?>[deviceId, latencyMs, lossRate],
    )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onLinkQuality.'
      '${channelSuffix ?? suffix}',
      eventMessage,
      (ByteData? _) {},
    );
  }

  /// Makes [peerId] an active direct route in [routing] -- `setActiveRoute`
  /// is what `activeRouteFor` reads (task §6 risk note); `computeRoute`
  /// alone never populates it.
  void makeDirectRouteActive(String peerId) {
    routing.recordLinkMeasurement(
      peerId,
      latencyMs: 1,
      lossRate: 0.0,
      batteryDrain: 0.0,
    );
    final route = routing.computeRoute(peerId, TrafficProfile.interactive)!;
    routing.setActiveRoute(route);
  }

  test('test_EARS_ROUTE_13_unmeasured_link_renders_not_measured_not_zero', () async {
    // The falsification test for this task: a route with no DIRECT
    // measurement must render as `NotMeasuredLink`, never
    // `MeasuredLink(latencyMs: 0, ...)`. Seeded two hops away (a relay +
    // destination) -- multi-hop routes have no aggregate measurement
    // anywhere in this build (controller file header): only a direct
    // neighbor's `linkQuality` ever produces a `MeasuredLink`.
    controller.onInit();
    routing.recordLinkMeasurement(
      'relay-1',
      latencyMs: 5,
      lossRate: 0.0,
      batteryDrain: 0.0,
    );
    routing.recordLinkMeasurement(
      'dest-1',
      latencyMs: 5,
      lossRate: 0.0,
      batteryDrain: 0.0,
      from: 'relay-1',
    );
    final route = routing.computeRoute('dest-1', TrafficProfile.interactive)!;
    routing.setActiveRoute(route);
    // The controller only learns a destination id exists via a
    // `linkQuality` event naming it (file header). This one deliberately
    // names `dest-1` itself -- proving that even when SOME quality data
    // exists for that exact id, a 2-hop route still renders unmeasured,
    // because [NetworkSettingsController] only trusts a measurement for a
    // route whose `hopCount == 1` (a real direct neighbor). A weaker test
    // that never pushed any quality data for `dest-1` would pass even if
    // the hop-count guard were deleted entirely -- this one does not.
    pushLinkQuality('dest-1', 999, 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.routes.length, 1);
    final summary = controller.routes.single;
    expect(summary.hopCount, 2);
    expect(summary.measurement, isA<NotMeasuredLink>());
  });

  test('test_EARS_ROUTE_13_single_hop_renders_direct', () async {
    controller.onInit();
    makeDirectRouteActive('neighbor-1');
    pushLinkQuality('neighbor-1', 42, 0.1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.routes.length, 1);
    final summary = controller.routes.single;
    expect(summary.hopCount, 1);
    expect(summary.measurement, isA<MeasuredLink>());
    expect((summary.measurement as MeasuredLink).latencyMs, 42);
  });

  test(
    'test_EARS_UI_11_transport_read_failure_leaves_the_routes_card_rendered',
    () async {
      final erroringTransport = _ErroringDiscoveryTransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'network-settings-erroring-${suffixCounter++}',
      );
      final erroringController = NetworkSettingsController(
        transport: erroringTransport,
        routing: routing,
      );
      erroringController.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(erroringController.transportsError.value, isTrue);

      // The Routes card is driven by a DIFFERENT stream on the SAME
      // transport instance (`linkQuality`, not `discoveredDevices`) --
      // proving it is untouched is the whole point of this test.
      makeDirectRouteActive('neighbor-1');
      final eventMessage = TransportEventsApi.pigeonChannelCodec.encodeMessage(
        <Object?>['neighbor-1', 10, 0.0],
      )!;
      messenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.TransportEventsApi.onLinkQuality.'
        'network-settings-erroring-${suffixCounter - 1}',
        eventMessage,
        (ByteData? _) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(erroringController.routesError.value, isFalse);
      expect(erroringController.routes.length, 1);

      erroringController.onClose();
    },
  );

  test(
    'test_EARS_UI_11_route_computation_failure_leaves_the_transports_card_rendered',
    () async {
      // The symmetric direction: `activeRouteFor` throwing must not touch
      // the Transports card, which never calls into `routing` at all.
      final throwingRouting = _ThrowingRoutingEngine(selfId: 'self-device');
      final erroringController = NetworkSettingsController(
        transport: transport,
        routing: throwingRouting,
      );
      erroringController.onInit();

      pushDeviceDiscovered('neighbor-1');
      pushLinkQuality('neighbor-1', 10, 0.0);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(erroringController.routesError.value, isTrue);
      expect(erroringController.transportsError.value, isFalse);
      expect(erroringController.transports.single.available, isTrue);

      erroringController.onClose();
    },
  );

  test('test_EARS_ROUTE_14_transports_become_unavailable_once_lost', () async {
    controller.onInit();
    pushDeviceDiscovered('neighbor-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.transports.single.available, isTrue);

    pushDeviceLost('neighbor-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.transports.length, 1);
    expect(controller.transports.single.available, isFalse);
  });

  test(
    'test_EARS_ROUTE_13_no_polling_timer_is_started',
    () async {
      // A call counter on `activeRouteFor` over a pumped duration with NO
      // new events pushed -- if a `Timer.periodic` were re-running
      // `_recomputeRoutes` on its own, this count would keep growing.
      final countingRouting = _CountingRoutingEngine(selfId: 'self-device');
      final counterController = NetworkSettingsController(
        transport: transport,
        routing: countingRouting,
      );
      counterController.onInit();

      countingRouting.recordLinkMeasurement(
        'neighbor-1',
        latencyMs: 1,
        lossRate: 0.0,
        batteryDrain: 0.0,
      );
      final route =
          countingRouting.computeRoute('neighbor-1', TrafficProfile.interactive)!;
      countingRouting.setActiveRoute(route);
      pushLinkQuality('neighbor-1', 1, 0.0);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final afterFirstLoad = countingRouting.activeRouteForCalls;
      expect(afterFirstLoad, greaterThan(0));

      // No new device/link-quality event over a real, pumped span of
      // wall-clock time.
      await Future<void>.delayed(const Duration(seconds: 1));

      expect(
        countingRouting.activeRouteForCalls,
        afterFirstLoad,
        reason: 'EARS-ROUTE-13/NFR-BATT-001: this screen must bind to real '
            'events, never poll on a timer',
      );

      counterController.onClose();
    },
  );

  testWidgets('test_EARS_ROUTE_14_no_control_is_rendered', (tester) async {
    Get.testMode = true;
    final viewController =
        NetworkSettingsController(transport: transport, routing: routing);
    Get.put<NetworkSettingsController>(viewController);
    makeDirectRouteActive('neighbor-1');
    pushDeviceDiscovered('neighbor-1');
    pushLinkQuality('neighbor-1', 12, 0.0);

    await tester.pumpWidget(const GetMaterialApp(home: NetworkSettingsView()));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(find.text('Network'), findsOneWidget);
    // EARS-ROUTE-14: no button, switch or tappable row anywhere on either
    // card. `SettingsSubScreenScaffold`'s own back affordance is the one
    // `InkWell` this screen composes but does not own (task §3's shared
    // shell) -- excluded here the same way the Battery screen's own
    // equivalent test excludes it.
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(InkWell), findsOneWidget); // the shell's own back affordance, only

    viewController.onClose();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    Get.reset();
  });
}

/// Overrides ONLY `discoveredDevices`, so `lostDevices`/`linkQuality` on the
/// SAME instance stay real and functional -- the seam
/// `test_EARS_UI_11_transport_read_failure_leaves_the_routes_card_rendered`
/// needs to prove the two cards fail independently.
class _ErroringDiscoveryTransportService extends TransportService {
  _ErroringDiscoveryTransportService({
    required super.binaryMessenger,
    required super.messageChannelSuffix,
  });

  @override
  Stream<TransportDevice> get discoveredDevices =>
      Stream<TransportDevice>.error(StateError('simulated read failure'));
}

/// A `RoutingEngine` whose `activeRouteFor` always throws -- the Routes
/// card's own failure seam, independent of any `TransportService` stream.
class _ThrowingRoutingEngine extends RoutingEngine {
  _ThrowingRoutingEngine({required super.selfId});

  @override
  Route? activeRouteFor(String destinationId) {
    throw StateError('simulated routing failure');
  }
}

/// Counts `activeRouteFor` calls -- the falsification seam
/// `test_EARS_ROUTE_13_no_polling_timer_is_started` needs (never `fail()`
/// inside the seam -- L-testing).
class _CountingRoutingEngine extends RoutingEngine {
  _CountingRoutingEngine({required super.selfId});

  int activeRouteForCalls = 0;

  @override
  Route? activeRouteFor(String destinationId) {
    activeRouteForCalls++;
    return super.activeRouteFor(destinationId);
  }
}
