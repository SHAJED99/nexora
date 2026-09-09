// features/settings/security_center/data — SecurityRecordsRepository
// (E15-T06, FR-DIAG-003). Four read methods over four tables that already
// ship (`DeviceRevocations`, `SignalTrustedIdentities`, `Relationships`,
// `RateLimitCounters`) -- nothing here computes a new security opinion, it
// renders records that already exist (task §2).
//
// `FR-DIAG-002` binds absolutely: a record renders as *what happened, to
// which device id, and when* -- never *what was in it*. This repository
// exists so the SQL lives in one reviewable place and the controller can
// never reach a raw table (task §2). **There is no write method anywhere in
// this file, deliberately** -- blocking, trust and revocation decisions have
// exactly one home (`devices.md`, task §2), and this screen only reports
// what those decisions already recorded.
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/trust/domain/relationship.dart'
    show RelationshipState;

/// What kind of record a row represents -- rendered as the row's own state
/// label per `design/screens/settings-security-center.md`. Not persisted
/// anywhere (this repository only reads), so a plain Dart enum is enough --
/// `docs/conventions.md`'s "store enums as `.name` text, never an integer
/// index" rule is about Drift columns, and nothing here is one.
enum SecurityRecordType { revoked, trusted, blocked, rateLimited }

/// A read-only view of one security record -- exactly the fields
/// `design/screens/settings-security-center.md` renders and nothing else.
/// **It has no field that could hold key material, session material,
/// message content or location data. That is the design, not an
/// implementation detail** (task §5's own words) -- if a future edit needs
/// one of those, that is a task on `devices.md`'s design, not a field added
/// here.
class SecurityRecord {
  const SecurityRecord({
    required this.displayIdentifier,
    required this.recordType,
    this.timestamp,
    this.count,
  });

  /// A device id (already public -- `E11-B06` made it the hex of a
  /// device's own identity public key) for [SecurityRecordType.revoked],
  /// [SecurityRecordType.trusted] and [SecurityRecordType.blocked]; a
  /// human-readable limit name (never the raw bucket key, which may carry
  /// an account uid rather than a device id after its `:`) for
  /// [SecurityRecordType.rateLimited].
  final String displayIdentifier;

  final SecurityRecordType recordType;

  /// When this device recorded the event. `null` where the source table
  /// carries no such column at all -- see [trustedIdentities]'s own doc --
  /// or where the design's own contract renders no "when" for this record
  /// type (blocked, rate-limited).
  final DateTime? timestamp;

  /// A count, for [SecurityRecordType.rateLimited] only.
  final int? count;
}

class SecurityRecordsRepository {
  SecurityRecordsRepository({required this.db});

  final AppDatabase db;

  /// `DeviceRevocations` (`E12`) -- SC6. Every column on this table is
  /// already display-safe (device id, timestamp, source); no projection is
  /// needed to keep this method FR-DIAG-002-safe.
  Future<List<SecurityRecord>> revocations() async {
    final rows = await db.select(db.deviceRevocations).get();
    return [
      for (final row in rows)
        SecurityRecord(
          displayIdentifier: row.deviceId,
          recordType: SecurityRecordType.revoked,
          timestamp: row.revokedAt,
        ),
    ];
  }

  /// `SignalTrustedIdentities` (`E03`) -- SC10, "the section most likely to
  /// be implemented wrongly" (task §5). `identityKey` is never read: this
  /// projects exactly `addressName` -- the peer's own device id, the same
  /// value `SignalProtocolAddress`'s own first component holds everywhere
  /// else in the codebase -- via `selectOnly`, so the key-material blob
  /// cannot be selected into a row, dropped in the widget, or forgotten in
  /// a future edit (task §6 risk: "Project the columns in the query; do not
  /// select the row and drop the field in the widget.").
  ///
  /// `signal_trusted_identities` (`crypto_tables.dart`, `E03-T01b`) carries
  /// **no first-seen timestamp column at all** -- [SecurityRecord.timestamp]
  /// is `null` here. Fabricating one would be inventing data the store
  /// never recorded (rule 1); flagged as `OQ-E15-T06-2` rather than guessed.
  Future<List<SecurityRecord>> trustedIdentities() async {
    final query = db.selectOnly(db.signalTrustedIdentities)
      ..addColumns([db.signalTrustedIdentities.addressName]);
    final rows = await query.get();
    return [
      for (final row in rows)
        SecurityRecord(
          displayIdentifier: row.read(db.signalTrustedIdentities.addressName)!,
          recordType: SecurityRecordType.trusted,
        ),
    ];
  }

  /// `Relationships` filtered to `blocked` (`E02`) -- SC14. Read only:
  /// blocking/unblocking decisions stay on `devices.md` (task §2) -- this
  /// method has no counterpart that writes `RelationshipState.blocked`.
  Future<List<SecurityRecord>> blockedPeers() async {
    final rows =
        await (db.select(db.relationships)
              ..where((t) => t.state.equals(RelationshipState.blocked.name)))
            .get();
    return [
      for (final row in rows)
        SecurityRecord(
          displayIdentifier: row.deviceId,
          recordType: SecurityRecordType.blocked,
        ),
    ];
  }

  /// `RateLimitCounters` (`E13-T02`) -- SC19. A `bucketKey` is
  /// `"<limit>:<subject>"` (`rate_limiter.dart`'s own callers -- e.g.
  /// `relay:<deviceId>`, `device_registration:<accountUid>`); only the
  /// human-readable prefix is ever surfaced here, never the subject after
  /// the `:`, so this can never become a second place a device id (or an
  /// account uid, which is not a device id at all) leaks (FR-DIAG-002).
  Future<List<SecurityRecord>> rateLimitDenials() async {
    final rows = await db.select(db.rateLimitCounters).get();
    return [
      for (final row in rows)
        SecurityRecord(
          displayIdentifier: _limitName(row.bucketKey),
          recordType: SecurityRecordType.rateLimited,
          count: row.count,
        ),
    ];
  }

  /// The prefix before `bucketKey`'s first `:`, mapped to a human-readable
  /// name for every limit this codebase currently defines
  /// (`inbound_pipeline.dart`, `group_membership_service.dart`,
  /// `device_identity_repository.dart`, `evaluate_connection_request_use_case.dart`).
  /// An unrecognised prefix (a future limit added elsewhere) falls back to
  /// the raw prefix rather than throwing -- this screen must never crash on
  /// a row a newer caller wrote (task §5's `error`-state reasoning applies
  /// to a single row too).
  static String _limitName(String bucketKey) {
    final prefix = bucketKey.split(':').first;
    return _limitNames[prefix] ?? prefix;
  }

  static const Map<String, String> _limitNames = {
    'relay': 'Relay',
    'storage_volume': 'Storage volume',
    'group_invite': 'Group invites',
    'device_registration': 'Device registration',
    'connection_request': 'Connection requests',
  };
}
