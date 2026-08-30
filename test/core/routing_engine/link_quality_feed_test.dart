// test/core/routing_engine/link_quality_feed_test.dart — E06-T04.
//
// Proves the producer/consumer loop closes: a real `onLinkQuality` Pigeon
// event -> TransportService.linkQuality -> LinkQualityFeed ->
// RoutingEngine.recordLinkMeasurement. Fakes only the native side of the
// platform-channel boundary (matching
// test/core/transport/transport_service_test.dart's own pattern) — the
// native Kotlin producers (BluetoothTransport.kt/LoopbackTransport.kt) have
// no Dart-testable path; see this task's Run log for exactly which lines
// rest on review and reasoning alone rather than hardware verification.
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';

/// Test-only subclass so a test can prove idempotent `start()` (§8's
/// `test_link_quality_feed_start_is_idempotent`) and the exact
/// `batteryDrain` value passed (`test_no_default_battery_drain_is_invented`)
/// without a mocking framework — `RoutingEngine` is a plain, unsealed class
/// with an overridable public method, so overriding it here is the minimal
/// seam.
class _RecordingRoutingEngine extends RoutingEngine {
  _RecordingRoutingEngine({required super.selfId});

  int recordCalls = 0;
  double? lastBatteryDrain;

  @override
  void recordLinkMeasurement(
    String neighborId, {
    required int latencyMs,
    required double lossRate,
    required double batteryDrain,
    String? from,
  }) {
    recordCalls++;
    lastBatteryDrain = batteryDrain;
    super.recordLinkMeasurement(
      neighborId,
      latencyMs: latencyMs,
      lossRate: lossRate,
      batteryDrain: batteryDrain,
      from: from,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Pushes a fake native `onLinkQuality` event through the real generated
  /// codec, exactly as a Kotlin transport would.
  void pushLinkQuality(
    String suffix,
    String deviceId,
    int latencyMs,
    double lossRate,
  ) {
    final ByteData eventMessage =
        TransportEventsApi.pigeonChannelCodec.encodeMessage(
      <Object?>[deviceId, latencyMs, lossRate],
    )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onLinkQuality.$suffix',
      eventMessage,
      (ByteData? _) {},
    );
  }

  test('test_EARS_ROUTE_10_measurement_reaches_the_routing_engine', () async {
    const String suffix = 'route10';
    final TransportService transport = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(transport.dispose);
    final _RecordingRoutingEngine routing =
        _RecordingRoutingEngine(selfId: 'self');
    final LinkQualityFeed feed =
        LinkQualityFeed(transport: transport, routing: routing);
    feed.start();
    addTearDown(feed.stop);

    pushLinkQuality(suffix, 'neighbor-1', 42, 0.1);
    await Future<void>.delayed(Duration.zero);

    expect(routing.recordCalls, 1);
    final Route? route =
        routing.computeRoute('neighbor-1', TrafficProfile.interactive);
    expect(route, isNotNull);
    expect(route!.hops, <String>['neighbor-1']);
  });

  test('test_EARS_ROUTE_11_route_is_computable_after_a_measurement', () async {
    const String suffix = 'route11';
    final TransportService transport = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(transport.dispose);
    final RoutingEngine routing = RoutingEngine(selfId: 'self');
    final LinkQualityFeed feed =
        LinkQualityFeed(transport: transport, routing: routing);
    addTearDown(feed.stop);

    // This is the regression assertion for E04-B03: on `development` @
    // `35710f7` (no LinkQualityFeed, no wiring) this must fail because
    // `computeRoute` returns `null` unconditionally and never flips.
    expect(
      routing.computeRoute('neighbor-1', TrafficProfile.interactive),
      isNull,
    );

    feed.start();
    pushLinkQuality(suffix, 'neighbor-1', 30, 0.0);
    await Future<void>.delayed(Duration.zero);

    expect(
      routing.computeRoute('neighbor-1', TrafficProfile.interactive),
      isNotNull,
    );
  });

  test(
      'test_EARS_ROUTE_12_out_of_range_measurements_are_rejected',
      () async {
    const String suffix = 'route12';
    final TransportService transport = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(transport.dispose);
    final RoutingEngine routing = RoutingEngine(selfId: 'self');
    final LinkQualityFeed feed =
        LinkQualityFeed(transport: transport, routing: routing);
    feed.start();
    addTearDown(feed.stop);

    // No exception must escape the feed for any of these.
    expect(() {
      pushLinkQuality(suffix, 'bad-loss-negative', 10, -0.1);
      pushLinkQuality(suffix, 'bad-loss-over-one', 10, 1.5);
      pushLinkQuality(suffix, 'bad-latency-negative', -5, 0.1);
    }, returnsNormally);
    await Future<void>.delayed(Duration.zero);

    expect(
      routing.computeRoute('bad-loss-negative', TrafficProfile.interactive),
      isNull,
    );
    expect(
      routing.computeRoute('bad-loss-over-one', TrafficProfile.interactive),
      isNull,
    );
    expect(
      routing.computeRoute(
          'bad-latency-negative', TrafficProfile.interactive),
      isNull,
    );
  });

  test('test_link_quality_feed_start_is_idempotent', () async {
    const String suffix = 'idempotent';
    final TransportService transport = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(transport.dispose);
    final _RecordingRoutingEngine routing =
        _RecordingRoutingEngine(selfId: 'self');
    final LinkQualityFeed feed =
        LinkQualityFeed(transport: transport, routing: routing);

    feed.start();
    feed.start(); // second call must be a no-op, not a second subscription
    addTearDown(feed.stop);

    pushLinkQuality(suffix, 'neighbor-1', 15, 0.0);
    await Future<void>.delayed(Duration.zero);

    expect(routing.recordCalls, 1);
  });

  test('test_no_default_battery_drain_is_invented', () async {
    const String suffix = 'battery';
    final TransportService transport = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(transport.dispose);
    final _RecordingRoutingEngine routing =
        _RecordingRoutingEngine(selfId: 'self');
    final LinkQualityFeed feed =
        LinkQualityFeed(transport: transport, routing: routing);
    feed.start();
    addTearDown(feed.stop);

    pushLinkQuality(suffix, 'neighbor-1', 10, 0.0);
    await Future<void>.delayed(Duration.zero);

    expect(routing.recordCalls, 1);
    expect(
      routing.lastBatteryDrain,
      LinkQualityFeed.kUnmeasuredBatteryDrainNeutral,
    );
  });
}
