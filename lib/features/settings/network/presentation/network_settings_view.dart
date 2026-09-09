// features/settings/network/presentation -- NW1-NW15
// (design/screens/settings-network.md, GAP-036). Composes E15-T03's
// `SettingsSubScreenScaffold`; no local frame, no route, no row wiring
// (task §4 -- all three are E15-T11's alone). Read-only throughout --
// `EARS-ROUTE-14`: no button, switch or tappable row anywhere on either
// card.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/core/transport/transport_service.dart'
    show TransportType;
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart';

import 'network_settings_controller.dart';

/// NW1-NW15. Every fixed string below is `settings-network.md`'s §Copy,
/// copied character for character.
class NetworkSettingsView extends GetView<NetworkSettingsController> {
  const NetworkSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsSubScreenScaffold(
        title: 'Network',
        subtitle: 'How this device is reaching the mesh right now.',
        children: [
          SettingsSectionCard(
            children: [
              const Row(
                children: [
                  Expanded(child: SettingsSectionHeading('Transports')),
                  SizedBox(width: 8),
                  // NW4 -- `settings.md` element 24's own hub-row glyph.
                  // The design's glyph name is `wifi_tethering`;
                  // `Icons.wifi_tethering` is Flutter's own bundled
                  // equivalent from the same Material Symbols font
                  // family (`settings_view.dart`'s own header already
                  // established this correspondence pattern for a
                  // different glyph, `battery_full_alt` ->
                  // `Icons.battery_full`). This icon is not in
                  // `flutter_probe_dumper.dart`'s icon-name map
                  // (test/design, not this task's `files:`) -- an
                  // expected, disclosed style-delta on the glyph's `text`
                  // field, not a UI defect (design-fidelity rule 5: a
                  // probe capability gap is the tool's problem).
                  SettingsRowGlyph(
                    Icons.wifi_tethering,
                    color: NexoraColors.welcomeHeading,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TransportsBody(
                transports: controller.transports,
                error: controller.transportsError.value,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            children: [
              const Row(
                children: [
                  Expanded(child: SettingsSectionHeading('Active routes')),
                  SizedBox(width: 8),
                  // NW9 -- `settings.md` element 55's own glyph.
                  SettingsRowGlyph(
                    Icons.router,
                    color: NexoraColors.settingsBodyText,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RoutesBody(
                routes: controller.routes,
                error: controller.routesError.value,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// NW6/NW7/NW15's own list/empty/error handling. An empty list (task §5:
/// "the ordinary state on a device that is alone") renders NW7, never an
/// error -- being alone in the room is a fact, not a failure.
class _TransportsBody extends StatelessWidget {
  const _TransportsBody({required this.transports, required this.error});

  final List<TransportStatus> transports;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (error) {
      // NW15 -- shared error copy, this card's list only.
      return const SettingsEmptyOrErrorLine(
        'Network state could not be read.',
      );
    }
    if (transports.isEmpty) {
      return const SettingsEmptyOrErrorLine('No transport is available.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final t in transports) _TransportRow(status: t)],
    );
  }
}

/// NW6 -- one transport's name (SH7, body text -- never SH11's machine
/// value; this is a human word like `Bluetooth`, not a device id) plus its
/// `Available`/`Unavailable` state label (SH10).
class _TransportRow extends StatelessWidget {
  const _TransportRow({required this.status});

  final TransportStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SettingsBodyLine(_transportName(status.type))),
          const SizedBox(width: 12),
          SettingsStateLabel(status.available ? 'Available' : 'Unavailable'),
        ],
      ),
    );
  }
}

/// NW11/NW14/NW15's own list/empty/error handling. An empty list (task §5:
/// "a user in a room with no peers correctly sees an empty route list") is
/// NW14, never an error.
class _RoutesBody extends StatelessWidget {
  const _RoutesBody({required this.routes, required this.error});

  final List<RouteSummary> routes;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (error) {
      // NW15 -- shared error copy, this card's list only.
      return const SettingsEmptyOrErrorLine(
        'Network state could not be read.',
      );
    }
    if (routes.isEmpty) {
      return const SettingsEmptyOrErrorLine('No route to anywhere yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final r in routes) _RouteRow(route: r)],
    );
  }
}

/// NW11 -- destination id (SH11, machine value) + NW12's hop summary +
/// NW13's measurement (or `Not measured`, never a substituted number,
/// `EARS-ROUTE-13`).
class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.route});

  final RouteSummary route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsMachineValue(route.destinationId),
                const SizedBox(height: 2),
                SettingsBodyLine(_hopSummary(route.hopCount)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SettingsStateLabel(_measurementLabel(route.measurement)),
        ],
      ),
    );
  }
}

/// NW12 -- `Direct` for a single-hop route, `N hops` otherwise. Both are
/// fixed copy compared character for character; `1 hops` never renders
/// (task §4).
String _hopSummary(int hopCount) =>
    hopCount == 1 ? 'Direct' : '$hopCount hops';

/// NW13 -- `latency + loss`, or the contract's own `Not measured` string.
/// Never a substituted number (`EARS-ROUTE-13`).
String _measurementLabel(LinkMeasurement measurement) => switch (measurement) {
  MeasuredLink(latencyMs: final latencyMs, lossRate: final lossRate) =>
    '$latencyMs ms · ${(lossRate * 100).round()}% loss',
  NotMeasuredLink() => 'Not measured',
};

/// NW6's human name for a `TransportType` -- `settings.md`'s own vocabulary
/// for the mesh's carriers, never a raw enum value.
String _transportName(TransportType type) => switch (type) {
  TransportType.bluetooth => 'Bluetooth',
  TransportType.wifiDirect => 'Wi-Fi Direct',
  TransportType.internet => 'Internet',
};
