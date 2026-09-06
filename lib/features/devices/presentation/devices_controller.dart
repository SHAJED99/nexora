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
    Future<String?> Function()? thisDeviceId,
  })  : _repository = repository,
        _transportService = transportService ?? TransportService(),
        _evaluateConnectionRequestUseCase = evaluateConnectionRequestUseCase ??
            EvaluateConnectionRequestUseCase(repository),
        _firebaseMetadataService =
            firebaseMetadataService ?? FirebaseMetadataService(),
        _currentAccountUid = currentAccountUid ?? _defaultCurrentAccountUid,
        _thisDeviceId = thisDeviceId ?? _defaultThisDeviceId;

  final RelationshipRepository _repository;
  final BlockUseCase _blockUseCase;
  final TransportService _transportService;
  final EvaluateConnectionRequestUseCase _evaluateConnectionRequestUseCase;
  final FirebaseMetadataService _firebaseMetadataService;
  final Future<String?> Function() _currentAccountUid;

  /// `E12-B02`'s own collaborator: this device's OWN id (the approving
  /// device, not the enrolling one) -- needed as `approvedByDeviceId` when
  /// `verify()` writes a grant record for a pending enrollment. Same
  /// injectable-with-production-default shape as [_currentAccountUid]
  /// (task §5 of `E12-T02`'s own precedent), for the same reason: this
  /// controller's `files:` scope has no constructor path to
  /// `DeviceIdentityRepository` the way `devices_binding.dart` explicitly
  /// wires `TransportService`.
  final Future<String?> Function() _thisDeviceId;

  final RxList<Relationship> relationships = <Relationship>[].obs;

  /// Discovered device ids classified as this account's OWN device
  /// enrolling (E12-T02, `FR-RECOVER-001`) -- rendered at the top of
  /// `devices_view.dart`'s list per `design/screens/
  /// device-enrollment-approval.md`. Disjoint from [relationships]: a
  /// pending enrollment has, by definition, no local relationship row yet
  /// (`_classifyDiscoveredDevice`).
  final RxList<TransportDevice> pendingEnrollments = <TransportDevice>[].obs;

  final RxBool loading = false.obs;

  /// `E12-T01`'s `readOwnDeviceIds` result, fetched at most once per
  /// *discovery cycle* (reset in [discover], E12-B04) and cached here (§3/§6
  /// of the task: "a best-effort hint, not something to re-fetch on every
  /// single discovery event" -- no refresh timer, matching E10's one-tick
  /// discipline; re-resolving on a fresh, user-initiated `discover()` call
  /// is not a timer).
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

  /// Device ids that were classified `normal` by discovery (added to
  /// [relationships] in-memory by `_onDeviceDiscovered`, not loaded from
  /// `RelationshipRepository`) together with the [TransportDevice] payload
  /// that discovered them (E12-B04 round 2, F1).
  ///
  /// Why this exists: `_onDeviceDiscovered`'s own `alreadyShown` guard
  /// short-circuits BEFORE `_classifyDiscoveredDevice` runs again for any id
  /// already present in [relationships] or [pendingEnrollments] -- correctly,
  /// since re-running classification on every re-announced discovery event
  /// (real scans repeat `onDeviceDiscovered` every cycle, per T03b) would be
  /// wasted work for the overwhelming common case where nothing changed.
  /// But that guard is exactly what made the original B04 fix (resetting
  /// [_ownDeviceIdsFuture] alone) inert against B04's OWN repro: a device
  /// discovered once while the own-device-id cache was stale gets classified
  /// `normal` and added to [relationships] as a terminal answer -- from then
  /// on `alreadyShown` is true for it, and no amount of resetting the cache
  /// ever reaches `_classifyDiscoveredDevice` for that id again, however many
  /// times `discover()` is subsequently called.
  ///
  /// Tracking these ids (and only these -- never an id `load()` populated
  /// from a real persisted relationship, since that means this side already
  /// evaluated the device on purpose and must not be silently reclassified)
  /// lets [discover] explicitly re-run classification for them once the
  /// own-device-id cache updates, moving a device into [pendingEnrollments]
  /// if it now matches. Cleared whenever [load] replaces [relationships]
  /// wholesale (an in-memory discovery-only entry does not survive a real
  /// reload anyway -- see `_evaluatingIds`'s own doc comment on the same
  /// point) and whenever a tracked id is reclassified or otherwise removed
  /// from [relationships] (`block`/`verify`).
  final Map<String, TransportDevice> _discoveredNormalDevices =
      <String, TransportDevice>{};

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Re-reads every stored relationship from `RelationshipRepository`.
  Future<void> load() async {
    loading.value = true;
    relationships.value = await _repository.listAll();
    // Every entry now in `relationships` came from the repository, not from
    // an in-memory discovery classification -- the discovery-only rows this
    // tracks did not survive the replace above (E12-B04 round 2, F1's own
    // doc comment on `_discoveredNormalDevices`).
    _discoveredNormalDevices.clear();
    loading.value = false;
  }

  /// Kebab menu's "Block" action (FR-BLOCK-001) — the design contract's
  /// generic `more_vert` button, element 12/20/28/36.
  ///
  /// `E12-B09` fix: also deletes any device-enrollment grant this account
  /// may have previously issued for [deviceId]
  /// (`FirebaseMetadataService.deleteEnrollmentGrant`) -- without this, a
  /// device approved via `verify()` and later blocked/denied keeps its
  /// stale grant node forever, and the enrolling device's own
  /// `checkApproval()` never learns the approval was reversed (`E12-B09`'s
  /// own repro). Deliberately unconditional on [deviceId] currently being a
  /// pending enrollment (unlike `verify()`'s `wasPendingEnrollment` gate):
  /// by the time a previously-approved device is blocked, `verify()` has
  /// already removed it from [pendingEnrollments] (EARS-RECOVER-7), so that
  /// signal is gone by the time `block()` runs. A delete for a [deviceId]
  /// with no grant node at all (the overwhelmingly common "Block" of an
  /// ordinary stranger) is a harmless no-op --
  /// `FirebaseMetadataService.deleteEnrollmentGrant`'s own doc comment.
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
    final String? uid = await _currentAccountUid();
    // Best-effort, same degraded-case framing as `verify()`'s own mirror
    // call: an unknown uid (not signed in yet, or the repository lookup
    // fails) simply skips the delete -- the local block is still recorded
    // either way, never blocked on this.
    if (uid != null) {
      await _firebaseMetadataService.deleteEnrollmentGrant(uid, deviceId);
    }
  }

  /// "Verify" button (element 31, Unknown rows only) — promotes an Unknown
  /// relationship to Allowed. The richer trust-config flow FR-TRUST-006
  /// would otherwise gate is not built yet; this is the minimal safe
  /// transition the design contract shows (task §3).
  ///
  /// `E12-B02` fix: when [deviceId] is a pending ENROLLMENT request (not an
  /// ordinary stranger's `Unknown`/`Verify` row), this ALSO mirrors the
  /// approval to Firebase via `FirebaseMetadataService.writeEnrollmentGrant`
  /// -- the dedicated channel `E12-B03`'s human decision names (a new
  /// path, never merged through `RelationshipSyncService.pull`/
  /// `ConflictResolver`). Gated on `wasPendingEnrollment`, captured BEFORE
  /// the local upsert/removal below, because an ordinary `Verify` of a
  /// stranger has no enrollment to grant -- writing a grant record for a
  /// non-enrolling peer would be a category error, the same one `E12-B03`
  /// itself diagnoses for `ConflictResolver`. Deliberately does NOT call
  /// `RelationshipSyncService.push` or touch `users/$uid/relationships/*`
  /// -- that channel is unrelated and unchanged (`E12-B02`'s own "does not
  /// change push's own implementation or path" fence).
  Future<void> verify(String deviceId) async {
    final bool wasPendingEnrollment =
        pendingEnrollments.any((d) => d.id == deviceId);
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
    if (wasPendingEnrollment) {
      final String? uid = await _currentAccountUid();
      final String? myDeviceId = await _thisDeviceId();
      // Best-effort, same degraded-case framing as `readOwnDeviceIds`
      // (task §6 risk): an unknown uid/own-device-id (not signed in yet,
      // or the repository lookup fails) simply skips the mirror -- local
      // trust is still recorded either way, never blocked on this.
      if (uid != null && myDeviceId != null) {
        await _firebaseMetadataService.writeEnrollmentGrant(
          uid,
          deviceId,
          myDeviceId,
        );
      }
    }
  }

  /// "Discover" button (element 6) — starts real nearby-device discovery
  /// (FR-DISC-001) via `TransportService`, replacing the E02-T02 no-op
  /// stub. Newly-seen device ids not already shown are evaluated through
  /// E02's `EvaluateConnectionRequestUseCase` (defaults to Unknown for a
  /// never-seen device, FR-UI-004) and appended to the displayed list —
  /// additive to, never replacing, what `load()` already populated.
  void discover() {
    // E12-B04: re-resolve this discovery cycle's own-device-id read rather
    // than reusing whatever settled during a previous cycle. The natural
    // enrollment order is "open Devices, tap Discover, *then* sign in the
    // new device" -- a future cached across `discover()` calls would still
    // reflect the registry from the moment of the FIRST tap, permanently
    // misclassifying a device that registered afterwards as an ordinary
    // stranger. Cheap and user-initiated (task's own suggested direction),
    // not a polling timer: nothing refetches unless the user taps Discover
    // again. Concurrent discovery events WITHIN one cycle still share the
    // single future this assignment starts -- only cross-cycle reuse is
    // removed, preserving the in-flight de-dup the cache exists for (see
    // `_ownDeviceIdsFuture`'s own doc comment).
    _ownDeviceIdsFuture = null;
    // E12-B04 round 2, F1: resetting the cache above is necessary but not
    // sufficient -- a device already sitting in `relationships` as a
    // discovery-classified `normal` stranger is never re-offered to
    // `_classifyDiscoveredDevice` by `_onDeviceDiscovered` itself (its
    // `alreadyShown` guard short-circuits first). Explicitly re-evaluate
    // every such tracked device now, against the freshly-reset cache, so a
    // second Discover tap actually surfaces a device that registered after
    // the first tap classified it as an ordinary stranger. Unawaited: this
    // is user-initiated re-classification of already-visible rows, not
    // something the caller needs to block on (same shape as
    // `startDiscovery` below).
    unawaited(_reevaluateDiscoveredNormalDevices());
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
      // E12-B04 round 2, F1: tracked so a LATER `discover()` call (once the
      // own-device-id cache has had a chance to update) can re-run
      // classification for this id -- this row is an in-memory discovery
      // classification, not a persisted relationship, so it is still
      // eligible to turn out to be a pending enrollment after all.
      _discoveredNormalDevices[device.id] = device;
    } finally {
      // Always released, including on a failed evaluation — otherwise a
      // single repository error would blacklist the id for the rest of the
      // screen's life.
      _evaluatingIds.remove(device.id);
    }
  }

  /// E12-B04 round 2, F1: re-runs classification for every device currently
  /// tracked in [_discoveredNormalDevices] against whatever own-device-id
  /// cache is current at the moment this is called (freshly reset by
  /// [discover] just before this is invoked). A device that now turns out to
  /// be a pending enrollment moves from [relationships] into
  /// [pendingEnrollments]; one still not present in the current own-device
  /// set stays exactly as it was.
  ///
  /// Iterates a snapshot (`.entries.toList()`), not the live map, since
  /// [relationships]/[_discoveredNormalDevices] are mutated inside the loop.
  /// Skips an id currently in [_evaluatingIds] -- a fresh discovery event for
  /// the SAME id is already mid-classification via `_onDeviceDiscovered`,
  /// and running a second classification concurrently would race the two
  /// outcomes against each other for no benefit (the in-flight one will
  /// settle on its own next scan-cycle guard).
  Future<void> _reevaluateDiscoveredNormalDevices() async {
    for (final entry in _discoveredNormalDevices.entries.toList()) {
      final String deviceId = entry.key;
      if (_evaluatingIds.contains(deviceId)) continue;
      final _DeviceClassification classification =
          await _classifyDiscoveredDevice(deviceId);
      if (classification != _DeviceClassification.pendingEnrollment) {
        continue;
      }
      // Re-check: `load()` or a concurrent discovery event may have already
      // resolved this id one way or another while classification was in
      // flight above.
      if (pendingEnrollments.any((d) => d.id == deviceId)) {
        _discoveredNormalDevices.remove(deviceId);
        continue;
      }
      if (!_discoveredNormalDevices.containsKey(deviceId)) continue;
      relationships.removeWhere((r) => r.deviceId == deviceId);
      pendingEnrollments.add(entry.value);
      _discoveredNormalDevices.remove(deviceId);
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

  /// Default [_thisDeviceId]: same singleton lookup as
  /// [_defaultCurrentAccountUid], reading [DeviceIdentity.deviceId] instead
  /// of `accountUid` -- this is the APPROVING device's own id, `E12-B02`'s
  /// `approvedByDeviceId`. Never throws, for the same reason.
  static Future<String?> _defaultThisDeviceId() async {
    try {
      final identity =
          await Get.find<DeviceIdentityRepository>().latestDeviceIdentity();
      return identity?.deviceId;
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
