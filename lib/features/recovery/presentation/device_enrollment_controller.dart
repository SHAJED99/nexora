// features/recovery/presentation — GetX controller (ADR-0002), built
// against design/screens/device-enrollment.md (GAP-028).
//
// E12-T03 (FR-RECOVER-001/FR-RECOVER-002): the new device's own waiting
// screen, reached from `LoginController._signIn()` when this account
// already owns other registered devices.
//
// E12-B03 fix (human decision, 2026-09-06): `checkApproval()` used to be a
// `pull()`-then-read-local check against `users/$uid/relationships/*` --
// but `RelationshipSyncService.pull` (since deleted by `E12-B11`) merged
// every remote state through
// `ConflictResolver.resolveTrust` (`FR-MSG-007`, "more restrictive state
// wins"), and an enrolling device has no local relationship row, so
// `resolveTrust(unknown, allowed)` resolved to `unknown` and the approval
// was silently discarded -- `checkApproval()` could never return `true`.
// An enrollment approval is an authorization GRANT from a trusted device
// to a specific new device, not a peer-trust OPINION to reconcile, so
// running it through the conflict resolver was a category error, not a
// wiring bug. `checkApproval()` now reads
// `FirebaseMetadataService.readEnrollmentGrant` directly -- a plain
// existence/value check at the dedicated
// `users/$uid/device_enrollment_grants/$thisDeviceId` node
// (`FirebasePaths.deviceEnrollmentGrant`), never merged through `pull`/
// `ConflictResolver`. This does NOT loosen `ConflictResolver.resolveTrust`
// or `FR-MSG-007` for the general peer-relationship case -- both stay
// exactly as they were.
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
import 'package:nexora/core/services/firebase_metadata_service.dart';

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
  /// passes when it routes here. `firebaseMetadataService` defaults to a
  /// fresh `FirebaseMetadataService` (`E12-B03` fix) — not itself a
  /// registered singleton anywhere in the app, same "resolved lazily,
  /// never touches a live `FirebaseDatabase` until actually used" shape
  /// its own constructor already documents.
  DeviceEnrollmentController({
    String? accountUid,
    String? thisDeviceId,
    FirebaseMetadataService? firebaseMetadataService,
    Duration? pollInterval,
    int? maxPolls,
  })  : _accountUid = accountUid ?? _stringArgument('uid') ?? '',
        _thisDeviceId = thisDeviceId ?? _stringArgument('deviceId') ?? '',
        _firebaseMetadataService =
            firebaseMetadataService ?? FirebaseMetadataService(),
        _pollInterval = pollInterval ?? const Duration(seconds: 4),
        _maxPolls = maxPolls ?? 8;

  final String _accountUid;
  final String _thisDeviceId;
  final FirebaseMetadataService _firebaseMetadataService;
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

  /// The waiting state's own poll/check step (task §5 contract). `E12-B03`
  /// fix: reads `FirebaseMetadataService.readEnrollmentGrant` directly --
  /// the dedicated `users/$uid/device_enrollment_grants/$thisDeviceId` node
  /// -- NEVER through `ConflictResolver.resolveTrust` (nor through the
  /// since-deleted `RelationshipSyncService.pull`, `E12-B11`). A read
  /// failure/timeout is best-effort
  /// by design, same as the read it replaces — it simply reads as "not yet
  /// approved," never a thrown error (task §5 "UI" note: no dedicated
  /// error state).
  Future<bool> checkApproval() async {
    return _firebaseMetadataService.readEnrollmentGrant(
      _accountUid,
      _thisDeviceId,
    );
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
