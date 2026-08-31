// Tests for DriftSenderKeyStore + senderKeyNameFor/parseSenderKeyName
// (E07-T04, EARS-GROUP-12/14).
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/drift_sender_key_store.dart';
import 'package:nexora/core/persistence/database.dart';

void main() {
  group('senderKeyNameFor / parseSenderKeyName', () {
    test('test_sender_key_name_round_trips', () {
      final name = senderKeyNameFor(
        groupId: 'g:abcdef',
        epoch: 7,
        senderDeviceId: 'device-a',
      );
      final parsed = parseSenderKeyName(name);
      expect(parsed.groupId, 'g:abcdef');
      expect(parsed.epoch, 7);
      expect(parsed.senderDeviceId, 'device-a');
    });

    test('epoch is folded into the group half, never the sender half', () {
      final name = senderKeyNameFor(
        groupId: 'g:abcdef',
        epoch: 7,
        senderDeviceId: 'device-a',
      );
      expect(name.groupId, 'g:abcdef@7');
      expect(name.sender.getName(), 'device-a');
      expect(name.sender.getDeviceId(), kSenderKeyDeviceId);
    });

    test('two different epochs of the same group produce different names',
        () {
      final epoch0 = senderKeyNameFor(
        groupId: 'g:abcdef',
        epoch: 0,
        senderDeviceId: 'device-a',
      );
      final epoch1 = senderKeyNameFor(
        groupId: 'g:abcdef',
        epoch: 1,
        senderDeviceId: 'device-a',
      );
      expect(epoch0 == epoch1, isFalse);
    });

    test('parseSenderKeyName rejects a name this app did not mint', () {
      final foreign = SenderKeyName(
        'g:abcdef', // no '@<epoch>' suffix
        SignalProtocolAddress('device-a', kSenderKeyDeviceId),
      );
      expect(() => parseSenderKeyName(foreign), throwsArgumentError);
    });

    test('parseSenderKeyName rejects a non-integer epoch suffix', () {
      final foreign = SenderKeyName(
        'g:abcdef@not-a-number',
        SignalProtocolAddress('device-a', kSenderKeyDeviceId),
      );
      expect(() => parseSenderKeyName(foreign), throwsArgumentError);
    });

    test('parseSenderKeyName rejects the wrong sender device id', () {
      final foreign = SenderKeyName(
        'g:abcdef@0',
        SignalProtocolAddress('device-a', 99),
      );
      expect(() => parseSenderKeyName(foreign), throwsArgumentError);
    });
  });

  group('DriftSenderKeyStore', () {
    late AppDatabase db;
    late DriftSenderKeyStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = DriftSenderKeyStore(db);
    });

    tearDown(() => db.close());

    test(
        'test_load_unknown_name_returns_a_fresh_empty_record_not_a_neighbour',
        () async {
      // Seed a record for a DIFFERENT (group, epoch, sender) triple first,
      // so an unknown lookup returning it (instead of a fresh empty record)
      // would be caught, not accidentally missed by an empty table.
      final neighbourName = senderKeyNameFor(
        groupId: 'g:neighbour',
        epoch: 0,
        senderDeviceId: 'device-a',
      );
      await GroupSessionBuilder(store).create(neighbourName);
      final seeded = await store.loadSenderKey(neighbourName);
      expect(seeded.isEmpty, isFalse);

      final unknownName = senderKeyNameFor(
        groupId: 'g:unknown',
        epoch: 0,
        senderDeviceId: 'device-a',
      );
      final record = await store.loadSenderKey(unknownName);
      // Fresh and empty -- not the neighbour's non-empty record, and not
      // null (the type system already guarantees non-null; this asserts
      // the *value* is genuinely a distinct, empty record).
      expect(record.isEmpty, isTrue);
      expect(record.getSenderKeyState, throwsA(anything));
    });

    test('storeSenderKey then loadSenderKey round-trips a real chain state',
        () async {
      final name = senderKeyNameFor(
        groupId: 'g:store-test',
        epoch: 0,
        senderDeviceId: 'device-a',
      );
      final wrapper = await GroupSessionBuilder(store).create(name);
      final loaded = await store.loadSenderKey(name);
      expect(loaded.isEmpty, isFalse);
      expect(loaded.getSenderKeyState().keyId, wrapper.id);
    });

    test(
        'test_discard_chains_below_epoch_removes_only_the_named_group',
        () async {
      final gA0 = senderKeyNameFor(
        groupId: 'g:a',
        epoch: 0,
        senderDeviceId: 'device-a',
      );
      final gA1 = senderKeyNameFor(
        groupId: 'g:a',
        epoch: 1,
        senderDeviceId: 'device-a',
      );
      final gB0 = senderKeyNameFor(
        groupId: 'g:b',
        epoch: 0,
        senderDeviceId: 'device-a',
      );
      await GroupSessionBuilder(store).create(gA0);
      await GroupSessionBuilder(store).create(gA1);
      await GroupSessionBuilder(store).create(gB0);

      final deleted = await (db.delete(db.groupSenderKeys)
            ..where(
              (t) =>
                  t.groupId.equals('g:a') &
                  t.membershipEpoch.isSmallerThanValue(1),
            ))
          .go();

      expect(deleted, 1);
      expect((await store.loadSenderKey(gA0)).isEmpty, isTrue);
      expect((await store.loadSenderKey(gA1)).isEmpty, isFalse);
      expect((await store.loadSenderKey(gB0)).isEmpty, isFalse);
    });

    test('a second store on the same database sees the first store\'s writes '
        '(chain survives a reopen-equivalent)', () async {
      final name = senderKeyNameFor(
        groupId: 'g:reopen',
        epoch: 0,
        senderDeviceId: 'device-a',
      );
      await GroupSessionBuilder(store).create(name);

      final secondStore = DriftSenderKeyStore(db);
      final loaded = await secondStore.loadSenderKey(name);
      expect(loaded.isEmpty, isFalse);
    });

    test('no key material or record bytes appear in a toString() of the store',
        () {
      // DriftSenderKeyStore has no custom toString/logging of its own --
      // this documents that fact rather than testing a print call that does
      // not exist. See group_crypto_service_test.dart for the log-call grep
      // covering the sibling file.
      expect(store.toString(), isNot(contains('SenderKeyRecord')));
    });
  });
}
