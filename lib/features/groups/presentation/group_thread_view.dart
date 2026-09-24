// features/groups/presentation — the group thread view (E07-T18).
//
// Built against `design/screens/chat-group.md`. Every colour is declared
// locally by value with the element it is cited from, the way
// `group_create_view.dart` does: the contract is the source of truth, not a
// shared palette constant that could drift without this file noticing.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/features/groups/presentation/group_thread_controller.dart';

/// chat.md element 2 — the header glyph.
const _headerGlyphColor = Color(0xFF464555);

/// chat.md element 4 — the thread title.
const _titleColor = Color(0xFF3525CD);

/// conversations.md element 22 — the group glyph. Placement derived
/// (list row -> thread header); glyph, size and colour measured.
const _groupGlyphColor = Color(0xFF004666);

/// chat.md elements 5-6 — the encryption notice.
const _encryptionColor = Color(0xFF3525CD);

/// chat.md element 15 — an inbound bubble's body.
const _inboundTextColor = Color(0xFF0B1C30);

/// chat.md elements 12/20/23 — an inbound bubble's surface.
const _inboundFill = Color(0xFFFFFFFF);

/// chat.md element 30 — the accent fill, used for an outbound bubble and
/// for the send button.
const _accent = Color(0xFF3525CD);

/// chat.md element 31 — a glyph on the accent fill.
const _onAccent = Color(0xFFFFFFFF);

/// chat.md element 18 — secondary text. Also the event line and the
/// timestamp (elements 11/13), and G10's placeholder body.
const _secondaryText = Color(0xFF464555);

/// conversations.md element 26 — the sender attribution line (G9).
const _attributionColor = Color(0xFF0B1C30);

/// GAP-045, option (b), human-approved 2026-09-25.
///
/// The human's instruction was explicit: "Do not describe it as
/// undecryptable, failed to load, or otherwise imply a
/// cryptographic/decryption failure." The word "hidden" is load-bearing —
/// the message decrypted fine; it is withheld by policy. This is NOT the
/// same string as `chat_view.dart`'s `(unable to decrypt this message)`,
/// and the two must never be merged.
const kBlockedMemberPlaceholder = 'Message hidden — contact is blocked';

class GroupThreadView extends GetView<GroupThreadController> {
  const GroupThreadView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: Obx(() {
                if (controller.state.value == GroupThreadState.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.state.value == GroupThreadState.error) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'This group could not be opened.',
                        style: TextStyle(fontSize: 14, color: _secondaryText),
                      ),
                    ),
                  );
                }
                // State 5 `empty`: the thread frame renders with no rows.
                // The design draws no empty-state illustration or copy in
                // any of its contracts, so none is invented here.
                return ListView.builder(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                  itemCount: controller.rows.length,
                  itemBuilder: (_, i) => _Row(row: controller.rows[i]),
                );
              }),
            ),
            const _Composer(),
          ],
        ),
      ),
    );
  }
}

/// G1-G8. `chat.md` elements 7-8 (`more_vert`) are deliberately absent:
/// a group thread's overflow actions are membership management, which is
/// `group-manage.md`'s scope and is not built. An affordance with nothing
/// behind it is the E07-B01 mistake.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GroupThreadController>();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 16, 8),
      child: Row(
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: Get.back<void>,
              borderRadius: BorderRadius.circular(9999),
              child: const SizedBox(
                width: 40,
                height: 46,
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
          const Icon(Icons.dns, size: 24, color: _groupGlyphColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => Text(
                    controller.groupName.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: _titleColor,
                    ),
                  ),
                ),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 14, color: _encryptionColor),
                    SizedBox(width: 4),
                    Text(
                      'End-to-end encrypted',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _encryptionColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row: a bubble (G9/G10) or an event line (G11).
class _Row extends StatelessWidget {
  const _Row({required this.row});

  final GroupThreadRow row;

  @override
  Widget build(BuildContext context) {
    if (row.isEvent) {
      // G11 -- centred, surface-less, chat.md element 18's measured
      // `12px w500 rgb(70, 69, 85)` (reconciled from GAP-020's own
      // contradictory 14px prose by the human, 2026-09-25).
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            row.text ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _secondaryText,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            row.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // G9 -- incoming only. GAP-020: "outgoing bubbles do not [carry
          // attribution] -- the design never labels the user to themselves."
          if (!row.isMine && row.senderDeviceId != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 0, 2),
              child: Text(
                row.senderDeviceId!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _attributionColor,
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 272),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: row.isMine ? _accent : _inboundFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _body(),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    // G10 -- GAP-045 option (b). Checked BEFORE the decrypt-failure branch
    // so the two can never be conflated: a blocked sender's message is
    // withheld by policy, and the human's instruction forbids implying a
    // cryptographic failure. `row.text` is already null here (the
    // controller never resolves a blocked sender's body at all), so this
    // branch is what decides which of the two sentences the user reads.
    if (row.senderIsBlocked) {
      return const Text(
        kBlockedMemberPlaceholder,
        style: TextStyle(fontSize: 14, color: _secondaryText),
      );
    }
    return Text(
      row.text ?? '(unable to decrypt this message)',
      style: TextStyle(
        fontSize: 14,
        color: row.isMine ? _onAccent : _inboundTextColor,
      ),
    );
  }
}

/// G6 — `chat.md` element 28. G7 (the accent send button) awaits GAP-047,
/// its glyph identity. No `add` button (element 26) and
/// no `mic` (element 31): attachments and voice in a group thread are
/// separate contracts with their own gaps, and neither is built.
class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final controller = Get.find<GroupThreadController>();
    final text = _field.text;
    if (text.trim().isEmpty) {
      return;
    }
    _field.clear();
    await controller.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GroupThreadController>();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => controller.sendError.value.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 0, 6),
                    child: Text(
                      controller.sendError.value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _secondaryText,
                      ),
                    ),
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _field,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Secure message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 14, color: _secondaryText),
                  ),
                ),
              ),
              // G7 -- the 48x48 accent send button is IN the contract
              // (chat.md element 30) but its GLYPH is not: `send` appears in
              // no design contract and nowhere in this app. This project
              // treats glyph identity as a human sign-off item (GAP-014 did
              // exactly that for record-stop/play/pause), so it is NOT
              // invented here. Recorded as GAP-047.
              //
              // Until it is answered the composer submits from the
              // keyboard's own send key (`onSubmitted` above) -- which is
              // precisely how the already-shipped 1:1 chat composer works,
              // so this introduces no new behaviour and no new glyph.
            ],
          ),
        ],
      ),
    );
  }
}
