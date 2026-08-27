// core/crypto — real X3DH session establishment + Double Ratchet
// encrypt/decrypt (ADR-0003, E03-T03).
//
// This is the public API every later communication epic (E05, E06) calls to
// send/receive end-to-end encrypted bytes. It is a thin wrapper around
// `libsignal_protocol_dart`'s own `SessionBuilder`/`SessionCipher` — no
// ratchet math is reimplemented here (FR-SEC-004). Storage is delegated
// entirely to `DriftSignalProtocolStore` (E03-T01/T01b/E03-B01); this file
// never persists key material itself and never logs it.
//
// Filename kept as `crypto_stub.dart` — this is the genesis stub's file
// getting its real body, not a new file, so no other import in the app
// needs to change (task file §3).
//
// Does NOT auto-establish a session inside encrypt()/decrypt() on the
// initiating side; does NOT implement group/Sender-Keys crypto (E07); does
// NOT wire into main.dart or any use case (no caller exists yet this epic).
// See task file §4 for the full "does NOT do" list.
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'drift_signal_store.dart';

class CryptoService {
  CryptoService._();

  /// Process-wide singleton — the shape genesis established. Production
  /// code calls `init(store)` once at startup, then uses
  /// `CryptoService.instance` everywhere else.
  static final CryptoService instance = CryptoService._();

  /// A store-bound instance independent of the process-wide singleton.
  /// Production code has exactly one Signal identity per device, so it has
  /// no use for this — it exists for tests (this task's own two-party
  /// tests) that must simulate two separate devices, each with its own
  /// store, in a single process.
  CryptoService.withStore(DriftSignalProtocolStore store) : _store = store;

  DriftSignalProtocolStore? _store;

  /// Wires the durable store this service will use. Must be called once
  /// before [establishSession]/[encrypt]/[decrypt]. Safe to call again with
  /// the same store (idempotent); the store itself owns whether identity
  /// material already exists (E03-T02's `IdentityService`).
  Future<void> init(DriftSignalProtocolStore store) async {
    _store = store;
  }

  DriftSignalProtocolStore get _requireStore {
    final store = _store;
    if (store == null) {
      throw StateError(
        'CryptoService.init(store) must be called before use.',
      );
    }
    return store;
  }

  /// X3DH handshake, initiating side. Wraps
  /// `SessionBuilder.processPreKeyBundle`. On return, a session exists in
  /// the store for [remoteAddress].
  ///
  /// Throws [UntrustedIdentityException] if [remoteBundle]'s identity key
  /// contradicts a previously-trusted one for this address (T01b's durable
  /// `isTrustedIdentity`).
  Future<void> establishSession(
    SignalProtocolAddress remoteAddress,
    PreKeyBundle remoteBundle,
  ) async {
    final builder = SessionBuilder.fromSignalStore(
      _requireStore,
      remoteAddress,
    );
    await builder.processPreKeyBundle(remoteBundle);
  }

  /// Double Ratchet encrypt step. Wraps `SessionCipher.encrypt`.
  ///
  /// Returns a [PreKeySignalMessage] if the session is still
  /// pre-confirmation, else a [SignalMessage] — either way, its
  /// `.serialize()` bytes are what a transport actually carries.
  ///
  /// Throws [StateError] if no session exists yet for [remoteAddress] — this
  /// task never auto-establishes on demand (task file §4); callers
  /// (E05/E06) must call [establishSession] first.
  Future<CiphertextMessage> encrypt(
    SignalProtocolAddress remoteAddress,
    Uint8List plaintext,
  ) async {
    final store = _requireStore;
    if (!await store.containsSession(remoteAddress)) {
      throw StateError(
        'No session established with $remoteAddress. '
        'Call establishSession() first.',
      );
    }
    final cipher = SessionCipher.fromStore(store, remoteAddress);
    return cipher.encrypt(plaintext);
  }

  /// Double Ratchet decrypt step. Detects whether [ciphertext] is a
  /// [PreKeySignalMessage] (X3DH responder side — establishes the session
  /// implicitly, per the library's own `SessionBuilder.process`) or a
  /// steady-state [SignalMessage], and wraps the matching library call
  /// (`SessionCipher.decrypt` / `SessionCipher.decryptFromSignal` in the
  /// installed v0.8.2 API — the task file's `decryptPreKeyMessage` sketch
  /// was directionally correct but not the real method name).
  ///
  /// Throws on an invalid, replayed, or otherwise undecryptable message
  /// rather than returning garbage — e.g. [NoSessionException] with no
  /// session yet, [DuplicateMessageException] on a replayed counter.
  Future<Uint8List> decrypt(
    SignalProtocolAddress remoteAddress,
    CiphertextMessage ciphertext,
  ) async {
    final store = _requireStore;
    final cipher = SessionCipher.fromStore(store, remoteAddress);
    if (ciphertext is PreKeySignalMessage) {
      return cipher.decrypt(ciphertext);
    }
    if (ciphertext is SignalMessage) {
      return cipher.decryptFromSignal(ciphertext);
    }
    throw ArgumentError(
      'Unsupported ciphertext message type: ${ciphertext.runtimeType}',
    );
  }
}
