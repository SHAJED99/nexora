// core/persistence -- sync_cursors table (E05-T04, FR-MSG-006/FR-FB-002).
//
// Per device-pair, per conversation: the highest `sequence_number` this
// device has confirmed seeing from the remote device, so a reconnect can
// compute "what's missing" instead of re-syncing everything (epic.md's Data
// model). This table only holds cursor *positions* -- never message content
// or ciphertext (FR-FB-002, same boundary as `messages.ciphertext` in
// message_tables.dart and `FirebaseMetadataService`'s four-field limit).
//
// No `@TableIndex` declared: every real access pattern here is a point
// lookup/upsert by the full primary key (`local_device_id`, `remote_device_id`,
// `conversation_id`) -- `cursorFor`/`recordLocalProgress` both filter on all
// three columns, which the PK's own implicit index already serves. Unlike
// `messages` (T01), there is no range/order-by query over a subset of these
// columns that would need a secondary index. (T01's own round-1 finding:
// `createTable` does NOT create any `@TableIndex`-declared index by itself --
// noted here explicitly because this table deliberately declares none, not
// because that fact was overlooked.)
import 'package:drift/drift.dart';

@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  /// This device's own device id (the "local" side of the pair).
  TextColumn get localDeviceId => text()();

  /// The other device (of this user's own devices, per epic.md's
  /// mesh-to-mesh multi-device sync) this cursor tracks progress against.
  TextColumn get remoteDeviceId => text()();

  TextColumn get conversationId => text()();

  /// Highest `messages.sequence_number` confirmed seen from
  /// `remoteDeviceId` for this conversation. Monotonic -- never written
  /// backward (see `SyncCursorService.recordLocalProgress`).
  IntColumn get lastConfirmedSequenceNumber => integer()();

  /// Epoch-ms wall-clock time of the last update to this row.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {localDeviceId, remoteDeviceId, conversationId};
}
