// features/groups/domain — the group text-message wire envelope (E07-T06).
//
// The group analogue of `message_envelope.dart`'s `MessageEnvelope`: the
// plaintext structure `GroupCryptoService.encryptForGroup` encrypts as a
// single unit (task file §2/§5), carrying its `groupId`/`epoch` explicitly
// so the receiver never has to guess which chain to try (an explicit
// `group.no_chain` failure, never a silent fallback to another epoch —
// FR-GROUP-005 is exactly what a fallback would quietly defeat).
//
// **Why a second, small wire structure ([GroupMessageRoutingHeader]) also
// lives in this file.** `GroupCryptoService.decryptFromGroup(groupId, epoch,
// senderDeviceId, bytes)` (E07-T04) needs `groupId`/`epoch` BEFORE it can
// even attempt a decrypt — they select which `SenderKeyName` chain to try —
// but [GroupMessageEnvelope] carries them only INSIDE the ciphertext (per
// the encrypted-as-a-unit design above). Something has to carry them in the
// clear, alongside the ciphertext, purely for wire routing: this is the
// same shape `GroupCryptoService`'s own private `_KeyDistributionEnvelope`
// (E07-T04) already established for exactly this reason ("an implementation
// necessity of the documented contract, not a scope addition" — that file's
// own §9 Deviation). It has to be public here (unlike
// `_KeyDistributionEnvelope`) because the sending half
// (`send_group_message_use_case.dart`) and the receiving half
// (`inbound_pipeline.dart`) are two different files, and giving the wire
// format exactly one definition with two importers — rather than one file's
// codec and a second file's independently-guessed mirror — is the same
// discipline `message_envelope.dart`'s own header explains E05-B01 was a
// defect for not doing.
//
// **`senderDeviceId` inside [GroupMessageRoutingHeader] is deliberately NOT
// carried** — `RelayPacketFrame.source` (already clear, already present on
// every wire frame) is an equally-good routing candidate for which sender's
// chain to try, so duplicating it here would only be a second unauthenticated
// copy of the same non-authoritative hint. The AUTHORITATIVE sender is
// always [GroupMessageEnvelope.senderDeviceId], recovered only after a
// successful decrypt — never `RelayPacketFrame.source`/`frameSourceDeviceId`
// (E06-B04; task file §5's own contract for `InboundPipeline.
// handleGroupMessage`).
//
// This file does NOT decrypt, encrypt, persist, or touch the database —
// pure codecs, no I/O, mirroring `relay_packet_frame.dart`/
// `message_envelope.dart`/`group_control.dart`'s own discipline.
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/auth/google_auth_service.dart' show AppFailure;

/// The `controlKind` byte a group text message travels as — `1` is
/// `PrekeyExchange`'s (E06-T07), `2` is `DeliveryAckService`'s (E06-T08),
/// `3` is `GroupMembershipService`'s (E07-T03), `4` is `GroupCryptoService`'s
/// key-distribution slot (E07-T04). This was originally assigned `5`, but
/// this task's branch was created before E07-T09 (call signaling) merged
/// into `epic_07`, and T09 independently claimed `5` for
/// `kControlKindCallSignaling` (`call_signaling.dart`). Since T09 merged
/// first, `5` is now permanently call signaling; this slot is renumbered to
/// `6`, the next free value.
///
/// Unlike the four control kinds below it, this slot is dispatched by
/// `InboundPipeline` itself — registered onto its OWN
/// `registerControlHandler` seam from inside its own constructor
/// (`inbound_pipeline.dart`'s header explains why: this task's `files:`
/// fence updates that file directly and does not touch
/// `messaging_stack.dart`, so there is no external registration call site
/// available the way T07/T08/T03/T04 each had one).
const int kControlKindGroupMessage = 6;

/// Current, and so far only, [GroupMessageEnvelope] wire layout version.
const int groupMessageEnvelopeVersion = 1;

/// The plaintext structure `GroupCryptoService.encryptForGroup` encrypts as
/// one unit (task file §2/§3/§5) — the group analogue of `MessageEnvelope`.
/// Deterministic, length-prefixed binary encoding, matching
/// `MessageEnvelope`/`RelayPacketFrame`/`GroupControlFrame`'s own discipline
/// — never JSON, every length prefix bounds-checked against the *remaining*
/// buffer before it is used to slice.
///
/// Wire layout, big-endian:
///   [u8  formatVersion]
///   [u32 groupIdLen][groupId bytes]
///   [u32 epoch]
///   [u32 senderDeviceIdLen][senderDeviceId bytes]
///   [u32 messageIdLen][messageId bytes]
///   [u64 sequenceNumber]
///   [u64 createdAtMs]
///   [body bytes: remainder]
class GroupMessageEnvelope {
  const GroupMessageEnvelope({
    required this.groupId,
    required this.epoch,
    required this.senderDeviceId,
    required this.messageId,
    required this.sequenceNumber,
    required this.createdAtMs,
    required this.body,
  });

  final String groupId;
  final int epoch;

  /// The AUTHORITATIVE sender — written by the sender at compose time and
  /// recovered only once this envelope has been decrypted under a real
  /// sender-key chain. See this file's header for why this is never
  /// interchangeable with `RelayPacketFrame.source`/`frameSourceDeviceId`.
  final String senderDeviceId;

  /// Client-generated, globally unique — the dedupe key on the receive side
  /// (task file §5/§6: by `messageId`, never `(sender, sequenceNumber)`,
  /// since a group message can legitimately arrive more than once over
  /// different relay routes). Shares the same `messages.id` column 1:1
  /// messages already dedupe on.
  final String messageId;

  /// Monotonic per `(groupId, senderDeviceId)` — the same
  /// `messages`-table contract `MessageEnvelope.sequenceNumber` already
  /// documents, just partitioned by a group id instead of a peer id.
  final int sequenceNumber;

  final int createdAtMs;

  final Uint8List body;

  /// `formatVersion(1) + groupIdLen(4) + epoch(4) + senderDeviceIdLen(4) +
  /// messageIdLen(4) + sequenceNumber(8) + createdAtMs(8)`.
  static const int _headerFixedBytes = 1 + 4 + 4 + 4 + 4 + 8 + 8;

  /// Encodes this envelope into the bytes handed to
  /// `GroupCryptoService.encryptForGroup` as plaintext.
  Uint8List serialize() {
    final groupIdBytes = _utf8(groupId);
    final senderDeviceIdBytes = _utf8(senderDeviceId);
    final messageIdBytes = _utf8(messageId);

    final totalLength = _headerFixedBytes +
        groupIdBytes.length +
        senderDeviceIdBytes.length +
        messageIdBytes.length +
        body.length;

    final buffer = ByteData(totalLength);
    final bytes = buffer.buffer.asUint8List();
    var offset = 0;

    buffer.setUint8(offset, groupMessageEnvelopeVersion);
    offset += 1;

    offset = _putLengthPrefixed(buffer, bytes, offset, groupIdBytes);

    buffer.setUint32(offset, epoch);
    offset += 4;

    offset = _putLengthPrefixed(buffer, bytes, offset, senderDeviceIdBytes);
    offset = _putLengthPrefixed(buffer, bytes, offset, messageIdBytes);

    buffer.setUint64(offset, sequenceNumber);
    offset += 8;

    buffer.setUint64(offset, createdAtMs);
    offset += 8;

    bytes.setRange(offset, offset + body.length, body);

    return bytes;
  }

  /// Decodes bytes produced by [serialize]. Throws
  /// `AppFailure('group.malformed_message')` on any length/version/
  /// trailing-byte violation (task file §5's own contract) — deliberately
  /// the project's single error envelope, not `FormatException`, matching
  /// `GroupControlFrame.deserialize`'s own discipline for the same reason:
  /// a malformed group envelope is itself security-relevant enough to carry
  /// a stable, greppable code end to end.
  static GroupMessageEnvelope deserialize(Uint8List bytes) {
    try {
      if (bytes.isEmpty) {
        throw const AppFailure('group.malformed_message');
      }
      final view = ByteData.sublistView(bytes);
      var offset = 0;

      final version = view.getUint8(offset);
      if (version != groupMessageEnvelopeVersion) {
        throw const AppFailure('group.malformed_message');
      }
      offset += 1;

      final groupIdRead = _readLengthPrefixedString(view, bytes, offset);
      final groupId = groupIdRead.$1;
      offset = groupIdRead.$2;

      _requireRemaining(bytes, offset, 4);
      final epoch = view.getUint32(offset);
      offset += 4;

      final senderRead = _readLengthPrefixedString(view, bytes, offset);
      final senderDeviceId = senderRead.$1;
      offset = senderRead.$2;

      final messageIdRead = _readLengthPrefixedString(view, bytes, offset);
      final messageId = messageIdRead.$1;
      offset = messageIdRead.$2;

      _requireRemaining(bytes, offset, 8);
      final sequenceNumber = view.getUint64(offset);
      offset += 8;

      _requireRemaining(bytes, offset, 8);
      final createdAtMs = view.getUint64(offset);
      offset += 8;

      final body = Uint8List.fromList(bytes.sublist(offset));

      return GroupMessageEnvelope(
        groupId: groupId,
        epoch: epoch,
        senderDeviceId: senderDeviceId,
        messageId: messageId,
        sequenceNumber: sequenceNumber,
        createdAtMs: createdAtMs,
        body: body,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      // Any other slicing/range/UTF-8 failure collapses to the same typed
      // failure — never an uncaught RangeError/FormatException escaping
      // this codec (matches GroupControlFrame.deserialize's discipline).
      throw const AppFailure('group.malformed_message');
    }
  }

  static Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  static int _putLengthPrefixed(
    ByteData buffer,
    Uint8List bytes,
    int offset,
    Uint8List value,
  ) {
    buffer.setUint32(offset, value.length);
    offset += 4;
    bytes.setRange(offset, offset + value.length, value);
    return offset + value.length;
  }

  static void _requireRemaining(Uint8List bytes, int offset, int needed) {
    if (bytes.length < offset + needed) {
      throw const AppFailure('group.malformed_message');
    }
  }

  static (String, int) _readLengthPrefixedString(
    ByteData view,
    Uint8List bytes,
    int offset,
  ) {
    _requireRemaining(bytes, offset, 4);
    final length = view.getUint32(offset);
    offset += 4;
    _requireRemaining(bytes, offset, length);
    final value = utf8.decode(bytes.sublist(offset, offset + length));
    return (value, offset + length);
  }
}

/// Current, and so far only, [GroupMessageRoutingHeader] wire layout
/// version.
const int groupMessageRoutingHeaderVersion = 1;

/// The small CLEAR routing header wrapping a group message's ciphertext on
/// the wire — see this file's header for why it exists alongside
/// [GroupMessageEnvelope] rather than instead of it. Only ever read by the
/// frame's actual destination device (FR-ROUTE-003 gates forwarding on
/// `RelayPacketFrame.destination`, never on payload content — a relay
/// forwarding this frame to someone else never reaches this codec at all),
/// so a legitimate group member seeing its own group id/epoch in the clear
/// here discloses nothing they do not already know.
///
/// Wire layout, big-endian:
///   [u8  formatVersion]
///   [u32 groupIdLen][groupId bytes]
///   [u32 epoch]
///   [ciphertext bytes: remainder]
class GroupMessageRoutingHeader {
  const GroupMessageRoutingHeader({
    required this.groupId,
    required this.epoch,
    required this.ciphertext,
  });

  final String groupId;
  final int epoch;

  /// The `SenderKeyMessage` bytes `GroupCryptoService.encryptForGroup`
  /// returned — opaque here, never inspected by this codec.
  final Uint8List ciphertext;

  static const int _headerFixedBytes = 1 + 4 + 4;

  Uint8List serialize() {
    final groupIdBytes = Uint8List.fromList(utf8.encode(groupId));
    final totalLength =
        _headerFixedBytes + groupIdBytes.length + ciphertext.length;
    final buffer = ByteData(totalLength);
    final bytes = buffer.buffer.asUint8List();
    var offset = 0;

    buffer.setUint8(offset, groupMessageRoutingHeaderVersion);
    offset += 1;

    buffer.setUint32(offset, groupIdBytes.length);
    offset += 4;
    bytes.setRange(offset, offset + groupIdBytes.length, groupIdBytes);
    offset += groupIdBytes.length;

    buffer.setUint32(offset, epoch);
    offset += 4;

    bytes.setRange(offset, offset + ciphertext.length, ciphertext);

    return bytes;
  }

  /// Throws `AppFailure('group.malformed_message')` on any length/version
  /// violation — the same typed failure [GroupMessageEnvelope.deserialize]
  /// uses, since both describe the same "cannot make sense of this group
  /// message on the wire" outcome.
  static GroupMessageRoutingHeader deserialize(Uint8List bytes) {
    try {
      if (bytes.isEmpty) {
        throw const AppFailure('group.malformed_message');
      }
      final view = ByteData.sublistView(bytes);
      var offset = 0;

      final version = view.getUint8(offset);
      if (version != groupMessageRoutingHeaderVersion) {
        throw const AppFailure('group.malformed_message');
      }
      offset += 1;

      if (bytes.length < offset + 4) {
        throw const AppFailure('group.malformed_message');
      }
      final groupIdLength = view.getUint32(offset);
      offset += 4;
      if (bytes.length < offset + groupIdLength + 4) {
        throw const AppFailure('group.malformed_message');
      }
      final groupId = utf8.decode(bytes.sublist(offset, offset + groupIdLength));
      offset += groupIdLength;

      final epoch = view.getUint32(offset);
      offset += 4;

      final ciphertext = Uint8List.fromList(bytes.sublist(offset));

      return GroupMessageRoutingHeader(
        groupId: groupId,
        epoch: epoch,
        ciphertext: ciphertext,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('group.malformed_message');
    }
  }
}
