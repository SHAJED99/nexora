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
//
// **E12-B01 fix (S1 — every returning user misrouted to
// `/device-enrollment` on every launch after the first):**
// `generateSecureDeviceId()` used to be called unconditionally on every
// launch, so `SignInUseCase.call` (which always calls
// `createDeviceIdentity`/`registerDevice` — neither is in this bug's
// `files:` fence, so neither changes) accumulated one NEW registered id
// per launch. The gate above then always saw "another id exists" from
// launch 2 onward, because the registry held the previous launch's id
// plus this launch's freshly-minted one. Fix, entirely within this file:
// read this device's own existing identity (if any) via
// `DeviceIdentityRepository.latestDeviceIdentity()` BEFORE minting an id,
// and reuse its `deviceId` when one exists — the same read-back pattern
// `lib/app/main.dart` already uses to seed `selfDeviceId`, and the same
// signal `E13-T07` reuses for the same root cause on its own branch/file
// (that fix cannot be reused directly here: its `files:` fence
// deliberately excludes this file). A genuinely new device (no local row
// yet) still mints a fresh random id, unchanged. Reusing the id means the
// registry never gains a second entry for this device, so the gate's own
// condition (`otherDeviceIds.any((id) => id != deviceId)`, itself
// untouched by this fix) again reads "no other device" on every relaunch.
// This lookup is best-effort, same rationale as the AFTER-sign-in read
// below: a failure here (Drift error, corrupt row) must not block sign-in
// — it falls back to minting a fresh id, exactly the pre-B01 behavior,
// and is logged rather than silently swallowed.
//
// **E12-B08 fix (Defect 1, S4):** the AFTER-sign-in identity read (and the
// `readOwnDeviceIds` call it feeds) used to sit inside `_signIn()`'s outer
// `try`, so a Drift error there reported a SUCCEEDED sign-in as a mapped
// failure. It is now wrapped in its own try/catch that logs and falls
// through to the unchanged `/dashboard` redirect — the same degraded case
// this task's own §6 Risks already sanctions for an unresolvable
// repository, now applied to a resolvable-but-throwing one too.
//
// **E12-B08 fix (Defect 2, S4):** `_resolveDeviceIdentityRepository()`'s
// `catch (_)` was the one best-effort failure path in this feature that
// never logged — every sibling collaborator does. Now logs via
// `ObservabilityService` before returning `null`, same shape as every
// sibling catch (`firebase_metadata_service.dart`,
// `relationship_sync_service.dart`, this file's own outer `_signIn` catch).
import 'dart:math';

import 'package:get/get.dart';
import 'package:nexora/core/auth/google_auth_service.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
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
    MessagingStack? messagingStack,
  })  : _metadataService = metadataService ?? FirebaseMetadataService(),
        _deviceIdentityRepositoryOverride = deviceIdentityRepository,
        _messagingStackOverride = messagingStack;

  final SignInUseCase _signInUseCase;
  final FirebaseMetadataService _metadataService;
  final DeviceIdentityRepository? _deviceIdentityRepositoryOverride;
  final MessagingStack? _messagingStackOverride;

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
    } catch (e) {
      ObservabilityService.instance.logError(
        'recovery.device_identity_repository_unresolved',
        cause: e,
      );
      return null;
    }
  }

  /// Same resolution pattern as [_resolveDeviceIdentityRepository]: the
  /// explicit test override if one was given, otherwise the app-wide
  /// singleton `lib/app/main.dart` constructs before `runApp()` ever runs
  /// (`Get.find`, a lookup — never a second `MessagingStack.create`, which
  /// would violate that file's own "exactly one" discipline). `Get.find`
  /// throwing is caught and treated as "no local identity available",
  /// never a sign-in failure — same best-effort shape as the repository
  /// resolver above.
  MessagingStack? _resolveMessagingStack() {
    if (_messagingStackOverride != null) {
      return _messagingStackOverride;
    }
    try {
      return Get.find<MessagingStack>();
    } catch (e) {
      ObservabilityService.instance.logError(
        'recovery.messaging_stack_unresolved',
        cause: e,
      );
      return null;
    }
  }

  /// E11-B06 finding 1 (`ADR-0008`'s 2026-09-05 addendum): when this
  /// device has never signed in before (no `existingDeviceId`, the only
  /// caller of this method), derive its device id from its own already-
  /// generated Signal identity public key instead of an unrelated random
  /// token — `lib/app/main.dart` constructs `MessagingStack` (which
  /// generates this device's identity keypair on first run,
  /// `IdentityService.ensureLocalIdentity`) BEFORE `runApp()`, so the key
  /// material this reads already exists by the time any screen —
  /// including this one — is ever shown. The SAME hex encoding
  /// `DeviceDirectoryService._publish` uses for `identityPublicKey`
  /// (`identity_key_hex.dart`), so a Realtime Database rule can enforce
  /// `$deviceId === identityPublicKey` as a plain string equality — no
  /// hash primitive, no Cloud Function, no bootstrap reshape needed.
  ///
  /// Best-effort: returns `null` (never throws) on any failure — no
  /// `MessagingStack` resolvable, or the identity keypair read throwing
  /// (e.g. crypto/identity init itself failed). A `null` here falls
  /// through to [generateSecureDeviceId] at this method's own call site,
  /// exactly like every other best-effort hint in this file — a device
  /// can still sign in and use the app even when this derivation isn't
  /// available; it only loses the self-certifying-id property until it
  /// next has a chance to retry (this runs only on a genuine first-ever
  /// sign-in, so "next chance" in practice means "next fresh install").
  ///
  /// **Deliberately does NOT check `messagingStack.status.isReady`.**
  /// `MessagingStack.create` (`lib/app/main.dart`, before `runApp()`)
  /// reports `unavailable` whenever `selfDeviceId` is empty — which, on a
  /// genuinely fresh install, is EVERY time this method is ever called
  /// (there is no `selfDeviceId` yet precisely because signing in for the
  /// first time is this method's whole reason to exist). Gating on
  /// `isReady` would make this derivation dead code in production: the
  /// one case it exists for is exactly the case that flag reports as not
  /// ready. `identityService.ensureLocalIdentity()` runs unconditionally
  /// inside `MessagingStack.create`, BEFORE that empty-`selfDeviceId`
  /// check — so the identity keypair this method reads is genuinely
  /// available regardless of what `status` says; the try/catch below is
  /// the correct and sufficient guard on its own.
  Future<String?> _deriveDeviceIdFromLocalIdentity() async {
    final messagingStack = _resolveMessagingStack();
    if (messagingStack == null) {
      return null;
    }
    try {
      final identityKeyPair = await messagingStack.signalStore.getIdentityKeyPair();
      return hexEncodeIdentityKey(identityKeyPair.getPublicKey());
    } catch (e) {
      ObservabilityService.instance.logError(
        'recovery.local_identity_key_read_failed',
        cause: e,
      );
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
    try {
      final deviceIdentityRepository = _resolveDeviceIdentityRepository();

      // F1 fix (E13-T07 review round 2, S1/S2) + E12-B01 fix (merged from
      // `epic_12`): reuse this device's own already-registered id when one
      // exists, rather than unconditionally minting a fresh one on every
      // launch — minting fresh every time made every relaunch look like a
      // brand-new device registering, which silently exhausted
      // `DeviceIdentityRepository`'s per-account registration rate limit
      // (5/24h) after just 5 launches; it also permanently mis-routed
      // returning users to `/device-enrollment` (`E12-B01`). `call`
      // recognizes a reused id as a returning device and skips the
      // registration/rate-limit path entirely for it (see
      // `sign_in_use_case.dart`'s header + `call`'s own doc comment).
      //
      // Two independently-reviewed mechanisms read this device's existing
      // identity, reconciled here at the merge of `epic_12`/`epic_13`:
      // - When a `DeviceIdentityRepository` is resolvable (the real app,
      //   via `Get.find`, or a test's explicit `deviceIdentityRepository:`
      //   override), read it DIRECTLY (E12-B01's own mechanism) — a
      //   failure here is a best-effort hint, not a reason to fail the
      //   whole sign-in attempt. It falls back to minting a fresh id and
      //   is logged distinctly from a real sign-in failure
      //   (`E12-B08` regression: `test_EARS_AUTH_3_device_identity_read_
      //   failure_falls_through_to_dashboard`).
      // - When no repository is resolvable at all (no container, or a
      //   test that only wires `SignInUseCase` directly without also
      //   registering/injecting a `DeviceIdentityRepository`), fall back
      //   to `_signInUseCase.existingDeviceId()` — the same signal read
      //   via `_signInUseCase`'s own internal repository reference, which
      //   in production is always the identical singleton
      //   `deviceIdentityRepository` would have resolved to anyway
      //   (`E13-T07` regression:
      //   `test_EARS_ABUSE_5_returning_device_reaches_dashboard_across_N_
      //   launches`). Unlike the repository-read branch above, THIS read
      //   is intentionally left unguarded: if it throws, no fallback
      //   repository was even available, which is abnormal enough to fail
      //   the whole sign-in attempt cleanly via the outer catch below
      //   (EARS-AUTH-3) rather than silently minting a device id nothing
      //   could confirm (`E13-T07` review round 3, F6 regression:
      //   `test_EARS_AUTH_3_existing_device_id_read_failure_completes_
      //   signin_instead_of_hanging`). `onInit()` calls `_signIn()`
      //   unawaited, so this must stay inside the outer `try` — moved here
      //   deliberately, not left to float outside it.
      String? existingDeviceId;
      if (deviceIdentityRepository != null) {
        try {
          final existingIdentity =
              await deviceIdentityRepository.latestDeviceIdentity();
          existingDeviceId = existingIdentity?.deviceId;
        } catch (e) {
          ObservabilityService.instance.logError(
            'recovery.device_identity_read_failed',
            cause: e,
          );
        }
      } else {
        existingDeviceId = await _signInUseCase.existingDeviceId();
      }
      final deviceId = existingDeviceId ??
          await _deriveDeviceIdFromLocalIdentity() ??
          generateSecureDeviceId();
      await _signInUseCase(deviceId);
      signingIn.value = false;

      // E12-T03: the one new branch point. `SignInUseCase.call` already
      // wrote (and signed in) this exact device's identity row — read it
      // straight back for the `accountUid` it recorded, rather than
      // changing that use case's return type.
      //
      // E12-B08 fix (Defect 1): this read (and the `readOwnDeviceIds` call
      // it feeds) is a best-effort routing hint, not a sign-in outcome —
      // its own try/catch keeps a failure here from being reported as a
      // sign-in failure by the outer catch below; it falls through to the
      // unchanged `/dashboard` redirect instead, same as the no-accountUid
      // case already does.
      String? accountUid;
      var routeToEnrollment = false;
      try {
        final identity = await deviceIdentityRepository?.latestDeviceIdentity();
        accountUid = identity?.accountUid;

        if (accountUid != null) {
          final otherDeviceIds = await _metadataService.readOwnDeviceIds(
            accountUid,
          );
          // "any device id OTHER than the one just created" (task §2) — a
          // first device's own freshly-registered id may already be the
          // only entry `readOwnDeviceIds` reports (E01-T02's
          // `registerDevice` may have already run by the time this read
          // happens), which must not by itself count as "other devices
          // exist".
          routeToEnrollment = otherDeviceIds.any((id) => id != deviceId);
        }
      } catch (e) {
        ObservabilityService.instance.logError(
          'recovery.device_identity_lookup_failed',
          cause: e,
        );
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
