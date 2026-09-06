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
import 'package:nexora/core/transport/generated/transport_api.g.dart';
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
                        final pending = controller.pendingEnrollments;
                        final relationships = controller.relationships;
                        if (relationships.isEmpty && pending.isEmpty) {
                          return const _EmptyState();
                        }
                        return ListView.separated(
                          itemCount: pending.length + relationships.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            // E12-T02 (device-enrollment-approval.md): a
                            // pending enrollment request renders at the TOP
                            // of this list, ahead of every established
                            // device row (devices.md's own rows, unchanged
                            // below).
                            if (index < pending.length) {
                              return _PendingEnrollmentRow(
                                device: pending[index],
                                controller: controller,
                              );
                            }
                            return _DeviceRow(
                              relationship:
                                  relationships[index - pending.length],
                              controller: controller,
                            );
                          },
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
      decoration: const BoxDecoration(
        color: NexoraColors.devicesHeaderBg,
        border: Border(
          bottom: BorderSide(color: NexoraColors.devicesRowBorder, width: 1),
        ),
      ),
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
                  // devices.md's own token table measures this as a literal
                  // 9999px radius (the design system's "fully round" token),
                  // not a derived box/2 circle — BoxShape.circle renders
                  // identically but reports as radius 20px against the
                  // contract's 9999px (E12-B12).
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Icon(visual.rowIcon, size: 24, color: visual.iconColor),
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

/// `design/screens/device-enrollment-approval.md` (`source: derived`,
/// GAP-028) -- the pending-enrollment row for a discovered device
/// `DevicesController` has classified as this account's OWN device
/// enrolling (elements DEA1-DEA9). Prepended to `devices.md`'s existing
/// list (E12-T02 §3) -- `devices.md`'s own generated element table and
/// every other row are unchanged.
class _PendingEnrollmentRow extends StatelessWidget {
  const _PendingEnrollmentRow({required this.device, required this.controller});

  final TransportDevice device;
  final DevicesController controller;

  @override
  Widget build(BuildContext context) {
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
              // DEA1: a device platform icon -- no per-platform metadata
              // exists yet (same GAP-003 gap `_DeviceRow` already carries),
              // so this reuses that row's own generic fallback icon.
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: NexoraColors.devicesIconBackdropUnknown,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.devices,
                    size: 24, color: NexoraColors.devicesMuted),
              ),
              const SizedBox(width: 10),
              // DEA2/DEA3: title + short code. The name is the flexible/
              // ellipsis child here, per E06-B01 -- a trailing button pair
              // (DEA4/DEA5's kebab menu) follows it and must never be
              // squeezed out.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.displayName,
                        style: NexoraTextStyles.devicesDeviceName,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(_shortCode(device.id),
                        style: NexoraTextStyles.devicesDeviceSubtitle,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // DEA4/DEA5: the devices row's own trailing more-menu slot,
              // kept unchanged for consistency with every other row -- its
              // "Block" action is this row's own `Deny`, same underlying
              // `controller.block` call as the two buttons below.
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 24, color: NexoraColors.devicesMuted),
                onSelected: (value) {
                  if (value == 'block') {
                    controller.block(device.id);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(value: 'block', child: Text('Block')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // DEA6-DEA9: status glyph + label, then Approve/Deny. The label
          // is the flexible/ellipsis child and the button PAIR stays
          // fixed-width at the trailing end -- the exact shape E06-B01
          // fixed elsewhere in this file (§6 risk note).
          Row(
            children: [
              const Icon(Icons.warning,
                  size: 16, color: NexoraColors.devicesUnknownAmber),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Awaiting your approval',
                  style: NexoraTextStyles.devicesBadgeLabel
                      .copyWith(color: NexoraColors.devicesUnknownAmber),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OnProcessButtonWidget(
                backgroundColor: Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 56, minHeight: 24),
                onTap: () async {
                  await controller.verify(device.id);
                  return null;
                },
                child: const Text('Approve',
                    style: NexoraTextStyles.devicesVerifyLabel),
              ),
              const SizedBox(width: 8),
              OnProcessButtonWidget(
                backgroundColor: Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 56, minHeight: 24),
                onTap: () async {
                  await controller.block(device.id);
                  return null;
                },
                child: Text(
                  'Deny',
                  style: NexoraTextStyles.devicesVerifyLabel
                      .copyWith(color: NexoraColors.devicesBlockedRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// DEA3 -- a short fingerprint/code stood in for a real device fingerprint
/// (no key-exchange fingerprint exists pre-`E12`'s backend tasks, same kind
/// of placeholder GAP-003 already documents for `_DeviceRow`'s name/
/// subtitle): the trailing 4 characters of the raw transport device id,
/// uppercased.
String _shortCode(String deviceId) {
  final String code = deviceId.length >= 4
      ? deviceId.substring(deviceId.length - 4)
      : deviceId;
  return 'Code: ${code.toUpperCase()}';
}

class _StateVisual {
  const _StateVisual({
    required this.iconColor,
    required this.iconBackdrop,
    required this.rowIcon,
    required this.badgeIcon,
    required this.badgeColor,
    required this.badgeLabel,
  });

  final Color iconColor;
  final Color iconBackdrop;
  final IconData rowIcon;
  final IconData badgeIcon;
  final Color badgeColor;
  final String badgeLabel;
}

/// Elements 8/13-14, 16/21-22, 24/29-30, 32/37-38 — icon/color/copy per
/// state, exactly as the design contract's four example rows show them.
/// `rowIcon` (E12-B12): the contract's four example rows each show a
/// DIFFERENT leading device-type glyph (laptop_mac/smartphone/router/
/// desktop_windows, one per `RelationshipState`) — a fixed `Icons.devices`
/// for every row (the pre-fix behaviour) collided, in the design gate's own
/// matcher, with the bottom nav's "Devices" tab label (both dump as the
/// case-insensitive text "devices"), which is what produced that tab's
/// bogus copy/style findings. No new device-metadata field is introduced —
/// this is the same four fixed example glyphs the contract itself measures,
/// keyed on the state this screen already switches over.
_StateVisual _stateVisual(RelationshipState state) {
  switch (state) {
    case RelationshipState.trusted:
      return const _StateVisual(
        iconColor: NexoraColors.welcomeHeading,
        iconBackdrop: NexoraColors.devicesIconBackdropTrusted,
        rowIcon: Icons.laptop_mac,
        badgeIcon: Icons.check_circle,
        badgeColor: NexoraColors.devicesTrustedGreen,
        badgeLabel: 'Trusted Node',
      );
    case RelationshipState.allowed:
      return const _StateVisual(
        iconColor: NexoraColors.devicesAllowedBlue,
        iconBackdrop: NexoraColors.devicesIconBackdropAllowed,
        rowIcon: Icons.smartphone,
        badgeIcon: Icons.radio_button_checked,
        badgeColor: NexoraColors.devicesAllowedBlue,
        badgeLabel: 'Allowed',
      );
    case RelationshipState.unknown:
      return const _StateVisual(
        iconColor: NexoraColors.devicesMuted,
        iconBackdrop: NexoraColors.devicesIconBackdropUnknown,
        rowIcon: Icons.router,
        badgeIcon: Icons.warning,
        badgeColor: NexoraColors.devicesUnknownAmber,
        badgeLabel: 'Unknown',
      );
    case RelationshipState.blocked:
      return const _StateVisual(
        iconColor: NexoraColors.devicesBlockedRed,
        iconBackdrop: NexoraColors.devicesIconBackdropBlocked,
        rowIcon: Icons.desktop_windows,
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
