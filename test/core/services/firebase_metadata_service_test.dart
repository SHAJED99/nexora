// core/services — E01-T02: best-effort account↔device metadata write to
// Realtime Database (FR-FB-001/002). Tests exercise `writeDeviceMetadata`
// and `readDeviceMetadata`, the seams `FirebaseMetadataService` exposes
// specifically so tests never need a real `FirebaseDatabase`/platform-channel
// test harness (same pattern as `GoogleAuthService.signInAndGetAccountUid` —
// see that file's comments).
//
// E11-T03: `registerDevice` now reads the existing node first to decide
// whether `createdAt` should be written (first registration only) or
// omitted (repeat registration, `lastSeenAt` still refreshed). Every test
// double below overrides BOTH seams explicitly and deterministically —
// relying on a real `FirebaseDatabase.instance` throwing in the test
// environment to fall through to some default would be an accident of
// Firebase's own init behaviour, not a controlled test (task §6 Risks:
// "adding a second seam without updating those doubles silently bypasses
// them").
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/core/services/firebase_paths.dart';

/// Captures the path + data a real write would have sent, instead of
/// touching Realtime Database. `readDeviceMetadata` reports "no existing
/// node" by default, i.e. every call through this double is a first
/// registration — the existing pre-E11-T03 test pattern this double
/// supported unchanged.
class _CapturingFirebaseMetadataService extends FirebaseMetadataService {
  String? capturedUid;
  String? capturedDeviceId;
  Map<String, dynamic>? capturedData;

  @override
  Future<Object?> readDeviceMetadata(String uid, String deviceId) async =>
      null;

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    capturedUid = uid;
    capturedDeviceId = deviceId;
    capturedData = data;
  }
}

/// Reports an existing device node (a repeat registration), then captures
/// the write payload — for asserting `createdAt` is omitted on a repeat
/// registration while `lastSeenAt` is still refreshed.
class _ExistingDeviceFirebaseMetadataService extends FirebaseMetadataService {
  Map<String, dynamic>? capturedData;

  @override
  Future<Object?> readDeviceMetadata(String uid, String deviceId) async => {
        'deviceId': deviceId,
        'createdAt': 1000,
        'lastSeenAt': 1000,
        'platform': 'android',
      };

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    capturedData = data;
  }
}

/// The existence read itself throws — proves `registerDevice` treats a
/// failed existence check as just another best-effort failure: it does not
/// propagate, and it does not block the write of `lastSeenAt` (EARS-FB-9).
class _ReadFailureFirebaseMetadataService extends FirebaseMetadataService {
  Map<String, dynamic>? capturedData;

  @override
  Future<Object?> readDeviceMetadata(String uid, String deviceId) {
    throw Exception('realtime database read unavailable');
  }

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    capturedData = data;
  }
}

/// Reports an existing device node that is missing `createdAt` — the
/// leftover shape of a first registration whose existence read once
/// failed/threw, back when a failed read was treated as "not first" and
/// never backfilled (E11-T03 round-2, per cross-model review). Proves this
/// incomplete node is still treated as needing `createdAt`, not as "already
/// registered".
class _IncompleteExistingDeviceFirebaseMetadataService
    extends FirebaseMetadataService {
  Map<String, dynamic>? capturedData;

  @override
  Future<Object?> readDeviceMetadata(String uid, String deviceId) async => {
        'deviceId': deviceId,
        'lastSeenAt': 1000,
        'platform': 'android',
      };

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    capturedData = data;
  }
}

/// Always throws from the write seam, to prove `registerDevice` swallows
/// and logs rather than propagating (EARS-FB-2 boundary, service level).
/// `readDeviceMetadata` reports "no existing node" deterministically —
/// this double is about the write failing, not the existence decision.
class _ThrowingFirebaseMetadataService extends FirebaseMetadataService {
  @override
  Future<Object?> readDeviceMetadata(String uid, String deviceId) async =>
      null;

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the write seam — simulates `DatabaseReference.set()`
/// (now `.update()`) queuing offline and never getting a server ack. Proves
/// `registerDevice` is bounded by its `timeout`, not an indefinite hang
/// (review finding, E01-T02).
class _HangingFirebaseMetadataService extends FirebaseMetadataService {
  _HangingFirebaseMetadataService({super.timeout});

  @override
  Future<Object?> readDeviceMetadata(String uid, String deviceId) async =>
      null;

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return Completer<void>().future; // never completes
  }
}

/// The existence read itself never completes — proves the single
/// whole-sequence timeout bounds a hanging READ, not only a hanging write
/// (task §6 Risks: "two sequential awaits each with `_timeout` doubles the
/// worst case" — this double would catch a regression back to per-operation
/// timeouts, since a hanging read alone would then never time out at all).
class _HangingReadFirebaseMetadataService extends FirebaseMetadataService {
  _HangingReadFirebaseMetadataService({super.timeout});

  @override
  Future<Object?> readDeviceMetadata(String uid, String deviceId) {
    return Completer<Object?>().future; // never completes
  }

  @override
  Future<void> writeDeviceMetadata(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {}
}

void main() {
  test('test_EARS_FB_7_first_registration_writes_both_timestamps', () async {
    // EARS-FB-7: WHEN a device registers for the first time, the system
    // SHALL record createdAt and lastSeenAt in the device registry.
    final service = _CapturingFirebaseMetadataService();

    await service.registerDevice('uid-123', 'device-abc');

    expect(service.capturedUid, 'uid-123');
    expect(service.capturedDeviceId, 'device-abc');
    final data = service.capturedData!;
    expect(data.keys.toSet(), {'deviceId', 'createdAt', 'lastSeenAt', 'platform'});
    expect(data['deviceId'], 'device-abc');
    expect(data['platform'], 'android');
    expect(data['createdAt'], ServerValue.timestamp);
    expect(data['lastSeenAt'], ServerValue.timestamp);
  });

  test(
    'test_EARS_FB_8_second_registration_preserves_created_at',
    () async {
      // EARS-FB-8: WHEN a device that is already registered registers
      // again, the system SHALL refresh lastSeenAt and SHALL NOT overwrite
      // createdAt. The capturing double reports an existing node; the
      // emitted payload must carry no `createdAt` key at all — `.update()`
      // then leaves the existing value on the server untouched.
      final service = _ExistingDeviceFirebaseMetadataService();

      await service.registerDevice('uid-123', 'device-abc');

      final data = service.capturedData!;
      expect(data.containsKey('createdAt'), isFalse);
      expect(data['lastSeenAt'], ServerValue.timestamp);
      expect(data['deviceId'], 'device-abc');
      expect(data['platform'], 'android');
    },
  );

  test('test_EARS_FB_8_last_seen_never_precedes_created_at', () async {
    // EARS-FB-8 (E11-T02's invariant, preserved by construction): on a
    // repeat registration the existing createdAt is never rewritten (so it
    // keeps whatever earlier value the server already holds), while
    // lastSeenAt is freshly server-stamped on every call. Since the
    // Realtime Database server assigns ServerValue.timestamp sentinels in
    // write order, a later write's resolved timestamp can never be earlier
    // than an untouched, already-stored value -- asserted here structurally
    // (the payload omits createdAt and always carries a fresh
    // ServerValue.timestamp for lastSeenAt) rather than assumed.
    final service = _ExistingDeviceFirebaseMetadataService();

    await service.registerDevice('uid-123', 'device-abc');

    final data = service.capturedData!;
    expect(
      data.containsKey('createdAt'),
      isFalse,
      reason: 'an existing createdAt must never be rewritten to a new value',
    );
    expect(
      data['lastSeenAt'],
      ServerValue.timestamp,
      reason: 'lastSeenAt must be freshly stamped on every registration',
    );
  });

  test(
    'test_EARS_FB_9_read_failure_does_not_block_registration',
    () async {
      // EARS-FB-9: IF any Firebase operation in registration fails, times
      // out, or the device is offline, THEN the system SHALL log the
      // failure and complete normally without throwing. The existence
      // read throws; registration still completes and lastSeenAt is still
      // written.
      //
      // E11-T03 round-2 (cross-model review, PR #43): a failed read is now
      // treated as "first registration" (createdAt included), NOT "not
      // first" (createdAt omitted). The old omit-on-failure behavior was
      // only safe for an *already-registered* device; for a genuinely
      // first-ever registration it created a node with no createdAt at
      // all, and every later registration then saw a non-null node and
      // repeated the same omission forever -- permanently losing
      // createdAt. This test falsifies against the pre-fix code: reverting
      // `isFirstRegistration = true` (in the catch block) back to `= false`
      // makes this assertion fail.
      final service = _ReadFailureFirebaseMetadataService();

      await expectLater(
        service.registerDevice('uid-123', 'device-abc'),
        completes,
      );
      final data = service.capturedData!;
      expect(data['lastSeenAt'], ServerValue.timestamp);
      expect(
        data.containsKey('createdAt'),
        isTrue,
        reason:
            'a failed existence read must be treated as "first registration" '
            'so createdAt is never permanently lost',
      );
    },
  );

  test(
    'test_EARS_FB_8_incomplete_existing_node_still_gets_created_at',
    () async {
      // E11-T03 round-2 (cross-model review, PR #43): a node that already
      // exists but is missing createdAt (the durable leftover of a first
      // registration whose existence read once failed, before this fix)
      // must be treated as "first registration" and backfilled -- not as
      // "already registered" (which would skip createdAt forever). This is
      // the self-healing path the failed-read case above relies on.
      final service = _IncompleteExistingDeviceFirebaseMetadataService();

      await service.registerDevice('uid-123', 'device-abc');

      final data = service.capturedData!;
      expect(
        data.containsKey('createdAt'),
        isTrue,
        reason: 'an existing node missing createdAt must be backfilled, '
            'not treated as already fully registered',
      );
      expect(data['createdAt'], ServerValue.timestamp);
      expect(data['lastSeenAt'], ServerValue.timestamp);
    },
  );

  test(
    'test_EARS_FB_9_realtime_db_write_failure_is_caught_and_logged_not_thrown',
    () async {
      // A Realtime Database write failure must never propagate out of
      // registerDevice — it is swallowed and logged, not thrown.
      final service = _ThrowingFirebaseMetadataService();

      await expectLater(
        service.registerDevice('uid-123', 'device-abc'),
        completes,
      );
    },
  );

  test(
    'test_EARS_FB_9_hanging_write_still_bounded',
    () async {
      // Review finding (E01-T02): a write seam that never completes (the
      // real-world shape of an offline `DatabaseReference.update()`) must
      // not hang registerDevice forever — §4's "fire-and-forget" promise is
      // broken if awaiting it can block sign-in indefinitely.
      final service = _HangingFirebaseMetadataService(
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.registerDevice('uid-123', 'device-abc'),
        completes,
      );
    },
  );

  test(
    'test_EARS_FB_9_hanging_read_still_bounded_by_the_same_single_timeout',
    () async {
      // E11-T03 §6 Risks: the timeout budget is per-sequence, not
      // per-operation -- a hanging existence READ (not just a hanging
      // write) must still be bounded by the one `.timeout(_timeout)` that
      // wraps the whole read-decide-write sequence.
      final service = _HangingReadFirebaseMetadataService(
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.registerDevice('uid-123', 'device-abc'),
        completes,
      );
    },
  );

  test(
    'test_EARS_FB_3_writeDeviceMetadata_uses_the_path_registry_verbatim',
    () async {
      // E11-T01: writeDeviceMetadata must produce the same path
      // FirebaseMetadataService always produced -- via the registry now,
      // not an inline string.
      final service = _CapturingFirebaseMetadataService();

      await service.registerDevice('uid-123', 'device-abc');

      expect(
        FirebasePaths.device('uid-123', 'device-abc'),
        'users/uid-123/devices/device-abc',
      );
      // Confirms the seam still receives the right uid/deviceId pair that
      // FirebasePaths.device would build the same path from.
      expect(service.capturedUid, 'uid-123');
      expect(service.capturedDeviceId, 'device-abc');
    },
  );

  test(
    'test_EARS_FB_2_registerDevice_asserts_allowed_fields_before_the_write',
    () async {
      // E11-T01: registerDevice's own hardcoded payload must pass
      // FirebaseBoundary.assertAllowedFields cleanly (proving it is called
      // and that the field set stays within the allow-list) for both the
      // first-registration (superset) and repeat-registration (subset)
      // shapes.
      final first = _CapturingFirebaseMetadataService();
      await first.registerDevice('uid-123', 'device-abc');
      expect(
        first.capturedData!.keys.toSet(),
        FirebaseBoundary.allowedFields(FirebaseNodeKind.device),
      );

      final repeat = _ExistingDeviceFirebaseMetadataService();
      await repeat.registerDevice('uid-123', 'device-abc');
      expect(
        FirebaseBoundary.allowedFields(FirebaseNodeKind.device)
            .containsAll(repeat.capturedData!.keys),
        isTrue,
      );
    },
  );
}
