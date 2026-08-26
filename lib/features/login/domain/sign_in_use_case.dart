// features/login/domain — business logic between controller and
// repository (ADR-0002's `use_case.dart` seam — headless-testable without a
// device or a real UI).
//
// Genesis scope: stubbed "Continue with Google" — a fake 1-2s delay
// standing in for the real OAuth round trip, then one local Drift write.
// Real Firebase/Google auth is out of scope (human_gates: auth_or_payment_code).
import 'package:nexora/features/login/data/device_identity_repository.dart';

class SignInUseCase {
  SignInUseCase(this._repository, {this.delay = const Duration(seconds: 1)});

  final DeviceIdentityRepository _repository;
  final Duration delay;

  /// Stubbed "Continue with Google": creates a device identity, waits to
  /// simulate the OAuth round trip, then marks it signed in. Returns the
  /// device identity's local row id.
  Future<int> call(String deviceId) async {
    final id = await _repository.createDeviceIdentity(deviceId);
    await Future<void>.delayed(delay);
    await _repository.markSignedIn(id);
    return id;
  }
}
