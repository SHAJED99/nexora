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
