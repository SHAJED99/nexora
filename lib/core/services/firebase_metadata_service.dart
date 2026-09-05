// core/services — E01-T02: best-effort account↔device metadata write to
// Firebase Realtime Database.
//
// Uses Realtime Database rather than Firestore: Firestore now requires the
// project to be on the Blaze (pay-as-you-go) billing plan just to
// provision a database, even within its free-tier quota. The human
// explicitly declined enabling billing for this project — RTDB has no such
// requirement and covers this task's needs (one small JSON object per
// device, no queries beyond direct key lookup). Revisit if a future epic
// needs Firestore's richer query model and billing is reconsidered then.
//
// FR-FB-001/002 (non-negotiable boundary): Firebase may only ever hold
// device-registry metadata — never plaintext, keys, recordings, or
// location. This service writes exactly the four fields below and no
// others; adding a field here needs its own FR-FB-001 justification, not
// "might be useful later" (see task E01-T02 §6 Risks).
//
// ADR-0005 (independent sessions): this is purely an additive, queryable
// account-id <-> device-id link. It never feeds back into local device
// identity/session state, and a failure here must never affect the
// offline-first local sign-in flow — see `registerDevice`.
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_paths.dart';

class FirebaseMetadataService {
  FirebaseMetadataService({FirebaseDatabase? database, Duration? timeout})
      : _databaseOverride = database,
        _timeout = timeout ?? const Duration(seconds: 10);

  final FirebaseDatabase? _databaseOverride;

  // `DatabaseReference.set()`'s Future only completes on server ack — with
  // no connectivity it queues the write and never completes at all. §4's
  // "fire-and-forget" promise is broken if the caller awaits that
  // indefinitely, so this bounds it: a timeout is just another failure
  // mode caught below, same as any other Realtime Database error.
  final Duration _timeout;

  // Resolved lazily, mirroring `GoogleAuthService._firebaseAuth` — so
  // constructing a `FirebaseMetadataService()` with no override never
  // touches a live Realtime Database instance until a write is actually
  // attempted.
  FirebaseDatabase get _database => _databaseOverride ?? FirebaseDatabase.instance;

  /// Best-effort registration of [deviceId] under [uid]'s account, for
  /// FR-AUTH-004 multi-device visibility.
  ///
  /// Never throws: any Realtime Database error (including being offline,
  /// or the existence check below failing) is caught and logged via
  /// [ObservabilityService] rather than propagated, since this must never
  /// block local-first sign-in (offline-first constitution). Fire-and-forget
  /// only — no retry queue (task §4).
  ///
  /// E11-T03: `createdAt` is now written only on the device's *first*
  /// registration; every registration (first or repeat) refreshes
  /// `lastSeenAt`. Previously both fields used `ServerValue.timestamp` on
  /// every call, so they were always equal and `createdAt` carried no real
  /// "first seen" meaning (carried review note, `E01-T02` §Run log).
  ///
  /// The whole read-decide-write sequence shares exactly ONE `.timeout(
  /// _timeout)` budget (below, wrapping [_registerDevice] as a whole) —
  /// not one timeout per operation, which would double the worst-case hang
  /// a prior review already bounded (`E01-T02`, task §6 Risks).
  Future<void> registerDevice(String uid, String deviceId) async {
    try {
      await _registerDevice(uid, deviceId).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.device_registration_failed',
        cause: e,
      );
    }
  }

  /// Decides whether [deviceId] has registered before, builds the payload
  /// accordingly, and writes it. Split out from [registerDevice] only so
  /// the whole sequence can share one timeout/catch (above) instead of one
  /// per operation.
  ///
  /// EARS-FB-2 (E11-T01): the payload is checked against
  /// [FirebaseBoundary.assertAllowedFields] before the write — a boundary
  /// violation is a programming error, since both branches below only ever
  /// build payloads from this method's own hardcoded field set (task §6
  /// Risks).
  Future<void> _registerDevice(String uid, String deviceId) async {
    bool isFirstRegistration;
    try {
      final existing = await readDeviceMetadata(uid, deviceId);
      // "First registration" means "this node needs createdAt": either the
      // node does not exist yet, or it exists but is missing createdAt (a
      // prior first-registration whose existence read failed/threw, back
      // when this branch unconditionally treated a failed read as "not
      // first" and never backfilled it -- E11-T03 round-2, per review).
      // Both cases are safe to include createdAt for: `.update()` merges,
      // so a node that already has a real createdAt is simply left alone
      // by the `existing == null` case above and never reaches here.
      isFirstRegistration =
          existing == null || (existing is Map && !existing.containsKey('createdAt'));
    } catch (_) {
      // The read itself failed/threw: existence is unknown, so treat this
      // as a first registration -- the safer of the two wrong guesses.
      // Guessing "not first" (the pre-fix behavior) was safe for an
      // *existing* device (`.update()` merges, createdAt survives) but
      // catastrophic for a genuinely first-ever registration: it would
      // create a node with no createdAt at all, and every later
      // registration would then see a non-null node and repeat the same
      // omission forever, permanently losing createdAt (E11-T03 round-2,
      // per review). Guessing "first" here trades that permanent loss for
      // a narrow, self-correcting cost: if the node actually already
      // exists and this happened to be the one registration whose read
      // failed, createdAt gets re-stamped with a fresh timestamp instead
      // of preserved -- a one-time "first seen" inaccuracy, not a stuck
      // node, and it cannot recur for that device once the read succeeds
      // again.
      isFirstRegistration = true;
    }
    final data = {
      'deviceId': deviceId,
      'lastSeenAt': ServerValue.timestamp,
      'platform': 'android',
      if (isFirstRegistration) 'createdAt': ServerValue.timestamp,
    };
    await guardedWriteDeviceMetadata(uid, deviceId, data);
  }

  /// E11-B04: the actual guard-then-write sequence, extracted so a test can
  /// drive it with an arbitrary payload — [_registerDevice] only ever
  /// builds a payload from its own hardcoded, already-safe field set (task
  /// §6 Risks), so there was previously no way to prove EARS-FB-2's
  /// ordering (guard before write, write never reached on violation)
  /// through the public API: every real call site is guaranteed to pass.
  /// `@visibleForTesting` — production behavior is unchanged (same guard
  /// call, same write call, same order); this only exposes the sequence to
  /// a test that wants to force a violation.
  @visibleForTesting
  Future<void> guardedWriteDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    FirebaseBoundary.assertAllowedFields(FirebaseNodeKind.device, data);
    await writeDeviceMetadata(uid, deviceId, data);
  }

  /// Best-effort existence check for the device node, used by
  /// [_registerDevice] to decide whether `createdAt` should be written.
  /// Split out for the same reason as [writeDeviceMetadata]: a raw,
  /// un-caught test seam (mirrors `SyncCursorService.readCursorData`) so
  /// tests observe/override it without a live platform channel. May throw
  /// on a genuine Realtime Database error — the caller decides what a
  /// failure means (see [_registerDevice]), this method does not swallow
  /// anything itself.
  ///
  /// Returns the raw node value (a `Map` once the device has a registry
  /// entry), or `null` if the node does not exist yet.
  Future<Object?> readDeviceMetadata(String uid, String deviceId) {
    return _database
        .ref(FirebasePaths.device(uid, deviceId))
        .get()
        .then((snapshot) => snapshot.value);
  }

  /// Performs the actual Realtime Database write. `.update()`, not `.set()`
  /// — a `.set()` would replace the whole node and, on a repeat
  /// registration, wipe the `createdAt` this task deliberately omits from
  /// the payload; `.update()` merges the given fields into any existing
  /// node (and still creates it, with just the given fields, when none
  /// exists yet), which is exactly what both the first and every later
  /// registration need. Split out from [_registerDevice] deliberately:
  /// `FirebaseDatabase`/`DatabaseReference` need a live platform-channel
  /// test harness to construct in tests, so tests seam here instead
  /// (mirrors `GoogleAuthService.signInAndGetAccountUid` — see that file's
  /// comments for the same reasoning).
  ///
  /// Path from [FirebasePaths.device] (E11-T01) — byte-identical to the
  /// inline `'users/$uid/devices/$deviceId'` this replaced (EARS-FB-3).
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return _database.ref(FirebasePaths.device(uid, deviceId)).update(data);
  }

  /// E12-T01 (`FR-RECOVER-001`): the whole-list reader `E12-T02`/`E12-T03`
  /// both need -- which device ids already exist under this account's own
  /// `users/$uid/devices` registry. Best-effort, same as every other method
  /// on this class: any Realtime Database error, a timeout, or malformed
  /// data all read as "no information" (an empty set), never a thrown
  /// error, since this is a hint no caller may block on (task §6 Risks).
  ///
  /// Mirrors `DeviceRevocationService.pullRevocations`'s exact
  /// timeout+catch-and-log wrapper around a raw read seam, plus a private
  /// pure extraction function -- not a new, competing whole-subtree reader.
  Future<Set<String>> readOwnDeviceIds(String uid) async {
    final Object? raw;
    try {
      raw = await readOwnDevicesData(uid).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.read_own_device_ids_failed',
        cause: e,
      );
      return const {};
    }
    return _extractDeviceIds(raw);
  }

  /// Performs the actual Realtime Database read of the whole
  /// `users/$uid/devices` subtree. Split out from [readOwnDeviceIds] for the
  /// same test-seam reason as [writeDeviceMetadata]/
  /// `DeviceRevocationService.readDevicesData`: `FirebaseDatabase`/
  /// `DatabaseReference` need a live platform-channel test harness to
  /// construct in tests, so tests seam here instead.
  Future<Object?> readOwnDevicesData(String uid) async {
    final snapshot = await _database.ref(FirebasePaths.devices(uid)).get();
    return snapshot.value;
  }

  /// Reads the set of device id keys out of the raw `users/$uid/devices`
  /// snapshot value. Absent or malformed data (anything that isn't a `Map`)
  /// reads as an empty set, never a thrown error -- mirrors
  /// `DeviceRevocationService._extractRevocationFlags`'s shape.
  static Set<String> _extractDeviceIds(Object? raw) {
    if (raw is! Map) return const {};
    return raw.keys.whereType<String>().toSet();
  }

  /// `E12-B02` (`FR-RECOVER-001`, `EARS-RECOVER-7`): the approving device's
  /// own side of the dedicated device-enrollment-grant channel
  /// (`FirebasePaths.deviceEnrollmentGrant`, `E12-B03`'s human-decided fix
  /// -- a new Firebase path, read directly by the enrolling device, never
  /// merged through `RelationshipSyncService.pull`/`ConflictResolver`).
  /// Writes once [approvedByDeviceId] (the approving device's own id, NOT
  /// the enrolling account's uid) approves [newDeviceId]'s enrollment.
  ///
  /// Deliberately does NOT touch `RelationshipSyncService.push` or
  /// `users/$uid/relationships/*` -- that channel and this one are
  /// independent (`E12-B03`'s "does not loosen `ConflictResolver
  /// .resolveTrust` for the general peer-relationship case" fence).
  ///
  /// Best-effort, same pattern as every other wrapper on this class: never
  /// throws, any Realtime Database error (including being offline, or a
  /// timeout) is caught and logged via [ObservabilityService].
  Future<void> writeEnrollmentGrant(
    String uid,
    String newDeviceId,
    String approvedByDeviceId,
  ) async {
    final data = {
      'approvedByDeviceId': approvedByDeviceId,
      'approvedAt': ServerValue.timestamp,
    };
    // The guard runs before the try below, not inside it -- a boundary
    // violation is a programming error and must propagate, not get caught
    // and logged as "just another Firebase error" (same reasoning as every
    // other wrapper on this class).
    FirebaseBoundary.assertAllowedFields(
      FirebaseNodeKind.deviceEnrollmentGrant,
      data,
    );
    try {
      await writeEnrollmentGrantData(uid, newDeviceId, data).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.write_enrollment_grant_failed',
        cause: e,
      );
    }
  }

  /// Performs the actual Realtime Database write. Split out from
  /// [writeEnrollmentGrant] for the same test-seam reason as
  /// [writeDeviceMetadata].
  ///
  /// Path from [FirebasePaths.deviceEnrollmentGrant] (`E12-B02`/`E12-B03`)
  /// -- `users/$uid/device_enrollment_grants/$newDeviceId`.
  Future<void> writeEnrollmentGrantData(
    String uid,
    String newDeviceId,
    Map<String, dynamic> data,
  ) {
    return _database
        .ref(FirebasePaths.deviceEnrollmentGrant(uid, newDeviceId))
        .set(data);
  }

  /// `E12-B03` (`FR-RECOVER-001`): the enrolling device's own side -- a
  /// plain existence/value check at the dedicated grant path, read
  /// DIRECTLY, never through `RelationshipSyncService.pull`/
  /// `ConflictResolver.resolveTrust`. An enrollment approval is an
  /// authorization GRANT from a trusted device to a specific new device,
  /// not a peer-trust OPINION to be reconciled -- `FR-MSG-007`'s "more
  /// restrictive state wins" does not apply here (`E12-B03`'s human
  /// decision, 2026-09-06).
  ///
  /// Best-effort, same pattern as every other reader on this class: any
  /// read failure, timeout, or malformed data reads as "not yet approved"
  /// (`false`), never a thrown error.
  Future<bool> readEnrollmentGrant(String uid, String newDeviceId) async {
    final Object? raw;
    try {
      raw = await readEnrollmentGrantData(uid, newDeviceId).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.read_enrollment_grant_failed',
        cause: e,
      );
      return false;
    }
    return raw is Map && raw['approvedByDeviceId'] is String;
  }

  /// Performs the actual Realtime Database read of
  /// `users/$uid/device_enrollment_grants/$newDeviceId`. Split out from
  /// [readEnrollmentGrant] for the same test-seam reason as
  /// [readOwnDevicesData].
  Future<Object?> readEnrollmentGrantData(String uid, String newDeviceId) {
    return _database
        .ref(FirebasePaths.deviceEnrollmentGrant(uid, newDeviceId))
        .get()
        .then((snapshot) => snapshot.value);
  }
}
