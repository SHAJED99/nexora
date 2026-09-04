// core/background — E10-T09: proves PowerState round-trips through the
// real generated Pigeon codec (encode/decode included, not an in-Dart
// fake), that `BackgroundService.powerStates` de-duplicates consecutive
// equal states, and that `BackgroundStub`'s `emitPowerState` test lever
// gives `E10-T10` the same contract without a device. Mirrors
// `test/core/background/background_service_test.dart`'s shape (E10-T08).
//
// The reads themselves — `PowerManager.isDeviceIdleMode`,
// `ActivityManager.isBackgroundRestricted`, the four broadcast receivers,
// `RECEIVER_NOT_EXPORTED` — are native (`PowerStateMonitor.kt`) and are
// proven by `flutter build apk --debug` compiling plus the manual steps
// (task §8), not by a mock-Kotlin test that would pass regardless of
// correctness (E04-T03b's standing rule, carried forward by every prior
// E10 test file touching this boundary).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/background/background_service.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/background/generated/background_api.g.dart';
import 'package:nexora/core/background/power_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  PowerState allClear() => allClearPowerState();

  /// Sends a raw `onPowerStateChanged` event through the real generated
  /// codec, exactly as `BackgroundApiHost` would.
  void sendPowerStateEvent(String suffix, PowerState state) {
    final ByteData event = BackgroundEventsApi.pigeonChannelCodec
        .encodeMessage(<Object?>[state])!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.BackgroundEventsApi.onPowerStateChanged.$suffix',
      event,
      (ByteData? _) {},
    );
  }

  group('test_EARS_PLAT_10_state_change_emits', () {
    // EARS-PLAT-10 (FR-PLAT-002, FR-PLAT-003): WHEN the device enters or
    // leaves Doze, Battery Saver, background restriction or screen lock,
    // the system SHALL emit a PowerState reflecting the new value. Proven
    // here per flag: a state that flips exactly one signal from the
    // all-clear baseline reaches `BackgroundService.powerStates` through
    // the real generated codec.
    test('deviceIdle (Doze)', () async {
      const String suffix = 'device_idle';
      final BackgroundService service = BackgroundService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(service.dispose);

      final Future<PowerState> next = service.powerStates.first;
      final PowerState doze = PowerState(
        deviceIdle: true,
        powerSaveMode: false,
        backgroundRestricted: false,
        ignoringBatteryOptimizations: false,
        screenLocked: false,
      );
      sendPowerStateEvent(suffix, doze);

      expect(await next, doze);
    });

    test('powerSaveMode (Battery Saver)', () async {
      const String suffix = 'power_save';
      final BackgroundService service = BackgroundService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(service.dispose);

      final Future<PowerState> next = service.powerStates.first;
      final PowerState batterySaver = PowerState(
        deviceIdle: false,
        powerSaveMode: true,
        backgroundRestricted: false,
        ignoringBatteryOptimizations: false,
        screenLocked: false,
      );
      sendPowerStateEvent(suffix, batterySaver);

      expect(await next, batterySaver);
    });

    test('backgroundRestricted', () async {
      const String suffix = 'background_restricted';
      final BackgroundService service = BackgroundService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(service.dispose);

      final Future<PowerState> next = service.powerStates.first;
      final PowerState restricted = PowerState(
        deviceIdle: false,
        powerSaveMode: false,
        backgroundRestricted: true,
        ignoringBatteryOptimizations: false,
        screenLocked: false,
      );
      sendPowerStateEvent(suffix, restricted);

      expect(await next, restricted);
    });

    test('screenLocked', () async {
      const String suffix = 'screen_locked';
      final BackgroundService service = BackgroundService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(service.dispose);

      final Future<PowerState> next = service.powerStates.first;
      final PowerState locked = PowerState(
        deviceIdle: false,
        powerSaveMode: false,
        backgroundRestricted: false,
        ignoringBatteryOptimizations: false,
        screenLocked: true,
      );
      sendPowerStateEvent(suffix, locked);

      expect(await next, locked);
    });
  });

  test('test_EARS_PLAT_11_duplicate_state_not_reemitted', () async {
    // EARS-PLAT-11 (FR-PLAT-002): equal consecutive states SHALL NOT be
    // re-emitted. Two identical events reach the platform channel (a real
    // SCREEN_ON/SCREEN_OFF-style broadcast storm could produce exactly
    // this); only one item should ever reach `powerStates`.
    const String suffix = 'duplicate';
    final BackgroundService service = BackgroundService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    final List<PowerState> received = <PowerState>[];
    final StreamSubscription<PowerState> sub = service.powerStates.listen(
      received.add,
    );
    addTearDown(sub.cancel);

    final PowerState locked = PowerState(
      deviceIdle: false,
      powerSaveMode: false,
      backgroundRestricted: false,
      ignoringBatteryOptimizations: false,
      screenLocked: true,
    );
    sendPowerStateEvent(suffix, locked);
    sendPowerStateEvent(suffix, locked);
    // Let both handled-message microtasks resolve.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(received, <PowerState>[locked]);
  });

  test('test_EARS_PLAT_11_missing_signal_reads_false', () async {
    // EARS-PLAT-11 (FR-PLAT-002): a signal unavailable on the running API
    // level SHALL be reported as false, never null, and SHALL NOT throw.
    // The API-level branching itself is native (PowerStateMonitor.kt,
    // proven per this file's header); this proves the Dart-side plumbing
    // has no special-case exception path for an all-false snapshot -- the
    // one-shot read resolves cleanly through the real generated codec,
    // exactly as a normal reading would.
    const String suffix = 'missing_signal';
    final BackgroundService service = BackgroundService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    final PowerState allFalse = allClear();
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.BackgroundApi.powerState.$suffix',
      (ByteData? message) async {
        return BackgroundApi.pigeonChannelCodec.encodeMessage(<Object?>[
          allFalse,
        ]);
      },
    );

    final PowerState result = await service.powerState();

    expect(result, allFalse);
    expect(result.deviceIdle, isFalse);
    expect(result.powerSaveMode, isFalse);
    expect(result.backgroundRestricted, isFalse);
    expect(result.ignoringBatteryOptimizations, isFalse);
    expect(result.screenLocked, isFalse);
  });

  test('test_background_stub_emit_power_state_is_observable', () async {
    // Task §5: BackgroundStub.emitPowerState is the lever E10-T10's
    // hardware-free tests depend on.
    final BackgroundStub stub = BackgroundStub();
    addTearDown(stub.dispose);

    expect(await stub.powerState(), allClear());

    final Future<PowerState> next = stub.powerStates.first;
    final PowerState doze = PowerState(
      deviceIdle: true,
      powerSaveMode: false,
      backgroundRestricted: false,
      ignoringBatteryOptimizations: false,
      screenLocked: false,
    );
    stub.emitPowerState(doze);

    expect(await next, doze);
    expect(await stub.powerState(), doze);
  });

  test(
    'test_background_stub_duplicate_power_state_not_reemitted',
    () async {
      // Mirrors EARS-PLAT-11 for the stub: a test built against BackgroundStub
      // must see the same de-duplication contract the real service has.
      final BackgroundStub stub = BackgroundStub();
      addTearDown(stub.dispose);

      final List<PowerState> received = <PowerState>[];
      final StreamSubscription<PowerState> sub = stub.powerStates.listen(
        received.add,
      );
      addTearDown(sub.cancel);

      final PowerState saver = PowerState(
        deviceIdle: false,
        powerSaveMode: true,
        backgroundRestricted: false,
        ignoringBatteryOptimizations: false,
        screenLocked: false,
      );
      stub.emitPowerState(saver);
      stub.emitPowerState(saver);
      await Future<void>.delayed(Duration.zero);

      expect(received, <PowerState>[saver]);
    },
  );
}
