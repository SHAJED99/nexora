// core/persistence — relationships table (ADR-0001, E02-T01).
//
// One row per remote device this side has evaluated a trust state for.
// `state` stores a `RelationshipState` enum value's `.name` (see
// `lib/features/trust/domain/relationship.dart`) as text, per
// `docs/conventions.md` "Enums" — never an integer index.
import 'package:drift/drift.dart';

@DataClassName('RelationshipRow')
class Relationships extends Table {
  TextColumn get deviceId => text()();
  TextColumn get state => text()();
  DateTimeColumn get updatedAt => dateTime()();

  /// E04-B12 (Option A, part 1/2 — see `identity_announce.dart`): the
  /// peer's own real `selfDeviceId`, learned once via the identity-announce
  /// control protocol and stored keyed by [deviceId] above, which stays
  /// exactly what it always was — the Bluetooth-address transport id this
  /// relationship row was first created under. This column does NOT
  /// replace [deviceId] as the row's key (task file §2a's scope-refinement
  /// note: zero re-keying of existing relationship rows, zero Devices-
  /// screen/UI change). `null` until a peer has announced at least once;
  /// additive migration (schema v20 -> v21), no backfill for existing rows
  /// (they simply have not announced yet).
  TextColumn get remoteSelfDeviceId => text().nullable()();

  /// E04-B17: the peer's Bluetooth-visible name at the time this
  /// relationship was created or last reconciled — the only correlator
  /// available to recognize "this is the same already-trusted peer,
  /// reconnecting under a different address" when [deviceId] itself has
  /// gone stale (confirmed live: an OS/OEM Bluetooth stack can present a
  /// DIFFERENT real, currently-bonded address than whatever address a
  /// relationship was originally keyed under, e.g. from an earlier
  /// discovery scan — same root cause class `E04-B08`'s own
  /// `resolveDeviceId` already fixed for the discovery path, found here to
  /// also silently break inbound delivery on the accept path with no
  /// mechanism to ever recover). `null` for a relationship created before
  /// this column existed, or one whose peer has never been seen with a
  /// resolvable name — reconciliation simply cannot run for those, the
  /// same "additive, no backfill" shape `remoteSelfDeviceId` above already
  /// established. Never used for trust decisions itself (a name is not an
  /// authentication factor) — only to locate the CANDIDATE existing
  /// relationship whose already-evaluated trust state should carry over to
  /// a newly-seen address for the same peer; see
  /// `InboundPipeline._reconcileStaleRelationship` for where this is read.
  TextColumn get peerName => text().nullable()();

  @override
  Set<Column> get primaryKey => {deviceId};
}
