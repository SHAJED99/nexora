// E04-T01 — Route/battery/latency/partition simulator (FR-VER-004).
//
// SimulatedLink is a directed, immutable value object describing one hop of
// a simulated mesh topology. A-to-B and B-to-A are independent links; a test
// that wants a symmetric link registers both directions explicitly via
// NetworkSimulator.setLink.
//
// Test/dev-time only — never imported by production `lib/features/` code
// (task §4).
class SimulatedLink {
  /// Simulated one-hop latency in milliseconds, applied to a successful
  /// delivery.
  final int latencyMs;

  /// Probability (0.0-1.0 inclusive) that a `send()` over this link is lost
  /// rather than delivered.
  final double packetLossRate;

  /// Battery cost charged to the sending node for every successful
  /// delivery over this link.
  final double batteryDrainPerMessage;

  /// Whether the link is currently usable. A link set `down` behaves as if
  /// no route exists (`SendResult.noRoute`) until set `up` again.
  final bool up;

  const SimulatedLink({
    required this.latencyMs,
    required this.packetLossRate,
    required this.batteryDrainPerMessage,
    this.up = true,
  }) : assert(
         packetLossRate >= 0.0 && packetLossRate <= 1.0,
         'packetLossRate must be within 0.0-1.0',
       );

  SimulatedLink copyWith({
    int? latencyMs,
    double? packetLossRate,
    double? batteryDrainPerMessage,
    bool? up,
  }) {
    return SimulatedLink(
      latencyMs: latencyMs ?? this.latencyMs,
      packetLossRate: packetLossRate ?? this.packetLossRate,
      batteryDrainPerMessage:
          batteryDrainPerMessage ?? this.batteryDrainPerMessage,
      up: up ?? this.up,
    );
  }

  @override
  String toString() =>
      'SimulatedLink(latencyMs: $latencyMs, packetLossRate: $packetLossRate, '
      'batteryDrainPerMessage: $batteryDrainPerMessage, up: $up)';
}

/// Outcome of one `NetworkSimulator.send()` call — a single hop's worth of
/// a send attempt. Multi-hop path simulation is T02's job.
sealed class SendResult {
  const SendResult();

  /// The send succeeded; `latencyMs` is the link's simulated latency for
  /// this hop.
  const factory SendResult.delivered(int latencyMs) = SendResultDelivered;

  /// The link existed and was up, but the packet was lost (per the link's
  /// `packetLossRate`, decided by the simulator's seeded `Random`).
  const factory SendResult.lost() = SendResultLost;

  /// No usable link between `from` and `to` — either none was ever set,
  /// it was removed, or it is currently `down`.
  const factory SendResult.noRoute() = SendResultNoRoute;
}

final class SendResultDelivered extends SendResult {
  final int latencyMs;
  const SendResultDelivered(this.latencyMs);

  @override
  bool operator ==(Object other) =>
      other is SendResultDelivered && other.latencyMs == latencyMs;

  @override
  int get hashCode => Object.hash(SendResultDelivered, latencyMs);

  @override
  String toString() => 'SendResult.delivered($latencyMs)';
}

final class SendResultLost extends SendResult {
  const SendResultLost();

  @override
  bool operator ==(Object other) => other is SendResultLost;

  @override
  int get hashCode => (SendResultLost).hashCode;

  @override
  String toString() => 'SendResult.lost()';
}

final class SendResultNoRoute extends SendResult {
  const SendResultNoRoute();

  @override
  bool operator ==(Object other) => other is SendResultNoRoute;

  @override
  int get hashCode => (SendResultNoRoute).hashCode;

  @override
  String toString() => 'SendResult.noRoute()';
}
