// features/groups/domain — `E05-T06` (ADR-0009): the content-kind
// discriminator on `GroupMessageEnvelope`.
//
// The group mirror of `message_envelope_content_kind_test.dart`, with the two
// pre-existing differences this envelope has always had: a real monotonic
// version (`1`/`2`) rather than `MessageEnvelope`'s magic `0xE5`/`0xE6`
// sentinels, and `AppFailure('group.malformed_message')` rather than
// `FormatException` as the single typed failure for every malformed case.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/features/groups/domain/group_message_envelope.dart';
import 'package:nexora/features/messaging/domain/message_envelope.dart'
    show MessageContentKind;

/// The exact v1 bytes for the fixture below, written out by hand from the
/// documented layout — `[u8 1][u32 gidLen][gid][u32 epoch][u32 sndLen][snd]
/// [u32 midLen][mid][u64 seq][u64 createdAtMs][body…]`, big-endian.
Uint8List _expectedV1Bytes() {
  final gid = utf8.encode('g-1');
  final snd = utf8.encode('d-1');
  final mid = utf8.encode('m-1');
  final body = utf8.encode('hello');
  return Uint8List.fromList(<int>[
    1,
    0, 0, 0, gid.length,
    ...gid,
    0, 0, 0, 3, // epoch = 3
    0, 0, 0, snd.length,
    ...snd,
    0, 0, 0, mid.length,
    ...mid,
    0, 0, 0, 0, 0, 0, 0, 7, // sequenceNumber = 7
    0, 0, 0, 0, 0, 0, 0, 9, // createdAtMs = 9
    ...body,
  ]);
}

GroupMessageEnvelope _fixture({
  MessageContentKind kind = MessageContentKind.text,
}) {
  return GroupMessageEnvelope(
    groupId: 'g-1',
    epoch: 3,
    senderDeviceId: 'd-1',
    messageId: 'm-1',
    sequenceNumber: 7,
    createdAtMs: 9,
    body: Uint8List.fromList(utf8.encode('hello')),
    kind: kind,
  );
}

Matcher get _malformed => isA<AppFailure>().having(
      (f) => f.code,
      'code',
      'group.malformed_message',
    );

void main() {
  test(
    'test_E05_T06_a_text_group_envelope_serializes_byte_identically_to_v1',
    () {
      expect(_fixture().serialize(), equals(_expectedV1Bytes()));
    },
  );

  test(
    'test_E05_T06_a_non_text_group_envelope_emits_v2_and_the_kind_byte',
    () {
      final bytes = _fixture(kind: MessageContentKind.image).serialize();

      expect(bytes[0], 2, reason: 'the v2 version');
      expect(bytes[1], 2, reason: 'image == wire value 2');

      final withoutKind = Uint8List.fromList(<int>[1, ...bytes.sublist(2)]);
      expect(withoutKind, equals(_expectedV1Bytes()));
    },
  );

  test('test_E05_T06_a_v1_group_envelope_decodes_as_text', () {
    final decoded = GroupMessageEnvelope.deserialize(_expectedV1Bytes());

    expect(decoded.kind, MessageContentKind.text);
    expect(decoded.unknownKindWireValue, isNull);
    expect(decoded.groupId, 'g-1');
    expect(decoded.epoch, 3);
    expect(decoded.senderDeviceId, 'd-1');
    expect(decoded.messageId, 'm-1');
    expect(decoded.sequenceNumber, 7);
    expect(decoded.createdAtMs, 9);
    expect(utf8.decode(decoded.body), 'hello');
  });

  test('test_E05_T06_every_group_kind_round_trips', () {
    for (final kind in MessageContentKind.values) {
      final decoded = GroupMessageEnvelope.deserialize(
        _fixture(kind: kind).serialize(),
      );
      expect(decoded.kind, kind, reason: '$kind did not survive a round trip');
      expect(decoded.unknownKindWireValue, isNull);
      expect(decoded.groupId, 'g-1');
      expect(utf8.decode(decoded.body), 'hello');
    }
  });

  test(
    'test_E05_T06_an_unknown_group_kind_is_preserved_not_guessed_or_dropped',
    () {
      final bytes = _fixture(kind: MessageContentKind.image).serialize();
      bytes[1] = 99;

      final decoded = GroupMessageEnvelope.deserialize(bytes);

      expect(decoded.kind, isNull, reason: 'not guessed — and NOT text');
      expect(decoded.unknownKindWireValue, 99);
      // Intact enough to persist and to dedupe on: the authoritative sender
      // and the message id survive, which is what makes "preserved" mean
      // anything at all here.
      expect(decoded.senderDeviceId, 'd-1');
      expect(decoded.messageId, 'm-1');
      expect(utf8.decode(decoded.body), 'hello');

      expect(decoded.serialize, throwsA(_malformed));
    },
  );

  test('test_E05_T06_a_v2_group_envelope_missing_its_kind_byte_throws', () {
    expect(
      () => GroupMessageEnvelope.deserialize(Uint8List.fromList(<int>[2])),
      throwsA(_malformed),
    );
  });

  test('test_E05_T06_a_foreign_group_version_byte_is_still_rejected', () {
    for (final leading in <int>[0, 3, 0xE5, 0xFF]) {
      final bytes = _expectedV1Bytes();
      bytes[0] = leading;
      expect(
        () => GroupMessageEnvelope.deserialize(bytes),
        throwsA(_malformed),
        reason: 'version $leading must not parse',
      );
    }
  });
}
