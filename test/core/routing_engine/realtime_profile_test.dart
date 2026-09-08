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
        // `onRouteFailure` takes its profile explicitly from the caller
        // (E07-B02 fix) -- passing `realtime` again must recover under the
        // SAME weighting the original route was chosen under, not fall
        // back to `interactive`.
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

        // Fail the active route and remove the relay link entirely --
        // only the direct hop remains, so the next best route (computed
        // again under `realtime`, passed explicitly) must be the direct
        // one.
        routingEngine.setActiveRoute(first!);
        routingEngine.removeLink('relay', 'B');
        final alternative =
            routingEngine.onRouteFailure('B', TrafficProfile.realtime);
        expect(alternative?.hops, ['B']);
      },
    );

    test(
      'test_E07_B02_onRouteFailure_uses_the_callers_own_profile_never_a_sticky_one',
      () {
        // The actual defect: `onRouteFailure` used to fall back to a
        // sticky map written by ANY prior `computeRoute`/`considerMigration`
        // call for this destination, regardless of who made it -- so an
        // unrelated caller (the Dashboard's own connectivity poll, which
        // calls `computeRoute(peerId, interactive)` for every known peer)
        // could silently make a call's route-failure recovery pick the
        // wrong profile. Now the profile is always exactly what THIS call
        // passes, independent of what any other caller asked for a moment
        // ago.
        //
        // Three paths, since `onRouteFailure` always blacklists the FAILED
        // route's own first hop as part of its contract (a route that
        // just failed cannot be recovered onto again) -- the interesting
        // comparison is between the two SURVIVING candidates:
        //   direct     : high latency, excellent reliability/battery.
        //   via-active : very low latency, worse reliability -- the call's
        //                current route, about to fail and be blacklisted.
        //   via-backup : also low latency (though not quite as low as
        //                via-active) and equally poor reliability --
        //                `realtime` still prefers it over `direct`;
        //                `interactive` prefers `direct`.
        final routingEngine = RoutingEngine(selfId: 'A');
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 500,
          lossRate: 0.001,
          batteryDrain: 0.05,
        );
        routingEngine.recordLinkMeasurement(
          'active',
          latencyMs: 5,
          lossRate: 0.05,
          batteryDrain: 3.0,
        );
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 5,
          lossRate: 0.05,
          batteryDrain: 3.0,
          from: 'active',
        );
        routingEngine.recordLinkMeasurement(
          'backup',
          latencyMs: 10,
          lossRate: 0.05,
          batteryDrain: 3.0,
        );
        routingEngine.recordLinkMeasurement(
          'B',
          latencyMs: 10,
          lossRate: 0.05,
          batteryDrain: 3.0,
          from: 'backup',
        );

        // A call is placed on the low-latency `active` route.
        final realtimeRoute =
            routingEngine.computeRoute('B', TrafficProfile.realtime);
        expect(realtimeRoute?.hops, ['active', 'B']);
        routingEngine.setActiveRoute(realtimeRoute!);

        // An UNRELATED caller (mirrors the Dashboard's own connectivity
        // poll) reads a route for the SAME destination under a DIFFERENT
        // profile in between -- this must have zero effect on the call's
        // own recovery below.
        routingEngine.computeRoute('B', TrafficProfile.interactive);

        // The active route fails (its first hop, `active`, gets
        // blacklisted). Recovering under `realtime` (this call's own,
        // correct profile) must still prefer the low-latency `backup`
        // path over the reliable-but-slow direct hop -- proving the
        // interleaved interactive poll never leaked into this recovery.
        final recovered =
            routingEngine.onRouteFailure('B', TrafficProfile.realtime);
        expect(
          recovered?.hops,
          ['backup', 'B'],
          reason: 'an unrelated interactive computeRoute() call must not '
              'leak into this call\'s own realtime recovery -- recovering '
              'under interactive would have picked the direct hop instead',
        );
      },
    );
  });
}
