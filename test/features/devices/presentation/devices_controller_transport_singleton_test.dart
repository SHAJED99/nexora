// Regression test for E06-B02: DevicesController's fallback
// `TransportService()` silently steals the native Pigeon transport
// channels from `MessagingStack`'s shared `TransportService` the moment
// `DevicesController` is constructed.
//
// This exercises the REAL production wiring path -- `DevicesBinding`, not a
// hand-built `DevicesController(..., transportService: someMock)` -- because
// the bug lives in the binding, not the controller: `DevicesController`
// keeps its `transportService ?? TransportService()` fallback for test
// convenience, and only `DevicesBinding` proves whether that fallback ever
// actually fires in the app.
//
// Mirrors real app startup-then-navigation ordering (task file's own
// prescription): `MessagingStack` is built first (as `main.dart` builds it,
// before `runApp`), then `DevicesController` is constructed second (as
// `DevicesBinding` builds it lazily, only on first navigation to
// `/devices`). On the pre-fix code, that ordering lets
// `DevicesController`'s fallback `TransportService()` construct a second
// live instance that calls `TransportEventsApi.setUp` again -- replacing,
// not adding to, `MessagingStack`'s handler on the same (default, empty
// suffix) channel names, exactly as production does. This test proves an
// event delivered on the (mocked) `onDataReceived` channel still reaches
// `MessagingStack`'s own `TransportService.incomingData(...)` stream even
// after `DevicesController` has been constructed.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/devices/presentation/devices_binding.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test(
    'test_E06_B02_shared_transport_service_survives_devices_controller_construction',
    () async {
      // 1. Startup ordering: `MessagingStack` (and the single, unsuffixed
      //    `TransportService` it owns) is built first, exactly as
      //    `main.dart` builds it before `runApp`. No `messageChannelSuffix`
      //    is passed -- production never passes one either, so this test
      //    exercises the exact channel names the real app collides on.
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final MessagingStack stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-a',
        transport: TransportService(binaryMessenger: messenger),
      );
      addTearDown(stack.dispose);
      expect(stack.status, const MessagingStackStatus.ready());

      // Mirrors the subset of `AppBinding.dependencies()` that
      // `DevicesBinding` actually resolves from -- `RelationshipRepository`/
      // `BlockUseCase` (already-established permanent-registration pattern)
      // plus, per this task's fix, `stack.transport` itself.
      final RelationshipRepository repository = RelationshipRepository(db);
      Get.put<RelationshipRepository>(repository, permanent: true);
      Get.put<BlockUseCase>(BlockUseCase(repository), permanent: true);
      Get.put<TransportService>(stack.transport, permanent: true);

      // Subscribe to the shared instance's own stream BEFORE constructing
      // DevicesController, so the assertion below can tell whether this
      // exact stream ever gets fed -- not just whether *some*
      // `TransportService` received the event.
      final List<Uint8List> receivedByStack = <Uint8List>[];
      final subscription =
          stack.transport.incomingData('peer-1').listen(receivedByStack.add);
      addTearDown(subscription.cancel);

      // 2. Navigation ordering: `DevicesController` is constructed second,
      //    through the real `DevicesBinding` -- the same lazyPut GetX runs
      //    the first time the user opens `/devices`.
      DevicesBinding().dependencies();
      final DevicesController controller = Get.find<DevicesController>();
      addTearDown(controller.onClose);
      // Constructing DevicesController must not have thrown even though
      // this is the production binding path (proves `Get.find` resolved).
      expect(controller, isNotNull);

      // 3. Fire a real inbound-data event on the exact (default, unsuffixed)
      //    native channel name both the pre-fix fallback instance and the
      //    real, shared instance would be listening on.
      final Uint8List payload = Uint8List.fromList(<int>[1, 2, 3]);
      final ByteData? eventMessage =
          TransportEventsApi.pigeonChannelCodec.encodeMessage(
        <Object?>['peer-1', payload],
      );
      await messenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived',
        eventMessage,
        (ByteData? _) {},
      );

      // 4. The shared instance -- the one `MessagingStack`'s inbound
      //    pipeline/coordinator/link-quality feed all consume -- must still
      //    be the one that received the event. On the pre-fix code, a
      //    second live `TransportService` (DevicesController's fallback)
      //    would have replaced this handler and this list stays empty.
      expect(
        receivedByStack,
        <Uint8List>[payload],
        reason:
            'the event must reach MessagingStack\'s shared TransportService '
            'even after DevicesController has been constructed -- if this '
            'list is empty, DevicesController silently stole the native '
            'transport-event channel handler (E06-B02)',
      );
    },
  );
}
