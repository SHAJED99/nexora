// features/groups/presentation — `/groups/new`, built against
// design/screens/group-create.md (E07-T15). Element numbers below (GC1-GC16)
// are that contract's "Elements — the build checklist" tables.
//
// `design/screens/*.md`, `design/gaps.md` and `design/thresholds.yaml` are
// unchanged (rule 2). Every colour below is declared locally by value, cited
// to the parent contract that measures it — `lib/core/design/tokens.dart` is
// deliberately NOT in this task's `files:` fence, the same convention
// `conversations_view.dart` documents at its own head. No value here is new:
// group-create.md's §Tokens table certifies each one is grep-verifiable in
// `conversations.md`, `devices.md`, `chat.md` or `dashboard.md`.
//
// The create-group ENTRY POINT is not built here and must not be. It is
// group-create.md §Open, explicitly "⏳ awaiting the human" and NOT covered
// by GAP-018's clearance, so `/groups/new` is reachable only by direct
// navigation until that decision is taken (task §4).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';

import 'group_create_controller.dart';

/// GC3/GC6 section headings — rgb(234, 241, 255) (conversations 8/21).
const _sectionHeadingColor = Color(0xFFEAF1FF);

/// GC2 header glyph — rgb(195, 192, 255) (conversations 2/5).
const _headerGlyphColor = Color(0xFFC3C0FF);

/// GC9 contact name — rgb(11, 28, 48) (conversations 10/16/23).
const _rowTitleColor = Color(0xFF0B1C30);

/// GC15/GC16 centred line — rgb(70, 69, 85) (conversations 13/19).
const _mutedBodyColor = Color(0xFF464555);

/// GC13 unselected glyph and GC7's disabled label — rgb(119, 117, 135), the
/// muted colour conversations already uses for an inactive nav item (35/36).
/// The contract is explicit that the disabled treatment is this colour on the
/// same button: no opacity value, no new fill.
const _mutedGlyphColor = Color(0xFF777587);

/// GC8 initials and GC14 selected glyph — rgb(53, 37, 205) (conversations 15),
/// which is also GC7's fill (devices 6).
const _accent = Color(0xFF3525CD);

/// GC4 `dns` — rgb(0, 70, 102), measured on conversations element 22. Marked
/// ⁂ in the contract's token table: a single-use measured value the
/// generator's "most-used" table omits. Real, not invented.
const _groupGlyphColor = Color(0xFF004666);

/// GC10/GC11 trusted pair — rgb(78, 222, 163), measured on conversations
/// element 12 / devices elements 13-14. Also ⁂, same reason.
const _trustedColor = Color(0xFF4EDEA3);

/// GC5 field fill — rgb(229, 238, 255) (conversations 7).
const _fieldFill = Color(0xFFE5EEFF);

/// The header's own hairline, as on conversations.
const _headerBorder = Color(0x1AC7C4D8);

const _sectionHeadingStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w500,
  color: _sectionHeadingColor,
);

/// GC5's placeholder — 14px, the search field's own hint treatment.
const _fieldHintStyle = TextStyle(fontSize: 14, color: _mutedGlyphColor);

const _fieldTextStyle = TextStyle(fontSize: 14, color: _rowTitleColor);

/// GC11 `Trusted Node` — 12px w500 (devices 14), copy unchanged.
const _trustedLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: _trustedColor,
);

/// GC8 initials — 22px w500 (conversations 15).
const _initialsStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w500,
  color: _accent,
);

/// GC9 — w500 rgb(11, 28, 48) (conversations 10/16/23).
const _rowTitleStyle = TextStyle(
  fontWeight: FontWeight.w500,
  color: _rowTitleColor,
);

/// GC15/GC16 — 14px rgb(70, 69, 85), centred. Not re-derived here: this is
/// GAP-002/GAP-006/GAP-007's already-approved and already-built centred
/// subtitle pattern, reused with this screen's own noun.
const _centredLineStyle = TextStyle(fontSize: 14, color: _mutedBodyColor);

class GroupCreateView extends GetView<GroupCreateController> {
  const GroupCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.settingsPageBg,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  _NameField(controller: controller),
                  const SizedBox(height: 20),
                  // GC6 stays in EVERY state, including `empty`. Deleting a
                  // measured element to satisfy the data layer is a
                  // design-fidelity rule-3 violation; `empty` differs from
                  // `default` only in the list area's content.
                  const Text('Members', style: _sectionHeadingStyle),
                  const SizedBox(height: 12),
                  _MemberList(controller: controller),
                ],
              ),
            ),
            _CreateBar(controller: controller),
          ],
        ),
      ),
    );
  }
}

/// GC1/GC2 (`arrow_back`, chat 2) + GC3 `New Group` + GC4 `dns`
/// (conversations 22).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NexoraColors.devicesHeaderBg,
        border: Border.fromBorderSide(BorderSide(color: _headerBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: Get.back<void>,
              borderRadius: BorderRadius.circular(9999),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: _headerGlyphColor,
                  ),
                ),
              ),
            ),
          ),
          const Text('New Group', style: _sectionHeadingStyle),
          const Spacer(),
          const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(Icons.dns, size: 24, color: _groupGlyphColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// GC5 — the conversations search field, unchanged in every measurable
/// respect (358x39, 14px, fill rgb(229,238,255), r8px).
class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final GroupCreateController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: TextField(
        onChanged: controller.setName,
        style: _fieldTextStyle,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Group name',
          hintStyle: _fieldHintStyle,
        ),
      ),
    );
  }
}

/// The list area — the only part that differs between the four §States.
class _MemberList extends StatelessWidget {
  const _MemberList({required this.controller});

  final GroupCreateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (controller.state.value) {
        case GroupCreateState.loading:
          // §States 3: the design draws no spinner or skeleton anywhere
          // across its contracts, so none is invented. This state is the
          // frame with an unpopulated list.
          return const SizedBox.shrink();
        case GroupCreateState.empty:
          return const _CentredLine('No trusted contacts yet'); // GC15
        case GroupCreateState.error:
          // §States 4: the frame is unchanged and one line renders in the
          // list area's own treatment. The rows stay: the selection is not
          // cleared, so it must remain visible and re-submittable.
          return Column(
            children: [
              const _CentredLine("Couldn't create the group. Try again."),
              const SizedBox(height: 12),
              ..._rows(),
            ],
          );
        case GroupCreateState.data:
          return Column(children: _rows());
      }
    });
  }

  List<Widget> _rows() => controller.members
      .map((m) => _MemberRowTile(controller: controller, row: m))
      .toList();
}

class _CentredLine extends StatelessWidget {
  const _CentredLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: _centredLineStyle,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// GC8-GC14, one row.
///
/// **The layout here is load-bearing, not cosmetic** (contract, and E06-B01):
/// a trailing widget after a `Spacer()` with no width bound overflowed by
/// 57px and hung the test harness for its full 10-minute timeout. So the
/// trailing slot is fixed-width and the NAME is the flexible child with an
/// ellipsis policy — a contact name is user-supplied and arbitrarily long.
class _MemberRowTile extends StatelessWidget {
  const _MemberRowTile({required this.controller, required this.row});

  final GroupCreateController controller;
  final MemberRow row;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.selected.contains(row.deviceId);
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => controller.toggle(row.deviceId),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // GC8 — 35x28 initials, not conversations' 46x46 image
                // treatment: no avatar asset exists for a trusted contact
                // (GAP-003).
                SizedBox(
                  width: 35,
                  height: 28,
                  child: Center(
                    child: Text(row.initials, style: _initialsStyle),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.displayName, // GC9
                        style: _rowTitleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon( // GC10
                            Icons.check_circle,
                            size: 16,
                            color: _trustedColor,
                          ),
                          SizedBox(width: 4),
                          Text('Trusted Node', style: _trustedLabelStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                // GC12 — the devices per-row trailing action slot, 24x30,
                // fixed width. See the class doc above.
                SizedBox(
                  width: 24,
                  height: 30,
                  child: Center(
                    child: Icon(
                      isSelected
                          ? Icons.radio_button_checked // GC14
                          : Icons.radio_button_unchecked, // GC13
                      size: 24,
                      color: isSelected ? _accent : _mutedGlyphColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// GC7 — the devices `Discover` primary button (116x34, 12px w500, white on
/// rgb(53,37,205), r8px), this design's only measured primary button.
class _CreateBar extends StatelessWidget {
  const _CreateBar({required this.controller});

  final GroupCreateController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Obx(() {
          final enabled = controller.canCreate;
          return Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? controller.create : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 116,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Create group',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    // The contract's disabled treatment: the SAME button
                    // with its label muted. No opacity, no second fill.
                    color: enabled ? Colors.white : _mutedGlyphColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
