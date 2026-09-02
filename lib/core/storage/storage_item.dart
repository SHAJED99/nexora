// core/storage — value types for the storage inventory read model
// (E08-T02, ADR-0001).
//
// These are plain, immutable Dart values — no Drift dependency, no
// persistence of their own. `StorageInventory` (storage_inventory.dart)
// produces them from real SQL aggregates over `AppDatabase`; nothing here
// invents or estimates a figure (task §2's standing prohibition, restated
// from E04-B03/`dashboard_controller.dart`).
library;

/// Every class of locally stored data this build can enumerate.
///
/// `message` and `relayPayload` have real producers today (`messages` and
/// `relay_packets` respectively) and are backed by real SQL aggregates.
/// `databaseFile` is the sqlite file's own on-disk size, not a row sum.
///
/// `voiceMessage`, `pttRecording`, `callRecording` and `attachment` are
/// declared here as the seam a future media-capture task extends — but
/// **nothing in this build writes rows for any of them** (task §3/§6,
/// `OQ-E08-6`). `StorageInventory.itemsOfKind` and `snapshot()` therefore
/// report these four kinds with zero items today, honestly, not as a
/// promise that data exists.
enum StorageItemKind {
  message,
  relayPayload,
  databaseFile,
  voiceMessage,
  pttRecording,
  callRecording,
  attachment,
}

/// One stored item — a single `messages` row's ciphertext, a single
/// `relay_packets` row's non-NULL payload, or (once a producer exists) a
/// media file. `bytes` is always a real measured length, never an estimate.
class StorageItem {
  const StorageItem({
    required this.kind,
    required this.id,
    required this.conversationId,
    required this.bytes,
    required this.createdAt,
    required this.isTemporary,
  });

  final StorageItemKind kind;
  final String id;

  /// Null for kinds with no conversation association (e.g. a relay packet,
  /// which belongs to a route, not a conversation).
  final String? conversationId;

  /// Real measured byte length (`LENGTH(...)` in SQL). Never synthesized.
  final int bytes;

  /// Epoch-ms wall-clock creation time, same convention as the source
  /// table's `created_at` column.
  final int createdAt;

  /// Derived, not invented (task §2): a `relayPayload` is temporary by
  /// construction — `relay_tables.dart` documents relay packets as "local
  /// only, ephemeral" with TTL owned by `RelayEngine.reclaimPayloads()`.
  /// A `message` is not temporary. This is the definition the rest of the
  /// epic's eight factors uses for "temporary status".
  final bool isTemporary;
}

/// Per-kind aggregate: how many items of this kind exist, and how many real
/// bytes they occupy in total. Produced by SQL `COUNT(*)`/`SUM(LENGTH(...))`
/// aggregates — never by summing a materialized item list in Dart.
class StorageClassTotal {
  const StorageClassTotal({
    required this.kind,
    required this.itemCount,
    required this.bytes,
  });

  final StorageItemKind kind;
  final int itemCount;
  final int bytes;
}
