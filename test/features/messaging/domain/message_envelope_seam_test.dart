// E05-B01 — regression tests for the send/receive envelope seam.
//
// The defect (E05-B01.md): `SendMessageUseCase` encrypted the caller's raw
// plaintext directly, never building the `MessageEnvelope` that
// `ReceiveMessageUseCase` expects to deserialize on the other end -- so
// nothing this epic's sender produced could ever be received by this
// epic's receiver. Every test in this file puts T02's REAL output through
// T03's REAL input (the thing neither task's own suite ever did), using
// identity encrypt/decrypt (the bug file's own repro shape) so nothing but
// the envelope seam itself is under test -- E03's actual Double Ratchet
// crypto already has its own exhaustive suite elsewhere.
//
// Per the bug file's own instruction, these were confirmed FAILING on
// `epic_05` @ `af86907` (pre-fix `SendMessageUseCase`, raw plaintext
// on the wire) before the fix landed: `MessageEnvelope.deserialize` threw
// `FormatException` on the plaintext bytes handed to `enqueue`, exactly the
// bug file's own §Repro.
//
// `test_envelope_deserialize_rejects_a_non_envelope_payload` was corrected
// in review round 2 (E05-B01, F1): the original buffer used a huge bogus
// `conversationIdLength` that already threw on the OLD pre-fix parser for an
// unrelated reason (truncation, not version rejection), so it didn't
// actually prove the version-byte hardening. The replacement buffer parses
// SUCCESSFULLY into a garbage envelope under the OLD parser and is REJECTED
// only by the NEW version-byte check -- falsified by temporarily deleting
// the version-byte check (and its associated byte-consumption) from
// `MessageEnvelope.deserialize`: with it gone, this sub-test fails (no
// exception -- the buffer parses); with it restored, this sub-test passes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/messaging/domain/receive_message_use_case.dart';
import 'package:nexora/features/messaging/domain/send_message_use_case.dart';

/// A `CiphertextMessage` that just carries whatever bytes were actually
/// handed to `RelayEngine.enqueue` on the sending side -- i.e. exactly what
/// travels "on the wire" in this test's identity-encryption setup. Never
/// used with real Signal ciphertext (that's already covered by T02/T03's own
/// suites and by E03-T03's).
class _WireCiphertext implements CiphertextMessage {
  const _WireCiphertext(this.bytes);

  final Uint8List bytes;

  @override
  Uint8List serialize() => bytes;

  @override
  int getType() => CiphertextMessage.whisperType;
}

Uint8List _plaintext(String s) => Uint8List.fromList(utf8.encode(s));

/// Identity "encryption": returns the envelope bytes unchanged, per the bug
/// file's own §Repro ("the single most favourable case, where the receiver
/// decrypts bytes identical to what the sender encrypted, so nothing else
/// can be blamed").
Future<Uint8List> _identityEncrypt(String recipientDeviceId, Uint8List bytes) async =>
    bytes;

/// The matching identity "decryption" -- the seam `ReceiveMessageUseCase`
/// exposes for exactly this kind of deterministic test (already used the
/// same way by T03's own suite for its non-real-crypto tests).
Future<Uint8List> _identityDecrypt(
  SignalProtocolAddress address,
  CiphertextMessage ciphertext,
) async => (ciphertext as _WireCiphertext).bytes;

void main() {
  group('E05-B01 — send -> wire bytes -> receive seam', () {
    late AppDatabase senderDb;
    late AppDatabase receiverDb;

    setUp(() {
      senderDb = AppDatabase.forTesting(NativeDatabase.memory());
      receiverDb = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await senderDb.close();
      await receiverDb.close();
    });

    test(
      'test_EARS_MSG_2_sent_message_is_receivable_by_receive_use_case',
      () async {
        Uint8List? onTheWire;
        Future<String> captureEnqueue(
          String destination,
          Uint8List payload,
          int priority,
          Duration ttl,
        ) async {
          onTheWire = payload;
          return 'relay-1';
        }

        final sendUseCase = SendMessageUseCase(
          db: senderDb,
          selfDeviceId: 'device-A',
          encrypt: _identityEncrypt,
          enqueue: captureEnqueue,
        );

        final sent = await sendUseCase.call(
          'conv-1',
          'device-B',
          _plaintext('hello world'),
        );

        expect(
          onTheWire,
          isNotNull,
          reason: 'test setup: enqueue should have captured the wire bytes',
        );

        // Exactly what ReceiveMessageUseCase.call does with the bytes E04
        // hands back after decrypting -- this is the bug file's own §Repro,
        // step 3, but driven all the way through both real use cases
        // instead of a standalone probe.
        final receiveUseCase = ReceiveMessageUseCase(
          database: receiverDb,
          decrypt: _identityDecrypt,
        );

        final received = await receiveUseCase.call(
          'device-A',
          _WireCiphertext(onTheWire!),
        );

        expect(
          received,
          isNotNull,
          reason: 'a message this epic sends must be receivable by this '
              "epic's own receiver -- if this is null or throws, the "
              'envelope seam is broken again',
        );
        expect(received!.id, sent.id);
        expect(received.conversationId, 'conv-1');
        expect(received.sequenceNumber, sent.sequenceNumber);
      },
    );

    test(
      'test_EARS_MSG_2_duplicate_of_real_message_is_dropped',
      () async {
        Uint8List? onTheWire;
        Future<String> captureEnqueue(
          String destination,
          Uint8List payload,
          int priority,
          Duration ttl,
        ) async {
          onTheWire = payload;
          return 'relay-1';
        }

        final sendUseCase = SendMessageUseCase(
          db: senderDb,
          selfDeviceId: 'device-A',
          encrypt: _identityEncrypt,
          enqueue: captureEnqueue,
        );

        await sendUseCase.call('conv-1', 'device-B', _plaintext('hi bob'));
        final wireBytes = onTheWire!;

        final receiveUseCase = ReceiveMessageUseCase(
          database: receiverDb,
          decrypt: _identityDecrypt,
        );

        final first = await receiveUseCase.call(
          'device-A',
          _WireCiphertext(wireBytes),
        );
        expect(first, isNotNull);

        // The SAME real wire bytes, delivered a second time -- a plausible
        // relay retry (task file §6). Must be dropped, not double-stored.
        final second = await receiveUseCase.call(
          'device-A',
          _WireCiphertext(wireBytes),
        );
        expect(second, isNull);

        final rows = await receiverDb.select(receiverDb.messages).get();
        expect(rows, hasLength(1));
      },
    );

    test(
      'test_EARS_MSG_3_out_of_order_delivery_of_real_messages_orders_by_sequence',
      () async {
        final wireBytesByCall = <Uint8List>[];
        Future<String> captureEnqueue(
          String destination,
          Uint8List payload,
          int priority,
          Duration ttl,
        ) async {
          wireBytesByCall.add(payload);
          return 'relay-${wireBytesByCall.length}';
        }

        final sendUseCase = SendMessageUseCase(
          db: senderDb,
          selfDeviceId: 'device-A',
          encrypt: _identityEncrypt,
          enqueue: captureEnqueue,
        );

        final first = await sendUseCase.call(
          'conv-1',
          'device-B',
          _plaintext('first logically'),
        );
        final second = await sendUseCase.call(
          'conv-1',
          'device-B',
          _plaintext('second logically'),
        );
        expect(second.sequenceNumber, greaterThan(first.sequenceNumber));
        expect(wireBytesByCall, hasLength(2));

        final receiveUseCase = ReceiveMessageUseCase(
          database: receiverDb,
          decrypt: _identityDecrypt,
        );

        // Delivered in REVERSE physical order -- sequence-number-2's real
        // wire bytes arrive before sequence-number-1's.
        final receivedSecond = await receiveUseCase.call(
          'device-A',
          _WireCiphertext(wireBytesByCall[1]),
        );
        final receivedFirst = await receiveUseCase.call(
          'device-A',
          _WireCiphertext(wireBytesByCall[0]),
        );

        expect(receivedSecond, isNotNull);
        expect(receivedFirst, isNotNull);

        final rows = await (receiverDb.select(receiverDb.messages)
              ..orderBy([(t) => OrderingTerm.asc(t.sequenceNumber)]))
            .get();

        expect(rows, hasLength(2));
        expect(rows[0].id, first.id);
        expect(rows[0].sequenceNumber, first.sequenceNumber);
        expect(rows[1].id, second.id);
        expect(rows[1].sequenceNumber, second.sequenceNumber);
      },
    );

    test(
      'test_envelope_deserialize_rejects_a_non_envelope_payload',
      () {
        // The E05-B01 "silent mis-parse" case. This buffer is laid out
        // exactly as the OLD pre-fix wire format (no leading format-version
        // byte): [u32 idLen]["foo"][u32 convLen]["bar"][u64 seq][payload].
        // Its leading bytes happen to form small, plausible-looking
        // length-prefix values -- the shape a length-prefixed blob, a
        // protobuf, or an image chunk could plausibly have.
        //
        // Discriminating property (this is what makes the test actually
        // prove the hardening, rather than merely throw for an unrelated
        // reason): under the OLD pre-fix parser (no version byte, `epic_05`
        // @ `af86907`) this buffer PARSES SUCCESSFULLY into a plausible but
        // completely wrong envelope (id="foo", conversationId="bar", seq=7)
        // -- exactly the silent mis-parse this bug describes. Under the
        // fixed parser it must be REJECTED, because its first byte (0x00,
        // the high byte of the 4-byte idLen=3 field) is not
        // `envelopeFormatVersion` (0xE5) -- the version-byte check rejects
        // it before any length field is even trusted.
        final nonEnvelopePayload = Uint8List.fromList([
          0, 0, 0, 3, 0x66, 0x6f, 0x6f, // idLen=3 "foo"
          0, 0, 0, 3, 0x62, 0x61, 0x72, // convLen=3 "bar"
          0, 0, 0, 0, 0, 0, 0, 7, // seq=7
          1, 2, 3, // payload
        ]);

        expect(
          () => MessageEnvelope.deserialize(nonEnvelopePayload),
          throwsFormatException,
        );
      },
    );
  });
}
