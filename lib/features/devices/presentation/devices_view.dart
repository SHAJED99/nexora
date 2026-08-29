// features/devices/presentation — built against design/screens/devices.md.
// Elements referenced by number below are that contract's "Elements — the
// build checklist" table.
//
// Two data gaps this screen has no source for yet (no device-discovery
// metadata exists before E04): a device's display name and its transport
// type. `RelationshipRepository` (E02-T01) stores only deviceId/state/
// updatedAt. Logged as design/gaps.md GAP-003 — the deviceId is shown as
// the name, and the subtitle line uses a fixed placeholder until E04
// supplies real metadata.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/features/trust/domain/relationship.dart';
import 'package:on_process_button_widget/on_process_button_widget.dart';
import 'devices_controller.dart';

class DevicesView extends GetView<DevicesController> {
  const DevicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleRow(controller: controller),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Obx(() {
                        final relationships = controller.relationships;
                        if (relationships.isEmpty) {
                          return const _EmptyState();
                        }
                        return ListView.separated(
                          itemCount: relationships.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _DeviceRow(
                            relationship: relationships[index],
                            controller: controller,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            _BottomNav(),
          ],
        ),
      ),
    );
  }
}

/// Elements 1-3: hub icon, "NEXORA", lock icon on a dark header bar.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NexoraColors.devicesHeaderBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.hub, size: 24, color: NexoraColors.welcomeHeading),
          const SizedBox(width: 8),
          const Text('NEXORA', style: NexoraTextStyles.devicesBrandTitle),
          const Spacer(),
          const Icon(Icons.lock, size: 24, color: NexoraColors.welcomeHeading),
        ],
      ),
    );
  }
}

/// Elements 4-7: "Network Nodes" heading + subtitle, and the "Discover"
/// button (no-op — real discovery is E04's job, OQ-E02-T02-1).
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.controller});

  final DevicesController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Network Nodes', style: NexoraTextStyles.devicesSectionHeading),
              SizedBox(height: 4),
              Text(
                'Manage paired and nearby devices.',
                style: NexoraTextStyles.devicesSectionSubtitle,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OnProcessButtonWidget(
          backgroundColor: NexoraColors.loginBrand,
          borderRadius: BorderRadius.circular(8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(minWidth: 116, minHeight: 34),
          onTap: () async {
            controller.discover();
            return null;
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text('Discover', style: NexoraTextStyles.devicesDiscoverLabel),
            ],
          ),
        ),
      ],
    );
  }
}

/// Derived, per rule 2 — the design contract has no empty state (design/
/// gaps.md GAP-002). Reuses the screen's own body typography, no new
/// visual language.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No devices yet', style: NexoraTextStyles.devicesSectionSubtitle),
    );
  }
}

/// One relationship row — elements 8-15 (Trusted example), matching the
/// same structure for every `RelationshipState`.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.relationship, required this.controller});

  final Relationship relationship;
  final DevicesController controller;

  _StateVisual get _visual => _stateVisual(relationship.state);

  @override
  Widget build(BuildContext context) {
    final visual = _visual;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NexoraColors.devicesRowFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NexoraColors.devicesRowBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.iconBackdrop,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.devices, size: 24, color: visual.iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // deviceId stands in for a display name — E02-T01's
                    // repository has no device-name field yet.
                    Text(relationship.deviceId,
                        style: NexoraTextStyles.devicesDeviceName),
                    const SizedBox(height: 2),
                    // Transport type isn't known pre-E04 discovery
                    // (design/gaps.md GAP-003) — fixed placeholder.
                    const Text('Paired locally',
                        style: NexoraTextStyles.devicesDeviceSubtitle),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 24, color: NexoraColors.devicesMuted),
                onSelected: (value) {
                  if (value == 'block') {
                    controller.block(relationship.deviceId);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(value: 'block', child: Text('Block')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(visual.badgeIcon, size: 16, color: visual.badgeColor),
              const SizedBox(width: 4),
              Text(
                visual.badgeLabel,
                style: NexoraTextStyles.devicesBadgeLabel
                    .copyWith(color: visual.badgeColor),
              ),
              const Spacer(),
              if (relationship.state == RelationshipState.unknown)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OnProcessButtonWidget(
                      backgroundColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints:
                          const BoxConstraints(minWidth: 56, minHeight: 24),
                      onTap: () async {
                        await controller.verify(relationship.deviceId);
                        return null;
                      },
                      child: const Text('Verify',
                          style: NexoraTextStyles.devicesVerifyLabel),
                    ),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    'Last seen: ${_formatLastSeen(relationship.updatedAt)}',
                    style: NexoraTextStyles.devicesLastSeen,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateVisual {
  const _StateVisual({
    required this.iconColor,
    required this.iconBackdrop,
    required this.badgeIcon,
    required this.badgeColor,
    required this.badgeLabel,
  });

  final Color iconColor;
  final Color iconBackdrop;
  final IconData badgeIcon;
  final Color badgeColor;
  final String badgeLabel;
}

/// Elements 13-14, 21-22, 29-30, 37-38 — icon/color/copy per state, exactly
/// as the design contract's four example rows show them.
_StateVisual _stateVisual(RelationshipState state) {
  switch (state) {
    case RelationshipState.trusted:
      return const _StateVisual(
        iconColor: NexoraColors.welcomeHeading,
        iconBackdrop: NexoraColors.devicesIconBackdropTrusted,
        badgeIcon: Icons.check_circle,
        badgeColor: NexoraColors.devicesTrustedGreen,
        badgeLabel: 'Trusted Node',
      );
    case RelationshipState.allowed:
      return const _StateVisual(
        iconColor: NexoraColors.devicesAllowedBlue,
        iconBackdrop: NexoraColors.devicesIconBackdropAllowed,
        badgeIcon: Icons.radio_button_checked,
        badgeColor: NexoraColors.devicesAllowedBlue,
        badgeLabel: 'Allowed',
      );
    case RelationshipState.unknown:
      return const _StateVisual(
        iconColor: NexoraColors.devicesMuted,
        iconBackdrop: NexoraColors.devicesIconBackdropUnknown,
        badgeIcon: Icons.warning,
        badgeColor: NexoraColors.devicesUnknownAmber,
        badgeLabel: 'Unknown',
      );
    case RelationshipState.blocked:
      return const _StateVisual(
        iconColor: NexoraColors.devicesBlockedRed,
        iconBackdrop: NexoraColors.devicesIconBackdropBlocked,
        badgeIcon: Icons.block,
        badgeColor: NexoraColors.devicesBlockedRed,
        badgeLabel: 'Blocked',
      );
  }
}

String _formatLastSeen(DateTime updatedAt) {
  final diff = DateTime.now().difference(updatedAt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Elements 40-51: Dashboard/Conversations/Devices/Settings. Devices is the
/// active tab (element 46's filled pill); the other three route to screens
/// not yet built by their owning feature epics, so they are present and
/// tappable but intentionally do nothing yet.
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                active: false,
                onTap: () {}),
          ),
          Expanded(
            child: _NavItem(
                icon: Icons.chat,
                label: 'Conversations',
                active: false,
                onTap: () {}),
          ),
          Expanded(
            child: _NavItem(
                icon: Icons.router,
                label: 'Devices',
                active: true,
                onTap: () {}),
          ),
          Expanded(
            child: _NavItem(
                icon: Icons.settings,
                label: 'Settings',
                active: false,
                onTap: () {}),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? NexoraColors.welcomeTextAccent
        : NexoraColors.loginBody;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: active
              ? NexoraTextStyles.devicesNavLabelActive
              : NexoraTextStyles.devicesNavLabel,
        ),
      ],
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(active ? 9999 : 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: active
            ? BoxDecoration(
                color: NexoraColors.devicesActiveNavBg,
                borderRadius: BorderRadius.circular(9999),
              )
            : null,
        child: content,
      ),
    );
  }
}
