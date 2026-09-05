// features/recovery/presentation — GetX controller (ADR-0002), built
// against design/screens/device-enrollment.md (GAP-028).
//
// E12-T03 (FR-RECOVER-001/FR-RECOVER-002): the new device's own waiting
// screen, reached from `LoginController._signIn()` when this account
// already owns other registered devices. It has no new wire mechanism of
// its own — `checkApproval()` is a thin read-only consumer of two
// collaborators E11/E12 already built:
//   - `RelationshipSyncService.pull(uid)` (E11-T05) reconciles
//     `users/$uid/relationships/*` (written by a trusted device's own
//     `push`, E12-T02) into this device's LOCAL `relationships` table.
//   - `RelationshipRepository.get(thisDeviceId)` (E02-T01) then reads that
//     merged local state back for THIS device's own id — which is exactly
//     the entry a trusted device's `push(uid, thisDeviceId, state)` would
//     have written, once pulled.
//
// Polling discipline (task §6 Risks, E08-T06/E10-T08's one-tick precedent):
// a single bounded-interval `Timer.periodic`, started in `onInit`, stopped
// the instant approval is detected, a bounded number of unanswered polls
// elapses (-> `denied`, matching the design contract's own "or the request
// timed out with no device reachable" wording — no explicit deny signal
// exists in this task's own scope, so a bounded timeout is the only way
// `denied` is ever reached), "Continue without history" is tapped, or the
// controller is disposed. Never left running past any of those.
import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/core/services/relationship_sync_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// The three states `design/screens/device-enrollment.md` requires.
enum EnrollmentState { waiting, denied, noRecoveryNotice }

class DeviceEnrollmentController extends GetxController {
  /// Every collaborator is an optional named parameter with a production
  /// default, mirroring `LoginController`'s own reasoning: this route is
  /// registered with an inline `BindingsBuilder` (`app/routes.dart`, not a
  /// dedicated `DeviceEnrollmentBinding` file — outside this task's
  /// `files:` fence), so the constructor itself must be able to resolve
  /// every dependency with no explicit argument passed at the call site.
  ///
  /// `accountUid`/`thisDeviceId` default to `Get.arguments` (a `Map` with
  /// `'uid'`/`'deviceId'` keys) — exactly what `LoginController._signIn()`
  /// passes when it routes here. `relationshipRepository` defaults to the
  /// app-wide permanent `RelationshipRepository` singleton
  /// (`AppBinding.dependencies()`, `Get.find` — safe for the same reason
  /// `LoginController`'s own `DeviceIdentityRepository` default is: a
  /// lookup, never a second construction). `relationshipSyncService`
  /// defaults to a fresh `RelationshipSyncService` wired to that same
  /// repository — this service is not itself a registered singleton
  /// anywhere in the app.
  DeviceEnrollmentController({
    String? accountUid,
    String? thisDeviceId,
    RelationshipRepository? relationshipRepository,
    RelationshipSyncService? relationshipSyncService,
    Duration? pollInterval,
    int? maxPolls,
  })  : _accountUid = accountUid ?? _stringArgument('uid') ?? '',
        _thisDeviceId = thisDeviceId ?? _stringArgument('deviceId') ?? '',
        _relationshipRepository =
            relationshipRepository ?? Get.find<RelationshipRepository>(),
        _relationshipSyncService = relationshipSyncService ??
            RelationshipSyncService(
              repository:
                  relationshipRepository ?? Get.find<RelationshipRepository>(),
            ),
        _pollInterval = pollInterval ?? const Duration(seconds: 4),
        _maxPolls = maxPolls ?? 8;

  final String _accountUid;
  final String _thisDeviceId;
  final RelationshipRepository _relationshipRepository;
  final RelationshipSyncService _relationshipSyncService;
  final Duration _pollInterval;
  final int _maxPolls;

  /// Reads a `String` value out of `Get.arguments` by key, or `null` if
  /// `Get.arguments` is not a `Map`, has no such key, or the value is not a
  /// `String`. Static (not an instance method) so it can run inside this
  /// class's own constructor initializer list.
  static String? _stringArgument(String key) {
    final args = Get.arguments;
    if (args is Map && args[key] is String) return args[key] as String;
    return null;
  }

  final Rx<EnrollmentState> state = EnrollmentState.waiting.obs;

  Timer? _timer;
  int _pollCount = 0;

  @override
  void onInit() {
    super.onInit();
    _startPolling();
  }

  void _startPolling() {
    _pollCount = 0;
    unawaited(_poll());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    // Already left `waiting` (approved mid-flight, timed out, or the user
    // tapped "Continue without history") — a tick that fires after that,
    // before `_stopPolling` gets to cancel it, must be a no-op.
    if (state.value != EnrollmentState.waiting) return;
    _pollCount++;
    final approved = await checkApproval();
    if (state.value != EnrollmentState.waiting) return;
    if (approved) {
      _stopPolling();
      Get.offNamed('/dashboard');
      return;
    }
    if (_pollCount >= _maxPolls) {
      _stopPolling();
      state.value = EnrollmentState.denied;
    }
  }

  /// The waiting state's own poll/check step (task §5 contract). Pulls
  /// remote relationship state for this account, then checks whether THIS
  /// device's own local relationship has become trusted/allowed. A `pull()`
  /// failure (offline, timeout) is best-effort by design — it simply leaves
  /// the local state untouched, so this reads as "not yet approved," never
  /// a thrown error (task §5 "UI" note: no dedicated error state).
  Future<bool> checkApproval() async {
    await _relationshipSyncService.pull(_accountUid);
    final relationship = await _relationshipRepository.get(_thisDeviceId);
    final peerState = relationship?.state;
    return peerState == RelationshipState.trusted ||
        peerState == RelationshipState.allowed;
  }

  /// "Continue without history" (`waiting`/`denied`) — EARS-RECOVER-11.
  /// Reachable from the very first frame (the view never gates this button
  /// on any poll/timeout state), and always stops polling: there is nothing
  /// left to wait for once the user has chosen to proceed without it.
  void continueWithoutHistory() {
    _stopPolling();
    state.value = EnrollmentState.noRecoveryNotice;
  }

  /// `no-recovery-notice`'s own "Continue" button.
  void continueToDashboard() {
    Get.offNamed('/dashboard');
  }

  @override
  void onClose() {
    _stopPolling();
    super.onClose();
  }
}
