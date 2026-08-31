// core/crypto — Drift-backed `SenderKeyStore` (ADR-0003, E07-T04,
// `drift_signal_store.dart`'s own header: "explicitly out of scope — that
// belongs to E07").
//
// **The mapping is the task (task file §2/§6, `OQ-E07-8`).** libsignal's own
// `SenderKeyName` is a two-part `(groupId, sender)` key — it has no notion of
// a membership epoch. `E07-T01`'s `group_sender_keys` table is deliberately
// keyed by the *three*-part `(groupId, senderDeviceId, membershipEpoch)`, so
// that a rotation (E07-T05) can hold a removed member's old chain and the new
// chain apart as distinct rows rather than overwriting one in place
// (`OQ-E07-4` advisory 1). [senderKeyNameFor]/[parseSenderKeyName] are the
// ONE place that reconciles the two shapes: the epoch is folded into the
// *group* half of libsignal's name as `'<groupId>@<epoch>'`, never into the
// sender half. Folding it into the sender half (or leaving it out entirely)
// would make libsignal treat two different epochs as the SAME group/sender
// pair — an overwrite race that silently breaks FR-GROUP-005 with every test
// still green if it isn't caught here (task file §6's own warning).
//
// This file implements ONLY `libsignal_protocol_dart`'s `SenderKeyStore`
// interface (`storeSenderKey`/`loadSenderKey`) — no key generation, no
// ratchet, no cipher. `GroupCryptoService` (this task's other half) is the
// only caller that ever mints or advances a chain; this file is a pure
// storage seam, mirroring `DriftSignalProtocolStore`'s own discipline.
//
// **`loadSenderKey` for an unknown name returns a fresh, empty
// `SenderKeyRecord` — never `null`, never a neighbouring group's or epoch's
// record** (task file §2). This is libsignal's own documented contract
// (`GroupCipher.decrypt` checks `record.isEmpty` itself, exactly like
// `DriftSignalProtocolStore.loadSession`'s "fresh empty `SessionRecord`"
// contract for the pairwise store) — not a design choice made here.
//
// Does NOT add a table, column, index or migration — `E07-T01` owns
// `group_sender_keys` and its schema. Does NOT decide when to rotate or
// discard a chain (`E07-T05`) — `GroupCryptoService.discardChains` (this
// task's other file) is the delete path; this store has no delete method of
// its own beyond the two the library's interface requires.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor's `clock` parameter, matching the same documented exclusion
// already used by `relay_engine.dart`/`prekey_exchange.dart`/
// `group_membership_service.dart`: the field is private (`_clock`) while the
// constructor's public named parameter is `clock`, so an initializing formal
// would make the parameter itself private too.
// ignore_for_file: prefer_initializing_formals
import 'package:drift/drift.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../persistence/database.dart';

/// The Signal device-id half of every `SenderKeyName.sender` address this
/// app mints for the group layer — matches `_localSignalDeviceId`/
/// `_remoteSignalDeviceId`, independently redeclared per file across this
/// codebase for the same reason documented in `messaging_stack.dart`'s
/// header (judgment call 1): those constants are `library`-private, so Dart
/// makes literal reuse across files impossible.
const int kSenderKeyDeviceId = 1;

/// Builds the ONE `SenderKeyName` this app ever mints for a group's sender
/// chain (task file §2/§5): `SenderKeyName('groupId@epoch',
/// SignalProtocolAddress(senderDeviceId, kSenderKeyDeviceId))`. The epoch is
/// folded into the *group* half — never the sender half — so libsignal
/// itself treats each epoch as a structurally distinct group, which is
/// exactly the property FR-GROUP-005 needs (a chain for epoch N is then
/// incapable of decrypting a message sent at epoch N+1, by construction, not
/// by policy).
SenderKeyName senderKeyNameFor({
  required String groupId,
  required int epoch,
  required String senderDeviceId,
}) {
  return SenderKeyName(
    '$groupId@$epoch',
    SignalProtocolAddress(senderDeviceId, kSenderKeyDeviceId),
  );
}

/// The inverse of [senderKeyNameFor]. Throws [ArgumentError] on a
/// `SenderKeyName` this app did not mint — a group half with no `'@'`
/// epoch suffix, a non-integer suffix, or a sender device id other than
/// [kSenderKeyDeviceId] — rather than silently misparsing it into the wrong
/// `(groupId, epoch)` pair.
({String groupId, int epoch, String senderDeviceId}) parseSenderKeyName(
  SenderKeyName name,
) {
  final compositeGroupId = name.groupId;
  final atIndex = compositeGroupId.lastIndexOf('@');
  if (atIndex < 0) {
    throw ArgumentError.value(
      name,
      'name',
      'SenderKeyName group half "$compositeGroupId" has no "@<epoch>" '
          'suffix -- not minted by senderKeyNameFor',
    );
  }
  final groupId = compositeGroupId.substring(0, atIndex);
  final epochText = compositeGroupId.substring(atIndex + 1);
  final epoch = int.tryParse(epochText);
  if (epoch == null) {
    throw ArgumentError.value(
      name,
      'name',
      'SenderKeyName epoch suffix "$epochText" is not an integer',
    );
  }
  if (name.sender.getDeviceId() != kSenderKeyDeviceId) {
    throw ArgumentError.value(
      name,
      'name',
      'SenderKeyName sender device id ${name.sender.getDeviceId()} does '
          'not match kSenderKeyDeviceId ($kSenderKeyDeviceId)',
    );
  }
  return (
    groupId: groupId,
    epoch: epoch,
    senderDeviceId: name.sender.getName(),
  );
}

/// The durable `SenderKeyStore` `GroupSessionBuilder`/`GroupCipher` read and
/// write through (task file §3), backed by `E07-T01`'s `group_sender_keys`
/// table. One instance per [AppDatabase] — cheap to construct, holds no
/// state of its own.
class DriftSenderKeyStore implements SenderKeyStore {
  DriftSenderKeyStore(this._db, {DateTime Function() clock = DateTime.now})
      : _clock = clock;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<void> storeSenderKey(
    SenderKeyName senderKeyName,
    SenderKeyRecord record,
  ) async {
    final parsed = parseSenderKeyName(senderKeyName);
    await _db.into(_db.groupSenderKeys).insertOnConflictUpdate(
          GroupSenderKeysCompanion.insert(
            groupId: parsed.groupId,
            senderDeviceId: parsed.senderDeviceId,
            membershipEpoch: parsed.epoch,
            record: record.serialize(),
            updatedAt: _clock().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<SenderKeyRecord> loadSenderKey(SenderKeyName senderKeyName) async {
    final parsed = parseSenderKeyName(senderKeyName);
    final row = await (_db.select(_db.groupSenderKeys)
          ..where(
            (t) =>
                t.groupId.equals(parsed.groupId) &
                t.senderDeviceId.equals(parsed.senderDeviceId) &
                t.membershipEpoch.equals(parsed.epoch),
          ))
        .getSingleOrNull();
    if (row == null) {
      // libsignal's own contract (this file's header) -- a fresh, empty
      // record, never null and never a neighbouring group's/epoch's record
      // (the WHERE clause above already guarantees the latter).
      return SenderKeyRecord();
    }
    return SenderKeyRecord.fromSerialized(row.record);
  }
}
