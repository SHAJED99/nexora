// core/auth — real Google Sign-In via Firebase Auth (E01-T01).
//
// ADR-0005 (independent sessions): this wraps *account* identity only.
// Nothing here ever produces, stores, or reads the local device identity —
// that stays entirely local (see `features/login/presentation/login_controller.dart`
// and `features/login/domain/sign_in_use_case.dart`), so a Firebase token
// refresh, expiry, or outage can never affect it.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nexora/core/observability/observability_service.dart';

/// The project's one error envelope for cross-layer failures
/// (`docs/conventions.md` "Error handling"). This is the first real call
/// site that needs it; a shared `core/error/` home is a natural follow-up
/// once a second caller needs the same shape — kept here since this file is
/// the only one E01-T01 is allowed to create.
class AppFailure implements Exception {
  const AppFailure(this.code, {this.cause});

  /// Stable, greppable error code, e.g. `'auth.google_sign_in_failed'`.
  final String code;

  /// Original exception/reason, logged — never shown to the user.
  final Object? cause;

  @override
  String toString() => 'AppFailure($code)';
}

/// Wraps `google_sign_in` + `firebase_auth` into the app's one Google
/// sign-in flow.
class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _firebaseAuthOverride = firebaseAuth,
        _googleSignInOverride = googleSignIn;

  final FirebaseAuth? _firebaseAuthOverride;
  final GoogleSignIn? _googleSignInOverride;

  // Resolved lazily (not in the constructor) so constructing a
  // `GoogleAuthService()` with no overrides never touches a live Firebase
  // instance until a sign-in is actually attempted — the default
  // constructor path is safe to use in `SignInUseCase`'s own default.
  FirebaseAuth get _firebaseAuth => _firebaseAuthOverride ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _googleSignInOverride ?? GoogleSignIn();

  /// Runs the Google Sign-In flow, then exchanges the resulting Google
  /// credential for a Firebase session via `signInWithCredential`.
  ///
  /// Throws [AppFailure] with code `'auth.google_sign_in_failed'` on any
  /// failure — including the user cancelling the account picker.
  Future<UserCredential> signIn() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User dismissed the account picker — not a crash, just no result.
        throw const AppFailure(
          'auth.google_sign_in_failed',
          cause: 'cancelled',
        );
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('auth.google_sign_in_failed', cause: e);
    }
  }

  /// Signs in and returns just the resulting Firebase account uid (or
  /// `null` if the signed-in user has none) — the one piece of account
  /// identity `SignInUseCase` needs.
  ///
  /// Split out from [signIn] deliberately: firebase_auth's `UserCredential`
  /// has a package-private constructor, so no test double outside
  /// firebase_auth itself can construct one — seaming at "the account id
  /// this sign-in produced" instead lets `SignInUseCase`'s tests fake this
  /// service by overriding this method, with no Firebase platform test
  /// harness required. See E01-T01 self-review, Deviations.
  Future<String?> signInAndGetAccountUid() async {
    final credential = await signIn();
    return credential.user?.uid;
  }

  /// ADR-0005's account-pointer half of sign-out (`E15-T01`, `FR-AUTH-006`):
  /// terminates the Firebase Authentication session and revokes the cached
  /// Google credential.
  ///
  /// Calls `GoogleSignIn.disconnect()`, not `signOut()` — `IMP-003` found
  /// that a plain `signOut()` risks the next `signIn()` silently reusing a
  /// still-cached Google account with no chooser shown, which would falsify
  /// FR-AUTH-008's "next sign-in is indistinguishable from a first-ever
  /// install." `disconnect()` revokes the previous authentication outright.
  ///
  /// Never throws: the Firebase half and the Google half are caught and
  /// logged independently via `ObservabilityService` (never `print()`, per
  /// `docs/conventions.md`) — `SignOutUseCase`'s local erase must never be
  /// blocked by either failing, and one failing must not skip the other.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      ObservabilityService.instance.logError(
        'auth.firebase_sign_out_failed',
        cause: e,
      );
    }
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      ObservabilityService.instance.logError(
        'auth.google_disconnect_failed',
        cause: e,
      );
    }
  }
}
