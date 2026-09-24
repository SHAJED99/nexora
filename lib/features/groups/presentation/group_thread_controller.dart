// features/groups/presentation — the group thread (E07-T18).
//
// A SEPARATE controller from `ChatController`, deliberately. `ChatController`
// treats its `conversationId` as a Signal PEER DEVICE id and runs an X3DH
// handshake against it; `E07-B01` measured what a group id does there
// (undecryptable bubbles in, a non-retryable send failure out), the human
// classified it P1 and chose "gate the tap" on 2026-09-02, and `E07-B05`
// re-closed a second door into it. `E07-B01`'s own scope fence forbids
// widening that controller into a multi-party one. This file is the
// alternative that fence points at.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart' show GroupEventRow;
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/domain/group_message_envelope.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/message.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// The group send seam. `SendGroupMessageUseCase` is reached through
/// `MessagingStack`, whose construction a controller test must not be forced
/// to stand up — the same narrow-seam reasoning `GroupCreateController`
/// documents for `CreateGroup`.
typedef SendGroupText = Future<AppFailure?> Function({
  required String groupId,
  required Uint8List body,
});

/// The group decrypt seam, same reasoning.
typedef DecryptGroupBody = Future<Uint8List> Function({
  required String groupId,
  required int epoch,
  required String senderDeviceId,
  required Uint8List bytes,
});

enum GroupThreadState { loading, ready, error }

/// One rendered row. A thread is a single ordered list of **bubbles and
/// event lines merged by timestamp** (contract states 2/3/4), so both shapes
/// share one type rather than forcing the view to zip two lists.
@immutable
class GroupThreadRow {
  const GroupThreadRow._({
    required this.id,
    required this.timestamp,
    required this.isEvent,
    this.isMine = false,
    this.senderDeviceId,
    this.text,
    this.senderIsBlocked = false,
  });

  /// A message bubble (contract states 2 and 3).
  factory GroupThreadRow.message({
    required String id,
    required DateTime timestamp,
    required bool isMine,
    required String? senderDeviceId,
    required String? text,
    required bool senderIsBlocked,
  }) =>
      GroupThreadRow._(
        id: id,
        timestamp: timestamp,
        isEvent: false,
        isMine: isMine,
        senderDeviceId: senderDeviceId,
        text: text,
        senderIsBlocked: senderIsBlocked,
      );

  /// A membership event line (contract state 4).
  factory GroupThreadRow.event({
    required String id,
    required DateTime timestamp,
    required String sentence,
  }) =>
      GroupThreadRow._(
        id: id,
        timestamp: timestamp,
        isEvent: true,
        text: sentence,
      );

  final String id;
  final DateTime timestamp;
  final bool isEvent;
  final bool isMine;

  /// `null` for this device's own messages and for event lines. GAP-020:
  /// "outgoing bubbles do not [carry attribution] — the design never labels
  /// the user to themselves."
  final String? senderDeviceId;

  /// The body, or the event sentence. `null` on a genuine decrypt failure
  /// only — which is NOT the blocked case, see [senderIsBlocked].
  final String? text;

  /// GAP-045, human-approved option (b), 2026-09-25. Distinct from
  /// `text == null` on purpose: a blocked member still holds a valid sender
  /// key, so their message usually decrypts without difficulty. It is
  /// withheld by POLICY, not by failure, and the human's instruction was
  /// explicit — "do not describe it as undecryptable, failed to load, or
  /// otherwise imply a cryptographic/decryption failure". Conflating the two
  /// flags is exactly how that instruction gets violated by accident.
  final bool senderIsBlocked;
}

class GroupThreadController extends GetxController {
  GroupThreadController({
    required this.groupId,
    required ConversationRepository repo,
    required GroupRepository groups,
    required RelationshipRepository relationships,
    SendGroupText? send,
    DecryptGroupBody? decrypt,
  })  : _repo = repo, // ignore: prefer_initializing_formals
        _groups = groups, // ignore: prefer_initializing_formals
        _relationships = relationships, // ignore: prefer_initializing_formals
        _send = send ?? _defaultSend,
        _decrypt = decrypt ?? _defaultDecrypt;

  final String groupId;
  final ConversationRepository _repo;
  final GroupRepository _groups;
  final RelationshipRepository _relationships;
  final SendGroupText _send;
  final DecryptGroupBody _decrypt;

  static Future<AppFailure?> _defaultSend({
    required String groupId,
    required Uint8List body,
  }) =>
      Get.find<MessagingStack>().sendGroupMessage.send(
            groupId: groupId,
            body: body,
          );

  static Future<Uint8List> _defaultDecrypt({
    required String groupId,
    required int epoch,
    required String senderDeviceId,
    required Uint8List bytes,
  }) =>
      Get.find<MessagingStack>().groupCryptoService.decryptFromGroup(
            groupId: groupId,
            epoch: epoch,
            senderDeviceId: senderDeviceId,
            bytes: bytes,
          );

  final RxList<GroupThreadRow> rows = <GroupThreadRow>[].obs;
  final Rx<GroupThreadState> state = GroupThreadState.loading.obs;
  final RxString groupName = ''.obs;

  /// Non-empty immediately after a failed [send]. Cleared on the next
  /// attempt — the same contract `ChatController.sendError` already carries.
  final RxString sendError = ''.obs;
  final RxBool sending = false.obs;

  StreamSubscription<List<Message>>? _subscription;

  /// Body cache keyed by message id. A stored message is immutable, and a
  /// group decrypt spends a message key — the same reason
  /// `ConversationsController` keeps its own group-preview cache.
  final Map<String, String?> _bodyCache = <String, String?>{};

  /// Monotonic render generation. [render] is async — it awaits the group
  /// row, the blocked set and every body — so two renders can be in flight
  /// at once, and the one that STARTED first can FINISH last.
  ///
  /// Found by the `chat-group` design probe, not by reasoning: a
  /// subscription created before the database was seeded emitted an empty
  /// list, that render's awaits resolved after the seeded one had already
  /// published four rows, and it overwrote them with one. In the app the
  /// same shape is reachable whenever a message arrives while an earlier
  /// render is still resolving bodies — the thread would flicker back to a
  /// stale list. A generation check is the fix; cancelling the subscription
  /// is not, because the in-flight render is not part of the subscription.
  int _renderGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  @override
  void onClose() {
    unawaited(_subscription?.cancel());
    super.onClose();
  }

  Future<void> load() async {
    state.value = GroupThreadState.loading;
    try {
      final group = await _groups.groupRow(groupId);
      if (group == null) {
        state.value = GroupThreadState.error;
        return;
      }
      groupName.value = group.name;
      await _subscription?.cancel();
      _subscription = _repo.watchConversation(groupId).listen(
        (messages) => unawaited(render(messages)),
        onError: (Object _) => state.value = GroupThreadState.error,
      );
    } on Object {
      state.value = GroupThreadState.error;
    }
  }

  /// Rebuilds [rows] from a message page plus this group's event rows.
  /// Visible for testing so a test can drive one deterministic render
  /// without racing a Drift stream.
  @visibleForTesting
  Future<void> render(List<Message> messages) async {
    final generation = ++_renderGeneration;
    final group = await _groups.groupRow(groupId);
    final epoch = group?.membershipEpoch;
    final blocked = await _blockedDeviceIds();
    final self = _repo.selfDeviceId;

    final built = <GroupThreadRow>[];
    for (final m in messages) {
      final isMine = m.senderDeviceId == self;
      final senderBlocked = !isMine && blocked.contains(m.senderDeviceId);
      built.add(
        GroupThreadRow.message(
          id: m.id,
          timestamp: DateTime.fromMillisecondsSinceEpoch(m.createdAt),
          isMine: isMine,
          senderDeviceId: isMine ? null : m.senderDeviceId,
          // A blocked sender's body is never resolved AT ALL -- not
          // decrypted and then hidden, not read in the first place.
          // Withholding it only at the view layer would leave the plaintext
          // one careless widget away from the screen.
          text: senderBlocked ? null : await _body(m, epoch),
          senderIsBlocked: senderBlocked,
        ),
      );
    }

    for (final e in await _groups.eventsFor(groupId)) {
      built.add(
        GroupThreadRow.event(
          id: e.id,
          timestamp: DateTime.fromMillisecondsSinceEpoch(e.createdAt),
          sentence: eventSentence(e),
        ),
      );
    }

    if (generation != _renderGeneration) {
      // A newer render started while this one was resolving bodies. Its
      // result is the current one; publishing this would visibly regress
      // the thread to older data.
      return;
    }

    built.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    rows.assignAll(built);
    state.value = GroupThreadState.ready;
  }

  Future<Set<String>> _blockedDeviceIds() async {
    final all = await _relationships.listAll();
    return all
        .where((r) => r.state == RelationshipState.blocked)
        .map((r) => r.deviceId)
        .toSet();
  }

  /// Resolves [row]'s body for display. `null` on any genuine failure, so
  /// the row still renders — never an error row, the same graceful degrade
  /// `ChatController` and `ConversationsController` already establish.
  Future<String?> _body(Message row, int? epoch) async {
    if (_bodyCache.containsKey(row.id)) {
      return _bodyCache[row.id];
    }
    String? body;
    try {
      final persisted = row.plaintextPayload;
      if (persisted != null) {
        // E04-B20: the body persisted at send/receive time. Never a second
        // `decryptFromGroup` on a spent message key.
        body = utf8.decode(persisted);
      } else if (epoch != null) {
        final plaintext = await _decrypt(
          groupId: groupId,
          epoch: epoch,
          senderDeviceId: row.senderDeviceId,
          bytes: row.ciphertext,
        );
        body = utf8.decode(GroupMessageEnvelope.deserialize(plaintext).body);
      }
    } on Object {
      body = null;
    }
    _bodyCache[row.id] = body;
    return body;
  }

  /// GAP-020's approved event lines: "Ahmed added David", "Group renamed to
  /// Work" — one per `group_events` row. The design supplies the *shape*;
  /// the ids are data. No display-name lookup exists anywhere in this app
  /// (`Relationship` carries no name field), which is why the already-
  /// shipped `conversations.md` sender prefix renders a device id too.
  @visibleForTesting
  static String eventSentence(GroupEventRow e) {
    final actor = e.actorDeviceId;
    final subject = e.subjectDeviceId ?? '';
    final matches = GroupEventKind.values.where((k) => k.name == e.kind);
    final kind = matches.isEmpty ? null : matches.first;
    return switch (kind) {
      GroupEventKind.renamed => '$actor renamed the group',
      GroupEventKind.memberAdded => '$actor added $subject',
      GroupEventKind.memberRemoved => '$actor removed $subject',
      GroupEventKind.adminGranted => '$actor made $subject an admin',
      GroupEventKind.adminRevoked => '$actor removed admin from $subject',
      GroupEventKind.ownershipTransferred =>
        '$actor transferred ownership to $subject',
      GroupEventKind.deleted => '$actor deleted the group',
      GroupEventKind.created => '$actor created the group',
      // An unrecognised kind is RENDERED, not dropped: a membership change
      // this build does not know about still happened, and silently omitting
      // it would under-report the group's own history.
      null => '$actor changed the group',
    };
  }

  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || sending.value) {
      return;
    }
    sending.value = true;
    sendError.value = '';
    try {
      final failure = await _send(
        groupId: groupId,
        body: Uint8List.fromList(utf8.encode(body)),
      );
      if (failure != null) {
        sendError.value = 'Could not send this message. Try again.';
      }
    } finally {
      sending.value = false;
    }
  }
}
