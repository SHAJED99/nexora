// core/routing_engine — store-and-forward relay engine (E04-T04).
//
// When this device is a relay hop for someone else's route, it temporarily
// holds their encrypted packet (`relay_packets`, ADR-0001) and forwards it
// toward its destination using T02's `RoutingEngine` for path decisions and
// an injected send function for the actual byte transfer.
//
// FR-ROUTE-003 (non-negotiable): a relay device never gains access to
// plaintext. This file treats every payload as opaque `Uint8List` — it is
// never decrypted, parsed, or logged. There is no import of `core/crypto`
// anywhere in this file, and there must never be one.
//
// Production wiring (a later epic) constructs [RelaySendFn] from
// `TransportService.send`; this task's own tests (per its §6 risk note)
// wire it from T01's `NetworkSimulator.send` instead, since real Bluetooth
// isn't needed to prove queue/priority/expiry/retry logic and using it
// would make these tests as unrunnable-without-hardware as T03b/c's.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor: the fields are private (`_db`, `_routingEngine`, ...) while
// the constructor's public named parameters (`db`, `routingEngine`, ...)
// match §5's documented call shape — an initializing formal would rename
// those parameters to the private field names, breaking every call site.
// ignore_for_file: prefer_initializing_formals
import 'package:drift/drift.dart';

import '../persistence/database.dart';
import 'route_cost_calculator.dart';
import 'routing_engine.dart';

/// The closed set of states a relay packet can be in. Stored in Drift as
/// its `.name` string (`relay_packets.delivery_state`), per
/// `docs/conventions.md` "Enums" — never as an integer index.
enum RelayDeliveryState {
  /// Enqueued, not yet successfully handed off, and not (yet) expired.
  /// Eligible for the next `processQueue()` pass.
  queued,

  /// Successfully handed off to an *intermediate* hop (not the final
  /// destination) — this device's part is done. Kept as a row for
  /// diagnostics (§3); not retried further by this device, since retrying
  /// an already-forwarded packet without an ack/dedup mechanism (E05's
  /// job, not this task's, per §4) would only risk duplicate delivery.
  forwarding,

  /// Successfully handed off directly to the destination's transport.
  /// Per §4: this means "handed to the next hop's transport successfully,"
  /// NOT "the end recipient's app confirmed receipt" — no delivery-receipt
  /// semantics live here.
  delivered,

  /// Past `expires_at` when `sweepExpired()` last ran; removed from the
  /// active queue but kept as a row for diagnostics (§3, later E13 needs).
  expired,

  /// Declared per §5's schema for a future explicit failure path (e.g. a
  /// later epic's manual/diagnostic intervention). `processQueue()` never
  /// assigns this itself: per §3, even a packet with no route and no
  /// failure alternative "leaves it queued until expires_at" rather than
  /// being marked failed immediately — so this task's own code never
  /// writes this state. Declared here (not silently dropped) so the schema
  /// matches §5 exactly.
  failed,
}

/// Sends [payload] toward [nextHopId] (this device's own next hop, one
/// physical hop only — see `RelayEngine.processQueue` doc). Returns whether
/// the hand-off succeeded. Production wires this from
/// `TransportService.send`; tests wire it from
/// `NetworkSimulator.send(selfId, nextHopId, payload)`.
typedef RelaySendFn = Future<bool> Function(
  String nextHopId,
  Uint8List payload,
);

/// Named priority bands for `relay_packets.priority` (E04-T04's column;
/// E07-T10 is the first caller to give it named values instead of a bare
/// int). Integers with gaps so a future band fits between without
/// renumbering existing enqueues. `bulk = 0` matches
/// `messaging_stack.dart`'s pre-existing `_defaultPriority = 0` exactly —
/// every E05/E06 enqueue keeps its current effective priority unchanged by
/// this task; see this task's own self-review for the explicit check.
abstract final class RelayPriority {
  static const int realtime = 200;
  static const int interactive = 100;
  static const int bulk = 0;
}

/// Store-and-forward relay engine (§1). One instance per device identity —
/// [selfId] must match the [RoutingEngine] it is given, since `onRouteFailure`
/// blacklists links relative to `RoutingEngine.selfId`.
class RelayEngine {
  RelayEngine({
    required this.selfId,
    required AppDatabase db,
    required RoutingEngine routingEngine,
    required RelaySendFn send,
    TrafficProfile profile = TrafficProfile.interactive,
    DateTime Function() clock = DateTime.now,
  })  : _db = db,
        _routingEngine = routingEngine,
        _send = send,
        _profile = profile,
        _clock = clock;

  final String selfId;
  final AppDatabase _db;
  final RoutingEngine _routingEngine;
  final RelaySendFn _send;
  final TrafficProfile _profile;
  final DateTime Function() _clock;

  int _idCounter = 0;

  /// Accepts a packet for store-and-forward (§3). [payload] is opaque
  /// already-encrypted bytes — never inspected here beyond `.length` (for
  /// the diagnostic `size_bytes` column, per FR-ROUTE-004's own data model;
  /// this is a byte count, not a content inspection).
  Future<String> enqueue(
    String destination,
    Uint8List payload,
    int priority,
    Duration ttl,
  ) async {
    final now = _clock();
    final id = _generateId(now);
    await _db.into(_db.relayPackets).insert(
          RelayPacketsCompanion.insert(
            id: id,
            destinationId: destination,
            payload: Value(payload),
            priority: priority,
            sizeBytes: payload.length,
            createdAt: now.millisecondsSinceEpoch,
            expiresAt: now.add(ttl).millisecondsSinceEpoch,
            deliveryState: RelayDeliveryState.queued.name,
          ),
        );
    return id;
  }

  /// The minimum share of a bounded cycle's budget reserved for whatever is
  /// NOT the highest priority band currently present (E07-T10, §2's
  /// starvation guard) — TUNABLE. Without this, a continuous stream of
  /// `realtime` traffic arriving between cycles could claim every slot of
  /// every cycle forever, and a device in a long call would never drain its
  /// message queue; "a messaging queue that never drains during a
  /// 40-minute call is a worse bug than a slightly choppy call" (task file
  /// §2). At least `ceil(budget * this fraction)` slots (never fewer than
  /// 1, when a lower band is non-empty) go to non-top-priority rows every
  /// cycle regardless of how much top-priority traffic is queued.
  static const double _minReservedFractionForLowerBands = 0.2;

  /// One pass over the queue (§3): every `queued` packet not yet expired,
  /// priority order then oldest-first, gets one forward attempt (plus, on
  /// failure, one retry via `RoutingEngine.onRouteFailure`'s alternative —
  /// bounded to avoid retry-looping a single packet forever within one pass,
  /// per §6's starvation risk note).
  ///
  /// Each attempt is exactly one physical hop: this device only ever
  /// transmits to `route.hops.first` (its own direct next hop). A route
  /// with more than one remaining hop is not walked further by this same
  /// call — the next hop is a *different* device, running its own
  /// `RelayEngine` instance once it receives and re-enqueues the packet;
  /// this device cannot simulate that other device's forwarding decision.
  ///
  /// [maxPacketsPerCycle] (E07-T10) bounds how many packets this single
  /// call attempts. `null` (the default, and every pre-E07-T10 call site's
  /// behaviour) means unbounded — every eligible row gets attempted, exactly
  /// as before this task. When set, rows are still drained
  /// `(priority DESC, created_at ASC)`, but [_minReservedFractionForLowerBands]
  /// guarantees a non-highest-priority band still makes progress every
  /// cycle even under continuous higher-priority load (§2's starvation
  /// guard) — see [_applyStarvationGuard]. Returns the number of packets
  /// actually attempted this cycle.
  Future<int> processQueue({int? maxPacketsPerCycle}) async {
    final now = _clock();
    final rows = await (_db.select(_db.relayPackets)
          ..where((t) => t.deliveryState.equals(RelayDeliveryState.queued.name))
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();

    // Defensive: skip (never forward) a packet that is already
    // time-expired even if `sweepExpired()` hasn't run yet this pass —
    // `delivery_state` alone is not the authority for "still active";
    // `expires_at` vs. the current clock always wins (L-backend-003).
    final eligible = rows
        .where((row) => row.expiresAt > now.millisecondsSinceEpoch)
        .toList(growable: false);

    final budget = maxPacketsPerCycle;
    final selected = (budget == null || eligible.length <= budget)
        ? eligible
        : _applyStarvationGuard(eligible, budget);

    for (final row in selected) {
      await _attempt(row);
    }
    return selected.length;
  }

  /// Picks up to [budget] rows from [rows] (already sorted
  /// `(priority DESC, created_at ASC)`), reserving a minimum slice of the
  /// budget for whatever is NOT the highest priority band present — see
  /// [_minReservedFractionForLowerBands]. Only called when `rows.length >
  /// budget`, i.e. there is genuine contention for this cycle's slots.
  List<RelayPacketRow> _applyStarvationGuard(
    List<RelayPacketRow> rows,
    int budget,
  ) {
    final topPriority = rows.first.priority;
    final topBand = <RelayPacketRow>[];
    final lowerBand = <RelayPacketRow>[];
    for (final row in rows) {
      (row.priority == topPriority ? topBand : lowerBand).add(row);
    }

    // Nothing but the top band is queued -- no lower-priority progress to
    // guarantee, so just take the oldest `budget` top-band rows.
    if (lowerBand.isEmpty) {
      return topBand.take(budget).toList(growable: false);
    }

    final reserved = (budget * _minReservedFractionForLowerBands).floor();
    final reservedForLower =
        (reserved < 1 ? 1 : reserved).clamp(0, lowerBand.length).clamp(0, budget);
    final remainingForTop = budget - reservedForLower;

    return <RelayPacketRow>[
      ...topBand.take(remainingForTop),
      ...lowerBand.take(reservedForLower),
    ];
  }

  Future<void> _attempt(RelayPacketRow row) async {
    Route? route = _routingEngine.computeRoute(row.destinationId, _profile);
    if (route == null || route.hops.isEmpty) {
      // No known path at all — stays queued until a route appears or the
      // packet expires (§3).
      return;
    }

    // Bounded to exactly one retry (the initial attempt + one alternative
    // via onRouteFailure) so one packet can never retry-loop within a
    // single processQueue() pass and starve lower-priority packets behind
    // it (§6).
    for (var attempt = 0; attempt < 2; attempt++) {
      // Track this as the route currently in use so onRouteFailure (which
      // blacklists the active route's own first-hop link) blacklists the
      // right link if this attempt fails. Deliberately NOT setActiveRoute:
      // this is a per-packet forward attempt over whatever computeRoute
      // currently returns, not a validated route switch, and setActiveRoute
      // would reset RoutingEngine's make-before-break migration-stability
      // tracking on every single relay packet (E04-B01) -- silently
      // suppressing EARS-ROUTE-2 for any destination this device relays to.
      _routingEngine.noteAttemptedRoute(route!);

      final nextHop = route.hops.first;
      bool sent;
      try {
        // Never null here: only `queued` rows reach `_attempt` (via
        // `processQueue`'s own where-clause), and `reclaimPayloads()` only
        // ever nulls a payload on a row that has already left `queued` for
        // a terminal state (E04-B02).
        sent = await _send(nextHop, row.payload!);
      } catch (_) {
        // A transport-level exception is treated exactly like a failed
        // send — never surfaced as a crash from a relay hop's own queue
        // processing.
        sent = false;
      }

      if (sent) {
        final terminalState = route.hops.length == 1
            ? RelayDeliveryState.delivered
            : RelayDeliveryState.forwarding;
        await _setState(row.id, terminalState);
        return;
      }

      final alternative = _routingEngine.onRouteFailure(row.destinationId);
      if (alternative == null) {
        // No alternative — leave queued until a route recovers or the
        // packet expires (§3, EARS-ROUTE-4b), not dropped immediately.
        return;
      }
      route = alternative;
    }
    // Both attempts failed — stays queued (bounded retry, §6).
  }

  /// TTL enforcement (§3): marks any `queued` packet past `expires_at` as
  /// `expired` and returns how many were swept. Kept as rows (not deleted)
  /// for diagnostics per a later epic's needs (E13).
  Future<int> sweepExpired() async {
    final now = _clock().millisecondsSinceEpoch;
    final expiredRows = await (_db.select(_db.relayPackets)
          ..where((t) =>
              t.deliveryState.equals(RelayDeliveryState.queued.name) &
              t.expiresAt.isSmallerOrEqualValue(now)))
        .get();

    for (final row in expiredRows) {
      await _setState(row.id, RelayDeliveryState.expired);
    }
    return expiredRows.length;
  }

  Future<void> _setState(String id, RelayDeliveryState state) {
    return (_db.update(_db.relayPackets)..where((t) => t.id.equals(id)))
        .write(RelayPacketsCompanion(deliveryState: Value(state.name)));
  }

  /// Payload retention (E04-B02, FR-ROUTE-004, `epic.md` §Data model):
  /// nulls out the `payload` BLOB for any row in a terminal state
  /// (`forwarding` / `delivered` / `expired`) that is past its own
  /// `expires_at`. The row itself — id, destination, size, timestamps and
  /// state — is left intact for later diagnostics (T04 §3, E13); only the
  /// third-party ciphertext bytes are reclaimed.
  ///
  /// 🧍-resolved 2026-08-27: no additional grace period beyond the
  /// packet's own TTL — a row becomes eligible the instant it is both
  /// terminal AND past `expires_at`, since the TTL the caller chose at
  /// `enqueue()` time is already the "how long is this worth keeping"
  /// signal. Deliberately excludes `queued`: an unexpired (or even expired
  /// but not-yet-swept) `queued` row is still active-queue traffic, not
  /// retained history, and must never lose its payload here.
  Future<int> reclaimPayloads() async {
    final now = _clock().millisecondsSinceEpoch;
    const terminalStates = [
      RelayDeliveryState.forwarding,
      RelayDeliveryState.delivered,
      RelayDeliveryState.expired,
    ];
    final rows = await (_db.select(_db.relayPackets)
          ..where((t) =>
              t.deliveryState.isIn(terminalStates.map((s) => s.name)) &
              t.expiresAt.isSmallerOrEqualValue(now) &
              t.payload.isNotNull()))
        .get();

    for (final row in rows) {
      await (_db.update(_db.relayPackets)..where((t) => t.id.equals(row.id)))
          .write(const RelayPacketsCompanion(payload: Value(null)));
    }
    return rows.length;
  }

  /// Timestamp + an in-process counter — unique per instance without
  /// pulling in a new dependency (no `uuid` package is declared in
  /// `pubspec.yaml`, and adding one is a 🧍 `new_dependency` gate this task
  /// does not need to clear).
  String _generateId(DateTime now) =>
      '${now.microsecondsSinceEpoch}-${_idCounter++}';
}
