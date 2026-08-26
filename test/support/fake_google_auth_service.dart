// test/support — shared test double for GoogleAuthService (E01-T01).
//
// firebase_auth's `UserCredential` has a package-private constructor, so no
// test double outside the firebase_auth package can construct one without
// standing up the full Firebase platform-channel test harness. This double
// instead overrides `signInAndGetAccountUid` — the seam
// `GoogleAuthService` exposes specifically so callers/tests never need a
// real `UserCredential`. See lib/core/auth/google_auth_service.dart and the
// E01-T01 task file's self-review Deviations.
import 'package:nexora/core/auth/google_auth_service.dart';

class FakeGoogleAuthService extends GoogleAuthService {
  FakeGoogleAuthService.success(this._uid) : _error = null;
  FakeGoogleAuthService.failure(Object error)
      : _uid = null,
        _error = error;

  final String? _uid;
  final Object? _error;

  @override
  Future<String?> signInAndGetAccountUid() async {
    final error = _error;
    if (error != null) throw error;
    return _uid;
  }
}
