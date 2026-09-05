// features/login/data — wraps core/persistence for the walking skeleton's
// one real write + read (E00-T05). No feature logic beyond that.
//
// E13-T02 (FR-ABUSE-001): gains an optional `RateLimiter` admission check
// (EARS-ABUSE-5) on `createDeviceIdentity`, gating how many devices ONE
// account may register within a window. Both `_rateLimiter` and
// `accountUid` are OPTIONAL: this repository's one real production caller,
// `SignInUseCase.call` (`sign_in_use_case.dart`), already has `accountUid`
// in hand at its call site but is outside this task's `files:` fence, so
// it cannot be edited to pass it through here. Omitting either parameter
// skips the gate — behavior for the existing call site is byte-for-byte
// unchanged from before this task (see task's Run log Deviations for the
// follow-up this leaves open).
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/persistence/database.dart';

class DeviceIdentityRepository {
  DeviceIdentityRepository(this._db, {this._rateLimiter});

  final AppDatabase _db;
  final RateLimiter? _rateLimiter;

  /// Bucket key scheme + limit chosen by this task (§3): keyed by the
  /// LOCAL account uid registering a new device, since the abuse shape
  /// being bounded is "how many devices may one account register" — a
  /// user reasonably registering 2-3 devices in a sitting should get
  /// through comfortably, so the ceiling is generous relative to that
  /// legitimate case over a full day (Run log documents the full
  /// reasoning).
  static const int _maxDeviceRegistrationsPerWindow = 5;
  static const Duration _deviceRegistrationWindow = Duration(hours: 24);

  /// Creates a fresh device-identity row, returns its id.
  ///
  /// [accountUid], when supplied together with a `rateLimiter`, gates this
  /// write behind EARS-ABUSE-5's per-account registration-rate check
  /// BEFORE the existing write — denies by throwing an [AppFailure]
  /// (matching `sign_in_use_case.dart`'s existing error-mapping
  /// convention: propagate, never swallow) rather than silently dropping
  /// the write.
  Future<int> createDeviceIdentity(String deviceId, {String? accountUid}) async {
    if (_rateLimiter != null && accountUid != null) {
      final admitted = await _rateLimiter.allow(
        'device_registration:$accountUid',
        maxCount: _maxDeviceRegistrationsPerWindow,
        window: _deviceRegistrationWindow,
      );
      if (!admitted) {
        throw const AppFailure('device.registration_rate_limited');
      }
    }
    return _db.createDeviceIdentity(deviceId);
  }

  /// Marks the given device identity as signed in, optionally recording the
  /// Firebase account uid it was signed in under (ADR-0005: the device
  /// identity row itself never derives from this — `accountUid` is purely
  /// an additive, queryable link, per FR-AUTH-004).
  Future<void> markSignedIn(int id, {String? accountUid}) =>
      _db.markSignedIn(id, accountUid: accountUid);

  /// Reads back the most recently created device identity, if any.
  Future<DeviceIdentity?> latestDeviceIdentity() => _db.latestDeviceIdentity();
}
