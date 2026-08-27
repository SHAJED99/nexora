// core/crypto — Signal protocol store, backed by Drift (ADR-0003, E03-T01).
//
// Storage seam only: implements `libsignal_protocol_dart`'s four store
// interfaces (`IdentityKeyStore`, `PreKeyStore`, `SignedPreKeyStore`,
// `SessionStore`, bundled as `SignalProtocolStore`) so T02/T03 have
// somewhere durable to keep key material. No key generation and no
// encrypt/decrypt logic lives here.
//
// `SenderKeyStore` (group/Sender-Keys persistence) is explicitly out of
// scope — that belongs to E07 when group encryption is built.
import 'package:drift/drift.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../persistence/database.dart';

/// The fixed row id for the singleton local-identity row. Never
/// autoincrement — a second row would mean a silently-regenerated identity,
/// which would orphan every session a peer has with this device.
const int _localIdentityRowId = 0;

/// The fixed row id for the singleton allocation-counters row (E03-B01).
const int _countersRowId = 0;

/// libsignal's own prekey id space wraps here (`Medium.MAX_VALUE`,
/// `2^24 - 1`). Allocation wraps back to 1 rather than overflowing —
/// full wrap-safety (skipping ids that might still be live) is not
/// required for v1: one-time prekeys are expected to be consumed and
/// replenished long before ~16M ids are ever issued (task file, "What
/// this task does").
const int _preKeyIdMediumMaxValue = 0xFFFFFF;

/// The modulus of the *usable* prekey id space, which must match
/// libsignal's `generatePreKeys(start, count)` exactly. That function
/// computes `((start - 1 + i).remainder(Medium.MAX_VALUE - 1)) + 1`
/// (`key_helper.dart:37`), so the ids it can actually mint are
/// `1..Medium.MAX_VALUE - 1`.
///
/// Allocating over the wider `1..Medium.MAX_VALUE` would break the
/// invariant this whole fix rests on — that the id handed out by
/// [DriftSignalProtocolStore.allocateOneTimePreKeyIds] is the id that ends
/// up in `signal_one_time_prekeys`. Allocating `Medium.MAX_VALUE` itself
/// made libsignal silently mint id `1` instead, so the counter recorded a
/// ~16M id as issued while the row written reused an ancient id — and a
/// batch straddling the boundary minted the same id twice, overwriting a
/// live prekey's key material. Caught in E03-B01 review.
const int _preKeyIdSpaceModulus = _preKeyIdMediumMaxValue - 1;

class DriftSignalProtocolStore extends SignalProtocolStore {
  DriftSignalProtocolStore(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------
  // IdentityKeyStore
  // ---------------------------------------------------------------------

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    final row = await (_db.select(_db.signalIdentity)
          ..where((t) => t.id.equals(_localIdentityRowId)))
        .getSingleOrNull();
    if (row == null) {
      throw StateError(
        'No Signal identity keypair has been generated yet (see E03-T02).',
      );
    }
    return IdentityKeyPair.fromSerialized(row.identityKeyPair);
  }

  @override
  Future<int> getLocalRegistrationId() async {
    final row = await (_db.select(_db.signalIdentity)
          ..where((t) => t.id.equals(_localIdentityRowId)))
        .getSingleOrNull();
    if (row == null) {
      throw StateError(
        'No Signal registration id has been generated yet (see E03-T02).',
      );
    }
    return row.registrationId;
  }

  /// Persists the local identity keypair + registration id as the
  /// singleton row. Not part of the library's `IdentityKeyStore` interface
  /// (that interface only reads the local identity) — this is the write
  /// side T02's key-generation step calls, exposed here since this class
  /// owns the `signal_identity` table.
  ///
  /// A second call is a no-op (the existing identity is left untouched and
  /// returned as-is via [getIdentityKeyPair]/[getLocalRegistrationId]) —
  /// regenerating would orphan every session a peer has with this device.
  Future<void> saveLocalIdentityIfAbsent(
    IdentityKeyPair identityKeyPair,
    int registrationId,
  ) async {
    final existing = await (_db.select(_db.signalIdentity)
          ..where((t) => t.id.equals(_localIdentityRowId)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }
    await _db.into(_db.signalIdentity).insert(
          SignalIdentityCompanion.insert(
            id: const Value(_localIdentityRowId),
            identityKeyPair: identityKeyPair.serialize(),
            registrationId: registrationId,
          ),
        );
  }

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    final previous = await getIdentity(address);
    final changed =
        previous != null && identityKey != null && previous != identityKey;

    if (identityKey == null) {
      await (_db.delete(_db.signalTrustedIdentities)
            ..where((t) =>
                t.addressName.equals(address.getName()) &
                t.addressDeviceId.equals(address.getDeviceId())))
          .go();
    } else {
      await _db.into(_db.signalTrustedIdentities).insertOnConflictUpdate(
            SignalTrustedIdentitiesCompanion.insert(
              addressName: address.getName(),
              addressDeviceId: address.getDeviceId(),
              identityKey: identityKey.serialize(),
            ),
          );
    }
    return changed;
  }

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction direction,
  ) async {
    final previous = await getIdentity(address);
    if (previous == null) {
      // Trust-on-first-use: nothing recorded yet.
      return true;
    }
    return previous == identityKey;
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final row = await (_db.select(_db.signalTrustedIdentities)
          ..where((t) =>
              t.addressName.equals(address.getName()) &
              t.addressDeviceId.equals(address.getDeviceId())))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return IdentityKey.fromBytes(row.identityKey, 0);
  }

  // ---------------------------------------------------------------------
  // PreKeyStore (one-time prekeys)
  // ---------------------------------------------------------------------

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final row = await (_db.select(_db.signalOneTimePrekeys)
          ..where((t) => t.id.equals(preKeyId)))
        .getSingleOrNull();
    if (row == null) {
      throw InvalidKeyIdException('No such one-time prekey: $preKeyId');
    }
    return PreKeyRecord.fromBuffer(row.record);
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    await _db.into(_db.signalOneTimePrekeys).insertOnConflictUpdate(
          SignalOneTimePrekeysCompanion.insert(
            id: Value(preKeyId),
            record: record.serialize(),
          ),
        );
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    final row = await (_db.select(_db.signalOneTimePrekeys)
          ..where((t) => t.id.equals(preKeyId)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    await (_db.delete(_db.signalOneTimePrekeys)
          ..where((t) => t.id.equals(preKeyId)))
        .go();
  }

  /// Atomically allocates [count] consecutive one-time-prekey ids from a
  /// monotonic high-water mark (`crypto_counters.next_one_time_prekey_id`)
  /// that survives both consumption (`removePreKey`) and app restart —
  /// never re-derived from the live `signal_one_time_prekeys` rows (E03-B01
  /// root cause: `max(existing ids) + 1` restarts at 1 once the pool
  /// drains, reissuing ids already handed to peers with different key
  /// material).
  ///
  /// Allocates within libsignal's own mintable id space
  /// (`1..Medium.MAX_VALUE - 1`, see [_preKeyIdSpaceModulus]) so the id
  /// returned here is always the id `generatePreKeys` mints and
  /// `storePreKey` persists. Wraps back to 1 past the top of that space
  /// rather than overflowing; full wrap-safety against an ancient
  /// still-live id is a known, accepted edge case for v1 (task file, "What
  /// this task does").
  Future<List<int>> allocateOneTimePreKeyIds(int count) async {
    return _db.transaction(() async {
      final row = await (_db.select(_db.cryptoCounters)
            ..where((t) => t.id.equals(_countersRowId)))
          .getSingleOrNull();
      final start = row?.nextOneTimePreKeyId ?? 1;

      final ids = List<int>.generate(
        count,
        (i) => ((start - 1 + i) % _preKeyIdSpaceModulus) + 1,
      );
      final nextStart = ((start - 1 + count) % _preKeyIdSpaceModulus) + 1;

      await _db.into(_db.cryptoCounters).insertOnConflictUpdate(
            CryptoCountersCompanion.insert(
              id: const Value(_countersRowId),
              nextOneTimePreKeyId: Value(nextStart),
            ),
          );
      return ids;
    });
  }

  /// Atomically selects and reserves one not-previously-issued one-time
  /// prekey for `getLocalPreKeyBundle()` to hand to a peer (E03-B02).
  ///
  /// Distinct from [allocateOneTimePreKeyIds]: that counter tracks which ids
  /// exist at all (minting), this one tracks which of the *existing* ids
  /// have already been handed to a peer (issuance) — the seam
  /// `getLocalPreKeyBundle()` fell through, since it advanced only as a
  /// side effect of a peer's successful X3DH (`removePreKey`), not once per
  /// bundle issued. Selects the lowest live prekey id `>=` the persisted
  /// `next_issued_one_time_prekey_id` cursor and advances that cursor past
  /// it, in one transaction — mirrors [allocateOneTimePreKeyIds]'s atomic
  /// read-then-advance pattern so two concurrent bundle requests can never
  /// receive the same prekey.
  ///
  /// Returns `null` if no un-issued prekey remains live in the pool (pool
  /// exhaustion) — the caller ([IdentityService.getLocalPreKeyBundle])
  /// turns that into a `StateError`.
  Future<SignalOneTimePrekey?> issueOneTimePreKey() async {
    return _db.transaction(() async {
      final counterRow = await (_db.select(_db.cryptoCounters)
            ..where((t) => t.id.equals(_countersRowId)))
          .getSingleOrNull();
      final cursor = counterRow?.nextIssuedOneTimePreKeyId ?? 1;

      final row = await (_db.select(_db.signalOneTimePrekeys)
            ..where((t) => t.id.isBiggerOrEqualValue(cursor))
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(1))
          .getSingleOrNull();
      if (row == null) {
        return null;
      }

      await _db.into(_db.cryptoCounters).insertOnConflictUpdate(
            CryptoCountersCompanion.insert(
              id: const Value(_countersRowId),
              nextIssuedOneTimePreKeyId: Value(row.id + 1),
            ),
          );
      return row;
    });
  }

  /// Counts the one-time prekeys [issueOneTimePreKey] can still hand out:
  /// live rows at or above the issue cursor.
  ///
  /// Added in review (E03-B02): once issuance is cursor-driven, the raw row
  /// count of `signal_one_time_prekeys` is no longer the pool's usable
  /// depth — a row the cursor has already passed is still in the table but
  /// can never be issued again. Any health check that wants to know "can
  /// this device still hand a bundle to a new peer?" must ask this, not
  /// `count(*)`, or it will report a healthy pool while every request
  /// fails.
  Future<int> countIssuableOneTimePreKeys() async {
    final counterRow = await (_db.select(_db.cryptoCounters)
          ..where((t) => t.id.equals(_countersRowId)))
        .getSingleOrNull();
    final cursor = counterRow?.nextIssuedOneTimePreKeyId ?? 1;
    final rows = await (_db.select(_db.signalOneTimePrekeys)
          ..where((t) => t.id.isBiggerOrEqualValue(cursor)))
        .get();
    return rows.length;
  }

  // ---------------------------------------------------------------------
  // SignedPreKeyStore
  // ---------------------------------------------------------------------

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final row = await (_db.select(_db.signalSignedPrekeys)
          ..where((t) => t.id.equals(signedPreKeyId)))
        .getSingleOrNull();
    if (row == null) {
      throw InvalidKeyIdException(
        'No such signed prekey: $signedPreKeyId',
      );
    }
    return SignedPreKeyRecord.fromSerialized(row.record);
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final rows = await _db.select(_db.signalSignedPrekeys).get();
    return rows
        .map((row) => SignedPreKeyRecord.fromSerialized(row.record))
        .toList();
  }

  @override
  Future<void> storeSignedPreKey(
    int signedPreKeyId,
    SignedPreKeyRecord record,
  ) async {
    await _db.into(_db.signalSignedPrekeys).insertOnConflictUpdate(
          SignalSignedPrekeysCompanion.insert(
            id: Value(signedPreKeyId),
            record: record.serialize(),
          ),
        );
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    final row = await (_db.select(_db.signalSignedPrekeys)
          ..where((t) => t.id.equals(signedPreKeyId)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    await (_db.delete(_db.signalSignedPrekeys)
          ..where((t) => t.id.equals(signedPreKeyId)))
        .go();
  }

  // ---------------------------------------------------------------------
  // SessionStore
  // ---------------------------------------------------------------------

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final row = await (_db.select(_db.signalSessions)
          ..where((t) =>
              t.addressName.equals(address.getName()) &
              t.addressDeviceId.equals(address.getDeviceId())))
        .getSingleOrNull();
    if (row == null) {
      // Per the library's documented contract: a fresh, empty session
      // record when none exists yet, not an exception.
      return SessionRecord();
    }
    return SessionRecord.fromSerialized(row.record);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final rows = await (_db.select(_db.signalSessions)
          ..where((t) => t.addressName.equals(name)))
        .get();
    return rows.map((row) => row.addressDeviceId).toList();
  }

  @override
  Future<void> storeSession(
    SignalProtocolAddress address,
    SessionRecord record,
  ) async {
    await _db.into(_db.signalSessions).insertOnConflictUpdate(
          SignalSessionsCompanion.insert(
            addressName: address.getName(),
            addressDeviceId: address.getDeviceId(),
            record: record.serialize(),
          ),
        );
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final row = await (_db.select(_db.signalSessions)
          ..where((t) =>
              t.addressName.equals(address.getName()) &
              t.addressDeviceId.equals(address.getDeviceId())))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    await (_db.delete(_db.signalSessions)
          ..where((t) =>
              t.addressName.equals(address.getName()) &
              t.addressDeviceId.equals(address.getDeviceId())))
        .go();
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    await (_db.delete(_db.signalSessions)
          ..where((t) => t.addressName.equals(name)))
        .go();
  }
}
