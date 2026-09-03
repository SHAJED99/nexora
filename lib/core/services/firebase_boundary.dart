// core/services — E11-T01: the FR-FB-001 allowed-field registry.
//
// One closed permitted-key set per Realtime Database node kind, greppable in
// one place, plus a runtime guard both existing Firebase wrappers
// (`FirebaseMetadataService`, `SyncCursorService`) route their write payload
// through immediately before `.set()` (EARS-FB-2). The guard must run
// *before* the write, not inside the wrappers' existing best-effort
// try/catch — a boundary violation is a programming error, not "just
// another Firebase error", and must fail loudly rather than get logged and
// swallowed (task §6 Risks).
//
// `FirebaseNodeKind` is stored/compared by `.name` per `docs/conventions.md`
// §Enums (diffable, doesn't break silently on reordering — irrelevant to an
// in-memory enum today, but keeps the convention consistent everywhere Dart
// enums appear in this codebase).
enum FirebaseNodeKind { device, syncCursor }

/// Thrown by [FirebaseBoundary.assertAllowedFields] when a payload carries a
/// key outside its node kind's allow-list. A programming error (extends
/// [Error], not [Exception]) — this should never happen in production code
/// that only ever builds payloads from the allow-list itself; if it does,
/// the fix is in the caller, not a retry.
///
/// The message names the offending *keys* only, never the payload's
/// *values* — the whole point of this guard is to stop a leak, and a guard
/// that logs the leaked value while rejecting it defeats itself.
class FirebaseBoundaryViolation extends Error {
  FirebaseBoundaryViolation(this.kind, this.offendingKeys);

  final FirebaseNodeKind kind;
  final Set<String> offendingKeys;

  @override
  String toString() =>
      'FirebaseBoundaryViolation: node "${kind.name}" received key(s) outside '
      'its FR-FB-001 allow-list: ${offendingKeys.join(', ')}';
}

/// The FR-FB-001 allowed-field registry: for each [FirebaseNodeKind], the
/// closed set of permitted keys, and the guard that enforces it.
class FirebaseBoundary {
  const FirebaseBoundary._();

  static const Map<FirebaseNodeKind, Set<String>> _allowedFields = {
    // `users/$uid/devices/$deviceId` — device registry metadata
    // (FirebaseMetadataService.writeDeviceMetadata, E01-T02).
    FirebaseNodeKind.device: {
      'deviceId',
      'createdAt',
      'lastSeenAt',
      'platform',
    },
    // `users/$uid/sync_cursors/$writer/$conversation/$about` —
    // synchronization metadata (SyncCursorService.writeCursorData, E05-T04).
    FirebaseNodeKind.syncCursor: {
      'localDeviceId',
      'remoteDeviceId',
      'conversationId',
      'lastConfirmedSequenceNumber',
      'updatedAt',
    },
  };

  /// The closed set of permitted keys for [kind] — the FR-FB-001 allow-list,
  /// in one place.
  static Set<String> allowedFields(FirebaseNodeKind kind) =>
      _allowedFields[kind]!;

  /// Throws [FirebaseBoundaryViolation] if [data] carries any key outside
  /// [kind]'s allow-list. Checks *keys* only, never value types —
  /// `ServerValue.timestamp` is a sentinel `Map`, not an `int`, and this
  /// guard must not reject it (task §6 Risks).
  static void assertAllowedFields(
    FirebaseNodeKind kind,
    Map<String, Object?> data,
  ) {
    final allowed = allowedFields(kind);
    final offending = data.keys.where((key) => !allowed.contains(key)).toSet();
    if (offending.isNotEmpty) {
      throw FirebaseBoundaryViolation(kind, offending);
    }
  }
}
