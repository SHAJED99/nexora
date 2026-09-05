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
  /// [onKeyMaterialChanged], if given, is invoked (best-effort — any error
  /// it throws is swallowed, never propagated to this class's own callers)
  /// whenever [ensureSignedPreKey] or [replenishOneTimePreKeys] actually
  /// runs (E11-T06, `ADR-0008` option 2's publish trigger). Deliberately a
  /// generic callback rather than a direct `DeviceDirectoryService`
  /// dependency: `core/crypto` does not import `core/services` (this
  /// file's own header — "does NOT transmit the bundle anywhere"), so the
  /// actual publish call is wired in by whoever constructs this service,
  /// keeping this file's own layering unchanged. `null` (the default) is a
  /// pure no-op — every existing caller/test is unaffected.
  IdentityService(
    this._db,
    this._store, {
    Future<void> Function()? onKeyMaterialChanged,
  })  : // Named param (`onKeyMaterialChanged`) is public API; the private
        // field below can't share that name, so `prefer_initializing_formals`
        // doesn't apply here despite the trivial assignment -- same
        // reasoning as `DeviceRevocationService`/`RelationshipSyncService`.
        _onKeyMaterialChanged = onKeyMaterialChanged; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final DriftSignalProtocolStore _store;
  final Future<void> Function()? _onKeyMaterialChanged;

  /// Best-effort hook invocation shared by [ensureSignedPreKey] and
  /// [replenishOneTimePreKeys] — never allowed to change either method's
  /// own return value or throwing behaviour (task E11-T06 §3: "additive
  /// calls only").
  Future<void> _notifyKeyMaterialChanged() async {
    if (_onKeyMaterialChanged == null) return;
    try {
      await _onKeyMaterialChanged();
    } catch (_) {
      // Swallowed deliberately: a directory-publish failure must never
      // surface as an identity/prekey-bootstrap failure. The concrete
      // hook implementation (`DeviceDirectoryService.publish`) already
      // never throws on its own, so this is a second, redundant layer of
      // protection against whatever hook a future caller wires in here.
    }
  }

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
    // E11-T06: only fires when a signed prekey was actually (re)generated
    // -- the idempotent no-op branch above must not trigger a directory
    // republish for material that did not change.
    await _notifyKeyMaterialChanged();
  }

  /// Keeps the one-time prekey pool from running dry. Counts the prekeys
  /// that can still be *issued*; if below [minimum], allocates [batch] more
  /// ids from the store's monotonic high-water mark
  /// ([DriftSignalProtocolStore.allocateOneTimePreKeyIds]) — never derived
  /// from the live rows, so a fully-drained pool never restarts id
  /// allocation at 1 and reissue ids already handed to peers (E03-B01).
  ///
  /// The depth check is
  /// [DriftSignalProtocolStore.countIssuableOneTimePreKeys], NOT the raw row
  /// count (added in review, E03-B02). Once issuance became cursor-driven, a
  /// prekey that was handed to a peer who has not replied yet is still a
  /// live row but can never be issued again. Counting rows would report a
  /// full pool for a device whose every prekey is already in flight, this
  /// method would return 0, and [getLocalPreKeyBundle] would then throw
  /// `StateError` on every subsequent call with no recovery available to the
  /// caller — the exact state a device reaches simply by adding [minimum]
  /// contacts before any of them answers.
  ///
  /// Returns the count of newly generated prekeys (0 if already at or
  /// above [minimum]).
  Future<int> replenishOneTimePreKeys({
    int minimum = 20,
    int batch = 20,
  }) async {
    final issuable = await _store.countIssuableOneTimePreKeys();
    if (issuable >= minimum) {
      return 0;
    }

    final ids = await _store.allocateOneTimePreKeyIds(batch);
    for (final id in ids) {
      final record = generatePreKeys(id, 1).single;
      await _store.storePreKey(record.id, record);
    }
    // E11-T06: only fires when the pool was actually replenished -- the
    // early `return 0` above (pool already at/above minimum) must not
    // trigger a directory republish for material that did not change.
    await _notifyKeyMaterialChanged();
    return ids.length;
  }

  /// Assembles the local identity key, registration id, signed prekey, and
  /// one not-previously-issued one-time prekey into a [PreKeyBundle] for a
  /// remote peer to X3DH with this device. Each call returns a *distinct*
  /// one-time prekey from the last (E03-B02) — selection and cursor advance
  /// happen atomically in [DriftSignalProtocolStore.issueOneTimePreKey], so
  /// two callers can never be handed the same prekey. Does not remove the
  /// row from the store — the receiving side of establishment (E03-T03)
  /// removes it when it's actually consumed.
  ///
  /// Throws [StateError] if [ensureLocalIdentity]/[ensureSignedPreKey]
  /// haven't run yet, or if no un-issued one-time prekey remains in the
  /// pool (no material available for the first-message forward-secrecy
  /// guarantee — call [replenishOneTimePreKeys] first; per the task file,
  /// invoking that automatically here is left to the caller, E05/E06).
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

    final issuedRow = await _store.issueOneTimePreKey();
    if (issuedRow == null) {
      throw StateError(
        'No one-time prekeys available '
        '(call replenishOneTimePreKeys() first).',
      );
    }
    final oneTimeRecord = PreKeyRecord.fromBuffer(issuedRow.record);

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
}
