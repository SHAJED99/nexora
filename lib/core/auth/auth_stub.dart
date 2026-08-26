// core/auth — genesis structural stub (ADR-0005, independent sessions).
//
// Real Firebase Auth wiring (account identity) and the local device-session
// store it must stay independent from are feature-epic work — this is the
// human-gated `human_gates: auth_or_payment_code` boundary the task brief
// explicitly excludes from genesis. `features/welcome` and `features/login`
// use `core/persistence` directly for the walking skeleton's one write
// instead of routing through here, so this stub stays honestly empty
// rather than pretending to be a session store it isn't.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Placeholder — no real Firebase Auth / device-session wiring in genesis.
  Future<void> init() async {}
}
