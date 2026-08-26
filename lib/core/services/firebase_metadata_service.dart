// core/services — E01-T02: best-effort account↔device metadata write to
// Firestore.
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexora/core/observability/observability_service.dart';

class FirebaseMetadataService {
  FirebaseMetadataService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  // Resolved lazily, mirroring `GoogleAuthService._firebaseAuth` — so
  // constructing a `FirebaseMetadataService()` with no override never
  // touches a live Firestore instance until a write is actually attempted.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Best-effort registration of [deviceId] under [uid]'s account, for
  /// FR-AUTH-004 multi-device visibility.
  ///
  /// Never throws: any Firestore error (including being offline) is caught
  /// and logged via [ObservabilityService] rather than propagated, since
  /// this must never block local-first sign-in (offline-first
  /// constitution). Fire-and-forget only — no retry queue (task §4).
  Future<void> registerDevice(String uid, String deviceId) async {
    try {
      await writeDeviceMetadata(uid, deviceId, {
        'deviceId': deviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      });
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.device_registration_failed',
        cause: e,
      );
    }
  }

  /// Performs the actual Firestore write. Split out from [registerDevice]
  /// deliberately: `FirebaseFirestore`/`DocumentReference` need a live
  /// platform-channel test harness to construct in tests, so tests seam
  /// here instead (mirrors `GoogleAuthService.signInAndGetAccountUid` —
  /// see that file's comments for the same reasoning).
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .set(data);
  }
}
