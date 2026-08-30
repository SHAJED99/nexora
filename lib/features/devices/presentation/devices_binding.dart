// features/devices/presentation — per-route GetX binding (E02-T02).
//
// `RelationshipRepository`/`BlockUseCase` are registered as permanent
// singletons in `app/bindings.dart` (shared across the trust feature);
// this binding only owns the screen's own controller, per
// `docs/conventions.md` "Project structure".
//
// E06-B02: `TransportService` is ALSO one of those shared, permanent
// singletons (`app/bindings.dart` -- `Get.put(messagingStack.transport,
// permanent: true)`, registered before this binding ever runs, since it's
// part of `AppBinding.dependencies()` executed at app startup while this
// binding is a route `Bindings` only instantiated on first navigation to
// `/devices`). This binding MUST inject that exact instance into
// `DevicesController` -- never leave `transportService` unset, which would
// let `DevicesController`'s constructor fall back to constructing its own
// `TransportService()` and silently steal the native Pigeon transport
// channels (`onDeviceDiscovered`/`onDeviceLost`/`onConnectionStateChanged`/
// `onDataReceived`/`onLinkQuality`) away from `MessagingStack`'s instance --
// a platform channel has exactly one Dart-side handler per channel name, so
// a second live `TransportService` doesn't add a listener, it replaces one.
import 'package:get/get.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';

class DevicesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => DevicesController(
        Get.find<RelationshipRepository>(),
        Get.find<BlockUseCase>(),
        transportService: Get.find<TransportService>(),
      ),
    );
  }
}
