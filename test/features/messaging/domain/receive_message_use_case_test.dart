// Tests for ReceiveMessageUseCase + MessageEnvelope (E05-T03,
// EARS-MSG-2/EARS-MSG-3).
//
// Two testing seams are used deliberately, for two different kinds of
// proof:
//  - `test_EARS_MSG_2_duplicate_packet_dropped_not_double_stored` runs the
//    REAL E03 CryptoService end to end (two live Signal parties, real X3DH +
//    Double Ratchet) — this is the one test that proves the whole pipeline
//    (decrypt -> deserialize -> dedup -> persist) genuinely works together,
//    not just each piece in isolation.
//  - The concurrency and out-of-order tests inject a fake `decrypt` callback
//    (the use case's constructor seam, not part of its `call` contract) so
//    they can deterministically control exactly which plaintext bytes come
//    back for which ciphertext, and run truly concurrent calls, without
//    entangling the assertion with the Double Ratchet's own independent
//    replay/ordering behavior (already proven separately in E03-T03's own
//    test suite). This isolates "is the DB-level dedup+insert atomic" from
//    "does Signal's ratchet also enforce ordering", which are different
//    claims.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message.dart';
import 'package:nexora/features/messaging/domain/receive_message_use_case.dart';

/// A minimal `CiphertextMessage` for the fake-decrypt tests — it carries no
/// real cryptographic content, only a tag so the fake decrypt function
/// (a plain `Map` lookup) can tell distinct fake packets apart. Never used
/// in the real-crypto test, which uses genuine `PreKeySignalMessage`/
/// `SignalMessage` instances produced by `CryptoService.encrypt`.
class _FakeCiphertext implements CiphertextMessage {
  const _FakeCiphertext(this.tag);

  final String tag;

  @override
  Uint8List serialize() => Uint8List.fromList(utf8.encode('fake:$tag'));

  @override
  int getType() => CiphertextMessage.whisperType;
}

/// One simulated real Signal device — mirrors `crypto_service_test.dart`'s
/// own `_Party` helper, plus an `AppDatabase` for the `messages` table this
/// task writes to.
class _Party {
  _Party._(this.db, this.store, this.crypto);

  final AppDatabase db;
  final DriftSignalProtocolStore store;
  final CryptoService crypto;

  static Future<_Party> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftSignalProtocolStore(db);
    final identity = IdentityService(db, store);
    await identity.ensureLocalIdentity();
    await identity.ensureSignedPreKey();
    await identity.replenishOneTimePreKeys();
    final crypto = CryptoService.withStore(store);
    return _Party._(db, store, crypto);
  }

  Future<PreKeyBundle> bundle() async {
    final identity = IdentityService(db, store);
    return identity.getLocalPreKeyBundle();
  }

  Future<void> close() => db.close();
}

Uint8List _plaintext(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('MessageEnvelope', () {
    test('test_envelope_roundtrip_preserves_all_fields', () {
      final cases = <MessageEnvelope>[
        MessageEnvelope(
          id: 'msg-1',
          conversationId: 'conv-1',
          sequenceNumber: 1,
          payload: _plaintext('hello'),
        ),
        MessageEnvelope(
          id: 'a-much-longer-client-generated-uuid-like-id-0123456789',
          conversationId: 'convo-with-unicode-üñîçødé-🎉',
          sequenceNumber: 9223372036854775807, // max int64-ish
          payload: Uint8List(0), // empty payload must round-trip too
        ),
        MessageEnvelope(
          id: '',
          conversationId: '',
          sequenceNumber: 0,
          payload: _plaintext('payload with no id/conversationId'),
        ),
      ];

      for (final envelope in cases) {
        final bytes = envelope.serialize();
        final decoded = MessageEnvelope.deserialize(bytes);
        expect(decoded.id, envelope.id);
        expect(decoded.conversationId, envelope.conversationId);
        expect(decoded.sequenceNumber, envelope.sequenceNumber);
        expect(decoded.payload, envelope.payload);
      }
    });

    test('deserialize throws FormatException on truncated bytes', () {
      final envelope = MessageEnvelope(
        id: 'id',
        conversationId: 'conv',
        sequenceNumber: 5,
        payload: _plaintext('x'),
      );
      final bytes = envelope.serialize();

      // Truncated before the id-length header even completes.
      expect(
        () => MessageEnvelope.deserialize(bytes.sublist(0, 2)),
        throwsFormatException,
      );
      // Truncated mid-way through the fixed-width header (id present,
      // sequenceNumber's 8 bytes cut short) — the payload itself being
      // short is NOT an error (a zero-length payload is valid), but a
      // short *header* must be rejected rather than silently misread.
      final headerOnlyLength =
          4 + utf8.encode(envelope.id).length + 4 +
          utf8.encode(envelope.conversationId).length + 8;
      expect(
        () => MessageEnvelope.deserialize(
          bytes.sublist(0, headerOnlyLength - 1),
        ),
        throwsFormatException,
      );
    });
  });

  group('ReceiveMessageUseCase — real E03 CryptoService', () {
    late _Party alice;
    late _Party bob;
    // `bobAddress` is how ALICE addresses the remote party (Bob) when
    // encrypting — same convention as `crypto_service_test.dart`. Bob's own
    // side never needs an explicit address: `ReceiveMessageUseCase` builds
    // `SignalProtocolAddress(senderDeviceId, 1)` internally from the
    // `'alice'` string passed to `call()`.
    const bobAddress = SignalProtocolAddress('bob', 1);

    setUp(() async {
      alice = await _Party.create();
      bob = await _Party.create();
      await alice.crypto.establishSession(bobAddress, await bob.bundle());
    });

    tearDown(() async {
      await alice.close();
      await bob.close();
    });

    test(
      'test_EARS_MSG_2_duplicate_packet_dropped_not_double_stored',
      () async {
        final useCase = ReceiveMessageUseCase(
          database: bob.db,
          decrypt: bob.crypto.decrypt,
        );

        final envelope = MessageEnvelope(
          id: 'dup-msg-1',
          conversationId: 'conv-1',
          sequenceNumber: 1,
          payload: _plaintext('hello bob'),
        );

        // Alice encrypts and "sends" the same envelope twice — a plausible
        // real-world retry (task file §6: E04's relay might hand off the
        // same logical packet twice under some retry path). Each is a
        // genuinely distinct Double Ratchet ciphertext.
        final wire1 = await alice.crypto.encrypt(
          bobAddress,
          envelope.serialize(),
        );
        final wire2 = await alice.crypto.encrypt(
          bobAddress,
          envelope.serialize(),
        );

        final first = await useCase.call('alice', wire1);
        expect(first, isNotNull);
        expect(first!.id, 'dup-msg-1');
        expect(first.deliveryState, DeliveryState.accepted);

        final second = await useCase.call('alice', wire2);
        expect(second, isNull);

        final rows = await bob.db.select(bob.db.messages).get();
        expect(rows, hasLength(1));
        expect(rows.single.id, 'dup-msg-1');
      },
    );

    // E04-B18: this call already decrypts the envelope (line ~107 of the
    // use case, to recover id/conversationId/sequenceNumber) -- this test
    // proves that ALREADY-decrypted payload is now persisted, not thrown
    // away, so the chat screen never has to (and structurally cannot
    // safely) decrypt this exact ciphertext a second time.
    test(
      'test_E04_B18_persists_the_already_decrypted_payload_not_just_ciphertext',
      () async {
        final useCase = ReceiveMessageUseCase(
          database: bob.db,
          decrypt: bob.crypto.decrypt,
        );

        final envelope = MessageEnvelope(
          id: 'plain-msg-1',
          conversationId: 'conv-1',
          sequenceNumber: 1,
          payload: _plaintext('the real text'),
        );
        final wire = await alice.crypto.encrypt(
          bobAddress,
          envelope.serialize(),
        );

        final result = await useCase.call('alice', wire);
        expect(result, isNotNull);
        expect(result!.plaintextPayload, isNotNull);
        expect(utf8.decode(result.plaintextPayload!), 'the real text');

        final row = await (bob.db.select(bob.db.messages)
              ..where((t) => t.id.equals('plain-msg-1')))
            .getSingle();
        expect(row.plaintextPayload, isNotNull);
        expect(utf8.decode(row.plaintextPayload!), 'the real text');
        // The ciphertext is still persisted too -- this is additive, not a
        // replacement of the existing opaque-bytes column.
        expect(row.ciphertext, isNotEmpty);
      },
    );
  });

  group('ReceiveMessageUseCase — fake decrypt seam', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    Future<Uint8List> Function(SignalProtocolAddress, CiphertextMessage)
        fakeDecryptFor(Map<String, MessageEnvelope> envelopesByTag) {
      return (SignalProtocolAddress address, CiphertextMessage ciphertext) async {
        final tagged = ciphertext as _FakeCiphertext;
        final envelope = envelopesByTag[tagged.tag]!;
        return envelope.serialize();
      };
    }

    test(
      'test_EARS_MSG_2_concurrent_duplicate_delivery_still_single_row',
      () async {
        final envelope = MessageEnvelope(
          id: 'race-msg-1',
          conversationId: 'conv-1',
          sequenceNumber: 1,
          payload: _plaintext('racing packet'),
        );
        final useCase = ReceiveMessageUseCase(
          database: db,
          decrypt: fakeDecryptFor({'p': envelope}),
        );

        // Two near-simultaneous deliveries of the exact same duplicate
        // packet — the race this task's §6 flags as the same class as
        // L-backend-003's lineage (check-then-act split across two
        // concurrent calls). Both `call()`s start before either has
        // finished; the dedup check + insert must be one atomic
        // transaction so only one ever passes "not found".
        final results = await Future.wait([
          useCase.call('alice', const _FakeCiphertext('p')),
          useCase.call('alice', const _FakeCiphertext('p')),
        ]);

        final nonNull = results.whereType<Message>().toList();
        expect(
          nonNull,
          hasLength(1),
          reason: 'exactly one of the two racing calls must persist a row; '
              'the other must observe the duplicate and return null',
        );

        final rows = await (db.select(db.messages)
              ..where((t) => t.id.equals('race-msg-1')))
            .get();
        expect(
          rows,
          hasLength(1),
          reason: 'the race must never produce a second row for the same id',
        );
      },
    );

    test(
      'test_EARS_MSG_3_out_of_order_arrival_preserves_logical_sequence',
      () async {
        final envelope1 = MessageEnvelope(
          id: 'seq-msg-1',
          conversationId: 'conv-1',
          sequenceNumber: 1,
          payload: _plaintext('first logically'),
        );
        final envelope2 = MessageEnvelope(
          id: 'seq-msg-2',
          conversationId: 'conv-1',
          sequenceNumber: 2,
          payload: _plaintext('second logically'),
        );
        final useCase = ReceiveMessageUseCase(
          database: db,
          decrypt: fakeDecryptFor({'p1': envelope1, 'p2': envelope2}),
        );

        // Delivered in REVERSE physical order: sequence 2's packet arrives
        // before sequence 1's — the whole point of this task existing
        // (task file §6: don't assume packets from one sender arrive in
        // arrival order).
        final second = await useCase.call('alice', const _FakeCiphertext('p2'));
        final first = await useCase.call('alice', const _FakeCiphertext('p1'));

        expect(second, isNotNull);
        expect(first, isNotNull);

        final rows = await (db.select(db.messages)
              ..where((t) => t.conversationId.equals('conv-1'))
              ..orderBy([(t) => OrderingTerm.asc(t.sequenceNumber)]))
            .get();

        expect(rows, hasLength(2));
        expect(rows[0].id, 'seq-msg-1');
        expect(rows[0].sequenceNumber, 1);
        expect(rows[1].id, 'seq-msg-2');
        expect(rows[1].sequenceNumber, 2);
      },
    );
  });

  // E04-B26: each device mints a 1:1 conversation id from its OWN
  // `relationships.device_id` for the peer, and the sender puts its own id
  // into the envelope. Live hardware: Pixel's id for Redmi is
  // `00:00:46:00:00:01`, Redmi's id for Pixel is `B8:DB:38:7C:D4:BF`, so every
  // inbound message landed in a ghost conversation on the receiver.
  group('E04-B26 — inbound conversation id remap', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    const sender = 'peer-identity';
    const senderMintedId = 'sender-minted-id';

    Future<void> insertRelationship(
      String deviceId,
      String state, {
      String? remoteSelfDeviceId,
    }) async {
      await db.into(db.relationships).insert(
            RelationshipsCompanion.insert(
              deviceId: deviceId,
              state: state,
              updatedAt: DateTime.now(),
              remoteSelfDeviceId: Value(remoteSelfDeviceId),
            ),
          );
    }

    ReceiveMessageUseCase useCaseFor(String id) {
      final envelope = MessageEnvelope(
        id: id,
        conversationId: senderMintedId,
        sequenceNumber: 1,
        payload: _plaintext('hello'),
      );
      return ReceiveMessageUseCase(
        database: db,
        decrypt: (_, _) async => envelope.serialize(),
      );
    }

    Future<String> persistedConversationId(String id) async {
      final row = await (db.select(db.messages)..where((t) => t.id.equals(id)))
          .getSingle();
      return row.conversationId;
    }

    test(
        'test_E04_B26_remaps_to_the_single_trusted_or_allowed_relationship_for_the_sender',
        () async {
      await insertRelationship(
        'local-id-for-peer',
        'allowed',
        remoteSelfDeviceId: sender,
      );

      final message =
          await useCaseFor('m1').call(sender, const _FakeCiphertext('m1'));

      expect(await persistedConversationId('m1'), 'local-id-for-peer');
      expect(message!.conversationId, 'local-id-for-peer');
    });

    test('test_E04_B26_no_matching_relationship_keeps_the_envelope_id',
        () async {
      await insertRelationship(
        'someone-else',
        'trusted',
        remoteSelfDeviceId: 'another-identity',
      );

      final message =
          await useCaseFor('m2').call(sender, const _FakeCiphertext('m2'));

      expect(await persistedConversationId('m2'), senderMintedId);
      expect(message!.conversationId, senderMintedId);
    });

    test('test_E04_B26_ambiguous_matches_keep_the_envelope_id', () async {
      await insertRelationship('dup-a', 'trusted', remoteSelfDeviceId: sender);
      await insertRelationship('dup-b', 'allowed', remoteSelfDeviceId: sender);

      await useCaseFor('m3').call(sender, const _FakeCiphertext('m3'));

      expect(await persistedConversationId('m3'), senderMintedId);
    });

    test('test_E04_B26_never_remaps_into_a_blocked_or_unknown_relationship',
        () async {
      await insertRelationship(
        'blocked-peer',
        'blocked',
        remoteSelfDeviceId: sender,
      );
      await useCaseFor('m4').call(sender, const _FakeCiphertext('m4'));
      expect(await persistedConversationId('m4'), senderMintedId);

      await (db.delete(db.relationships)).go();
      await insertRelationship(
        'unknown-peer',
        'unknown',
        remoteSelfDeviceId: sender,
      );
      await useCaseFor('m5').call(sender, const _FakeCiphertext('m5'));
      expect(await persistedConversationId('m5'), senderMintedId);
    });

    test(
        'test_E04_B26_never_remaps_an_envelope_id_that_already_has_its_own_relationship',
        () async {
      // The envelope's conversation id already belongs to a (blocked)
      // relationship on THIS device; a spoofed sender claim matching an
      // allowed contact must not pull it into that contact's thread
      // (E04-B24 round-2 F5, restated for the receive path).
      await insertRelationship(senderMintedId, 'blocked');
      await insertRelationship(
        'trusted-contact',
        'allowed',
        remoteSelfDeviceId: sender,
      );

      await useCaseFor('m6').call(sender, const _FakeCiphertext('m6'));

      expect(await persistedConversationId('m6'), senderMintedId);
    });

    test('test_E04_B26_duplicate_is_still_dropped_after_a_remap', () async {
      await insertRelationship(
        'local-id-for-peer',
        'trusted',
        remoteSelfDeviceId: sender,
      );
      final useCase = useCaseFor('m7');

      final first = await useCase.call(sender, const _FakeCiphertext('m7'));
      final second = await useCase.call(sender, const _FakeCiphertext('m7'));

      expect(first, isNotNull);
      expect(second, isNull);
      final rows = await (db.select(db.messages)
            ..where((t) => t.id.equals('m7')))
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.conversationId, 'local-id-for-peer');
    });
  });
}
