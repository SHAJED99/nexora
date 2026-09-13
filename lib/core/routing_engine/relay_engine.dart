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

  /// Reads back the current `delivery_state` of the row [id] (E07-T10,
  /// review finding F4). Exposes only the state column `enqueue()` and
  /// `_attempt()` already maintain -- no new tracking mechanism, no new
  /// column, just an honest read of what this device actually recorded for
  /// that packet. Returns `null` if the row does not exist (already reclaimed
  /// or never inserted, neither of which is expected right after a caller's
  /// own `enqueue()`, but this is a read, not an assumption).
  Future<RelayDeliveryState?> deliveryStateOf(String id) async {
    final row = await (_db.select(_db.relayPackets)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return RelayDeliveryState.values.byName(row.deliveryState);
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
  /// budget for EACH distinct priority band below the top one — see
  /// [_minReservedFractionForLowerBands]. Only called when `rows.length >
  /// budget`, i.e. there is genuine contention for this cycle's slots.
  ///
  /// Review finding F1 (round 1): the earlier version of this method merged
  /// every non-top row into a single "lower" bucket, still sorted
  /// `(priority DESC, created_at ASC)`. With 3+ distinct bands present, the
  /// middle band's own rows always sorted ahead of the bottom band's within
  /// that merged bucket, so `lowerBand.take(reservedForLower)` could -- and,
  /// under continuous middle-band pressure, always did -- consume the whole
  /// reserve without ever reaching the bottom band. The fix: reserve a slice
  /// *per band*, not per "everything but top", so the bottom band's progress
  /// never depends on how much traffic a band above it (but still below the
  /// top) happens to have queued.
  ///
  /// Review finding F2 (round 1): the earlier version also discarded any
  /// part of the top band's `remainingForTop` share that the top band was
  /// too small to fill, instead of letting a lower band use it. The fix:
  /// after the top band takes what it can, any still-unused budget rolls
  /// down through the lower bands (in priority order), each still bounded by
  /// its own remaining rows -- so a thin top band no longer wastes slots
  /// that a fat lower backlog could have used.
  List<RelayPacketRow> _applyStarvationGuard(
    List<RelayPacketRow> rows,
    int budget,
  ) {
    // Group into distinct priority bands, preserving each band's existing
    // (created_at ASC) order, highest priority first.
    final bandsByPriority = <int, List<RelayPacketRow>>{};
    for (final row in rows) {
      bandsByPriority
          .putIfAbsent(row.priority, () => <RelayPacketRow>[])
          .add(row);
    }
    final prioritiesDesc = bandsByPriority.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Only one band present -- no lower-priority progress to guarantee, so
    // just take the oldest `budget` rows.
    if (prioritiesDesc.length == 1) {
      return rows.take(budget).toList(growable: false);
    }

    final topPriority = prioritiesDesc.first;
    final lowerPriorities = prioritiesDesc.skip(1).toList(growable: false);
    final taken = <int, int>{for (final p in prioritiesDesc) p: 0};

    // Step 1: reserve a minimum slice of the budget for EACH lower band
    // individually (F1) -- never a single merged "everything but top"
    // bucket, since that lets a mid band's own row count starve a band
    // below it even though a per-band reserve was intended.
    var remaining = budget;
    final totalReserve =
        (budget * _minReservedFractionForLowerBands).ceil().clamp(0, budget);
    final perBandReserve = (totalReserve / lowerPriorities.length).ceil();
    for (final p in lowerPriorities) {
      if (remaining <= 0) break;
      final band = bandsByPriority[p]!;
      final take = perBandReserve.clamp(0, band.length).clamp(0, remaining);
      taken[p] = take;
      remaining -= take;
    }

    // Step 2: whatever budget remains after the per-band reserves goes to
    // the top band first.
    final topBand = bandsByPriority[topPriority]!;
    final topTake = topBand.length.clamp(0, remaining);
    taken[topPriority] = topTake;
    remaining -= topTake;

    // Step 3: roll any still-unused budget down through the lower bands, in
    // priority order, each still bounded by its own remaining rows (F2) --
    // this is what prevents a thin top band from wasting slots a fat lower
    // backlog could otherwise have used.
    if (remaining > 0) {
      for (final p in lowerPriorities) {
        if (remaining <= 0) break;
        final band = bandsByPriority[p]!;
        final already = taken[p] ?? 0;
        final more = (band.length - already).clamp(0, remaining);
        taken[p] = already + more;
        remaining -= more;
      }
    }

    final selected = <RelayPacketRow>[];
    for (final p in prioritiesDesc) {
      selected.addAll(bandsByPriority[p]!.take(taken[p] ?? 0));
    }
    return selected;
  }

  Future<void> _attempt(RelayPacketRow row) async {
    Route? route = _routingEngine.computeRoute(row.destinationId, _profile);
    if (route == null || route.hops.isEmpty) {
      // E04-B23: `computeRoute` only ever knows a link once
      // `RoutingEngine.recordLinkMeasurement` has fired for it — which
      // itself only ever happens from live link-quality data during an
      // ALREADY-active connection (`LinkQualityFeed`). A device this
      // process has never yet connected to (or one whose only prior
      // connection dropped without this process happening to still hold
      // that measurement -- e.g. after an app restart) therefore has NO
      // route, ever, until *something* connects to it first -- but
      // nothing else does that on this device's own initiative
      // (`MessagingCoordinator._seedKnownDevices`'s own doc comment:
      // "Does NOT call `connect()` ... same no-eager-connect reasoning").
      // The result, confirmed live (two-device testing, 2026-09-14): a
      // real, already-bonded, already-trusted contact's very first
      // message send (or the first one after any connection drop) can
      // never leave this device at all -- not even a failed native
      // connect attempt is ever made, since this early `return` fires
      // before `_send` (which is what actually calls
      // `TransportService.connect`) is ever reached.
      //
      // Human decision (2026-09-14, "do the best" -- delegating the
      // choice among three presented options): rather than weakening
      // `E04-B07`'s deliberate no-eager-connect design app-wide (e.g. a
      // background reconnect timer for every known device, regardless of
      // whether the user is trying to talk to them), this narrowly
      // treats an explicit SEND to an already `trusted`/`allowed`
      // relationship as sufficient reason to attempt one direct hop
      // (destination == next hop, the common 1-hop-mesh case) even with
      // no measured route -- exactly the "the user needs to talk to
      // someone they're already paired with, and nothing else is going
      // to make that connection happen" case, while a stranger with no
      // relationship at all still gets no eager-connect attempt, same as
      // before. On success this is recorded exactly like any other
      // single-hop delivery (`RelayDeliveryState.delivered`); on failure
      // the packet is left queued, same as an ordinary failed hop
      // (§3/§6) -- no new failure-handling path.
      // Queried directly against the `relationships` table (not via
      // `features/trust`'s own repository/domain enum) -- this file
      // already treats `core/persistence` as its only allowed dependency
      // beyond routing itself (see this file's own FR-ROUTE-003 header
      // note on import discipline), and the two states that matter here
      // are exactly the same two strings `RelationshipRepository.upsert`
      // itself writes (`RelationshipState.trusted.name`/`.allowed.name`).
      final relationshipRow = await (_db.select(_db.relationships)
            ..where((t) => t.deviceId.equals(row.destinationId)))
          .getSingleOrNull();
      final isKnownContact = relationshipRow != null &&
          (relationshipRow.state == 'trusted' ||
              relationshipRow.state == 'allowed');
      if (!isKnownContact) return;

      bool sentDirect;
      try {
        sentDirect = await _send(row.destinationId, row.payload!);
      } catch (_) {
        sentDirect = false;
      }
      if (sentDirect) {
        await _setState(row.id, RelayDeliveryState.delivered);
      }
      // A failed direct attempt leaves the packet queued for the next
      // `processQueue()` pass, exactly like a genuinely-routed hop that
      // failed and had no alternative (§3) -- not a new failure state.
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

      // E07-B02: this engine always knows its own profile -- passed
      // explicitly rather than relying on RoutingEngine's own now-removed
      // sticky profile map.
      final alternative = _routingEngine.onRouteFailure(row.destinationId, _profile);
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
