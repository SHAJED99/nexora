// features/login/domain — business logic between controller and
// repository (ADR-0002's `use_case.dart` seam — headless-testable without a
// device or a real UI).
//
// E01-T01: replaces the genesis walking skeleton's `Future.delayed` stub
// with a real Google Sign-In (via `GoogleAuthService`) + local
// device-identity write. ADR-0005: the device identity row is keyed by the
// caller-supplied `deviceId` (generated independently, before this is ever
// called) — it is written regardless of what the Firebase session carries,
// and never derives from it.
//
// E01-T02: after the local Drift write, also fires a best-effort Firebase
// account<->device metadata registration (FR-FB-001/002, FR-AUTH-004) via
// `FirebaseMetadataService`. `registerDevice` already swallows and logs
// its own errors, but is only called when `accountUid` is non-null — a
// Firestore write failure must never block local-first sign-in
// (EARS-FB-2, offline-first constitution).
import 'package:nexora/core/auth/google_auth_service.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';

class SignInUseCase {
  SignInUseCase(
    this._repository, {
    GoogleAuthService? authService,
    FirebaseMetadataService? metadataService,
  })  : _authService = authService ?? GoogleAuthService(),
        _metadataService = metadataService ?? FirebaseMetadataService();

  final DeviceIdentityRepository _repository;
  final GoogleAuthService _authService;
  final FirebaseMetadataService _metadataService;

  /// Orchestrates real Google sign-in + local device-identity persistence.
  ///
  /// Signs in first (fail-fast): if sign-in throws, no device row is
  /// written and the [AppFailure] propagates to the caller — it is never
  /// swallowed, so callers can map it to UI state without the app crashing
  /// (EARS-AUTH-3).
  Future<void> call(String deviceId) async {
    final accountUid = await _authService.signInAndGetAccountUid();
    final id = await _repository.createDeviceIdentity(deviceId);
    await _repository.markSignedIn(id, accountUid: accountUid);

    // E01-T02 (EARS-FB-1/2): best-effort, non-blocking Firebase
    // account<->device metadata registration, fired after the local write
    // above. No accountUid (e.g. a credential with no Firebase user) means
    // nothing to link under — skip rather than register a meaningless row.
    if (accountUid != null) {
      await _metadataService.registerDevice(accountUid, deviceId);
    }
  }
}
