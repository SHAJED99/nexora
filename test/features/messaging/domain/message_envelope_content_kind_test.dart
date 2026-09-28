// features/messaging/domain — `E05-T06` (ADR-0009): the content-kind
// discriminator on `MessageEnvelope`.
//
// The property that matters most here is the FIRST test's: a text envelope
// must serialize to bytes that are *identical* to what this app has always
// sent, not merely "compatible". That is what makes the whole change safe to
// ship before any attachment feature exists — the only path that actually
// runs today never executes a new encoding branch. It is asserted against a
// literal expected byte list rather than against a re-serialization, because
// a round-trip through the same (possibly wrong) encoder proves nothing.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/messaging/domain/message_envelope.dart';

/// The exact v1 bytes for the fixture below, written out by hand from the
/// documented layout — `[u8 0xE5][u32 idLen][id][u32 cidLen][cid][u64 seq]
/// [payload…]`, big-endian — so this file never asks the encoder under test
/// to vouch for itself.
Uint8List _expectedV1Bytes() {
  final id = utf8.encode('m-1');
  final cid = utf8.encode('c-1');
  final payload = utf8.encode('hello');
  return Uint8List.fromList(<int>[
    0xE5,
    0, 0, 0, id.length,
    ...id,
    0, 0, 0, cid.length,
    ...cid,
    0, 0, 0, 0, 0, 0, 0, 7, // sequenceNumber = 7
    ...payload,
  ]);
}

MessageEnvelope _fixture({MessageContentKind kind = MessageContentKind.text}) {
  return MessageEnvelope(
    id: 'm-1',
    conversationId: 'c-1',
    sequenceNumber: 7,
    payload: Uint8List.fromList(utf8.encode('hello')),
    kind: kind,
  );
}

void main() {
  test(
    'test_E05_T06_a_text_envelope_serializes_byte_identically_to_v1',
    () {
      expect(_fixture().serialize(), equals(_expectedV1Bytes()));
    },
  );

  test(
    'test_E05_T06_a_non_text_envelope_emits_the_v2_sentinel_and_kind_byte',
    () {
      final bytes = _fixture(kind: MessageContentKind.voice).serialize();

      expect(bytes[0], 0xE6, reason: 'the v2 sentinel');
      expect(bytes[1], 4, reason: 'voice == wire value 4');

      // Every subsequent field keeps its order and shifts by exactly one:
      // dropping the kind byte must reproduce the v1 encoding exactly.
      final withoutKind = Uint8List.fromList(
        <int>[0xE5, ...bytes.sublist(2)],
      );
      expect(withoutKind, equals(_expectedV1Bytes()));
    },
  );

  test('test_E05_T06_a_v1_envelope_decodes_as_text', () {
    final decoded = MessageEnvelope.deserialize(_expectedV1Bytes());

    expect(decoded.kind, MessageContentKind.text);
    expect(decoded.unknownKindWireValue, isNull);
    expect(utf8.decode(decoded.payload), 'hello');
    expect(decoded.id, 'm-1');
    expect(decoded.conversationId, 'c-1');
    expect(decoded.sequenceNumber, 7);
  });

  test('test_E05_T06_every_kind_round_trips', () {
    for (final kind in MessageContentKind.values) {
      final decoded = MessageEnvelope.deserialize(
        _fixture(kind: kind).serialize(),
      );
      expect(decoded.kind, kind, reason: '$kind did not survive a round trip');
      expect(decoded.unknownKindWireValue, isNull);
      expect(utf8.decode(decoded.payload), 'hello');
    }
  });

  test(
    'test_E05_T06_an_unknown_kind_is_preserved_not_guessed_and_not_dropped',
    () {
      // A kind byte from some future build. The three failure modes ADR-0009
      // forbids: throwing it away, refusing the whole message, or quietly
      // calling it text (the `E05-B01` silent-mis-parse class).
      final bytes = _fixture(kind: MessageContentKind.voice).serialize();
      bytes[1] = 99;

      final decoded = MessageEnvelope.deserialize(bytes);

      expect(decoded.kind, isNull, reason: 'not guessed — and NOT text');
      expect(decoded.unknownKindWireValue, 99, reason: 'the raw byte survives');
      // The message itself is intact: it is renderable-as-something, and the
      // receiver can be honest about what it cannot render.
      expect(decoded.id, 'm-1');
      expect(utf8.decode(decoded.payload), 'hello');

      // ...and it refuses to be re-emitted, rather than silently becoming a
      // different kind than it arrived as.
      expect(decoded.serialize, throwsStateError);
    },
  );

  test('test_E05_T06_a_v2_envelope_missing_its_kind_byte_throws', () {
    expect(
      () => MessageEnvelope.deserialize(Uint8List.fromList(<int>[0xE6])),
      throwsFormatException,
    );
  });

  test('test_E05_T06_a_foreign_leading_byte_is_still_rejected', () {
    // The E05-B01 hardening is widened to a two-value known set, not
    // loosened: anything that is neither 0xE5 nor 0xE6 still fails loudly.
    for (final leading in <int>[0x00, 0x01, 0xE4, 0xE7, 0xFF]) {
      final bytes = _expectedV1Bytes();
      bytes[0] = leading;
      expect(
        () => MessageEnvelope.deserialize(bytes),
        throwsFormatException,
        reason: '0x${leading.toRadixString(16)} must not parse',
      );
    }
  });
}
