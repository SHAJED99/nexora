// E07-T10 — TrafficProfile.realtime route-selection tests (FR-CALL-002,
// FR-ROUTE-002). One topology, three profiles, three route choices --
// asserting WHICH route each profile picks (`Route.hops` equality), never a
// cost number (task file §6/§9: a test that pins a cost value breaks the
// moment anyone tunes the TUNABLE weights).
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/routing_engine/route_cost_calculator.dart';
import 'package:nexora/core/routing_engine/routing_engine.dart';

void main() {
  group('EARS-CALL-7 — realtime route selection', () {
    test(
      'test_EARS_CALL_7_realtime_prefers_the_low_latency_route_where_interactive_does_not',
      () {
        // Topology: two independent paths from A to B.
        //   direct  (1 hop):  high latency, excellent reliability/battery.
        //   via-relay (2 hops): very low latency EACH hop, but worse
        //   reliability and battery per hop.
        //
        // `interactive` (unreliability x10, battery x2, latency x0.01)
        // weighs reliability/battery heavily enough that the reliable
        // single hop wins despite its much higher latency -- i.e.
        // `interactive` does NOT prefer the low-latency route here.
        // `realtime` (latency x0.04, hopCount x2, battery x0.25,
        // unreliability x2) weighs latency so much more heavily that the
        // low-latency multi-hop route wins instead, even paying for an
        // extra hop and worse battery/reliability.
        final routingEngine = RoutingEngine(selfId: 'A');

        // direct: A -> B
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 500,
          lossRate: 0.001,
          batteryDrain: 0.05,
        );

        // via-relay: A -> relay -> B, each hop low-latency/poor
        // reliability/battery.
        routingEngine.recordLinkMeasurement(
          'relay',
          latencyMs: 10,
          lossRate: 0.05,
          batteryDrain: 3.0,
        );
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 10,
          lossRate: 0.05,
          batteryDrain: 3.0,
          from: 'relay',
        );

        final interactiveRoute =
            routingEngine.computeRoute('B', TrafficProfile.interactive);
        final bulkRoute = routingEngine.computeRoute('B', TrafficProfile.bulk);
        final realtimeRoute =
            routingEngine.computeRoute('B', TrafficProfile.realtime);

        expect(
          interactiveRoute?.hops,
          ['B'],
          reason: 'interactive must prefer the reliable, low-battery direct '
              'hop despite its much higher latency -- it does NOT prefer '
              'the low-latency route on this topology',
        );
        expect(
          bulkRoute?.hops,
          ['B'],
          reason: 'bulk weighs reliability/battery even more heavily than '
              'interactive, so it also picks the direct hop',
        );
        expect(
          realtimeRoute?.hops,
          ['relay', 'B'],
          reason: 'realtime must prefer the low-latency multi-hop route '
              'even though interactive/bulk do not choose it (FR-CALL-002, '
              'FR-ROUTE-002)',
        );
      },
    );

    test(
      'test_EARS_CALL_7_realtime_is_a_registered_profile_routing_engine_can_replay',
      () {
        // computeRoute() records the profile it was last asked for
        // (`_lastProfile`), which `onRouteFailure`'s own fallback route
        // computation reads -- a route computed under `realtime` must not
        // silently fall back to `interactive` on the very next lookup for
        // the same destination.
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 500,
          lossRate: 0.001,
          batteryDrain: 0.05,
        );
        routingEngine.recordLinkMeasurement(
          'relay',
          latencyMs: 10,
          lossRate: 0.05,
          batteryDrain: 3.0,
        );
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 10,
          lossRate: 0.05,
          batteryDrain: 3.0,
          from: 'relay',
        );

        final first = routingEngine.computeRoute('B', TrafficProfile.realtime);
        expect(first?.hops, ['relay', 'B']);

        // Fail the active route via the realtime path and remove the
        // relay link entirely -- only the direct hop remains, so the next
        // best route (still computed under the remembered `realtime`
        // profile) must be the direct one.
        routingEngine.setActiveRoute(first!);
        routingEngine.removeLink('relay', 'B');
        final alternative = routingEngine.onRouteFailure('B');
        expect(alternative?.hops, ['B']);
      },
    );
  });
}
