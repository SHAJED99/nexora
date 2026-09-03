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
  /// Never throws: any Realtime Database error (including being offline)
  /// is caught and logged via [ObservabilityService] rather than
  /// propagated, since this must never block local-first sign-in
  /// (offline-first constitution). Fire-and-forget only — no retry queue
  /// (task §4).
  ///
  /// EARS-FB-2 (E11-T01): the payload is checked against
  /// [FirebaseBoundary.assertAllowedFields] *before* the `try` below, not
  /// inside it — a boundary violation is a programming error and must
  /// propagate, not get caught and logged as "just another Firebase error"
  /// (task §6 Risks).
  Future<void> registerDevice(String uid, String deviceId) async {
    final data = {
      'deviceId': deviceId,
      'createdAt': ServerValue.timestamp,
      'lastSeenAt': ServerValue.timestamp,
      'platform': 'android',
    };
    FirebaseBoundary.assertAllowedFields(FirebaseNodeKind.device, data);
    try {
      await writeDeviceMetadata(uid, deviceId, data).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.device_registration_failed',
        cause: e,
      );
    }
  }

  /// Performs the actual Realtime Database write. Split out from
  /// [registerDevice] deliberately: `FirebaseDatabase`/`DatabaseReference`
  /// need a live platform-channel test harness to construct in tests, so
  /// tests seam here instead (mirrors
  /// `GoogleAuthService.signInAndGetAccountUid` — see that file's comments
  /// for the same reasoning).
  ///
  /// Path from [FirebasePaths.device] (E11-T01) — byte-identical to the
  /// inline `'users/$uid/devices/$deviceId'` this replaced (EARS-FB-3).
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return _database.ref(FirebasePaths.device(uid, deviceId)).set(data);
  }
}
