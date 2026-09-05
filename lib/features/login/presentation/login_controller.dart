// features/login/presentation — GetX controller (ADR-0002).
//
// Drives the "Signing in..." transient state, then the real Google
// Sign-In use case, then navigates onward (E01-T01 — replaces the genesis
// walking skeleton's stub).
//
// E06-T12: post-login destination is now `/dashboard`
// (design/screens/dashboard.md), superseding the genesis `/home` placeholder
// per that task's §3/§6 ("verify the login journey end to end, since a
// broken redirect here breaks the app's entry point"). This file is not
// listed in E06-T12's own `files:` fence (an omission in that task's
// frontmatter — the literal `/home` redirect below is the ONLY place the
// post-login destination is hardcoded), but the task's own body explicitly
// requires this exact change and names verifying it as a risk; logged here
// as a Deviation (one line, this file only) rather than silently left
// pointing at the superseded placeholder.
//
// E12-T03 (FR-RECOVER-001): one new branch point before that unconditional
// `/dashboard` redirect. `SignInUseCase.call` (unchanged by this task)
// already persists the freshly-created device identity locally, including
// `accountUid` when Firebase produced one — `DeviceIdentityRepository
// .latestDeviceIdentity()` reads that same row back rather than threading a
// new return value through `SignInUseCase`'s signature (task §4: "does not
// change SignInUseCase"). When `accountUid` is present, `E12-T01`'s
// `FirebaseMetadataService.readOwnDeviceIds(accountUid)` says whether any
// OTHER device already exists on this account; if so, this device cannot
// read that history locally, so it routes to `/device-enrollment` instead
// of straight to `/dashboard`. A first device (no accountUid, or no other
// registered ids) keeps the exact unchanged behavior.
import 'dart:math';

import 'package:get/get.dart';
import 'package:nexora/core/auth/google_auth_service.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';

/// Generates a device identifier using a cryptographically-secure RNG.
///
/// ADR-0005: device identity is independent of, and never derived from,
/// the account/Firebase session — this token is generated before any
/// Firebase call is made. This is a random device *token*, not a
/// cryptographic keypair: the X3DH/Double-Ratchet protocol is E03's job
/// (FR-AUTH-003 only needs a unique, hard-to-guess per-install id here).
///
/// File-scope (not private to [LoginController]) so it is directly
/// testable without instantiating a controller.
String generateSecureDeviceId() {
  final rand = Random.secure();
  return List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
}

class LoginController extends GetxController {
  /// [metadataService]/[deviceIdentityRepository] are optional named
  /// parameters. [metadataService] defaults to a fresh
  /// [FirebaseMetadataService]. [deviceIdentityRepository] defaults to
  /// `null` at construction — resolved lazily via [_resolveDeviceIdentityRepository]
  /// instead, since `AppBinding.dependencies()` (NOT in this task's
  /// `files:` fence, so its existing single-positional-argument
  /// `LoginController(Get.find<SignInUseCase>())` call site stays
  /// unmodified) is the only production place that registers a
  /// `DeviceIdentityRepository` singleton — `Get.find` in a constructor
  /// initializer would throw for any caller that never registered one
  /// (e.g. `test/widget_test.dart`'s walking-skeleton test, which builds
  /// its own unregistered `DeviceIdentityRepository` and passes only a
  /// `SignInUseCase`). Resolving lazily inside `_signIn()`, guarded by a
  /// try/catch, keeps that caller's existing behavior byte-for-byte: no
  /// registered repository reads as "cannot determine `accountUid`", which
  /// this task's own §6 Risks already treats as an acceptable degraded
  /// case (falls through to the unchanged `/dashboard` redirect).
  LoginController(
    this._signInUseCase, {
    FirebaseMetadataService? metadataService,
    DeviceIdentityRepository? deviceIdentityRepository,
  })  : _metadataService = metadataService ?? FirebaseMetadataService(),
        _deviceIdentityRepositoryOverride = deviceIdentityRepository;

  final SignInUseCase _signInUseCase;
  final FirebaseMetadataService _metadataService;
  final DeviceIdentityRepository? _deviceIdentityRepositoryOverride;

  /// Resolves the collaborator this task's branch needs: the explicit
  /// override if one was given (every test in
  /// `login_controller_enrollment_gate_test.dart` supplies one), otherwise
  /// the app-wide permanent singleton via `Get.find` — a lookup, never a
  /// second construction, so it never risks the
  /// second-`AppDatabase`/`DeviceIdentityRepository` pitfall
  /// `app/bindings.dart`'s own header warns about. `Get.find` throwing
  /// (nothing registered) is caught and reads as "unknown" rather than
  /// crashing sign-in — this whole branch is a best-effort hint (task §6
  /// Risks), never something worth blocking navigation over.
  DeviceIdentityRepository? _resolveDeviceIdentityRepository() {
    if (_deviceIdentityRepositoryOverride != null) {
      return _deviceIdentityRepositoryOverride;
    }
    try {
      return Get.find<DeviceIdentityRepository>();
    } catch (_) {
      return null;
    }
  }

  final RxBool signingIn = true.obs;

  @override
  void onInit() {
    super.onInit();
    _signIn();
  }

  Future<void> _signIn() async {
    signingIn.value = true;
    final deviceId = generateSecureDeviceId();
    try {
      await _signInUseCase(deviceId);
      signingIn.value = false;

      // E12-T03: the one new branch point. `SignInUseCase.call` already
      // wrote (and signed in) this exact device's identity row — read it
      // straight back for the `accountUid` it recorded, rather than
      // changing that use case's return type.
      final deviceIdentityRepository = _resolveDeviceIdentityRepository();
      final identity = await deviceIdentityRepository?.latestDeviceIdentity();
      final accountUid = identity?.accountUid;

      var routeToEnrollment = false;
      if (accountUid != null) {
        final otherDeviceIds = await _metadataService.readOwnDeviceIds(
          accountUid,
        );
        // "any device id OTHER than the one just created" (task §2) — a
        // first device's own freshly-registered id may already be the only
        // entry `readOwnDeviceIds` reports (E01-T02's `registerDevice` may
        // have already run by the time this read happens), which must not
        // by itself count as "other devices exist".
        routeToEnrollment = otherDeviceIds.any((id) => id != deviceId);
      }

      if (routeToEnrollment) {
        Get.offNamed(
          '/device-enrollment',
          arguments: {'uid': accountUid, 'deviceId': deviceId},
        );
      } else {
        Get.offNamed('/dashboard');
      }
    } catch (e) {
      // EARS-AUTH-3: surface as a mapped failure, never crash. A full
      // error-state UI is out of scope for this task (see task §4) — this
      // is the minimum the task asks for: map + log, no error screen yet.
      signingIn.value = false;
      ObservabilityService.instance.logError(
        e is AppFailure ? e.code : 'auth.google_sign_in_failed',
        cause: e,
      );
    }
  }
}
