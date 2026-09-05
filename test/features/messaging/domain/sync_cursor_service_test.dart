// E05-T04 -- SyncCursorService tests.
//
// Local read/write tests use a real in-memory AppDatabase (fast, no mocking
// needed for Drift). Firebase read/write tests use the same test-seam
// pattern as firebase_metadata_service_test.dart -- subclass the service and
// override the seam methods (`writeCursorData`/`readCursorData`) instead of
// touching a real `FirebaseDatabase`/platform channel.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_paths.dart';
import 'package:nexora/features/messaging/domain/sync_cursor_service.dart';

/// Captures the path components + data a real write would have sent.
class _CapturingSyncCursorService extends SyncCursorService {
  _CapturingSyncCursorService({required super.localDeviceId, required super.database});

  String? capturedUid;
  SyncCursor? capturedCursor;
  Map<String, dynamic>? capturedData;

  @override
  Future<void> writeCursorData(
    String uid,
    SyncCursor cursor,
    Map<String, dynamic> data,
  ) async {
    capturedUid = uid;
    capturedCursor = cursor;
    capturedData = data;
  }
}

/// Always throws from the write seam, to prove `writeCursorToFirebase`
/// swallows and logs rather than propagating (EARS-MSG-6).
class _ThrowingWriteSyncCursorService extends SyncCursorService {
  _ThrowingWriteSyncCursorService({
    required super.localDeviceId,
    required super.database,
  });

  @override
  Future<void> writeCursorData(
    String uid,
    SyncCursor cursor,
    Map<String, dynamic> data,
  ) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the write seam -- simulates `DatabaseReference.set()`
/// queuing offline and never getting a server ack. Proves the write is
/// bounded by `timeout`, not an indefinite hang.
class _HangingWriteSyncCursorService extends SyncCursorService {
  _HangingWriteSyncCursorService({
    required super.localDeviceId,
    required super.database,
    required super.timeout,
  });

  @override
  Future<void> writeCursorData(
    String uid,
    SyncCursor cursor,
    Map<String, dynamic> data,
  ) {
    return Completer<void>().future; // never completes
  }
}

/// Always throws from the read seam, to prove
/// `readRemoteCursorFromFirebase` returns `null` rather than propagating.
class _ThrowingReadSyncCursorService extends SyncCursorService {
  _ThrowingReadSyncCursorService({
    required super.localDeviceId,
    required super.database,
  });

  @override
  Future<Object?> readCursorData(
    String uid,
    String remoteDeviceId,
    String conversationId,
  ) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the read seam -- proves the read is bounded by
/// `timeout` and returns `null` rather than hanging forever.
class _HangingReadSyncCursorService extends SyncCursorService {
  _HangingReadSyncCursorService({
    required super.localDeviceId,
    required super.database,
    required super.timeout,
  });

  @override
  Future<Object?> readCursorData(
    String uid,
    String remoteDeviceId,
    String conversationId,
  ) {
    return Completer<Object?>().future; // never completes
  }
}

/// Returns well-formed cursor data from the read seam, exactly the field
/// set `writeCursorToFirebase` writes.
class _RespondingReadSyncCursorService extends SyncCursorService {
  _RespondingReadSyncCursorService({
    required super.localDeviceId,
    required super.database,
  });

  @override
  Future<Object?> readCursorData(
    String uid,
    String remoteDeviceId,
    String conversationId,
  ) async {
    return {
      'localDeviceId': remoteDeviceId,
      'remoteDeviceId': super.localDeviceId,
      'conversationId': conversationId,
      'lastConfirmedSequenceNumber': 42,
      'updatedAt': 5000,
    };
  }
}

AppDatabase _openTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  group('local read/write', () {
    test(
      'test_EARS_MSG_5_cursor_advances_monotonically',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service =
            SyncCursorService(localDeviceId: 'device-A', database: db);

        await service.recordLocalProgress('conv-1', 'device-B', 3);
        await service.recordLocalProgress('conv-1', 'device-B', 7);

        final cursor = await service.cursorFor('conv-1', 'device-B');
        expect(cursor, isNotNull);
        expect(cursor!.lastConfirmedSequenceNumber, 7);
      },
    );

    test(
      'test_EARS_MSG_5_out_of_order_older_sequence_does_not_regress_cursor',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service =
            SyncCursorService(localDeviceId: 'device-A', database: db);

        await service.recordLocalProgress('conv-1', 'device-B', 10);
        // A delayed/out-of-order call with an older sequence number must
        // not move the cursor backward.
        await service.recordLocalProgress('conv-1', 'device-B', 4);

        final cursor = await service.cursorFor('conv-1', 'device-B');
        expect(cursor!.lastConfirmedSequenceNumber, 10);
      },
    );

    test(
      'test_EARS_MSG_5_concurrent_calls_do_not_regress_cursor',
      () async {
        // Round-1 review finding: recordLocalProgress used to do a
        // read-then-write (a `cursorFor` guard, then a separate write) with
        // an `await` in between, so two overlapping calls could both read
        // the stale row before either wrote -- a lost update. Reviewer
        // demonstrated this concretely with exactly this scenario
        // (concurrent sequence numbers 10 and 4 on the same conversation/
        // device pair), which left the cursor at 4 instead of 10 on the
        // buggy code. The fix collapses the guard + write into a single
        // upsert statement (see recordLocalProgress's doc comment), so
        // regardless of which of the two concurrent calls the database
        // durably applies first, the higher sequence number always wins.
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service =
            SyncCursorService(localDeviceId: 'device-A', database: db);

        await Future.wait([
          service.recordLocalProgress('conv-1', 'device-B', 10),
          service.recordLocalProgress('conv-1', 'device-B', 4),
        ]);

        final cursor = await service.cursorFor('conv-1', 'device-B');
        expect(cursor, isNotNull);
        expect(cursor!.lastConfirmedSequenceNumber, 10);
      },
    );

    test(
      'cursorFor returns null when no progress has been recorded yet',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service =
            SyncCursorService(localDeviceId: 'device-A', database: db);

        expect(await service.cursorFor('conv-1', 'device-B'), isNull);
      },
    );

    test(
      'recordLocalProgress keeps separate cursors per remote device and per conversation',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service =
            SyncCursorService(localDeviceId: 'device-A', database: db);

        await service.recordLocalProgress('conv-1', 'device-B', 5);
        await service.recordLocalProgress('conv-1', 'device-C', 9);
        await service.recordLocalProgress('conv-2', 'device-B', 2);

        expect(
          (await service.cursorFor('conv-1', 'device-B'))!
              .lastConfirmedSequenceNumber,
          5,
        );
        expect(
          (await service.cursorFor('conv-1', 'device-C'))!
              .lastConfirmedSequenceNumber,
          9,
        );
        expect(
          (await service.cursorFor('conv-2', 'device-B'))!
              .lastConfirmedSequenceNumber,
          2,
        );
      },
    );
  });

  group('Firebase write', () {
    test('test_only_metadata_fields_written_to_firebase', () async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final service =
          _CapturingSyncCursorService(localDeviceId: 'device-A', database: db);

      await service.recordLocalProgress('conv-1', 'device-B', 7);
      final cursor = (await service.cursorFor('conv-1', 'device-B'))!;

      await service.writeCursorToFirebase('uid-123', cursor);

      expect(service.capturedUid, 'uid-123');
      final data = service.capturedData!;
      // Exactly the allowed field set -- device/conversation ids +
      // sequence number, nothing beyond it (FR-FB-002).
      expect(
        data.keys.toSet(),
        {
          'localDeviceId',
          'remoteDeviceId',
          'conversationId',
          'lastConfirmedSequenceNumber',
          'updatedAt',
        },
      );
      expect(data['localDeviceId'], 'device-A');
      expect(data['remoteDeviceId'], 'device-B');
      expect(data['conversationId'], 'conv-1');
      expect(data['lastConfirmedSequenceNumber'], 7);
      expect(data['updatedAt'], isA<int>());
    });

    test(
      'test_EARS_FB_2_writeCursorToFirebase_asserts_allowed_fields_before_the_try_block',
      () async {
        // E11-T01: writeCursorToFirebase's own payload must match the
        // boundary's allow-list exactly, and the guard call must sit
        // outside the existing best-effort try/catch (task §6 Risks) --
        // verified here by comparing the captured field set to
        // FirebaseBoundary's registered allow-list.
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _CapturingSyncCursorService(
          localDeviceId: 'device-A',
          database: db,
        );
        await service.recordLocalProgress('conv-1', 'device-B', 7);
        final cursor = (await service.cursorFor('conv-1', 'device-B'))!;

        await service.writeCursorToFirebase('uid-123', cursor);

        expect(
          service.capturedData!.keys.toSet(),
          FirebaseBoundary.allowedFields(FirebaseNodeKind.syncCursor),
        );
      },
    );

    test(
      'test_EARS_FB_2_a_forbidden_field_never_reaches_the_real_write_seam',
      () async {
        // E11-B04: the test above proves writeCursorToFirebase's own
        // hardcoded payload is always allow-list-safe -- it cannot prove
        // the GUARD is what's keeping it safe, since that payload can
        // never actually violate the allow-list. This drives the real
        // guard-then-write sequence (guardedWriteCursorData, called by
        // production code exactly as writeCursorToFirebase calls it) with
        // a payload that DOES violate the allow-list, confirming both that
        // FirebaseBoundaryViolation is thrown AND that the real write seam
        // (writeCursorData) was never reached.
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _CapturingSyncCursorService(
          localDeviceId: 'device-A',
          database: db,
        );
        const cursor = SyncCursor(
          localDeviceId: 'device-A',
          remoteDeviceId: 'device-B',
          conversationId: 'conv-1',
          lastConfirmedSequenceNumber: 1,
          updatedAt: 0,
        );

        await expectLater(
          () => service.guardedWriteCursorData(
            'uid-123',
            cursor,
            {'localDeviceId': 'device-A', 'plaintext': 'leak'},
          ),
          throwsA(isA<FirebaseBoundaryViolation>()),
        );

        expect(
          service.capturedData,
          isNull,
          reason: 'writeCursorData must never be reached when the guard '
              'throws',
        );
      },
    );

    test(
      'test_EARS_MSG_6_firebase_write_failure_caught_not_thrown',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _ThrowingWriteSyncCursorService(
          localDeviceId: 'device-A',
          database: db,
        );
        const cursor = SyncCursor(
          localDeviceId: 'device-A',
          remoteDeviceId: 'device-B',
          conversationId: 'conv-1',
          lastConfirmedSequenceNumber: 7,
          updatedAt: 1000,
        );

        await expectLater(
          service.writeCursorToFirebase('uid-123', cursor),
          completes,
        );
      },
    );

    test(
      'a never-completing Firebase write is bounded by timeout, not hung',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _HangingWriteSyncCursorService(
          localDeviceId: 'device-A',
          database: db,
          timeout: const Duration(milliseconds: 50),
        );
        const cursor = SyncCursor(
          localDeviceId: 'device-A',
          remoteDeviceId: 'device-B',
          conversationId: 'conv-1',
          lastConfirmedSequenceNumber: 7,
          updatedAt: 1000,
        );

        await expectLater(
          service.writeCursorToFirebase('uid-123', cursor),
          completes,
        );
      },
    );
  });

  group('Firebase read', () {
    test(
      'test_EARS_MSG_6_firebase_read_timeout_returns_null_not_hangs',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _HangingReadSyncCursorService(
          localDeviceId: 'device-A',
          database: db,
          timeout: const Duration(milliseconds: 50),
        );

        final result = await service.readRemoteCursorFromFirebase(
          'uid-123',
          'device-B',
          'conv-1',
        );

        expect(result, isNull);
      },
    );

    test(
      'a throwing Firebase read returns null rather than propagating',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _ThrowingReadSyncCursorService(
          localDeviceId: 'device-A',
          database: db,
        );

        final result = await service.readRemoteCursorFromFirebase(
          'uid-123',
          'device-B',
          'conv-1',
        );

        expect(result, isNull);
      },
    );

    test(
      'a well-formed Firebase read returns the remote cursor',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final service = _RespondingReadSyncCursorService(
          localDeviceId: 'device-A',
          database: db,
        );

        final result = await service.readRemoteCursorFromFirebase(
          'uid-123',
          'device-B',
          'conv-1',
        );

        expect(result, isNotNull);
        expect(result!.lastConfirmedSequenceNumber, 42);
        expect(result.conversationId, 'conv-1');
      },
    );
  });

  group('E11-T01 path registry', () {
    test(
      'test_EARS_FB_3_write_and_read_paths_are_byte_identical_to_the_original',
      () {
        // Byte-identical to SyncCursorService._cursorPath's original inline
        // path: 'users/$uid/sync_cursors/$writerDeviceId/$conversationId/$aboutDeviceId'.
        //
        // writeCursorData writes at (localDeviceId, conversationId,
        // remoteDeviceId) -- this device is the writer, the remote device is
        // "about".
        expect(
          FirebasePaths.syncCursor(
            'uid-123',
            'device-A',
            'conv-1',
            'device-B',
          ),
          'users/uid-123/sync_cursors/device-A/conv-1/device-B',
        );

        // readCursorData reads at (remoteDeviceId, conversationId,
        // localDeviceId) -- the remote device is the writer of *its own*
        // cursor entry, this device is "about" from that entry's point of
        // view. Argument order must not be transposed (task §6 Risks).
        expect(
          FirebasePaths.syncCursor(
            'uid-123',
            'device-B',
            'conv-1',
            'device-A',
          ),
          'users/uid-123/sync_cursors/device-B/conv-1/device-A',
        );
      },
    );
  });
}
