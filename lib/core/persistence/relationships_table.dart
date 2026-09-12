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

  @override
  Set<Column> get primaryKey => {deviceId};
}
