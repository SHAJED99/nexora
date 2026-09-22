// features/devices/presentation — DevicesController (E02-T02; discovery
// wired in E04-T05).
//
// The discovery tests mock only the *native side* of the TransportApi/
// TransportEventsApi platform-channel boundary, same pattern as
// `test/core/transport/transport_service_test.dart` — a real
// `TransportService` runs against a `TestDefaultBinaryMessenger` with a
// per-test `messageChannelSuffix` so instances don't clobber each other's
// mock handlers.
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AppDatabase db;
  late RelationshipRepository repository;
  late BlockUseCase blockUseCase;
  late DevicesController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RelationshipRepository(db);
    blockUseCase = BlockUseCase(repository);
    controller = DevicesController(repository, blockUseCase);
  });

  tearDown(() => db.close());

  test('test_EARS_DEV_2_block_action_updates_state', () async {
    await repository.upsert('device-1', RelationshipState.unknown);
    await controller.load();
    expect(controller.relationships.single.state, RelationshipState.unknown);

    await controller.block('device-1');

    expect(controller.relationships, hasLength(1));
    expect(controller.relationships.single.deviceId, 'device-1');
    expect(controller.relationships.single.state, RelationshipState.blocked);

    // Persisted, not just held in memory — a re-read confirms the write.
    final persisted = await repository.get('device-1');
    expect(persisted!.state, RelationshipState.blocked);
  });

  test('verify promotes an Unknown relationship to Allowed', () async {
    await repository.upsert('device-2', RelationshipState.unknown);
    await controller.load();

    await controller.verify('device-2');

    expect(controller.relationships.single.state, RelationshipState.allowed);
  });

  test('test_E02_B01_unblock_restores_a_blocked_relationship_to_allowed',
      () async {
    await repository.upsert('device-1', RelationshipState.unknown);
    await repository.upsert('device-3', RelationshipState.trusted);
    await controller.load();

    await controller.block('device-1');
    expect(
      controller.relationships
          .firstWhere((r) => r.deviceId == 'device-1')
          .state,
      RelationshipState.blocked,
    );

    await controller.unblock('device-1');

    expect(
      controller.relationships
          .firstWhere((r) => r.deviceId == 'device-1')
          .state,
      RelationshipState.allowed,
    );
    // A different row is never touched by unblocking device-1.
    expect(
      controller.relationships
          .firstWhere((r) => r.deviceId == 'device-3')
          .state,
      RelationshipState.trusted,
    );

    // Persisted, not just held in memory.
    final persisted = await repository.get('device-1');
    expect(persisted!.state, RelationshipState.allowed);
  });

  test('refresh loads an empty list when no relationships are stored',
      () async {
    await controller.load();
    expect(controller.relationships, isEmpty);
  });

  test(
      'test_E04_B19_localDeviceName_populates_from_getLocalDeviceName_on_init',
      () async {
    const String suffix = 'devices-local-name';
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.TransportApi.getLocalDeviceName.$suffix',
      (ByteData? message) async => TransportApi.pigeonChannelCodec
          .encodeMessage(<Object?>["Ahmed's Phone"]),
    );
    final TransportService transportService = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(transportService.dispose);

    final DevicesController withName = DevicesController(
      repository,
      blockUseCase,
      transportService: transportService,
    );
    // GetxController's onInit() is a GetX lifecycle hook fired by
    // Get.put/Get.find -- a bare constructor call (as every other test in
    // this file does too, calling load() directly rather than relying on
    // constructor-triggered init) never invokes it, so it's called
    // explicitly here. The getLocalDeviceName() future inside is
    // unawaited, so this test pumps the event queue afterward.
    withName.onInit();
    await pumpEventQueue();

    expect(withName.localDeviceName.value, "Ahmed's Phone");
  });

  test('test_E04_B19_localDeviceName_stays_empty_when_the_native_call_fails',
      () async {
    // No mock handler registered for getLocalDeviceName on this suffix --
    // the call fails (no plugin implementation found), and must be
    // swallowed silently rather than crashing the screen.
    const String suffix = 'devices-local-name-unmocked';
    final TransportService transportService = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(transportService.dispose);

    final DevicesController withoutName = DevicesController(
      repository,
      blockUseCase,
      transportService: transportService,
    );
    withoutName.onInit();
    await pumpEventQueue();

    expect(withoutName.localDeviceName.value, isEmpty);
  });

  group('discover()', () {
    /// Builds a `DevicesController` wired to a real `TransportService`
    /// running over `messenger` with a test-unique [suffix], and a mock
    /// handler for `TransportApi.startDiscovery` that always accepts.
    DevicesController buildDiscoveringController(
      String suffix, {
      EvaluateConnectionRequestUseCase? useCase,
    }) {
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.startDiscovery.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.stopDiscovery.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      final TransportService transportService = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(transportService.dispose);
      return DevicesController(
        repository,
        blockUseCase,
        transportService: transportService,
        evaluateConnectionRequestUseCase:
            useCase ?? EvaluateConnectionRequestUseCase(repository),
      );
    }

    void pushDiscoveredDevice(String suffix, TransportDevice device) {
      final ByteData eventMessage =
          TransportEventsApi.pigeonChannelCodec.encodeMessage(
        <Object?>[device],
      )!;
      messenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
        eventMessage,
        (ByteData? _) {},
      );
    }

    test('test_EARS_DEV_3_discover_starts_transport_discovery', () async {
      const String suffix = 'devices-discover-start';
      bool startDiscoveryCalled = false;
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.startDiscovery.$suffix',
        (ByteData? message) async {
          startDiscoveryCalled = true;
          return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[
            null,
          ]);
        },
      );
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.stopDiscovery.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      final TransportService transportService = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(transportService.dispose);
      final DevicesController discovering = DevicesController(
        repository,
        blockUseCase,
        transportService: transportService,
        evaluateConnectionRequestUseCase:
            EvaluateConnectionRequestUseCase(repository),
      );

      discovering.discover();
      // startDiscovery() is awaited on the mocked platform channel; pump
      // the microtask queue so the fire-and-forget future settles.
      await pumpEventQueue();

      expect(startDiscoveryCalled, isTrue);
    });

    // E04-B09: the existing "Discover" button (design/screens/devices.md
    // element 6) now also requests discoverability — proves discover()
    // fires TransportApi.requestDiscoverable, not just startDiscovery.
    test('test_discover_also_requests_discoverable', () async {
      const String suffix = 'devices-discover-requestdiscoverable';
      bool requestDiscoverableCalled = false;
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.requestDiscoverable.$suffix',
        (ByteData? message) async {
          requestDiscoverableCalled = true;
          return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[
            null,
          ]);
        },
      );
      final DevicesController discovering =
          buildDiscoveringController(suffix);

      discovering.discover();
      await pumpEventQueue();

      expect(requestDiscoverableCalled, isTrue);
    });

    test(
        'test_EARS_DEV_4_discovered_device_evaluated_as_unknown_by_default',
        () async {
      const String suffix = 'devices-discover-unknown';
      final DevicesController discovering =
          buildDiscoveringController(suffix);

      discovering.discover();
      await pumpEventQueue();

      pushDiscoveredDevice(
        suffix,
        TransportDevice(
          id: 'nearby-device-1',
          displayName: 'Nearby Phone',
          type: TransportType.bluetooth,
        ),
      );
      // Let the discovery-stream listener's evaluate-and-append future run.
      await pumpEventQueue();

      expect(discovering.relationships, hasLength(1));
      expect(discovering.relationships.single.deviceId, 'nearby-device-1');
      expect(
        discovering.relationships.single.state,
        RelationshipState.unknown,
      );
    });

    test('test_EARS_DEV_5_discovery_alone_grants_no_authorization', () async {
      // FR-DISC-002: "Discovery shall not by itself grant any authorization."
      // `EARS-DEV-4` already proves a discovered device is SURFACED as
      // unknown; this asserts the requirement's actual negative -- that
      // discovery grants nothing and leaves nothing behind. Both halves
      // matter: a persisted row would make a merely-seen device
      // indistinguishable from one the user has decided about, and an
      // evaluation of `allowed`/`trusted` would be authorization granted by
      // proximity alone.
      const String suffix = 'devices-discover-no-authz';
      final DevicesController discovering = buildDiscoveringController(suffix);

      discovering.discover();
      await pumpEventQueue();

      pushDiscoveredDevice(
        suffix,
        TransportDevice(
          id: 'stranger-device-1',
          displayName: 'Stranger Phone',
          type: TransportType.bluetooth,
        ),
      );
      await pumpEventQueue();

      // Nothing persisted -- discovery leaves no authorization record.
      final persisted = await repository.get('stranger-device-1');
      expect(persisted, isNull);

      // And the authorization decision itself refuses to upgrade it.
      final state = await EvaluateConnectionRequestUseCase(repository)
          .call('stranger-device-1');
      expect(state, RelationshipState.unknown);
      expect(state, isNot(RelationshipState.allowed));
      expect(state, isNot(RelationshipState.trusted));
    });

    test('test_discover_deduplicates_repeated_device_events', () async {
      const String suffix = 'devices-discover-dedup';
      final DevicesController discovering =
          buildDiscoveringController(suffix);

      discovering.discover();
      await pumpEventQueue();

      final TransportDevice device = TransportDevice(
        id: 'repeated-device',
        displayName: 'Repeated Phone',
        type: TransportType.bluetooth,
      );
      // Same device id announced across three simulated scan cycles.
      pushDiscoveredDevice(suffix, device);
      pushDiscoveredDevice(suffix, device);
      pushDiscoveredDevice(suffix, device);
      await pumpEventQueue();

      expect(discovering.relationships, hasLength(1));
      expect(discovering.relationships.single.deviceId, 'repeated-device');
    });

    test('test_on_close_stops_discovery', () async {
      const String suffix = 'devices-discover-close';
      bool stopDiscoveryCalled = false;
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.startDiscovery.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.stopDiscovery.$suffix',
        (ByteData? message) async {
          stopDiscoveryCalled = true;
          return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[
            null,
          ]);
        },
      );
      final TransportService transportService = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(transportService.dispose);
      final DevicesController discovering = DevicesController(
        repository,
        blockUseCase,
        transportService: transportService,
        evaluateConnectionRequestUseCase:
            EvaluateConnectionRequestUseCase(repository),
      );

      discovering.discover();
      await pumpEventQueue();

      discovering.onClose();
      await pumpEventQueue();

      expect(stopDiscoveryCalled, isTrue);
    });

    test('test_rediscovery_after_load_readds_unpersisted_device', () async {
      // Review regression (E04-T05): a discovered Unknown device has no
      // Relationship row, so any later `load()` — which block()/verify()
      // both call — wipes it from the displayed list. The de-dup set must
      // therefore guard only the in-flight async gap, not permanently
      // blacklist the id; otherwise the device can never reappear for the
      // rest of the screen's life even though real Bluetooth discovery
      // keeps re-announcing it every scan cycle (§6 risk).
      const String suffix = 'devices-discover-readd';
      final DevicesController discovering =
          buildDiscoveringController(suffix);

      discovering.discover();
      await pumpEventQueue();

      final TransportDevice device = TransportDevice(
        id: 'transient-device',
        displayName: 'Transient Phone',
        type: TransportType.bluetooth,
      );
      pushDiscoveredDevice(suffix, device);
      await pumpEventQueue();
      expect(discovering.relationships, hasLength(1));

      // block()/verify() end in load(), which re-reads only persisted rows.
      await discovering.load();
      expect(discovering.relationships, isEmpty);

      // Next scan cycle re-announces the same device.
      pushDiscoveredDevice(suffix, device);
      await pumpEventQueue();

      expect(discovering.relationships, hasLength(1));
      expect(discovering.relationships.single.deviceId, 'transient-device');
      expect(
        discovering.relationships.single.state,
        RelationshipState.unknown,
      );
    });

    test(
      'test_EARS_ABUSE_4_rate_limited_evaluation_is_not_shown_as_blocked',
      () async {
        // E13-T07: resolves the UI-conflation finding from E13-T02's review
        // -- a rate-limited evaluation must not render with the same
        // "Blocked" badge a genuine `BlockUseCase` block gets.
        const String suffix = 'devices-discover-ratelimited';
        const String deviceId = 'rate-limited-device';
        final limiter = RateLimiter(db);
        // Exhaust the connection-request bucket for this device id BEFORE
        // discovery ever evaluates it (same bucket-key scheme
        // `evaluate_connection_request_use_case.dart` documents:
        // `connection_request:<deviceId>`, max 10/minute).
        for (var i = 0; i < 10; i++) {
          final admitted = await limiter.allow(
            'connection_request:$deviceId',
            maxCount: 10,
            window: const Duration(minutes: 1),
          );
          expect(admitted, isTrue);
        }

        final discovering = buildDiscoveringController(
          suffix,
          useCase: EvaluateConnectionRequestUseCase(
            repository,
            rateLimiter: limiter,
          ),
        );

        discovering.discover();
        await pumpEventQueue();

        pushDiscoveredDevice(
          suffix,
          TransportDevice(
            id: deviceId,
            displayName: 'Rate Limited Phone',
            type: TransportType.bluetooth,
          ),
        );
        await pumpEventQueue();

        expect(
          discovering.relationships,
          isEmpty,
          reason:
              'a rate-limited evaluation must not be surfaced at all, '
              'let alone with the same badge a genuine block gets',
        );
      },
    );
  });
}
