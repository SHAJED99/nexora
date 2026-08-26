// features/login/data — wraps core/persistence for the walking skeleton's
// one real write + read (E00-T05). No feature logic beyond that.
import 'package:nexora/core/persistence/database.dart';

class DeviceIdentityRepository {
  DeviceIdentityRepository(this._db);

  final AppDatabase _db;

  /// Creates a fresh device-identity row, returns its id.
  Future<int> createDeviceIdentity(String deviceId) {
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
