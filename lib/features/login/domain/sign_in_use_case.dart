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
// Realtime Database write failure must never block local-first sign-in
// (EARS-FB-2, offline-first constitution).
//
// E13-T07 (FR-ABUSE-001, EARS-ABUSE-5, task §2 item 3): `accountUid` is now
// threaded into `createDeviceIdentity` so `DeviceIdentityRepository`'s
// per-account device-registration rate limit (E13-T02) can actually gate
// this, the repository's one real production caller.
//
// **F1 fix (E13-T07 review round 2, S1/S2 — human-decided direction):**
// `LoginController._signIn` used to mint a brand-new random device id on
// EVERY app launch and always call through to [call] below, which always
// ran `createDeviceIdentity` — i.e. the registration/rate-limit gate fired
// on every single launch, not just on a genuinely new device's first one. A
// normal user opening the app more than 5 times in 24h got silently denied
// on launch 6. `existingDeviceId` (below) exposes this device's own,
// already-registered identity (via `DeviceIdentityRepository
// .latestDeviceIdentity()` — the same read `lib/app/main.dart` already
// performs to seed `selfDeviceId`), so `LoginController` can reuse it
// instead of minting fresh. [call] itself then recognizes a `deviceId` that
// matches this device's own current latest identity as a RETURNING device,
// not a new registration, and skips `createDeviceIdentity` (and therefore
// the rate limiter) entirely for it — see [call]'s own comment. Kept as a
// deviceId-equality check, not "any identity exists", specifically so
// `test_EARS_ABUSE_5_wired_sign_in_flow_denies_over_limit_registration`
// (below) — which legitimately registers several *distinct* device ids
// under one account, simulating several real physical devices/an attacker
// rotating ids — keeps failing exactly as before: none of those calls ever
// matches the immediately-prior call's own id, so every one of them still
// goes through the real registration/rate-limit path.
//
// **Partial-auth-state decision (task §3, `E13-T02`'s review):** once this
// gate is live, `createDeviceIdentity` can now throw
// `AppFailure('device.registration_rate_limited')` AFTER Google sign-in
// already succeeded but BEFORE any local device-identity row is written.
// Decided here, explicitly, rather than left unaddressed:
// - No partial local state is ever persisted either way — the repository's
//   own rate-limit check runs BEFORE its write (`device_identity_repository
//   .dart`), and a denied `RateLimiter.allow` call never increments its
//   counter (`rate_limiter.dart`), so a denied attempt costs the account
//   nothing and is safely retried once the window elapses.
// - The `AppFailure` propagates unchanged, same as every other failure this
//   method already lets through (EARS-AUTH-3) — `LoginController._signIn`'s
//   existing generic `catch (e)` (outside this task's `files:` fence)
//   already logs `e.code` via `ObservabilityService`, sets `signingIn` back
//   to `false`, and does NOT navigate to `/dashboard` — so a user who hits
//   this never reaches an inconsistent authenticated-but-deviceless screen;
//   they stay on the login screen with an honest, distinguishable logged
//   failure code and can retry (a retry that will keep failing until the
//   24h window rolls over, which is the rate limit working as intended, not
//   a bug this task needs to route around).
// - Google's own cached credential state (outside this repository's reach)
//   may remain signed-in across a retry — that's expected and harmless:
//   ADR-0005 already treats the local device identity, never the Firebase
//   session, as this app's source of truth, so a cached Google session with
//   no local device row is not a state this app's own logic depends on.
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

  /// This device's own, already-registered local device id, if any (F1
  /// fix, see file header) — a thin passthrough to
  /// `DeviceIdentityRepository.latestDeviceIdentity()` so `LoginController`
  /// never needs to depend on the repository directly (mirrors
  /// `lib/app/main.dart`'s own pre-existing read of the same signal).
  /// `null` on a fresh install with no local identity yet.
  Future<String?> existingDeviceId() async {
    final existing = await _repository.latestDeviceIdentity();
    return existing?.deviceId;
  }

  /// Orchestrates real Google sign-in + local device-identity persistence.
  ///
  /// Signs in first (fail-fast): if sign-in throws, no device row is
  /// written and the [AppFailure] propagates to the caller — it is never
  /// swallowed, so callers can map it to UI state without the app crashing
  /// (EARS-AUTH-3).
  ///
  /// [deviceId] is either a freshly-minted id (a genuinely new device) or
  /// this device's OWN existing id, read back via [existingDeviceId] by the
  /// caller before this runs (F1 fix, see file header). When [deviceId]
  /// matches this device's own current latest identity, this is a
  /// returning device on a normal relaunch, not a new registration: reuse
  /// that row and skip `createDeviceIdentity` (and therefore the
  /// per-account registration rate limiter) entirely — a device that
  /// already has a local identity never counts against the limit again, no
  /// matter how many times the app is launched.
  Future<void> call(String deviceId) async {
    final accountUid = await _authService.signInAndGetAccountUid();

    final existing = await _repository.latestDeviceIdentity();
    if (existing != null && existing.deviceId == deviceId) {
      await _repository.markSignedIn(existing.id, accountUid: accountUid);
      if (accountUid != null) {
        await _metadataService.registerDevice(accountUid, deviceId);
      }
      return;
    }

    final id = await _repository.createDeviceIdentity(
      deviceId,
      accountUid: accountUid,
    );
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
