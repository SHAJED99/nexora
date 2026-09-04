// core/services — RelationshipSyncService (E11-T05, FR-TRUST-007,
// FR-MSG-007, FR-FB-001).
//
// Let a user's trust/block decision about one peer device show up on their
// *other* devices -- `FR-TRUST-007`'s "relevant relationship configuration
// shall synchronize", read narrowly per `ADR-0008` as a user's own devices
// agreeing with each other, never one account learning another account's
// relationship state. Every path this service touches is
// `users/$uid/relationships/$peerDeviceId` for the caller's own `$uid`;
// `$peerDeviceId` is always a remote device id, never a foreign uid
// (task §2/§4 -- ADR-0008's declined-option-3 boundary is binding here).
//
// FR-MSG-007 is binding on the merge (task §2): the more restrictive of two
// trust states wins. `ConflictResolver.resolveTrust` (E05-T05) already
// implements exactly this and is the only merge rule used here -- never
// re-derived.
//
// Scope fence (task §4): this service ships local-first push + best-effort
// pull ONLY. It does NOT decide when to call push/pull (a caller's decision
// outside this task), does NOT call ConflictResolver for revocation (that
// is E11-T04, DeviceRevocationService), and does NOT change
// RelationshipState's values or _trustRestrictiveness's ordering.
//
// Firebase boundary (FR-FB-002, non-negotiable): the Firebase read/write
// methods below mirror DeviceRevocationService's exact pattern
// (E11-T04) -- best-effort, bounded timeout via `.timeout()`, catch-and-log
// via ObservabilityService, never throws to the caller. Only `state`/
// `updatedAt` are ever written -- never anything outside
// FirebaseBoundary's allow-list for this node.
import 'package:firebase_database/firebase_database.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_paths.dart';
import 'package:nexora/features/messaging/domain/conflict_resolver.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

class RelationshipSyncService {
  RelationshipSyncService({
    required RelationshipRepository repository,
    FirebaseDatabase? firebaseDatabase,
    Duration? timeout,
  })  : // Named params (`repository`) are public API; the private field
        // below can't share that name, so `prefer_initializing_formals`
        // doesn't apply here despite the trivial assignment -- same
        // reasoning as `DeviceRevocationService`.
        _repository = repository, // ignore: prefer_initializing_formals
        _firebaseDatabaseOverride = firebaseDatabase,
        // Same reasoning as DeviceRevocationService._timeout /
        // FirebaseMetadataService._timeout: a Realtime Database write/read
        // queued offline never completes at all, so this bounds it -- a
        // timeout is just another failure mode, caught below like any
        // other Realtime Database error.
        _timeout = timeout ?? const Duration(seconds: 10);

  final RelationshipRepository _repository;
  final FirebaseDatabase? _firebaseDatabaseOverride;
  final Duration _timeout;

  // Resolved lazily, mirroring DeviceRevocationService._firebaseDatabase --
  // so constructing a RelationshipSyncService with no override never
  // touches a live Realtime Database instance until a read/write is
  // actually attempted.
  FirebaseDatabase get _firebaseDatabase =>
      _firebaseDatabaseOverride ?? FirebaseDatabase.instance;

  /// Mirrors a local trust/block decision to the account's other devices,
  /// best-effort (EARS-FB-14). Writes the local record first via
  /// `RelationshipRepository.upsert` -- a relationship change is
  /// authoritative locally the instant that returns; the Firebase mirror
  /// never blocks or reverses it. Never throws: any Realtime Database
  /// error (including being offline) is caught and logged, not propagated
  /// to the caller of a trust/block action.
  Future<void> push(String uid, String deviceId, RelationshipState state) async {
    await _repository.upsert(deviceId, state);

    final data = {
      'state': state.name,
      'updatedAt': ServerValue.timestamp,
    };
    // EARS-FB-16/task §6 Risks: the guard runs *before* the try below, not
    // inside it -- a boundary violation is a programming error and must
    // propagate, not get caught and logged as "just another Firebase
    // error" (same reasoning as DeviceRevocationService.revoke).
    FirebaseBoundary.assertAllowedFields(FirebaseNodeKind.relationship, data);
    try {
      await writeRelationshipData(uid, deviceId, data).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.relationship_sync_push_failed',
        cause: e,
      );
    }
  }

  /// Performs the actual Realtime Database write. Split out from [push]
  /// deliberately -- `FirebaseDatabase`/`DatabaseReference` need a live
  /// platform-channel test harness to construct in tests, so tests seam
  /// here instead (mirrors `DeviceRevocationService.writeRevocationData`).
  ///
  /// Path from [FirebasePaths.relationship] (E11-T05) --
  /// `users/$uid/relationships/$peerDeviceId`.
  Future<void> writeRelationshipData(
    String uid,
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return _firebaseDatabase
        .ref(FirebasePaths.relationship(uid, deviceId))
        .set(data);
  }

  /// Reconciles relationship state written by another of this account's
  /// devices (EARS-FB-15). Reads every `relationships/$peerDeviceId` node
  /// under the caller's own uid, merges each remote `state` with the
  /// corresponding local one via `ConflictResolver.resolveTrust`, and
  /// persists the merged result only when it differs from what is already
  /// stored -- so a `pull` call never generates a spurious write for a
  /// peer that already agrees (task §6 Risks).
  ///
  /// A peer with no local relationship merges as if the local side were
  /// [RelationshipState.unknown] (the domain default), never crashing on a
  /// missing row. Never throws: any read failure or offline device leaves
  /// local state completely untouched.
  Future<void> pull(String uid) async {
    final Object? raw;
    try {
      raw = await readRelationshipsData(uid).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.relationship_sync_pull_failed',
        cause: e,
      );
      return;
    }

    final remoteStates = _extractRemoteStates(raw);
    for (final entry in remoteStates.entries) {
      final deviceId = entry.key;
      final remote = entry.value;
      final local = await _repository.get(deviceId);
      final localState = local?.state ?? RelationshipState.unknown;
      final merged = ConflictResolver.resolveTrust(localState, remote);
      if (merged != localState) {
        await _repository.upsert(deviceId, merged);
      }
    }
  }

  /// Performs the actual Realtime Database read of the whole
  /// `users/$uid/relationships` subtree (every peer device this account
  /// has a relationship node for). Split out from [pull] for the same
  /// test-seam reason as [writeRelationshipData].
  Future<Object?> readRelationshipsData(String uid) async {
    final snapshot =
        await _firebaseDatabase.ref(FirebasePaths.relationships(uid)).get();
    return snapshot.value;
  }

  /// Reads `{peerDeviceId: RelationshipState}` out of the raw
  /// `users/$uid/relationships` snapshot value. A malformed or unknown
  /// `state` string is skipped entirely -- treated as "no information",
  /// never crashing `pull` or silently coercing to a guessed state.
  static Map<String, RelationshipState> _extractRemoteStates(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, RelationshipState>{};
    for (final entry in raw.entries) {
      final deviceId = entry.key;
      if (deviceId is! String) continue;
      final nodeData = entry.value;
      if (nodeData is! Map) continue;
      final stateName = nodeData['state'];
      if (stateName is! String) continue;
      RelationshipState? state;
      for (final candidate in RelationshipState.values) {
        if (candidate.name == stateName) {
          state = candidate;
          break;
        }
      }
      if (state == null) continue;
      result[deviceId] = state;
    }
    return result;
  }
}
