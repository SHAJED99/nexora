// core/crypto — local identity + prekey bundle generation (ADR-0003, E03-T02).
//
// On first run, generates this device's real Signal identity material
// (identity keypair, registration id, a signed prekey, and a pool of
// one-time prekeys) via `libsignal_protocol_dart`'s own `KeyHelper`
// functions, and persists it through `DriftSignalProtocolStore` (E03-T01).
// Assembles a `PreKeyBundle` for a remote peer to X3DH with this device.
//
// Does NOT transmit the bundle anywhere — how a peer actually receives it
// is E04's (transport) concern. Does NOT implement SessionBuilder/X3DH
// session establishment on the consuming side, or SessionCipher
// encrypt/decrypt — that's E03-T03. Does NOT add a prekey rotation/expiry
// policy — the app runs one signed prekey at a time for v1 (task file §4;
// noted here as a follow-up, not solved in this task).
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../persistence/database.dart';
import 'drift_signal_store.dart';

/// The fixed signed-prekey id this app uses for v1: one signed prekey at a
/// time, no rotation policy yet.
const int _signedPreKeyId = 1;

/// This device's own numbering within the Signal protocol's multi-device
/// addressing scheme (the `deviceId` half of `SignalProtocolAddress`).
/// Multi-device key distribution (FR-MSG-005) is out of scope for this
/// task and this epic's current wave — fixed at 1 until a multi-device
/// task introduces real per-device allocation. Not specified by this
/// task's §5 contract; recorded as a judgment call in the Run log.
const int _localDeviceId = 1;

/// Generates and assembles this device's Signal protocol identity material.
///
/// Storage is delegated entirely to [DriftSignalProtocolStore] (E03-T01) —
/// this class only decides *when* to generate material and *how* to shape
/// it into a [PreKeyBundle]; it never invents its own serialization format
/// or persistence path.
class IdentityService {
  IdentityService(this._db, this._store);

  final AppDatabase _db;
  final DriftSignalProtocolStore _store;

  /// First-run identity bootstrap. Idempotent: a second (or later) call is
  /// a no-op that leaves the already-persisted identity untouched, per
  /// [DriftSignalProtocolStore.saveLocalIdentityIfAbsent]'s singleton-row
  /// contract — regenerating would orphan every session a peer has with
  /// this device.
  Future<void> ensureLocalIdentity() async {
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    await _store.saveLocalIdentityIfAbsent(identityKeyPair, registrationId);
  }

  /// First-run signed-prekey bootstrap. Idempotent: a second call is a
  /// no-op if a signed prekey already exists (id [_signedPreKeyId]).
  ///
  /// Must run after [ensureLocalIdentity] — the signed prekey's signature
  /// is computed with the local identity's private key.
  Future<void> ensureSignedPreKey() async {
    if (await _store.containsSignedPreKey(_signedPreKeyId)) {
      return;
    }
    final identityKeyPair = await _store.getIdentityKeyPair();
    final record = generateSignedPreKey(identityKeyPair, _signedPreKeyId);
    await _store.storeSignedPreKey(_signedPreKeyId, record);
  }

  /// Keeps the one-time prekey pool from running dry. Counts prekeys
  /// currently in the store; if below [minimum], generates [batch] more
  /// starting at `max(existing ids) + 1` — never reusing an id left free
  /// by a consumed/removed prekey (task file §6 risk).
  ///
  /// Returns the count of newly generated prekeys (0 if already at or
  /// above [minimum]).
  Future<int> replenishOneTimePreKeys({
    int minimum = 20,
    int batch = 20,
  }) async {
    final existingIds = await _oneTimePreKeyIds();
    if (existingIds.length >= minimum) {
      return 0;
    }

    final nextId = existingIds.isEmpty
        ? 1
        : existingIds.reduce((a, b) => a > b ? a : b) + 1;
    final newRecords = generatePreKeys(nextId, batch);
    for (final record in newRecords) {
      await _store.storePreKey(record.id, record);
    }
    return newRecords.length;
  }

  /// Assembles the local identity key, registration id, signed prekey, and
  /// one unconsumed one-time prekey into a [PreKeyBundle] for a remote peer
  /// to X3DH with this device. Does not mark the one-time prekey consumed —
  /// the receiving side of establishment (E03-T03) removes it when it's
  /// actually used.
  ///
  /// Throws [StateError] if [ensureLocalIdentity]/[ensureSignedPreKey]
  /// haven't run yet, or if the one-time prekey pool is empty (no material
  /// available for the first-message forward-secrecy guarantee).
  Future<PreKeyBundle> getLocalPreKeyBundle() async {
    // Throws StateError itself if no identity has been generated yet.
    final identityKeyPair = await _store.getIdentityKeyPair();
    final registrationId = await _store.getLocalRegistrationId();

    final signedPreKeyRows = await _db.select(_db.signalSignedPrekeys).get();
    if (signedPreKeyRows.isEmpty) {
      throw StateError(
        'No signed prekey generated yet (call ensureSignedPreKey() first).',
      );
    }
    final signedPreKeyRecord = SignedPreKeyRecord.fromSerialized(
      signedPreKeyRows.first.record,
    );

    final oneTimeRows = await _db.select(_db.signalOneTimePrekeys).get();
    if (oneTimeRows.isEmpty) {
      throw StateError(
        'No one-time prekeys available '
        '(call replenishOneTimePreKeys() first).',
      );
    }
    final oneTimeRecord = PreKeyRecord.fromBuffer(oneTimeRows.first.record);

    return PreKeyBundle(
      registrationId,
      _localDeviceId,
      oneTimeRecord.id,
      oneTimeRecord.getKeyPair().publicKey,
      signedPreKeyRecord.id,
      signedPreKeyRecord.getKeyPair().publicKey,
      signedPreKeyRecord.signature,
      identityKeyPair.getPublicKey(),
    );
  }

  Future<List<int>> _oneTimePreKeyIds() async {
    final rows = await _db.select(_db.signalOneTimePrekeys).get();
    return rows.map((row) => row.id).toList();
  }
}
