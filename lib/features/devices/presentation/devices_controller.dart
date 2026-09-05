// features/devices/presentation — DevicesController (E02-T02, discovery
// wired in E04-T05).
//
// Built against design/screens/devices.md. `discover()` now starts real
// nearby-device discovery via `TransportService` (T03a/T03b) instead of the
// "not available yet" snackbar stub (design/gaps.md GAP-004) — the screen's
// layout/elements are unchanged, only what powers the "Discover" action.
import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// `E12-T02` (`FR-RECOVER-001`) -- the one new decision `_classifyDiscoveredDevice`
/// adds ahead of `EvaluateConnectionRequestUseCase`'s own unrelated
/// evaluation: is this discovered device id a stranger (`normal`, handled
/// exactly as before this task), or this account's OWN device enrolling
/// (`pendingEnrollment`)?
enum _DeviceClassification { pendingEnrollment, normal }

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
    FirebaseMetadataService? firebaseMetadataService,
    Future<String?> Function()? currentAccountUid,
  })  : _repository = repository,
        _transportService = transportService ?? TransportService(),
        _evaluateConnectionRequestUseCase = evaluateConnectionRequestUseCase ??
            EvaluateConnectionRequestUseCase(repository),
        _firebaseMetadataService =
            firebaseMetadataService ?? FirebaseMetadataService(),
        _currentAccountUid = currentAccountUid ?? _defaultCurrentAccountUid;

  final RelationshipRepository _repository;
  final BlockUseCase _blockUseCase;
  final TransportService _transportService;
  final EvaluateConnectionRequestUseCase _evaluateConnectionRequestUseCase;
  final FirebaseMetadataService _firebaseMetadataService;
  final Future<String?> Function() _currentAccountUid;

  final RxList<Relationship> relationships = <Relationship>[].obs;

  /// Discovered device ids classified as this account's OWN device
  /// enrolling (E12-T02, `FR-RECOVER-001`) -- rendered at the top of
  /// `devices_view.dart`'s list per `design/screens/
  /// device-enrollment-approval.md`. Disjoint from [relationships]: a
  /// pending enrollment has, by definition, no local relationship row yet
  /// (`_classifyDiscoveredDevice`).
  final RxList<TransportDevice> pendingEnrollments = <TransportDevice>[].obs;

  final RxBool loading = false.obs;

  /// `E12-T01`'s `readOwnDeviceIds` result, fetched at most once per this
  /// controller's lifetime and cached here (§3/§6 of the task: "a
  /// best-effort hint, not something to re-fetch on every single discovery
  /// event" -- no refresh timer, matching E10's one-tick discipline).
  ///
  /// Deliberately a cached **Future**, not a cached value: `discover()`
  /// commonly announces several devices back-to-back (real Bluetooth scans
  /// report a batch), so multiple `_onDeviceDiscovered` calls can reach
  /// [_ownDeviceIds] concurrently. Caching only the resolved value would
  /// leave a window -- between checking "is it cached yet" and awaiting
  /// [_currentAccountUid]/[FirebaseMetadataService.readOwnDeviceIds] -- in
  /// which every one of those concurrent callers sees no cache and starts
  /// its own fetch (regression test:
  /// `readOwnDeviceIds is fetched at most once per controller lifetime`).
  /// Caching the in-flight Future itself closes that window: every caller
  /// gets the one shared future, however many started before it settled.
  Future<Set<String>>? _ownDeviceIdsFuture;

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
    // EARS-RECOVER-7: `Deny` (a pending-enrollment row's trailing button)
    // calls this SAME existing method -- a pending request that gets
    // blocked simply disappears (`device-enrollment-approval.md`'s
    // `pending` state notes), same as any other row `block()` removes.
    // A no-op for a deviceId not currently pending (every other caller,
    // e.g. the kebab menu's "Block").
    pendingEnrollments.removeWhere((d) => d.id == deviceId);
    await load();
  }

  /// "Verify" button (element 31, Unknown rows only) — promotes an Unknown
  /// relationship to Allowed. The richer trust-config flow FR-TRUST-006
  /// would otherwise gate is not built yet; this is the minimal safe
  /// transition the design contract shows (task §3).
  Future<void> verify(String deviceId) async {
    await _repository.upsert(deviceId, RelationshipState.allowed);
    // EARS-RECOVER-7: `Approve` (a pending-enrollment row's trailing
    // button) calls this SAME existing method -- once trust is recorded,
    // the device reappears through `load()` as a normal Allowed row
    // (`device-enrollment-approval.md`'s `pending` state notes: "approved
    // requests become a normal established-device row ... no new row shape
    // for that"), so it must leave [pendingEnrollments] here or it would
    // render twice. A no-op for a deviceId not currently pending (every
    // other caller of `verify`).
    pendingEnrollments.removeWhere((d) => d.id == deviceId);
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
        relationships.any((r) => r.deviceId == device.id) ||
            pendingEnrollments.any((d) => d.id == device.id);
    if (alreadyShown || _evaluatingIds.contains(device.id)) return;
    _evaluatingIds.add(device.id);

    try {
      // E12-T02: the one new decision point ahead of the existing
      // `EvaluateConnectionRequestUseCase` evaluation -- EARS-RECOVER-5/6.
      final _DeviceClassification classification =
          await _classifyDiscoveredDevice(device.id);
      // Re-check: `load()` may have replaced the list, or another
      // discovery event for the same id may have settled, while
      // classification was in flight.
      if (relationships.any((r) => r.deviceId == device.id) ||
          pendingEnrollments.any((d) => d.id == device.id)) {
        return;
      }
      if (classification == _DeviceClassification.pendingEnrollment) {
        pendingEnrollments.add(device);
        return;
      }
      final RelationshipState state =
          await _evaluateConnectionRequestUseCase(device.id);
      // Re-check again: the evaluation above is its own async gap.
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

  /// EARS-RECOVER-5/6 (`FR-RECOVER-001`). [deviceId] is this account's OWN
  /// device enrolling -- not an unknown stranger -- exactly when it is
  /// present in `E12-T01`'s `readOwnDeviceIds` result AND has no local
  /// relationship entry yet. Every other case (not in that set, task §2's
  /// "unrelated peer"; or already evaluated locally, e.g. re-discovered
  /// after being blocked) classifies as `normal`: unchanged from this
  /// task's pre-existing behaviour.
  Future<_DeviceClassification> _classifyDiscoveredDevice(
    String deviceId,
  ) async {
    final Set<String> ownDeviceIds = await _ownDeviceIds();
    if (!ownDeviceIds.contains(deviceId)) {
      return _DeviceClassification.normal;
    }
    final existing = await _repository.get(deviceId);
    if (existing != null) return _DeviceClassification.normal;
    return _DeviceClassification.pendingEnrollment;
  }

  /// `E12-T01`'s `readOwnDeviceIds`, fetched once and cached in
  /// [_ownDeviceIdsFuture] (see its own doc comment). A `null` uid (no
  /// signed-in account known yet, §6 risk: the caller may not be signed in
  /// at the exact moment discovery starts) reads as "no own devices known"
  /// -- the same best-effort degraded case `readOwnDeviceIds` itself
  /// documents for a flaky/offline read, never a thrown error.
  Future<Set<String>> _ownDeviceIds() {
    return _ownDeviceIdsFuture ??= () async {
      final String? uid = await _currentAccountUid();
      return uid == null
          ? const <String>{}
          : await _firebaseMetadataService.readOwnDeviceIds(uid);
    }();
  }

  /// Default [_currentAccountUid]: resolves the app-wide permanent
  /// `DeviceIdentityRepository` singleton (`app/bindings.dart`) via GetX's
  /// locator, since this controller's own `files:` scope (this file + its
  /// view only, task §5) has no constructor path to it the way
  /// `devices_binding.dart` explicitly wires `TransportService` -- same
  /// "resolved lazily, only touched when actually needed" shape as
  /// `FirebaseMetadataService._database`/`GoogleAuthService._firebaseAuth`.
  /// Never throws: an unregistered repository (e.g. a test constructing
  /// `DevicesController` directly without overriding this parameter) or no
  /// signed-in identity yet both read as "uid unknown" -- degraded, not
  /// fatal, matching this whole feature's best-effort framing (task §6).
  static Future<String?> _defaultCurrentAccountUid() async {
    try {
      final identity =
          await Get.find<DeviceIdentityRepository>().latestDeviceIdentity();
      return identity?.accountUid;
    } catch (_) {
      return null;
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
