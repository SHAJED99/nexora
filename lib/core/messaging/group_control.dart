// core/messaging — the group membership control wire format (E07-T03).
//
// **Security posture (task file §2, OQ-E07-6).** Every existing
// `PayloadType.control` sub-protocol (`PrekeyExchange` kind 1, `DeliveryAck`
// kind 2) travels as CLEARTEXT bytes, authenticated by nothing stronger than
// `RelayPacketFrame.source` — a field any mesh node can set to anything
// (E06-B04). A membership control frame must not inherit that weakness: a
// forged `frame.source` on a `memberRemoved` frame would let any device on
// the mesh remove any member of any group. So this file's wire body is never
// sent in the clear — `GroupMembershipService` (this task's other half)
// always encrypts a serialized [GroupControlFrame] through the *pairwise*
// Double Ratchet session with the recipient (the same `CryptoService`
// E06-T07/E03-T03 already established) before it ever reaches
// `TransportService`, and only trusts an inbound frame's claimed actor once
// `CryptoService.decrypt` has cryptographically proven which session
// produced it (never `frame.source` directly — see
// `group_membership_service.dart`'s header for the receive-side half of this
// design).
//
// [kControlKindGroupControl] is still carried as a `PayloadType.control`
// frame, dispatched through `InboundPipeline`'s existing keyed
// `registerControlHandler` seam (`inbound_pipeline.dart`, unmodified by this
// task) exactly like kinds 1 and 2 — the seam itself does not care whether a
// registrant's own body happens to be ciphertext.
//
// [encodeCiphertextControlBody]/[decodeCiphertextControlBody] are the small
// nesting codec that lets a `CiphertextMessage` (a `PreKeySignalMessage` or a
// `SignalMessage`, indistinguishable by bytes alone per `CiphertextCodec`'s
// own header) travel inside a control frame's opaque `payload`, the same
// explicit-tag discipline `CiphertextCodec`/`RelayPacketFrame` already use —
// no heuristic, no try-both.
//
// This file does NOT decrypt, encrypt, apply a membership change, or touch
// the database — pure codec, no I/O (task file §4/§5), mirroring
// `relay_packet_frame.dart`/`ciphertext_codec.dart`'s own discipline.
import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../auth/google_auth_service.dart' show AppFailure;
import '../persistence/group_tables.dart' show GroupEventKind;
import 'ciphertext_codec.dart';
import 'relay_packet_frame.dart';

/// The `controlKind` byte `InboundPipeline` dispatches on
/// (`inbound_pipeline.dart`'s keyed `Map<int, ControlHandler>`, retrofitted
/// by `OQ-E06-T08-2`) — `1` is `PrekeyExchange`'s (E06-T07), `2` is
/// `DeliveryAckService`'s (E06-T08); this task's group membership protocol
/// takes the next unused value. Registered against
/// `GroupMembershipService.handleWireFrame` in `messaging_stack.dart`.
const int kControlKindGroupControl = 3;

/// Current, and so far only, [GroupControlFrame] wire layout version.
const int groupControlFrameVersion = 1;

/// Explicit, stable wire tags for [GroupEventKind] — deliberately NOT the
/// enum's declaration-order index, so the wire value survives that
/// declaration being reordered (same discipline as `PayloadType.tag`).
const Map<GroupEventKind, int> _kindTags = {
  GroupEventKind.created: 1,
  GroupEventKind.renamed: 2,
  GroupEventKind.memberAdded: 3,
  GroupEventKind.memberRemoved: 4,
  GroupEventKind.adminGranted: 5,
  GroupEventKind.adminRevoked: 6,
  GroupEventKind.ownershipTransferred: 7,
  GroupEventKind.deleted: 8,
};

GroupEventKind _kindFromTag(int tag) {
  for (final entry in _kindTags.entries) {
    if (entry.value == tag) return entry.key;
  }
  throw const AppFailure('group.malformed_control');
}

/// The serialized control payload for every FR-GROUP-002 membership action
/// (task file §3). Deterministic binary encoding, length-prefixed strings —
/// the same idiom `relay_packet_frame.dart`/`prekey_exchange.dart` already
/// establish; never JSON.
///
/// Wire layout (task file §5, big-endian, matching `RelayPacketFrame`'s own
/// discipline — every length prefix bounds-checked against the *remaining*
/// buffer before it is used to slice):
///
///   [u8  version]
///   [u8  kind]                                  // explicit tag, see [_kindTags]
///   [u32 groupIdLen][groupId bytes]
///   [u32 epoch]
///   [u32 actorLen][actorDeviceId bytes]
///   [u8  hasSubject][u32 subjectLen][subject bytes]      // only if hasSubject
///   [u8  hasName][u32 nameLen][name bytes]                // only if hasName
///   [u8  hasMemberList][u32 count]([u32 len][bytes])*     // only if hasMemberList
///   [u64 createdAtMs]
class GroupControlFrame {
  const GroupControlFrame({
    required this.kind,
    required this.groupId,
    required this.epoch,
    required this.actorDeviceId,
    required this.createdAtMs,
    this.version = groupControlFrameVersion,
    this.subjectDeviceId,
    this.name,
    this.memberList,
  });

  final int version;
  final GroupEventKind kind;
  final String groupId;
  final int epoch;
  final String actorDeviceId;

  /// The member the event is about (added/removed/promoted/demoted/the new
  /// owner) — null for a group-level event (`renamed`, `deleted`) or a
  /// self-action where the caller already folds subject into actor (`leave`
  /// is sent as `memberRemoved` with `subjectDeviceId == actorDeviceId`, see
  /// `group_membership_service.dart`).
  final String? subjectDeviceId;

  /// The new group name — only meaningful for `renamed`/`created`.
  final String? name;

  /// The full initial roster — only meaningful for `created`, so an invitee
  /// who has never heard of this group learns it in one frame (task file
  /// §3).
  final List<String>? memberList;

  final int createdAtMs;

  /// Encodes this frame per the layout documented above. Round-trips exactly
  /// through [deserialize].
  Uint8List serialize() {
    final groupIdBytes = _utf8(groupId);
    final actorBytes = _utf8(actorDeviceId);
    final subjectBytes = subjectDeviceId == null ? null : _utf8(subjectDeviceId!);
    final nameBytes = name == null ? null : _utf8(name!);
    final memberListBytes = memberList?.map(_utf8).toList();

    var totalLength = 1 + // version
        1 + // kind
        4 + groupIdBytes.length +
        4 + // epoch
        4 + actorBytes.length +
        1 + (subjectBytes == null ? 0 : 4 + subjectBytes.length) +
        1 + (nameBytes == null ? 0 : 4 + nameBytes.length) +
        1; // hasMemberList
    if (memberListBytes != null) {
      totalLength += 4; // count
      for (final m in memberListBytes) {
        totalLength += 4 + m.length;
      }
    }
    totalLength += 8; // createdAtMs

    final buffer = ByteData(totalLength);
    final bytes = buffer.buffer.asUint8List();
    var offset = 0;

    buffer.setUint8(offset, version);
    offset += 1;

    buffer.setUint8(offset, _kindTags[kind]!);
    offset += 1;

    offset = _putLengthPrefixed(buffer, bytes, offset, groupIdBytes);

    buffer.setUint32(offset, epoch);
    offset += 4;

    offset = _putLengthPrefixed(buffer, bytes, offset, actorBytes);

    buffer.setUint8(offset, subjectBytes == null ? 0 : 1);
    offset += 1;
    if (subjectBytes != null) {
      offset = _putLengthPrefixed(buffer, bytes, offset, subjectBytes);
    }

    buffer.setUint8(offset, nameBytes == null ? 0 : 1);
    offset += 1;
    if (nameBytes != null) {
      offset = _putLengthPrefixed(buffer, bytes, offset, nameBytes);
    }

    buffer.setUint8(offset, memberListBytes == null ? 0 : 1);
    offset += 1;
    if (memberListBytes != null) {
      buffer.setUint32(offset, memberListBytes.length);
      offset += 4;
      for (final m in memberListBytes) {
        offset = _putLengthPrefixed(buffer, bytes, offset, m);
      }
    }

    buffer.setUint64(offset, createdAtMs);
    offset += 8;

    return bytes;
  }

  /// Decodes bytes produced by [serialize]. Throws
  /// `AppFailure('group.malformed_control')` on any length/version/trailing-
  /// byte violation — task file §5's own contract, deliberately not
  /// `FormatException` (unlike this file's sibling codecs) since this is the
  /// one control body whose malformity is itself security-relevant enough to
  /// travel through the project's single error envelope. Never returns a
  /// partially-built frame.
  static GroupControlFrame deserialize(Uint8List bytes) {
    try {
      if (bytes.isEmpty) {
        throw const AppFailure('group.malformed_control');
      }
      final view = ByteData.sublistView(bytes);
      var offset = 0;

      final version = view.getUint8(offset);
      if (version != groupControlFrameVersion) {
        throw const AppFailure('group.malformed_control');
      }
      offset += 1;

      _requireRemaining(bytes, offset, 1);
      final kind = _kindFromTag(view.getUint8(offset));
      offset += 1;

      final groupIdRead = _readLengthPrefixedString(view, bytes, offset);
      final groupId = groupIdRead.$1;
      offset = groupIdRead.$2;

      _requireRemaining(bytes, offset, 4);
      final epoch = view.getUint32(offset);
      offset += 4;

      final actorRead = _readLengthPrefixedString(view, bytes, offset);
      final actorDeviceId = actorRead.$1;
      offset = actorRead.$2;

      _requireRemaining(bytes, offset, 1);
      final hasSubject = view.getUint8(offset);
      offset += 1;
      String? subjectDeviceId;
      if (hasSubject == 1) {
        final subjectRead = _readLengthPrefixedString(view, bytes, offset);
        subjectDeviceId = subjectRead.$1;
        offset = subjectRead.$2;
      } else if (hasSubject != 0) {
        throw const AppFailure('group.malformed_control');
      }

      _requireRemaining(bytes, offset, 1);
      final hasName = view.getUint8(offset);
      offset += 1;
      String? name;
      if (hasName == 1) {
        final nameRead = _readLengthPrefixedString(view, bytes, offset);
        name = nameRead.$1;
        offset = nameRead.$2;
      } else if (hasName != 0) {
        throw const AppFailure('group.malformed_control');
      }

      _requireRemaining(bytes, offset, 1);
      final hasMemberList = view.getUint8(offset);
      offset += 1;
      List<String>? memberList;
      if (hasMemberList == 1) {
        _requireRemaining(bytes, offset, 4);
        final count = view.getUint32(offset);
        offset += 4;
        final members = <String>[];
        for (var i = 0; i < count; i++) {
          final memberRead = _readLengthPrefixedString(view, bytes, offset);
          members.add(memberRead.$1);
          offset = memberRead.$2;
        }
        memberList = members;
      } else if (hasMemberList != 0) {
        throw const AppFailure('group.malformed_control');
      }

      _requireRemaining(bytes, offset, 8);
      final createdAtMs = view.getUint64(offset);
      offset += 8;

      if (offset != bytes.length) {
        throw const AppFailure('group.malformed_control');
      }

      return GroupControlFrame(
        version: version,
        kind: kind,
        groupId: groupId,
        epoch: epoch,
        actorDeviceId: actorDeviceId,
        subjectDeviceId: subjectDeviceId,
        name: name,
        memberList: memberList,
        createdAtMs: createdAtMs,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      // Any other slicing/range failure (a corrupt length prefix that
      // `_requireRemaining` did not already catch, a bad UTF-8 sequence,
      // ...) collapses to the same typed failure — never an uncaught
      // `RangeError`/`FormatException` escaping this codec.
      throw const AppFailure('group.malformed_control');
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
      throw const AppFailure('group.malformed_control');
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

/// Nests a `CiphertextMessage` inside a group-control `payload`: one leading
/// type-tag byte (matching [PayloadType.tag] for the two ciphertext tags —
/// `preKeySignalMessage`/`signalMessage`, mapped via [CiphertextCodec], never
/// [PayloadType.control] itself) followed by `message.serialize()`. This is
/// what makes the outer wire frame's `payload` opaque ciphertext, not a
/// cleartext [GroupControlFrame] — see this file's header for why that
/// matters here specifically.
Uint8List encodeCiphertextControlBody(CiphertextMessage message) {
  final (payloadType, bytes) = CiphertextCodec.encode(message);
  final body = Uint8List(1 + bytes.length);
  body[0] = payloadType.tag;
  body.setRange(1, body.length, bytes);
  return body;
}

/// The inverse of [encodeCiphertextControlBody]. Throws
/// `AppFailure('group.malformed_control')` on an empty buffer or an
/// unrecognised leading tag; whatever [CiphertextCodec.decode] itself throws
/// (a `CryptoDecryptFailure` on an unparseable ciphertext body) propagates
/// unchanged.
CiphertextMessage decodeCiphertextControlBody(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const AppFailure('group.malformed_control');
  }
  final PayloadType type;
  try {
    type = PayloadType.fromTag(bytes[0]);
  } on FormatException {
    throw const AppFailure('group.malformed_control');
  }
  if (type == PayloadType.control) {
    throw const AppFailure('group.malformed_control');
  }
  return CiphertextCodec.decode(type, bytes.sublist(1));
}
