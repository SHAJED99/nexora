// features/chat/presentation — ChatView (E06-T11). Built against
// design/screens/chat.md. Elements referenced by number below are that
// contract's "Elements — the build checklist" table (31 rows).
//
// Every colour/style below either reuses an existing `NexoraColors` constant
// that already matches the contract's own measured value exactly, or is a
// new value measured directly from this contract's own token table and
// declared locally in THIS file — `lib/core/design/tokens.dart` is
// intentionally NOT in this task's `files:` fence, same precedent
// `conversations_view.dart` (E06-T10) already established for exactly this
// reason.
//
// Approved gaps this screen renders knowingly-incomplete, per
// `design/gaps.md`:
// - GAP-008 — empty thread renders header + composer unchanged, with one
//   centered pill (the day-divider pill's own styling) in place of the list.
// - GAP-009 — delivery-tick glyph mapping (see `_tickFor` below).
// - GAP-010 — `add`/`mic` render exactly as measured and are inert
//   ("not yet available" snackbar, the same primitive GAP-004's Discover
//   stub already established); the file-transfer bubble (elements 16-18) is
//   data-driven content this task does not build, so it is never rendered.
//
// Every interactive element below is `InkWell`/`Material` or `TextField`'s
// own gesture handling — never `Listener`. See `chat_controller.dart`'s
// header and this task's Run log for why: `Listener` never enters the
// gesture arena (a scroll/drag would fire as a tap) and contributes zero
// accessibility semantics. T10's independent reviewer found exactly this
// defect and it is not repeated here, even where it costs design-fidelity
// gate score against T01's probe-dumper limitation (documented in the Run
// log, not worked around by reshaping the widget tree).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/design/tokens.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'chat_controller.dart';

/// Today pill / composer field / incoming-bubble fill family — measured
/// directly from this contract's own token table, not reused from
/// `tokens.dart` by name where no existing constant matches exactly.
const _pillBg = Color(0xFFEFF4FF); // rgb(239, 244, 255) — == NexoraColors.loginBg's value
const _barBg = Color(0xFFE5EEFF); // rgb(229, 238, 255)
const _headerComposerBorder = Color(0x1AC7C4D8); // rgba(199, 196, 216, 0.1)
const _bubbleBorder = Color(0x33C7C4D8); // rgba(199, 196, 216, 0.2)
const _avatarBackdrop = Color(0xFFDCE9FF); // rgb(220, 233, 255) == NexoraColors.settingsIconLightBlue's value

const _nameStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBrand,
);

const _encryptedLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBrand,
);

const _pillTextStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBody,
);

const _timestampStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: NexoraColors.loginBody,
);

const _incomingBubbleTextStyle = TextStyle(
  fontSize: 14,
  color: NexoraColors.loginHeading,
);

const _outgoingBubbleTextStyle = TextStyle(
  fontSize: 14,
  color: Colors.white,
);

const _composerHintStyle = TextStyle(
  fontSize: 16,
  color: NexoraColors.devicesMuted,
);

class ChatView extends GetView<ChatController> {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // E06-B06 (Redmi 10 2022 / MIUI composer-dead-to-touch fix): on-device
      // diagnostics (RenderBox global position + raw `FlutterView` metrics,
      // logged live via `flutter run -d <redmi-serial>` and cross-checked
      // against `dumpsys window`/`uiautomator dump`) showed the Composer's
      // own row landing with its bottom edge EXACTLY flush against this
      // device's reported physical canvas height, and MIUI's own
      // accessibility bridge (`uiautomator dump`) independently reporting
      // the composer's three controls as only 23-32 *physical* px tall —
      // a sliver, not their real 46-48px design height — because on this
      // device `MediaQuery.padding.bottom` (what plain `SafeArea` consumes)
      // is reported as exactly zero: the OS's own nav-bar reservation is
      // already excluded from the canvas Flutter is handed, so `SafeArea`
      // alone sees nothing further to guard against. That leaves the
      // composer's interactive controls with ZERO cushion from the
      // device's absolute bottom edge — where MIUI's own edge/gesture
      // input handling (confirmed present on this ROM via
      // `horizontal_edge_suppression_size`/`vertical_edge_suppression_size`
      // system settings, and this device's own three-button nav bar
      // sitting immediately beneath) is demonstrably more aggressive about
      // reclaiming edge-adjacent touches than stock Android/the Pixel this
      // was cross-checked against. `minimum:` forces a floor under
      // whatever `SafeArea` would otherwise compute (zero, here), pushing
      // every composer control a fixed, small distance off the true edge
      // on every device — a no-op in practice on any device that already
      // reports a real inset (e.g. the Pixel), and the guard this device
      // was missing entirely. See task file §"Root cause" / Run log for
      // the full on-device measurement trail; `OQ-E06-B06-2` covers what
      // this session's own ADB-injected taps could and couldn't prove.
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            _Header(controller: controller),
            Expanded(child: _MessageArea(controller: controller)),
            _Composer(controller: controller),
          ],
        ),
      ),
    );
  }
}

/// Elements 1-8: back button, avatar (GAP-003 precedent — initials, no
/// avatar-image data source pre-E04), peer name, `lock` + "End-to-end
/// encrypted", `more_vert`.
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsOf(controller.conversationId);
    return Container(
      decoration: const BoxDecoration(
        color: _barBg,
        border: Border(bottom: BorderSide(color: _headerComposerBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          _IconTapTarget(
            icon: Icons.arrow_back,
            color: NexoraColors.loginBody,
            onTap: () => Get.back<void>(),
          ),
          const SizedBox(width: 4),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _avatarBackdrop,
              borderRadius: BorderRadius.all(Radius.circular(9999)),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: NexoraColors.loginBrand,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.conversationId,
                  style: _nameStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: const [
                    Icon(Icons.lock, size: 14, color: NexoraColors.loginBrand),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'End-to-end encrypted',
                        style: _encryptedLabelStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _IconTapTarget(
            icon: Icons.more_vert,
            color: NexoraColors.loginBody,
            onTap: () => Get.snackbar(
              'Not available',
              'This isn\'t available yet.',
              snackPosition: SnackPosition.BOTTOM,
            ),
          ),
        ],
      ),
    );
  }
}

/// A 40x46, r9999 tap target around a 24px icon (elements 1-2, 7-8) — real
/// gesture-arena participation + real semantics via `InkWell`/`Material`,
/// never `Listener` (this file's header).
class _IconTapTarget extends StatelessWidget {
  const _IconTapTarget({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: SizedBox(
          width: 40,
          height: 46,
          child: Center(child: Icon(icon, size: 24, color: color)),
        ),
      ),
    );
  }
}

/// Elements 9-25: loading / error / empty (GAP-008) / the live thread —
/// `Today` divider, bubbles per party, timestamps, delivery ticks (GAP-009).
class _MessageArea extends StatelessWidget {
  const _MessageArea({required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errorMessage.value.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              controller.errorMessage.value,
              style: NexoraTextStyles.devicesSectionSubtitle,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      final bubbles = controller.messages;
      if (bubbles.isEmpty) {
        // GAP-008 — empty thread: the day-divider pill's own
        // typography/fill, reused as a single centered line.
        return const Center(
          child: _DayPill(text: 'No messages yet — say hello'),
        );
      }
      return ListView(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          for (var i = bubbles.length - 1; i >= 0; i--) ...[
            _MessageBubble(
              bubble: bubbles[i],
              controller: controller,
            ),
            const SizedBox(height: 12),
            if (i == 0 || !_isSameDay(bubbles[i - 1].timestamp, bubbles[i].timestamp)) ...[
              _DayPill(text: _dayLabel(bubbles[i].timestamp)),
              const SizedBox(height: 12),
            ],
          ],
        ],
      );
    });
  }
}

/// Element 9: "Today" pill — also GAP-008's empty-state treatment, reusing
/// the same styling unchanged.
class _DayPill extends StatelessWidget {
  const _DayPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: _pillBg,
        borderRadius: BorderRadius.all(Radius.circular(9999)),
      ),
      child: Text(text, style: _pillTextStyle),
    );
  }
}

/// Elements 10-15 / 19-25 style: one bubble, timestamp, delivery tick
/// (mine only, GAP-009). Marks itself displayed (T08's `markRead` hook,
/// task §5 — a no-op while read receipts are disabled) the moment it is
/// built for an incoming message.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.bubble, required this.controller});

  final ChatBubble bubble;
  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    if (!bubble.isMine) {
      // Fire-and-forget — task §5: "a no-op while read receipts are
      // disabled", never gates rendering.
      controller.onMessageDisplayed(bubble.id);
    }
    final alignment =
        bubble.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = bubble.isMine ? NexoraColors.loginBrand : NexoraColors.loginSurface;
    final textStyle =
        bubble.isMine ? _outgoingBubbleTextStyle : _incomingBubbleTextStyle;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _bubbleBorder),
          ),
          child: Text(
            // Decryption for display only (NFR-SEC-001) — a `null` text is
            // a graceful decrypt-failure degrade, never an error row.
            bubble.text ?? '(unable to decrypt this message)',
            style: textStyle,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formatClock(bubble.timestamp), style: _timestampStyle),
            if (bubble.isMine) ...[
              const SizedBox(width: 4),
              Icon(_tickIconFor(bubble.deliveryState), size: 16, color: _tickColorFor(bubble.deliveryState)),
            ],
          ],
        ),
      ],
    );
  }
}

/// Elements 26-31: `add` (inert, GAP-010), the multiline `Secure
/// message...` field, its own `lock` glyph, `mic` on the accent fill
/// (inert, GAP-010). Send is the field's own submit action — the contract
/// draws no send button (task §3), so `mic` is never repurposed as one.
class _Composer extends StatefulWidget {
  const _Composer({required this.controller});

  final ChatController controller;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    // Optimistic clear — the composer itself must never block on
    // `ensureSession`'s multi-second round trip (task §6 Risks); the row's
    // own appearance is driven entirely by the live `watchConversation`
    // stream once `SendMessageUseCase.call` persists it. If the send
    // ultimately fails, the composed text is restored (EARS-COMM-25: never
    // silently dropped).
    _textController.clear();
    unawaited(_sendAndRestoreOnFailure(trimmed));
  }

  Future<void> _sendAndRestoreOnFailure(String trimmed) async {
    await widget.controller.send(trimmed);
    // Real-hardware regression: `send` can still be in flight when the user
    // navigates away from the chat (taps back, or the peer resolves and the
    // route is popped) -- `dispose()` already ran and `_textController` is
    // gone by the time this resumes. Never touch controller/Get.snackbar
    // state after that.
    if (!mounted) return;
    if (widget.controller.sendError.value.isNotEmpty) {
      _textController.text = trimmed;
      Get.snackbar(
        'Message not sent',
        widget.controller.sendError.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _barBg,
        border: Border(top: BorderSide(color: _headerComposerBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RoundIconButton(
            icon: Icons.add,
            iconColor: NexoraColors.loginBrand,
            background: Colors.transparent,
            onTap: () => Get.snackbar(
              'Not available',
              'This isn\'t available yet.',
              snackPosition: SnackPosition.BOTTOM,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: NexoraColors.loginSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 16, color: NexoraColors.loginHeading),
                      decoration: const InputDecoration(
                        hintText: 'Secure message...',
                        hintStyle: _composerHintStyle,
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _submit,
                    ),
                  ),
                  const Icon(Icons.lock, size: 24, color: NexoraColors.loginBrand),
                ],
              ),
            ),
          ),
          _RoundIconButton(
            icon: Icons.mic,
            iconColor: Colors.white,
            background: NexoraColors.loginBrand,
            onTap: () => Get.snackbar(
              'Not available',
              'This isn\'t available yet.',
              snackPosition: SnackPosition.BOTTOM,
            ),
          ),
        ],
      ),
    );
  }
}

/// Elements 26/30 — a 48x48, r9999 tap target, `InkWell`/`Material` (never
/// `Listener`, this file's header).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Icon(icon, size: 24, color: iconColor)),
        ),
      ),
    );
  }
}

/// GAP-009's approved glyph mapping — `Queued` -> `radio_button_unchecked`,
/// `Sent`/`Accepted`/`Stored` (OQ-E06-T11-2) -> `check`, `Delivered` ->
/// `done_all` (grey), `Read` -> `done_all` (green), `Failed` (OQ-E06-T11-1)
/// -> `error_outline`, distinguished by icon shape alone at the SAME muted
/// grey token as `Delivered` — no new colour token.
IconData _tickIconFor(DeliveryState state) => switch (state) {
      DeliveryState.queued => Icons.radio_button_unchecked,
      DeliveryState.sent || DeliveryState.accepted || DeliveryState.stored =>
        Icons.check,
      DeliveryState.delivered => Icons.done_all,
      DeliveryState.read => Icons.done_all,
      DeliveryState.failed => Icons.error_outline,
    };

Color _tickColorFor(DeliveryState state) =>
    state == DeliveryState.read ? NexoraColors.settingsIconGreen : NexoraColors.loginBody;

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayLabel(DateTime dt) {
  final now = DateTime.now();
  if (_isSameDay(dt, now)) return 'Today';
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(dt, yesterday)) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

String _formatClock(DateTime dt) {
  final hour24 = dt.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

String _initialsOf(String name) {
  final alnum = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (alnum.isEmpty) return '?';
  return alnum.substring(0, alnum.length >= 2 ? 2 : 1).toUpperCase();
}
