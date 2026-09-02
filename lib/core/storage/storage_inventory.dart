// core/storage — StorageInventory read model (E08-T02, ADR-0001).
//
// The one honest answer to "what is actually stored on this device, in
// what classes, and how many real bytes does each take" -- every later
// storage policy/warning/explanation in this epic reads from here rather
// than from an invented estimate (task §2, E04-B03's standing prohibition,
// `dashboard_controller.dart`'s own header restates the same rule).
//
// Read-only, always. This file never writes a row, never deletes a row,
// never touches relay TTL/reclaim (that's `RelayEngine.reclaimPayloads()`,
// owned by E04-B02/E06-T06), and never computes a percentage or a quota --
// there is no denominator yet (OQ-E08-1).
//
// Never decrypts, never parses a payload. `messages.ciphertext` and
// `relay_packets.payload` are opaque bytes (FR-ROUTE-003, NFR-PRIV-001);
// every measurement below is a SQL `LENGTH(...)`/`COUNT(*)` aggregate, never
// a materialized row loaded into Dart and inspected.
import 'package:drift/drift.dart';
import 'package:nexora/core/persistence/database.dart';

import 'storage_item.dart';

/// A single measurement pass over locally stored data: per-class totals
/// (message, relayPayload, and the four zero-item-today media kinds) plus
/// the sqlite file's own on-disk byte size, taken together at [measuredAt].
///
/// [databaseFileBytes] is reported separately from [classTotals] on
/// purpose (task §6 risk note): the file's own size includes pages, free
/// space and WAL overhead, and is never the sum of row payloads. Nothing
/// in this class sums the two together -- see [StorageInventory.totalBytes].
class StorageInventorySnapshot {
  const StorageInventorySnapshot({
    required this.classTotals,
    required this.databaseFileBytes,
    required this.measuredAt,
  });

  final List<StorageClassTotal> classTotals;
  final int databaseFileBytes;
  final DateTime measuredAt;
}

/// Read-only inventory over locally stored data. Every measurement comes
/// from a SQL aggregate over [db] (ADR-0001: all access through
/// `AppDatabase`) or from the injected [databaseFileBytes] measurement --
/// never from loading every row into Dart and counting there (task §2,
/// "a history large enough to be worth managing is a history too large to
/// materialize").
class StorageInventory {
  StorageInventory({required this.db, required this.databaseFileBytes});

  /// The app's single `AppDatabase` instance (composed by E08-T06, never
  /// constructed here).
  final AppDatabase db;

  /// Injected measurement of the sqlite file's on-disk size -- injected so
  /// tests need no real file, and so the real implementation's `dart:io`
  /// call stays a caller concern.
  final Future<int> Function() databaseFileBytes;

  /// The one call every policy and every UI surface reads (task §5).
  Future<StorageInventorySnapshot> snapshot() async {
    final messageTotal = await _messageTotal();
    final relayTotal = await _relayPayloadTotal();
    final fileBytes = await databaseFileBytes();

    final classTotals = <StorageClassTotal>[
      messageTotal,
      relayTotal,
      // Media kinds: no producer exists in this build (task §3/§6,
      // OQ-E08-6) -- reported as real zero-item totals, not "unmeasured",
      // because there is nothing ambiguous about a class with no rows.
      for (final kind in const [
        StorageItemKind.voiceMessage,
        StorageItemKind.pttRecording,
        StorageItemKind.callRecording,
        StorageItemKind.attachment,
      ])
        StorageClassTotal(kind: kind, itemCount: 0, bytes: 0),
    ];

    return StorageInventorySnapshot(
      classTotals: classTotals,
      databaseFileBytes: fileBytes,
      measuredAt: DateTime.now(),
    );
  }

  Future<StorageClassTotal> _messageTotal() async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS item_count, '
          'COALESCE(SUM(LENGTH(ciphertext)), 0) AS total_bytes '
          'FROM messages',
          readsFrom: {db.messages},
        )
        .getSingle();
    return StorageClassTotal(
      kind: StorageItemKind.message,
      itemCount: row.read<int>('item_count'),
      bytes: row.read<int>('total_bytes'),
    );
  }

  Future<StorageClassTotal> _relayPayloadTotal() async {
    // NULL payload = a reclaimed row (relay_tables.dart: nulled out by
    // RelayEngine.reclaimPayloads once a terminal-state row passes its own
    // expires_at). Excluded here deliberately (task §6 risk note): counting
    // it as an item with bytes: 0 would overstate the item count.
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS item_count, '
          'COALESCE(SUM(LENGTH(payload)), 0) AS total_bytes '
          'FROM relay_packets WHERE payload IS NOT NULL',
          readsFrom: {db.relayPackets},
        )
        .getSingle();
    return StorageClassTotal(
      kind: StorageItemKind.relayPayload,
      itemCount: row.read<int>('item_count'),
      bytes: row.read<int>('total_bytes'),
    );
  }

  /// Per-item enumeration for candidate selection, bounded by construction
  /// (task §5): [limit] is a hard bound, the caller pages, this method
  /// never returns an unbounded list. Newest first. Empty for a kind with
  /// no producer today.
  Future<List<StorageItem>> itemsOfKind(
    StorageItemKind kind, {
    int limit = 500,
    int? olderThanEpochMs,
  }) async {
    switch (kind) {
      case StorageItemKind.message:
        return _messageItems(limit: limit, olderThanEpochMs: olderThanEpochMs);
      case StorageItemKind.relayPayload:
        return _relayPayloadItems(
          limit: limit,
          olderThanEpochMs: olderThanEpochMs,
        );
      case StorageItemKind.databaseFile:
      case StorageItemKind.voiceMessage:
      case StorageItemKind.pttRecording:
      case StorageItemKind.callRecording:
      case StorageItemKind.attachment:
        // No producer today (task §3/§6) -- databaseFile is a single
        // container property, not an enumerable item, and the four media
        // kinds have nothing writing rows yet. Both report empty, honestly.
        return const [];
    }
  }

  Future<List<StorageItem>> _messageItems({
    required int limit,
    int? olderThanEpochMs,
  }) async {
    final buffer = StringBuffer(
      'SELECT id, conversation_id, LENGTH(ciphertext) AS bytes, created_at '
      'FROM messages',
    );
    final variables = <Variable<Object>>[];
    if (olderThanEpochMs != null) {
      buffer.write(' WHERE created_at < ?');
      variables.add(Variable.withInt(olderThanEpochMs));
    }
    buffer.write(' ORDER BY created_at DESC LIMIT ?');
    variables.add(Variable.withInt(limit));

    final rows = await db
        .customSelect(
          buffer.toString(),
          variables: variables,
          readsFrom: {db.messages},
        )
        .get();
    return rows
        .map(
          (row) => StorageItem(
            kind: StorageItemKind.message,
            id: row.read<String>('id'),
            conversationId: row.read<String>('conversation_id'),
            bytes: row.read<int>('bytes'),
            createdAt: row.read<int>('created_at'),
            // Not temporary -- a message is not TTL'd (task §2).
            isTemporary: false,
          ),
        )
        .toList();
  }

  Future<List<StorageItem>> _relayPayloadItems({
    required int limit,
    int? olderThanEpochMs,
  }) async {
    final buffer = StringBuffer(
      'SELECT id, LENGTH(payload) AS bytes, created_at FROM relay_packets '
      'WHERE payload IS NOT NULL',
    );
    final variables = <Variable<Object>>[];
    if (olderThanEpochMs != null) {
      buffer.write(' AND created_at < ?');
      variables.add(Variable.withInt(olderThanEpochMs));
    }
    buffer.write(' ORDER BY created_at DESC LIMIT ?');
    variables.add(Variable.withInt(limit));

    final rows = await db
        .customSelect(
          buffer.toString(),
          variables: variables,
          readsFrom: {db.relayPackets},
        )
        .get();
    return rows
        .map(
          (row) => StorageItem(
            kind: StorageItemKind.relayPayload,
            id: row.read<String>('id'),
            // A relay packet belongs to a route, not a conversation.
            conversationId: null,
            bytes: row.read<int>('bytes'),
            createdAt: row.read<int>('created_at'),
            // Temporary by construction -- relay_tables.dart: "local only,
            // ephemeral", TTL owned by RelayEngine.reclaimPayloads (task §2).
            isTemporary: true,
          ),
        )
        .toList();
  }

  /// The numerator every later surface uses -- the denominator is
  /// `OQ-E08-1`'s, not this method's. Sums only the measured class totals
  /// in [snapshot]; [StorageInventorySnapshot.databaseFileBytes] is
  /// reported separately and is deliberately NOT added here (task §6 risk
  /// note: the file's own size is never the sum of row payloads, and
  /// summing them would double-count/misrepresent both figures).
  int totalBytes(StorageInventorySnapshot snapshot) {
    var total = 0;
    for (final classTotal in snapshot.classTotals) {
      total += classTotal.bytes;
    }
    return total;
  }
}
