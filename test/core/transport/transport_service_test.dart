// core/transport — E04-T03a: proves TransportService's facade against the
// real generated Pigeon channels (encode/decode included), not an in-Dart
// fake. Each test mocks only the *native side* of the platform-channel
// boundary — the host-API reply and, where relevant, a simulated
// native-to-Dart event push — exactly the seam a real Kotlin implementation
// (loopback here, real Bluetooth in T03b/T03c) sits behind. The actual
// loopback echo-with-delay behavior lives in native Kotlin
// (`LoopbackTransport.kt`) and is proven by the on-device manual smoke test
// per the task's §7/§8, since a Dart unit test has no way to run real
// Kotlin code.
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('test_EARS_TRANSPORT_1_loopback_roundtrip', () async {
    // EARS-TRANSPORT-1 (FR-PLAT-003): TransportService.send() over the
    // loopback implementation SHALL result in the same bytes appearing on
    // incomingData for that device id.
    const String suffix = 'roundtrip';
    final TransportService service = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    const String deviceId = 'loopback-device-1';
    final Uint8List sentBytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    // Simulates the native TransportApi.send handler: accepts the send,
    // then — mirroring LoopbackTransport.kt's real, delayed
    // Handler.postDelayed echo — pushes onDataReceived back for the same
    // device id after a short delay, through the real generated codec.
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.send.$suffix',
      (ByteData? message) async {
        final List<Object?> args =
            TransportApi.pigeonChannelCodec.decodeMessage(message)!
                as List<Object?>;
        final String gotDeviceId = args[0]! as String;
        final Uint8List gotBytes = args[1]! as Uint8List;

        Future<void>.delayed(const Duration(milliseconds: 20), () {
          final ByteData eventMessage =
              TransportEventsApi.pigeonChannelCodec.encodeMessage(
            <Object?>[gotDeviceId, gotBytes],
          )!;
          messenger.handlePlatformMessage(
            'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$suffix',
            eventMessage,
            (ByteData? _) {},
          );
        });

        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );

    final Future<Uint8List> receivedFuture =
        service.incomingData(deviceId).first;

    final bool sent = await service.send(deviceId, sentBytes);
    expect(sent, isTrue);

    final Uint8List received = await receivedFuture;
    expect(received, sentBytes);
  });

  test('test_EARS_TRANSPORT_2_discovery_stream_emits_devices', () async {
    // EARS-TRANSPORT-2 (FR-DISC-001): TransportService.discoveredDevices
    // SHALL emit a device when the native layer calls onDeviceDiscovered.
    const String suffix = 'discovery';
    final TransportService service = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    final Future<TransportDevice> discoveredFuture =
        service.discoveredDevices.first;

    final TransportDevice device = TransportDevice(
      id: 'discovered-device-1',
      displayName: 'Nearby Phone',
      type: TransportType.bluetooth,
    );
    final ByteData eventMessage =
        TransportEventsApi.pigeonChannelCodec.encodeMessage(
      <Object?>[device],
    )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
      eventMessage,
      (ByteData? _) {},
    );

    final TransportDevice discovered = await discoveredFuture;
    expect(discovered.id, device.id);
    expect(discovered.displayName, device.displayName);
    expect(discovered.type, TransportType.bluetooth);
  });

  // Regression test added at review (E04-T03a, reviewer). The task's §6 risk
  // note requires the facade to await the eventual onConnectionStateChanged
  // without assuming a synchronous accept. The first implementation
  // subscribed to the state stream only *after* awaiting the host reply, so
  // a transport that settled before the reply was delivered — an
  // already-connected peer, a cached link, a fast failure — lost the event
  // and connect() never completed. Loopback's 50ms postDelayed hid it; real
  // Bluetooth (T03b) would not.
  test('test_connect_settles_when_state_event_precedes_host_reply', () async {
    const String suffix = 'connectfast';
    final TransportService service = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    const String deviceId = 'fast-settling-device';

    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.connect.$suffix',
      (ByteData? message) async {
        // Native pushes the settled state before returning the accept reply.
        messenger.handlePlatformMessage(
          'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
          TransportEventsApi.pigeonChannelCodec.encodeMessage(
            <Object?>[deviceId, ConnectionState.connected],
          )!,
          (ByteData? _) {},
        );
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );

    final bool connected = await service.connect(deviceId).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError(
            'connect() never completed — state event was missed',
          ),
        );
    expect(connected, isTrue);
  });

  test('test_connect_returns_false_when_native_reports_failed', () async {
    const String suffix = 'connectfail';
    final TransportService service = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    const String deviceId = 'failing-device';

    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.connect.$suffix',
      (ByteData? message) async {
        Future<void>.delayed(const Duration(milliseconds: 20), () {
          messenger.handlePlatformMessage(
            'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
            TransportEventsApi.pigeonChannelCodec.encodeMessage(
              <Object?>[deviceId, ConnectionState.failed],
            )!,
            (ByteData? _) {},
          );
        });
        return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );

    final bool connected = await service.connect(deviceId).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError('connect() never completed'),
        );
    expect(connected, isFalse);
  });
}
