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
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/background/background_service.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/background/generated/background_api.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EARS-PLAT-10 — the boot receiver must actually be reachable', () {
    // E10-B01: `android:exported="false"` on a manifest-declared receiver
    // means only components running under this app's own UID may deliver
    // an intent to it. `ACTION_BOOT_COMPLETED` is broadcast by the system
    // server under a DIFFERENT uid, so an unexported BootReceiver never
    // receives it at all -- the whole boot-restart feature (ADR-0007 §S3)
    // is then dead on every device, silently, because nothing in this repo
    // asserted the one manifest attribute the feature actually depends on.
    // This is the only layer this defect is assertable at without a real
    // device (no installable hardware in this environment -- the standing
    // E04 limitation).
    //
    // Deliberately no XML-parsing package: `xml` is only a transitive
    // dependency today (not declared in pubspec.yaml), and adding a new
    // direct dependency is a rule-3 human gate this bug fix's own scope
    // fence does not authorise. A targeted regex extraction of the two
    // `<receiver>`/`<service>` elements by name is sufficient and exact
    // for this manifest's structure.
    late String manifestText;

    setUpAll(() {
      final file = File(
        '${Directory.current.path}/android/app/src/main/AndroidManifest.xml',
      );
      manifestText = file.readAsStringSync();
    });

    String elementFor(String tag, String name) {
      final pattern = RegExp(
        '<$tag\\b[^>]*android:name="${RegExp.escape(name)}"[^>]*'
        '(?:/>|>.*?</$tag>)',
        dotAll: true,
      );
      final match = pattern.firstMatch(manifestText);
      expect(
        match,
        isNotNull,
        reason: 'no <$tag android:name="$name"> element found in the '
            'manifest',
      );
      return match!.group(0)!;
    }

    test(
      'test_EARS_PLAT_10_boot_receiver_is_exported_so_the_system_can_deliver_boot_completed',
      () {
        final receiver = elementFor('receiver', '.background.BootReceiver');
        expect(
          receiver,
          contains('android:exported="true"'),
          reason:
              'BOOT_COMPLETED is broadcast by the system server (a different '
              'uid than this app) -- an exported="false" receiver can never '
              'be delivered this broadcast, making the whole boot-restart '
              'feature (ADR-0007 §S3) unreachable on every device (E10-B01).',
        );
      },
    );

    test(
      'test_EARS_PLAT_10_foreground_service_stays_unexported',
      () {
        // The fix for B01 is scoped to the receiver only -- the service
        // itself must remain unexported, since it is only ever started by
        // this app (either via the Pigeon channel or by BootReceiver
        // itself, both in-process). Exporting it would be a real regression
        // this test exists to catch.
        final service = elementFor(
          'service',
          '.background.ForegroundMeshService',
        );
        expect(service, contains('android:exported="false"'));
      },
    );

    test(
      'test_EARS_PLAT_10_boot_receiver_declares_the_boot_completed_action',
      () {
        final receiver = elementFor('receiver', '.background.BootReceiver');
        expect(
          receiver,
          contains('android.intent.action.BOOT_COMPLETED'),
        );
      },
    );

    test(
      'test_EARS_PLAT_10_receive_boot_completed_permission_is_declared',
      () {
        expect(
          manifestText,
          contains(
            '<uses-permission android:name='
            '"android.permission.RECEIVE_BOOT_COMPLETED" />',
          ),
        );
      },
    );
  });

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
