// E11-T05 -- RelationshipSyncService tests.
//
// Local read/write tests use a real in-memory AppDatabase (fast, no mocking
// needed for Drift) through RelationshipRepository. Firebase read/write
// tests use the same test-seam pattern as
// device_revocation_service_test.dart -- subclass the service and override
// the seam methods (`writeRelationshipData`/`readRelationshipsData`)
// instead of touching a real `FirebaseDatabase`/platform channel.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_paths.dart';
import 'package:nexora/core/services/relationship_sync_service.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// Captures the uid/deviceId/data a real write would have sent.
class _CapturingRelationshipSyncService extends RelationshipSyncService {
  _CapturingRelationshipSyncService({required super.repository});

  String? capturedUid;
  String? capturedDeviceId;
  Map<String, dynamic>? capturedData;

  @override
  Future<void> writeRelationshipData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    capturedUid = uid;
    capturedDeviceId = deviceId;
    capturedData = data;
  }
}

/// Proves `push` is local-first (EARS-FB-14): the Firebase write seam
/// checks, at the moment it is called, whether the local row already
/// reflects the new state -- `push` must await the local write before ever
/// reaching this seam.
class _OrderRecordingRelationshipSyncService extends RelationshipSyncService {
  _OrderRecordingRelationshipSyncService({required super.repository})
      : _repositoryRef = repository;

  final RelationshipRepository _repositoryRef;
  RelationshipState? localStateWhenFirebaseWriteRan;
  var firebaseWriteCalls = 0;

  @override
  Future<void> writeRelationshipData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    firebaseWriteCalls++;
    final row = await _repositoryRef.get(deviceId);
    localStateWhenFirebaseWriteRan = row?.state;
  }
}

/// Always throws from the write seam, to prove `push` swallows and logs
/// rather than propagating (EARS-FB-14).
class _ThrowingWriteRelationshipSyncService extends RelationshipSyncService {
  _ThrowingWriteRelationshipSyncService({required super.repository});

  @override
  Future<void> writeRelationshipData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the write seam -- simulates `DatabaseReference.set()`
/// queuing offline and never getting a server ack. Proves the write is
/// bounded by `timeout`, not an indefinite hang.
class _HangingWriteRelationshipSyncService extends RelationshipSyncService {
  _HangingWriteRelationshipSyncService({
    required super.repository,
    required super.timeout,
  });

  @override
  Future<void> writeRelationshipData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return Completer<void>().future; // never completes
  }
}

/// Always throws from the read seam, to prove `pull` returns rather than
/// propagating.
class _ThrowingReadRelationshipSyncService extends RelationshipSyncService {
  _ThrowingReadRelationshipSyncService({required super.repository});

  @override
  Future<Object?> readRelationshipsData(String uid) {
    throw Exception('realtime database unavailable');
  }
}

/// Never completes from the read seam -- proves the read is bounded by
/// `timeout` and returns rather than hanging forever.
class _HangingReadRelationshipSyncService extends RelationshipSyncService {
  _HangingReadRelationshipSyncService({
    required super.repository,
    required super.timeout,
  });

  @override
  Future<Object?> readRelationshipsData(String uid) {
    return Completer<Object?>().future; // never completes
  }
}

/// Returns a fixed raw `users/$uid/relationships` snapshot from the read
/// seam.
class _RespondingReadRelationshipSyncService extends RelationshipSyncService {
  _RespondingReadRelationshipSyncService({
    required super.repository,
    required this.response,
  });

  final Object? response;

  @override
  Future<Object?> readRelationshipsData(String uid) async => response;
}

AppDatabase _openTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  group('local push + repository state', () {
    test(
      'test_EARS_FB_14_push_writes_local_first_then_best_effort_remote',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service =
            _OrderRecordingRelationshipSyncService(repository: repository);

        await service.push('uid-123', 'device-B', RelationshipState.blocked);

        final stored = await repository.get('device-B');
        expect(stored?.state, RelationshipState.blocked);
        expect(service.firebaseWriteCalls, 1);
        // The local row already reflected the new state by the time the
        // Firebase write seam ran -- proves local-first ordering, not just
        // "both eventually happened".
        expect(
          service.localStateWhenFirebaseWriteRan,
          RelationshipState.blocked,
        );
      },
    );

    test(
      'test_EARS_FB_14_remote_failure_does_not_throw_or_revert_local',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service =
            _ThrowingWriteRelationshipSyncService(repository: repository);

        await expectLater(
          service.push('uid-123', 'device-B', RelationshipState.trusted),
          completes,
        );
        // The local write still happened even though Firebase failed.
        final stored = await repository.get('device-B');
        expect(stored?.state, RelationshipState.trusted);
      },
    );

    test(
      'a never-completing Firebase write is bounded by timeout, not hung',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service = _HangingWriteRelationshipSyncService(
          repository: repository,
          timeout: const Duration(milliseconds: 50),
        );

        await expectLater(
          service.push('uid-123', 'device-B', RelationshipState.allowed),
          completes,
        );
      },
    );
  });

  group('Firebase write (push)', () {
    test('writes only state + updatedAt to Firebase, state as .name string',
        () async {
      final db = _openTestDatabase();
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      final service =
          _CapturingRelationshipSyncService(repository: repository);

      await service.push('uid-123', 'device-B', RelationshipState.blocked);

      expect(service.capturedUid, 'uid-123');
      expect(service.capturedDeviceId, 'device-B');
      expect(
        service.capturedData!.keys.toSet(),
        {'state', 'updatedAt'},
      );
      expect(service.capturedData!['state'], 'blocked');
    });

    test(
      'test_EARS_FB_16_writeRelationshipData_asserts_allowed_fields_before_the_try_block',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service =
            _CapturingRelationshipSyncService(repository: repository);

        await service.push('uid-123', 'device-B', RelationshipState.trusted);

        expect(
          service.capturedData!.keys.toSet(),
          FirebaseBoundary.allowedFields(FirebaseNodeKind.relationship),
        );
      },
    );

    test(
      'test_EARS_FB_16_boundary_rejects_extra_relationship_field',
      () {
        expect(
          () => FirebaseBoundary.assertAllowedFields(
            FirebaseNodeKind.relationship,
            const {
              'state': 'trusted',
              'updatedAt': 12345,
              'extraField': 'not allowed',
            },
          ),
          throwsA(isA<FirebaseBoundaryViolation>()),
        );
      },
    );
  });

  group('pull', () {
    test(
      'test_EARS_FB_15_pull_merges_to_more_restrictive_state',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        await repository.upsert('device-B', RelationshipState.trusted);
        final service = _RespondingReadRelationshipSyncService(
          repository: repository,
          response: {
            'device-B': {'state': 'blocked', 'updatedAt': 2000},
          },
        );

        await service.pull('uid-123');

        final stored = await repository.get('device-B');
        expect(stored?.state, RelationshipState.blocked);
      },
    );

    test(
      'test_EARS_FB_15_local_more_restrictive_than_remote_stays_local',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        await repository.upsert('device-B', RelationshipState.blocked);
        final service = _RespondingReadRelationshipSyncService(
          repository: repository,
          response: {
            'device-B': {'state': 'trusted', 'updatedAt': 2000},
          },
        );

        await service.pull('uid-123');

        final stored = await repository.get('device-B');
        expect(stored?.state, RelationshipState.blocked);
      },
    );

    test(
      'test_EARS_FB_15_pull_no_op_when_merged_state_matches_stored',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        await repository.upsert('device-B', RelationshipState.blocked);
        final before = await repository.get('device-B');
        final service = _RespondingReadRelationshipSyncService(
          repository: repository,
          response: {
            'device-B': {'state': 'blocked', 'updatedAt': 2000},
          },
        );

        await service.pull('uid-123');

        final after = await repository.get('device-B');
        // Same stored state AND the same updatedAt -- proves no redundant
        // write happened (a spurious upsert would bump updatedAt to
        // "now", which would not equal the original timestamp).
        expect(after?.state, RelationshipState.blocked);
        expect(after?.updatedAt, before?.updatedAt);
      },
    );

    test(
      'a peer with no local relationship merges as if local were unknown -- '
      'a remote state LESS restrictive than unknown (allowed/trusted) does '
      'not create a row, since unknown already outranks both',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service = _RespondingReadRelationshipSyncService(
          repository: repository,
          response: {
            'device-B': {'state': 'allowed', 'updatedAt': 2000},
          },
        );

        expect(await repository.get('device-B'), isNull);
        await service.pull('uid-123');

        expect(await repository.get('device-B'), isNull);
      },
    );

    test(
      'a peer with no local relationship and a remote state MORE '
      'restrictive than unknown (blocked) creates a local row',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service = _RespondingReadRelationshipSyncService(
          repository: repository,
          response: {
            'device-B': {'state': 'blocked', 'updatedAt': 2000},
          },
        );

        expect(await repository.get('device-B'), isNull);
        await service.pull('uid-123');

        final stored = await repository.get('device-B');
        expect(stored?.state, RelationshipState.blocked);
      },
    );

    test(
      'a peer with no local relationship and remote unknown does not create a row',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service = _RespondingReadRelationshipSyncService(
          repository: repository,
          response: {
            'device-B': {'state': 'unknown', 'updatedAt': 2000},
          },
        );

        await service.pull('uid-123');

        expect(await repository.get('device-B'), isNull);
      },
    );

    test(
      'a malformed remote state string is skipped, not crashed on',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service = _RespondingReadRelationshipSyncService(
          repository: repository,
          response: {
            'device-B': {'state': 'not-a-real-state', 'updatedAt': 2000},
          },
        );

        await expectLater(service.pull('uid-123'), completes);
        expect(await repository.get('device-B'), isNull);
      },
    );

    test(
      'offline pull changes nothing and does not throw',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        await repository.upsert('device-B', RelationshipState.trusted);
        final service =
            _ThrowingReadRelationshipSyncService(repository: repository);

        await expectLater(service.pull('uid-123'), completes);

        final stored = await repository.get('device-B');
        expect(stored?.state, RelationshipState.trusted);
      },
    );

    test(
      'a never-completing Firebase read is bounded by timeout',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        final service = _HangingReadRelationshipSyncService(
          repository: repository,
          timeout: const Duration(milliseconds: 50),
        );

        await expectLater(service.pull('uid-123'), completes);
      },
    );

    test(
      'multiple peers in one pull are each merged independently',
      () async {
        final db = _openTestDatabase();
        addTearDown(db.close);
        final repository = RelationshipRepository(db);
        await repository.upsert('device-B', RelationshipState.allowed);
        await repository.upsert('device-C', RelationshipState.blocked);
        final service = _RespondingReadRelationshipSyncService(
          repository: repository,
          response: {
            'device-B': {'state': 'blocked', 'updatedAt': 1000},
            'device-C': {'state': 'trusted', 'updatedAt': 1500},
            'device-D': {'state': 'trusted', 'updatedAt': 1800},
          },
        );

        await service.pull('uid-123');

        expect((await repository.get('device-B'))?.state,
            RelationshipState.blocked);
        expect((await repository.get('device-C'))?.state,
            RelationshipState.blocked);
        // device-D has no local row (defaults to unknown), and unknown
        // outranks trusted -- no row is created for it.
        expect(await repository.get('device-D'), isNull);
      },
    );
  });

  group('E11-T05 path registry', () {
    test('relationship path is a child of the parent relationships node',
        () {
      expect(
        FirebasePaths.relationship('uid-123', 'device-B'),
        'users/uid-123/relationships/device-B',
      );
      expect(
        FirebasePaths.relationship('uid-123', 'device-B'),
        '${FirebasePaths.relationships('uid-123')}/device-B',
      );
    });

    test('relationships path is the parent enumerated by pull', () {
      expect(
        FirebasePaths.relationships('uid-123'),
        'users/uid-123/relationships',
      );
    });
  });
}
