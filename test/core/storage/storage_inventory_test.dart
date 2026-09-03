// test/core/storage — E08-T02, StorageInventory read model.
//
// Every test seeds a real in-memory AppDatabase.forTesting(NativeDatabase
// .memory()) (onCreate path, same idiom as other *_migration_test.dart
// files under test/core/persistence/) and asserts on real SQL-measured
// totals -- never a fixture that pre-computes the answer in Dart.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_item.dart';

Uint8List _bytes(int length, [int fill = 0x41]) {
  return Uint8List.fromList(List<int>.filled(length, fill));
}

Future<void> _seedMessage(
  AppDatabase db, {
  required String id,
  required int bytes,
  String conversationId = 'conv-1',
  int createdAt = 1000,
}) {
  return db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: conversationId,
          senderDeviceId: 'device-1',
          sequenceNumber: 1,
          ciphertext: _bytes(bytes),
          createdAt: createdAt,
          deliveryState: 'Queued',
        ),
      );
}

Future<void> _seedRelayPacket(
  AppDatabase db, {
  required String id,
  int? payloadBytes,
  int createdAt = 1000,
}) {
  return db.into(db.relayPackets).insert(
        RelayPacketsCompanion.insert(
          id: id,
          destinationId: 'dest-1',
          payload: payloadBytes == null
              ? const drift.Value.absent()
              : drift.Value(_bytes(payloadBytes, 0x00)),
          priority: 1,
          sizeBytes: payloadBytes ?? 0,
          createdAt: createdAt,
          expiresAt: createdAt + 60000,
          deliveryState: 'queued',
        ),
      );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('EARS-STORE-5', () {
    test('test_EARS_STORE_5_snapshot_reports_measured_message_bytes',
        () async {
      await _seedMessage(db, id: 'm1', bytes: 10);
      await _seedMessage(db, id: 'm2', bytes: 20);
      await _seedMessage(db, id: 'm3', bytes: 30);

      final inventory = StorageInventory(
        db: db,
        databaseFileBytes: () async => 0,
      );
      final snapshot = await inventory.snapshot();

      final messageTotal = snapshot.classTotals
          .singleWhere((t) => t.kind == StorageItemKind.message);
      expect(messageTotal.itemCount, 3);
      expect(messageTotal.bytes, 60);
    });

    test('test_EARS_STORE_5_relay_rows_with_null_payload_are_not_items',
        () async {
      await _seedRelayPacket(db, id: 'r1', payloadBytes: 15);
      await _seedRelayPacket(db, id: 'r2', payloadBytes: 25);
      // Reclaimed row -- payload nulled out by RelayEngine.reclaimPayloads,
      // row kept for diagnostics. Must not count as an item.
      await _seedRelayPacket(db, id: 'r3', payloadBytes: null);

      final inventory = StorageInventory(
        db: db,
        databaseFileBytes: () async => 0,
      );
      final snapshot = await inventory.snapshot();

      final relayTotal = snapshot.classTotals
          .singleWhere((t) => t.kind == StorageItemKind.relayPayload);
      expect(relayTotal.itemCount, 2);
      expect(relayTotal.bytes, 40);

      final items = await inventory.itemsOfKind(StorageItemKind.relayPayload);
      expect(items.map((i) => i.id), containsAll(['r1', 'r2']));
      expect(items.map((i) => i.id), isNot(contains('r3')));
    });

    test('test_EARS_STORE_5_media_kinds_yield_zero_items_today', () async {
      final inventory = StorageInventory(
        db: db,
        databaseFileBytes: () async => 0,
      );

      for (final kind in [
        StorageItemKind.voiceMessage,
        StorageItemKind.pttRecording,
        StorageItemKind.callRecording,
        StorageItemKind.attachment,
      ]) {
        final items = await inventory.itemsOfKind(kind);
        expect(items, isEmpty, reason: '$kind has no producer today');
      }

      final snapshot = await inventory.snapshot();
      for (final kind in [
        StorageItemKind.voiceMessage,
        StorageItemKind.pttRecording,
        StorageItemKind.callRecording,
        StorageItemKind.attachment,
      ]) {
        final total =
            snapshot.classTotals.singleWhere((t) => t.kind == kind);
        expect(total.itemCount, 0);
        expect(total.bytes, 0);
      }
    });

    test('test_EARS_STORE_5_database_file_size_is_reported_separately',
        () async {
      await _seedMessage(db, id: 'm1', bytes: 10);
      await _seedRelayPacket(db, id: 'r1', payloadBytes: 20);

      final inventory = StorageInventory(
        db: db,
        databaseFileBytes: () async => 999999,
      );
      final snapshot = await inventory.snapshot();

      expect(snapshot.databaseFileBytes, 999999);
      // Never summed into the class totals -- pages/free-space/WAL overhead
      // makes the file's own size unrelated to the sum of row payloads
      // (task §6 risk note).
      expect(
        snapshot.classTotals.any((t) => t.kind == StorageItemKind.databaseFile),
        isFalse,
      );

      final total = inventory.totalBytes(snapshot);
      expect(total, 30); // 10 (message) + 20 (relay) -- NOT + 999999.
    });
  });

  group('EARS-STORE-6', () {
    test('test_EARS_STORE_6_inventory_never_decrypts', () async {
      // Source-level guard: the inventory must never import a decrypt path
      // or call one. Checked against the `import` lines and any call-like
      // token (`.decrypt(`/`decrypt(`) rather than the whole file text --
      // the file's own doc comments legitimately explain, in prose, that it
      // never decrypts, and a whole-text grep for "decrypt" would trip on
      // that prose rather than on real code.
      final source =
          File('lib/core/storage/storage_inventory.dart').readAsStringSync();
      final importLines = source
          .split('\n')
          .where((line) => line.trimLeft().startsWith('import '));
      for (final line in importLines) {
        expect(line.contains('crypto'), isFalse, reason: line);
        expect(line.contains('CryptoService'), isFalse, reason: line);
        expect(line.contains('MessageEnvelope'), isFalse, reason: line);
      }
      expect(source.contains('CryptoService'), isFalse);
      expect(source.contains('MessageEnvelope'), isFalse);
      expect(source.contains('.decrypt('), isFalse);
      expect(RegExp(r'(?<![a-zA-Z])decrypt\(').hasMatch(source), isFalse);

      // Functional guard: undecryptable garbage bytes must not stop the
      // snapshot from succeeding -- the inventory only measures length.
      await _seedMessage(db, id: 'garbage', bytes: 5);
      final inventory = StorageInventory(
        db: db,
        databaseFileBytes: () async => 0,
      );
      final snapshot = await inventory.snapshot();
      final messageTotal = snapshot.classTotals
          .singleWhere((t) => t.kind == StorageItemKind.message);
      expect(messageTotal.itemCount, 1);
    });

    test('test_EARS_STORE_6_items_of_kind_respects_limit', () async {
      for (var i = 0; i < 10; i++) {
        await _seedMessage(db, id: 'm$i', bytes: 5, createdAt: 1000 + i);
      }

      final inventory = StorageInventory(
        db: db,
        databaseFileBytes: () async => 0,
      );
      final items =
          await inventory.itemsOfKind(StorageItemKind.message, limit: 4);
      expect(items.length, 4);
    });
  });

  test(
      'LENGTH() on the BLOB ciphertext/payload columns returns bytes, '
      'not characters (task §6 risk note)', () async {
    // A blob containing an embedded NUL and non-ASCII byte values -- if
    // this were ever mis-measured as TEXT, a NUL would truncate the
    // apparent length and multi-byte sequences would miscount.
    final tricky = Uint8List.fromList([
      0x00, 0xFF, 0xC0, 0x80, 0x00, 0xE2, 0x82, 0xAC, ...List.filled(292, 0x00)
    ]); // length 300
    expect(tricky.length, 300);
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'tricky',
            conversationId: 'conv-1',
            senderDeviceId: 'device-1',
            sequenceNumber: 1,
            ciphertext: tricky,
            createdAt: 1000,
            deliveryState: 'Queued',
          ),
        );

    final inventory = StorageInventory(
      db: db,
      databaseFileBytes: () async => 0,
    );
    final snapshot = await inventory.snapshot();
    final messageTotal = snapshot.classTotals
        .singleWhere((t) => t.kind == StorageItemKind.message);
    expect(messageTotal.bytes, 300);

    final items = await inventory.itemsOfKind(StorageItemKind.message);
    expect(items.single.bytes, 300);
  });
}
