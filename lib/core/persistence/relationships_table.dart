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

  @override
  Set<Column> get primaryKey => {deviceId};
}
