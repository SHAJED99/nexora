// features/devices/presentation — DevicesController (E02-T02, discovery
// wired in E04-T05).
//
// Built against design/screens/devices.md. `discover()` now starts real
// nearby-device discovery via `TransportService` (T03a/T03b) instead of the
// "not available yet" snackbar stub (design/gaps.md GAP-004) — the screen's
// layout/elements are unchanged, only what powers the "Discover" action.
import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

class DevicesController extends GetxController {
  /// [transportService] and [evaluateConnectionRequestUseCase] are optional
  /// named parameters, defaulting to real production instances, so tests can
  /// inject a `TransportService` wired to a mock platform channel (same
  /// pattern as `test/core/transport/transport_service_test.dart`) or a
  /// stub `EvaluateConnectionRequestUseCase` without needing a full DI
  /// container.
  ///
  /// E06-B02: the `transportService ?? TransportService()` fallback below
  /// must never actually construct a second instance in the running app --
  /// `TransportService`'s constructor claims the app's native Pigeon
  /// transport-event channels (`TransportEventsApi.setUp`), and a platform
  /// channel has exactly one Dart-side handler per channel name, so a
  /// second live instance silently replaces `MessagingStack`'s handler
  /// registration instead of adding to it, detaching the entire messaging
  /// stack from native transport events with no error. `DevicesBinding`
  /// (`devices_binding.dart`) always supplies the app-wide shared instance
  /// (`Get.find<TransportService>()`, registered permanently in
  /// `app/bindings.dart` from `messagingStack.transport`), so this fallback
  /// only ever fires for a `DevicesController` built directly in a test,
  /// never through the app's real navigation/binding path. See
  /// `test/features/devices/presentation/devices_controller_transport_singleton_test.dart`
  /// for the regression proof.
  DevicesController(
    RelationshipRepository repository,
    this._blockUseCase, {
    TransportService? transportService,
    EvaluateConnectionRequestUseCase? evaluateConnectionRequestUseCase,
  })  : _repository = repository,
        _transportService = transportService ?? TransportService(),
        _evaluateConnectionRequestUseCase = evaluateConnectionRequestUseCase ??
            EvaluateConnectionRequestUseCase(repository);

  final RelationshipRepository _repository;
  final BlockUseCase _blockUseCase;
  final TransportService _transportService;
  final EvaluateConnectionRequestUseCase _evaluateConnectionRequestUseCase;

  final RxList<Relationship> relationships = <Relationship>[].obs;
  final RxBool loading = false.obs;

  StreamSubscription<TransportDevice>? _discoverySubscription;

  /// Device ids whose evaluation is currently **in flight** — guards the
  /// async gap between a discovery event and
  /// `EvaluateConnectionRequestUseCase` resolving, so a device re-announced
  /// mid-evaluation (real Bluetooth discovery repeats `onDeviceDiscovered`
  /// across scan cycles, per T03b) is not evaluated/added twice (§6 risk).
  ///
  /// An id is removed once its evaluation settles: steady-state de-dup is
  /// the `relationships` membership check, not this set. Keeping ids here
  /// permanently would blacklist them — a discovered Unknown device has no
  /// `Relationship` row, so the next `load()` (which `block()`/`verify()`
  /// both call) drops it from the list, and it could then never reappear
  /// despite discovery re-announcing it every scan cycle. Review fix,
  /// E04-T05; regression test
  /// `test_rediscovery_after_load_readds_unpersisted_device`.
  final Set<String> _evaluatingIds = <String>{};

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Re-reads every stored relationship from `RelationshipRepository`.
  Future<void> load() async {
    loading.value = true;
    relationships.value = await _repository.listAll();
    loading.value = false;
  }

  /// Kebab menu's "Block" action (FR-BLOCK-001) — the design contract's
  /// generic `more_vert` button, element 12/20/28/36.
  Future<void> block(String deviceId) async {
    await _blockUseCase(deviceId);
    await load();
  }

  /// "Verify" button (element 31, Unknown rows only) — promotes an Unknown
  /// relationship to Allowed. The richer trust-config flow FR-TRUST-006
  /// would otherwise gate is not built yet; this is the minimal safe
  /// transition the design contract shows (task §3).
  Future<void> verify(String deviceId) async {
    await _repository.upsert(deviceId, RelationshipState.allowed);
    await load();
  }

  /// "Discover" button (element 6) — starts real nearby-device discovery
  /// (FR-DISC-001) via `TransportService`, replacing the E02-T02 no-op
  /// stub. Newly-seen device ids not already shown are evaluated through
  /// E02's `EvaluateConnectionRequestUseCase` (defaults to Unknown for a
  /// never-seen device, FR-UI-004) and appended to the displayed list —
  /// additive to, never replacing, what `load()` already populated.
  void discover() {
    _discoverySubscription ??=
        _transportService.discoveredDevices.listen(_onDeviceDiscovered);
    unawaited(
      _transportService.startDiscovery().catchError((Object _) {
        // §6 risk: a permission denial (or any start failure) must surface
        // as something the user understands, not a silently empty list
        // forever. No dedicated error affordance exists in the design
        // contract (design/gaps.md GAP-004 already covers this button's
        // behavior) — reusing the same SnackBar primitive the E02-T02 stub
        // used is the closest existing pattern, not a new UI element.
        Get.snackbar(
          'Discover',
          'Could not start device discovery.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }),
    );
  }

  Future<void> _onDeviceDiscovered(TransportDevice device) async {
    final bool alreadyShown =
        relationships.any((r) => r.deviceId == device.id);
    if (alreadyShown || _evaluatingIds.contains(device.id)) return;
    _evaluatingIds.add(device.id);

    try {
      final RelationshipState state =
          await _evaluateConnectionRequestUseCase(device.id);
      // Re-check: `load()` may have replaced the list while the evaluation
      // was in flight and could already have brought this device back in.
      if (relationships.any((r) => r.deviceId == device.id)) return;
      relationships.add(
        Relationship(
          deviceId: device.id,
          state: state,
          updatedAt: DateTime.now(),
        ),
      );
    } finally {
      // Always released, including on a failed evaluation — otherwise a
      // single repository error would blacklist the id for the rest of the
      // screen's life.
      _evaluatingIds.remove(device.id);
    }
  }

  @override
  void onClose() {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    unawaited(
      // A native `stopDiscovery` can fail (Bluetooth switched off or the
      // permission revoked mid-session, per T03b). Swallow it here: the
      // controller is being torn down, there is no UI left to surface it
      // on, and an unhandled async error out of `onClose` would surface as
      // an app-level zone error instead.
      _transportService.stopDiscovery().catchError((Object _) {}),
    );
    super.onClose();
  }
}
