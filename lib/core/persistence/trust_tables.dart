// core/persistence -- trust/connection-request settings (ADR-0001, E02-T04).
//
// A single-row table (`id == 1`), the same shape `LocationSettings`
// (`location_tables.dart`) already established for "exactly one global
// setting exists" as a schema invariant rather than a thing every reader
// must cope with.
//
// `allowNewConnectionRequests` is `FR-TRUST-006`'s "allow/disable
// communication" rule, scoped by the human's 2026-09-27 answer to
// `Q-FUNC-011` (`spec/questions.md`): it gates only a NEW connection
// request from a device with no stored relationship row -- it does not
// suppress inbound delivery, hide existing conversations, alter
// notifications, or otherwise silence an established conversation. Its
// default is deliberately `true`, not `false` like `LocationSettings
// .globalEnabled` -- the location default withholds data never shared,
// whereas defaulting this to `false` would silently stop every existing
// install from accepting anyone (task E02-T04 §2).
import 'package:drift/drift.dart';

@DataClassName('TrustSettingRow')
class TrustSettings extends Table {
  IntColumn get id => integer()();

  BoolColumn get allowNewConnectionRequests =>
      boolean().withDefault(const Constant(true))();

  /// Epoch-ms.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
