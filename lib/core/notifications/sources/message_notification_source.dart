// core/notifications/sources — the `message` category producer (E10-T03).
//
// Adapts `InboundPipeline.delivered` (E06-T05, `inbound_pipeline.dart:264`)
// to `NotificationFacts` without touching `inbound_pipeline.dart` at all
// (task file §4 fence: "Subscribe to the stream — do not add a hook inside
// the pipeline"). This is the discharge of `E06-T05.md:124-125`'s own
// obligation: "Does NOT surface anything to the user. Counters and a
// stream; no UI, no notification (E10)."
//
// `InboundPipeline.delivered` also carries group-text messages (E07-T06) —
// there is no field on `Message` distinguishing a personal message from a
// group one without decrypting, and `E10-T06.md` §4 explicitly assigns
// group messages to this same `message` class ("those arrive through
// `InboundPipeline.delivered` and are already `E10-T03`'s `message`
// class"), so this source does not attempt to tell them apart. The same
// applies to voice messages and PTT (`OQ-E10-3`, task file §4): `Message`
// has no payload-kind field, so every delivered message is `message` until
// that changes.
//
// Never reads `message.ciphertext` — the only fields used are
// `conversationId` and `senderDeviceId`, both plaintext routing metadata
// already handled unencrypted by `InboundPipeline` itself (this file's own
// header). Does not decrypt, and does not add a decrypt path (task file
// §4).
import '../../../features/messaging/domain/message.dart';
import '../generated/notification_api.g.dart' show NotificationCategory;
import '../notification_dispatcher.dart' show NotificationSource;
import '../notification_policy.dart';

/// Maps each [Message] on [delivered] to a `message`-category
/// [NotificationFacts]. [selfDeviceId] guards against ever building a
/// notification for a message this device itself authored — `delivered`
/// should never emit one (every message on it came from a packet addressed
/// to this device and decrypted from a peer), but the check is cheap and
/// removes any doubt rather than relying on that invariant holding forever
/// (task file §5 signature: `selfDeviceId` is a required parameter for
/// exactly this reason).
class MessageNotificationSource implements NotificationSource {
  MessageNotificationSource(this.delivered, {required this.selfDeviceId});

  final Stream<Message> delivered;
  final String selfDeviceId;

  @override
  Stream<NotificationFacts> get facts => delivered
      .where((message) => message.senderDeviceId != selfDeviceId)
      .map(_toFacts);

  NotificationFacts _toFacts(Message message) {
    return NotificationFacts(
      category: NotificationCategory.message,
      conversationId: message.conversationId,
      peerDeviceId: message.senderDeviceId,
      // `RelationshipRepository` has no display-name column
      // (`design/gaps.md` GAP-003) — the sender's device id stands in for a
      // name, the same treatment already approved for the Conversations
      // screen (`conversations_controller.dart`'s own
      // `ConversationTile.from`). Never derived from message content.
      peerDisplayName: message.senderDeviceId,
      stableId: stableNotificationId(message.conversationId),
    );
  }
}
