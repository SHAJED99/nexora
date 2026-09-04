// core/persistence — device_revocations table (E11-T04, FR-FB-001,
// FR-MSG-007).
//
// Local, authoritative-on-this-device record of which device ids this
// account has revoked -- one row per revoked device id, written only by
// `DeviceRevocationService` (E11-T04 §3). This task builds the record and
// its own-account propagation ONLY; nothing here enforces revocation
// anywhere (task §4 -- `DeviceRevocationService.isRevoked` has zero callers
// in this task, deliberately).
//
// Revocation is monotonic and irreversible in v1 (task §2): there is no
// un-revoke, and no code path in this task ever deletes or updates a row's
// `revokedAt`/`source` away from an existing revocation -- a device already
// present in this table stays present forever.
import 'package:drift/drift.dart';

@DataClassName('DeviceRevocationRow')
class DeviceRevocations extends Table {
  /// The device id that was revoked -- may be this device or another of the
  /// account's own devices (FR-AUTH-004: devices on one account are
  /// independent).
  TextColumn get deviceId => text()();

  /// When this device recorded the revocation -- not necessarily the same
  /// instant Firebase's `ServerValue.timestamp` recorded it there.
  DateTimeColumn get revokedAt => dateTime()();

  /// A `RevocationSource.name` string (`DeviceRevocationService`, E11-T04)
  /// -- `'local'` (this device issued the revocation via `revoke`) or
  /// `'firebase'` (learned via `pullRevocations`), per docs/conventions.md
  /// "Enums" -- never an integer index.
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {deviceId};
}
