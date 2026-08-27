// core/persistence — relay_packets table (ADR-0001, E04-T04).
//
// One row per store-and-forward packet this device is temporarily holding
// as a relay hop for someone else's route (epic.md's Data model, FR-ROUTE-004).
// `payload` is opaque, already-encrypted bytes (E03 owns encryption) — this
// table and every reader of it (`lib/core/routing_engine/relay_engine.dart`)
// must never decrypt or parse it (FR-ROUTE-003). `delivery_state` stores a
// `RelayDeliveryState` enum value's `.name` (see `relay_engine.dart`) as
// text, per `docs/conventions.md` "Enums" — never an integer index.
//
// "Local only, ephemeral" per epic.md's Data model — rows are never synced,
// but ARE durably written locally (this is a real Drift table, not
// in-memory-only like T02's `routes`), since a relay packet must survive an
// app restart while it waits for a route rather than being silently lost.
import 'package:drift/drift.dart';

@DataClassName('RelayPacketRow')
class RelayPackets extends Table {
  TextColumn get id => text()();

  /// The final destination node id this packet is ultimately routed toward
  /// — never this device's own id (a relay packet is, by definition, for
  /// someone else).
  TextColumn get destinationId => text()();

  /// Opaque, already-encrypted bytes. Never parsed, inspected or logged by
  /// anything in this table's own file or `relay_engine.dart` (FR-ROUTE-003).
  ///
  /// Nullable as of schema v10 (E04-B02): `RelayEngine.reclaimPayloads()`
  /// nulls this out once a terminal-state row (`forwarding` / `delivered` /
  /// `expired`) passes its own `expires_at` -- the row itself (id,
  /// destination, size, timestamps, state) is kept for diagnostics (E13),
  /// but the ciphertext bytes are not retained past the packet's own TTL.
  /// See `epic.md` §Data model for the exact retention rule.
  BlobColumn get payload => blob().nullable()();

  /// Higher values are forwarded first within a `processQueue()` pass.
  IntColumn get priority => integer()();

  /// `payload.length`, stored for diagnostics/UI-adjacent needs (a later
  /// epic) — never derived from parsing the payload itself.
  IntColumn get sizeBytes => integer()();

  /// Epoch-ms wall-clock timestamp this packet was enqueued.
  IntColumn get createdAt => integer()();

  /// Epoch-ms wall-clock timestamp after which this packet is no longer
  /// forwarded and is instead swept to `expired` by `sweepExpired()`.
  IntColumn get expiresAt => integer()();

  /// `RelayDeliveryState.name` — one of queued / forwarding / delivered /
  /// expired / failed.
  TextColumn get deliveryState => text()();

  @override
  Set<Column> get primaryKey => {id};
}
