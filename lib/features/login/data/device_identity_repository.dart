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

  /// Marks the given device identity as signed in.
  Future<void> markSignedIn(int id) => _db.markSignedIn(id);

  /// Reads back the most recently created device identity, if any.
  Future<DeviceIdentity?> latestDeviceIdentity() => _db.latestDeviceIdentity();
}
