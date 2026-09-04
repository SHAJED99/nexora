// core/background — E10-T08: proves BackgroundService's facade against the
// real generated Pigeon channels (encode/decode included), not an in-Dart
// fake, plus BackgroundStub's in-memory state-tracking contract. Mirrors
// `test/core/notifications/notification_service_test.dart`'s shape
// deliberately (E10-T01).
//
// The service itself — startForeground, retained-engine survival,
// START_STICKY, the boot receiver — is native (`ForegroundMeshService.kt`,
// `BootReceiver.kt`) and is proven by `flutter build apk --debug` compiling
// plus the manual steps (task §8) — not by a Robolectric/mock-Kotlin test
// that would pass regardless of correctness (E04-T03b's standing rule,
// carried forward by E10-T01's own test file). What this suite proves on
// the Dart side: `start()`/`stop()` round-trip through the real generated
// codec, `stoppedBySystem` events are observable, and `BackgroundStub`'s
// double-start idempotence contract holds for whatever calls E10-T10 will
// make against it.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/background/background_service.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/background/generated/background_api.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('test_EARS_PLAT_7_start_reports_running', () async {
    // EARS-PLAT-7 (FR-PLAT-001, FR-PLAT-003): WHEN BackgroundService.start()
    // succeeds, the system SHALL run a foreground service... The
    // startForeground()/notification/retained-engine half is native and
    // proven per this file's header; this proves the Dart-side contract:
    // start() resolves true through the real generated codec, and a
    // `running` event reaching Dart is observable on the state stream.
    const String suffix = 'start';
    final BackgroundService service = BackgroundService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    bool startServiceCalled = false;
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.BackgroundApi.startService.$suffix',
      (ByteData? message) async {
        startServiceCalled = true;
        return BackgroundApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      },
    );

    final Future<ServiceState> runningFuture = service.state.first;
    final bool started = await service.start();

    final ByteData runningEvent =
        BackgroundEventsApi.pigeonChannelCodec.encodeMessage(
          <Object?>[ServiceState.running],
        )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.BackgroundEventsApi.onServiceStateChanged.$suffix',
      runningEvent,
      (ByteData? _) {},
    );

    expect(startServiceCalled, isTrue);
    expect(started, isTrue);
    expect(await runningFuture, ServiceState.running);
  });

  test('test_EARS_PLAT_9_stop_reports_stopped', () async {
    // EARS-PLAT-9 (FR-PLAT-001): WHEN stop() is called, the system SHALL
    // stop the service and remove the ongoing notification. The native
    // teardown is proven per this file's header; this proves stop() round-
    // trips through the real generated codec without throwing, and that a
    // `stopped` event reaching Dart is observable.
    const String suffix = 'stop';
    final BackgroundService service = BackgroundService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    bool stopServiceCalled = false;
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.BackgroundApi.stopService.$suffix',
      (ByteData? message) async {
        stopServiceCalled = true;
        return BackgroundApi.pigeonChannelCodec.encodeMessage(<Object?>[null]);
      },
    );

    final Future<ServiceState> stoppedFuture = service.state.first;
    await service.stop();

    final ByteData stoppedEvent =
        BackgroundEventsApi.pigeonChannelCodec.encodeMessage(
          <Object?>[ServiceState.stopped],
        )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.BackgroundEventsApi.onServiceStateChanged.$suffix',
      stoppedEvent,
      (ByteData? _) {},
    );

    expect(stopServiceCalled, isTrue);
    expect(await stoppedFuture, ServiceState.stopped);
  });

  test('test_EARS_PLAT_8_stopped_by_system_is_observable', () async {
    // EARS-PLAT-8 (FR-PLAT-002): IF the system terminates the app process,
    // THEN the service SHALL be re-created (START_STICKY, native, proven per
    // this file's header) and SHALL report its state to Dart. This proves
    // E10-T10 has a real signal to react to instead of assuming a kill never
    // happens (task §5): a `stoppedBySystem` event reaching Dart through the
    // real generated codec is observable on the state stream, distinct from
    // a caller-initiated stop.
    const String suffix = 'killed';
    final BackgroundService service = BackgroundService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    final Future<ServiceState> killedFuture = service.state.first;

    final ByteData killedEvent =
        BackgroundEventsApi.pigeonChannelCodec.encodeMessage(
          <Object?>[ServiceState.stoppedBySystem],
        )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.BackgroundEventsApi.onServiceStateChanged.$suffix',
      killedEvent,
      (ByteData? _) {},
    );

    expect(await killedFuture, ServiceState.stoppedBySystem);
  });

  test('test_background_stub_double_start_is_idempotent', () async {
    // Task §6: "Double-start and start-while-stopping are real races; make
    // both idempotent." Proven here against BackgroundStub — the double
    // every downstream (E10-T10) test will use, per this file's header.
    final BackgroundStub stub = BackgroundStub();
    addTearDown(stub.dispose);

    final bool first = await stub.start();
    final bool second = await stub.start();
    final bool third = await stub.start();

    expect(first, isTrue);
    expect(second, isTrue);
    expect(third, isTrue);
    // Only the first call actually "started" anything; the rest observed
    // it was already running and did nothing further.
    expect(stub.startCallCount, 1);
    expect(await stub.isRunning(), isTrue);
  });

  test('test_background_stub_start_returns_false_when_platform_refuses', () async {
    // Mirrors NotificationStub's EARS-PLAT-6 shape: a platform refusal
    // resolves false and never throws.
    final BackgroundStub stub = BackgroundStub(canStart: false);
    addTearDown(stub.dispose);

    final bool result = await stub.start();

    expect(result, isFalse);
    expect(await stub.isRunning(), isFalse);
  });

  test('test_background_stub_stopped_by_system_is_observable', () async {
    final BackgroundStub stub = BackgroundStub();
    addTearDown(stub.dispose);

    await stub.start();
    final Future<ServiceState> killedFuture = stub.state.first;
    stub.simulateStoppedBySystem();

    expect(await killedFuture, ServiceState.stoppedBySystem);
    expect(await stub.isRunning(), isFalse);
  });
}
