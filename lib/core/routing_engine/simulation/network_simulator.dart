// E04-T01 — Route/battery/latency/partition simulator (FR-VER-004).
//
// A pure-Dart, in-memory, no-hardware simulated mesh topology that later
// routing tasks (T02's cost/migration engine, T04's relay) test against.
// Deterministic by construction: all randomness flows through the single
// seeded `Random` supplied at construction, and simulated time only moves
// when a test calls `tick()` — never `DateTime.now()`, never
// `Future.delayed`.
//
// Test/dev-time only — never imported by production `lib/features/` code
// (task §4). Multi-hop pathfinding is explicitly out of scope here; this is
// the substrate T02's routing engine computes paths against, one `send()`
// call per hop.
import 'dart:math';
import 'dart:typed_data';

import 'simulated_link.dart';

class NetworkSimulator {
  final Random _random;
  final Set<String> _nodes = {};

  /// Directed adjacency: `_links['A']['B']` is the A->B link, independent
  /// of any B->A link.
  final Map<String, Map<String, SimulatedLink>> _links = {};

  final Map<String, double> _batteryDrained = {};

  int _tickCount = 0;

  /// Deterministic constructor — same seed, same sequence of loss/random
  /// decisions.
  NetworkSimulator({required int seed}) : _random = Random(seed);

  /// Simulated ticks elapsed so far, for tests that want to assert on
  /// timing without reading wall-clock time.
  int get tickCount => _tickCount;

  /// Registers a node id in the topology. Idempotent — adding an
  /// already-known node is a no-op.
  void addNode(String id) {
    _nodes.add(id);
  }

  /// Removes a node and every link touching it (as source or destination).
  void removeNode(String id) {
    _nodes.remove(id);
    _links.remove(id);
    for (final destinations in _links.values) {
      destinations.remove(id);
    }
    _batteryDrained.remove(id);
  }

  /// Creates or replaces the directed `from -> to` link. `from`/`to` need
  /// not have been registered via `addNode` first — a link implicitly
  /// establishes both endpoints as known nodes, matching how a real
  /// discovery event would surface a peer.
  void setLink(String from, String to, SimulatedLink link) {
    addNode(from);
    addNode(to);
    _links.putIfAbsent(from, () => {})[to] = link;
  }

  /// Simulates a link disappearing entirely (not just going down) —
  /// distinct from `setLink(from, to, link.copyWith(up: false))`, which
  /// leaves the link present but unusable.
  void removeLink(String from, String to) {
    _links[from]?.remove(to);
  }

  /// Reads the current directed link, or `null` if none exists.
  SimulatedLink? linkBetween(String from, String to) => _links[from]?[to];

  /// Advances simulated time by one discrete step. Link-state changes made
  /// via `setLink`/`removeLink` are already visible to `send()` immediately
  /// (there is no queued mutation) — `tick()` exists so tests can express
  /// "time passes" explicitly and later tasks (T02's migration stability
  /// window) have a discrete clock to count against.
  void tick() {
    _tickCount++;
  }

  /// One hop's worth of a send attempt: consults the current `from -> to`
  /// link and applies loss/latency/battery cost. Multi-hop path simulation
  /// is T02's job — it calls `send()` once per hop along the route it
  /// computed.
  SendResult send(String from, String to, Uint8List bytes) {
    final link = _links[from]?[to];
    if (link == null || !link.up) {
      return const SendResult.noRoute();
    }

    final lost = _random.nextDouble() < link.packetLossRate;
    if (lost) {
      return const SendResult.lost();
    }

    _batteryDrained.update(
      from,
      (existing) => existing + link.batteryDrainPerMessage,
      ifAbsent: () => link.batteryDrainPerMessage,
    );

    return SendResult.delivered(link.latencyMs);
  }

  /// Cumulative simulated battery cost for tests asserting a route choice
  /// minimized drain — sums every successful send's `batteryDrainPerMessage`
  /// on the sending node.
  double batteryDrainedFor(String nodeId) => _batteryDrained[nodeId] ?? 0.0;
}
