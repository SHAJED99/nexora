// core/persistence — routes table (ADR-0001, E04-T02).
//
// One row per candidate path this device knows about to a given
// destination. Multiple candidate routes to the same destination coexist
// (per §5) — the primary key is the pair (destinationId, hops), not
// destinationId alone. `hops` stores the ordered relay path as a JSON
// array of node ids (per docs/conventions.md — no bespoke delimiter
// format). `stableSinceTick` backs the make-before-break migration
// stability window (§2/§6 of E04-T02) — it is the engine's own tick
// counter, never wall-clock time.
import 'package:drift/drift.dart';

@DataClassName('RouteRow')
class Routes extends Table {
  TextColumn get destinationId => text()();

  /// Ordered JSON array of hop node ids from this device to
  /// [destinationId], e.g. `'["B","C"]'` for a 2-hop relay via B then C.
  TextColumn get hops => text()();

  /// Last-computed cost for this route (lower is better) — a snapshot, not
  /// a time series (task §4: no route-quality-over-time reporting).
  RealColumn get lastCost => real()();

  /// Epoch-ms wall-clock timestamp of the last cost measurement — display
  /// bookkeeping only, never used for the migration stability window.
  IntColumn get lastMeasuredAt => integer()();

  /// The engine's own tick count at which this route first started
  /// holding its current cost advantage (§5's declared schema, OQ-E04-2).
  /// Nullable: a route with no tracked advantage yet.
  ///
  /// NOT the authority for the migration stability window. As implemented
  /// in E04-T02, `RoutingEngine` holds that state in memory as a count of
  /// consecutive `considerMigration` samples — a different quantity from a
  /// tick number — and never reads or writes this column. This column has
  /// no writer and no reader today; it exists because §5 declares the
  /// schema. Whoever wires persistence in (T04) must reconcile the two
  /// representations rather than assume this column is live —
  /// L-backend-003.
  IntColumn get stableSinceTick => integer().nullable()();

  @override
  Set<Column> get primaryKey => {destinationId, hops};
}
