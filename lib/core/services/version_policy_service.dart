// core/services -- VersionPolicyService (E14-T01/T03, FR-VER-005,
// FR-VER-008, FR-VER-011).
//
// Claims `OQ-E11-2`'s reserved `config/version_policy` node and gives every
// later E14 task a locally-cached, offline-usable copy of the remote
// version policy (task §1).
//
// Scope fence (task §4): this service does NOT implement the version state
// machine (UP_TO_DATE/UPDATE_AVAILABLE/UPDATE_REQUIRED -- `E14-T02`'s own
// pure domain logic, consuming [cached]'s output). It does NOT add a
// polling driver -- [refresh] has no caller in this task; when wired, the
// caller decides the cadence, not a new always-on timer invented here.
//
// Signature verification (E14-T03, FR-VER-011): a fetched payload is
// verified via `VersionPolicySignatureVerifier` BEFORE it is cached --
// fail-CLOSED (an invalid/missing signature is treated exactly like a
// malformed payload, below). This composes with the pre-existing
// fail-open default (no valid cached policy -> `EvaluateVersionStateUseCase`
// falls back to `UP_TO_DATE`), not a stricter new failure mode.
//
// Firebase boundary (FR-FB-002, non-negotiable): [refresh] mirrors every
// other wrapper's exact pattern (`FirebaseMetadataService`,
// `SyncCursorService`, `DeviceRevocationService`) -- best-effort, bounded
// timeout via `.timeout()`, catch-and-log via `ObservabilityService`, never
// throws to the caller. There is no write path for this node in this build
// (`.write: false` for every client -- task §2/§6 Risks): only the read
// side ever runs `FirebaseBoundary.assertAllowedFields`, against whatever
// the read parses the remote payload into.
import 'package:drift/drift.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_paths.dart';
import 'package:nexora/core/services/version_policy_signature_verifier.dart';

/// The fixed row id [VersionPolicyCache] always uses -- there is exactly
/// one cached policy, same "exactly one settings row" shape as
/// `StoragePolicySettings`/`LocationSettings`/`NotificationPreferences`.
const int _cacheRowId = 1;

/// The last successfully fetched, SIGNATURE-VERIFIED `config/version_policy`
/// payload -- a plain data holder, not a domain object. By the time a
/// [VersionPolicy] exists here, `signature` has already been checked by
/// `VersionPolicySignatureVerifier` (E14-T03, FR-VER-011); `refresh()`
/// never caches a payload that failed that check.
class VersionPolicy {
  const VersionPolicy({
    required this.minimumSupportedBuild,
    required this.currentBuild,
    required this.updateAvailableBuild,
    required this.signature,
    required this.updatedAt,
  });

  final int minimumSupportedBuild;
  final int currentBuild;
  final int updateAvailableBuild;
  final String signature;
  final int updatedAt;
}

class VersionPolicyService {
  VersionPolicyService({
    required AppDatabase database,
    FirebaseDatabase? firebaseDatabase,
    Duration? timeout,
    VersionPolicySignatureVerifier? signatureVerifier,
  })  : // Named param (`database`) is public API; the private field below
        // can't share that name, so `prefer_initializing_formals` doesn't
        // apply here -- same reasoning as `SyncCursorService`/
        // `DeviceRevocationService`.
        _database = database, // ignore: prefer_initializing_formals
        _firebaseDatabaseOverride = firebaseDatabase,
        // Same reasoning as every other wrapper's `_timeout`: a Realtime
        // Database read queued offline never completes at all, so this
        // bounds it -- a timeout is just another failure mode, caught
        // below like any other Realtime Database error.
        _timeout = timeout ?? const Duration(seconds: 10),
        _signatureVerifier =
            signatureVerifier ?? VersionPolicySignatureVerifier();

  final AppDatabase _database;
  final FirebaseDatabase? _firebaseDatabaseOverride;
  final Duration _timeout;
  final VersionPolicySignatureVerifier _signatureVerifier;

  // Resolved lazily, mirroring every other wrapper's `_firebaseDatabase` --
  // so constructing a VersionPolicyService with no override never touches
  // a live Realtime Database instance until [refresh] is actually called.
  FirebaseDatabase get _firebaseDatabase =>
      _firebaseDatabaseOverride ?? FirebaseDatabase.instance;

  /// Best-effort read of `config/version_policy`, bounded by [_timeout].
  /// On success, overwrites the local cache row (`EARS-VER-3`). On any
  /// failure or timeout, leaves the existing cache untouched and never
  /// throws (`EARS-VER-4`) -- the same shape as
  /// `DeviceRevocationService.pullRevocations`.
  Future<void> refresh() async {
    final Object? raw;
    try {
      raw = await readVersionPolicyData().timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.version_policy_refresh_failed',
        cause: e,
      );
      return;
    }

    final parsed = _parse(raw);
    if (parsed == null) {
      // Malformed/absent payload -- not a thrown error, but still "no
      // usable policy was fetched": leave the existing cache untouched,
      // same as any other failure (`EARS-VER-4`).
      ObservabilityService.instance.logError(
        'firebase.version_policy_refresh_failed',
        cause: 'malformed or absent config/version_policy payload',
      );
      return;
    }

    // E14-T03 (FR-VER-011, EARS-VER-17): fail-CLOSED at the signature check
    // itself -- an invalid/missing signature is treated exactly like a
    // malformed payload above (no cache write, existing cache untouched),
    // never as "trust it anyway". This composes with `EvaluateVersionStateUseCase`'s
    // pre-existing fail-open default (no valid cached policy -> UP_TO_DATE)
    // rather than inventing a stricter new failure mode.
    final signatureValid = await _signatureVerifier.verify(
      minimumSupportedBuild: parsed.minimumSupportedBuild,
      currentBuild: parsed.currentBuild,
      updateAvailableBuild: parsed.updateAvailableBuild,
      updatedAt: parsed.updatedAt,
      signatureBase64: parsed.signature,
    );
    if (!signatureValid) {
      ObservabilityService.instance.logError(
        'firebase.version_policy_signature_invalid',
        cause: 'config/version_policy payload failed signature verification',
      );
      return;
    }

    // E14-B06 round 2 (F2): this local Drift write used to sit OUTSIDE the
    // try/catch above -- a locked/full/corrupt local database would throw
    // straight out of `refresh()`, breaking `EARS-VER-4`'s "never throws"
    // contract for real (the fetch succeeding was never the only way this
    // method could fail). Folded into the same catch-and-log,
    // never-rethrow shape as the fetch above, so `refresh()` is actually
    // total, not just documented as total.
    try {
      await _database
          .into(_database.versionPolicyCache)
          .insertOnConflictUpdate(
            VersionPolicyCacheCompanion.insert(
              id: const Value(_cacheRowId),
              minimumSupportedBuild: parsed.minimumSupportedBuild,
              currentBuild: parsed.currentBuild,
              updateAvailableBuild: parsed.updateAvailableBuild,
              signature: parsed.signature,
              updatedAt: parsed.updatedAt,
            ),
          );
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.version_policy_cache_write_failed',
        cause: e,
      );
    }
  }

  /// Performs the actual Realtime Database read. Split out from [refresh]
  /// deliberately -- `FirebaseDatabase`/`DatabaseReference` need a live
  /// platform-channel test harness to construct in tests, so tests seam
  /// here instead (mirrors `DeviceRevocationService.readDevicesData`).
  Future<Object?> readVersionPolicyData() async {
    final snapshot =
        await _firebaseDatabase.ref(FirebasePaths.versionPolicy()).get();
    return snapshot.value;
  }

  /// The offline-usable read `E14-T02`'s state machine consumes
  /// (`EARS-VER-5`). Returns `null` if [refresh] has never once succeeded.
  Future<VersionPolicy?> cached() async {
    final row = await (_database.select(_database.versionPolicyCache)
          ..where((t) => t.id.equals(_cacheRowId)))
        .getSingleOrNull();
    if (row == null) return null;
    return VersionPolicy(
      minimumSupportedBuild: row.minimumSupportedBuild,
      currentBuild: row.currentBuild,
      updateAvailableBuild: row.updateAvailableBuild,
      signature: row.signature,
      updatedAt: row.updatedAt,
    );
  }

  /// Parses the raw `config/version_policy` snapshot value into a
  /// [VersionPolicy], applying the FR-FB-001 boundary guard to whatever
  /// keys the payload carries (task §6 Risks: this node has no write path
  /// in this build, so this read-side call is the only place the guard
  /// exercises this node's allow-list). Returns `null` for anything that
  /// is not a well-formed payload -- never throws.
  ///
  /// Unlike every write-side call of `assertAllowedFields` in this
  /// codebase (where an offending key is this app's OWN programming error
  /// and must propagate loudly, never get swallowed as "just another
  /// Firebase error"), a payload here comes from the remote publisher, not
  /// from a local caller this codebase controls -- so a boundary
  /// violation on this read path is treated the same as any other
  /// malformed payload: logged, and folded into "no usable policy was
  /// fetched" (`EARS-VER-4`'s own "never throws" contract), never
  /// rethrown.
  static VersionPolicy? _parse(Object? raw) {
    if (raw is! Map) return null;
    final data = raw.map((key, value) => MapEntry(key.toString(), value));

    try {
      FirebaseBoundary.assertAllowedFields(
        FirebaseNodeKind.versionPolicy,
        data,
      );
    } on FirebaseBoundaryViolation catch (e) {
      ObservabilityService.instance.logError(
        'firebase.version_policy_boundary_violation',
        cause: e,
      );
      return null;
    }

    final minimumSupportedBuild = data['minimumSupportedBuild'];
    final currentBuild = data['currentBuild'];
    final updateAvailableBuild = data['updateAvailableBuild'];
    final signature = data['signature'];
    final updatedAt = data['updatedAt'];

    if (minimumSupportedBuild is! int ||
        currentBuild is! int ||
        updateAvailableBuild is! int ||
        signature is! String ||
        updatedAt is! int) {
      return null;
    }

    return VersionPolicy(
      minimumSupportedBuild: minimumSupportedBuild,
      currentBuild: currentBuild,
      updateAvailableBuild: updateAvailableBuild,
      signature: signature,
      updatedAt: updatedAt,
    );
  }
}
