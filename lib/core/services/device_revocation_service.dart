// core/services — DeviceRevocationService (E11-T04, FR-FB-001, FR-MSG-007,
// FR-AUTH-004).
//
// Let a user revoke one of their own devices and have every *other* device
// on that account learn about it -- the "revocation information" half of
// FR-FB-001, which no earlier epic built (task §1). This is the first and
// only thing in the project that writes revocation state.
//
// FR-MSG-007 is binding on the merge (task §2): REVOKED > ACTIVE, always,
// in both directions. `ConflictResolver.resolveRevocation` (E05-T05,
// `a || b`) already implements exactly this and is the only merge rule
// used here -- never re-derived.
//
// Scope fence (task §4): this service builds the local record and
// own-account propagation ONLY. It does NOT enforce revocation anywhere --
// `isRevoked` has zero callers in this task, deliberately. It does NOT
// propagate to peers or other accounts (`ADR-0008`/`E11-T06`'s job) and
// does NOT implement un-revoke (revocation is monotonic and irreversible in
// v1, task §2).
//
// Firebase boundary (FR-FB-002, non-negotiable): the Firebase read/write
// methods below mirror `FirebaseMetadataService`/`SyncCursorService`'s exact
// pattern (E01-T02/E05-T04) -- best-effort, bounded timeout via `.timeout()`,
// catch-and-log via `ObservabilityService`, never throws to the caller.
// Only `revokedAt`/`revokedByDeviceId` are ever written -- never message
// content, keys, or anything outside `FirebaseBoundary`'s allow-list for
// this node.
import 'package:firebase_database/firebase_database.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/device_directory_service.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_paths.dart';
import 'package:nexora/features/messaging/domain/conflict_resolver.dart';

/// Where a local `device_revocations` row's knowledge came from -- stored as
/// `.name` text (`DeviceRevocations.source`), per docs/conventions.md
/// "Enums" -- never an integer index.
enum RevocationSource { local, firebase }

class DeviceRevocationService {
  DeviceRevocationService({
    required this.localDeviceId,
    required AppDatabase database,
    FirebaseDatabase? firebaseDatabase,
    Duration? timeout,
    DateTime Function() clock = DateTime.now,
    DeviceDirectoryService? directoryService,
  })  : // Named params (`database`) are public API; the private field below
        // can't share that name, so `prefer_initializing_formals` doesn't
        // apply here despite the trivial assignment -- same reasoning as
        // `SyncCursorService`.
        _database = database, // ignore: prefer_initializing_formals
        _firebaseDatabaseOverride = firebaseDatabase,
        // Same reasoning as FirebaseMetadataService._timeout /
        // SyncCursorService._timeout: a Realtime Database write/read queued
        // offline never completes at all, so this bounds it -- a timeout is
        // just another failure mode, caught below like any other Realtime
        // Database error.
        _timeout = timeout ?? const Duration(seconds: 10),
        _clock = clock, // ignore: prefer_initializing_formals
        // E11-T06 (`ADR-0008` option 2): optional -- `null` (the default)
        // is a pure no-op, so every existing caller/test is unaffected.
        _directoryService = directoryService; // ignore: prefer_initializing_formals

  /// This device's own device id -- recorded as `revokedByDeviceId` when
  /// this device is the one issuing a revocation.
  final String localDeviceId;

  final AppDatabase _database;
  final FirebaseDatabase? _firebaseDatabaseOverride;
  final Duration _timeout;
  final DateTime Function() _clock;
  final DeviceDirectoryService? _directoryService;

  // Resolved lazily, mirroring FirebaseMetadataService._database /
  // SyncCursorService._firebaseDatabase -- so constructing a
  // DeviceRevocationService with no override never touches a live Realtime
  // Database instance until a read/write is actually attempted.
  FirebaseDatabase get _firebaseDatabase =>
      _firebaseDatabaseOverride ?? FirebaseDatabase.instance;

  /// The only way a revocation is created (task §3). Writes the local
  /// record first -- a revocation that only succeeded remotely is a
  /// revocation this device forgets on next launch (task §3, "local-first")
  /// -- then best-effort publishes it to the account's Firebase device
  /// registry. Completes after the local write; the Firebase write never
  /// throws.
  ///
  /// [deviceId] may be this device or another of the account's own devices
  /// (FR-AUTH-004).
  Future<void> revoke(String uid, String deviceId) async {
    await _database.into(_database.deviceRevocations).insertOnConflictUpdate(
          DeviceRevocationsCompanion.insert(
            deviceId: deviceId,
            revokedAt: _clock(),
            source: RevocationSource.local.name,
          ),
        );

    final data = {
      'revokedAt': ServerValue.timestamp,
      'revokedByDeviceId': localDeviceId,
    };
    // EARS-FB-13/task §6 Risks: the guard runs *before* the try below, not
    // inside it -- a boundary violation is a programming error and must
    // propagate, not get caught and logged as "just another Firebase
    // error" (same reasoning as FirebaseMetadataService.registerDevice).
    FirebaseBoundary.assertAllowedFields(
      FirebaseNodeKind.deviceRevocation,
      data,
    );
    try {
      await writeRevocationData(uid, deviceId, data).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.device_revocation_write_failed',
        cause: e,
      );
    }

    // E11-T06 (`ADR-0008` option 2): republish this device's own directory
    // entry so its `revokedAt` flag is current. Only when [deviceId] IS
    // this device ([localDeviceId]) -- `DeviceDirectoryService.publish`
    // assembles its `identityPublicKey`/`prekeyBundle` fields from THIS
    // process's own `IdentityService`, which holds no key material for any
    // *other* device on the account (FR-AUTH-004 lets [deviceId] name one
    // of those). Publishing this device's own bundle under a different
    // device's directory entry would corrupt that entry with the wrong
    // identity key, so this call is skipped entirely for that case -- the
    // other device republishes its own entry (with its own now-current
    // `revokedAt`) the next time ITS `IdentityService`/`revoke` runs.
    if (deviceId == localDeviceId) {
      await _directoryService?.publish(uid, deviceId);
    }
  }

  /// Performs the actual Realtime Database write. Split out from [revoke]
  /// deliberately -- `FirebaseDatabase`/`DatabaseReference` need a live
  /// platform-channel test harness to construct in tests, so tests seam
  /// here instead (mirrors `FirebaseMetadataService.writeDeviceMetadata` /
  /// `SyncCursorService.writeCursorData`).
  ///
  /// Path from [FirebasePaths.deviceRevocation] (E11-T04) --
  /// `users/$uid/devices/$deviceId/revocation`.
  Future<void> writeRevocationData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return _firebaseDatabase
        .ref(FirebasePaths.deviceRevocation(uid, deviceId))
        .set(data);
  }

  /// Merges each of the account's device revocation flags -- read from the
  /// account's Firebase device registry -- with the local one via
  /// [ConflictResolver.resolveRevocation] (FR-MSG-007: REVOKED > ACTIVE),
  /// persisting only the rows that actually change. Returns the number of
  /// local rows changed.
  ///
  /// Never throws: any read failure or offline device leaves local state
  /// completely untouched and returns `0` (task §6 Risks) -- a device
  /// missing from the read (or the read failing outright) is treated as
  /// "no information", which resolves through `resolveRevocation` as
  /// `false`, never as "unknown -> overwrite". Combined with never deleting
  /// or un-flagging a row, this makes an un-revoke structurally impossible
  /// through this method.
  Future<int> pullRevocations(String uid) async {
    final Object? raw;
    try {
      raw = await readDevicesData(uid).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.device_revocation_pull_failed',
        cause: e,
      );
      return 0;
    }

    final remoteRevoked = _extractRevocationFlags(raw);
    var changed = 0;
    for (final entry in remoteRevoked.entries) {
      final deviceId = entry.key;
      final remote = entry.value;
      final local = await isRevoked(deviceId);
      final merged = ConflictResolver.resolveRevocation(local, remote);
      // Only ever write when the merge actually turns a device from
      // not-revoked to revoked -- `merged` can never be `false` while
      // `local` is `true` (resolveRevocation is `a || b`), so this is the
      // only case in which anything changes.
      if (merged && !local) {
        await _database
            .into(_database.deviceRevocations)
            .insertOnConflictUpdate(
              DeviceRevocationsCompanion.insert(
                deviceId: deviceId,
                revokedAt: _clock(),
                source: RevocationSource.firebase.name,
              ),
            );
        changed++;
      }
    }
    return changed;
  }

  /// Performs the actual Realtime Database read of the whole
  /// `users/$uid/devices` subtree (every one of the account's device nodes,
  /// each carrying its own `revocation` child if one exists). Split out
  /// from [pullRevocations] for the same test-seam reason as
  /// [writeRevocationData].
  Future<Object?> readDevicesData(String uid) async {
    final snapshot =
        await _firebaseDatabase.ref(FirebasePaths.devices(uid)).get();
    return snapshot.value;
  }

  /// The one local query point (task §3) -- no callers in this task, by
  /// design (§4: enforcement spans E03's Signal session store and E04's
  /// transport, neither sharded yet -- `OQ-E11-T04-1`).
  Future<bool> isRevoked(String deviceId) async {
    final row = await (_database.select(_database.deviceRevocations)
          ..where((t) => t.deviceId.equals(deviceId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Reads `{deviceId: hasRevocationChild}` out of the raw
  /// `users/$uid/devices` snapshot value. A device with no `revocation`
  /// child (or a malformed one) reads as `false` -- absent information,
  /// never "unknown" -- per [pullRevocations]'s doc comment.
  static Map<String, bool> _extractRevocationFlags(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, bool>{};
    for (final entry in raw.entries) {
      final deviceId = entry.key;
      if (deviceId is! String) continue;
      final deviceData = entry.value;
      result[deviceId] = deviceData is Map &&
          deviceData['revocation'] is Map &&
          (deviceData['revocation'] as Map).isNotEmpty;
    }
    return result;
  }
}
